// Implements UltraGridCompatibility interoperability behavior, isolating peer-specific compatibility rules from generic transport.
import Darwin
import Foundation

/// Defines failures reported when UltraGrid compatibility error cannot continue.
public enum UltraGridCompatibilityError: Error, Equatable, Sendable {
    case unsupportedPayloadType(UInt8)
    case unsupportedMode(String)
    case truncatedPayload(byteCount: Int)
    case invalidFragment(index: UInt16, count: UInt16)
    case invalidPayloadLength(expected: Int, actual: Int)
    case invalidField(String, Int)
    case reassemblyIncomplete(missing: [UInt16])
    case receiveTimeout(expected: Int, actual: Int)
}

private let ultraGridRGB24FourCC = UltraGridFourCC(rawValue: 0x5247_4233)
private let ultraGridRGBAFourCC = UltraGridFourCC(rawValue: 0x5247_4241)

func ultraGridRawVideoFourCC(bitsPerPixel: Int) throws -> UltraGridFourCC {
    switch bitsPerPixel {
    case 8, 24:
        return ultraGridRGB24FourCC
    case 32:
        return ultraGridRGBAFourCC
    default:
        throw UltraGridCompatibilityError.unsupportedMode("raw-video-\(bitsPerPixel)bpp")
    }
}

/// Defines UltraGrid static payload types, clean-room evidence boundaries, and unsupported modes.
public enum UltraGridCompatibility {
    public static let audioPayloadType = UltraGridCompatibilityPayloadType.audio.rawValue
    public static let videoPayloadType = UltraGridCompatibilityPayloadType.video.rawValue
    public static let encryptedVideoPayloadType: UInt8 = 24
    public static let encryptedAudioPayloadType: UInt8 = 25
    public static let fecPayloadType: UInt8 = 22
    public static let jpegPayloadType: UInt8 = 26
    public static let videoClockRateHertz = 90_000
    public static let evidenceBoundary = "Swift-native clean-room RTP/MVTP packetization from public UltraGrid "
        + "packet type and RTP payload references. Real UltraGrid interoperability remains PARTIAL "
        + "until measured peer capture evidence exists."
    public static let unsupportedModes: [String] = []

    public static func audioPacket(_ request: UltraGridAudioPacketRequest) throws -> RTPPacket {
        try validateUltraGridPositive(request.channels, "audio.channels")
        try validateUltraGridPositive(request.framesPerPacket, "audio.framesPerPacket")
        let payload = try UltraGridAudioPayload(
            header: UltraGridAudioPayloadHeader(
                substreamID: try uint16(request.channels, "audio.channels"),
                bufferNumber: UInt32(request.sequenceNumber),
                payloadOffset: 0,
                payloadByteCount: UInt32(request.pcmPayload.count),
                quantizationBits: 16,
                sampleRateHertz: try uint32(request.sampleRateHertz, "audio.sampleRateHertz")
            ),
            pcmPayload: request.pcmPayload
        ).encoded()
        return RTPPacket(
            header: RTPPacketHeader(
                payloadType: request.payloadType,
                marker: false,
                sequenceNumber: request.sequenceNumber,
                timestamp: request.timestamp,
                ssrc: request.ssrc
            ),
            payload: payload
        )
    }

    public static func videoFragments(_ request: UltraGridVideoFragmentRequest) throws -> [RTPPacket] {
        try validateUltraGridPositive(request.maxPayloadBytes, "video.maxPayloadBytes")
        guard !request.framePayload.isEmpty else {
            throw UltraGridCompatibilityError.invalidField("video.framePayload", 0)
        }
        let headerBytes = UltraGridVideoRawFragmentPayload.headerByteCount
        guard request.maxPayloadBytes > headerBytes else {
            throw UltraGridCompatibilityError.invalidField("video.maxPayloadBytes", request.maxPayloadBytes)
        }
        let chunkSize = request.maxPayloadBytes - headerBytes
        let fragmentCount = UInt16((request.framePayload.count + chunkSize - 1) / chunkSize)
        var packets: [RTPPacket] = []
        for fragmentIndex in 0..<fragmentCount {
            let offset = Int(fragmentIndex) * chunkSize
            let end = min(request.framePayload.count, offset + chunkSize)
            let payload = try UltraGridVideoRawFragmentPayload(
                header: UltraGridVideoPayloadHeader(
                    bufferNumber: request.frameID,
                    payloadOffset: UInt32(offset),
                    payloadByteCount: UInt32(request.framePayload.count),
                    geometry: UltraGridVideoPayloadGeometry(
                        width: try uint16(request.width, "video.width"),
                        height: try uint16(request.height, "video.height"),
                        fourCC: try ultraGridRawVideoFourCC(bitsPerPixel: request.bitsPerPixel)
                    ),
                    timing: UltraGridVideoPayloadTiming(
                        frameRateNumerator: try uint16(request.frameRate, "video.frameRate")
                    )
                ),
                fragmentPayload: Data(request.framePayload[offset..<end])
            ).encoded()
            packets.append(RTPPacket(
                header: RTPPacketHeader(
                    payloadType: request.payloadType,
                    marker: fragmentIndex == fragmentCount - 1,
                    sequenceNumber: request.sequenceStart &+ fragmentIndex,
                    timestamp: request.timestamp,
                    ssrc: request.ssrc
                ),
                payload: payload
            ))
        }
        return packets
    }

