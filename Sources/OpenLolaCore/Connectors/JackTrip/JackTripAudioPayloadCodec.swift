// Encodes and decodes interleaved PCM bytes using the negotiated JackTrip bit resolution.
import Foundation

private enum JackTripFramedDatagramMode {
    case defaultHeader
    case jamLink

    var headerByteCount: Int {
        switch self {
        case .defaultHeader: JackTripDefaultHeader.byteCount
        case .jamLink: JackTripJamLinkHeader.byteCount
        }
    }

    func packetByteCount(_ bytes: [UInt8], offset: Int) throws -> Int {
        switch self {
        case .defaultHeader:
            guard let sampleRate = JackTripSampleRate(rawValue: bytes[offset + 12]) else {
                throw JackTripCompatibilityError.unsupportedMode("sample-rate-enum-\(bytes[offset + 12])")
            }
            guard let bitResolution = JackTripBitResolution(rawValue: bytes[offset + 13]) else {
                throw JackTripCompatibilityError.unsupportedMode("bit-resolution-enum-\(bytes[offset + 13])")
            }
            let header = try JackTripDefaultHeader(
                timestampMicroseconds: readJackTripUInt64LE(bytes, offset: offset),
                sequenceNumber: readJackTripUInt16LE(bytes, offset: offset + 8),
                bufferSizeSamples: readJackTripUInt16LE(bytes, offset: offset + 10),
                sampleRate: sampleRate,
                bitResolution: bitResolution,
                incomingChannelsFromNetwork: bytes[offset + 14],
                outgoingChannelsToNetwork: bytes[offset + 15]
            )
            return headerByteCount
                + Int(header.bufferSizeSamples)
                * header.payloadChannelCount
                * header.bitResolution.bytesPerSample
        case .jamLink:
            let header = try JackTripJamLinkHeader(
                common: readJackTripUInt16LE(bytes, offset: offset),
                sequenceNumber: readJackTripUInt16LE(bytes, offset: offset + 2),
                timestamp: readJackTripUInt32LE(bytes, offset: offset + 4)
            )
            return headerByteCount
                + Int(header.bufferSizeSamples)
                * Int(header.channelCount)
                * JackTripBitResolution.bit16.bytesPerSample
        }
    }

    func decodePacket(_ bytes: ArraySlice<UInt8>) throws -> JackTripAudioPacket {
        switch self {
        case .defaultHeader:
            try JackTripAudioPayloadCodec.decodeDefaultPacket(bytes)
        case .jamLink:
            try JackTripAudioPayloadCodec.decodeJamLinkPacket(bytes)
        }
    }
}

/// Defines the values accepted for JackTrip audio payload codec.
public enum JackTripAudioPayloadCodec {
    public static func encodeDatagram(
        _ packets: [JackTripAudioPacket],
        headerMode: JackTripPacketHeaderMode
    ) throws -> Data {
        switch headerMode {
        case .default:
            return try encodeDefaultDatagram(packets)
        case .jamLink:
            return try encodeJamLinkDatagram(packets)
        case .empty:
            return try encodeEmptyDatagram(packets)
        }
    }

    public static func decodeDatagram<Bytes: DataProtocol>(
        _ data: Bytes,
        headerMode: JackTripPacketHeaderMode,
        emptyHeaderTemplate: JackTripDefaultHeader? = nil
    ) throws -> [JackTripAudioPacket] {
        switch headerMode {
        case .default:
            return try decodeDefaultDatagram(data)
        case .jamLink:
            return try decodeJamLinkDatagram(data)
        case .empty:
            guard let emptyHeaderTemplate else {
                throw JackTripCompatibilityError.unsupportedMode("empty-header-missing-template")
            }
            return [try decodeEmptyPacket(data, template: emptyHeaderTemplate)]
        }
    }

    public static func encodeDefaultDatagram(_ packets: [JackTripAudioPacket]) throws -> Data {
        guard !packets.isEmpty else {
            throw JackTripCompatibilityError.invalidField("packets", 0)
        }
        var data = Data()
        for packet in packets {
            data.append(try encodeDefaultPacket(packet))
        }
        return data
    }

    public static func encodeEmptyDatagram(_ packets: [JackTripAudioPacket]) throws -> Data {
        guard packets.count == 1, let packet = packets.first else {
            throw JackTripCompatibilityError.unsupportedMode("empty-header-redundancy")
        }
        try packet.validate()
        return packet.planarAudioPayload
    }

    public static func encodeJamLinkDatagram(_ packets: [JackTripAudioPacket]) throws -> Data {
        guard !packets.isEmpty else {
            throw JackTripCompatibilityError.invalidField("packets", 0)
        }
        var data = Data()
        for packet in packets {
            data.append(try encodeJamLinkPacket(packet))
        }
        return data
    }

    public static func encodeJamLinkPacket(_ packet: JackTripAudioPacket) throws -> Data {
        try packet.validate()
        let header = try JackTripJamLinkHeader(packet: packet)
        var data = Data()
        data.reserveCapacity(JackTripJamLinkHeader.byteCount + packet.planarAudioPayload.count)
        appendJackTripUInt16LE(header.common, to: &data)
        appendJackTripUInt16LE(header.sequenceNumber, to: &data)
        appendJackTripUInt32LE(header.timestamp, to: &data)
        data.append(packet.planarAudioPayload)
        return data
    }

