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
              open_lola_atomic_u64_load(&callbackState.ioProcRunning) == 0,
              open_lola_atomic_u64_load(&callbackState.activeIOProcCallbacks) == 0 else {
            throw DirectPeerAudioGraphError.graphAlreadyStarted
        }
        guard modeMatchesRequestedDevices(inputDeviceID: inputDeviceID, outputDeviceID: outputDeviceID) else {
            throw DirectPeerAudioGraphError.graphNotStarted
        }
        self.inputDeviceID = inputDeviceID
        self.outputDeviceID = outputDeviceID
        captureOriginalDeviceState(inputDeviceID: inputDeviceID, outputDeviceID: outputDeviceID)
        do {
            // Without the original values the stop path could not restore the device, so refuse before any set call.
            try requireOriginalDeviceState(inputDeviceID: inputDeviceID, outputDeviceID: outputDeviceID)
            if let inputDeviceID { try configureDevice(inputDeviceID) }
            if let outputDeviceID, outputDeviceID != inputDeviceID {
                try configureDevice(outputDeviceID)
            }
            open_lola_atomic_u64_store(&callbackState.activeIOProcCallbacks, 0)
            open_lola_atomic_u64_store(&callbackState.ioProcRunning, 1)
            if let inputDeviceID, inputDeviceID == outputDeviceID {
                inputIOProcID = try makeAndStartIOProc(
                    deviceID: inputDeviceID,
                    ioProc: directPeerRealtimeAudioIOProc, role: "input"
                )
            } else {
                if let inputDeviceID {
                    inputIOProcID = try makeAndStartIOProc(deviceID: inputDeviceID, ioProc: directPeerRealtimeAudioInputIOProc, role: "input")
                }
                if let outputDeviceID {
                    outputIOProcID = try makeAndStartIOProc(deviceID: outputDeviceID, ioProc: directPeerRealtimeAudioOutputIOProc, role: "output")
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

    func requireOriginalDeviceState(inputDeviceID: AudioObjectID?, outputDeviceID: AudioObjectID?) throws {
        if inputDeviceID != nil, originalInputSampleRate == nil || originalInputBufferFrameSize == nil {
            throw DirectPeerAudioGraphError.coreAudioStatus(
                kAudioHardwareUnspecifiedError, "read original input device sample rate and buffer size"
            )
        }
        if outputDeviceID != nil, originalOutputSampleRate == nil || originalOutputBufferFrameSize == nil {
            throw DirectPeerAudioGraphError.coreAudioStatus(
                kAudioHardwareUnspecifiedError, "read original output device sample rate and buffer size"
            )
        }
    }

    public func runtimeCounters() -> DirectPeerRealtimeAudioGraphRuntimeCounters {
        DirectPeerRealtimeAudioGraphRuntimeCounters(
            capturedInputBlocks: Int(open_lola_atomic_u64_load(&callbackState.capturedInputBlocks)),
            droppedInputBlocks: Int(open_lola_atomic_u64_load(&callbackState.droppedInputBlocks)),
            inputOverrunBlocks: Int(open_lola_atomic_u64_load(&callbackState.inputOverrunBlocks)),
            outputBlocks: Int(open_lola_atomic_u64_load(&callbackState.outputBlocks)),
            droppedOutputBlocks: Int(open_lola_atomic_u64_load(&callbackState.droppedOutputBlocks)),
            outputUnderrunBlocks: Int(open_lola_atomic_u64_load(&callbackState.outputUnderrunBlocks)),
            callbackInvocationBlocks: Int(open_lola_atomic_u64_load(&callbackState.callbackInvocationBlocks)),
            callbackMaxMicroseconds: Int(open_lola_atomic_u64_load(&callbackState.callbackMaxMicroseconds)),
            callbackDeadlineMisses: Int(open_lola_atomic_u64_load(&callbackState.callbackDeadlineMisses)),
            callbackOverrunBlocks: Int(open_lola_atomic_u64_load(&callbackState.callbackOverrunBlocks)),
            hostTimeConversionFailures: Int(open_lola_atomic_u64_load(&callbackState.hostTimeConversionFailures))
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
        // The HAL may clamp or ignore a request; a larger buffer would silently truncate to the first block.
        let actualFrames = Self.pollReadBack(accept: { $0 == UInt32(configuration.framesPerBuffer) }) {
            uint32Property(deviceID, kAudioDevicePropertyBufferFrameSize, kAudioObjectPropertyScopeGlobal)
        }
        guard actualFrames == UInt32(configuration.framesPerBuffer) else {
            throw DirectPeerAudioGraphError.unsupportedFrameSize(
                uid: "device \(deviceID): requested \(configuration.framesPerBuffer) frames, device reports \(actualFrames.map(String.init) ?? "unknown")",
                framesPerBuffer: configuration.framesPerBuffer
            )
        }
        let actualRate = Self.pollReadBack(accept: { $0.map { abs($0 - Double(configuration.sampleRateHertz)) <= 0.5 } ?? false }) {
            doubleProperty(deviceID, kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal)
        }
        guard let actualRate, abs(actualRate - Double(configuration.sampleRateHertz)) <= 0.5 else {
            throw DirectPeerAudioGraphError.unsupportedSampleRate(
                uid: "device \(deviceID): requested \(configuration.sampleRateHertz) Hz, device reports \(actualRate.map { "\($0)" } ?? "unknown") Hz",
                sampleRateHertz: configuration.sampleRateHertz
            )
        }
    }

    /// Core Audio applies rate and buffer changes asynchronously, so re-read for up to a second before judging. Not for RT threads.
    private static func pollReadBack<Value>(accept: (Value?) -> Bool, read: () -> Value?) -> Value? {
        var value = read()
        for _ in 0..<100 where !accept(value) {
            usleep(10_000)
            value = read()
        }
        return value
    }

    func makeAndStartIOProc(
        deviceID: AudioObjectID, ioProc: AudioDeviceIOProc, role: String
    ) throws -> AudioDeviceIOProcID {
        // One balanced retain for each HAL registration. No IOProc refers to self.
        let clientData = Unmanaged.passRetained(callbackState).toOpaque()
        var createdIOProcID: AudioDeviceIOProcID?
        let status = createIOProc(deviceID, ioProc, clientData, &createdIOProcID)
        guard let createdIOProcID else {
            Unmanaged<DirectPeerRealtimeAudioCallbackState>.fromOpaque(clientData).release()
            try throwDirectPeerAudioStatusIfNeeded(status, "create AudioDeviceIOProcID")
            throw DirectPeerAudioGraphError.graphNotStarted
        }
        // Track ownership before start can fail so the outer cleanup can retry
        // failed destruction instead of losing the only registration handle.
        if role == "input" {
            inputIOProcID = createdIOProcID
            inputIOProcClientData = clientData
        } else {
            outputIOProcID = createdIOProcID
            outputIOProcClientData = clientData
        }
        try throwDirectPeerAudioStatusIfNeeded(status, "create AudioDeviceIOProcID")
        try throwDirectPeerAudioStatusIfNeeded(startDevice(deviceID, createdIOProcID), "start AudioDeviceIOProc")
        return createdIOProcID
    }

    private func createIOProc(
        _ deviceID: AudioObjectID, _ ioProc: AudioDeviceIOProc,
        _ clientData: UnsafeMutableRawPointer, _ identifier: UnsafeMutablePointer<AudioDeviceIOProcID?>
    ) -> OSStatus {
        #if DEBUG
        createIOProcForTesting(deviceID, ioProc, clientData, identifier)
        #else
        AudioDeviceCreateIOProcID(deviceID, ioProc, clientData, identifier)
        #endif
    }

    private func startDevice(_ deviceID: AudioObjectID, _ identifier: AudioDeviceIOProcID) -> OSStatus {
        #if DEBUG
        startDeviceForTesting(deviceID, identifier)
        #else
        AudioDeviceStart(deviceID, identifier)
        #endif
    }
}
