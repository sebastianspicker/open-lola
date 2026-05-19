import Foundation

public enum AES67ST2110L24Profile {
    public static let payloadType: UInt8 = 96
    public static let clockRateHertz = 48_000
    public static let channelCount = 2
    public static let framesPerPacket = 48
    public static let packetTimeMilliseconds = 1
    public static let payloadByteCount = framesPerPacket * channelCount * 3
    public static let profileName = "aes67-st2110-l24"
}

public enum RTPPacketError: Error, Equatable, Sendable {
    case truncatedPacket(byteCount: Int)
    case unsupportedVersion(UInt8)
    case unsupportedPadding
    case unsupportedExtension
    case unsupportedCSRCCount(UInt8)
    case unsupportedPayloadType(UInt8)
    case invalidSSRC(UInt32)
    case payloadLengthMismatch(expected: Int, actual: Int)
    case sequenceDiscontinuity(expected: UInt16, actual: UInt16)
    case timestampStepMismatch(expected: UInt32, actual: UInt32)
    case ssrcMismatch(expected: UInt32, actual: UInt32)
}

public struct RTPPacketHeader: Codable, Equatable, Sendable {
    public static let byteCount = 12

    public var payloadType: UInt8
    public var marker: Bool
    public var sequenceNumber: UInt16
    public var timestamp: UInt32
    public var ssrc: UInt32

    public init(
        payloadType: UInt8 = AES67ST2110L24Profile.payloadType,
        marker: Bool = false,
        sequenceNumber: UInt16,
        timestamp: UInt32,
        ssrc: UInt32
    ) {
        self.payloadType = payloadType
        self.marker = marker
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.ssrc = ssrc
    }
}

public struct RTPPacket: Codable, Equatable, Sendable {
    public var header: RTPPacketHeader
    public var payload: Data

    public init(header: RTPPacketHeader, payload: Data) {
        self.header = header
        self.payload = payload
    }

    public static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> RTPPacket {
        let bytes = [UInt8](data)
        guard bytes.count >= RTPPacketHeader.byteCount else {
            throw RTPPacketError.truncatedPacket(byteCount: bytes.count)
        }
        let version = bytes[0] >> 6
        guard version == 2 else {
            throw RTPPacketError.unsupportedVersion(version)
        }
        guard bytes[0] & 0x20 == 0 else {
            throw RTPPacketError.unsupportedPadding
        }
        guard bytes[0] & 0x10 == 0 else {
            throw RTPPacketError.unsupportedExtension
        }
        let csrcCount = bytes[0] & 0x0f
        guard csrcCount == 0 else {
            throw RTPPacketError.unsupportedCSRCCount(csrcCount)
        }
        let payloadType = bytes[1] & 0x7f
        let marker = (bytes[1] & 0x80) != 0
        let sequenceNumber = readRTPUInt16BE(bytes, offset: 2)
        let timestamp = readRTPUInt32BE(bytes, offset: 4)
        let ssrc = readRTPUInt32BE(bytes, offset: 8)
        guard ssrc != 0 else {
            throw RTPPacketError.invalidSSRC(ssrc)
        }
        return RTPPacket(
            header: RTPPacketHeader(
                payloadType: payloadType,
                marker: marker,
                sequenceNumber: sequenceNumber,
                timestamp: timestamp,
                ssrc: ssrc
            ),
            payload: Data(bytes[RTPPacketHeader.byteCount..<bytes.count])
        )
    }

    public func encoded() throws -> Data {
        guard header.ssrc != 0 else {
            throw RTPPacketError.invalidSSRC(header.ssrc)
        }
        var data = Data()
        data.reserveCapacity(RTPPacketHeader.byteCount + payload.count)
        data.append(0x80)
        data.append((header.marker ? 0x80 : 0x00) | (header.payloadType & 0x7f))
        appendRTPUInt16BE(header.sequenceNumber, to: &data)
        appendRTPUInt32BE(header.timestamp, to: &data)
        appendRTPUInt32BE(header.ssrc, to: &data)
        data.append(payload)
        return data
    }
}

public enum L24PCMCodecError: Error, Equatable, Sendable {
    case invalidFloatPayloadByteCount(Int)
    case invalidL24PayloadByteCount(Int)
    case unsupportedChannelCount(Int)
    case unsupportedFrameCount(Int)
}

public enum L24PCMCodec {
    public static func encodeFloat32InterleavedStereo<Bytes: DataProtocol>(
        _ payload: Bytes,
        framesPerPacket: Int = AES67ST2110L24Profile.framesPerPacket
    ) throws -> Data {
        let bytes = [UInt8](payload)
        let sampleCount = framesPerPacket * AES67ST2110L24Profile.channelCount
        let expectedByteCount = sampleCount * MemoryLayout<Float>.size
        guard bytes.count == expectedByteCount else {
            throw L24PCMCodecError.invalidFloatPayloadByteCount(bytes.count)
        }
        var l24 = Data()
        l24.reserveCapacity(sampleCount * 3)
        for sampleIndex in 0..<sampleCount {
            let offset = sampleIndex * MemoryLayout<Float>.size
            let bitPattern = UInt32(bytes[offset])
                | UInt32(bytes[offset + 1]) << 8
                | UInt32(bytes[offset + 2]) << 16
                | UInt32(bytes[offset + 3]) << 24
            let sample = Float(bitPattern: bitPattern)
            appendL24Sample(sample, to: &l24)
        }
        return l24
    }

