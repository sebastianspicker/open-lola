// Implements AudioLoopbackIOProc audio-path behavior, isolating device and sample handling from higher-level routing.
import COpenLolaAtomics
import CoreAudio
import Darwin
import Foundation

final class AudioLoopbackIOProcState {
    private static let maximumRecordedCallbackIntervals = 100_000
    private static let microsecondsPerSecond = 1_000_000.0

    private let intervalStorage: UnsafeMutablePointer<Double>
    private let intervals: UnsafeMutableBufferPointer<Double>
    private let timebaseNumerator: UInt64
    private let timebaseDenominator: UInt64
    private let expectedIntervalMicroseconds: Double
    private var lastHostTimeNanoseconds: UInt64 = 0
    private var intervalCount = 0
    private var missedDeadlines = 0
    private var underruns = 0
    private var overruns = 0
    private var droppedIntervalSamples = 0
    private var hostTimeConversionFailures = 0
    private var stopped = false
    private var nextFrame = OpenLolaAtomicUInt64()
    private var handoff: RealtimeAudioPacketHandoff
    private let framesPerBuffer: Int

    init(configuration: AudioLoopbackRunConfiguration) throws {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        self.timebaseNumerator = UInt64(info.numer)
        self.timebaseDenominator = UInt64(info.denom)
        self.expectedIntervalMicroseconds = (
            Double(configuration.framesPerBuffer) / Double(configuration.sampleRateHertz)
        ) * Self.microsecondsPerSecond
        self.framesPerBuffer = configuration.framesPerBuffer
        let expectedCallbackProduct = configuration.durationSeconds.multipliedReportingOverflow(
            by: configuration.sampleRateHertz
        )
        let uncappedExpectedCallbacks = expectedCallbackProduct.overflow
            ? Self.maximumRecordedCallbackIntervals
            : max(1, expectedCallbackProduct.partialValue / configuration.framesPerBuffer)
        let recordedCallbackCapacity = min(
            uncappedExpectedCallbacks,
            Self.maximumRecordedCallbackIntervals
        )
        let intervalCapacity = recordedCallbackCapacity + 16
        guard let rawIntervals = calloc(intervalCapacity, MemoryLayout<Double>.stride) else {
            throw AudioLoopbackRunError.callbackIntervalBufferAllocationFailed(intervalCapacity)
        }
        self.intervalStorage = rawIntervals.assumingMemoryBound(to: Double.self)
        self.intervals = UnsafeMutableBufferPointer(start: intervalStorage, count: intervalCapacity)
        self.handoff = try RealtimeAudioPacketHandoff(
            configuration: try audioLoopbackRealtimeConfiguration(for: configuration)
        )
        open_lola_atomic_u64_init(&nextFrame, 0)
    }

    deinit {
        free(UnsafeMutableRawPointer(intervalStorage))
    }

    func record(hostTime: UInt64, input: UnsafePointer<AudioBufferList>) {
        guard let hostTimeNanoseconds = audioLoopbackHostTimeNanoseconds(
            hostTime: hostTime,
            timebaseNumerator: timebaseNumerator,
            timebaseDenominator: timebaseDenominator
        ) else {
            hostTimeConversionFailures += 1
            return
        }
        let startFrame = open_lola_atomic_u64_fetch_add(&nextFrame, UInt64(framesPerBuffer))
        let captureResult = handoff.captureAudioBufferListCallback(
            startFrame: startFrame,
            hostTimeNanoseconds: hostTimeNanoseconds,
            input: input
        )
        if captureResult == .droppedFull {
            overruns += 1
        }
        let renderResult = handoff.renderCallback()
        if case .silence = renderResult {
            underruns += 1
        }

        recordInterval(hostTimeNanoseconds: hostTimeNanoseconds)
    }

    private func recordInterval(hostTimeNanoseconds: UInt64) {
        guard lastHostTimeNanoseconds > 0 else {
            lastHostTimeNanoseconds = hostTimeNanoseconds
            return
        }

        guard hostTimeNanoseconds > lastHostTimeNanoseconds else {
            droppedIntervalSamples += 1
            return
        }
        let deltaNanoseconds = hostTimeNanoseconds - lastHostTimeNanoseconds
        lastHostTimeNanoseconds = hostTimeNanoseconds
        let deltaMicroseconds = Double(deltaNanoseconds) / 1_000
        if intervalCount < intervals.count {
            intervals[intervalCount] = deltaMicroseconds
            intervalCount += 1
        } else {
            droppedIntervalSamples += 1
        }
        if deltaMicroseconds > expectedIntervalMicroseconds * 1.5 {
            missedDeadlines += 1
        }
    }

