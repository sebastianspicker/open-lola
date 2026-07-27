// Implements JackTripCompatibility interoperability behavior, isolating peer-specific compatibility rules from generic transport.
import Darwin
import Foundation

/// Defines the validated fields for JackTrip compatibility datagram.
public struct JackTripCompatibilityDatagram: Codable, Equatable, Sendable {
    public var sourceHost: String?
    public var sourcePort: UInt16?
    public var destinationPort: UInt16
    public var headerMode: JackTripPacketHeaderMode
    public var packets: [JackTripAudioPacket]

    public init(
        sourceHost: String? = nil,
        sourcePort: UInt16? = nil,
        destinationPort: UInt16,
        headerMode: JackTripPacketHeaderMode = .default,
        packet: JackTripAudioPacket
    ) {
        self.init(
            sourceHost: sourceHost,
            sourcePort: sourcePort,
            destinationPort: destinationPort,
            headerMode: headerMode,
            packets: [packet]
        )
    }

    public init(
        sourceHost: String? = nil,
        sourcePort: UInt16? = nil,
        destinationPort: UInt16,
        headerMode: JackTripPacketHeaderMode = .default,
        packets: [JackTripAudioPacket]
    ) {
        self.sourceHost = sourceHost
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.headerMode = headerMode
        self.packets = packets
    }

    public var packet: JackTripAudioPacket {
        packets[0]
    }
}

/// Records the evidence and outcome for JackTrip compatibility media report.
public struct JackTripCompatibilityMediaReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var role: ExternalConnectorSessionRole
    public var datagrams: [JackTripCompatibilityDatagram]
    public var transmittedDatagramCount: Int
    public var receivedDatagramCount: Int
    public var stopControlDatagramCount: Int
    public var redundancyRecoveredPacketCount: Int
    public var packetLossCount: Int
    public var duplicatePacketCount: Int
    public var outOfOrderPacketCount: Int
    public var learnedPeerHost: String?
    public var learnedPeerPort: UInt16?
    public var networkServiceClassStatus: String
    public var unsupportedModes: [String]
    public var topology: JackTripTopologyReport
    public var tcpHandshake: JackTripTCPHandshakeReport
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

    public init(fields: JackTripCompatibilityMediaReportFields) {
        id = fields.id
        capturedAt = fields.capturedAt
        role = fields.role
        datagrams = fields.datagrams
        transmittedDatagramCount = fields.transmittedDatagramCount
        receivedDatagramCount = fields.receivedDatagramCount
        stopControlDatagramCount = fields.stopControlDatagramCount
        redundancyRecoveredPacketCount = fields.redundancyRecoveredPacketCount
        packetLossCount = fields.packetLossCount
        duplicatePacketCount = fields.duplicatePacketCount
        outOfOrderPacketCount = fields.outOfOrderPacketCount
        learnedPeerHost = fields.learnedPeerHost
        learnedPeerPort = fields.learnedPeerPort
        networkServiceClassStatus = fields.networkServiceClassStatus
        unsupportedModes = fields.unsupportedModes
        topology = fields.topology
        tcpHandshake = fields.tcpHandshake
        provider = fields.provider
        sink = fields.sink
        observedEvidenceClasses = fields.observedEvidenceClasses
        missingEvidenceClassesForPass = fields.missingEvidenceClassesForPass
        realLinkTransmitted = fields.realLinkTransmitted
        verdict = fields.verdict
        runtimeError = fields.runtimeError
        runtimeErrorFree = fields.runtimeErrorFree ?? (fields.runtimeError == nil)
        evidenceBoundary = fields.evidenceBoundary
        notes = fields.notes
    }

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "jackTripMedia.id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "jackTripMedia.capturedAt")
        try topology.validate(fieldPrefix: "jackTripMedia.topology")
        try tcpHandshake.validate(fieldPrefix: "jackTripMedia.tcpHandshake")
        try provider.validate(fieldPrefix: "jackTripMedia.provider")
        try sink.validate(fieldPrefix: "jackTripMedia.sink")
        try requireExternalConnectorSessionNonEmptyEvidenceClasses(
            observedEvidenceClasses,
            "jackTripMedia.observedEvidenceClasses"
        )
        try requireExternalConnectorSessionNonEmpty(evidenceBoundary, "jackTripMedia.evidenceBoundary")
        try requireExternalConnectorSessionNonEmpty(notes, "jackTripMedia.notes")
        if verdict == .pass {
            try validatePassEvidence()
        } else {
            try requireExternalConnectorSessionNonEmptyEvidenceClasses(
                missingEvidenceClassesForPass,
                "jackTripMedia.missingEvidenceClassesForPass"
            )
        }
        if verdict == .fail {
            try requireExternalConnectorSessionNonEmpty(runtimeError ?? "", "jackTripMedia.runtimeError")
        }
        try validateNonNegativeCounts()
        try requireExternalConnectorSessionNonEmpty(
            networkServiceClassStatus,
            "jackTripMedia.networkServiceClassStatus"
        )
    }

    private func validateNonNegativeCounts() throws {
        guard transmittedDatagramCount >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "jackTripMedia.transmittedDatagramCount",
                String(transmittedDatagramCount)
            )
        }
        guard receivedDatagramCount >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "jackTripMedia.receivedDatagramCount",
                String(receivedDatagramCount)
            )
        }
        guard stopControlDatagramCount >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "jackTripMedia.stopControlDatagramCount",
                String(stopControlDatagramCount)
            )
        }
        guard redundancyRecoveredPacketCount >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "jackTripMedia.redundancyRecoveredPacketCount",
                String(redundancyRecoveredPacketCount)
            )
        }
    }

}

