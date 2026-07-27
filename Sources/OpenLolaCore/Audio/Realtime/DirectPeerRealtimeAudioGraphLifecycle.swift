// Preflights devices, configures sample rate and frame size, and starts IOProcs while preserving the state needed for restoration.
import CoreAudio
import COpenLolaAtomics
import Foundation
import os

extension DirectPeerRealtimeAudioGraph {
    public static func preflight(
        configuration: DirectPeerRealtimeAudioGraphConfiguration,
        inventory: CoreAudioInventoryReport
    ) throws -> DirectPeerRealtimeAudioGraphPreflight {
        let preflight = DirectPeerRealtimeAudioGraphPreflight.evaluate(
            configuration: configuration,
            inventory: inventory
        )
        guard let device = preflight.device else {
            throw DirectPeerAudioGraphError.missingDeviceUID(configuration.inputDeviceUID)
        }
        guard let outputDevice = preflight.outputDevice else {
            throw DirectPeerAudioGraphError.missingDeviceUID(configuration.outputDeviceUID)
        }
        guard preflight.fullDuplexSupported else {
            throw DirectPeerAudioGraphError.deviceNotFullDuplex(
                configuration.inputDeviceUID == configuration.outputDeviceUID ? device.uid : outputDevice.uid
            )
        }
        guard preflight.sampleRateSupported else {
            throw DirectPeerAudioGraphError.unsupportedSampleRate(
                uid: device.uid,
                sampleRateHertz: configuration.sampleRateHertz
            )
        }
        guard preflight.frameSizeSupported else {
            throw DirectPeerAudioGraphError.unsupportedFrameSize(
                uid: device.uid,
                framesPerBuffer: configuration.framesPerBuffer
            )
        }
        try validateChannelMap(
            configuration.inputChannelMap,
            scope: .input,
            available: device.inputChannelCount,
            expectedCount: configuration.channelCount
        )
        try validateChannelMap(
            configuration.outputChannelMap,
            scope: .output,
            available: outputDevice.outputChannelCount,
            expectedCount: configuration.channelCount
        )
        return preflight
    }

    public func start(deviceID: AudioObjectID) throws {
        try start(inputDeviceID: deviceID, outputDeviceID: deviceID)
    }

    public func start(inputDeviceID: AudioObjectID, outputDeviceID: AudioObjectID) throws {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard inputIOProcID == nil,
              outputIOProcID == nil,
              open_lola_atomic_u64_load(&ioProcRunning) == 0 else {
            throw DirectPeerAudioGraphError.graphAlreadyStarted
        }
        self.inputDeviceID = inputDeviceID
        self.outputDeviceID = outputDeviceID
        captureOriginalDeviceState(inputDeviceID: inputDeviceID, outputDeviceID: outputDeviceID)
        do {
            try configureDevice(inputDeviceID)
            if inputDeviceID != outputDeviceID {
                try configureDevice(outputDeviceID)
            }
            open_lola_atomic_u64_store(&activeIOProcCallbacks, 0)
            open_lola_atomic_u64_store(&ioProcRunning, 1)
            if inputDeviceID == outputDeviceID {
                inputIOProcID = try makeAndStartIOProc(
                    deviceID: inputDeviceID,
                    ioProc: directPeerRealtimeAudioIOProc
                )
            } else {
                inputIOProcID = try makeAndStartIOProc(
                    deviceID: inputDeviceID,
                    ioProc: directPeerRealtimeAudioInputIOProc
                )
                outputIOProcID = try makeAndStartIOProc(
                    deviceID: outputDeviceID,
                    ioProc: directPeerRealtimeAudioOutputIOProc
                )
            }
        } catch {
            let cleanupResult = stopUnlocked()
            if !cleanupResult.succeeded {
                os_log(
                    .fault,
                    "Audio graph cleanup during start failure also failed: %{public}@",
                    directPeerRealtimeAudioCleanupFailureSummary(cleanupResult)
                )
            }
            throw error
        }
    }

