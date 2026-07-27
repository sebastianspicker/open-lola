// Builds and validates UltraGrid media reports from packet, topology, provider, sink, and quality evidence.
import Foundation

/// Records the evidence and outcome for UltraGrid compatibility media report input.
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
/// Records the evidence and outcome for UltraGrid compatibility media report.
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
    public var notes: String
    public var runtimeErrorFree: Bool?
    public var provider: ExternalConnectorMediaProviderReport
    public var sink: ExternalConnectorMediaSinkReport
    public var observedEvidenceClasses: [ExternalConnectorEvidenceClass]
    public var missingEvidenceClassesForPass: [ExternalConnectorEvidenceClass]
    public var realLinkTransmitted: Bool
    public var verdict: MeasurementVerdict
    public var runtimeError: String?
    public var evidenceBoundary: String

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
        self.notes = input.evidence.notes
        self.runtimeErrorFree = input.evidence.runtimeErrorFree ?? (input.evidence.runtimeError == nil)
        self.provider = input.reports.provider
        self.sink = input.reports.sink
        self.observedEvidenceClasses = input.evidence.observedEvidenceClasses
        self.missingEvidenceClassesForPass = input.evidence.missingEvidenceClassesForPass
        self.realLinkTransmitted = input.evidence.realLinkTransmitted
        self.verdict = input.evidence.verdict
        self.runtimeError = input.evidence.runtimeError
        self.evidenceBoundary = input.evidence.evidenceBoundary
    }

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "ultraGridMedia.id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "ultraGridMedia.capturedAt")
        try validateNestedReports()
        try validateEvidenceState()
        try validateDatagramCounts()
        try validateNonNegativeCounters()
    }

    private func validateNestedReports() throws {
        try topology.validate(fieldPrefix: "ultraGridMedia.topology")
        try control.validate(fieldPrefix: "ultraGridMedia.control")
        try provider.validate(fieldPrefix: "ultraGridMedia.provider")
        try sink.validate(fieldPrefix: "ultraGridMedia.sink")
    }

    private func validateEvidenceState() throws {
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
    }

    private func validateDatagramCounts() throws {
        guard audioDatagramCount == datagrams.filter({ $0.stream == .audio }).count else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "ultraGridMedia.audioDatagramCount",
            String(audioDatagramCount)
        )
        }
        guard videoDatagramCount == datagrams.filter({ $0.stream == .video }).count else {
        throw ExternalConnectorSessionError.invalidPositiveInteger(
            "ultraGridMedia.videoDatagramCount",
                String(videoDatagramCount)
            )
        }
    }

    private func validateNonNegativeCounters() throws {
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
            ("ultraGridMedia.videoFrameReassemblyFailureCount", videoFrameReassemblyFailureCount)
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
