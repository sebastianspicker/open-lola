// Runs role-aware LoLa media exchange and records frame, byte, and sequence evidence.
import Foundation

/// Defines the supported choices for LoLa compatibility media stream.
public enum LoLaCompatibilityMediaStream: String, Codable, Equatable, Sendable {
    case audio
    case video
}

/// Defines the supported choices for LoLa compatibility media session role.
public enum LoLaCompatibilityMediaSessionRole: String, Codable, Equatable, Sendable {
    // swiftlint:disable:next identifier_name
    case tx
    // swiftlint:disable:next identifier_name
    case rx
    case txRx = "tx-rx"
}

/// Defines the validated fields for LoLa compatibility media frame.
public struct LoLaCompatibilityMediaFrame: Codable, Equatable, Sendable {
    public struct Endpoints: Equatable, Sendable {
        public var sourceHost: String?
        public var destinationHost: String?
        public var sourcePort: UInt16
        public var destinationPort: UInt16

        public init(
            sourceHost: String? = nil,
            destinationHost: String? = nil,
            sourcePort: UInt16,
            destinationPort: UInt16
        ) {
            self.sourceHost = sourceHost
            self.destinationHost = destinationHost
            self.sourcePort = sourcePort
            self.destinationPort = destinationPort
        }
    }

    public struct Payload: Equatable, Sendable {
        public var byteCount: Int
        public var wireByteCount: Int
        public var confidence: String
        public var encodedFrame: Data

        public init(byteCount: Int, wireByteCount: Int, confidence: String, encodedFrame: Data) {
            self.byteCount = byteCount
            self.wireByteCount = wireByteCount
            self.confidence = confidence
            self.encodedFrame = encodedFrame
        }
    }

    public struct Fragment: Equatable, Sendable {
        public var packetKind: LoLaCompatibilityMediaPacketKind
        public var frameID: UInt32?
        public var index: Int?
        public var count: Int?
        public var payloadLength: Int?
        public var serializedMediaPayloadLength: Int?
        public var isFinal: Bool?

        public init(
            packetKind: LoLaCompatibilityMediaPacketKind,
            frameID: UInt32? = nil,
            index: Int? = nil,
            count: Int? = nil,
            payloadLength: Int? = nil,
            serializedMediaPayloadLength: Int? = nil,
            isFinal: Bool? = nil
        ) {
            self.packetKind = packetKind
            self.frameID = frameID
            self.index = index
            self.count = count
            self.payloadLength = payloadLength
            self.serializedMediaPayloadLength = serializedMediaPayloadLength
            self.isFinal = isFinal
        }
    }

    public struct Input: Equatable, Sendable {
        public var stream: LoLaCompatibilityMediaStream
        public var sequenceNumber: Int
        public var endpoints: Endpoints
        public var payload: Payload
        public var envelopeValidated: Bool
        public var fragment: Fragment

        public init(
            stream: LoLaCompatibilityMediaStream,
            sequenceNumber: Int,
            endpoints: Endpoints,
            payload: Payload,
            envelopeValidated: Bool,
            fragment: Fragment
        ) {
            self.stream = stream
            self.sequenceNumber = sequenceNumber
            self.endpoints = endpoints
            self.payload = payload
            self.envelopeValidated = envelopeValidated
            self.fragment = fragment
        }
    }

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

    public init(input: Input) {
        stream = input.stream
        sequenceNumber = input.sequenceNumber
        sourceHost = input.endpoints.sourceHost
        destinationHost = input.endpoints.destinationHost
        sourcePort = input.endpoints.sourcePort
        destinationPort = input.endpoints.destinationPort
        payloadByteCount = input.payload.byteCount
        wireByteCount = input.payload.wireByteCount
        envelopeValidated = input.envelopeValidated
        packetKind = input.fragment.packetKind
        frameID = input.fragment.frameID
        fragmentIndex = input.fragment.index
        fragmentCount = input.fragment.count
        fragmentPayloadLength = input.fragment.payloadLength
        serializedMediaPayloadLength = input.fragment.serializedMediaPayloadLength
        finalFragment = input.fragment.isFinal
        payloadConfidence = input.payload.confidence
        encodedFrame = input.payload.encodedFrame
    }
}

/// Runs role-aware LoLa media exchange and derives sent and received frame evidence.
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
            try frames.append(contentsOf: buildTransmitFramesForSequence(
                configuration: configuration,
                sequence: sequence,
                profile: profile,
                capturedVideoPayload: capturedVideoPayloads.indices.contains(sequence)
                    ? capturedVideoPayloads[sequence]
                    : nil,
                sourceMAC: sourceMAC,
                destinationMAC: destinationMAC
            ))
        }
        return frames
    }

    static func buildTransmitFramesForSequence(
        configuration: ExternalConnectorSessionConfiguration,
        sequence: Int,
        profile: ExternalConnectorMediaProfile? = nil,
        capturedVideoPayload: Data? = nil,
        sourceMAC: LoLaEthernetAddress? = nil,
        destinationMAC: LoLaEthernetAddress? = nil
    ) throws -> [LoLaCompatibilityMediaFrame] {
        let profile = try profile ?? ExternalConnectorMediaProfile.build(configuration: configuration)
        var frames = try audioTransmitFrames(
            sequence: sequence,
            profile: profile,
            configuration: configuration,
            sourceMAC: sourceMAC,
            destinationMAC: destinationMAC
        )
        try frames.append(contentsOf: videoTransmitFrames(LoLaCompatibilityVideoTransmitFrameRequest(
            sequence: sequence,
            profile: profile,
            configuration: configuration,
            capturedVideoPayload: capturedVideoPayload,
            sourceMAC: sourceMAC,
            destinationMAC: destinationMAC
        )))
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

    // swiftlint:disable:next type_name
    private struct LoLaCompatibilityVideoTransmitFrameRequest {
        var sequence: Int
        var profile: ExternalConnectorMediaProfile
        var configuration: ExternalConnectorSessionConfiguration
        var capturedVideoPayload: Data?
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
            capturedVideoPayload: request.capturedVideoPayload
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
        capturedVideoPayload: Data?
    ) throws -> Data {
        if configuration.lolaVideoPayload == .generated {
            return try LoLaVideoPayloadProvider.generatedRawVideoPayload(
                configuration: configuration,
                sequenceNumber: sequence
            )
        }
        guard let capturedVideoPayload else {
            throw LoLaVideoPayloadError.captureUnavailable
        }
        return capturedVideoPayload
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
        let receiveSource = loLaLoopbackTransmitConfiguration(from: configuration)
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

}

func loLaLoopbackTransmitConfiguration(
    from configuration: ExternalConnectorSessionConfiguration
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .tx,
        peer: configuration.localHost,
        outputPath: configuration.outputPath
    ) { input in
        input.localHost = configuration.peer.isEmpty ? "127.0.0.1" : configuration.peer
        input.controlTransport = configuration.controlTransport
        input.audioPort = configuration.audioPort
        input.videoPort = configuration.videoPort
        applyLoLaMediaFields(to: &input, from: configuration)
    })
}
