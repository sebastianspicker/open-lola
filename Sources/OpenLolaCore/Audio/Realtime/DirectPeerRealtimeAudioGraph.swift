// Owns Core Audio graph state, aligned rings, IOProc identifiers, and atomic counters while extensions isolate callback-safe operations.
import CoreAudio
import COpenLolaAtomics
import Darwin
import Dispatch
import Foundation
import os

let directPeerRealtimeAudioBufferAlignment = max(16, MemoryLayout<Float>.alignment)

struct DirectPeerIOProcCleanupTarget {
    var role: String
    var deviceID: AudioObjectID
    var ioProcID: AudioDeviceIOProcID
}

/// Owns the capture and playout rings that connect direct-peer networking to the real-time audio callbacks.
public final class DirectPeerRealtimeAudioGraph: @unchecked Sendable {
    public let configuration: DirectPeerRealtimeAudioGraphConfiguration
    public let captureRing: DirectPeerAudioPayloadRing
    public let playoutRing: DirectPeerAudioPayloadRing

    var nextInputFrame = OpenLolaAtomicUInt64()
    var nextOutputFrame = OpenLolaAtomicUInt64()
    var inputDeviceID: AudioObjectID?
    var outputDeviceID: AudioObjectID?
    var inputIOProcID: AudioDeviceIOProcID?
    var outputIOProcID: AudioDeviceIOProcID?
    var originalInputSampleRate: Double?
    var originalOutputSampleRate: Double?
    var originalInputBufferFrameSize: UInt32?
    var originalOutputBufferFrameSize: UInt32?
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
    var latestCleanupResult = DirectPeerRealtimeAudioGraphCleanupResult()
    var inputScratch: UnsafeMutableRawPointer
    var outputScratch: UnsafeMutableRawPointer
    let hostTimeNumerator: UInt64
    let hostTimeDenominator: UInt64
    let lifecycleLock = NSLock()
    let rxBufferAdaptationLock = NSLock()
    let capturedPayloadSignal = DispatchSemaphore(value: 0)
    let captureReadinessSignal: DirectPeerCaptureReadinessSignal?
    var rxBufferSnapshot: RxBufferRuntimeSnapshot?
    var adaptiveRxBufferController: RxBufferAdaptiveController?
    #if DEBUG
    var stopDeviceForTesting: (AudioObjectID, AudioDeviceIOProcID) -> OSStatus = AudioDeviceStop
    var destroyIOProcForTesting: (AudioObjectID, AudioDeviceIOProcID) -> OSStatus = AudioDeviceDestroyIOProcID
    var setDoublePropertyForTesting: (
        AudioObjectID,
        AudioObjectPropertySelector,
        AudioObjectPropertyScope,
        Double
    ) throws -> Void = setDoubleProperty
    var setUInt32PropertyForTesting: (
        AudioObjectID,
        AudioObjectPropertySelector,
        AudioObjectPropertyScope,
        UInt32
    ) throws -> Void = setUInt32Property
    var hostTimeConversionForTesting: ((UInt64) -> UInt64?)?
    var callbackTimingTickForTesting: (() -> UInt64)?
    #endif

    public init(configuration: DirectPeerRealtimeAudioGraphConfiguration) throws {
        try configuration.validateRealtimeBufferInputs()
        self.configuration = configuration
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
        if let policy = configuration.rxBufferPolicy {
            self.rxBufferSnapshot = RxBufferRuntimeSnapshot(policy: policy)
            if policy.profile == .adaptive { self.adaptiveRxBufferController = try .runtimeController(policy: policy) }
        }
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
        _ = stopUnlocked()
        inputScratch.deallocate()
        outputScratch.deallocate()
    }

    @discardableResult
    public func stop() -> DirectPeerRealtimeAudioGraphCleanupResult {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return stopUnlocked()
    }

    public func lastCleanupResult() -> DirectPeerRealtimeAudioGraphCleanupResult {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return latestCleanupResult
    }

    /// Injects a synthetic capture payload only while the realtime IOProc is stopped.
    public func captureInjectedPayload(_ payload: Data, hostTimeNanoseconds: UInt64) -> SPSCAtomicRingResult {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard open_lola_atomic_u64_load(&ioProcRunning) == 0 else {
            recordCaptureResult(.invalid)
            return .invalid
        }
        let startFrame = reserveInputStartFrame()
        let result = payload.withUnsafeBytes { bytes in
            captureRing.push(
                startFrame: startFrame,
                hostTimeNanoseconds: hostTimeNanoseconds,
                sourceBytes: bytes
            )
        }
        recordCaptureResult(result)
        return result
    }

    public func withCapturedPayload<Result>(
        _ body: (RealtimeAudioFrameBlock, UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result? {
        let result = try captureRing.withPoppedPayload(body)
        if case .some = result {
            _ = capturedPayloadSignal.wait(timeout: .now())
        }
        return result
    }

    func waitForCapturedPayload(until deadline: DispatchTime) -> Bool {
        capturedPayloadSignal.wait(timeout: deadline) == .success
    }

    var captureReadinessDescriptor: Int32? {
        captureReadinessSignal?.readDescriptor
    }

    func consumeCapturedReadiness() {
        captureReadinessSignal?.drain()
    }

    func dropCapturedPayloadsKeepingNewest() -> Int {
        let dropped = captureRing.dropAllButNewest()
        for _ in 0..<dropped {
            _ = capturedPayloadSignal.wait(timeout: .now())
        }
        return dropped
    }

    func nextOutputFrameSnapshot() -> UInt64 {
        open_lola_atomic_u64_load(&nextOutputFrame)
    }

    public func queuePlayoutPayload(
        _ payload: Data,
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64
    ) -> SPSCAtomicRingResult {
        let playoutStartFrameResult = startFrame.addingReportingOverflow(UInt64(currentPlayoutTargetFrames()))
        guard !playoutStartFrameResult.overflow else {
            increment(&droppedOutputBlocks)
            observeAdaptiveRxBuffer(
                startFrame: startFrame,
                hostTimeNanoseconds: hostTimeNanoseconds,
                pressure: true
            )
            return .invalid
        }
        let playoutStartFrame = playoutStartFrameResult.partialValue
        let result = payload.withUnsafeBytes { bytes in
            playoutRing.push(
                startFrame: playoutStartFrame,
                hostTimeNanoseconds: hostTimeNanoseconds,
                sourceBytes: bytes
            )
        }
        if result == .full {
            increment(&droppedOutputBlocks)
        }
        observeAdaptiveRxBuffer(
            startFrame: startFrame,
            hostTimeNanoseconds: hostTimeNanoseconds,
            pressure: result != .stored
        )
        return result
    }

}
