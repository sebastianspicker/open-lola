// Builds direct-peer run plans and generated artifacts from the operator prototype state.
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
        case .jackTrip:
            try jackTripPeerFields.validateAppSettings(connector: .jackTrip)
        case .ultraGrid:
            try ultraGridPeerFields.validateAppSettings(connector: .mvtpUltraGrid)
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
        let fields = directPeerCommandFields
        let arguments = [
            fields.executablePath, "mac-to-mac-connection-preflight-run",
            "--local-peer-id", fields.localPeer,
            "--remote-peer-id", fields.remotePeer,
            "--peer", fields.remoteHost,
            "--output", NativeAppShellExecutionPaths.defaultConnectionPreflightReportPath()
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
        let macA = DirectPeerTwoPeerRunPlanPeer(
            peerID: fields.localPeer,
            host: fields.localHost,
            portBase: fields.controlPort,
            inputUID: try requiredSelection(localSelection.audioInputUID, "audioInputUID"),
            outputUID: try requiredSelection(localSelection.audioOutputUID, "audioOutputUID"),
            videoDeviceID: try requiredSelection(localSelection.videoDeviceID, "videoDeviceID")
        )
        let macB = DirectPeerTwoPeerRunPlanPeer(
            peerID: fields.remotePeer,
            host: fields.remoteHost,
            portBase: fields.remoteControlPort,
            inputUID: try requiredRemoteSelection(remoteSelection.audioInputUID, "audioInputUID"),
            outputUID: try requiredRemoteSelection(remoteSelection.audioOutputUID, "audioOutputUID"),
            videoDeviceID: try requiredRemoteSelection(remoteSelection.videoDeviceID, "videoDeviceID")
        )
        let input = DirectPeerTwoPeerRunPlanConfiguration.Input(
            paths: .init(outputPath: outputPath, runDirectory: runDirectory),
            peers: .init(macA: macA, macB: macB),
            audio: .init(
            channelCount: fields.channelCount,
            sampleRateHertz: fields.sampleRateHertz,
            framesPerPacket: fields.framesPerPacket,
            sampleFormat: fields.sampleFormat,
                transport: fields.audioTransport
            ),
            video: .init(
                width: fields.videoWidth,
                height: fields.videoHeight,
                pixelFormat: fields.videoPixelFormat,
                compression: fields.videoCompression,
                frameRate: fields.videoFrameRate
            ),
            runtime: .init(
                durationSeconds: fields.durationSeconds,
                avProfile: fields.avProfile,
                rxBufferProfile: fields.rxBufferProfile,
                preview: fields.preview,
                timeoutSeconds: fields.timeoutSeconds
            )
        )
        return DirectPeerTwoPeerRunPlanConfiguration(input)
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

    func externalConnectorSessionArguments(
        connector: ExternalConnectorKind,
        executablePath: String,
        dryRun: Bool
    ) throws -> [String] {
        try validate()
        guard sessionMode.externalConnectorKind == connector else {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
        }
        return try externalConnectorFields(connector: connector).sessionArguments(
            connector: connector,
            executablePath: executablePath,
            dryRun: dryRun
        )
    }

    func externalConnectorValidatorArguments(
        connector: ExternalConnectorKind,
        executablePath: String
    ) throws -> [String] {
        try validate()
        guard sessionMode.externalConnectorKind == connector else {
            throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
        }
        return try externalConnectorFields(connector: connector).validatorArguments(
            connector: connector,
            executablePath: executablePath
        )
    }

    func externalConnectorFields(
        connector: ExternalConnectorKind
    ) -> NativeAppShellExternalConnectorPeerFields {
        switch connector {
        case .jackTrip:
            return jackTripPeerFields
        case .mvtpUltraGrid:
            return ultraGridPeerFields
        case .lola:
            return NativeAppShellExternalConnectorPeerFields(
                connection: NativeAppShellExternalConnectorPeerFields.Connection(
                    peerHost: windowsLoLaPeerFields.windowsHost,
                    audioPort: windowsLoLaPeerFields.audioPort,
                    peerAudioPort: windowsLoLaPeerFields.audioPort,
                    videoPort: windowsLoLaPeerFields.videoPort,
                    mediaMode: windowsLoLaPeerFields.mediaMode
                ),
                execution: NativeAppShellExternalConnectorPeerFields.Execution(
                    executablePath: windowsLoLaPeerFields.executablePath,
                    localHost: windowsLoLaPeerFields.localHost,
                    role: windowsLoLaPeerFields.role,
                    durationSeconds: windowsLoLaPeerFields.durationSeconds,
                    outputPath: windowsLoLaPeerFields.outputPath
                )
            )
        }
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
