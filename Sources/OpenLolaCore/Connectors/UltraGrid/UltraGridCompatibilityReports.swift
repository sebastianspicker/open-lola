// Defines UltraGrid datagram, fragment, packet-summary, quality, topology, and evidence report values.
import Foundation

/// Defines the validated fields for UltraGrid compatibility datagram.
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

/// Defines the validated fields for UltraGrid video fragment request.
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

/// Defines the validated fields for UltraGrid video fragment frame.
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

/// Defines the validated fields for UltraGrid video fragment transport.
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

/// Defines the validated fields for UltraGrid audio packet request.
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

/// Defines the supported choices for UltraGrid topology state.
public enum UltraGridTopologyState: String, Codable, Equatable, Sendable {
    case directPeerReady = "direct-peer-ready"
    case serverListening = "server-listening"
    case clientReady = "client-ready"
}

/// Records the evidence and outcome for UltraGrid topology report.
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
        try validateExternalConnectorTopology(
            ExternalConnectorTopologyValidationInput(
                localHost: localHost,
                peer: peer,
                peerRequired: peerRequired,
                notes: notes,
                fieldPrefix: fieldPrefix,
                requiresDirectRole: mode == .directPeer,
                isDirectRole: role == .direct,
                invalidRoleError: "ultragrid-topology-role-\(role.rawValue)",
                rejectsDirectRole: mode == .serverClient,
                directRoleError: "ultragrid-topology-role-direct"
            )
        )
    }
}

/// Defines the validated fields for UltraGrid compatibility media identity.
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

/// Summarizes retained datagrams and the sent and received counts for a compatibility run.
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

/// Defines the validated fields for UltraGrid compatibility quality counters.
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

/// Records the evidence and outcome for UltraGrid compatibility nested reports.
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

/// Records the evidence and outcome for UltraGrid compatibility evidence state.
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
