import Foundation

public struct LoLaEthernetAddress: Codable, Equatable, Sendable {
    public static let byteCount = 6

    public var octets: [UInt8]

    public init(octets: [UInt8]) throws {
        guard octets.count == Self.byteCount else {
            throw LoLaCompatibilityWireFrameError.invalidEthernetAddress(octets.count)
        }
        self.octets = octets
    }
}

public struct LoLaIPv4Address: Codable, Equatable, Sendable {
    public static let byteCount = 4

    public var octets: [UInt8]

    public init(octets: [UInt8]) throws {
        guard octets.count == Self.byteCount else {
            throw LoLaCompatibilityWireFrameError.invalidIPv4Address(octets.count)
        }
        self.octets = octets
    }
}

public enum LoLaCompatibilityWireFrameError: Error, Equatable, Sendable {
    case invalidEthernetAddress(Int)
    case invalidIPv4Address(Int)
    case payloadTooLarge(Int)
    case truncatedFrame(Int)
    case unsupportedEtherType(UInt16)
    case unsupportedIPv4Header(UInt8)
    case unsupportedIPv4Protocol(UInt8)
    case ipv4TotalLengthMismatch(expected: Int, actual: Int)
    case nonZeroTrailingBytes(expectedEndOffset: Int, actualByteCount: Int)
    case udpLengthMismatch(expected: Int, actual: Int)
    case invalidIPv4Checksum
    case invalidUDPChecksum
}

public struct LoLaCompatibilityWireFrame: Equatable, Sendable {
    // Ethernet, IPv4, and UDP header fields below are serialized in network byte order.
    public static let etherTypeIPv4: UInt16 = 0x0800
    public static let ipv4VersionAndHeaderLength: UInt8 = 0x45
    public static let ipv4ProtocolUDP: UInt8 = 0x11
    public static let defaultTTL: UInt8 = 0x80

    public var destinationMAC: LoLaEthernetAddress
    public var sourceMAC: LoLaEthernetAddress
    public var sourceIP: LoLaIPv4Address
    public var destinationIP: LoLaIPv4Address
    public var sourcePort: UInt16
    public var destinationPort: UInt16
    public var payload: Data

    public init(
        destinationMAC: LoLaEthernetAddress,
        sourceMAC: LoLaEthernetAddress,
        sourceIP: LoLaIPv4Address,
        destinationIP: LoLaIPv4Address,
        sourcePort: UInt16,
        destinationPort: UInt16,
        payload: Data
    ) {
        self.destinationMAC = destinationMAC
        self.sourceMAC = sourceMAC
        self.sourceIP = sourceIP
        self.destinationIP = destinationIP
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.payload = payload
    }

    public func encoded() throws -> Data {
        let udpLength = LoLaCompatibilityMediaModel.udpHeaderByteCount + payload.count
        let ipv4TotalLength = LoLaCompatibilityMediaModel.ipv4HeaderByteCount + udpLength
        guard ipv4TotalLength <= Int(UInt16.max) else {
            throw LoLaCompatibilityWireFrameError.payloadTooLarge(payload.count)
        }

        var data = Data()
        data.reserveCapacity(LoLaCompatibilityMediaModel.wirePayloadOffset + payload.count)
        data.append(contentsOf: destinationMAC.octets)
        data.append(contentsOf: sourceMAC.octets)
        appendLoLaUInt16BE(Self.etherTypeIPv4, to: &data)

        let ipv4HeaderOffset = data.count
        data.append(Self.ipv4VersionAndHeaderLength)
        data.append(0)
        appendLoLaUInt16BE(UInt16(ipv4TotalLength), to: &data)
        appendLoLaUInt16BE(LoLaCompatibilityMediaModel.ipv4Identification, to: &data)
        appendLoLaUInt16BE(0, to: &data)
        data.append(Self.defaultTTL)
        data.append(Self.ipv4ProtocolUDP)
        appendLoLaUInt16BE(0, to: &data)
        data.append(contentsOf: sourceIP.octets)
        data.append(contentsOf: destinationIP.octets)

        let ipv4HeaderEnd = ipv4HeaderOffset + LoLaCompatibilityMediaModel.ipv4HeaderByteCount
        let ipv4Header = Array(data[ipv4HeaderOffset..<ipv4HeaderEnd])
        let ipv4Checksum = loLaInternetChecksum(ipv4Header)
        data[ipv4HeaderOffset + 10] = UInt8(ipv4Checksum >> 8)
        data[ipv4HeaderOffset + 11] = UInt8(ipv4Checksum & 0xff)

        let udpHeaderOffset = data.count
        appendLoLaUInt16BE(sourcePort, to: &data)
        appendLoLaUInt16BE(destinationPort, to: &data)
        appendLoLaUInt16BE(UInt16(udpLength), to: &data)
        appendLoLaUInt16BE(0, to: &data)
        data.append(payload)

        let udpChecksum = loLaUDPChecksum(
            sourceIP: sourceIP.octets,
            destinationIP: destinationIP.octets,
            udpSegment: Array(data[udpHeaderOffset..<data.count])
        )
        data[udpHeaderOffset + 6] = UInt8(udpChecksum >> 8)
        data[udpHeaderOffset + 7] = UInt8(udpChecksum & 0xff)

        return data
    }

