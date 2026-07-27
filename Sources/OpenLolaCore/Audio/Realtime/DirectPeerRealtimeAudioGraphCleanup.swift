// Stops IOProcs, waits for callbacks to drain, and restores device properties under bounded timeouts so teardown failures remain observable.
import CoreAudio
import COpenLolaAtomics
import Darwin
import Foundation

private let ioProcStableMicros: UInt64 = 10_000
private let ioProcTimeoutMicros: UInt64 = 100_000
private let ioProcPollMicros: useconds_t = 1_000

extension DirectPeerRealtimeAudioGraph {
    func waitForIOProcQuiescence() -> Bool {
        let start = DispatchTime.now().uptimeNanoseconds
        let timeoutNanoseconds = ioProcTimeoutMicros * 1_000
        while DispatchTime.now().uptimeNanoseconds - start <= timeoutNanoseconds {
            guard open_lola_atomic_u64_load(&activeIOProcCallbacks) == 0 else {
                usleep(ioProcPollMicros)
                continue
            }
            let callbackCount = open_lola_atomic_u64_load(&callbackInvocationBlocks)
            usleep(useconds_t(ioProcStableMicros))
            if open_lola_atomic_u64_load(&activeIOProcCallbacks) == 0,
               open_lola_atomic_u64_load(&callbackInvocationBlocks) == callbackCount {
                return true
            }
        }
        return false
    }

    func stopDevice(_ deviceID: AudioObjectID, _ ioProcID: AudioDeviceIOProcID) -> OSStatus {
        #if DEBUG
        stopDeviceForTesting(deviceID, ioProcID)
        #else
        AudioDeviceStop(deviceID, ioProcID)
        #endif
    }

    func destroyIOProc(_ deviceID: AudioObjectID, _ ioProcID: AudioDeviceIOProcID) -> OSStatus {
        #if DEBUG
        destroyIOProcForTesting(deviceID, ioProcID)
        #else
        AudioDeviceDestroyIOProcID(deviceID, ioProcID)
        #endif
    }

    func setDoublePropertyForGraph(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope,
        _ value: Double
    ) throws {
        #if DEBUG
        try setDoublePropertyForTesting(objectID, selector, scope, value)
        #else
        try setDoubleProperty(objectID, selector, scope, value)
        #endif
    }

    func setUInt32PropertyForGraph(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope,
        _ value: UInt32
    ) throws {
        #if DEBUG
        try setUInt32PropertyForTesting(objectID, selector, scope, value)
        #else
        try setUInt32Property(objectID, selector, scope, value)
        #endif
    }

    func recordCleanupStatus(
        _ status: OSStatus,
        operation: String,
        result: inout DirectPeerRealtimeAudioGraphCleanupResult
    ) {
        guard status != noErr else { return }
        result.failures.append(.init(operation: operation, status: status))
    }

    func recordCleanupRestore(
        operation: String,
        result: inout DirectPeerRealtimeAudioGraphCleanupResult,
        _ body: () throws -> Void
    ) {
        do {
            try body()
        } catch {
            result.failures.append(.init(
                operation: operation,
                status: cleanupStatus(from: error)
            ))
        }
    }

