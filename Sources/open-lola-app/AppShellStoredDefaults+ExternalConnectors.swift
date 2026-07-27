// Maps application settings to UserDefaults, isolating persistence keys from operator-facing configuration.
import Foundation
import OpenLolaCore

extension AppShellStoredDefaults {
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
        fields.role = ExternalConnectorSessionRole(
            rawValue: defaults.string(forKey: AppStorageKeys.windowsLoLaRole) ?? ""
        )
            ?? fields.role
        fields.controlPort = uint16Default(
            AppStorageKeys.windowsLoLaControlPort,
            fallback: fields.controlPort,
            defaults: defaults
        )
        fields.audioPort = uint16Default(
            AppStorageKeys.windowsLoLaAudioPort,
            fallback: fields.audioPort,
            defaults: defaults
        )
        fields.videoPort = uint16Default(
            AppStorageKeys.windowsLoLaVideoPort,
            fallback: fields.videoPort,
            defaults: defaults
        )
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
        fields.durationSeconds = intDefault(
            defaultsPrefix.duration,
            fallback: fields.durationSeconds,
            defaults: defaults
        )
        fields.outputPath = defaults.string(forKey: defaultsPrefix.outputPath) ?? fields.outputPath
        return validatedOrDefault(fields, connector: connector, fallback: fallback)
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
