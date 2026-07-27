// Defines JackTrip topology, hub-patch, and authentication options so launch parsing and handshake code share compatibility rules.
import Foundation

/// Defines the values accepted for JackTrip advanced mode codec.
public enum JackTripAdvancedModeCodec {
    public static func encodeTransportDatagram(
        _ packets: [JackTripAudioPacket],
        headerMode: JackTripPacketHeaderMode,
        transportMode: JackTripTransportMode,
        webTransportQuarterStreamID: UInt64 = 0
    ) throws -> Data {
        let payload = try JackTripAudioPayloadCodec.encodeDatagram(packets, headerMode: headerMode)
        switch transportMode {
        case .udp, .webRTC:
            return payload
        case .webTransport:
            return encodeQUICVarint(webTransportQuarterStreamID) + payload
        }
    }

    public static func decodeTransportDatagram<Bytes: DataProtocol>(
        _ data: Bytes,
        headerMode: JackTripPacketHeaderMode,
        transportMode: JackTripTransportMode,
        emptyHeaderTemplate: JackTripDefaultHeader? = nil
    ) throws -> [JackTripAudioPacket] {
        let payload: Data
        switch transportMode {
        case .udp, .webRTC:
            payload = Data(data)
        case .webTransport:
            let decoded = try decodeQUICVarint(data)
            payload = decoded.remainder
        }
        return try JackTripAudioPayloadCodec.decodeDatagram(
            payload,
            headerMode: headerMode,
            emptyHeaderTemplate: emptyHeaderTemplate
        )
    }

    public static func encodeOpusExtensionPacket(
        encodedOpusPayload: Data,
        sequenceNumber: UInt16,
        timestampMicroseconds: UInt64,
        channels: UInt8
    ) throws -> JackTripAudioPacket {
        try JackTripDefaultHeader(
            timestampMicroseconds: timestampMicroseconds,
            sequenceNumber: sequenceNumber,
            bufferSizeSamples: UInt16(OpusCELTLowDelayConstants.frameCount),
            sampleRate: try JackTripSampleRate(hertz: OpusCELTLowDelayConstants.sampleRateHertz),
            bitResolution: .bit32,
            incomingChannelsFromNetwork: channels,
            outgoingChannelsToNetwork: channels
        ).validate()
        guard !encodedOpusPayload.isEmpty,
              encodedOpusPayload.count <= OpusCELTLowDelayConstants.maxEncodedByteCount else {
            throw JackTripCompatibilityError.payloadLengthMismatch(
                expected: OpusCELTLowDelayConstants.maxEncodedByteCount,
                actual: encodedOpusPayload.count
            )
        }
        let expectedPayloadByteCount = OpusCELTLowDelayConstants.frameCount
            * Int(channels)
            * JackTripBitResolution.bit32.bytesPerSample
        var payload = Data([0x4f, 0x50, 0x55, 0x53])
        appendJackTripUInt16LE(UInt16(encodedOpusPayload.count), to: &payload)
        payload.append(encodedOpusPayload)
        if payload.count > expectedPayloadByteCount {
            throw JackTripCompatibilityError.payloadLengthMismatch(
                expected: expectedPayloadByteCount,
                actual: payload.count
            )
        }
        payload.append(Data(repeating: 0, count: expectedPayloadByteCount - payload.count))
        return try JackTripAudioPacket(
            header: JackTripDefaultHeader(
                timestampMicroseconds: timestampMicroseconds,
                sequenceNumber: sequenceNumber,
                bufferSizeSamples: UInt16(OpusCELTLowDelayConstants.frameCount),
                sampleRate: try JackTripSampleRate(hertz: OpusCELTLowDelayConstants.sampleRateHertz),
                bitResolution: .bit32,
                incomingChannelsFromNetwork: channels,
                outgoingChannelsToNetwork: channels
            ),
            planarAudioPayload: payload
        )
    }

