// Encodes and decodes UltraGrid RTP headers, extensions, payloads, and sequence metadata.
import Foundation

/// Defines the values accepted for UltraGrid RTP packet codec.
public enum UltraGridRTPPacketCodec {
    private static let staticPayloadClassifications: [UInt8: UltraGridRTPPayloadClassification] = [
        22: .videoFEC,
        24: .videoEncrypted,
        25: .audioEncrypted,
        26: .videoJPEG
    ]

    private static let unsupportedStaticPayloadModes: [UInt8: String] = [
        0: "g711-pcmu",
        8: "g711-pcma",
        14: "mpa",
        27: "fec-video-rs",
        29: "encrypted-video-fec",
        30: "encrypted-video-fec",
        35: "fec-audio-rs",
        36: "encrypted-audio-fec"
    ]

    public static func classification(
        for payloadType: UInt8,
        registry: UltraGridRTPPayloadRegistry = .default
    ) throws -> UltraGridRTPPayloadClassification {
        if let codec = registry.codec(for: payloadType) {
            return try classification(for: codec)
        }
        if let classification = staticPayloadClassifications[payloadType] {
            return classification
        }
        if let unsupportedMode = unsupportedStaticPayloadModes[payloadType] {
            throw UltraGridCompatibilityError.unsupportedMode(unsupportedMode)
        }
        if (96...127).contains(payloadType) {
            throw UltraGridCompatibilityError.unsupportedMode("dynamic-rtp-unmapped-\(payloadType)")
        }
        throw UltraGridCompatibilityError.unsupportedPayloadType(payloadType)
    }

    public static func decode(
        _ packet: RTPPacket,
        registry: UltraGridRTPPayloadRegistry = .default,
        encryptionConfiguration: UltraGridEncryptionConfiguration? = nil
    ) throws -> UltraGridCompatibilityDatagram {
        switch try classification(for: packet.header.payloadType, registry: registry) {
        case .audioPCM:
            _ = try UltraGridAudioPayload.decode(packet.payload)
            return UltraGridCompatibilityDatagram(stream: .audio, destinationPort: 0, rtp: packet)
        case .audioEncrypted:
            let decrypted = try decryptAudio(packet, configuration: encryptionConfiguration)
            _ = try UltraGridAudioPayload.decode(decrypted.payload)
            return UltraGridCompatibilityDatagram(stream: .audio, destinationPort: 0, rtp: decrypted)
        case .videoRaw:
            _ = try UltraGridVideoRawFragmentPayload.decode(packet.payload)
            return UltraGridCompatibilityDatagram(stream: .video, destinationPort: 0, rtp: packet)
        case .videoFEC:
            _ = try UltraGridFECPayload.decode(packet.payload)
            return UltraGridCompatibilityDatagram(stream: .video, destinationPort: 0, rtp: packet)
        case .videoEncrypted:
            let decrypted = try decryptVideo(packet, configuration: encryptionConfiguration)
            _ = try UltraGridVideoRawFragmentPayload.decode(decrypted.payload)
            return UltraGridCompatibilityDatagram(stream: .video, destinationPort: 0, rtp: decrypted)
        case .videoJPEG:
            _ = try UltraGridRTPJPEGPayload.decode(packet.payload)
            return UltraGridCompatibilityDatagram(stream: .video, destinationPort: 0, rtp: packet)
        case .videoH264:
            _ = try UltraGridRTPH264Payload.decode(packet.payload)
            return UltraGridCompatibilityDatagram(stream: .video, destinationPort: 0, rtp: packet)
        }
    }

    private static func decryptAudio(
        _ packet: RTPPacket,
        configuration: UltraGridEncryptionConfiguration?
    ) throws -> RTPPacket {
        guard let configuration else {
            throw UltraGridCompatibilityError.unsupportedMode("encrypted-audio-missing-key")
        }
        let payload = try decryptedPayload(
            packet.payload,
            mediaHeaderByteCount: UltraGridAudioPayloadHeader.byteCount,
            configuration: configuration
        )
        return RTPPacket(
            header: RTPPacketHeader(
                payloadType: UltraGridCompatibility.audioPayloadType,
                marker: packet.header.marker,
                sequenceNumber: packet.header.sequenceNumber,
                timestamp: packet.header.timestamp,
                ssrc: packet.header.ssrc
            ),
            payload: payload
        )
    }

    private static func decryptVideo(
        _ packet: RTPPacket,
        configuration: UltraGridEncryptionConfiguration?
    ) throws -> RTPPacket {
        guard let configuration else {
            throw UltraGridCompatibilityError.unsupportedMode("encrypted-video-missing-key")
        }
        let payload = try decryptedPayload(
            packet.payload,
            mediaHeaderByteCount: UltraGridVideoPayloadHeader.byteCount,
            configuration: configuration
        )
        return RTPPacket(
            header: RTPPacketHeader(
                payloadType: UltraGridCompatibility.videoPayloadType,
                marker: packet.header.marker,
                sequenceNumber: packet.header.sequenceNumber,
                timestamp: packet.header.timestamp,
                ssrc: packet.header.ssrc
            ),
            payload: payload
        )
    }

    private static func decryptedPayload(
        _ payload: Data,
        mediaHeaderByteCount: Int,
        configuration: UltraGridEncryptionConfiguration
    ) throws -> Data {
        let minimum = mediaHeaderByteCount
            + UltraGridCryptoPayloadHeader.byteCount
            + UltraGridOpenSSLEncryption.lengthByteCount
            + UltraGridOpenSSLEncryption.ivByteCount
            + UltraGridOpenSSLEncryption.gcmTagByteCount
        guard payload.count >= minimum else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: payload.count)
        }
        let mediaHeader = payload[..<mediaHeaderByteCount]
        let cryptoHeaderStart = mediaHeaderByteCount
        let cryptoHeaderEnd = cryptoHeaderStart + UltraGridCryptoPayloadHeader.byteCount
        let cryptoHeader = try UltraGridCryptoPayloadHeader(bytes: payload[cryptoHeaderStart..<cryptoHeaderEnd])
        guard cryptoHeader.cipherMode == .aes128GCM else {
            throw UltraGridCompatibilityError.unsupportedMode("encryption-mode-\(cryptoHeader.cipherMode.rawValue)")
        }
        let plaintext = try UltraGridOpenSSLEncryption.decrypt(
            ciphertext: payload[cryptoHeaderEnd..<payload.count],
            aad: mediaHeader,
            configuration: configuration
        )
        var decrypted = Data(mediaHeader)
        decrypted.append(plaintext)
        return decrypted
    }

    private static func classification(
        for codec: UltraGridNegotiatedCodec
    ) throws -> UltraGridRTPPayloadClassification {
        switch codec {
        case .pcmAudio:
            return .audioPCM
        case .rawVideo:
            return .videoRaw
        case .jpeg:
            return .videoJPEG
        case .h264:
            return .videoH264
        }
    }
}
