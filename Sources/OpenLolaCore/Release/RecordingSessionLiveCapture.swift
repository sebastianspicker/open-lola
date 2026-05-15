import Foundation
import Dispatch
import COpenLolaAtomics
#if canImport(CoreAudio)
import CoreAudio
import Darwin
#endif
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
#endif

enum RecordingSessionLiveMediaCapture {
    static func capture(configuration: RecordingSessionRunConfiguration) -> RecordingCapturedMedia {
        var media = RecordingCapturedMedia()
        if configuration.capture.audio.mode == .on {
            do {
                media.audio = try CoreAudioRawInputRecorder.run(
                    selection: configuration.capture.audio,
                    durationSeconds: configuration.durationSeconds
                )
            } catch {
                media.audioBlockers = ["Core Audio input capture unavailable: \(error)"]
            }
        }
        if configuration.capture.video.mode == .on {
            do {
                media.video = try AVFoundationRawVideoRecorder.run(
                    selection: configuration.capture.video,
                    durationSeconds: configuration.durationSeconds
                )
            } catch {
                media.videoBlockers = ["AVFoundation video capture unavailable: \(error)"]
            }
        }
        return media
    }
}

enum RecordingLiveCaptureWait {
    @discardableResult
    static func wait(
        durationSeconds: Int,
        cancellation: DispatchSemaphore = DispatchSemaphore(value: 0)
    ) -> DispatchTimeoutResult {
        cancellation.wait(timeout: .now() + .seconds(max(0, durationSeconds)))
    }
}

#if canImport(CoreAudio)
enum CoreAudioRawInputRecorder {
    static func run(
        selection: RecordingAudioCaptureSelection,
        durationSeconds: Int
    ) throws -> RecordingCapturedAudio {
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

        let state = try CoreAudioRawInputState(
            framesPerBuffer: frames,
            channelCount: channelCount,
            inputChannels: selection.inputChannels,
            sampleFormat: selection.sampleFormat,
            durationSeconds: durationSeconds,
            sampleRateHertz: sampleRate
        )
        var ioProcID: AudioDeviceIOProcID?
        let deviceID = AudioObjectID(device.id)
        let retainedState = Unmanaged.passRetained(state)
        var status = AudioDeviceCreateIOProcID(
            deviceID,
            recordingAudioInputIOProc,
            retainedState.toOpaque(),
            &ioProcID
        )
        try throwRecordingAudioStatus(status, "create recording AudioDeviceIOProcID")
        defer {
            state.invalidateCallbacks()
            if let ioProcID {
                _ = AudioDeviceDestroyIOProcID(deviceID, ioProcID)
            }
            retainedState.release()
        }
        guard let ioProcID else {
            throw RecordingLiveCaptureError.audioDeviceNotRunnable
        }
        var didStartDevice = false
        defer {
            if didStartDevice {
                _ = AudioDeviceStop(deviceID, ioProcID)
            }
        }
        status = AudioDeviceStart(deviceID, ioProcID)
        try throwRecordingAudioStatus(status, "start recording AudioDeviceIOProc")
        didStartDevice = true
        RecordingLiveCaptureWait.wait(durationSeconds: durationSeconds)
        status = AudioDeviceStop(deviceID, ioProcID)
        didStartDevice = false
        try throwRecordingAudioStatus(status, "stop recording AudioDeviceIOProc")

        let audio = state.capturedAudio()
        guard !audio.data.isEmpty else {
            throw RecordingLiveCaptureError.audioCapturedNoBytes
        }
        return audio
    }
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

#if canImport(AVFoundation)
enum AVFoundationRawVideoRecorder {
    static func run(
        selection: RecordingVideoCaptureSelection,
        durationSeconds: Int
    ) throws -> RecordingCapturedVideo {
        let permission = resolveAVFoundationVideoPermission()
        guard permission == .authorized else {
            throw VideoCaptureProbeError.cameraNotAuthorized(permission)
        }
        let requested = selection.deviceID == "auto" ? nil : selection.deviceID
        let selected = try selectedAVFoundationDevice(
            from: currentAVCaptureVideoDevices(),
            requestedUniqueId: requested
        )
        guard let selected else {
            throw VideoCaptureProbeError.cameraNotFound(requested)
        }
        let collector = AVFoundationSampleBufferCollector(
            queueDepth: selection.queueDepth,
            streamID: selection.streamID,
            frameRate: videoFrameRate(from: selection.frameRate),
            captureRawFrames: true
        )
        let captureSession = try makeAVFoundationCaptureSession(
            device: selected,
            collector: collector,
            requestedFrameRate: selection.frameRate
        )
        var didStartSession = false
        defer {
            if didStartSession {
                captureSession.session.stopRunning()
            }
            captureSession.restoreDevice(logger: AVFoundationVideoCaptureRunner.logger)
        }
        captureSession.session.startRunning()
        didStartSession = true
        RecordingLiveCaptureWait.wait(durationSeconds: durationSeconds)
        captureSession.session.stopRunning()
        didStartSession = false
        guard let artifact = collector.rawVideoArtifact() else {
            throw VideoCaptureProbeError.captureUnavailable
        }
        return artifact
    }
}
#else
enum AVFoundationRawVideoRecorder {
    static func run(selection: RecordingVideoCaptureSelection, durationSeconds: Int) throws -> RecordingCapturedVideo {
        _ = selection
        _ = durationSeconds
        throw VideoCaptureProbeError.captureUnavailable
    }
}
#endif

public enum RecordingLiveCaptureError: Error, Equatable, Sendable {
    case coreAudioUnavailable
    case coreAudioStatus(OSStatus, String)
    case audioInputNotFound(String)
    case audioInputHasNoChannels(String)
    case audioConfigurationIncomplete
    case audioChannelOutOfRange
    case audioDeviceNotRunnable
    case audioCapturedNoBytes
    case audioBufferSizingOverflow
}

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