    func callbackMetrics() -> EndpointCallbackMetrics {
        precondition(stopped, "AudioLoopbackIOProcState metrics must be read after AudioDeviceStop")
        var values = Array(intervals.prefix(intervalCount))
        values.sort()
        return EndpointCallbackMetrics(latency: .init(p50Microseconds: percentile(values, 0.50), p95Microseconds: percentile(values, 0.95), p99Microseconds: percentile(values, 0.99), maxMicroseconds: values.last ?? 0), events: .init(missedDeadlines: missedDeadlines, underruns: underruns, overruns: overruns), sampling: .init(recordedIntervalSamples: intervalCount, droppedIntervalSamples: droppedIntervalSamples, hostTimeConversionFailures: hostTimeConversionFailures))
    }

    func handoffMetrics() -> RealtimeAudioHandoffMetrics {
        precondition(stopped, "AudioLoopbackIOProcState handoff metrics must be read after AudioDeviceStop")
        var metrics = handoff.metrics
        metrics.shutdownCompleted = true
        return metrics
    }

    func markStopped() {
        stopped = true
    }
}

func audioLoopbackHostTimeNanoseconds(
    hostTime: UInt64,
    timebaseNumerator: UInt64,
    timebaseDenominator: UInt64
) -> UInt64? {
    guard timebaseDenominator > 0 else {
        return nil
    }
    let (scaledHostTime, overflow) = hostTime.multipliedReportingOverflow(
        by: timebaseNumerator
    )
    guard !overflow else {
        return nil
    }
    return scaledHostTime / timebaseDenominator
}

func audioLoopbackRealtimeConfiguration(
    for configuration: AudioLoopbackRunConfiguration
) throws -> RealtimeAudioEngineConfiguration {
    RealtimeAudioEngineConfiguration(
            devices: .init(inputDeviceUID: configuration.inputUID, outputDeviceUID: configuration.outputUID),
            format: .init(sampleRateHertz: configuration.sampleRateHertz, framesPerBuffer: configuration.framesPerBuffer, channelCount: configuration.channelCount, packetFormat: configuration.sampleFormat),
            channelMaps: .init(input: configuration.inputChannelMap, output: configuration.outputChannelMap),
            buffering: .init(playoutTargetFrames: configuration.framesPerBuffer, preallocatedBlockCount: configuration.preallocatedBlockCount, rxBufferPolicy: try configuration.rxBufferProfile.policy(
    framesPerPacket: configuration.framesPerBuffer,
    sampleRateHertz: configuration.sampleRateHertz
    ))
        )
}

// swiftlint:disable:next function_parameter_count
func audioLoopbackIOProc(
    _: AudioObjectID,
    _ inNow: UnsafePointer<AudioTimeStamp>,
    _ inInputData: UnsafePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _ outOutputData: UnsafeMutablePointer<AudioBufferList>,
    _: UnsafePointer<AudioTimeStamp>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    if let inClientData {
        let state = Unmanaged<AudioLoopbackIOProcState>
            .fromOpaque(inClientData)
            .takeUnretainedValue()
        state.record(hostTime: inNow.pointee.mHostTime, input: inInputData)
    }
    return copyInputToOutput(input: inInputData, output: outOutputData)
        ? noErr
        : kAudioHardwareBadPropertySizeError
}

private func copyInputToOutput(
    input: UnsafePointer<AudioBufferList>,
    output: UnsafeMutablePointer<AudioBufferList>
) -> Bool {
    let inputBuffers = UnsafeMutableAudioBufferListPointer(
        UnsafeMutablePointer(mutating: input)
    )
    let outputBuffers = UnsafeMutableAudioBufferListPointer(output)
    guard inputBuffers.count == outputBuffers.count else {
        zeroOutputBuffers(outputBuffers)
        return false
    }

    for index in 0..<outputBuffers.count {
        guard let inputData = inputBuffers[index].mData,
              let outputData = outputBuffers[index].mData else {
            if let outputData = outputBuffers[index].mData {
                memset(outputData, 0, Int(outputBuffers[index].mDataByteSize))
            }
            continue
        }
        guard inputBuffers[index].mDataByteSize == outputBuffers[index].mDataByteSize else {
            memset(outputData, 0, Int(outputBuffers[index].mDataByteSize))
            return false
        }
        memcpy(
            outputData,
            inputData,
            Int(outputBuffers[index].mDataByteSize)
        )
    }
    return true
}

private func zeroOutputBuffers(_ outputBuffers: UnsafeMutableAudioBufferListPointer) {
    for index in 0..<outputBuffers.count {
        if let outputData = outputBuffers[index].mData {
            memset(outputData, 0, Int(outputBuffers[index].mDataByteSize))
        }
    }
}