    public static func decodeFloat32InterleavedStereo(
        _ payload: Data,
        framesPerPacket: Int = AES67ST2110L24Profile.framesPerPacket
    ) throws -> Data {
        let sampleCount = framesPerPacket * AES67ST2110L24Profile.channelCount
        let expectedByteCount = sampleCount * 3
        guard payload.count == expectedByteCount else {
            throw L24PCMCodecError.invalidL24PayloadByteCount(payload.count)
        }
        let bytes = [UInt8](payload)
        var floats = Data()
        floats.reserveCapacity(sampleCount * MemoryLayout<Float>.size)
        for sampleIndex in 0..<sampleCount {
            let offset = sampleIndex * 3
            var value = UInt32(bytes[offset]) << 16
                | UInt32(bytes[offset + 1]) << 8
                | UInt32(bytes[offset + 2])
            if value & 0x80_0000 != 0 {
                value |= 0xFF00_0000
            }
            let signedValue = Int32(bitPattern: value)
            let sample = Float(signedValue) / 8_388_607.0
            appendFloat32LE(sample, to: &floats)
        }
        return floats
    }

    private static func appendL24Sample(_ sample: Float, to data: inout Data) {
        let clamped = min(max(sample, -1.0), 1.0)
        let scaled = Int32((clamped * 8_388_607.0).rounded())
        let unsigned = UInt32(bitPattern: scaled) & 0xFF_FFFF
        data.append(UInt8((unsigned >> 16) & 0xff))
        data.append(UInt8((unsigned >> 8) & 0xff))
        data.append(UInt8(unsigned & 0xff))
    }
}

public struct AES67ST2110L24RTPReceiveValidator: Sendable {
    public var expectedSSRC: UInt32?
    public private(set) var lostPackets: Int = 0
    private var nextSequenceNumber: UInt16?
    private var nextTimestamp: UInt32?

    public init(expectedSSRC: UInt32? = nil) {
        self.expectedSSRC = expectedSSRC
    }

    public mutating func validate(_ packet: RTPPacket) throws {
        guard packet.header.payloadType == AES67ST2110L24Profile.payloadType else {
            throw RTPPacketError.unsupportedPayloadType(packet.header.payloadType)
        }
        if let expectedSSRC {
            guard packet.header.ssrc == expectedSSRC else {
                throw RTPPacketError.ssrcMismatch(expected: expectedSSRC, actual: packet.header.ssrc)
            }
        } else {
            expectedSSRC = packet.header.ssrc
        }
        guard packet.payload.count == AES67ST2110L24Profile.payloadByteCount else {
            throw RTPPacketError.payloadLengthMismatch(
                expected: AES67ST2110L24Profile.payloadByteCount,
                actual: packet.payload.count
            )
        }
        if let nextSequenceNumber, packet.header.sequenceNumber != nextSequenceNumber {
            let sequenceGap = Int(UInt16(packet.header.sequenceNumber &- nextSequenceNumber))
            if sequenceGap > 0 && sequenceGap <= 1_024 {
                let skippedFrames = UInt32(sequenceGap) * UInt32(AES67ST2110L24Profile.framesPerPacket)
                let expectedTimestamp = nextTimestamp.map { $0 &+ skippedFrames }
                if let expectedTimestamp, packet.header.timestamp != expectedTimestamp {
                    throw RTPPacketError.timestampStepMismatch(
                        expected: expectedTimestamp,
                        actual: packet.header.timestamp
                    )
                }
                lostPackets += sequenceGap
            } else {
                throw RTPPacketError.sequenceDiscontinuity(
                    expected: nextSequenceNumber,
                    actual: packet.header.sequenceNumber
                )
            }
        } else if let nextTimestamp, packet.header.timestamp != nextTimestamp {
            throw RTPPacketError.timestampStepMismatch(
                expected: nextTimestamp,
                actual: packet.header.timestamp
            )
        }
        nextSequenceNumber = packet.header.sequenceNumber &+ 1
        nextTimestamp = packet.header.timestamp &+ UInt32(AES67ST2110L24Profile.framesPerPacket)
    }
}

public struct AES67ST2110L24SDP: Codable, Equatable, Sendable {
    public var address: String
    public var port: UInt16
    public var direction: MediaStreamDirection
    public var ptpEvidenceSummary: String?

