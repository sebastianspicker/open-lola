// Coordinates release-readiness execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation
import Dispatch
import COpenLolaAtomics
import os
#if canImport(CoreAudio)
import CoreAudio
import Darwin
#endif

#if canImport(CoreAudio)
enum CoreAudioRawInputRecorder {
    static func run(
        selection: RecordingAudioCaptureSelection,
        durationSeconds: Int
    ) throws -> RecordingCapturedAudio {
        let plan = try makeRecordingAudioInputPlan(selection: selection, durationSeconds: durationSeconds)
        let state = try CoreAudioRawInputState(plan: plan)
        let registration = try createRecordingAudioInputIOProc(deviceID: plan.deviceID, state: state)
        defer {
            cleanupRecordingAudioInputIOProc(deviceID: plan.deviceID, registration: registration, state: state)
        }
        try runRecordingAudioInputIOProc(
            deviceID: plan.deviceID,
            ioProcID: registration.ioProcID,
            durationSeconds: durationSeconds
        )
        let audio = state.capturedAudio()
        guard !audio.data.isEmpty else {
            throw RecordingLiveCaptureError.audioCapturedNoBytes
        }
        return audio
    }

    private static func makeRecordingAudioInputPlan(
        selection: RecordingAudioCaptureSelection,
        durationSeconds: Int
    ) throws -> RecordingAudioInputPlan {
        let inventory = try CoreAudioInventoryReader().capture()
        guard let uid = selection.inputUID,
              let device = inventory.devices.first(where: { $0.uid == uid }) else {
            throw RecordingLiveCaptureError.audioInputNotFound(selection.inputUID ?? "")
        }
        guard device.inputChannelCount > 0 else {
            throw RecordingLiveCaptureError.audioInputHasNoChannels(uid)
        }
        guard let sampleRate = selection.sampleRateHertz,
              let frames = selection.framesPerBuffer,
              let channelCount = selection.channelCount else {
            throw RecordingLiveCaptureError.audioConfigurationIncomplete
        }
        guard selection.inputChannels.allSatisfy({ $0 < device.inputChannelCount }) else {
            throw RecordingLiveCaptureError.audioChannelOutOfRange
        }
        return RecordingAudioInputPlan(
            deviceID: AudioObjectID(device.id),
            framesPerBuffer: frames,
            channelCount: channelCount,
            inputChannels: selection.inputChannels,
            sampleFormat: selection.sampleFormat,
            durationSeconds: durationSeconds,
            sampleRateHertz: sampleRate
        )
    }

    private static func createRecordingAudioInputIOProc(
        deviceID: AudioObjectID,
        state: CoreAudioRawInputState
    ) throws -> RecordingAudioInputIOProcRegistration {
        var ioProcID: AudioDeviceIOProcID?
        let retainedState = Unmanaged.passRetained(state)
        let status = AudioDeviceCreateIOProcID(
            deviceID,
            recordingAudioInputIOProc,
            retainedState.toOpaque(),
            &ioProcID
        )
        do {
            try throwRecordingAudioStatus(status, "create recording AudioDeviceIOProcID")
        } catch {
            retainedState.release()
            throw error
        }
        guard let ioProcID else {
            retainedState.release()
            throw RecordingLiveCaptureError.audioDeviceNotRunnable
        }
        return RecordingAudioInputIOProcRegistration(ioProcID: ioProcID, retainedState: retainedState)
    }

    private static func cleanupRecordingAudioInputIOProc(
        deviceID: AudioObjectID,
        registration: RecordingAudioInputIOProcRegistration,
        state: CoreAudioRawInputState
    ) {
        state.invalidateCallbacks()
        let destroyStatus = AudioDeviceDestroyIOProcID(deviceID, registration.ioProcID)
        if destroyStatus != noErr {
            os_log(
                .error,
                "AudioDeviceDestroyIOProcID failed for recording input cleanup with status %{public}d",
                destroyStatus
            )
        }
        registration.retainedState.release()
    }

    private static func runRecordingAudioInputIOProc(
        deviceID: AudioObjectID,
        ioProcID: AudioDeviceIOProcID,
        durationSeconds: Int
    ) throws {
        var didStartDevice = false
        defer {
            if didStartDevice {
                let stopStatus = AudioDeviceStop(deviceID, ioProcID)
                if stopStatus != noErr {
                    os_log(
                        .error,
                        "AudioDeviceStop failed for recording input cleanup with status %{public}d",
                        stopStatus
                    )
                }
            }
        }
        var status = AudioDeviceStart(deviceID, ioProcID)
        try throwRecordingAudioStatus(status, "start recording AudioDeviceIOProc")
        didStartDevice = true
        RecordingLiveCaptureWait.wait(durationSeconds: durationSeconds)
        status = AudioDeviceStop(deviceID, ioProcID)
        didStartDevice = false
        try throwRecordingAudioStatus(status, "stop recording AudioDeviceIOProc")
    }
}

