import Foundation

public extension NativeAppShellOperatorPrototypeState {
    func validate() throws {
        try nativeAppShellOperatorNonEmpty(inventory.capturedAt, "inventory.capturedAt")
        try nativeAppShellOperatorNonEmpty(inventory.hostName, "inventory.hostName")
        switch sessionMode {
        case .directMacPeer:
            try nativeAppShellOperatorNonEmpty(remoteInventory.capturedAt, "remoteInventory.capturedAt")
            try nativeAppShellOperatorNonEmpty(remoteInventory.hostName, "remoteInventory.hostName")
            try directPeerCommandFields.validateAppSettings()
            try validateAudioSelection()
            try validateVideoSelection()
            try validateRemoteAudioSelection()
            try validateRemoteVideoSelection()
        case .windowsLoLa:
            try windowsLoLaPeerFields.validateAppSettings()
        }
        if remoteOrchestrationEnabled {
            throw NativeAppShellSurfaceValidationError.operatorEnablesRemoteOrchestration
        }
        if startsLongRunningProcess {
            throw NativeAppShellSurfaceValidationError.operatorStartsLongRunningProcess
        }
    }

    func localDirectPeerCommandHandoff() throws -> NativeAppShellLocalCommandHandoff {
        try validate()
        guard sessionMode == .directMacPeer else {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
        }
        let inputUID = try requiredSelection(inventory.selection.audioInputUID, "audioInputUID")
        let outputUID = try requiredSelection(inventory.selection.audioOutputUID, "audioOutputUID")
        let videoDeviceID = try requiredSelection(inventory.selection.videoDeviceID, "videoDeviceID")
        let fields = directPeerCommandFields
        let arguments = [
            fields.executablePath, "direct-p2p-session-run",
            "--media", "audio-video",
            "--role", fields.role.rawValue,
            "--local-peer", fields.localPeer,
            "--remote-peer", fields.remotePeer,
            "--local-host", fields.localHost,
            "--remote-host", fields.remoteHost,
            "--control-port", "\(fields.controlPort)",
            "--remote-control-port", "\(fields.remoteControlPort)",
            "--audio-port", "\(fields.audioPort)",
            "--video-port", "\(fields.videoPort)",
            "--metrics-port", "\(fields.metricsPort)",
            "--output", fields.outputPath,
            "--duration-seconds", "\(fields.durationSeconds)",
            "--input-uid", inputUID,
            "--output-uid", outputUID,
            "--sample-rate", "\(fields.sampleRateHertz)",
            "--frames", "\(fields.framesPerPacket)",
            "--sample-format", fields.sampleFormat,
            "--audio-transport", fields.audioTransport.rawValue,
            "--channels", "\(fields.channelCount)",
            "--input-channels", operatorChannelCSV(count: fields.channelCount),
            "--output-channels", operatorChannelCSV(count: fields.channelCount),
            "--video-device-id", videoDeviceID,
            "--video-width", "\(fields.videoWidth)",
            "--video-height", "\(fields.videoHeight)",
            "--video-pixel-format", fields.videoPixelFormat,
            "--video-compression", fields.videoCompression.rawValue,
            "--video-frame-rate", "\(fields.videoFrameRate)",
            "--video-stream-id", "\(fields.videoStreamID)",
            "--av-profile", fields.avProfile.rawValue,
            "--rx-buffer-profile", fields.rxBufferProfile.rawValue,
            "--preview", fields.preview.rawValue,
            "--timeout-seconds", "\(fields.timeoutSeconds)",
        ]
        let handoff = NativeAppShellLocalCommandHandoff(
            intent: commandIntent,
            command: NativeAppShellLocalDirectPeerCommand(arguments: arguments),
            remoteOrchestrationEnabled: remoteOrchestrationEnabled,
            startsLongRunningProcess: startsLongRunningProcess
        )
        try handoff.validate()
        return handoff
    }