    func cleanupStatus(from error: Error) -> OSStatus? {
        if let error = error as? AudioLoopbackRunError,
           case .coreAudioStatus(let status, _) = error {
            return status
        }
        if let error = error as? DirectPeerAudioGraphError,
           case .coreAudioStatus(let status, _) = error {
            return status
        }
        return nil
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

    func stopUnlocked() -> DirectPeerRealtimeAudioGraphCleanupResult {
        var result = DirectPeerRealtimeAudioGraphCleanupResult()
        let ioProcsToDestroy = stopActiveIOProcs(result: &result)
        clearRunningFlagIfNeeded(hasStoppedIOProcs: !ioProcsToDestroy.isEmpty)
        destroyStoppedIOProcs(ioProcsToDestroy, result: &result)
        restoreDeviceSettings(result: &result)
        latestCleanupResult = result
        guard result.succeeded else {
            return result
        }
        clearStoppedGraphState()
        return result
    }

    func stopActiveIOProcs(
        result: inout DirectPeerRealtimeAudioGraphCleanupResult
    ) -> [DirectPeerIOProcCleanupTarget] {
        var ioProcsToDestroy: [DirectPeerIOProcCleanupTarget] = []
        if let inputDeviceID, let inputIOProcID {
            stopActiveIOProc(
                role: "input",
                deviceID: inputDeviceID,
                ioProcID: inputIOProcID,
                result: &result,
                targets: &ioProcsToDestroy
            )
        }
        if let outputDeviceID, let outputIOProcID {
            stopActiveIOProc(
                role: "output",
                deviceID: outputDeviceID,
                ioProcID: outputIOProcID,
                result: &result,
                targets: &ioProcsToDestroy
            )
        }
        return ioProcsToDestroy
    }

    func stopActiveIOProc(
        role: String,
        deviceID: AudioObjectID,
        ioProcID: AudioDeviceIOProcID,
        result: inout DirectPeerRealtimeAudioGraphCleanupResult,
        targets: inout [DirectPeerIOProcCleanupTarget]
    ) {
        let status = stopDevice(deviceID, ioProcID)
        recordCleanupStatus(status, operation: "stop \(role) AudioDeviceIOProc", result: &result)
        targets.append(.init(role: role, deviceID: deviceID, ioProcID: ioProcID))
    }

    func clearRunningFlagIfNeeded(hasStoppedIOProcs: Bool) {
        if hasStoppedIOProcs || open_lola_atomic_u64_load(&ioProcRunning) != 0 {
            open_lola_atomic_u64_store(&ioProcRunning, 0)
        }
    }

    func destroyStoppedIOProcs(
        _ targets: [DirectPeerIOProcCleanupTarget],
        result: inout DirectPeerRealtimeAudioGraphCleanupResult
    ) {
        guard !targets.isEmpty else { return }
        guard waitForIOProcQuiescence() else {
            recordQuiescenceFailures(for: targets, result: &result)
            return
        }
        for target in targets {
            destroyStoppedIOProc(target, result: &result)
        }
    }

    func destroyStoppedIOProc(
        _ target: DirectPeerIOProcCleanupTarget,
        result: inout DirectPeerRealtimeAudioGraphCleanupResult
    ) {
        let status = destroyIOProc(target.deviceID, target.ioProcID)
        recordCleanupStatus(
            status,
            operation: "destroy \(target.role) AudioDeviceIOProc",
            result: &result
        )
        guard status == noErr else { return }
        if target.role == "input" {
            self.inputIOProcID = nil
        } else {
            self.outputIOProcID = nil
        }
    }

    func recordQuiescenceFailures(
        for targets: [DirectPeerIOProcCleanupTarget],
        result: inout DirectPeerRealtimeAudioGraphCleanupResult
    ) {
        for target in targets {
            result.failures.append(.init(
                operation: "wait for \(target.role) AudioDeviceIOProc quiescence",
                status: nil
            ))
        }
    }

    func restoreDeviceSettings(result: inout DirectPeerRealtimeAudioGraphCleanupResult) {
        restoreInputDeviceSettings(result: &result)
        restoreOutputDeviceSettings(result: &result)
    }

    func restoreInputDeviceSettings(result: inout DirectPeerRealtimeAudioGraphCleanupResult) {
        if let inputDeviceID, let originalInputSampleRate {
            recordCleanupRestore(
                operation: "restore input sample rate",
                result: &result
            ) {
                try setDoublePropertyForGraph(
                    inputDeviceID,
                    kAudioDevicePropertyNominalSampleRate,
                    kAudioObjectPropertyScopeGlobal,
                    originalInputSampleRate
                )
            }
        }
        if let inputDeviceID, let originalInputBufferFrameSize {
            recordCleanupRestore(
                operation: "restore input buffer frame size",
                result: &result
            ) {
                try setUInt32PropertyForGraph(
                    inputDeviceID,
                    kAudioDevicePropertyBufferFrameSize,
                    kAudioObjectPropertyScopeGlobal,
                    originalInputBufferFrameSize
                )
            }
        }
    }

    func restoreOutputDeviceSettings(result: inout DirectPeerRealtimeAudioGraphCleanupResult) {
        if inputDeviceID != outputDeviceID, let outputDeviceID, let originalOutputSampleRate {
            recordCleanupRestore(
                operation: "restore output sample rate",
                result: &result
            ) {
                try setDoublePropertyForGraph(
                    outputDeviceID,
                    kAudioDevicePropertyNominalSampleRate,
                    kAudioObjectPropertyScopeGlobal,
                    originalOutputSampleRate
                )
            }
        }
        if inputDeviceID != outputDeviceID, let outputDeviceID, let originalOutputBufferFrameSize {
            recordCleanupRestore(
                operation: "restore output buffer frame size",
                result: &result
            ) {
                try setUInt32PropertyForGraph(
                    outputDeviceID,
                    kAudioDevicePropertyBufferFrameSize,
                    kAudioObjectPropertyScopeGlobal,
                    originalOutputBufferFrameSize
                )
            }
        }
    }

    func clearStoppedGraphState() {
        open_lola_atomic_u64_store(&ioProcRunning, 0)
        self.inputIOProcID = nil
        self.outputIOProcID = nil
        self.inputDeviceID = nil
        self.outputDeviceID = nil
        self.originalInputSampleRate = nil
        self.originalOutputSampleRate = nil
        self.originalInputBufferFrameSize = nil
        self.originalOutputBufferFrameSize = nil
    }

#if DEBUG
// swiftlint:disable:next function_parameter_count
func setCleanupStateForTesting(
        inputDeviceID: AudioObjectID?,
        inputIOProcID: AudioDeviceIOProcID?,
        outputDeviceID: AudioObjectID?,
        outputIOProcID: AudioDeviceIOProcID?,
        originalInputSampleRate: Double?,
        originalInputBufferFrameSize: UInt32?,
        originalOutputSampleRate: Double?,
        originalOutputBufferFrameSize: UInt32?
    ) {
        self.inputDeviceID = inputDeviceID
        self.inputIOProcID = inputIOProcID
        self.outputDeviceID = outputDeviceID
        self.outputIOProcID = outputIOProcID
        self.originalInputSampleRate = originalInputSampleRate
        self.originalInputBufferFrameSize = originalInputBufferFrameSize
        self.originalOutputSampleRate = originalOutputSampleRate
        self.originalOutputBufferFrameSize = originalOutputBufferFrameSize
    }

    struct DirectPeerCleanupOperationOverrides {
    var stop: (AudioObjectID, AudioDeviceIOProcID) -> OSStatus = { _, _ in noErr }
    var destroy: (AudioObjectID, AudioDeviceIOProcID) -> OSStatus = { _, _ in noErr }
    var setDouble: (
        AudioObjectID,
        AudioObjectPropertySelector,
        AudioObjectPropertyScope,
        Double
    ) throws -> Void = { _, _, _, _ in }
    var setUInt32: (
        AudioObjectID,
        AudioObjectPropertySelector,
        AudioObjectPropertyScope,
        UInt32
    ) throws -> Void = { _, _, _, _ in }
}

func setCleanupOperationOverridesForTesting(_ overrides: DirectPeerCleanupOperationOverrides = .init()) {
    stopDeviceForTesting = overrides.stop
    destroyIOProcForTesting = overrides.destroy
    setDoublePropertyForTesting = overrides.setDouble
    setUInt32PropertyForTesting = overrides.setUInt32
}

    func setHostTimeConversionForTesting(_ conversion: ((UInt64) -> UInt64?)?) {
        hostTimeConversionForTesting = conversion
    }

    func setCallbackTimingTickForTesting(_ tick: (() -> UInt64)?) {
        callbackTimingTickForTesting = tick
    }

    func lifecycleLockForTesting() -> NSLock {
        lifecycleLock
    }
    #endif

}
