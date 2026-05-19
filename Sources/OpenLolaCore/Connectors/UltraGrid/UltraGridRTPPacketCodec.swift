import Foundation

public enum UltraGridRTPPacketCodec {
    public static func classification(
        for payloadType: UInt8,
        registry: UltraGridRTPPayloadRegistry = .default
    ) throws -> UltraGridRTPPayloadClassification {
        if let codec = registry.codec(for: payloadType) {
            return try classification(for: codec)
        }
        switch payloadType {
        case 0:
            throw UltraGridCompatibilityError.unsupportedMode("g711-pcmu")
        case 8:
            throw UltraGridCompatibilityError.unsupportedMode("g711-pcma")
        case 14:
            throw UltraGridCompatibilityError.unsupportedMode("mpa")
        case 22:
            return .videoFEC
        case 24:
            return .videoEncrypted
        case 25:
            return .audioEncrypted
        case 26:
            return .videoJPEG
        case 29, 30:
            throw UltraGridCompatibilityError.unsupportedMode("encrypted-video-fec")
        case 36:
            throw UltraGridCompatibilityError.unsupportedMode("encrypted-audio-fec")
        case 27:
            throw UltraGridCompatibilityError.unsupportedMode("fec-video-rs")
        case 35:
            throw UltraGridCompatibilityError.unsupportedMode("fec-audio-rs")
        case 96...127:
            throw UltraGridCompatibilityError.unsupportedMode("dynamic-rtp-unmapped-\(payloadType)")
        default:
            throw UltraGridCompatibilityError.unsupportedPayloadType(payloadType)
        }
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