    public static func decode<Bytes: DataProtocol>(_ bytes: Bytes) throws -> LoLaCompatibilityWireFrame {
        let data = [UInt8](bytes)
        try validateMinimumFrameLength(data)
        try validateEthernetAndIPv4Header(data)

        let ipv4TotalLength = try validatedIPv4TotalLength(data)
        try validateRecoveredEnvelopePadding(data, ipv4TotalLength: ipv4TotalLength)
        try validateIPv4ProtocolAndChecksum(data)
        let udpLength = try validatedUDPLength(data, ipv4TotalLength: ipv4TotalLength)
        let udpSegmentEnd = LoLaCompatibilityMediaModel.ethernetHeaderByteCount
            + LoLaCompatibilityMediaModel.ipv4HeaderByteCount
            + udpLength
        let udpSegment = Array(data[34..<udpSegmentEnd])
        try validateUDPChecksum(data, udpSegment: udpSegment)

        return try decodedFrame(from: data, payloadEnd: udpSegmentEnd)
    }

    private static func validateMinimumFrameLength(_ data: [UInt8]) throws {
        guard data.count >= LoLaCompatibilityMediaModel.wirePayloadOffset else {
            throw LoLaCompatibilityWireFrameError.truncatedFrame(data.count)
        }
    }

    private static func validateEthernetAndIPv4Header(_ data: [UInt8]) throws {
        let etherType = readLoLaUInt16BE(data, offset: 12)
        guard etherType == etherTypeIPv4 else {
            throw LoLaCompatibilityWireFrameError.unsupportedEtherType(etherType)
        }
        guard data[14] == ipv4VersionAndHeaderLength else {
            throw LoLaCompatibilityWireFrameError.unsupportedIPv4Header(data[14])
        }
    }

    private static func validatedIPv4TotalLength(_ data: [UInt8]) throws -> Int {
        let ipv4TotalLength = Int(readLoLaUInt16BE(data, offset: 16))
        let actualIPv4Length = data.count - LoLaCompatibilityMediaModel.ethernetHeaderByteCount
        guard ipv4TotalLength <= actualIPv4Length else {
            throw LoLaCompatibilityWireFrameError.ipv4TotalLengthMismatch(
                expected: ipv4TotalLength,
                actual: actualIPv4Length
            )
        }
        return ipv4TotalLength
    }

    private static func validateRecoveredEnvelopePadding(_ data: [UInt8], ipv4TotalLength: Int) throws {
        let ipv4FrameEnd = LoLaCompatibilityMediaModel.ethernetHeaderByteCount + ipv4TotalLength
        guard ipv4FrameEnd < data.count else { return }

        let trailingBytes = data[ipv4FrameEnd..<data.count]
        guard trailingBytes.allSatisfy({ $0 == 0 }) else {
            throw LoLaCompatibilityWireFrameError.nonZeroTrailingBytes(
                expectedEndOffset: ipv4FrameEnd,
                actualByteCount: data.count
            )
        }
    }