    func captureOriginalDeviceState(inputDeviceID: AudioObjectID, outputDeviceID: AudioObjectID) {
        originalInputSampleRate = doubleProperty(
            inputDeviceID,
            kAudioDevicePropertyNominalSampleRate,
            kAudioObjectPropertyScopeGlobal
        )
        originalInputBufferFrameSize = uint32Property(
            inputDeviceID,
            kAudioDevicePropertyBufferFrameSize,
            kAudioObjectPropertyScopeGlobal
        )
        originalOutputSampleRate = inputDeviceID == outputDeviceID
            ? originalInputSampleRate
            : doubleProperty(
                outputDeviceID,
                kAudioDevicePropertyNominalSampleRate,
                kAudioObjectPropertyScopeGlobal
            )
        originalOutputBufferFrameSize = inputDeviceID == outputDeviceID
            ? originalInputBufferFrameSize
            : uint32Property(
                outputDeviceID,
                kAudioDevicePropertyBufferFrameSize,
                kAudioObjectPropertyScopeGlobal
            )
    }

    public func runtimeCounters() -> DirectPeerRealtimeAudioGraphRuntimeCounters {
        DirectPeerRealtimeAudioGraphRuntimeCounters(
            capturedInputBlocks: Int(open_lola_atomic_u64_load(&capturedInputBlocks)),
            droppedInputBlocks: Int(open_lola_atomic_u64_load(&droppedInputBlocks)),
            inputOverrunBlocks: Int(open_lola_atomic_u64_load(&inputOverrunBlocks)),
            outputBlocks: Int(open_lola_atomic_u64_load(&outputBlocks)),
            droppedOutputBlocks: Int(open_lola_atomic_u64_load(&droppedOutputBlocks)),
            outputUnderrunBlocks: Int(open_lola_atomic_u64_load(&outputUnderrunBlocks)),
            callbackInvocationBlocks: Int(open_lola_atomic_u64_load(&callbackInvocationBlocks)),
            callbackMaxMicroseconds: Int(open_lola_atomic_u64_load(&callbackMaxMicroseconds)),
            callbackDeadlineMisses: Int(open_lola_atomic_u64_load(&callbackDeadlineMisses)),
            callbackOverrunBlocks: Int(open_lola_atomic_u64_load(&callbackOverrunBlocks)),
            hostTimeConversionFailures: Int(open_lola_atomic_u64_load(&hostTimeConversionFailures))
        )
    }

    func configureDevice(_ deviceID: AudioObjectID) throws {
        try setDoubleProperty(
            deviceID,
            kAudioDevicePropertyNominalSampleRate,
            kAudioObjectPropertyScopeGlobal,
            Double(configuration.sampleRateHertz)
        )
        try setUInt32Property(
            deviceID,
            kAudioDevicePropertyBufferFrameSize,
            kAudioObjectPropertyScopeGlobal,
            UInt32(configuration.framesPerBuffer)
        )
    }

    func makeAndStartIOProc(deviceID: AudioObjectID, ioProc: AudioDeviceIOProc) throws -> AudioDeviceIOProcID {
        let clientData = Unmanaged.passUnretained(self).toOpaque()
        var createdIOProcID: AudioDeviceIOProcID?
        var status = AudioDeviceCreateIOProcID(
            deviceID,
            ioProc,
            clientData,
            &createdIOProcID
        )
        try throwDirectPeerAudioStatusIfNeeded(status, "create AudioDeviceIOProcID")
        guard let createdIOProcID else { throw DirectPeerAudioGraphError.graphNotStarted }
        status = AudioDeviceStart(deviceID, createdIOProcID)
        do {
            try throwDirectPeerAudioStatusIfNeeded(status, "start AudioDeviceIOProc")
        } catch {
            let cleanupStatus = destroyIOProc(deviceID, createdIOProcID)
            if cleanupStatus != noErr {
                os_log(
                    .error,
                    "AudioDeviceDestroyIOProcID failed after start failure with status %{public}d",
                    cleanupStatus
                )
            }
            throw error
        }
        return createdIOProcID
    }

}
