// Owns Core Audio lifecycle policy and independently retained callback storage, keeping device cleanup off the realtime path.
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
    public let mode: DirectPeerRealtimeAudioGraphMode
    let callbackState: DirectPeerRealtimeAudioCallbackState
    public var captureRing: DirectPeerAudioPayloadRing { callbackState.captureRing }
    public var playoutRing: DirectPeerAudioPayloadRing { callbackState.playoutRing }
    var inputDeviceID: AudioObjectID?
    var outputDeviceID: AudioObjectID?
    var inputIOProcID: AudioDeviceIOProcID?
    var outputIOProcID: AudioDeviceIOProcID?
    var inputIOProcClientData: UnsafeMutableRawPointer?
    var outputIOProcClientData: UnsafeMutableRawPointer?
    var originalInputSampleRate: Double?
    var originalOutputSampleRate: Double?
    var originalInputBufferFrameSize: UInt32?
    var originalOutputBufferFrameSize: UInt32?
    var latestCleanupResult = DirectPeerRealtimeAudioGraphCleanupResult()
    let lifecycleLock = NSLock()
    let rxBufferAdaptationLock = NSLock()
    var rxBufferSnapshot: RxBufferRuntimeSnapshot?
    var adaptiveRxBufferController: RxBufferAdaptiveController?
    var rxInterarrivalJitter = RealtimeAudioInterarrivalJitter()
    #if DEBUG
    var createIOProcForTesting: (
        AudioObjectID, AudioDeviceIOProc, UnsafeMutableRawPointer?,
        UnsafeMutablePointer<AudioDeviceIOProcID?>
    ) -> OSStatus = AudioDeviceCreateIOProcID
    var startDeviceForTesting: (AudioObjectID, AudioDeviceIOProcID) -> OSStatus = AudioDeviceStart
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
    #endif

    public init(
        configuration: DirectPeerRealtimeAudioGraphConfiguration,
        mode: DirectPeerRealtimeAudioGraphMode = .fullDuplex
    ) throws {
        try configuration.validateRealtimeBufferInputs()
        self.configuration = configuration
        self.mode = mode
        self.callbackState = DirectPeerRealtimeAudioCallbackState(configuration: configuration)
        if let policy = configuration.rxBufferPolicy {
            self.rxBufferSnapshot = RxBufferRuntimeSnapshot(policy: policy)
            if policy.profile == .adaptive { self.adaptiveRxBufferController = try .runtimeController(policy: policy) }
        }
    }

    deinit {
        let cleanup = stopUnlocked()
        if inputIOProcClientData != nil || outputIOProcClientData != nil {
            // HAL still owns callback pointers. Their independent retained storage
            // must survive this graph; future calls see ioProcRunning == 0.
            os_log(.fault, "Audio callback storage retained after failed teardown: %{public}@",
                   directPeerRealtimeAudioCleanupFailureSummary(cleanup))
        }
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
        guard inputIOProcID == nil, outputIOProcID == nil,
              open_lola_atomic_u64_load(&callbackState.ioProcRunning) == 0,
              open_lola_atomic_u64_load(&callbackState.activeIOProcCallbacks) == 0 else {
            callbackState.recordCaptureResult(.invalid)
            return .invalid
        }
        let startFrame = callbackState.reserveInputStartFrame()
        let result = payload.withUnsafeBytes { bytes in
            captureRing.push(
                startFrame: startFrame,
                hostTimeNanoseconds: hostTimeNanoseconds,
                sourceBytes: bytes
            )
        }
        callbackState.recordCaptureResult(result)
        return result
    }

    public func withCapturedPayload<Result>(
        _ body: (RealtimeAudioFrameBlock, UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result? {
        let result = try captureRing.withPoppedPayload(body)
        if case .some = result {
            _ = callbackState.capturedPayloadSignal.wait(timeout: .now())
        }
        return result
    }

    package func waitForCapturedPayload(until deadline: DispatchTime) -> Bool {
        callbackState.capturedPayloadSignal.wait(timeout: deadline) == .success
    }

    package var captureReadinessDescriptor: Int32? {
        callbackState.captureReadinessSignal?.readDescriptor
    }

    package func consumeCapturedReadiness() {
        callbackState.captureReadinessSignal?.drain()
    }

    package func dropCapturedPayloadsKeepingNewest() -> Int {
        let dropped = captureRing.dropAllButNewest()
        for _ in 0..<dropped {
            _ = callbackState.capturedPayloadSignal.wait(timeout: .now())
        }
        return dropped
    }

    package func nextOutputFrameSnapshot() -> UInt64 {
        open_lola_atomic_u64_load(&callbackState.nextOutputFrame)
    }

    public func queuePlayoutPayload(
        _ payload: Data,
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64
    ) -> SPSCAtomicRingResult {
        let playoutStartFrameResult = startFrame.addingReportingOverflow(UInt64(currentPlayoutTargetFrames()))
        guard !playoutStartFrameResult.overflow else {
            callbackState.increment(&callbackState.droppedOutputBlocks)
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
            callbackState.increment(&callbackState.droppedOutputBlocks)
        }
        observeAdaptiveRxBuffer(
            startFrame: startFrame,
            hostTimeNanoseconds: hostTimeNanoseconds,
            pressure: result != .stored
        )
        return result
    }

}