    public static func decodeOpusExtensionPayload(_ packet: JackTripAudioPacket) throws -> Data {
        let bytes = [UInt8](packet.planarAudioPayload)
        guard bytes.count >= 6, bytes[0..<4] == [0x4f, 0x50, 0x55, 0x53] else {
            throw JackTripCompatibilityError.unsupportedMode("jacktrip-opus-extension-magic")
        }
        let byteCount = Int(readJackTripUInt16LE(bytes, offset: 4))
        guard bytes.count >= 6 + byteCount else {
            throw JackTripCompatibilityError.payloadLengthMismatch(
                expected: byteCount,
                actual: max(0, bytes.count - 6)
            )
        }
        return Data(bytes[6..<6 + byteCount])
    }

    public static func encodeWebRTCSignalingFrame(_ message: JackTripWebRTCSignalingMessage) throws -> Data {
        let payload = try JSONEncoder().encode(message)
        guard payload.count <= Int(UInt32.max) else {
            throw JackTripCompatibilityError.invalidField("webrtcSignalingPayloadBytes", payload.count)
        }
        var frame = Data()
        let length = UInt32(payload.count)
        frame.append(UInt8((length >> 24) & 0xff))
        frame.append(UInt8((length >> 16) & 0xff))
        frame.append(UInt8((length >> 8) & 0xff))
        frame.append(UInt8(length & 0xff))
        frame.append(payload)
        return frame
    }

    public static func decodeWebRTCSignalingFrame<Bytes: DataProtocol>(
        _ frame: Bytes
    ) throws -> JackTripWebRTCSignalingMessage {
        let bytes = [UInt8](frame)
        guard bytes.count >= 4 else {
            throw JackTripCompatibilityError.truncatedPacket(byteCount: bytes.count)
        }
        let length = (UInt32(bytes[0]) << 24)
            | (UInt32(bytes[1]) << 16)
            | (UInt32(bytes[2]) << 8)
            | UInt32(bytes[3])
        guard bytes.count - 4 == Int(length) else {
            throw JackTripCompatibilityError.payloadLengthMismatch(
                expected: Int(length),
                actual: bytes.count - 4
            )
        }
        return try JSONDecoder().decode(
            JackTripWebRTCSignalingMessage.self,
            from: Data(bytes[4..<bytes.count])
        )
    }

    private static func encodeQUICVarint(_ value: UInt64) -> Data {
        if value < 0x40 {
            return Data([UInt8(value)])
        }
        if value < 0x4000 {
            return Data([
                UInt8(((value >> 8) & 0x3f) | 0x40),
                UInt8(value & 0xff)
            ])
        }
        if value < 0x4000_0000 {
            return Data([
                UInt8(((value >> 24) & 0x3f) | 0x80),
                UInt8((value >> 16) & 0xff),
                UInt8((value >> 8) & 0xff),
                UInt8(value & 0xff)
            ])
        }
        return Data([
            UInt8(((value >> 56) & 0x3f) | 0xc0),
            UInt8((value >> 48) & 0xff),
            UInt8((value >> 40) & 0xff),
            UInt8((value >> 32) & 0xff),
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ])
    }

    private static func decodeQUICVarint<Bytes: DataProtocol>(
        _ data: Bytes
    ) throws -> (value: UInt64, remainder: Data) {
        let bytes = [UInt8](data)
        guard let first = bytes.first else {
            throw JackTripCompatibilityError.truncatedPacket(byteCount: 0)
        }
        let marker = first >> 6
        let length = 1 << marker
        guard bytes.count >= length else {
            throw JackTripCompatibilityError.truncatedPacket(byteCount: bytes.count)
        }
        var value = UInt64(first & 0x3f)
        for byte in bytes[1..<length] {
            value = (value << 8) | UInt64(byte)
        }
        return (value, Data(bytes[length..<bytes.count]))
    }
}

/// Carries WebRTC signaling type, protocol version, client identity, SDP, or ICE candidate data.
public struct JackTripWebRTCSignalingMessage: Codable, Equatable, Sendable {
    public var type: String
    public var protocolVersion: Int
    public var clientName: String?
    public var sdp: String?
    public var candidate: String?

    public init(
        type: String,
        protocolVersion: Int = 1,
        clientName: String? = nil,
        sdp: String? = nil,
        candidate: String? = nil
    ) {
        self.type = type
        self.protocolVersion = protocolVersion
        self.clientName = clientName
        self.sdp = sdp
        self.candidate = candidate
    }
}
