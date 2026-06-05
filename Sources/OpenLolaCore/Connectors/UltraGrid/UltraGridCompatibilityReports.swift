import Foundation

public struct UltraGridCompatibilityDatagram: Codable, Equatable, Sendable {
    public var stream: LoLaCompatibilityMediaStream
    public var sourceHost: String?
    public var sourcePort: UInt16?
    public var destinationPort: UInt16
    public var rtp: RTPPacket

    public init(
        stream: LoLaCompatibilityMediaStream,
        sourceHost: String? = nil,
        sourcePort: UInt16? = nil,
        destinationPort: UInt16,
        rtp: RTPPacket
    ) {
        self.stream = stream
        self.sourceHost = sourceHost
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.rtp = rtp
    }
}

public struct UltraGridVideoFragmentRequest: Equatable, Sendable {
    public var framePayload: Data
    public var frameID: UInt32
    public var sequenceStart: UInt16
    public var timestamp: UInt32
    public var ssrc: UInt32
    public var width: Int
    public var height: Int
    public var frameRate: Int
    public var bitsPerPixel: Int
    public var payloadType: UInt8
    public var maxPayloadBytes: Int

    public init(
        frame: UltraGridVideoFragmentFrame,
        transport: UltraGridVideoFragmentTransport
    ) {
        self.framePayload = frame.payload
        self.frameID = frame.id
        self.sequenceStart = transport.sequenceStart
        self.timestamp = transport.timestamp
        self.ssrc = transport.ssrc
        self.width = frame.width
        self.height = frame.height
        self.frameRate = frame.frameRate
        self.bitsPerPixel = frame.bitsPerPixel
        self.payloadType = transport.payloadType
        self.maxPayloadBytes = transport.maxPayloadBytes
    }
}

public struct UltraGridVideoFragmentFrame: Equatable, Sendable {
    public var payload: Data
    public var id: UInt32
    public var width: Int
    public var height: Int
    public var frameRate: Int
    public var bitsPerPixel: Int

    public init(
        payload: Data,
        id: UInt32,
        width: Int,
        height: Int,
        frameRate: Int,
        bitsPerPixel: Int
    ) {
        self.payload = payload
        self.id = id
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.bitsPerPixel = bitsPerPixel
    }
}

public struct UltraGridVideoFragmentTransport: Equatable, Sendable {
    public var sequenceStart: UInt16
    public var timestamp: UInt32
    public var ssrc: UInt32
    public var payloadType: UInt8
    public var maxPayloadBytes: Int

    public init(
        sequenceStart: UInt16,
        timestamp: UInt32,
        ssrc: UInt32,
        payloadType: UInt8 = UltraGridCompatibility.videoPayloadType,
        maxPayloadBytes: Int = 1_200
    ) {
        self.sequenceStart = sequenceStart
        self.timestamp = timestamp
        self.ssrc = ssrc
        self.payloadType = payloadType
        self.maxPayloadBytes = maxPayloadBytes
    }
}

public struct UltraGridAudioPacketRequest: Equatable, Sendable {
    public var sequenceNumber: UInt16
    public var timestamp: UInt32
    public var ssrc: UInt32
    public var channels: Int
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var pcmPayload: Data
    public var payloadType: UInt8

    public init(
        sequenceNumber: UInt16,
        timestamp: UInt32,
        ssrc: UInt32,
        channels: Int,
        sampleRateHertz: Int,
        framesPerPacket: Int,
        pcmPayload: Data,
        payloadType: UInt8 = UltraGridCompatibility.audioPayloadType
    ) {
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.ssrc = ssrc
        self.channels = channels
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.pcmPayload = pcmPayload
        self.payloadType = payloadType
    }
}

public enum UltraGridTopologyState: String, Codable, Equatable, Sendable {
    case directPeerReady = "direct-peer-ready"
    case serverListening = "server-listening"
    case clientReady = "client-ready"
}

