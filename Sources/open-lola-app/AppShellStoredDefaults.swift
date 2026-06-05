import Foundation
import OpenLolaCore
import OSLog

enum AppShellStoredDefaults {
    // Default parameters intentionally read from UserDefaults.standard.
    private static let logger = Logger(subsystem: "org.openlola.app", category: "stored-defaults")

    static func positivePreviewStreamValue(_ value: Int) -> Int {
        max(1, value)
    }

    static func placeholderOperatorSurface(
        commandIntent: NativeAppShellOperatorCommandIntent = .idle,
        remoteInventory: NativeAppShellLocalMediaInventory = .editableRemotePlaceholder()
    ) -> NativeAppShellOperatorPrototypeState {
        NativeAppShellOperatorPrototypeState(
            sessionMode: sessionMode(),
            controlMode: controlMode(),
            inventory: NativeAppShellLocalMediaInventory(
                capturedAt: "launch-inventory-pending",
                hostName: "local-peer",
                audioDevices: [],
                videoDevices: [],
                selection: NativeAppShellLocalMediaSelection(
                    audioInputUID: nil,
                    audioOutputUID: nil,
                    videoDeviceID: nil
                ),
                inventoryErrors: ["Local media inventory refresh pending."]
            ),
            remoteInventory: remoteInventory,
            commandIntent: commandIntent,
            remoteOrchestrationEnabled: false,
            startsLongRunningProcess: false,
            directPeerCommandFields: directPeerCommandFields(),
            windowsLoLaPeerFields: windowsLoLaPeerFields(),
            jackTripPeerFields: jackTripPeerFields(),
            ultraGridPeerFields: ultraGridPeerFields()
        )
    }

    static func hydratedOperatorSurface(
        commandIntent: NativeAppShellOperatorCommandIntent = .idle,
        remoteInventory: NativeAppShellLocalMediaInventory = .editableRemotePlaceholder()
    ) -> NativeAppShellOperatorPrototypeState {
        AppLocalOperatorInventory.capture(AppLocalOperatorInventoryCaptureRequest(
            sessionMode: sessionMode(),
            controlMode: controlMode(),
            commandIntent: commandIntent,
            remoteInventory: remoteInventory,
            directPeerCommandFields: directPeerCommandFields(),
            windowsLoLaPeerFields: windowsLoLaPeerFields(),
            jackTripPeerFields: jackTripPeerFields(),
            ultraGridPeerFields: ultraGridPeerFields()
        ))
    }

    static func sessionMode(defaults: UserDefaults = .standard) -> NativeAppShellSessionMode {
        NativeAppShellSessionMode(rawValue: defaults.string(forKey: AppStorageKeys.sessionMode) ?? "")
            ?? .directMacPeer
    }

    static func controlMode(defaults: UserDefaults = .standard) -> NativeAppShellControlMode {
        NativeAppShellControlMode(rawValue: defaults.string(forKey: AppStorageKeys.controlMode) ?? "")
            ?? .normal
    }

    static func directPeerCommandFields(defaults: UserDefaults = .standard) -> NativeAppShellDirectPeerCommandFields {
        var fields = NativeAppShellDirectPeerCommandFields.appDefault
        applyDirectPeerIdentityFields(to: &fields, defaults: defaults)
        applyDirectPeerPortFields(to: &fields, defaults: defaults)
        applyDirectPeerAudioFields(to: &fields, defaults: defaults)
        applyDirectPeerVideoFields(to: &fields, defaults: defaults)
        applyDirectPeerRuntimeFields(to: &fields, defaults: defaults)
        return validatedOrDefault(fields)
    }

    private static func applyDirectPeerIdentityFields(
        to fields: inout NativeAppShellDirectPeerCommandFields,
        defaults: UserDefaults
    ) {
        fields.executablePath = defaults.string(forKey: AppStorageKeys.executablePath) ?? fields.executablePath
        fields.role = DirectPeerSessionManualRole(rawValue: defaults.string(forKey: AppStorageKeys.role) ?? "")
            ?? fields.role
        fields.localPeer = defaults.string(forKey: AppStorageKeys.localPeer) ?? fields.localPeer
        fields.remotePeer = defaults.string(forKey: AppStorageKeys.remotePeer) ?? fields.remotePeer
        fields.localHost = defaults.string(forKey: AppStorageKeys.localHost) ?? fields.localHost
        fields.remoteHost = defaults.string(forKey: AppStorageKeys.remoteHost) ?? fields.remoteHost
        fields.outputPath = defaults.string(forKey: AppStorageKeys.outputPath) ?? fields.outputPath
    }