private struct RecordingAudioInputPlan {
    let deviceID: AudioObjectID
    let framesPerBuffer: Int
    let channelCount: Int
    let inputChannels: [Int]
    let sampleFormat: RecordingAudioSampleFormat
    let durationSeconds: Int
    let sampleRateHertz: Int
}

private struct RecordingAudioInputIOProcRegistration {
    let ioProcID: AudioDeviceIOProcID
    let retainedState: Unmanaged<CoreAudioRawInputState>
}

final class CoreAudioRawInputState {
    private let bufferStorage: RecordingRawByteBuffer
    private let capacity: Int
    private let callbackDurationsStorage: RecordingUInt64Buffer
    private let callbackCapacity: Int
    private let framesPerBuffer: Int
    private let inputChannels: [Int]
    private let bytesPerSample: Int
    private var callbacksActive = OpenLolaAtomicUInt64()
    private var writtenBytes = 0
    private var callbackCount = 0
    private var overflowedBuffers = 0

    init(
        framesPerBuffer: Int,
        channelCount: Int,
        inputChannels: [Int],
        sampleFormat: RecordingAudioSampleFormat,
        durationSeconds: Int,
        sampleRateHertz: Int
    ) throws {
        self.framesPerBuffer = framesPerBuffer
        self.inputChannels = inputChannels
        self.bytesPerSample = sampleFormat.bytesPerSample
        guard let bytesPerBuffer = checkedRecordingAudioByteCount(
            frames: framesPerBuffer,
            channels: channelCount,
            bytesPerSample: sampleFormat.bytesPerSample
        ) else {
            throw RecordingLiveCaptureError.audioBufferSizingOverflow
        }
        let durationProduct = durationSeconds.multipliedReportingOverflow(by: sampleRateHertz)
        guard !durationProduct.overflow else {
            throw RecordingLiveCaptureError.audioBufferSizingOverflow
        }
        let rawCallbackCount = durationProduct.partialValue / framesPerBuffer + 2
        let callbackCount = max(1, rawCallbackCount)
        self.callbackCapacity = callbackCount
        let capacityProduct = bytesPerBuffer.multipliedReportingOverflow(by: callbackCount)
        guard !capacityProduct.overflow else {
            throw RecordingLiveCaptureError.audioBufferSizingOverflow
        }
        self.capacity = capacityProduct.partialValue
        self.bufferStorage = RecordingRawByteBuffer(byteCount: capacity, alignment: 16)
        self.callbackDurationsStorage = RecordingUInt64Buffer(capacity: callbackCapacity)
        open_lola_atomic_u64_init(&callbacksActive, 1)
    }

    fileprivate convenience init(plan: RecordingAudioInputPlan) throws {
        try self.init(
            framesPerBuffer: plan.framesPerBuffer,
            channelCount: plan.channelCount,
            inputChannels: plan.inputChannels,
            sampleFormat: plan.sampleFormat,
            durationSeconds: plan.durationSeconds,
            sampleRateHertz: plan.sampleRateHertz
        )
    }

    var canRecordCallback: Bool {
        open_lola_atomic_u64_load(&callbacksActive) == 1
    }

    func invalidateCallbacks() {
        open_lola_atomic_u64_store(&callbacksActive, 0)
    }

    func record(input: UnsafePointer<AudioBufferList>) {
        let start = DispatchTime.now().uptimeNanoseconds
        defer { recordCallbackDuration(startNanoseconds: start) }
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard !buffers.isEmpty else {
            return
        }
        guard let needed = checkedRecordingAudioByteCount(
            frames: framesPerBuffer,
            channels: inputChannels.count,
            bytesPerSample: bytesPerSample
        ) else {
            overflowedBuffers += 1
            return
        }
        let writeEnd = writtenBytes.addingReportingOverflow(needed)
        guard !writeEnd.overflow, writeEnd.partialValue <= capacity else {
            overflowedBuffers += 1
            return
        }
        let destination = bufferStorage.pointer.advanced(by: writtenBytes)
        if buffers.count == 1, Int(buffers[0].mNumberChannels) > (inputChannels.max() ?? 0) {
            copyInterleaved(buffer: buffers[0], destination: destination)
        } else {
            copyPlanar(buffers: buffers, destination: destination)
        }
        writtenBytes += needed
    }

    func capturedAudio() -> RecordingCapturedAudio {
        let metrics = callbackMetrics()
        return RecordingCapturedAudio(
            data: Data(bytes: bufferStorage.pointer, count: writtenBytes),
            callbackP99Microseconds: metrics.p99Microseconds,
            callbackMaxMicroseconds: metrics.maxMicroseconds,
            underruns: overflowedBuffers
        )
    }

