// Owns every value reachable from an IOProc independently of the session graph.
import CoreAudio
import COpenLolaAtomics
import Darwin
import Dispatch
import Foundation

/// HAL registrations retain this storage, never the graph or its lifecycle lock.
/// A failed unregister keeps storage alive for late callbacks until cleanup retries.
final class DirectPeerRealtimeAudioCallbackState: @unchecked Sendable {
    let configuration: DirectPeerRealtimeAudioGraphConfiguration
    let captureRing: DirectPeerAudioPayloadRing
    let playoutRing: DirectPeerAudioPayloadRing
    let inputChannelMapIsIdentity: Bool
    let outputChannelMapIsIdentity: Bool

    var nextInputFrame = OpenLolaAtomicUInt64()
    var nextOutputFrame = OpenLolaAtomicUInt64()
    var capturedInputBlocks = OpenLolaAtomicUInt64()
    var droppedInputBlocks = OpenLolaAtomicUInt64()
    var inputOverrunBlocks = OpenLolaAtomicUInt64()
    var outputBlocks = OpenLolaAtomicUInt64()
    var droppedOutputBlocks = OpenLolaAtomicUInt64()
    var outputUnderrunBlocks = OpenLolaAtomicUInt64()
    var callbackInvocationBlocks = OpenLolaAtomicUInt64()
    var callbackMaxMicroseconds = OpenLolaAtomicUInt64()
    var callbackDeadlineMisses = OpenLolaAtomicUInt64()
    var callbackOverrunBlocks = OpenLolaAtomicUInt64()
    var hostTimeConversionFailures = OpenLolaAtomicUInt64()
    var ioProcRunning = OpenLolaAtomicUInt64()
    var activeIOProcCallbacks = OpenLolaAtomicUInt64()
    var inputScratch: UnsafeMutableRawPointer
    var outputScratch: UnsafeMutableRawPointer
    let hostTimeNumerator: UInt64
    let hostTimeDenominator: UInt64
    let capturedPayloadSignal = DispatchSemaphore(value: 0)
    let captureReadinessSignal: DirectPeerCaptureReadinessSignal?
    #if DEBUG
    var hostTimeConversionForTesting: ((UInt64) -> UInt64?)?
    var callbackTimingTickForTesting: (() -> UInt64)?
    #endif

    init(configuration: DirectPeerRealtimeAudioGraphConfiguration) {
        self.configuration = configuration
        self.inputChannelMapIsIdentity = configuration.inputChannelMap.count == configuration.channelCount
            && configuration.inputChannelMap.enumerated().allSatisfy { $0.offset == $0.element }
        self.outputChannelMapIsIdentity = configuration.outputChannelMap.count == configuration.channelCount
            && configuration.outputChannelMap.enumerated().allSatisfy { $0.offset == $0.element }
        self.captureReadinessSignal = configuration.rxBufferPolicy?.profile == .direct
            ? DirectPeerCaptureReadinessSignal()
            : nil
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        self.hostTimeNumerator = UInt64(timebase.numer)
        self.hostTimeDenominator = UInt64(timebase.denom)
        precondition(self.hostTimeDenominator > 0, "mach timebase denominator must be positive")
        self.captureRing = DirectPeerAudioPayloadRing(
            capacity: configuration.ringCapacityBlocks,
            payloadByteCount: configuration.payloadByteCount,
            frameCount: configuration.framesPerBuffer
        )
        self.playoutRing = DirectPeerAudioPayloadRing(
            capacity: configuration.ringCapacityBlocks,
            payloadByteCount: configuration.payloadByteCount,
            frameCount: configuration.framesPerBuffer
        )
        self.inputScratch = UnsafeMutableRawPointer.allocate(
            byteCount: configuration.payloadByteCount,
            alignment: directPeerRealtimeAudioBufferAlignment
        )
        self.outputScratch = UnsafeMutableRawPointer.allocate(
            byteCount: configuration.payloadByteCount,
            alignment: directPeerRealtimeAudioBufferAlignment
        )
        initializeRealtimeStorage(payloadByteCount: configuration.payloadByteCount)
    }

    private func initializeRealtimeStorage(payloadByteCount: Int) {
        memset(inputScratch, 0, payloadByteCount)
        memset(outputScratch, 0, payloadByteCount)
        open_lola_atomic_u64_init(&nextInputFrame, 0)
        open_lola_atomic_u64_init(&nextOutputFrame, 0)
        open_lola_atomic_u64_init(&capturedInputBlocks, 0)
        open_lola_atomic_u64_init(&droppedInputBlocks, 0)
        open_lola_atomic_u64_init(&inputOverrunBlocks, 0)
        open_lola_atomic_u64_init(&outputBlocks, 0)
        open_lola_atomic_u64_init(&droppedOutputBlocks, 0)
        open_lola_atomic_u64_init(&outputUnderrunBlocks, 0)
        open_lola_atomic_u64_init(&callbackInvocationBlocks, 0)
        open_lola_atomic_u64_init(&callbackMaxMicroseconds, 0)
        open_lola_atomic_u64_init(&callbackDeadlineMisses, 0)
        open_lola_atomic_u64_init(&callbackOverrunBlocks, 0)
        open_lola_atomic_u64_init(&hostTimeConversionFailures, 0)
        open_lola_atomic_u64_init(&ioProcRunning, 0)
        open_lola_atomic_u64_init(&activeIOProcCallbacks, 0)
    }

    deinit {
        inputScratch.deallocate()
        outputScratch.deallocate()
    }

    func beginIOProcCallback() -> Bool {
        open_lola_atomic_u64_fetch_add(&activeIOProcCallbacks, 1)
        guard open_lola_atomic_u64_load(&ioProcRunning) != 0 else {
            endIOProcCallback()
            return false
        }
        return true
    }

    func endIOProcCallback() {
        open_lola_atomic_u64_fetch_add(&activeIOProcCallbacks, UInt64.max)
    }
}