    public static func decodeJamLinkDatagram<Bytes: DataProtocol>(_ data: Bytes) throws -> [JackTripAudioPacket] {
        try decodeFramedDatagram(data, mode: .jamLink)
    }

    public static func decodeJamLinkPacket<Bytes: DataProtocol>(_ data: Bytes) throws -> JackTripAudioPacket {
        let bytes = [UInt8](data)
        guard bytes.count >= JackTripJamLinkHeader.byteCount else {
            throw JackTripCompatibilityError.truncatedPacket(byteCount: bytes.count)
        }
        let header = try JackTripJamLinkHeader(
            common: readJackTripUInt16LE(bytes, offset: 0),
            sequenceNumber: readJackTripUInt16LE(bytes, offset: 2),
            timestamp: readJackTripUInt32LE(bytes, offset: 4)
        )
        return try JackTripAudioPacket(
            header: header.defaultHeader(),
            planarAudioPayload: Data(bytes[JackTripJamLinkHeader.byteCount..<bytes.count])
        )
    }

    public static func decodeEmptyPacket<Bytes: DataProtocol>(
        _ data: Bytes,
        template: JackTripDefaultHeader
    ) throws -> JackTripAudioPacket {
        let payload = Data(data)
        return try JackTripAudioPacket(header: template, planarAudioPayload: payload)
    }

    public static func decodeDefaultDatagram<Bytes: DataProtocol>(_ data: Bytes) throws -> [JackTripAudioPacket] {
        try decodeFramedDatagram(data, mode: .defaultHeader)
    }

    private static func decodeFramedDatagram<Bytes: DataProtocol>(
        _ data: Bytes,
        mode: JackTripFramedDatagramMode
    ) throws -> [JackTripAudioPacket] {
        let bytes = [UInt8](data)
        guard !bytes.isEmpty else {
            throw JackTripCompatibilityError.truncatedPacket(byteCount: 0)
        }
        var packets: [JackTripAudioPacket] = []
        var offset = 0
        while offset < bytes.count {
            guard bytes.count - offset >= mode.headerByteCount else {
                throw JackTripCompatibilityError.truncatedPacket(byteCount: bytes.count - offset)
            }
            let packetByteCount = try mode.packetByteCount(bytes, offset: offset)
            guard bytes.count - offset >= packetByteCount else {
                throw JackTripCompatibilityError.payloadLengthMismatch(
                    expected: packetByteCount - mode.headerByteCount,
                    actual: max(0, bytes.count - offset - mode.headerByteCount)
                )
            }
            packets.append(try mode.decodePacket(bytes[offset..<offset + packetByteCount]))
            offset += packetByteCount
        }
        return packets
    }

    public static func encodeDefaultPacket(_ packet: JackTripAudioPacket) throws -> Data {
        try packet.header.validate()
        try packet.validate()
        var data = Data()
        data.reserveCapacity(JackTripDefaultHeader.byteCount + packet.planarAudioPayload.count)
        appendJackTripUInt64LE(packet.header.timestampMicroseconds, to: &data)
        appendJackTripUInt16LE(packet.header.sequenceNumber, to: &data)
        appendJackTripUInt16LE(packet.header.bufferSizeSamples, to: &data)
        data.append(packet.header.sampleRate.rawValue)
        data.append(packet.header.bitResolution.rawValue)
        data.append(packet.header.incomingChannelsFromNetwork)
        data.append(packet.header.outgoingChannelsToNetwork)
        data.append(packet.planarAudioPayload)
        return data
    }

    public static func decodeDefaultPacket<Bytes: DataProtocol>(_ data: Bytes) throws -> JackTripAudioPacket {
        let bytes = [UInt8](data)
        guard bytes.count >= JackTripDefaultHeader.byteCount else {
            throw JackTripCompatibilityError.truncatedPacket(byteCount: bytes.count)
        }
        guard let sampleRate = JackTripSampleRate(rawValue: bytes[12]) else {
            throw JackTripCompatibilityError.unsupportedMode("sample-rate-enum-\(bytes[12])")
        }
        guard let bitResolution = JackTripBitResolution(rawValue: bytes[13]) else {
            throw JackTripCompatibilityError.unsupportedMode("bit-resolution-enum-\(bytes[13])")
        }
        let header = try JackTripDefaultHeader(
            timestampMicroseconds: readJackTripUInt64LE(bytes, offset: 0),
            sequenceNumber: readJackTripUInt16LE(bytes, offset: 8),
            bufferSizeSamples: readJackTripUInt16LE(bytes, offset: 10),
            sampleRate: sampleRate,
            bitResolution: bitResolution,
            incomingChannelsFromNetwork: bytes[14],
            outgoingChannelsToNetwork: bytes[15]
        )
        let payload = Data(bytes[JackTripDefaultHeader.byteCount..<bytes.count])
        return try JackTripAudioPacket(header: header, planarAudioPayload: payload)
    }

}
