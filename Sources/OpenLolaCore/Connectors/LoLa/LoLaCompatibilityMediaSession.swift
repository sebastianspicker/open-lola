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

    public init(
        stream: LoLaCompatibilityMediaStream,
        sequenceNumber: Int,
        sourceHost: String? = nil,
        destinationHost: String? = nil,
        sourcePort: UInt16,
        destinationPort: UInt16,
        payloadByteCount: Int,
        wireByteCount: Int,
        envelopeValidated: Bool,
        packetKind: LoLaCompatibilityMediaPacketKind = .unknown,
        frameID: UInt32? = nil,
        fragmentIndex: Int? = nil,
        fragmentCount: Int? = nil,
        fragmentPayloadLength: Int? = nil,
        serializedMediaPayloadLength: Int? = nil,
        finalFragment: Bool? = nil,
        payloadConfidence: String,
        encodedFrame: Data
    ) {
        self.stream = stream
        self.sequenceNumber = sequenceNumber
        self.sourceHost = sourceHost
        self.destinationHost = destinationHost
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.payloadByteCount = payloadByteCount
        self.wireByteCount = wireByteCount
        self.envelopeValidated = envelopeValidated
        self.packetKind = packetKind
        self.frameID = frameID
        self.fragmentIndex = fragmentIndex
        self.fragmentCount = fragmentCount
        self.fragmentPayloadLength = fragmentPayloadLength
        self.serializedMediaPayloadLength = serializedMediaPayloadLength
        self.finalFragment = finalFragment
        self.payloadConfidence = payloadConfidence
        self.encodedFrame = encodedFrame
    }
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
    public var evidenceBoundary: String
    public var notes: String

    public var malformedFrameCount: Int {
        frames.filter { $0.packetKind == .malformedFragment }.count
    }

    public init(
        id: String,
        capturedAt: String,
        role: LoLaCompatibilityMediaSessionRole,
        mediaMode: ExternalConnectorMediaMode,
        frames: [LoLaCompatibilityMediaFrame],
        realLinkTransmitted: Bool,
        verdict: MeasurementVerdict,
        runtimeError: String? = nil,
        localHost: String? = nil,
        peer: String? = nil,
        audioPort: UInt16? = nil,
        videoPort: UInt16? = nil,
        timeoutSeconds: Int? = nil,
        expectedDatagramCount: Int? = nil,
        evidenceBoundary: String,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.role = role
        self.mediaMode = mediaMode
        self.frames = frames
        self.audioFrameCount = frames.filter { $0.stream == .audio }.count
        self.videoFrameCount = frames.filter { $0.stream == .video }.count
        self.totalWireBytes = frames.map(\.wireByteCount).reduce(0, +)
        self.envelopeValidatedFrameCount = frames.filter(\.envelopeValidated).count
        self.realLinkTransmitted = realLinkTransmitted
        self.verdict = verdict
        self.runtimeError = runtimeError
        self.localHost = localHost
        self.peer = peer
        self.audioPort = audioPort
        self.videoPort = videoPort
        self.timeoutSeconds = timeoutSeconds
        self.expectedDatagramCount = expectedDatagramCount
        self.evidenceBoundary = evidenceBoundary
        self.notes = notes
    }

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorSessionNonEmpty(evidenceBoundary, "evidenceBoundary")
        try requireExternalConnectorSessionNonEmpty(notes, "notes")
        guard verdict != .pass else {
            throw ExternalConnectorSessionError.dryRunCannotPass
        }
        if verdict == .fail {
            try requireExternalConnectorSessionNonEmpty(runtimeError ?? "", "runtimeError")
        }
        guard audioFrameCount == frames.filter({ $0.stream == .audio }).count else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("audioFrameCount", String(audioFrameCount))
        }
        guard videoFrameCount == frames.filter({ $0.stream == .video }).count else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("videoFrameCount", String(videoFrameCount))
        }
        guard totalWireBytes == frames.map(\.wireByteCount).reduce(0, +) else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("totalWireBytes", String(totalWireBytes))
        }
        guard envelopeValidatedFrameCount == frames.filter(\.envelopeValidated).count else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "envelopeValidatedFrameCount",
                String(envelopeValidatedFrameCount)
            )
        }
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
            if profile.audioEnabled {
                frames.append(contentsOf: try LoLaCompatibilityMediaCodec.audioFragments(
                    sequenceNumber: UInt32(sequence),
                    channels: configuration.channels
                ).map {
                    try makeFrame(
                        packet: $0,
                        sequenceNumber: sequence,
                        configuration: configuration,
                        port: configuration.audioPort,
                        sourceMAC: sourceMAC,
                        destinationMAC: destinationMAC
                    )
                })
            }
            if profile.videoEnabled {
                let payload = configuration.lolaVideoPayload == .generated
                    ? try LoLaVideoPayloadProvider.generatedRawVideoPayload(
                        configuration: configuration,
                        sequenceNumber: sequence
                    )
                    : capturedVideoPayloads[sequence]
                let packets = try LoLaCompatibilityMediaCodec.videoPackets(
                    sequenceNumber: UInt32(sequence),
                    payload: payload
                )
                frames.append(contentsOf: try packets.map {
                    try makeFrame(
                        packet: $0,
                        sequenceNumber: sequence,
                        configuration: configuration,
                        port: configuration.videoPort,
                        sourceMAC: sourceMAC,
                        destinationMAC: destinationMAC
                    )
                })
            }
        }
        return frames
    }

    private static func makeFrame(
        packet: LoLaCompatibilityMediaPacket,
        sequenceNumber: Int,
        configuration: ExternalConnectorSessionConfiguration,
        port: UInt16,
        sourceMAC: LoLaEthernetAddress?,
        destinationMAC: LoLaEthernetAddress?
    ) throws -> LoLaCompatibilityMediaFrame {
        try makeFrame(
            stream: packet.stream,
            sequenceNumber: sequenceNumber,
            configuration: configuration,
            payload: packet.payload,
            port: port,
            sourceMAC: sourceMAC,
            destinationMAC: destinationMAC,
            packetKind: packet.kind,
            frameID: packet.frameID,
            fragmentIndex: packet.fragmentIndex,
            fragmentCount: packet.fragmentCount,
            fragmentPayloadLength: packet.fragmentPayloadLength,
            serializedMediaPayloadLength: packet.serializedMediaPayloadLength,
            finalFragment: packet.finalFragment,
            payloadConfidence: payloadConfidence(for: packet.kind)
        )
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
            notes: "Source-level LoLa media TX frame generation uses recovered serialized bodies, audio fragments, video preludes, and video fragments. Real media attempts use the UDP socket or raw-link runners; PASS remains blocked until a responding Windows LoLa peer and measured capture exist."
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
            try LoLaCompatibilityMediaEnvelopeValidation.validateReceivedFrames(encodedFrames, configuration: configuration)
        }
        return report(
            role: .rx,
            mediaMode: configuration.mediaMode,
            frames: frames,
            realLinkTransmitted: false,
            verdict: malformedCount > 0 ? .fail : .partial,
            runtimeError: malformedCount > 0 ? "malformed LoLa media payloads: \(malformedCount)" : nil,
            notes: "Source-level LoLa media RX envelope validation decodes recovered prelude/fragment payload shapes where present. PASS remains blocked until measured Windows LoLa media capture exists."
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
            notes: "Source-level LoLa bidirectional media handoff covers TX frame generation and RX prelude/fragment validation in one tx-rx session. Real media attempts remain PARTIAL until a responding Windows LoLa peer and measured capture exist."
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
        makeLoLaMediaSessionReport(
            id: "lola-media-\(role.rawValue)-source-level",
            role: role,
            mediaMode: mediaMode,
            frames: frames,
            realLinkTransmitted: realLinkTransmitted,
            verdict: verdict,
            runtimeError: runtimeError,
            notes: notes
        )
    }

    private static func makeFrame(
        stream: LoLaCompatibilityMediaStream,
        sequenceNumber: Int,
        configuration: ExternalConnectorSessionConfiguration,
        payload: Data,
        port: UInt16,
        sourceMAC: LoLaEthernetAddress?,
        destinationMAC: LoLaEthernetAddress?,
        packetKind: LoLaCompatibilityMediaPacketKind,
        frameID: UInt32?,
        fragmentIndex: Int?,
        fragmentCount: Int?,
        fragmentPayloadLength: Int?,
        serializedMediaPayloadLength: Int?,
        finalFragment: Bool?,
        payloadConfidence: String
    ) throws -> LoLaCompatibilityMediaFrame {
        let frame = try LoLaCompatibilityWireFrame(
            destinationMAC: destinationMAC ?? LoLaEthernetAddress(octets: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
            sourceMAC: sourceMAC ?? LoLaEthernetAddress(octets: [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00]),
            sourceIP: try lolaIPv4(configuration.localHost),
            destinationIP: try lolaIPv4(configuration.peer.isEmpty ? "127.0.0.1" : configuration.peer),
            sourcePort: port,
            destinationPort: port,
            payload: payload
        )
        let encoded = try frame.encoded()
        _ = try LoLaCompatibilityWireFrame.decode(encoded)
        return LoLaCompatibilityMediaFrame(
            stream: stream,
            sequenceNumber: sequenceNumber,
            sourceHost: lolaIPv4HostString(frame.sourceIP),
            destinationHost: lolaIPv4HostString(frame.destinationIP),
            sourcePort: port,
            destinationPort: port,
            payloadByteCount: payload.count,
            wireByteCount: encoded.count,
            envelopeValidated: true,
            packetKind: packetKind,
            frameID: frameID,
            fragmentIndex: fragmentIndex,
            fragmentCount: fragmentCount,
            fragmentPayloadLength: fragmentPayloadLength,
            serializedMediaPayloadLength: serializedMediaPayloadLength,
            finalFragment: finalFragment,
            payloadConfidence: payloadConfidence,
            encodedFrame: encoded
        )
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
        let stream: LoLaCompatibilityMediaStream = packetKind == .videoPrelude || ports.contains(configuration.videoPort)
            ? .video
            : .audio
        let reportedPacketKind = stream == .audio && packetKind == .videoFragment ? .audioFragment : packetKind
        return LoLaCompatibilityMediaFrame(
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
        )
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