    public static func decode(
        _ packet: RTPPacket,
        registry: UltraGridRTPPayloadRegistry = .default,
        encryptionConfiguration: UltraGridEncryptionConfiguration? = nil
    ) throws -> UltraGridCompatibilityDatagram {
        try UltraGridRTPPacketCodec.decode(
            packet,
            registry: registry,
            encryptionConfiguration: encryptionConfiguration
        )
    }

    public static func encryptedAudioPacket(
        _ packet: RTPPacket,
        configuration: UltraGridEncryptionConfiguration,
        // swiftlint:disable:next identifier_name
        iv: Data? = nil
    ) throws -> RTPPacket {
        try encryptedPacket(
            packet,
            encryptedPayloadType: encryptedAudioPayloadType,
            mediaHeaderByteCount: UltraGridAudioPayloadHeader.byteCount,
            configuration: configuration,
            iv: iv
        )
    }

    public static func encryptedVideoPacket(
        _ packet: RTPPacket,
        configuration: UltraGridEncryptionConfiguration,
        // swiftlint:disable:next identifier_name
        iv: Data? = nil
    ) throws -> RTPPacket {
        try encryptedPacket(
            packet,
            encryptedPayloadType: encryptedVideoPayloadType,
            mediaHeaderByteCount: UltraGridVideoPayloadHeader.byteCount,
            configuration: configuration,
            iv: iv
        )
    }

    private static func encryptedPacket(
        _ packet: RTPPacket,
        encryptedPayloadType: UInt8,
        mediaHeaderByteCount: Int,
        configuration: UltraGridEncryptionConfiguration,
        // swiftlint:disable:next identifier_name
        iv: Data?
    ) throws -> RTPPacket {
        guard packet.payload.count >= mediaHeaderByteCount else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: packet.payload.count)
        }
        let mediaHeader = packet.payload[..<mediaHeaderByteCount]
        let plaintext = packet.payload[mediaHeaderByteCount..<packet.payload.count]
        let ciphertext = try UltraGridOpenSSLEncryption.encrypt(
            plaintext: plaintext,
            aad: mediaHeader,
            configuration: configuration,
            iv: iv
        )
        var payload = Data(mediaHeader)
        payload.append(UltraGridCryptoPayloadHeader().encoded())
        payload.append(ciphertext)
        return RTPPacket(
            header: RTPPacketHeader(
                payloadType: encryptedPayloadType,
                marker: packet.header.marker,
                sequenceNumber: packet.header.sequenceNumber,
                timestamp: packet.header.timestamp,
                ssrc: packet.header.ssrc
            ),
            payload: payload
        )
    }

    public static func fecParityPacket(
        protecting packets: [RTPPacket],
        sequenceNumber: UInt16,
        timestamp: UInt32,
        ssrc: UInt32
    ) throws -> RTPPacket {
        try UltraGridFECRecovery.parityPacket(
            protecting: packets,
            sequenceNumber: sequenceNumber,
            timestamp: timestamp,
            ssrc: ssrc
        )
    }

    public static func recoverVideoFragments(from packets: [RTPPacket]) throws -> [UltraGridVideoRawFragmentPayload] {
        try UltraGridFECRecovery.recoverVideoFragments(from: packets)
    }

    public static func reassembleVideoFrame(_ fragments: [UltraGridVideoRawFragmentPayload]) throws -> Data {
        guard let first = fragments.first else {
            throw UltraGridCompatibilityError.reassemblyIncomplete(missing: [0])
        }
        let frameByteCount = Int(first.framePayloadByteCount)
        var byOffset: [Int: UltraGridVideoRawFragmentPayload] = [:]
        for fragment in fragments {
            guard fragment.frameID == first.frameID,
                  fragment.framePayloadByteCount == first.framePayloadByteCount else {
                throw UltraGridCompatibilityError.unsupportedMode("mixed-video-fragments")
            }
            byOffset[Int(fragment.payloadOffset)] = fragment
        }
        var output = Data(count: frameByteCount)
        var cursor = 0
        for start in byOffset.keys.sorted() {
            guard start == cursor, let fragment = byOffset[start] else {
                throw UltraGridCompatibilityError.reassemblyIncomplete(missing: [UInt16(clamping: cursor)])
            }
            output.replaceSubrange(start..<start + fragment.fragmentPayload.count, with: fragment.fragmentPayload)
            cursor += fragment.fragmentPayload.count
        }
        guard cursor == frameByteCount else {
            throw UltraGridCompatibilityError.reassemblyIncomplete(missing: [UInt16(clamping: cursor)])
        }
        return output
    }
}
