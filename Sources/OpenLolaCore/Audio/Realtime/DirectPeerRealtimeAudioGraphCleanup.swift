import CoreAudio
import COpenLolaAtomics
import Darwin
import Foundation

private let directPeerIOProcQuiescenceStableMicroseconds: UInt64 = 10_000
private let directPeerIOProcQuiescenceTimeoutMicroseconds: UInt64 = 100_000
private let directPeerIOProcQuiescencePollMicroseconds: useconds_t = 1_000

extension DirectPeerRealtimeAudioGraph {
    func waitForIOProcQuiescence() -> Bool {
        let start = DispatchTime.now().uptimeNanoseconds
        let timeoutNanoseconds = directPeerIOProcQuiescenceTimeoutMicroseconds * 1_000
        while DispatchTime.now().uptimeNanoseconds - start <= timeoutNanoseconds {
            guard open_lola_atomic_u64_load(&activeIOProcCallbacks) == 0 else {
                usleep(directPeerIOProcQuiescencePollMicroseconds)
                continue
            }
            let callbackCount = open_lola_atomic_u64_load(&callbackInvocationBlocks)
            usleep(useconds_t(directPeerIOProcQuiescenceStableMicroseconds))
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
}