public struct UltraGridTopologyReport: Codable, Equatable, Sendable {
    public var mode: UltraGridTopologyMode
    public var role: UltraGridTopologyRole
    public var state: UltraGridTopologyState
    public var peerRequired: Bool
    public var peerConfigured: Bool
    public var localHost: String
    public var peer: String
    public var notes: String

    public init(
        mode: UltraGridTopologyMode,
        role: UltraGridTopologyRole,
        state: UltraGridTopologyState,
        peerRequired: Bool,
        peerConfigured: Bool,
        localHost: String,
        peer: String,
        notes: String
    ) {
        self.mode = mode
        self.role = role
        self.state = state
        self.peerRequired = peerRequired
        self.peerConfigured = peerConfigured
        self.localHost = localHost
        self.peer = peer
        self.notes = notes
    }

    public func validate(fieldPrefix: String) throws {
        try requireExternalConnectorSessionNonEmpty(localHost, "\(fieldPrefix).localHost")
        try requireExternalConnectorSessionNonEmpty(notes, "\(fieldPrefix).notes")
        if peerRequired {
            try requireExternalConnectorSessionNonEmpty(peer, "\(fieldPrefix).peer")
        }
        if mode == .directPeer, role != .direct {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("ultragrid-topology-role-\(role.rawValue)")
        }
        if mode == .serverClient, role == .direct {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("ultragrid-topology-role-direct")
        }
    }
}

public struct UltraGridCompatibilityMediaIdentity: Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var role: ExternalConnectorSessionRole
    public var mediaMode: ExternalConnectorMediaMode

    public init(
        id: String,
        capturedAt: String,
        role: ExternalConnectorSessionRole,
        mediaMode: ExternalConnectorMediaMode
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.role = role
        self.mediaMode = mediaMode
    }
}

public struct UltraGridCompatibilityPacketSummary: Equatable, Sendable {
    public var datagrams: [UltraGridCompatibilityDatagram]
    public var transmittedDatagramCount: Int
    public var receivedDatagramCount: Int

    public init(
        datagrams: [UltraGridCompatibilityDatagram],
        transmittedDatagramCount: Int,
        receivedDatagramCount: Int
    ) {
        self.datagrams = datagrams
        self.transmittedDatagramCount = transmittedDatagramCount
        self.receivedDatagramCount = receivedDatagramCount
    }
}

public struct UltraGridCompatibilityQualityCounters: Equatable, Sendable {
    public var rtpPacketsLost: Int
    public var rtpDuplicatePacketCount: Int
    public var rtpOutOfOrderPacketCount: Int
    public var rtpSsrcChangeCount: Int
    public var rtpTimestampRegressionCount: Int
    public var rtpJitterLikeArrivalDeltaCount: Int
    public var videoFrameReassemblyFailureCount: Int

    public init(
        rtpPacketsLost: Int = 0,
        rtpDuplicatePacketCount: Int = 0,
        rtpOutOfOrderPacketCount: Int = 0,
        rtpSsrcChangeCount: Int = 0,
        rtpTimestampRegressionCount: Int = 0,
        rtpJitterLikeArrivalDeltaCount: Int = 0,
        videoFrameReassemblyFailureCount: Int = 0
    ) {
        self.rtpPacketsLost = rtpPacketsLost
        self.rtpDuplicatePacketCount = rtpDuplicatePacketCount
        self.rtpOutOfOrderPacketCount = rtpOutOfOrderPacketCount
        self.rtpSsrcChangeCount = rtpSsrcChangeCount
        self.rtpTimestampRegressionCount = rtpTimestampRegressionCount
        self.rtpJitterLikeArrivalDeltaCount = rtpJitterLikeArrivalDeltaCount
        self.videoFrameReassemblyFailureCount = videoFrameReassemblyFailureCount
    }
}