    public init(
        address: String,
        port: UInt16,
        direction: MediaStreamDirection = .bidirectional,
        ptpEvidenceSummary: String? = nil
    ) {
        self.address = address
        self.port = port
        self.direction = direction
        self.ptpEvidenceSummary = ptpEvidenceSummary
    }

    public func text() -> String {
        var lines = [
            "v=0",
            "o=- 0 0 IN IP4 \(address)",
            "s=open-lola AES67 ST 2110-30 L24",
            "c=IN IP4 \(address)",
            "t=0 0",
            "m=audio \(port) RTP/AVP \(AES67ST2110L24Profile.payloadType)",
            "a=rtpmap:\(AES67ST2110L24Profile.payloadType) L24/\(AES67ST2110L24Profile.clockRateHertz)/\(AES67ST2110L24Profile.channelCount)",
            "a=ptime:\(AES67ST2110L24Profile.packetTimeMilliseconds)",
            "a=maxptime:\(AES67ST2110L24Profile.packetTimeMilliseconds)",
            "a=\(direction.sdpAttribute)",
        ]
        if let ptpEvidenceSummary, !ptpEvidenceSummary.isEmpty {
            lines.append("a=ts-refclk:ptp=IEEE1588-2019 \(ptpEvidenceSummary)")
            lines.append("a=mediaclk:direct=0")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func parse(_ text: String) throws -> AES67ST2110L24SDP {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard let media = lines.first(where: { $0.hasPrefix("m=audio ") }) else {
            throw AES67ST2110L24SDPError.missingLine("m=audio")
        }
        let mediaParts = media.split(separator: " ").map(String.init)
        guard mediaParts.count >= 4, let port = UInt16(mediaParts[1]) else {
            throw AES67ST2110L24SDPError.invalidLine(media)
        }
        guard mediaParts[2] == "RTP/AVP", mediaParts[3] == "\(AES67ST2110L24Profile.payloadType)" else {
            throw AES67ST2110L24SDPError.unsupportedMedia(media)
        }
        let rtpmap = "a=rtpmap:\(AES67ST2110L24Profile.payloadType) L24/\(AES67ST2110L24Profile.clockRateHertz)/\(AES67ST2110L24Profile.channelCount)"
        guard lines.contains(rtpmap) else {
            throw AES67ST2110L24SDPError.unsupportedRTPMap
        }
        guard lines.contains("a=ptime:\(AES67ST2110L24Profile.packetTimeMilliseconds)") else {
            throw AES67ST2110L24SDPError.unsupportedPacketTime
        }
        guard lines.contains("a=maxptime:\(AES67ST2110L24Profile.packetTimeMilliseconds)") else {
            throw AES67ST2110L24SDPError.unsupportedPacketTime
        }
        let address = lines.first(where: { $0.hasPrefix("c=IN IP4 ") })?.replacingOccurrences(of: "c=IN IP4 ", with: "")
            ?? "0.0.0.0"
        let direction = lines.compactMap(MediaStreamDirection.init(sdpAttribute:)).first ?? .bidirectional
        let ptp = lines.first(where: { $0.hasPrefix("a=ts-refclk:ptp=") })
        return AES67ST2110L24SDP(
            address: address,
            port: port,
            direction: direction,
            ptpEvidenceSummary: ptp
        )
    }
}

public enum AES67ST2110L24SDPError: Error, Equatable, Sendable {
    case missingLine(String)
    case invalidLine(String)
    case unsupportedMedia(String)
    case unsupportedRTPMap
    case unsupportedPacketTime
}

private extension MediaStreamDirection {
    var sdpAttribute: String {
        switch self {
        case .send:
            "sendonly"
        case .receive:
            "recvonly"
        case .bidirectional:
            "sendrecv"
        case .disabled:
            "inactive"
        }
    }

    init?(sdpAttribute line: String) {
        switch line {
        case "a=sendonly":
            self = .send
        case "a=recvonly":
            self = .receive
        case "a=sendrecv":
            self = .bidirectional
        case "a=inactive":
            self = .disabled
        default:
            return nil
        }
    }
}

private func appendFloat32LE(_ value: Float, to data: inout Data) {
    let bitPattern = value.bitPattern
    data.append(UInt8(bitPattern & 0xff))
    data.append(UInt8((bitPattern >> 8) & 0xff))
    data.append(UInt8((bitPattern >> 16) & 0xff))
    data.append(UInt8((bitPattern >> 24) & 0xff))
}

private func readRTPUInt16BE(_ bytes: [UInt8], offset: Int) -> UInt16 {
    NetworkByteReader.readUInt16BE(bytes, offset: offset)
}

private func readRTPUInt32BE(_ bytes: [UInt8], offset: Int) -> UInt32 {
    NetworkByteReader.readUInt32BE(bytes, offset: offset)
}

private func appendRTPUInt16BE(_ value: UInt16, to data: inout Data) {
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8(value & 0xff))
}

private func appendRTPUInt32BE(_ value: UInt32, to data: inout Data) {
    data.append(UInt8((value >> 24) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8(value & 0xff))
}
