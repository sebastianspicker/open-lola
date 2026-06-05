import Foundation

public enum LoLaCompatibilityMediaStream: String, Codable, Equatable, Sendable {
    case audio
    case video
}

public enum LoLaCompatibilityMediaSessionRole: String, Codable, Equatable, Sendable {
    case tx
    case rx
    case txRx = "tx-rx"
}

public struct LoLaCompatibilityMediaFrameFields: Equatable, Sendable {
    public var stream: LoLaCompatibilityMediaStream
    public var sequenceNumber: Int
    public var sourceHost: String?
    public var destinationHost: String?
    public var sourcePort: UInt16
    public var destinationPort: UInt16
    public var payloadByteCount: Int
    public var wireByteCount: Int
    public var envelopeValidated: Bool
    public var packetKind: LoLaCompatibilityMediaPacketKind
    public var frameID: UInt32?
    public var fragmentIndex: Int?
    public var fragmentCount: Int?
    public var fragmentPayloadLength: Int?
    public var serializedMediaPayloadLength: Int?
    public var finalFragment: Bool?
    public var payloadConfidence: String
    public var encodedFrame: Data
}

public struct LoLaCompatibilityMediaFrame: Codable, Equatable, Sendable {
    public var stream: LoLaCompatibilityMediaStream
    public var sequenceNumber: Int
    public var sourceHost: String?
    public var destinationHost: String?
    public var sourcePort: UInt16
    public var destinationPort: UInt16
    public var payloadByteCount: Int
    public var wireByteCount: Int
    public var envelopeValidated: Bool
    public var packetKind: LoLaCompatibilityMediaPacketKind
    public var frameID: UInt32?
    public var fragmentIndex: Int?
    public var fragmentCount: Int?
    public var fragmentPayloadLength: Int?
    public var serializedMediaPayloadLength: Int?
    public var finalFragment: Bool?
    public var payloadConfidence: String
    public var encodedFrame: Data

    public init(fields: LoLaCompatibilityMediaFrameFields) {
        stream = fields.stream
        sequenceNumber = fields.sequenceNumber
        sourceHost = fields.sourceHost
        destinationHost = fields.destinationHost
        sourcePort = fields.sourcePort
        destinationPort = fields.destinationPort
        payloadByteCount = fields.payloadByteCount
        wireByteCount = fields.wireByteCount
        envelopeValidated = fields.envelopeValidated
        packetKind = fields.packetKind
        frameID = fields.frameID
        fragmentIndex = fields.fragmentIndex
        fragmentCount = fields.fragmentCount
        fragmentPayloadLength = fields.fragmentPayloadLength
        serializedMediaPayloadLength = fields.serializedMediaPayloadLength
        finalFragment = fields.finalFragment
        payloadConfidence = fields.payloadConfidence
        encodedFrame = fields.encodedFrame
    }
}

public struct LoLaCompatibilityMediaSessionReportFields: Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var role: LoLaCompatibilityMediaSessionRole
    public var mediaMode: ExternalConnectorMediaMode
    public var frames: [LoLaCompatibilityMediaFrame]
    public var realLinkTransmitted: Bool
    public var verdict: MeasurementVerdict
    public var runtimeError: String?
    public var localHost: String?
    public var peer: String?
    public var audioPort: UInt16?
    public var videoPort: UInt16?
    public var timeoutSeconds: Int?
    public var expectedDatagramCount: Int?
    public var sentBytesTotal: Int?
    public var evidenceBoundary: String
    public var notes: String
}

public struct LoLaCompatibilityMediaSessionReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var role: LoLaCompatibilityMediaSessionRole
    public var mediaMode: ExternalConnectorMediaMode
    public var frames: [LoLaCompatibilityMediaFrame]
    public var audioFrameCount: Int
    public var videoFrameCount: Int
    public var totalWireBytes: Int
    public var envelopeValidatedFrameCount: Int
    public var realLinkTransmitted: Bool
    public var verdict: MeasurementVerdict
    public var runtimeError: String?
    public var localHost: String?
    public var peer: String?
    public var audioPort: UInt16?
    public var videoPort: UInt16?
    public var timeoutSeconds: Int?
    public var expectedDatagramCount: Int?
    public var sentBytesTotal: Int?
    public var evidenceBoundary: String
    public var notes: String

    public var malformedFrameCount: Int {
        frames.filter { $0.packetKind == .malformedFragment }.count
    }

    public init(fields: LoLaCompatibilityMediaSessionReportFields) {
        id = fields.id
        capturedAt = fields.capturedAt
        role = fields.role
        mediaMode = fields.mediaMode
        frames = fields.frames
        audioFrameCount = fields.frames.filter { $0.stream == .audio }.count
        videoFrameCount = fields.frames.filter { $0.stream == .video }.count
        totalWireBytes = fields.frames.map(\.wireByteCount).reduce(0, +)
        envelopeValidatedFrameCount = fields.frames.filter(\.envelopeValidated).count
        realLinkTransmitted = fields.realLinkTransmitted
        verdict = fields.verdict
        runtimeError = fields.runtimeError
        localHost = fields.localHost
        peer = fields.peer
        audioPort = fields.audioPort
        videoPort = fields.videoPort
        timeoutSeconds = fields.timeoutSeconds
        expectedDatagramCount = fields.expectedDatagramCount
        sentBytesTotal = fields.sentBytesTotal
        evidenceBoundary = fields.evidenceBoundary
        notes = fields.notes
    }

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorSessionNonEmpty(evidenceBoundary, "evidenceBoundary")
        try requireExternalConnectorSessionNonEmpty(notes, "notes")
        try validateLoLaMediaSessionVerdict()
        try validateLoLaMediaSessionSentBytes()
        try validateLoLaMediaSessionFrameCounts()
    }

    private func validateLoLaMediaSessionVerdict() throws {
        guard verdict != .pass else { throw ExternalConnectorSessionError.dryRunCannotPass }
        if verdict == .fail {
            try requireExternalConnectorSessionNonEmpty(runtimeError ?? "", "runtimeError")
        }
    }

    private func validateLoLaMediaSessionSentBytes() throws {
        guard let sentBytesTotal else { return }
        guard sentBytesTotal >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("sentBytesTotal", String(sentBytesTotal))
        }
        if realLinkTransmitted, role != .rx, sentBytesTotal == 0, verdict != .fail {
            throw ExternalConnectorSessionError.socketFailed(
                "measured LoLa TX reported zero sent bytes without fail verdict"
            )
        }
    }

    private func validateLoLaMediaSessionFrameCounts() throws {
        try requireLoLaMediaSessionCount(
            audioFrameCount,
            expected: frames.filter { $0.stream == .audio }.count,
            field: "audioFrameCount"
        )
        try requireLoLaMediaSessionCount(
            videoFrameCount,
            expected: frames.filter { $0.stream == .video }.count,
            field: "videoFrameCount"
        )
        try requireLoLaMediaSessionCount(
            totalWireBytes,
            expected: frames.map(\.wireByteCount).reduce(0, +),
            field: "totalWireBytes"
        )
        try requireLoLaMediaSessionCount(
            envelopeValidatedFrameCount,
            expected: frames.filter(\.envelopeValidated).count,
            field: "envelopeValidatedFrameCount"
        )
    }
}

private func requireLoLaMediaSessionCount(_ actual: Int, expected: Int, field: String) throws {
    guard actual == expected else {
        throw ExternalConnectorSessionError.invalidPositiveInteger(field, String(actual))
    }
}