    func twoPeerRunPlanConfiguration(
        outputPath: String = "/tmp/open-lola-mac-to-mac/plan.json",
        runDirectory: String = "/tmp/open-lola-mac-to-mac"
    ) throws -> DirectPeerTwoPeerRunPlanConfiguration {
        try validate()
        guard sessionMode == .directMacPeer else {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
        }
        let fields = directPeerCommandFields
        let localSelection = inventory.selection
        let remoteSelection = remoteInventory.selection
        return DirectPeerTwoPeerRunPlanConfiguration(
            outputPath: outputPath,
            runDirectory: runDirectory,
            macA: DirectPeerTwoPeerRunPlanPeer(
                peerID: fields.localPeer,
                host: fields.localHost,
                portBase: fields.controlPort,
                inputUID: try requiredSelection(localSelection.audioInputUID, "audioInputUID"),
                outputUID: try requiredSelection(localSelection.audioOutputUID, "audioOutputUID"),
                videoDeviceID: try requiredSelection(localSelection.videoDeviceID, "videoDeviceID")
            ),
            macB: DirectPeerTwoPeerRunPlanPeer(
                peerID: fields.remotePeer,
                host: fields.remoteHost,
                portBase: fields.remoteControlPort,
                inputUID: try requiredRemoteSelection(remoteSelection.audioInputUID, "audioInputUID"),
                outputUID: try requiredRemoteSelection(remoteSelection.audioOutputUID, "audioOutputUID"),
                videoDeviceID: try requiredRemoteSelection(remoteSelection.videoDeviceID, "videoDeviceID")
            ),
            durationSeconds: fields.durationSeconds,
            channelCount: fields.channelCount,
            sampleRateHertz: fields.sampleRateHertz,
            framesPerPacket: fields.framesPerPacket,
            sampleFormat: fields.sampleFormat,
            audioTransport: fields.audioTransport,
            videoWidth: fields.videoWidth,
            videoHeight: fields.videoHeight,
            videoPixelFormat: fields.videoPixelFormat,
            videoCompression: fields.videoCompression,
            videoFrameRate: fields.videoFrameRate,
            avProfile: fields.avProfile,
            rxBufferProfile: fields.rxBufferProfile,
            preview: fields.preview,
            timeoutSeconds: fields.timeoutSeconds
        )
    }

    func windowsLoLaSessionArguments(executablePath: String, dryRun: Bool) throws -> [String] {
        try validate()
        guard sessionMode == .windowsLoLa else {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
        }
        return try windowsLoLaPeerFields.sessionArguments(executablePath: executablePath, dryRun: dryRun)
    }

    func windowsLoLaValidatorArguments(executablePath: String) throws -> [String] {
        try validate()
        guard sessionMode == .windowsLoLa else {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
        }
        return try windowsLoLaPeerFields.validatorArguments(executablePath: executablePath)
    }
}

private extension NativeAppShellOperatorPrototypeState {
    func validateAudioSelection() throws {
        if let uid = inventory.selection.audioInputUID,
           !inventory.audioDevices.contains(where: { $0.uid == uid && $0.supportsInput }) {
            throw NativeAppShellSurfaceValidationError.selectedAudioInputUnavailable(uid)
        }
        if let uid = inventory.selection.audioOutputUID,
           !inventory.audioDevices.contains(where: { $0.uid == uid && $0.supportsOutput }) {
            throw NativeAppShellSurfaceValidationError.selectedAudioOutputUnavailable(uid)
        }
    }

    func validateVideoSelection() throws {
        guard let id = inventory.selection.videoDeviceID else { return }
        if !inventory.videoDevices.contains(where: { $0.uniqueId == id }) {
            throw NativeAppShellSurfaceValidationError.selectedVideoDeviceUnavailable(id)
        }
    }

    func validateRemoteAudioSelection() throws {
        if let uid = remoteInventory.selection.audioInputUID,
           !remoteInventory.audioDevices.contains(where: { $0.uid == uid && $0.supportsInput }) {
            throw NativeAppShellSurfaceValidationError.selectedRemoteAudioInputUnavailable(uid)
        }
        if let uid = remoteInventory.selection.audioOutputUID,
           !remoteInventory.audioDevices.contains(where: { $0.uid == uid && $0.supportsOutput }) {
            throw NativeAppShellSurfaceValidationError.selectedRemoteAudioOutputUnavailable(uid)
        }
    }

    func validateRemoteVideoSelection() throws {
        guard let id = remoteInventory.selection.videoDeviceID else { return }
        if !remoteInventory.videoDevices.contains(where: { $0.uniqueId == id }) {
            throw NativeAppShellSurfaceValidationError.selectedRemoteVideoDeviceUnavailable(id)
        }
    }

    func requiredSelection(_ value: String?, _ field: String) throws -> String {
        guard let value, !value.isEmpty else {
            throw NativeAppShellSurfaceValidationError.missingLocalCommandSelection(field)
        }
        return value
    }

    func requiredRemoteSelection(_ value: String?, _ field: String) throws -> String {
        guard let value, !value.isEmpty else {
            throw NativeAppShellSurfaceValidationError.missingRemoteCommandSelection(field)
        }
        return value
    }
}

private func nativeAppShellOperatorNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw NativeAppShellSurfaceValidationError.emptyField(field)
    }
}

private func operatorChannelCSV(count: Int) -> String {
    (0..<count).map(String.init).joined(separator: ",")
}