    private static func validateIPv4ProtocolAndChecksum(_ data: [UInt8]) throws {
        guard data[23] == ipv4ProtocolUDP else {
            throw LoLaCompatibilityWireFrameError.unsupportedIPv4Protocol(data[23])
        }

        let ipv4Header = Array(data[14..<34])
        guard loLaInternetChecksum(ipv4Header) == 0 else {
            throw LoLaCompatibilityWireFrameError.invalidIPv4Checksum
        }
    }

    private static func validatedUDPLength(_ data: [UInt8], ipv4TotalLength: Int) throws -> Int {
        let udpLength = Int(readLoLaUInt16BE(data, offset: 38))
        let actualUDPLength = ipv4TotalLength - LoLaCompatibilityMediaModel.ipv4HeaderByteCount
        guard udpLength == actualUDPLength else {
            throw LoLaCompatibilityWireFrameError.udpLengthMismatch(
                expected: udpLength,
                actual: actualUDPLength
            )
        }
        return udpLength
    }

    private static func validateUDPChecksum(_ data: [UInt8], udpSegment: [UInt8]) throws {
        let udpChecksum = readLoLaUInt16BE(data, offset: 40)
        guard udpChecksum != 0 else { return }

        let computed = loLaInternetChecksum(loLaUDPPseudoHeader(
            sourceIP: Array(data[26..<30]),
            destinationIP: Array(data[30..<34]),
            udpSegment: udpSegment
        ))
        guard computed == 0 else {
            throw LoLaCompatibilityWireFrameError.invalidUDPChecksum
        }
    }

    private static func decodedFrame(from data: [UInt8], payloadEnd: Int) throws -> LoLaCompatibilityWireFrame {
        try LoLaCompatibilityWireFrame(
            destinationMAC: LoLaEthernetAddress(octets: Array(data[0..<6])),
            sourceMAC: LoLaEthernetAddress(octets: Array(data[6..<12])),
            sourceIP: LoLaIPv4Address(octets: Array(data[26..<30])),
            destinationIP: LoLaIPv4Address(octets: Array(data[30..<34])),
            sourcePort: readLoLaUInt16BE(data, offset: 34),
            destinationPort: readLoLaUInt16BE(data, offset: 36),
            payload: Data(data[LoLaCompatibilityMediaModel.wirePayloadOffset..<payloadEnd])
        )
    }
}

private func appendLoLaUInt16BE(_ value: UInt16, to data: inout Data) {
    // BE here is network byte order, independent of the host CPU's endianness.
    data.append(UInt8(value >> 8))
    data.append(UInt8(value & 0xff))
}

private func readLoLaUInt16BE(_ bytes: [UInt8], offset: Int) -> UInt16 {
    // BE here is network byte order, independent of the host CPU's endianness.
    NetworkByteReader.readUInt16BE(bytes, offset: offset)
}

private func loLaInternetChecksum(_ bytes: [UInt8]) -> UInt16 {
    var sum: UInt32 = 0
    var index = 0
    while index + 1 < bytes.count {
        sum += UInt32(UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1]))
        index += 2
    }
    if index < bytes.count {
        sum += UInt32(UInt16(bytes[index]) << 8)
    }
    while (sum >> 16) != 0 {
        sum = (sum & 0xffff) + (sum >> 16)
    }
    return UInt16(~sum & 0xffff)
}

private func loLaUDPChecksum(
    sourceIP: [UInt8],
    destinationIP: [UInt8],
    udpSegment: [UInt8]
) -> UInt16 {
    let checksum = loLaInternetChecksum(loLaUDPPseudoHeader(
        sourceIP: sourceIP,
        destinationIP: destinationIP,
        udpSegment: udpSegment
    ))
    return checksum == 0 ? 0xffff : checksum
}

private func loLaUDPPseudoHeader(
    sourceIP: [UInt8],
    destinationIP: [UInt8],
    udpSegment: [UInt8]
) -> [UInt8] {
    var pseudoHeader = Data()
    pseudoHeader.append(contentsOf: sourceIP)
    pseudoHeader.append(contentsOf: destinationIP)
    pseudoHeader.append(0)
    pseudoHeader.append(LoLaCompatibilityWireFrame.ipv4ProtocolUDP)
    appendLoLaUInt16BE(UInt16(udpSegment.count), to: &pseudoHeader)
    pseudoHeader.append(contentsOf: udpSegment)
    return [UInt8](pseudoHeader)
}