    private static func applyDirectPeerPortFields(
        to fields: inout NativeAppShellDirectPeerCommandFields,
        defaults: UserDefaults
    ) {
        fields.controlPort = uint16Default(AppStorageKeys.controlPort, fallback: fields.controlPort, defaults: defaults)
        fields.remoteControlPort = uint16Default(
            AppStorageKeys.remoteControlPort,
            fallback: fields.remoteControlPort,
            defaults: defaults
        )
        fields.audioPort = uint16Default(AppStorageKeys.audioPort, fallback: fields.audioPort, defaults: defaults)
        fields.videoPort = uint16Default(AppStorageKeys.videoPort, fallback: fields.videoPort, defaults: defaults)
        fields.metricsPort = uint16Default(AppStorageKeys.metricsPort, fallback: fields.metricsPort, defaults: defaults)
    }

    private static func applyDirectPeerAudioFields(
        to fields: inout NativeAppShellDirectPeerCommandFields,
        defaults: UserDefaults
    ) {
        fields.channelCount = intDefault(AppStorageKeys.channelCount, fallback: fields.channelCount, defaults: defaults)
        fields.sampleRateHertz = intDefault(
            AppStorageKeys.sampleRate,
            fallback: fields.sampleRateHertz,
            defaults: defaults
        )
        fields.framesPerPacket = intDefault(AppStorageKeys.frames, fallback: fields.framesPerPacket, defaults: defaults)
        fields.durationSeconds = intDefault(AppStorageKeys.duration, fallback: fields.durationSeconds, defaults: defaults)
        fields.sampleFormat = defaults.string(forKey: AppStorageKeys.sampleFormat) ?? fields.sampleFormat
        applyDirectPeerAudioTransport(to: &fields, defaults: defaults)
    }

    private static func applyDirectPeerAudioTransport(
        to fields: inout NativeAppShellDirectPeerCommandFields,
        defaults: UserDefaults
    ) {
        if let persistedTransport = DirectPeerSessionAudioTransport(
            rawValue: defaults.string(forKey: AppStorageKeys.audioTransport) ?? ""
        ) {
            fields.audioTransport = persistedTransport
        } else if let legacyCompression = DirectPeerSessionAudioCompression(
            rawValue: defaults.string(forKey: AppStorageKeys.audioCompression) ?? ""
        ) {
            fields.audioTransport = legacyCompression.audioTransport
            defaults.set(fields.audioTransport.rawValue, forKey: AppStorageKeys.audioTransport)
            defaults.removeObject(forKey: AppStorageKeys.audioCompression)
            let migratedAudioTransport = fields.audioTransport.rawValue
            logger.notice(
                "Migrated legacy audioCompression '\(legacyCompression.rawValue, privacy: .public)' to audioTransport '\(migratedAudioTransport, privacy: .public)'"
            )
        }
    }

    private static func applyDirectPeerVideoFields(
        to fields: inout NativeAppShellDirectPeerCommandFields,
        defaults: UserDefaults
    ) {
        fields.videoWidth = intDefault(AppStorageKeys.videoWidth, fallback: fields.videoWidth, defaults: defaults)
        fields.videoHeight = intDefault(AppStorageKeys.videoHeight, fallback: fields.videoHeight, defaults: defaults)
        fields.videoPixelFormat = defaults.string(forKey: AppStorageKeys.videoPixelFormat) ?? fields.videoPixelFormat
        fields.videoCompression = DirectPeerSessionVideoCompression(
            rawValue: defaults.string(forKey: AppStorageKeys.videoCompression) ?? ""
        ) ?? fields.videoCompression
        fields.videoFrameRate = intDefault(
            AppStorageKeys.videoFrameRate,
            fallback: fields.videoFrameRate,
            defaults: defaults
        )
        fields.videoStreamID = intDefault(AppStorageKeys.videoStreamID, fallback: fields.videoStreamID, defaults: defaults)
    }

