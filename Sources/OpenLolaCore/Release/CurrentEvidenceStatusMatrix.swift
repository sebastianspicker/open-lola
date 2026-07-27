// Collects release-readiness evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Defines the finite evidence provenance values recorded by current-evidence status artifacts for deterministic validation and report interpretation.
public enum CurrentEvidenceStatus: String, Codable, Hashable, Sendable {
    case done = "DONE"
    case sourceDone = "SOURCE-DONE"
    case partial = "PARTIAL"
    case blocked = "BLOCKED"
}

/// Defines the finite evidence provenance values recorded by current-evidence status artifacts for deterministic validation and report interpretation.
public enum CurrentEvidenceLaneID: String, CaseIterable, Codable, Hashable, Sendable {
    case measurementRig = "measurement-rig"
    case coreAudioRme = "core-audio-rme"
    case udpP2PTransport = "udp-p2p-transport"
    case rxBufferingLatencyProfiles = "rx-buffering-latency-profiles"
    case plcAndDrift = "plc-and-drift"
    case dscpPtpAoip = "dscp-ptp-aoip"
    case video = "video"
    case lightingShowControl = "lighting-show-control"
    case windowsLoLaCompatibility = "windows-lola-compatibility"
    case appRecordingOperatorSurface = "app-recording-operator-surface"
    case releaseFieldClosure = "release-field-closure"
}

/// Defines the finite structured result values recorded by current-evidence status artifacts for deterministic validation and report interpretation.
public enum CurrentRealWorldTestID: String, CaseIterable, Codable, Hashable, Sendable {
    case hardwareBaseline = "RWT-001"
    case coreAudioLoopback = "RWT-002"
    case twoMacUdpP2P = "RWT-003"
    case rxBufferProfiles = "RWT-004"
    case plcAndDrift = "RWT-005"
    case networkTimingAndAoip = "RWT-006"
    case video = "RWT-007"
    case lightingAndShowControl = "RWT-008"
    case windowsLoLaCompatibility = "RWT-009"
    case releaseAndFieldPackage = "RWT-010"
    case natIspRoute = "RWT-011"
}

/// Captures evidence provenance required to validate, interpret, and reproduce a current-evidence status result.
public struct CurrentEvidenceStatusMatrixSource: Codable, Equatable, Sendable {
    public let title: String
    public let path: String
    public let role: String
}

/// Captures evidence provenance required to validate, interpret, and reproduce a current-evidence status result.
public struct CurrentEvidenceCrosswalkRow: Codable, Equatable, Sendable {
    public let lane: CurrentEvidenceLaneID
    public let status: CurrentEvidenceStatus
    public let finding: String
    public let doneNow: [String]
    public let missingBeforePass: [String]
    public let realWorldTaskIDs: [CurrentRealWorldTestID]
    public let sourceEvidence: [String]
}

/// Captures structured result required to validate, interpret, and reproduce a current-evidence status result.
public struct CurrentRealWorldTestTask: Codable, Equatable, Sendable {
    public let id: CurrentRealWorldTestID
    public let title: String
    public let blocks: [String]
    public let requiredEvidence: [String]
    public let acceptanceCondition: String
    public let sourceCompletability: String
}

/// Captures evidence provenance required to validate, interpret, and reproduce a current-evidence status result.
public struct CurrentEvidenceStatusMatrixSummary: Codable, Equatable, Sendable {
    public let sourceCount: Int
    public let laneCount: Int
    public let realWorldTaskCount: Int
    public let sourceDoneLaneCount: Int
    public let partialLaneCount: Int
    public let blockedLaneCount: Int
    public let openRealWorldTaskCount: Int

    public init(
        sources: [CurrentEvidenceStatusMatrixSource],
        crosswalk: [CurrentEvidenceCrosswalkRow],
        realWorldTests: [CurrentRealWorldTestTask]
    ) {
        sourceCount = sources.count
        laneCount = crosswalk.count
        realWorldTaskCount = realWorldTests.count
        sourceDoneLaneCount = crosswalk.filter { $0.status == .sourceDone }.count
        partialLaneCount = crosswalk.filter { $0.status == .partial }.count
        blockedLaneCount = crosswalk.filter { $0.status == .blocked }.count
        openRealWorldTaskCount = realWorldTests.count
    }
}

/// Captures evidence provenance required to validate, interpret, and reproduce a current-evidence status result.
public struct CurrentEvidenceStatusMatrixReport: ReportValidatingArtifact, Equatable, Sendable {
    public let id: String
    public let title: String
    public let capturedAt: String
    public let sourceMatrixPath: String
    public let verdict: MeasurementVerdict
    public let summary: CurrentEvidenceStatusMatrixSummary
    public let sources: [CurrentEvidenceStatusMatrixSource]
    public let crosswalk: [CurrentEvidenceCrosswalkRow]
    public let realWorldTests: [CurrentRealWorldTestTask]
    public let notes: String

    public static func current() -> CurrentEvidenceStatusMatrixReport {
        let sources = CurrentEvidenceStatusMatrixFixtures.sources
        let crosswalk = CurrentEvidenceStatusMatrixFixtures.crosswalk
        let realWorldTests = CurrentEvidenceStatusMatrixFixtures.realWorldTests
        return CurrentEvidenceStatusMatrixReport(
            id: "current-evidence-status-matrix-2026-07-24",
            title: "Current evidence status matrix",
            capturedAt: "2026-07-24T00:00:00Z",
            sourceMatrixPath: "docs/current-state.md",
            verdict: .partial,
            summary: CurrentEvidenceStatusMatrixSummary(
                sources: sources,
                crosswalk: crosswalk,
                realWorldTests: realWorldTests
            ),
            sources: sources,
            crosswalk: crosswalk,
            realWorldTests: realWorldTests,
            notes: "Source-level current-status matrix. PASS remains blocked until the real-world test tasks "
                + "attach measured hardware, Windows-peer, signing, notarization, and field evidence."
        )
    }

    public func validate() throws {
        try CurrentEvidenceStatusMatrixValidator.validate(self)
    }
}
