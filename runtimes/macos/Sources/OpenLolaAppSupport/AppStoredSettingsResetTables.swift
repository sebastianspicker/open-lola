// Names the independently resettable fields of each persisted settings group, keyed by the validator's field names.
import Foundation
import OpenLolaCore

extension AppShellStoredDefaults {
    private typealias Recovery = AppStoredSettingsRecovery

    /// Resets only the invalid direct-peer fields and returns them with a note for each reset.
    static func validatedOrDefault(
        _ fields: NativeAppShellDirectPeerCommandFields
    ) -> AppStoredSettingsLoad<NativeAppShellDirectPeerCommandFields> {
        Recovery.recover(
            fields,
            fallback: .appDefault,
            group: "Direct-peer",
            resets: directPeerResets,
            validate: { try $0.validateAppSettings() }
        )
    }

    /// Resets only the invalid LoLa connector fields and returns them with a note for each reset.
    static func validatedOrDefault(
        _ fields: NativeAppShellWindowsLoLaPeerFields
    ) -> AppStoredSettingsLoad<NativeAppShellWindowsLoLaPeerFields> {
        Recovery.recover(
            fields,
            fallback: .appDefault,
            group: "LoLa connector",
            resets: windowsLoLaResets,
            validate: { try $0.validateAppSettings() }
        )
    }

    /// Resets only the invalid JackTrip or UltraGrid fields and returns them with a note for each reset.
    static func validatedOrDefault(
        _ fields: NativeAppShellExternalConnectorPeerFields,
        connector: ExternalConnectorKind,
        fallback: NativeAppShellExternalConnectorPeerFields
    ) -> AppStoredSettingsLoad<NativeAppShellExternalConnectorPeerFields> {
        Recovery.recover(
            fields,
            fallback: fallback,
            group: connector == .jackTrip ? "JackTrip connector" : "UltraGrid connector",
            resets: externalConnectorResets,
            validate: { try $0.validateAppSettings(connector: connector) }
        )
    }

    /// The stored direct-peer fields without the reset notes, for callers that only hydrate the operator surface.
    static func directPeerCommandFields(defaults: UserDefaults = .standard) -> NativeAppShellDirectPeerCommandFields {
        directPeerCommandFieldsLoad(defaults: defaults).fields
    }

    /// The stored LoLa connector fields without the reset notes.
    static func windowsLoLaPeerFields(defaults: UserDefaults = .standard) -> NativeAppShellWindowsLoLaPeerFields {
        windowsLoLaPeerFieldsLoad(defaults: defaults).fields
    }

    /// The stored JackTrip fields without the reset notes.
    static func jackTripPeerFields(defaults: UserDefaults = .standard) -> NativeAppShellExternalConnectorPeerFields {
        jackTripPeerFieldsLoad(defaults: defaults).fields
    }

    /// The stored UltraGrid fields without the reset notes.
    static func ultraGridPeerFields(defaults: UserDefaults = .standard) -> NativeAppShellExternalConnectorPeerFields {
        ultraGridPeerFieldsLoad(defaults: defaults).fields
    }

    private static var directPeerResets: [String: AppStoredFieldReset<NativeAppShellDirectPeerCommandFields>] {
        [
            "executablePath": Recovery.reset(\.executablePath),
            "localPeer": Recovery.reset(\.localPeer),
            "remotePeer": Recovery.reset(\.remotePeer),
            "localHost": Recovery.reset(\.localHost),
            "remoteHost": Recovery.reset(\.remoteHost),
            "outputPath": Recovery.reset(\.outputPath),
            "sampleFormat": Recovery.reset(\.sampleFormat),
            "videoPixelFormat": Recovery.reset(\.videoPixelFormat),
            "audioTransport": Recovery.reset(\.audioTransport),
            "videoCompression": Recovery.reset(\.videoCompression),
            "durationSeconds": Recovery.reset(\.durationSeconds),
            "channelCount": Recovery.reset(\.channelCount),
            "sampleRateHertz": Recovery.reset(\.sampleRateHertz),
            "framesPerPacket": Recovery.reset(\.framesPerPacket),
            "videoWidth": Recovery.reset(\.videoWidth),
            "videoHeight": Recovery.reset(\.videoHeight),
            "videoFrameRate": Recovery.reset(\.videoFrameRate),
            "videoStreamID": Recovery.reset(\.videoStreamID),
            "timeoutSeconds": Recovery.reset(\.timeoutSeconds),
            "controlPort": Recovery.reset(\.controlPort),
            "remoteControlPort": Recovery.reset(\.remoteControlPort),
            "audioPort": Recovery.reset(\.audioPort),
            "videoPort": Recovery.reset(\.videoPort),
            "metricsPort": Recovery.reset(\.metricsPort)
        ]
    }

    private static var windowsLoLaResets: [String: AppStoredFieldReset<NativeAppShellWindowsLoLaPeerFields>] {
        [
            "executablePath": Recovery.reset(\.executablePath),
            "localHost": Recovery.reset(\.localHost),
            "windowsHost": Recovery.reset(\.windowsHost),
            "outputPath": Recovery.reset(\.outputPath),
            "durationSeconds": Recovery.reset(\.durationSeconds),
            "sampleRateHertz": Recovery.reset(\.sampleRateHertz),
            "framesPerPacket": Recovery.reset(\.framesPerPacket),
            "channelCount": Recovery.reset(\.channelCount),
            "videoWidth": Recovery.reset(\.videoWidth),
            "videoHeight": Recovery.reset(\.videoHeight),
            "videoFrameRate": Recovery.reset(\.videoFrameRate),
            "videoBitsPerPixel": Recovery.reset(\.videoBitsPerPixel),
            "compression": Recovery.reset(\.compression),
            "bayer": Recovery.reset(\.bayer),
            "audioDeviceMode": Recovery.reset(\.audioDeviceMode),
            "payloadMode": Recovery.reset(\.payloadMode),
            "controlPort": Recovery.reset(\.controlPort),
            "audioPort": Recovery.reset(\.audioPort),
            "videoPort": Recovery.reset(\.videoPort)
        ]
    }

    private static var externalConnectorResets: [String: AppStoredFieldReset<NativeAppShellExternalConnectorPeerFields>] {
        [
            "executablePath": Recovery.reset(\.executablePath),
            "localHost": Recovery.reset(\.localHost),
            "peerHost": Recovery.reset(\.peerHost),
            "outputPath": Recovery.reset(\.outputPath),
            "durationSeconds": Recovery.reset(\.durationSeconds),
            "audioPort": Recovery.reset(\.audioPort),
            "videoPort": Recovery.reset(\.videoPort),
            "peerAudioPort": Recovery.reset(\.peerAudioPort),
            "mediaMode": Recovery.reset(\.mediaMode)
        ]
    }
}