    private static func applyDirectPeerRuntimeFields(
        to fields: inout NativeAppShellDirectPeerCommandFields,
        defaults: UserDefaults
    ) {
        fields.timeoutSeconds = intDefault(
            AppStorageKeys.timeoutSeconds,
            fallback: fields.timeoutSeconds,
            defaults: defaults
        )
        fields.avProfile = DirectPeerSessionAVProfile(rawValue: defaults.string(forKey: AppStorageKeys.avProfile) ?? "")
            ?? fields.avProfile
        let persistedRXBufferProfile = defaults.string(forKey: AppStorageKeys.rxBufferProfile)
        if let persistedRXBufferProfile, let profile = RxBufferProfile(rawValue: persistedRXBufferProfile) {
            fields.rxBufferProfile = profile
        } else {
            fields.rxBufferProfile = fields.avProfile.defaultRXBufferProfile
            if let persistedRXBufferProfile, !persistedRXBufferProfile.isEmpty {
                let fallbackProfile = fields.rxBufferProfile.rawValue
                logger.warning(
                    "Invalid persisted rxBufferProfile '\(persistedRXBufferProfile, privacy: .public)' reset to '\(fallbackProfile, privacy: .public)'"
                )
            }
        }
        fields.preview = DirectPeerSessionPreviewMode(rawValue: defaults.string(forKey: AppStorageKeys.preview) ?? "")
            ?? fields.preview
    }

    static func windowsLoLaPeerFields(defaults: UserDefaults = .standard) -> NativeAppShellWindowsLoLaPeerFields {
        var fields = NativeAppShellWindowsLoLaPeerFields.appDefault
        applyWindowsLoLaConnectionFields(to: &fields, defaults: defaults)
        applyWindowsLoLaVideoFields(to: &fields, defaults: defaults)
        applyWindowsLoLaAudioFields(to: &fields, defaults: defaults)
        return validatedOrDefault(fields)
    }

    private static func applyWindowsLoLaConnectionFields(
        to fields: inout NativeAppShellWindowsLoLaPeerFields,
        defaults: UserDefaults
    ) {
        fields.executablePath = defaults.string(forKey: AppStorageKeys.executablePath) ?? fields.executablePath
        fields.localHost = defaults.string(forKey: AppStorageKeys.windowsLoLaLocalHost) ?? fields.localHost
        fields.windowsHost = defaults.string(forKey: AppStorageKeys.windowsLoLaWindowsHost) ?? fields.windowsHost
        fields.role = ExternalConnectorSessionRole(rawValue: defaults.string(forKey: AppStorageKeys.windowsLoLaRole) ?? "")
            ?? fields.role
        fields.controlPort = uint16Default(
            AppStorageKeys.windowsLoLaControlPort,
            fallback: fields.controlPort,
            defaults: defaults
        )
        fields.audioPort = uint16Default(AppStorageKeys.windowsLoLaAudioPort, fallback: fields.audioPort, defaults: defaults)
        fields.videoPort = uint16Default(AppStorageKeys.windowsLoLaVideoPort, fallback: fields.videoPort, defaults: defaults)
        fields.mediaMode = ExternalConnectorMediaMode(
            rawValue: defaults.string(forKey: AppStorageKeys.windowsLoLaMediaMode) ?? ""
        ) ?? fields.mediaMode
        fields.payloadMode = LoLaVideoPayloadKind(
            rawValue: defaults.string(forKey: AppStorageKeys.windowsLoLaPayloadMode) ?? ""
        ) ?? fields.payloadMode
        fields.outputPath = defaults.string(forKey: AppStorageKeys.windowsLoLaOutputPath) ?? fields.outputPath
    }