public struct UltraGridCompatibilityNestedReports: Equatable, Sendable {
    public static let defaultTopology = UltraGridTopologyReport(
        mode: .directPeer,
        role: .direct,
        state: .directPeerReady,
        peerRequired: false,
        peerConfigured: false,
        localHost: "0.0.0.0",
        peer: "",
        notes: "Direct peer UltraGrid topology."
    )
    public static let defaultControl = UltraGridControlReport(
        mode: .disabled,
        port: 5054,
        state: .disabled,
        commands: [],
        notes: "UltraGrid control socket modeling is disabled for this run."
    )
    public static let defaultProvider = ExternalConnectorMediaProviderReport(
        audioSource: "synthetic",
        videoSource: "synthetic",
        observedEvidenceClasses: [.synthetic],
        notes: "Synthetic UltraGrid media provider."
    )
    public static let defaultSink = ExternalConnectorMediaSinkReport(
        notes: "No UltraGrid RX sink media was decoded for this role."
    )

    public var topology: UltraGridTopologyReport
    public var control: UltraGridControlReport
    public var provider: ExternalConnectorMediaProviderReport
    public var sink: ExternalConnectorMediaSinkReport

    public init(
        topology: UltraGridTopologyReport = Self.defaultTopology,
        control: UltraGridControlReport = Self.defaultControl,
        provider: ExternalConnectorMediaProviderReport = Self.defaultProvider,
        sink: ExternalConnectorMediaSinkReport = Self.defaultSink
    ) {
        self.topology = topology
        self.control = control
        self.provider = provider
        self.sink = sink
    }
}

public struct UltraGridCompatibilityEvidenceState: Equatable, Sendable {
    public var observedEvidenceClasses: [ExternalConnectorEvidenceClass]
    public var missingEvidenceClassesForPass: [ExternalConnectorEvidenceClass]
    public var realLinkTransmitted: Bool
    public var verdict: MeasurementVerdict
    public var runtimeError: String?
    public var runtimeErrorFree: Bool?
    public var evidenceBoundary: String
    public var notes: String

    public init(
        observedEvidenceClasses: [ExternalConnectorEvidenceClass] = [.synthetic],
        missingEvidenceClassesForPass: [ExternalConnectorEvidenceClass] =
            ExternalConnectorEvidenceClass.runtimePassRequiredEvidence,
        realLinkTransmitted: Bool,
        verdict: MeasurementVerdict,
        runtimeError: String? = nil,
        runtimeErrorFree: Bool? = nil,
        evidenceBoundary: String = UltraGridCompatibility.evidenceBoundary,
        notes: String
    ) {
        self.observedEvidenceClasses = observedEvidenceClasses
        self.missingEvidenceClassesForPass = missingEvidenceClassesForPass
        self.realLinkTransmitted = realLinkTransmitted
        self.verdict = verdict
        self.runtimeError = runtimeError
        self.runtimeErrorFree = runtimeErrorFree
        self.evidenceBoundary = evidenceBoundary
        self.notes = notes
    }
}

public struct UltraGridCompatibilityMediaReportInput: Equatable, Sendable {
    public var identity: UltraGridCompatibilityMediaIdentity
    public var packets: UltraGridCompatibilityPacketSummary
    public var quality: UltraGridCompatibilityQualityCounters
    public var unsupportedModes: [String]
    public var reports: UltraGridCompatibilityNestedReports
    public var evidence: UltraGridCompatibilityEvidenceState

    public init(
        identity: UltraGridCompatibilityMediaIdentity,
        packets: UltraGridCompatibilityPacketSummary,
        quality: UltraGridCompatibilityQualityCounters = UltraGridCompatibilityQualityCounters(),
        unsupportedModes: [String] = UltraGridCompatibility.unsupportedModes,
        reports: UltraGridCompatibilityNestedReports = UltraGridCompatibilityNestedReports(),
        evidence: UltraGridCompatibilityEvidenceState
    ) {
        self.identity = identity
        self.packets = packets
        self.quality = quality
        self.unsupportedModes = unsupportedModes
        self.reports = reports
        self.evidence = evidence
    }
}

public struct UltraGridCompatibilityMediaReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var role: ExternalConnectorSessionRole
    public var mediaMode: ExternalConnectorMediaMode
    public var datagrams: [UltraGridCompatibilityDatagram]
    public var audioDatagramCount: Int
    public var videoDatagramCount: Int
    public var audioPayloadByteCount: Int
    public var videoFramePayloadByteCount: Int
    public var rtpPayloadByteCount: Int
    public var transmittedDatagramCount: Int
    public var receivedDatagramCount: Int
    public var rtpPacketsLost: Int
    public var rtpDuplicatePacketCount: Int
    public var rtpOutOfOrderPacketCount: Int
    public var rtpSsrcChangeCount: Int
    public var rtpTimestampRegressionCount: Int
    public var rtpJitterLikeArrivalDeltaCount: Int
    public var videoFrameReassemblyFailureCount: Int
    public var unsupportedModes: [String]
    public var topology: UltraGridTopologyReport
    public var control: UltraGridControlReport
    public var provider: ExternalConnectorMediaProviderReport
    public var sink: ExternalConnectorMediaSinkReport
    public var observedEvidenceClasses: [ExternalConnectorEvidenceClass]
    public var missingEvidenceClassesForPass: [ExternalConnectorEvidenceClass]
    public var realLinkTransmitted: Bool
    public var verdict: MeasurementVerdict
    public var runtimeError: String?
    public var runtimeErrorFree: Bool?
    public var evidenceBoundary: String
    public var notes: String

    public init(_ input: UltraGridCompatibilityMediaReportInput) {
        self.id = input.identity.id
        self.capturedAt = input.identity.capturedAt
        self.role = input.identity.role
        self.mediaMode = input.identity.mediaMode
        self.datagrams = input.packets.datagrams
        self.audioDatagramCount = input.packets.datagrams.filter { $0.stream == .audio }.count
        self.videoDatagramCount = input.packets.datagrams.filter { $0.stream == .video }.count
        self.audioPayloadByteCount = Self.audioPayloadByteCount(input.packets.datagrams)
        self.videoFramePayloadByteCount = Self.videoFramePayloadByteCount(input.packets.datagrams)
        self.rtpPayloadByteCount = input.packets.datagrams.reduce(0) { $0 + $1.rtp.payload.count }
        self.transmittedDatagramCount = input.packets.transmittedDatagramCount
        self.receivedDatagramCount = input.packets.receivedDatagramCount
        self.rtpPacketsLost = input.quality.rtpPacketsLost
        self.rtpDuplicatePacketCount = input.quality.rtpDuplicatePacketCount
        self.rtpOutOfOrderPacketCount = input.quality.rtpOutOfOrderPacketCount
        self.rtpSsrcChangeCount = input.quality.rtpSsrcChangeCount
        self.rtpTimestampRegressionCount = input.quality.rtpTimestampRegressionCount
        self.rtpJitterLikeArrivalDeltaCount = input.quality.rtpJitterLikeArrivalDeltaCount
        self.videoFrameReassemblyFailureCount = input.quality.videoFrameReassemblyFailureCount
        self.unsupportedModes = input.unsupportedModes
        self.topology = input.reports.topology
        self.control = input.reports.control
        self.provider = input.reports.provider
        self.sink = input.reports.sink
        self.observedEvidenceClasses = input.evidence.observedEvidenceClasses
        self.missingEvidenceClassesForPass = input.evidence.missingEvidenceClassesForPass
        self.realLinkTransmitted = input.evidence.realLinkTransmitted
        self.verdict = input.evidence.verdict
        self.runtimeError = input.evidence.runtimeError
        self.runtimeErrorFree = input.evidence.runtimeErrorFree ?? (input.evidence.runtimeError == nil)
        self.evidenceBoundary = input.evidence.evidenceBoundary
        self.notes = input.evidence.notes
    }

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "ultraGridMedia.id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "ultraGridMedia.capturedAt")
        try topology.validate(fieldPrefix: "ultraGridMedia.topology")
        try control.validate(fieldPrefix: "ultraGridMedia.control")
        try provider.validate(fieldPrefix: "ultraGridMedia.provider")
        try sink.validate(fieldPrefix: "ultraGridMedia.sink")
        try requireExternalConnectorSessionNonEmptyEvidenceClasses(
            observedEvidenceClasses,
            "ultraGridMedia.observedEvidenceClasses"
        )
        try requireExternalConnectorSessionNonEmpty(evidenceBoundary, "ultraGridMedia.evidenceBoundary")
        try requireExternalConnectorSessionNonEmpty(notes, "ultraGridMedia.notes")
        if verdict == .pass {
            try validatePassEvidence()
        } else {
            try requireExternalConnectorSessionNonEmptyEvidenceClasses(
                missingEvidenceClassesForPass,
                "ultraGridMedia.missingEvidenceClassesForPass"
            )
        }
        if verdict == .fail {
            try requireExternalConnectorSessionNonEmpty(runtimeError ?? "", "ultraGridMedia.runtimeError")
        }
        guard audioDatagramCount == datagrams.filter({ $0.stream == .audio }).count else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("ultraGridMedia.audioDatagramCount", String(audioDatagramCount))
        }
        guard videoDatagramCount == datagrams.filter({ $0.stream == .video }).count else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("ultraGridMedia.videoDatagramCount", String(videoDatagramCount))
        }
        for (field, value) in [
            ("ultraGridMedia.audioPayloadByteCount", audioPayloadByteCount),
            ("ultraGridMedia.videoFramePayloadByteCount", videoFramePayloadByteCount),
            ("ultraGridMedia.rtpPayloadByteCount", rtpPayloadByteCount),
            ("ultraGridMedia.rtpPacketsLost", rtpPacketsLost),
            ("ultraGridMedia.rtpDuplicatePacketCount", rtpDuplicatePacketCount),
            ("ultraGridMedia.rtpOutOfOrderPacketCount", rtpOutOfOrderPacketCount),
            ("ultraGridMedia.rtpSsrcChangeCount", rtpSsrcChangeCount),
            ("ultraGridMedia.rtpTimestampRegressionCount", rtpTimestampRegressionCount),
            ("ultraGridMedia.rtpJitterLikeArrivalDeltaCount", rtpJitterLikeArrivalDeltaCount),
            ("ultraGridMedia.videoFrameReassemblyFailureCount", videoFrameReassemblyFailureCount),
        ] {
            guard value >= 0 else {
                throw ExternalConnectorSessionError.invalidPositiveInteger(field, String(value))
            }
        }
    }

    private static func audioPayloadByteCount(_ datagrams: [UltraGridCompatibilityDatagram]) -> Int {
        datagrams.reduce(0) { total, datagram in
            guard datagram.stream == .audio,
                  let audio = try? UltraGridAudioPayload.decode(datagram.rtp.payload) else {
                return total
            }
            return total + audio.pcmPayload.count
        }
    }

    private static func videoFramePayloadByteCount(_ datagrams: [UltraGridCompatibilityDatagram]) -> Int {
        let fragments = datagrams.compactMap { datagram -> UltraGridVideoRawFragmentPayload? in
            guard datagram.stream == .video else {
                return nil
            }
            return try? UltraGridVideoRawFragmentPayload.decode(datagram.rtp.payload)
        }
        let byFrame = Dictionary(grouping: fragments, by: \.frameID)
        return byFrame.values.reduce(0) { total, frameFragments in
            total + Int(frameFragments.first?.framePayloadByteCount ?? 0)
        }
    }
}

public extension UltraGridCompatibilityMediaReport {
    var runtimeEvidenceState: ExternalConnectorRuntimeEvidenceState {
        externalConnectorRuntimeEvidenceState(
            verdict: verdict,
            runtimeError: runtimeError,
            runtimeErrorFree: runtimeErrorFree
        )
    }
}
