// Parses LoLaCompatibilityCaptureParser input at the boundary, keeping syntax errors out of the domain implementation.
import Foundation

struct LoLaPacketCaptureParser {
    var data: [UInt8]

    func parse() throws -> LoLaPacketCaptureParseResult {
        if isClassicPcap {
            return try parseClassicPcap()
        }
        if isPcapng {
            return try parsePcapng()
        }
        throw LoLaCompatibilityCaptureDecodeError.unsupportedCaptureFormat
    }

    private var isClassicPcap: Bool {
        data.count >= 4
            && (
                Array(data[0..<4]) == [0xd4, 0xc3, 0xb2, 0xa1]
                    || Array(data[0..<4]) == [0xa1, 0xb2, 0xc3, 0xd4]
                    || Array(data[0..<4]) == [0x4d, 0x3c, 0xb2, 0xa1]
                    || Array(data[0..<4]) == [0xa1, 0xb2, 0x3c, 0x4d]
            )
    }

    private var isPcapng: Bool {
        data.count >= 12 && Array(data[0..<4]) == [0x0a, 0x0d, 0x0d, 0x0a]
    }

    private func parseClassicPcap() throws -> LoLaPacketCaptureParseResult {
        guard data.count >= 24 else {
            throw LoLaCompatibilityCaptureDecodeError.truncatedClassicPcapHeader
        }
        let endian = classicPcapEndian()
        let linkType = readUInt32(data, offset: 20, endian: endian)
        guard linkType == 1 else {
            throw LoLaCompatibilityCaptureDecodeError.unsupportedClassicPcapLinkType(linkType)
        }

        var packets: [LoLaCapturedPacket] = []
        var offset = 24
        while offset < data.count {
            guard offset + 16 <= data.count else {
                throw LoLaCompatibilityCaptureDecodeError.malformedClassicPcapRecord(packets.count)
            }
            let capturedLength = Int(readUInt32(data, offset: offset + 8, endian: endian))
            let originalLength = Int(readUInt32(data, offset: offset + 12, endian: endian))
            try validatePacketShape(capturedLength: capturedLength, packetCount: packets.count)
            let packetOffset = offset + 16
            guard packetOffset + capturedLength <= data.count else {
                throw LoLaCompatibilityCaptureDecodeError.malformedClassicPcapRecord(packets.count)
            }
            packets.append(LoLaCapturedPacket(
                bytes: Array(data[packetOffset..<packetOffset + capturedLength]),
                originalLength: originalLength
            ))
            offset = packetOffset + capturedLength
        }
        return LoLaPacketCaptureParseResult(format: .classicPcap, packets: packets)
    }

    private func classicPcapEndian() -> LoLaCaptureEndian {
        let magic = Array(data[0..<4])
        return magic == [0xd4, 0xc3, 0xb2, 0xa1] || magic == [0x4d, 0x3c, 0xb2, 0xa1]
            ? .little
            : .big
    }

    private func parsePcapng() throws -> LoLaPacketCaptureParseResult {
        guard data.count >= 28 else {
            throw LoLaCompatibilityCaptureDecodeError.malformedPcapngSection
        }
        let endian = try pcapngEndian()
        var packets: [LoLaCapturedPacket] = []
        var offset = 0
        while offset < data.count {
            let block = try pcapngBlock(at: offset, endian: endian, packetCount: packets.count)
            if let packet = try pcapngEnhancedPacket(block, endian: endian, packetCount: packets.count) {
                packets.append(packet)
            }
            offset += block.length
        }
        return LoLaPacketCaptureParseResult(format: .pcapng, packets: packets)
    }

    private func pcapngEndian() throws -> LoLaCaptureEndian {
        switch Array(data[8..<12]) {
        case [0x4d, 0x3c, 0x2b, 0x1a]:
            return .little
        case [0x1a, 0x2b, 0x3c, 0x4d]:
            return .big
        default:
            throw LoLaCompatibilityCaptureDecodeError.malformedPcapngSection
        }
    }

    private func pcapngBlock(
        at offset: Int,
        endian: LoLaCaptureEndian,
        packetCount: Int
    ) throws -> LoLaPcapngBlock {
        guard offset + 12 <= data.count else {
            throw LoLaCompatibilityCaptureDecodeError.malformedPcapngBlock(packetCount)
        }
        let block = LoLaPcapngBlock(
            type: readUInt32(data, offset: offset, endian: endian),
            offset: offset,
            length: Int(readUInt32(data, offset: offset + 4, endian: endian))
        )
        guard block.length >= 12, offset + block.length <= data.count else {
            throw LoLaCompatibilityCaptureDecodeError.malformedPcapngBlock(packetCount)
        }
        return block
    }

