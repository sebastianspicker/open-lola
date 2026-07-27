// Derives validated UltraGrid runtime ports, payload registry, encryption, and media provider settings.
import Foundation

// swiftlint:disable:next type_name
enum UltraGridCompatibilityRuntimeConfiguration {
    static func payloadRegistry(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws -> UltraGridRTPPayloadRegistry {
        var dynamicPayloads: [UInt8: UltraGridNegotiatedCodec] = [:]
        if configuration.ultraGridAudioPayloadType != UltraGridCompatibility.audioPayloadType {
            dynamicPayloads[configuration.ultraGridAudioPayloadType] = .pcmAudio
        }
        if configuration.ultraGridVideoPayloadType != UltraGridCompatibility.videoPayloadType {
            dynamicPayloads[configuration.ultraGridVideoPayloadType] = .rawVideo
        }
        return try UltraGridRTPPayloadRegistry(dynamicPayloads: dynamicPayloads)
    }

    static func encryptionConfiguration(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws -> UltraGridEncryptionConfiguration? {
        guard configuration.ultraGridEncryptionMode != .none else {
            return nil
        }
        if configuration.ultraGridFECMode != .none {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("ultragrid-encryption-with-fec")
        }
        guard let passphrase = configuration.ultraGridEncryptionPassphrase, !passphrase.isEmpty else {
            throw ExternalConnectorSessionError.missingRequiredArgument("--ultragrid-encryption-passphrase")
        }
        return try UltraGridEncryptionConfiguration(
            mode: configuration.ultraGridEncryptionMode,
            passphrase: passphrase
        )
    }
}