    private static func applyWindowsLoLaVideoFields(
        to fields: inout NativeAppShellWindowsLoLaPeerFields,
        defaults: UserDefaults
    ) {
        fields.videoWidth = intDefault(
            AppStorageKeys.windowsLoLaVideoWidth,
            fallback: fields.videoWidth,
            defaults: defaults
        )
        fields.videoHeight = intDefault(
            AppStorageKeys.windowsLoLaVideoHeight,
            fallback: fields.videoHeight,
            defaults: defaults
        )
        fields.videoFrameRate = intDefault(
            AppStorageKeys.windowsLoLaVideoFrameRate,
            fallback: fields.videoFrameRate,
            defaults: defaults
        )
        fields.videoBitsPerPixel = intDefault(
            AppStorageKeys.windowsLoLaVideoBitsPerPixel,
            fallback: fields.videoBitsPerPixel,
            defaults: defaults
        )
        fields.durationSeconds = intDefault(
            AppStorageKeys.windowsLoLaDuration,
            fallback: fields.durationSeconds,
            defaults: defaults
        )
    }

    private static func applyWindowsLoLaAudioFields(
        to fields: inout NativeAppShellWindowsLoLaPeerFields,
        defaults: UserDefaults
    ) {
        fields.sampleRateHertz = intDefault(
            AppStorageKeys.windowsLoLaSampleRate,
            fallback: fields.sampleRateHertz,
            defaults: defaults
        )
        fields.framesPerPacket = intDefault(
            AppStorageKeys.windowsLoLaFrames,
            fallback: fields.framesPerPacket,
            defaults: defaults
        )
        fields.channelCount = intDefault(
            AppStorageKeys.windowsLoLaChannelCount,
            fallback: fields.channelCount,
            defaults: defaults
        )
        fields.compression = intDefault(
            AppStorageKeys.windowsLoLaCompression,
            fallback: fields.compression,
            defaults: defaults
        )
        fields.bayer = intDefault(AppStorageKeys.windowsLoLaBayer, fallback: fields.bayer, defaults: defaults)
    }

    static func jackTripPeerFields(defaults: UserDefaults = .standard) -> NativeAppShellExternalConnectorPeerFields {
        externalConnectorPeerFields(
            defaultsPrefix: .jackTrip,
            fallback: .jackTripAppDefault,
            connector: .jackTrip,
            defaults: defaults
        )
    }

    static func ultraGridPeerFields(defaults: UserDefaults = .standard) -> NativeAppShellExternalConnectorPeerFields {
        externalConnectorPeerFields(
            defaultsPrefix: .ultraGrid,
            fallback: .ultraGridAppDefault,
            connector: .mvtpUltraGrid,
            defaults: defaults
        )
    }

    private static func externalConnectorPeerFields(
        defaultsPrefix: AppExternalConnectorStoragePrefix,
        fallback: NativeAppShellExternalConnectorPeerFields,
        connector: ExternalConnectorKind,
        defaults: UserDefaults
    ) -> NativeAppShellExternalConnectorPeerFields {
        var fields = fallback
        fields.executablePath = defaults.string(forKey: AppStorageKeys.executablePath) ?? fields.executablePath
        fields.localHost = defaults.string(forKey: defaultsPrefix.localHost) ?? fields.localHost
        fields.peerHost = defaults.string(forKey: defaultsPrefix.peerHost) ?? fields.peerHost
        fields.role = ExternalConnectorSessionRole(rawValue: defaults.string(forKey: defaultsPrefix.role) ?? "")
            ?? fields.role
        fields.audioPort = uint16Default(defaultsPrefix.audioPort, fallback: fields.audioPort, defaults: defaults)
        fields.peerAudioPort = uint16Default(
            defaultsPrefix.peerAudioPort,
            fallback: fields.peerAudioPort,
            defaults: defaults
        )
        fields.videoPort = uint16Default(defaultsPrefix.videoPort, fallback: fields.videoPort, defaults: defaults)
        fields.mediaMode = ExternalConnectorMediaMode(rawValue: defaults.string(forKey: defaultsPrefix.mediaMode) ?? "")
            ?? fields.mediaMode
        fields.durationSeconds = intDefault(defaultsPrefix.duration, fallback: fields.durationSeconds, defaults: defaults)
        fields.outputPath = defaults.string(forKey: defaultsPrefix.outputPath) ?? fields.outputPath
        return validatedOrDefault(fields, connector: connector, fallback: fallback)
    }