public enum LoLaCompatibilityMediaSession {
    public static func buildTransmitFrames(
        configuration: ExternalConnectorSessionConfiguration,
        frameCountPerStream: Int = 1,
        sourceMAC: LoLaEthernetAddress? = nil,
        destinationMAC: LoLaEthernetAddress? = nil
    ) throws -> [LoLaCompatibilityMediaFrame] {
        guard configuration.connector == .lola else {
            throw ExternalConnectorSessionError.invalidConnector(configuration.connector.rawValue)
        }
        guard frameCountPerStream > 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "frameCountPerStream",
                String(frameCountPerStream)
            )
        }
        let profile = try ExternalConnectorMediaProfile.build(configuration: configuration)
        let capturedVideoPayloads = profile.videoEnabled && configuration.lolaVideoPayload != .generated
            ? try LoLaVideoPayloadProvider.payloads(configuration: configuration, frameCount: frameCountPerStream)
            : []
        var frames: [LoLaCompatibilityMediaFrame] = []
        for sequence in 0..<frameCountPerStream {
            try frames.append(contentsOf: audioTransmitFrames(
                sequence: sequence,
                profile: profile,
                configuration: configuration,
                sourceMAC: sourceMAC,
                destinationMAC: destinationMAC
            ))
            try frames.append(contentsOf: videoTransmitFrames(LoLaCompatibilityVideoTransmitFrameRequest(
                sequence: sequence,
                profile: profile,
                configuration: configuration,
                capturedVideoPayloads: capturedVideoPayloads,
                sourceMAC: sourceMAC,
                destinationMAC: destinationMAC
            )))
        }
        return frames
    }

    private static func audioTransmitFrames(
        sequence: Int,
        profile: ExternalConnectorMediaProfile,
        configuration: ExternalConnectorSessionConfiguration,
        sourceMAC: LoLaEthernetAddress?,
        destinationMAC: LoLaEthernetAddress?
    ) throws -> [LoLaCompatibilityMediaFrame] {
        guard profile.audioEnabled else { return [] }
        let context = LoLaCompatibilityMediaFrameContext(
            sequenceNumber: sequence,
            configuration: configuration,
            port: configuration.audioPort,
            sourceMAC: sourceMAC,
            destinationMAC: destinationMAC
        )
        let packets = try LoLaCompatibilityMediaCodec.audioFragments(
            sequenceNumber: UInt32(sequence),
            channels: configuration.channels
        )
        return try packets.map { try makeFrame(packet: $0, context: context) }
    }

    private struct LoLaCompatibilityVideoTransmitFrameRequest {
        var sequence: Int
        var profile: ExternalConnectorMediaProfile
        var configuration: ExternalConnectorSessionConfiguration
        var capturedVideoPayloads: [Data]
        var sourceMAC: LoLaEthernetAddress?
        var destinationMAC: LoLaEthernetAddress?
    }

    private static func videoTransmitFrames(
        _ request: LoLaCompatibilityVideoTransmitFrameRequest
    ) throws -> [LoLaCompatibilityMediaFrame] {
        guard request.profile.videoEnabled else { return [] }
        let payload = try videoTransmitPayload(
            sequence: request.sequence,
            configuration: request.configuration,
            capturedVideoPayloads: request.capturedVideoPayloads
        )
        let packets = try LoLaCompatibilityMediaCodec.videoPackets(
            sequenceNumber: UInt32(request.sequence),
            payload: payload
        )
        let context = LoLaCompatibilityMediaFrameContext(
            sequenceNumber: request.sequence,
            configuration: request.configuration,
            port: request.configuration.videoPort,
            sourceMAC: request.sourceMAC,
            destinationMAC: request.destinationMAC
        )
        return try packets.map { try makeFrame(packet: $0, context: context) }
    }

    private static func videoTransmitPayload(
        sequence: Int,
        configuration: ExternalConnectorSessionConfiguration,
        capturedVideoPayloads: [Data]
    ) throws -> Data {
        if configuration.lolaVideoPayload == .generated {
            return try LoLaVideoPayloadProvider.generatedRawVideoPayload(
                configuration: configuration,
                sequenceNumber: sequence
            )
        }
        return capturedVideoPayloads[sequence]
    }

    private static func makeFrame(
        packet: LoLaCompatibilityMediaPacket,
        context: LoLaCompatibilityMediaFrameContext
    ) throws -> LoLaCompatibilityMediaFrame {
        try makeFrame(LoLaCompatibilityMediaFrameDraft(
            stream: packet.stream,
            sequenceNumber: context.sequenceNumber,
            configuration: context.configuration,
            payload: packet.payload,
            port: context.port,
            sourceMAC: context.sourceMAC,
            destinationMAC: context.destinationMAC,
            packetKind: packet.kind,
            frameID: packet.frameID,
            fragmentIndex: packet.fragmentIndex,
            fragmentCount: packet.fragmentCount,
            fragmentPayloadLength: packet.fragmentPayloadLength,
            serializedMediaPayloadLength: packet.serializedMediaPayloadLength,
            finalFragment: packet.finalFragment,
            payloadConfidence: payloadConfidence(for: packet.kind)
        ))
    }

    private static func payloadConfidence(for kind: LoLaCompatibilityMediaPacketKind) -> String {
        switch kind {
        case .audioFragment:
            "source-level recovered audio fragment: one normal fragment per 64-frame int16 block"
        case .videoPrelude:
            "source-level recovered video prelude before normal video fragments"
        case .videoFragment:
            "source-level recovered video fragment carrying generated raw/JPEG-compatible bytes"
        case .malformedFragment:
            "malformed recovered LoLa media fragment"
        case .unknown:
            "unknown LoLa media payload"
        }
    }

    public static func transmitReport(
        configuration: ExternalConnectorSessionConfiguration,
        frameCountPerStream: Int = 1,
        sourceMAC: LoLaEthernetAddress? = nil,
        destinationMAC: LoLaEthernetAddress? = nil
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let frames = try buildTransmitFrames(
            configuration: configuration,
            frameCountPerStream: frameCountPerStream,
            sourceMAC: sourceMAC,
            destinationMAC: destinationMAC
        )
        return report(
            role: .tx,
            mediaMode: configuration.mediaMode,
            frames: frames,
            realLinkTransmitted: false,
            notes: "Source-level LoLa media TX frame generation uses recovered serialized bodies, "
                + "audio fragments, video preludes, and video fragments. Real media attempts use "
                + "the UDP socket or raw-link runners; PASS remains blocked until a responding "
                + "Windows LoLa peer and measured capture exist."
        )
    }

    public static func receiveReport(
        configuration: ExternalConnectorSessionConfiguration,
        encodedFrames: [Data]
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let frames = try encodedFrames.enumerated().map { index, data in
            try decodeFrame(data, sequenceNumber: index, configuration: configuration)
        }
        let malformedCount = frames.filter { $0.packetKind == .malformedFragment }.count
        if malformedCount > 0 {
            try LoLaCompatibilityMediaEnvelopeValidation.validateReceivedWireEnvelopes(
                encodedFrames,
                configuration: configuration
            )
        } else {
            try LoLaCompatibilityMediaEnvelopeValidation.validateReceivedFrames(
                encodedFrames,
                configuration: configuration
            )
        }
        return report(
            role: .rx,
            mediaMode: configuration.mediaMode,
            frames: frames,
            realLinkTransmitted: false,
            verdict: malformedCount > 0 ? .fail : .partial,
            runtimeError: malformedCount > 0 ? "malformed LoLa media payloads: \(malformedCount)" : nil,
            notes: "Source-level LoLa media RX envelope validation decodes recovered prelude/fragment "
                + "payload shapes where present. PASS remains blocked until measured Windows LoLa "
                + "media capture exists."
        )
    }

    public static func bidirectionalReport(
        configuration: ExternalConnectorSessionConfiguration,
        frameCountPerStream: Int = 1,
        sourceMAC: LoLaEthernetAddress? = nil,
        destinationMAC: LoLaEthernetAddress? = nil
    ) throws -> LoLaCompatibilityMediaSessionReport {
        let transmitFrames = try buildTransmitFrames(
            configuration: configuration,
            frameCountPerStream: frameCountPerStream,
            sourceMAC: sourceMAC,
            destinationMAC: destinationMAC
        )
        let receiveSource = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .tx,
            peer: configuration.localHost,
            localHost: configuration.peer.isEmpty ? "127.0.0.1" : configuration.peer,
            outputPath: configuration.outputPath,
            mediaMode: configuration.mediaMode,
            controlTransport: configuration.controlTransport,
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            channels: configuration.channels,
            sampleRateHertz: configuration.sampleRateHertz,
            framesPerPacket: configuration.framesPerPacket,
            videoWidth: configuration.videoWidth,
            videoHeight: configuration.videoHeight,
            videoBitsPerPixel: configuration.videoBitsPerPixel
        )
        let receivedFrames = try buildTransmitFrames(
            configuration: receiveSource,
            frameCountPerStream: frameCountPerStream
        )
        return report(
            role: .txRx,
            mediaMode: configuration.mediaMode,
            frames: transmitFrames + receivedFrames,
            realLinkTransmitted: false,
            notes: "Source-level LoLa bidirectional media handoff covers TX frame generation and RX "
                + "prelude/fragment validation in one tx-rx session. Real media attempts remain "
                + "PARTIAL until a responding Windows LoLa peer and measured capture exist."
        )
    }

    private static func report(
        role: LoLaCompatibilityMediaSessionRole,
        mediaMode: ExternalConnectorMediaMode,
        frames: [LoLaCompatibilityMediaFrame],
        realLinkTransmitted: Bool,
        verdict: MeasurementVerdict = .partial,
        runtimeError: String? = nil,
        notes: String
    ) -> LoLaCompatibilityMediaSessionReport {
        makeLoLaMediaSessionReport(LoLaCompatibilityMediaSessionReportDraft(
            id: "lola-media-\(role.rawValue)-source-level",
            role: role,
            mediaMode: mediaMode,
            frames: frames,
            realLinkTransmitted: realLinkTransmitted,
            verdict: verdict,
            runtimeError: runtimeError,
            notes: notes
        ))
    }

    private struct LoLaCompatibilityMediaFrameContext {
        var sequenceNumber: Int
        var configuration: ExternalConnectorSessionConfiguration
        var port: UInt16
        var sourceMAC: LoLaEthernetAddress?
        var destinationMAC: LoLaEthernetAddress?
    }

    private struct LoLaCompatibilityMediaFrameDraft {
        var stream: LoLaCompatibilityMediaStream
        var sequenceNumber: Int
        var configuration: ExternalConnectorSessionConfiguration
        var payload: Data
        var port: UInt16
        var sourceMAC: LoLaEthernetAddress?
        var destinationMAC: LoLaEthernetAddress?
        var packetKind: LoLaCompatibilityMediaPacketKind
        var frameID: UInt32?
        var fragmentIndex: Int?
        var fragmentCount: Int?
        var fragmentPayloadLength: Int?
        var serializedMediaPayloadLength: Int?
        var finalFragment: Bool?
        var payloadConfidence: String
    }

    private static func makeFrame(
        _ draft: LoLaCompatibilityMediaFrameDraft
    ) throws -> LoLaCompatibilityMediaFrame {
        let frame = try LoLaCompatibilityWireFrame(
            destinationMAC: draft.destinationMAC ?? LoLaEthernetAddress(octets: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
            sourceMAC: draft.sourceMAC ?? LoLaEthernetAddress(octets: [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00]),
            sourceIP: try lolaIPv4(draft.configuration.localHost),
            destinationIP: try lolaIPv4(draft.configuration.peer.isEmpty ? "127.0.0.1" : draft.configuration.peer),
            sourcePort: draft.port,
            destinationPort: draft.port,
            payload: draft.payload
        )
        let encoded = try frame.encoded()
        _ = try LoLaCompatibilityWireFrame.decode(encoded)
        return LoLaCompatibilityMediaFrame(fields: LoLaCompatibilityMediaFrameFields(
            stream: draft.stream,
            sequenceNumber: draft.sequenceNumber,
            sourceHost: lolaIPv4HostString(frame.sourceIP),
            destinationHost: lolaIPv4HostString(frame.destinationIP),
            sourcePort: draft.port,
            destinationPort: draft.port,
            payloadByteCount: draft.payload.count,
            wireByteCount: encoded.count,
            envelopeValidated: true,
            packetKind: draft.packetKind,
            frameID: draft.frameID,
            fragmentIndex: draft.fragmentIndex,
            fragmentCount: draft.fragmentCount,
            fragmentPayloadLength: draft.fragmentPayloadLength,
            serializedMediaPayloadLength: draft.serializedMediaPayloadLength,
            finalFragment: draft.finalFragment,
            payloadConfidence: draft.payloadConfidence,
            encodedFrame: encoded
        ))
    }

    private static func decodeFrame(
        _ data: Data,
        sequenceNumber: Int,
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> LoLaCompatibilityMediaFrame {
        let decoded = try LoLaCompatibilityWireFrame.decode(data)
        let decodedMedia = try? LoLaCompatibilityMediaCodec.decode(decoded.payload)
        let packetKind = decodedMedia?.kind ?? .malformedFragment
        let normal = decodedMedia?.normalFragment
        let prelude = decodedMedia?.videoPrelude
        let ports = Set([decoded.sourcePort, decoded.destinationPort])
        let stream: LoLaCompatibilityMediaStream = packetKind == .videoPrelude
            || ports.contains(configuration.videoPort)
            ? .video
            : .audio
        let reportedPacketKind = stream == .audio && packetKind == .videoFragment ? .audioFragment : packetKind
        return LoLaCompatibilityMediaFrame(fields: LoLaCompatibilityMediaFrameFields(
            stream: stream,
            sequenceNumber: sequenceNumber,
            sourceHost: lolaIPv4HostString(decoded.sourceIP),
            destinationHost: lolaIPv4HostString(decoded.destinationIP),
            sourcePort: decoded.sourcePort,
            destinationPort: decoded.destinationPort,
            payloadByteCount: decoded.payload.count,
            wireByteCount: data.count,
            envelopeValidated: true,
            packetKind: reportedPacketKind,
            frameID: normal?.header.frameID ?? prelude?.frameID,
            fragmentIndex: normal?.header.fragmentIndex,
            fragmentCount: normal?.header.fragmentCount ?? prelude?.fragmentCount,
            fragmentPayloadLength: normal?.header.fragmentPayloadLength,
            serializedMediaPayloadLength: prelude?.serializedSize,
            finalFragment: normal?.header.finalFlag,
            payloadConfidence: payloadConfidence(for: reportedPacketKind),
            encodedFrame: data
        ))
    }

}

private func lolaIPv4(_ value: String) throws -> LoLaIPv4Address {
    let parts = value.split(separator: ".")
    guard parts.count == 4 else {
        throw ExternalConnectorSessionError.socketFailed("invalid IPv4 \(value)")
    }
    let octets = try parts.map { part -> UInt8 in
        guard let octet = UInt8(part) else {
            throw ExternalConnectorSessionError.socketFailed("invalid IPv4 \(value)")
        }
        return octet
    }
    return try LoLaIPv4Address(octets: octets)
}

private func lolaIPv4HostString(_ address: LoLaIPv4Address) -> String {
    address.octets.map(String.init).joined(separator: ".")
}