    private func recordCallbackDuration(startNanoseconds: UInt64) {
        guard callbackCount < callbackCapacity else {
            return
        }
        callbackDurationsStorage.pointer[callbackCount] = DispatchTime.now().uptimeNanoseconds - startNanoseconds
        callbackCount += 1
    }

    private func callbackMetrics() -> (p99Microseconds: Double?, maxMicroseconds: Double?) {
        guard callbackCount > 0 else {
            return (nil, nil)
        }
        let durations = (0..<callbackCount).map { callbackDurationsStorage.pointer[$0] }.sorted()
        let p99Index = min(durations.count - 1, max(0, Int(ceil(Double(durations.count) * 0.99)) - 1))
        return (
            Double(durations[p99Index]) / 1_000.0,
            Double(durations[durations.count - 1]) / 1_000.0
        )
    }

    private func copyInterleaved(buffer: AudioBuffer, destination: UnsafeMutableRawPointer) {
        guard let source = buffer.mData else {
            return
        }
        let sourceChannels = Int(buffer.mNumberChannels)
        for frame in 0..<framesPerBuffer {
            for (outputChannel, inputChannel) in inputChannels.enumerated() {
                let sourceOffset = ((frame * sourceChannels) + inputChannel) * bytesPerSample
                let destinationOffset = ((frame * inputChannels.count) + outputChannel) * bytesPerSample
                memcpy(destination.advanced(by: destinationOffset), source.advanced(by: sourceOffset), bytesPerSample)
            }
        }
    }

    private func copyPlanar(
        buffers: UnsafeMutableAudioBufferListPointer,
        destination: UnsafeMutableRawPointer
    ) {
        for frame in 0..<framesPerBuffer {
            for (outputChannel, inputChannel) in inputChannels.enumerated() where inputChannel < buffers.count {
                guard let source = buffers[inputChannel].mData else {
                    continue
                }
                let sourceOffset = frame * bytesPerSample
                let destinationOffset = ((frame * inputChannels.count) + outputChannel) * bytesPerSample
                memcpy(destination.advanced(by: destinationOffset), source.advanced(by: sourceOffset), bytesPerSample)
            }
        }
    }
}

private final class RecordingRawByteBuffer {
    let pointer: UnsafeMutableRawPointer

    init(byteCount: Int, alignment: Int) {
        self.pointer = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: alignment)
        memset(pointer, 0, byteCount)
    }

    deinit {
        pointer.deallocate()
    }
}

private final class RecordingUInt64Buffer {
    let pointer: UnsafeMutablePointer<UInt64>
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.pointer = UnsafeMutablePointer<UInt64>.allocate(capacity: capacity)
        pointer.initialize(repeating: 0, count: capacity)
    }

    deinit {
        pointer.deinitialize(count: capacity)
        pointer.deallocate()
    }
}

// swiftlint:disable:next function_parameter_count
func recordingAudioInputIOProc(
    _: AudioObjectID,
    _: UnsafePointer<AudioTimeStamp>,
    _ inInputData: UnsafePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _ outOutputData: UnsafeMutablePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    zeroRecordingAudioOutputBuffers(outOutputData)
    if let inClientData {
        let state = Unmanaged<CoreAudioRawInputState>
            .fromOpaque(inClientData)
            .takeUnretainedValue()
        if state.canRecordCallback {
            state.record(input: inInputData)
        }
    }
    return noErr
}

private func zeroRecordingAudioOutputBuffers(_ output: UnsafeMutablePointer<AudioBufferList>) {
    let buffers = UnsafeMutableAudioBufferListPointer(output)
    for buffer in buffers {
        if let data = buffer.mData, buffer.mDataByteSize > 0 {
            memset(data, 0, Int(buffer.mDataByteSize))
        }
    }
}

private func throwRecordingAudioStatus(_ status: OSStatus, _ operation: String) throws {
    guard status == noErr else {
        throw RecordingLiveCaptureError.coreAudioStatus(status, operation)
    }
}
#else
enum CoreAudioRawInputRecorder {
    static func run(
        selection: RecordingAudioCaptureSelection,
        durationSeconds: Int
    ) throws -> RecordingCapturedAudio {
        _ = selection
        _ = durationSeconds
        throw RecordingLiveCaptureError.coreAudioUnavailable
    }
}
#endif
private func checkedRecordingAudioByteCount(frames: Int, channels: Int, bytesPerSample: Int) -> Int? {
    let frameSamples = frames.multipliedReportingOverflow(by: channels)
    guard !frameSamples.overflow else {
        return nil
    }
    let byteCount = frameSamples.partialValue.multipliedReportingOverflow(by: bytesPerSample)
    guard !byteCount.overflow else {
        return nil
    }
    return byteCount.partialValue
}