    static func executionSettings(defaults: UserDefaults = .standard) -> NativeAppShellExecutionSettings {
        var settings = NativeAppShellExecutionSettings()
        settings.planPath = defaults.string(forKey: AppStorageKeys.planPath) ?? settings.planPath
        settings.supervisorReportPath = defaults.string(forKey: AppStorageKeys.supervisorReportPath)
            ?? settings.supervisorReportPath
        settings.executionMode = DirectPeerTwoPeerRunExecutionMode(
            rawValue: defaults.string(forKey: AppStorageKeys.executionMode) ?? ""
        ) ?? settings.executionMode
        settings.requirePreflight = boolDefault(
            AppStorageKeys.requirePreflight,
            fallback: settings.requirePreflight,
            defaults: defaults
        )
        settings.macASSH = defaults.string(forKey: AppStorageKeys.executionMacASSH) ?? settings.macASSH
        settings.macBSSH = defaults.string(forKey: AppStorageKeys.executionMacBSSH) ?? settings.macBSSH
        settings.macAWorkingDirectory = defaults.string(forKey: AppStorageKeys.executionMacAWorkingDirectory)
            ?? settings.macAWorkingDirectory
        settings.macBWorkingDirectory = defaults.string(forKey: AppStorageKeys.executionMacBWorkingDirectory)
            ?? settings.macBWorkingDirectory
        settings.sshExecutable = defaults.string(forKey: AppStorageKeys.executionSSHExecutable) ?? settings.sshExecutable
        settings.scpExecutable = defaults.string(forKey: AppStorageKeys.executionSCPExecutable) ?? settings.scpExecutable
        return settings
    }

    @MainActor
    static func previewReceiverState(defaults: UserDefaults = .standard) -> AppPreviewReceiverState {
        let previewDefaults = previewDefaults(defaults: defaults)
        return AppPreviewReceiverState(
            audioPreviewEnabled: previewDefaults.audioPreviewEnabled,
            videoPreviewEnabled: previewDefaults.videoPreviewEnabled,
            showSafeFrame: previewDefaults.showSafeFrame,
            monitorGain: previewDefaults.monitorGain,
            remoteReturnBlend: previewDefaults.remoteReturnBlend,
            videoScale: previewDefaults.videoScale,
            visibleStreams: previewDefaults.visibleStreams,
            selectedVideoStream: previewDefaults.selectedVideoStream
        )
    }

    static func previewDefaults(defaults: UserDefaults = .standard) -> AppPreviewDefaults {
        AppPreviewDefaults(
            audioPreviewEnabled: boolDefault(
                AppStorageKeys.audioPreviewEnabled,
                fallback: true,
                defaults: defaults
            ),
            videoPreviewEnabled: boolDefault(
                AppStorageKeys.videoPreviewEnabled,
                fallback: true,
                defaults: defaults
            ),
            showSafeFrame: boolDefault(AppStorageKeys.showSafeFrame, fallback: true, defaults: defaults),
            monitorGain: doubleDefault(AppStorageKeys.monitorGain, fallback: 0.65, defaults: defaults),
            remoteReturnBlend: doubleDefault(AppStorageKeys.remoteReturnBlend, fallback: 0.25, defaults: defaults),
            videoScale: doubleDefault(AppStorageKeys.videoScale, fallback: 1.0, defaults: defaults),
            visibleStreams: positivePreviewStreamValue(
                intDefault(AppStorageKeys.visibleStreams, fallback: 1, defaults: defaults)
            ),
            selectedVideoStream: positivePreviewStreamValue(
                intDefault(AppStorageKeys.selectedVideoStream, fallback: 101, defaults: defaults)
            )
        )
    }

