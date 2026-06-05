import Foundation

public enum LoLaCompatibilityCaptureDecoder {
    public static let maxInputByteCount = 16 * 1024 * 1024
    public static let maxPacketCount = 10_000
    public static let maxPacketByteCount = 1 * 1024 * 1024
    public static let maxJpegScanByteCount = 32 * 1024

    public static func decode(inputPath: String) throws -> LoLaCompatibilityCaptureReport {
        try decode(
            data: BoundedFileReader.data(atPath: inputPath, maxBytes: maxInputByteCount),
            inputPath: inputPath,
            capturedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    public static func decode(
        data: Data,
        inputPath: String,
        capturedAt: String
    ) throws -> LoLaCompatibilityCaptureReport {
        guard data.count <= maxInputByteCount else {
            throw LoLaCompatibilityCaptureDecodeError.inputTooLarge(data.count)
        }
        let parser = LoLaPacketCaptureParser(data: [UInt8](data))
        let result = try parser.parse()
        var unexpectedErrorCount = 0
        let packets = try result.packets.enumerated().map { index, captured in
            let decoded = try decodePacket(captured, index: index)
            unexpectedErrorCount += decoded.unexpectedErrorCount
            return decoded.report
        }
        let summary = LoLaCompatibilityCaptureSummary(packets: packets)
        let verdict: MeasurementVerdict = unexpectedErrorCount == 0
            && summary.packetCount > 0
            && summary.malformedPacketCount < summary.packetCount
            ? .partial
            : .fail
        return LoLaCompatibilityCaptureReport(
            id: "lola-compatibility-capture-\(sanitizedLoLaCaptureID(inputPath))",
            title: "LoLa compatibility passive capture decoder",
            capturedAt: capturedAt,
            inputPath: inputPath,
            inputFormat: result.format,
            summary: summary,
            packets: packets,
            verdict: verdict,
            evidenceBoundary: captureEvidenceBoundary,
            notes: captureNotes(unexpectedErrorCount: unexpectedErrorCount)
        )
    }

    private static func decodePacket(
        _ captured: LoLaCapturedPacket,
        index: Int
    ) throws -> DecodedCapturePacket {
        do {
            let udp = try LoLaIPv4UDPPacket.decode(captured.bytes)
            let stream = classify(sourcePort: udp.sourcePort, destinationPort: udp.destinationPort)
            let details = try decodePacketDetails(stream: stream, captured: captured, payload: udp.payload)
            return DecodedCapturePacket(
                report: LoLaCompatibilityCapturePacketReport(
                    index: index,
                    capturedLength: captured.bytes.count,
                    originalLength: captured.originalLength,
                    stream: stream,
                    sourceIP: udp.sourceIP,
                    destinationIP: udp.destinationIP,
                    sourcePort: udp.sourcePort,
                    destinationPort: udp.destinationPort,
                    payloadLength: udp.payload.count,
                    mediaEnvelopeValid: details.mediaEnvelopeValid,
                    mediaPayloadCandidate: details.media.candidate,
                    packetKind: details.media.packetKind,
                    frameID: details.media.frameID,
                    fragmentIndex: details.media.fragmentIndex,
                    fragmentCount: details.media.fragmentCount,
                    fragmentPayloadLength: details.media.fragmentPayloadLength,
                    serializedMediaPayloadLength: details.media.serializedMediaPayloadLength,
                    finalFragment: details.media.finalFragment,
                    controlMessageName: details.controlMessageName,
                    notes: details.notes
                ),
                unexpectedErrorCount: details.unexpectedErrorCount
            )
        } catch let error as LoLaCompatibilityCaptureDecodeError {
            throw error
        } catch {
            return DecodedCapturePacket(
                report: LoLaCompatibilityCapturePacketReport(
                    index: index,
                    capturedLength: captured.bytes.count,
                    originalLength: captured.originalLength,
                    stream: .malformed,
                    notes: ["Packet envelope decode failed: \(error)"]
                ),
                unexpectedErrorCount: 1
            )
        }
    }

    private static func decodePacketDetails(
        stream: LoLaCompatibilityCaptureStream,
        captured: LoLaCapturedPacket,
        payload: Data
    ) throws -> LoLaCapturePacketDetails {
        var details = LoLaCapturePacketDetails()
        if stream == .audio || stream == .video {
            try decodeMediaPacketDetails(
                stream: stream,
                captured: captured,
                payload: payload,
                details: &details
            )
        }
        if stream == .control {
            decodeControlPacketDetails(payload: payload, details: &details)
        }
        return details
    }

    private static func decodeMediaPacketDetails(
        stream: LoLaCompatibilityCaptureStream,
        captured: LoLaCapturedPacket,
        payload: Data,
        details: inout LoLaCapturePacketDetails
    ) throws {
        do {
            _ = try LoLaCompatibilityWireFrame.decode(captured.bytes)
            details.mediaEnvelopeValid = true
            details.media = try classifyMediaPayload(stream: stream, payload: payload)
        } catch let error as LoLaCompatibilityCaptureDecodeError {
            throw error
        } catch {
            details.unexpectedErrorCount += 1
            details.notes.append("LoLa media envelope check failed: \(error)")
        }
    }

    private static func decodeControlPacketDetails(
        payload: Data,
        details: inout LoLaCapturePacketDetails
    ) {
        guard let message = String(data: nulTerminatedControlPayload(payload), encoding: .utf8) else {
            details.notes.append("Control payload is not UTF-8 text.")
            return
        }
        do {
            details.controlMessageName = try LoLaCompatibilityControlMessage.parse(message).name
        } catch {
            details.notes.append("Control payload is not a recovered /MESG_* text message.")
        }
    }

    private static func captureNotes(unexpectedErrorCount: Int) -> String {
        let base = "Passive decoder output. It cannot promote LoLa A/V interoperability to PASS "
            + "without measured Windows-originated media capture evidence."
        guard unexpectedErrorCount > 0 else {
            return base
        }
        return "\(base) Unexpected packet processing errors: \(unexpectedErrorCount)."
    }

    private static var captureEvidenceBoundary: String {
        LoLaCompatibilityMediaModel.evidenceBoundary
            + " This capture decoder classifies Ethernet/IPv4/UDP envelopes, default LoLa ports, "
            + "visible text control messages, and source-level media packet kinds."
    }

    private static func classify(sourcePort: UInt16, destinationPort: UInt16) -> LoLaCompatibilityCaptureStream {
        let ports = Set([sourcePort, destinationPort])
        if ports.contains(7000) {
            return .control
        }
        if ports.contains(19788) {
            return .audio
        }
        if ports.contains(19798) {
            return .video
        }
        return .otherUDP
    }

    private static func classifyMediaPayload(
        stream: LoLaCompatibilityCaptureStream,
        payload: Data
    ) throws -> LoLaMediaPayloadClassification {
        switch stream {
        case .audio:
            return audioPayloadClassification(payload)
        case .video:
            return try videoPayloadClassification(payload)
        case .control, .otherUDP, .nonUDP, .malformed:
            return .unknown
        }
    }

    private static func audioPayloadClassification(_ payload: Data) -> LoLaMediaPayloadClassification {
        do {
            let decoded = try LoLaCompatibilityMediaCodec.decode(payload)
            guard let normal = decoded.normalFragment else { return .malformed }
            return .normalFragment(candidate: .audioFragment, packetKind: .audioFragment, normal: normal)
        } catch {
            return .malformed
        }
    }

    private static func videoPayloadClassification(_ payload: Data) throws -> LoLaMediaPayloadClassification {
        do {
            let decoded = try LoLaCompatibilityMediaCodec.decode(payload)
            if let prelude = decoded.videoPrelude {
                return .videoPrelude(prelude)
            }
            guard let normal = decoded.normalFragment else { return .malformed }
            let candidate: LoLaCompatibilityMediaPayloadCandidate = try containsJPEGFrame(normal.fragmentBytes)
                ? .mjpeg
                : .videoFragment
            return .normalFragment(candidate: candidate, packetKind: .videoFragment, normal: normal)
        } catch let error as LoLaCompatibilityCaptureDecodeError {
            throw error
        } catch {
            return try rawVideoPayloadClassification(payload)
        }
    }

    private static func rawVideoPayloadClassification(_ payload: Data) throws -> LoLaMediaPayloadClassification {
        if try containsJPEGFrame(payload) {
            return LoLaMediaPayloadClassification(candidate: .mjpeg)
        }
        return .malformed
    }

    private static func containsJPEGFrame(_ payload: Data) throws -> Bool {
        guard payload.count <= maxJpegScanByteCount else {
            throw LoLaCompatibilityCaptureDecodeError.payloadTooLarge(payload.count)
        }
        let bytes = [UInt8](payload)
        guard bytes.count >= 4 else {
            return false
        }
        for start in 0..<(bytes.count - 3) where hasJPEGStartMarker(bytes, at: start) {
            if containsJPEGEndMarker(bytes, after: start) { return true }
        }
        return false
    }

    private static func hasJPEGStartMarker(_ bytes: [UInt8], at start: Int) -> Bool {
        bytes[start] == 0xff
            && bytes[start + 1] == 0xd8
            && bytes[start + 2] == 0xff
            && isLikelyJPEGSegmentMarker(bytes[start + 3])
    }

    private static func containsJPEGEndMarker(_ bytes: [UInt8], after start: Int) -> Bool {
        for end in stride(from: bytes.count - 2, through: start + 2, by: -1)
            where bytes[end] == 0xff && bytes[end + 1] == 0xd9 {
            return true
        }
        return false
    }

    private static func isLikelyJPEGSegmentMarker(_ marker: UInt8) -> Bool {
        (0xe0...0xef).contains(marker) || marker == 0xdb || marker == 0xc0 || marker == 0xc2
    }

    private static func nulTerminatedControlPayload(_ payload: Data) -> Data {
        guard let terminatorIndex = payload.firstIndex(of: 0) else {
            return payload
        }
        return payload[..<terminatorIndex]
    }
}

private struct LoLaCapturedPacket: Equatable {
    var bytes: [UInt8]
    var originalLength: Int
}

private struct DecodedCapturePacket {
    var report: LoLaCompatibilityCapturePacketReport
    var unexpectedErrorCount: Int
}

private struct LoLaCapturePacketDetails {
    var mediaEnvelopeValid = false
    var media = LoLaMediaPayloadClassification.unknown
    var controlMessageName: String?
    var notes: [String] = []
    var unexpectedErrorCount = 0
}

private struct LoLaMediaPayloadClassification {
    var candidate: LoLaCompatibilityMediaPayloadCandidate
    var packetKind: LoLaCompatibilityMediaPacketKind?
    var frameID: UInt32?
    var fragmentIndex: Int?
    var fragmentCount: Int?
    var fragmentPayloadLength: Int?
    var serializedMediaPayloadLength: Int?
    var finalFragment: Bool?

    static let unknown = LoLaMediaPayloadClassification(candidate: .unknown)
    static let malformed = LoLaMediaPayloadClassification(
        candidate: .malformedFragment,
        packetKind: .malformedFragment
    )

    static func videoPrelude(_ prelude: LoLaCompatibilityVideoPrelude) -> LoLaMediaPayloadClassification {
        LoLaMediaPayloadClassification(
            candidate: .videoPrelude,
            packetKind: .videoPrelude,
            frameID: prelude.frameID,
            fragmentCount: prelude.fragmentCount,
            serializedMediaPayloadLength: prelude.serializedSize
        )
    }

    static func normalFragment(
        candidate: LoLaCompatibilityMediaPayloadCandidate,
        packetKind: LoLaCompatibilityMediaPacketKind,
        normal: LoLaCompatibilityNormalFragment
    ) -> LoLaMediaPayloadClassification {
        LoLaMediaPayloadClassification(
            candidate: candidate,
            packetKind: packetKind,
            frameID: normal.header.frameID,
            fragmentIndex: normal.header.fragmentIndex,
            fragmentCount: normal.header.fragmentCount,
            fragmentPayloadLength: normal.header.fragmentPayloadLength,
            serializedMediaPayloadLength: normal.body.map { 8 + $0.payloadLength },
            finalFragment: normal.header.finalFlag
        )
    }
}

private struct LoLaPacketCaptureParseResult {
    var format: LoLaCompatibilityCaptureFormat
    var packets: [LoLaCapturedPacket]
}

private struct LoLaPcapngBlock {
    var type: UInt32
    var offset: Int
    var length: Int
}

private struct LoLaPacketCaptureParser {
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

private enum LoLaCaptureEndian {
    case little
    case big
}

private struct LoLaIPv4UDPPacket {
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

private func sanitizedLoLaCaptureID(_ inputPath: String) -> String {
    let last = URL(fileURLWithPath: inputPath).lastPathComponent
    let scalars = last.unicodeScalars.map { scalar -> Character in
        CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar).lowercased()) : "-"
    }
    let value = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return value.isEmpty ? "capture" : value
}

private func readUInt16BE(_ bytes: [UInt8], offset: Int) -> UInt16 {
    NetworkByteReader.readUInt16BE(bytes, offset: offset)
}

private func readUInt32(_ bytes: [UInt8], offset: Int, endian: LoLaCaptureEndian) -> UInt32 {
    switch endian {
    case .little:
        NetworkByteReader.readUInt32LE(bytes, offset: offset)
    case .big:
        NetworkByteReader.readUInt32BE(bytes, offset: offset)
    }
}

private func ipv4String(_ bytes: [UInt8]) -> String {
    bytes.map(String.init).joined(separator: ".")
}
