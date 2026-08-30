// Transfers callback audio to capture and playout rings, zero-fills underruns, and records atomic counters in the realtime I/O path.
import CoreAudio
import COpenLolaAtomics
import Darwin
import Foundation

enum DirectPeerInputCopyResult: Equatable {
    case copied
    case invalidSourceChannelCount
    case destinationChannelOutOfRange
    case inputChannelOutOfRange
    case inputBufferUnavailable
    case invalidByteOffset
    case inputBufferTooSmall
    case destinationBufferTooSmall
}

struct DirectPeerReadOnlyAudioBufferLocation {
    var buffer: AudioBuffer
    var channelIndex: Int
    var channelCount: Int
}

struct DirectPeerMutableAudioBufferLocation {
    var data: UnsafeMutableRawPointer
    var byteCount: Int
    var channelIndex: Int
    var channelCount: Int
}

extension DirectPeerRealtimeAudioGraph {
    func captureInputForTesting(input: UnsafePointer<AudioBufferList>, hostTimeNanoseconds: UInt64) {
        copyInputToCaptureRing(input: input, hostTimeNanoseconds: hostTimeNanoseconds)
    }

    func renderPlayoutForTesting(output: UnsafeMutablePointer<AudioBufferList>) {
        renderPlayout(output: output)
    }

    #if DEBUG
    func setIOProcRunningForTesting(_ running: Bool) {
        open_lola_atomic_u64_store(&ioProcRunning, running ? 1 : 0)
    }
    #endif

    func processIO(
        hostTimeNanoseconds: UInt64,
        input: UnsafePointer<AudioBufferList>,
        output: UnsafeMutablePointer<AudioBufferList>
    ) {
        let start = callbackTimingTick()
        copyInputToCaptureRing(input: input, hostTimeNanoseconds: hostTimeNanoseconds)
        renderPlayout(output: output)
        recordCallbackDuration(startTicks: start)
    }

    func processInputIO(
        hostTimeNanoseconds: UInt64,
        input: UnsafePointer<AudioBufferList>
    ) {
        let start = callbackTimingTick()
        copyInputToCaptureRing(input: input, hostTimeNanoseconds: hostTimeNanoseconds)
        recordCallbackDuration(startTicks: start)
    }

    func processOutputIO(output: UnsafeMutablePointer<AudioBufferList>) {
        let start = callbackTimingTick()
        renderPlayout(output: output)
        recordCallbackDuration(startTicks: start)
    }

    func nanoseconds(fromHostTime hostTime: UInt64) -> UInt64? {
        #if DEBUG
        if let hostTimeConversionForTesting {
            return hostTimeConversionForTesting(hostTime)
        }
        #endif
        precondition(hostTimeDenominator > 0, "mach timebase denominator must be positive")
        return nanosecondsFromHostTime(hostTime, numerator: hostTimeNumerator, denominator: hostTimeDenominator)
    }

    func recordHostTimeConversionFailure() {
        increment(&hostTimeConversionFailures)
    }

    func copyInputToCaptureRing(
        input: UnsafePointer<AudioBufferList>,
        hostTimeNanoseconds: UInt64
    ) {
        let buffers = ReadOnlyAudioBufferListPointer(input)
        guard !buffers.isEmpty else {
            return
        }
        let copyResult = copyMappedInput(from: buffers)
        guard copyResult == .copied else {
            increment(&droppedInputBlocks)
            return
        }
        let startFrame = reserveInputStartFrame()
        let result = captureRing.push(
            startFrame: startFrame,
            hostTimeNanoseconds: hostTimeNanoseconds,
            sourceBytes: UnsafeRawBufferPointer(start: inputScratch, count: configuration.payloadByteCount)
        )
        recordCaptureResult(result)
    }

    func renderPlayout(output: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(output)
        guard !buffers.isEmpty else {
            return
        }
        let dueFrame = open_lola_atomic_u64_load(&nextOutputFrame)
        let stalePayloads = playoutRing.dropPayloads(before: dueFrame)
        for _ in 0..<stalePayloads {
            increment(&droppedOutputBlocks)
        }
        let copied = playoutRing.copyPayload(
            startFrame: dueFrame,
            to: outputScratch,
            byteCount: configuration.payloadByteCount
        )
        clearOutput(buffers)
        if copied {
            if !copyMappedOutput(to: buffers) {
                increment(&droppedOutputBlocks)
            }
        } else {
            increment(&outputUnderrunBlocks)
        }
        increment(&outputBlocks)
        reserveOutputStartFrame()
    }

    func recordCaptureResult(_ result: SPSCAtomicRingResult) {
        if result == .stored {
            increment(&capturedInputBlocks)
            capturedPayloadSignal.signal()
            captureReadinessSignal?.signal()
        } else if result == .invalid {
            increment(&droppedInputBlocks)
        } else if result == .full {
            increment(&droppedInputBlocks)
            increment(&inputOverrunBlocks)
            increment(&callbackOverrunBlocks)
        }
    }

    func callbackTimingTick() -> UInt64 {
        #if DEBUG
        if let callbackTimingTickForTesting {
            return callbackTimingTickForTesting()
        }
        #endif
        return mach_absolute_time()
    }

    func recordCallbackDuration(startTicks: UInt64) {
        let elapsedMicroseconds = callbackElapsedMicroseconds(
            startTicks: startTicks,
            endTicks: callbackTimingTick()
        )
        increment(&callbackInvocationBlocks)
        observeMax(&callbackMaxMicroseconds, elapsedMicroseconds)
        if elapsedMicroseconds > callbackPeriodMicroseconds() {
            increment(&callbackDeadlineMisses)
        }
    }

    func callbackElapsedMicroseconds(startTicks: UInt64, endTicks: UInt64) -> UInt64 {
        guard endTicks >= startTicks else {
            return 0
        }
        let elapsedTicks = endTicks - startTicks
        let (elapsedNanoseconds, overflow) = elapsedTicks.multipliedReportingOverflow(by: hostTimeNumerator)
        guard !overflow else {
            return UInt64.max
        }
        return (elapsedNanoseconds / hostTimeDenominator) / 1_000
    }

    func callbackPeriodMicroseconds() -> UInt64 {
        max(1, UInt64(configuration.framesPerBuffer) * 1_000_000 / UInt64(configuration.sampleRateHertz))
    }

    func reserveInputStartFrame() -> UInt64 {
        open_lola_atomic_u64_fetch_add(&nextInputFrame, UInt64(configuration.framesPerBuffer))
    }

    func reserveOutputStartFrame() {
        _ = open_lola_atomic_u64_fetch_add(&nextOutputFrame, UInt64(configuration.framesPerBuffer))
    }

    func increment(_ counter: inout OpenLolaAtomicUInt64) {
        // Only the side effect matters for monotonic counters; the previous value is intentionally unused.
        _ = open_lola_atomic_u64_fetch_add(&counter, 1)
    }

    func observeMax(_ counter: inout OpenLolaAtomicUInt64, _ value: UInt64) {
        var current = open_lola_atomic_u64_load(&counter)
        while value > current {
            var expected = current
            if open_lola_atomic_u64_compare_exchange(&counter, &expected, value) {
                return
            }
            current = expected
        }
    }
}