    private func pcapngEnhancedPacket(
        _ block: LoLaPcapngBlock,
        endian: LoLaCaptureEndian,
        packetCount: Int
    ) throws -> LoLaCapturedPacket? {
        guard block.type == 0x0000_0006 else { return nil }
        guard block.length >= 32 else {
            throw LoLaCompatibilityCaptureDecodeError.malformedPcapngBlock(packetCount)
        }
        let capturedLength = Int(readUInt32(data, offset: block.offset + 20, endian: endian))
        let originalLength = Int(readUInt32(data, offset: block.offset + 24, endian: endian))
        try validatePacketShape(capturedLength: capturedLength, packetCount: packetCount)
        let packetOffset = block.offset + 28
        guard packetOffset + capturedLength <= block.offset + block.length - 4 else {
            throw LoLaCompatibilityCaptureDecodeError.malformedPcapngBlock(packetCount)
        }
        return LoLaCapturedPacket(
            bytes: Array(data[packetOffset..<packetOffset + capturedLength]),
            originalLength: originalLength
        )
    }

    private func validatePacketShape(capturedLength: Int, packetCount: Int) throws {
        guard packetCount < LoLaCompatibilityCaptureDecoder.maxPacketCount else {
            throw LoLaCompatibilityCaptureDecodeError.packetCountTooLarge(packetCount + 1)
        }
        guard capturedLength <= LoLaCompatibilityCaptureDecoder.maxPacketByteCount else {
            throw LoLaCompatibilityCaptureDecodeError.payloadTooLarge(capturedLength)
        }
    }
}

enum LoLaCaptureEndian {
    case little
    case big
}

struct LoLaIPv4UDPPacket {
    var sourceIP: String
    var destinationIP: String
    var sourcePort: UInt16
    var destinationPort: UInt16
    var payload: Data

    static func decode(_ bytes: [UInt8]) throws -> LoLaIPv4UDPPacket {
        guard bytes.count >= LoLaCompatibilityMediaModel.wirePayloadOffset else {
            throw LoLaCompatibilityWireFrameError.truncatedFrame(bytes.count)
        }
        let etherType = readUInt16BE(bytes, offset: 12)
        guard etherType == LoLaCompatibilityWireFrame.etherTypeIPv4 else {
            throw LoLaCompatibilityWireFrameError.unsupportedEtherType(etherType)
        }
        let versionAndHeaderLength = bytes[14]
        guard versionAndHeaderLength >> 4 == 4 else {
            throw LoLaCompatibilityWireFrameError.unsupportedIPv4Header(versionAndHeaderLength)
        }
        let ipv4HeaderLength = Int(versionAndHeaderLength & 0x0f) * 4
        guard ipv4HeaderLength >= 20, bytes.count >= 14 + ipv4HeaderLength + 8 else {
            throw LoLaCompatibilityWireFrameError.unsupportedIPv4Header(versionAndHeaderLength)
        }
        guard bytes[23] == LoLaCompatibilityWireFrame.ipv4ProtocolUDP else {
            throw LoLaCompatibilityWireFrameError.unsupportedIPv4Protocol(bytes[23])
        }
        let totalLength = Int(readUInt16BE(bytes, offset: 16))
        guard totalLength <= bytes.count - 14 else {
            throw LoLaCompatibilityWireFrameError.ipv4TotalLengthMismatch(
                expected: totalLength,
                actual: bytes.count - 14
            )
        }
        let udpOffset = 14 + ipv4HeaderLength
        let udpLength = Int(readUInt16BE(bytes, offset: udpOffset + 4))
        guard udpLength >= 8, udpOffset + udpLength <= 14 + totalLength else {
            throw LoLaCompatibilityWireFrameError.udpLengthMismatch(
                expected: udpLength,
                actual: max(0, 14 + totalLength - udpOffset)
            )
        }
        let payloadOffset = udpOffset + 8
        return LoLaIPv4UDPPacket(
            sourceIP: ipv4String(Array(bytes[26..<30])),
            destinationIP: ipv4String(Array(bytes[30..<34])),
            sourcePort: readUInt16BE(bytes, offset: udpOffset),
            destinationPort: readUInt16BE(bytes, offset: udpOffset + 2),
            payload: Data(bytes[payloadOffset..<udpOffset + udpLength])
        )
    }
}

func sanitizedLoLaCaptureID(_ inputPath: String) -> String {
    let last = URL(fileURLWithPath: inputPath).lastPathComponent
    let scalars = last.unicodeScalars.map { scalar -> Character in
        CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar).lowercased()) : "-"
    }
    let value = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return value.isEmpty ? "capture" : value
}

func readUInt16BE(_ bytes: [UInt8], offset: Int) -> UInt16 {
    NetworkByteReader.readUInt16BE(bytes, offset: offset)
}

func readUInt32(_ bytes: [UInt8], offset: Int, endian: LoLaCaptureEndian) -> UInt32 {
    switch endian {
    case .little:
        NetworkByteReader.readUInt32LE(bytes, offset: offset)
    case .big:
        NetworkByteReader.readUInt32BE(bytes, offset: offset)
    }
}

func ipv4String(_ bytes: [UInt8]) -> String {
    bytes.map(String.init).joined(separator: ".")
}