    @MainActor
    static func hydratePreviewState(_ previewState: AppPreviewReceiverState) {
        let storedDefaults = previewDefaults()
        previewState.audioPreviewEnabled = storedDefaults.audioPreviewEnabled
        previewState.videoPreviewEnabled = storedDefaults.videoPreviewEnabled
        previewState.showSafeFrame = storedDefaults.showSafeFrame
        previewState.monitorGain = storedDefaults.monitorGain
        previewState.remoteReturnBlend = storedDefaults.remoteReturnBlend
        previewState.videoScale = storedDefaults.videoScale
        previewState.visibleStreams = storedDefaults.visibleStreams
        previewState.selectedVideoStream = storedDefaults.selectedVideoStream
    }

    private static func validatedOrDefault(
        _ fields: NativeAppShellDirectPeerCommandFields
    ) -> NativeAppShellDirectPeerCommandFields {
        do {
            try fields.validateAppSettings()
            return fields
        } catch {
            return .appDefault
        }
    }

    private static func validatedOrDefault(
        _ fields: NativeAppShellWindowsLoLaPeerFields
    ) -> NativeAppShellWindowsLoLaPeerFields {
        do {
            try fields.validateAppSettings()
            return fields
        } catch {
            return .appDefault
        }
    }

    private static func validatedOrDefault(
        _ fields: NativeAppShellExternalConnectorPeerFields,
        connector: ExternalConnectorKind,
        fallback: NativeAppShellExternalConnectorPeerFields
    ) -> NativeAppShellExternalConnectorPeerFields {
        do {
            try fields.validateAppSettings(connector: connector)
            return fields
        } catch {
            return fallback
        }
    }

    private static func intDefault(_ key: String, fallback: Int, defaults: UserDefaults = .standard) -> Int {
        defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
    }

    private static func uint16Default(_ key: String, fallback: UInt16, defaults: UserDefaults = .standard) -> UInt16 {
        guard defaults.object(forKey: key) != nil else { return fallback }

        let persistedValue = defaults.integer(forKey: key)
        guard let exactValue = UInt16(exactly: persistedValue) else {
            defaults.removeObject(forKey: key)
            logger.warning(
                "Invalid persisted UInt16 value \(persistedValue, privacy: .public) for \(key, privacy: .public); reset to \(Int(fallback), privacy: .public)"
            )
            return fallback
        }
        return exactValue
    }

    private static func boolDefault(_ key: String, fallback: Bool, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }

    private static func doubleDefault(_ key: String, fallback: Double, defaults: UserDefaults = .standard) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}

private enum AppExternalConnectorStoragePrefix {
    case jackTrip
    case ultraGrid

    var localHost: String {
        switch self {
        case .jackTrip: AppStorageKeys.jackTripLocalHost
        case .ultraGrid: AppStorageKeys.ultraGridLocalHost
        }
    }

    var peerHost: String {
        switch self {
        case .jackTrip: AppStorageKeys.jackTripPeerHost
        case .ultraGrid: AppStorageKeys.ultraGridPeerHost
        }
    }

    var role: String {
        switch self {
        case .jackTrip: AppStorageKeys.jackTripRole
        case .ultraGrid: AppStorageKeys.ultraGridRole
        }
    }

    var audioPort: String {
        switch self {
        case .jackTrip: AppStorageKeys.jackTripAudioPort
        case .ultraGrid: AppStorageKeys.ultraGridAudioPort
        }
    }

    var peerAudioPort: String {
        switch self {
        case .jackTrip: AppStorageKeys.jackTripPeerAudioPort
        case .ultraGrid: AppStorageKeys.ultraGridPeerAudioPort
        }
    }

    var videoPort: String {
        switch self {
        case .jackTrip: AppStorageKeys.jackTripVideoPort
        case .ultraGrid: AppStorageKeys.ultraGridVideoPort
        }
    }

    var mediaMode: String {
        switch self {
        case .jackTrip: AppStorageKeys.jackTripMediaMode
        case .ultraGrid: AppStorageKeys.ultraGridMediaMode
        }
    }

    var duration: String {
        switch self {
        case .jackTrip: AppStorageKeys.jackTripDuration
        case .ultraGrid: AppStorageKeys.ultraGridDuration
        }
    }

    var outputPath: String {
        switch self {
        case .jackTrip: AppStorageKeys.jackTripOutputPath
        case .ultraGrid: AppStorageKeys.ultraGridOutputPath
        }
    }
}