/// Records the evidence and outcome for JackTrip compatibility media report fields.
public struct JackTripCompatibilityMediaReportFields: Sendable {
    public var id = ""
    public var capturedAt = ""
    public var role = ExternalConnectorSessionRole.tx
    public var datagrams: [JackTripCompatibilityDatagram] = []
    public var transmittedDatagramCount = 0
    public var receivedDatagramCount = 0
    public var stopControlDatagramCount = 0
    public var redundancyRecoveredPacketCount = 0
    public var packetLossCount = 0
    public var duplicatePacketCount = 0
    public var outOfOrderPacketCount = 0
    public var learnedPeerHost: String?
    public var learnedPeerPort: UInt16?
    public var networkServiceClassStatus = JackTripCompatibility.networkServiceClassStatus
    public var unsupportedModes = JackTripCompatibility.unsupportedModes
    public var topology = JackTripTopologyReport(
        mode: .directPeer,
        role: .direct,
        state: .directPeerReady,
        peerRequired: false,
        peerConfigured: false,
        localHost: "0.0.0.0",
        peer: "",
        hubPatchMode: .serverToClients,
        notes: "Direct JackTrip peer topology."
    )
    public var tcpHandshake = JackTripTCPHandshakeReport(
        mode: .none,
        state: .notApplicable,
        clientUDPPort: 0,
        serverUDPPort: 0,
        remoteClientName: nil,
        clientRequestByteCount: 0,
        serverResponseByteCount: 0,
        credentialFrameByteCount: 0,
        notes: "TCP hub handshake is not applicable for direct-peer JackTrip."
    )
    public var provider = ExternalConnectorMediaProviderReport(
        audioSource: "synthetic",
        videoSource: "not-applicable",
        observedEvidenceClasses: [.synthetic],
        notes: "Synthetic JackTrip audio provider."
    )
    public var sink = ExternalConnectorMediaSinkReport(
        notes: "No JackTrip RX sink media was decoded for this role."
    )
    public var observedEvidenceClasses = [ExternalConnectorEvidenceClass.synthetic]
    public var missingEvidenceClassesForPass = ExternalConnectorEvidenceClass.runtimePassRequiredEvidence
    public var realLinkTransmitted = false
    public var verdict = MeasurementVerdict.partial
    public var runtimeError: String?
    public var runtimeErrorFree: Bool?
    public var evidenceBoundary = JackTripCompatibility.evidenceBoundary
    public var notes = ""

    public init() {}
}

public extension JackTripCompatibilityMediaReport {
    var runtimeEvidenceState: ExternalConnectorRuntimeEvidenceState {
        externalConnectorRuntimeEvidenceState(
            verdict: verdict,
            runtimeError: runtimeError,
            runtimeErrorFree: runtimeErrorFree
        )
    }
}
