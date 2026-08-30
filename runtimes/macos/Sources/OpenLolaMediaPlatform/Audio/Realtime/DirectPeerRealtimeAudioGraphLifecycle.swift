// Preflights devices, configures sample rate and frame size, and starts IOProcs while preserving the state needed for restoration.
import CoreAudio
import COpenLolaAtomics
import Foundation
import os

extension DirectPeerRealtimeAudioGraph {
    public static func preflight(
        configuration: DirectPeerRealtimeAudioGraphConfiguration,
        inventory: CoreAudioInventoryReport,
        mode: DirectPeerRealtimeAudioGraphMode = .fullDuplex
    ) throws -> DirectPeerRealtimeAudioGraphPreflight {
        let preflight = DirectPeerRealtimeAudioGraphPreflight.evaluate(
            configuration: configuration,
            inventory: inventory,
            mode: mode
        )
        guard mode == .outputOnly || preflight.device != nil else {
            throw DirectPeerAudioGraphError.missingDeviceUID(configuration.inputDeviceUID)
        }
        guard mode == .inputOnly || preflight.outputDevice != nil else {
            throw DirectPeerAudioGraphError.missingDeviceUID(configuration.outputDeviceUID)
        }
        let outputDevice = preflight.outputDevice ?? preflight.device
        guard directPeerRealtimeAudioGraphRequestedDirectionsSupported(
            mode: mode,
            device: preflight.device,
            outputDevice: preflight.outputDevice
        ) else {
            throw DirectPeerAudioGraphError.deviceNotFullDuplex(
                outputDevice?.uid ?? configuration.outputDeviceUID
            )
        }
        guard preflight.sampleRateSupported else {
            throw DirectPeerAudioGraphError.unsupportedSampleRate(
                uid: outputDevice?.uid ?? configuration.outputDeviceUID,
                sampleRateHertz: configuration.sampleRateHertz
            )
        }
        guard preflight.frameSizeSupported else {
            throw DirectPeerAudioGraphError.unsupportedFrameSize(
                uid: outputDevice?.uid ?? configuration.outputDeviceUID,
                framesPerBuffer: configuration.framesPerBuffer
            )
        }
        if mode != .outputOnly, let device = preflight.device {
            try validateChannelMap(
                configuration.inputChannelMap,
                scope: .input,
                available: device.inputChannelCount,
                expectedCount: configuration.channelCount
            )
        }
        if mode != .inputOnly, let outputDevice {
            try validateChannelMap(
                configuration.outputChannelMap,
                scope: .output,
                available: outputDevice.outputChannelCount,
                expectedCount: configuration.channelCount
            )
        }
        return preflight
    }

    public func start(deviceID: AudioObjectID) throws {
        try start(inputDeviceID: deviceID, outputDeviceID: deviceID)
    }

    public func start(inputDeviceID: AudioObjectID, outputDeviceID: AudioObjectID) throws {
        try start(inputDeviceID: inputDeviceID as AudioObjectID?, outputDeviceID: outputDeviceID)
    }

    public func start(outputDeviceID: AudioObjectID) throws {
        try start(inputDeviceID: nil, outputDeviceID: outputDeviceID)
    }

    public func start(inputDeviceID: AudioObjectID) throws {
        try start(inputDeviceID: inputDeviceID, outputDeviceID: nil)
    }

    private func start(inputDeviceID: AudioObjectID?, outputDeviceID: AudioObjectID?) throws {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        guard inputIOProcID == nil,
              outputIOProcID == nil,
              open_lola_atomic_u64_load(&ioProcRunning) == 0 else {
            throw DirectPeerAudioGraphError.graphAlreadyStarted
        }
        guard modeMatchesRequestedDevices(inputDeviceID: inputDeviceID, outputDeviceID: outputDeviceID) else {
            throw DirectPeerAudioGraphError.graphNotStarted
        }
        self.inputDeviceID = inputDeviceID
        self.outputDeviceID = outputDeviceID
        captureOriginalDeviceState(inputDeviceID: inputDeviceID, outputDeviceID: outputDeviceID)
        do {
            if let inputDeviceID { try configureDevice(inputDeviceID) }
            if let outputDeviceID, outputDeviceID != inputDeviceID {
                try configureDevice(outputDeviceID)
            }
            open_lola_atomic_u64_store(&activeIOProcCallbacks, 0)
            open_lola_atomic_u64_store(&ioProcRunning, 1)
            if let inputDeviceID, inputDeviceID == outputDeviceID {
                inputIOProcID = try makeAndStartIOProc(
                    deviceID: inputDeviceID,
                    ioProc: directPeerRealtimeAudioIOProc
                )
            } else {
                if let inputDeviceID {
                    inputIOProcID = try makeAndStartIOProc(deviceID: inputDeviceID, ioProc: directPeerRealtimeAudioInputIOProc)
                }
                if let outputDeviceID {
                    outputIOProcID = try makeAndStartIOProc(deviceID: outputDeviceID, ioProc: directPeerRealtimeAudioOutputIOProc)
                }
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

    func modeMatchesRequestedDevices(inputDeviceID: AudioObjectID?, outputDeviceID: AudioObjectID?) -> Bool {
        switch mode {
        case .fullDuplex: inputDeviceID != nil && outputDeviceID != nil
        case .inputOnly: inputDeviceID != nil && outputDeviceID == nil
        case .outputOnly: inputDeviceID == nil && outputDeviceID != nil
        }
    }

    func captureOriginalDeviceState(inputDeviceID: AudioObjectID?, outputDeviceID: AudioObjectID?) {
        originalInputSampleRate = inputDeviceID.flatMap { doubleProperty(
            $0,
            kAudioDevicePropertyNominalSampleRate,
            kAudioObjectPropertyScopeGlobal
        ) }
        originalInputBufferFrameSize = inputDeviceID.flatMap { uint32Property(
            $0,
            kAudioDevicePropertyBufferFrameSize,
            kAudioObjectPropertyScopeGlobal
        ) }
        originalOutputSampleRate = inputDeviceID != nil && inputDeviceID == outputDeviceID
            ? originalInputSampleRate
            : outputDeviceID.flatMap { doubleProperty(
                $0,
                kAudioDevicePropertyNominalSampleRate,
                kAudioObjectPropertyScopeGlobal
            ) }
        originalOutputBufferFrameSize = inputDeviceID != nil && inputDeviceID == outputDeviceID
            ? originalInputBufferFrameSize
            : outputDeviceID.flatMap { uint32Property(
                $0,
                kAudioDevicePropertyBufferFrameSize,
                kAudioObjectPropertyScopeGlobal
            ) }
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
