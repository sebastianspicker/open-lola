// Maps application settings to UserDefaults, isolating persistence keys from operator-facing configuration.
import Foundation
import OpenLolaCore

extension AppShellStoredDefaults {
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
        fields.durationSeconds = intDefault(
            AppStorageKeys.duration,
            fallback: fields.durationSeconds,
            defaults: defaults
        )
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
                """
                Migrated legacy audioCompression '\(legacyCompression.rawValue, privacy: .public)' \
                to audioTransport '\(migratedAudioTransport, privacy: .public)'
                """
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
        fields.videoStreamID = intDefault(
            AppStorageKeys.videoStreamID,
            fallback: fields.videoStreamID,
            defaults: defaults
        )
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
                    """
                    Invalid persisted rxBufferProfile '\(persistedRXBufferProfile, privacy: .public)' \
                    reset to '\(fallbackProfile, privacy: .public)'
                    """
                )
            }
        }
        fields.preview = DirectPeerSessionPreviewMode(rawValue: defaults.string(forKey: AppStorageKeys.preview) ?? "")
            ?? fields.preview
    }
}
