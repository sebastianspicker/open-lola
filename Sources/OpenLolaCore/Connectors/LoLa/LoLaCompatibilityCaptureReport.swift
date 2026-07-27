// Decodes packet captures into LoLa control and media observations and validates the resulting report.
import Foundation

/// Defines the values accepted for LoLa compatibility capture decoder.
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
            identity: .init(
                id: "lola-compatibility-capture-\(sanitizedLoLaCaptureID(inputPath))",
                title: "LoLa compatibility passive capture decoder",
                capturedAt: capturedAt,
                inputPath: inputPath,
                inputFormat: result.format
            ),
            content: .init(summary: summary, packets: packets),
            outcome: .init(
                verdict: verdict,
                evidenceBoundary: captureEvidenceBoundary,
                notes: captureNotes(unexpectedErrorCount: unexpectedErrorCount)
            )
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
            return decodedPacket(
                captured: captured,
                index: index,
                udp: udp,
                stream: stream,
                details: details
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
                    metadata: .init(notes: ["Packet envelope decode failed: \(error)"])
                ),
                unexpectedErrorCount: 1
            )
        }
    }

    private static func decodedPacket(
        captured: LoLaCapturedPacket,
        index: Int,
        udp: LoLaIPv4UDPPacket,
        stream: LoLaCompatibilityCaptureStream,
        details: LoLaCapturePacketDetails
    ) -> DecodedCapturePacket {
        DecodedCapturePacket(
            report: LoLaCompatibilityCapturePacketReport(
                index: index,
                capturedLength: captured.bytes.count,
                originalLength: captured.originalLength,
                stream: stream,
                network: .init(
                    sourceIP: udp.sourceIP,
                    destinationIP: udp.destinationIP,
                    sourcePort: udp.sourcePort,
                    destinationPort: udp.destinationPort,
                    payloadLength: udp.payload.count
                ),
                media: .init(
                    envelopeValid: details.mediaEnvelopeValid,
                    payloadCandidate: details.media.candidate,
                    packetKind: details.media.packetKind,
                    frameID: details.media.frameID
                ),
                fragment: .init(
                    index: details.media.fragmentIndex,
                    count: details.media.fragmentCount,
                    payloadLength: details.media.fragmentPayloadLength,
                    serializedPayloadLength: details.media.serializedMediaPayloadLength,
                    final: details.media.finalFragment
                ),
                metadata: .init(controlMessageName: details.controlMessageName, notes: details.notes)
            ),
            unexpectedErrorCount: details.unexpectedErrorCount
        )
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
