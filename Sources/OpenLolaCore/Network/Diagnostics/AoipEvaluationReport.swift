// Collects network diagnostics evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Selects the depth of an AoIP evaluation run.
public enum AoipMode: String, Codable, Equatable, Sendable {
    case directUdpPcm
    case avb
    case tsn
    case aes67
    case ravenna
    case dante

    public var requiresPtpProfile: Bool {
        self != .directUdpPcm
    }
}

/// Records the operational context for an AoIP evaluation.
public enum AoipUsage: String, Codable, Equatable, Sendable {
    case deferred
    case interop
    case optionalFastestLocalMode
    case defaultReplacement
}

/// Records the PTP profile and clock-lock evidence for an AoIP path.
public struct AoipPtpProfile: Codable, Equatable, Sendable {
    public var version: String
    public var profile: String
    public var domain: String
    // swiftlint:disable:next inclusive_language
    public var masterClockId: String
    public var lockState: String

    public init(
        version: String,
        profile: String,
        domain: String,
        // swiftlint:disable:next inclusive_language
        masterClockId: String,
        lockState: String
    ) {
        self.version = version
        self.profile = profile
        self.domain = domain
        self.masterClockId = masterClockId
        self.lockState = lockState
    }
}

/// Describes one AoIP endpoint's implementation and receive-buffer profile.
public struct AoipEndpointProfile: Codable, Equatable, Sendable {
    public var vendor: String
    public var model: String
    public var firmwareVersion: String
    public var profileName: String
    public var bufferFrames: Int

    public init(
        vendor: String,
        model: String,
        firmwareVersion: String,
        profileName: String,
        bufferFrames: Int
    ) {
        self.vendor = vendor
        self.model = model
        self.firmwareVersion = firmwareVersion
        self.profileName = profileName
        self.bufferFrames = bufferFrames
    }
}

/// Pairs the sending and receiving endpoint profiles evaluated on an AoIP path.
public struct AoipEndpointPair: Codable, Equatable, Sendable {
    public var sender: AoipEndpointProfile
    public var receiver: AoipEndpointProfile

    public init(sender: AoipEndpointProfile, receiver: AoipEndpointProfile) {
        self.sender = sender
        self.receiver = receiver
    }
}

/// Records the switching, traffic-class, reservation, and scheduling profile of an AoIP path.
public struct AoipSwitchProfile: Codable, Equatable, Sendable {
    public var model: String
    public var firmwareVersion: String
    public var linkRateMbps: Int
    public var trafficClass: String
    public var streamReservation: String
    public var schedule: String

    public init(
        model: String,
        firmwareVersion: String,
        linkRateMbps: Int,
        trafficClass: String,
        streamReservation: String,
        schedule: String
    ) {
        self.model = model
        self.firmwareVersion = firmwareVersion
        self.linkRateMbps = linkRateMbps
        self.trafficClass = trafficClass
        self.streamReservation = streamReservation
        self.schedule = schedule
    }
}

/// Records the standards and vendor profiles reviewed for an AoIP evaluation.
public struct AoipProfileEvidence: Codable, Equatable, Sendable {
    public var standardsRead: [String]
    public var vendorProfilesRead: [String]

    public init(standardsRead: [String], vendorProfilesRead: [String]) {
        self.standardsRead = standardsRead
        self.vendorProfilesRead = vendorProfilesRead
    }
}

/// Compares an AoIP result with direct UDP PCM evidence measured on the same path.
public struct AoipBaselineComparison: Codable, Equatable, Sendable {
    public var directUdpPcmRouteReportId: String
    public var directUdpPcmVerdict: MeasurementVerdict
    public var measuredOnSamePath: Bool
    public var directUdpPcmP99Microseconds: Double
    public var evaluatedModeP99Microseconds: Double?
    public var notes: String

    public init(
        directUdpPcmRouteReportId: String,
        directUdpPcmVerdict: MeasurementVerdict,
        measuredOnSamePath: Bool,
        directUdpPcmP99Microseconds: Double,
        evaluatedModeP99Microseconds: Double?,
        notes: String
    ) {
        self.directUdpPcmRouteReportId = directUdpPcmRouteReportId
        self.directUdpPcmVerdict = directUdpPcmVerdict
        self.measuredOnSamePath = measuredOnSamePath
        self.directUdpPcmP99Microseconds = directUdpPcmP99Microseconds
        self.evaluatedModeP99Microseconds = evaluatedModeP99Microseconds
        self.notes = notes
    }
}

/// Captures AoIP packet-age, loss, and recovery evidence under competing traffic.
public struct AoipStressReport: Codable, Equatable, Sendable {
    public var measured: Bool
    public var competingTrafficProfile: String
    public var packetAge: UdpPcmPacketAgeMetrics
    public var packetLoss: Int
    public var recoveryBehavior: String
    public var notes: String

    public init(
        measured: Bool,
        competingTrafficProfile: String,
        packetAge: UdpPcmPacketAgeMetrics,
        packetLoss: Int,
        recoveryBehavior: String,
        notes: String
    ) {
        self.measured = measured
        self.competingTrafficProfile = competingTrafficProfile
        self.packetAge = packetAge
        self.packetLoss = packetLoss
        self.recoveryBehavior = recoveryBehavior
        self.notes = notes
    }
}

/// Enumerates failures that callers must handle when working with network diagnostics.
public enum AoipEvaluationValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyList(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedPacketAge
    case missingPtpField(String)
    case passWithoutLockedPtp
    case passWithoutSamePathBaseline
    case passWithoutMeasuredStress
    case passWithoutEvaluatedModeMetric
    case passWithoutMeasuredSuperiority(
        evaluatedP99Microseconds: Double,
        baselineP99Microseconds: Double
    )
    case defaultReplacementNotAllowed
    case passWithNonPassBaseline(MeasurementVerdict)
    case passWithUndocumentedSwitchProfile(String)
    case passWithUnknownEndpointBuffer(String)
}

/// Aggregates the profile, path, baseline, stress, and verdict evidence for one AoIP evaluation.
public struct AoipEvaluationReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public struct Metadata: Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var mode: AoipMode
        public var usage: AoipUsage

        public init(id: String, title: String, capturedAt: String, mode: AoipMode, usage: AoipUsage) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.mode = mode
            self.usage = usage
        }
    }

    public struct Path: Equatable, Sendable {
        public var route: RouteIdentity
        public var ptp: AoipPtpProfile
        public var switchProfile: AoipSwitchProfile
        public var endpoint: AoipEndpointPair

        public init(
            route: RouteIdentity,
            ptp: AoipPtpProfile,
            switchProfile: AoipSwitchProfile,
            endpoint: AoipEndpointPair
        ) {
            self.route = route
            self.ptp = ptp
            self.switchProfile = switchProfile
            self.endpoint = endpoint
        }
    }

    public struct Evidence: Equatable, Sendable {
        public var profile: AoipProfileEvidence
        public var baselineComparison: AoipBaselineComparison
        public var stress: AoipStressReport

        public init(
            profile: AoipProfileEvidence,
            baselineComparison: AoipBaselineComparison,
            stress: AoipStressReport
        ) {
            self.profile = profile
            self.baselineComparison = baselineComparison
            self.stress = stress
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = MutableReportOutcome<OutcomeDomain>

    public struct Input: Equatable, Sendable {
        public var metadata: Metadata
        public var path: Path
        public var evidence: Evidence
        public var outcome: Outcome

        public init(metadata: Metadata, path: Path, evidence: Evidence, outcome: Outcome) {
            self.metadata = metadata
            self.path = path
            self.evidence = evidence
            self.outcome = outcome
        }
    }

    public var id: String
    public var title: String
    public var capturedAt: String
    public var mode: AoipMode
    public var usage: AoipUsage
    public var route: RouteIdentity
    public var ptp: AoipPtpProfile
    public var switchProfile: AoipSwitchProfile
    public var endpoint: AoipEndpointPair
    public var profileEvidence: AoipProfileEvidence
    public var baselineComparison: AoipBaselineComparison
    public var stress: AoipStressReport
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(_ input: Input) {
        self.id = input.metadata.id
        self.title = input.metadata.title
        self.capturedAt = input.metadata.capturedAt
        self.mode = input.metadata.mode
        self.usage = input.metadata.usage
        self.route = input.path.route
        self.ptp = input.path.ptp
        self.switchProfile = input.path.switchProfile
        self.endpoint = input.path.endpoint
        self.profileEvidence = input.evidence.profile
        self.baselineComparison = input.evidence.baselineComparison
        self.stress = input.evidence.stress
        self.verdict = input.outcome.verdict
        self.notes = input.outcome.notes
    }

}

/// Produces deterministic partial AoIP evidence for source-level validation without professional network hardware.
public enum AoipSyntheticSmoke {
    public static func run() -> AoipEvaluationReport {
        let metadata = AoipEvaluationReport.Metadata(
            id: "m07-avb-synthetic-smoke",
            title: "Synthetic M07 AVB partial evaluation",
            capturedAt: "2026-05-02T00:00:00Z",
            mode: .avb,
            usage: .deferred
        )
        let path = AoipEvaluationReport.Path(
            route: syntheticRoute(),
            ptp: syntheticPtpProfile(),
            switchProfile: syntheticSwitchProfile(),
            endpoint: syntheticEndpointPair()
        )
        let evidence = AoipEvaluationReport.Evidence(
            profile: syntheticProfileEvidence(),
            baselineComparison: syntheticBaselineComparison(),
            stress: syntheticStressReport()
        )
        return AoipEvaluationReport(
            .init(
                metadata: metadata,
                path: path,
                evidence: evidence,
                outcome: .init(
                    verdict: .partial,
                    notes: "Synthetic source validation only; real M07 requires AoIP hardware, PTP, and WCRT evidence."
                )
            )
        )
    }

    private static func syntheticRoute() -> RouteIdentity {
        RouteIdentity(
            label: "synthetic-avb",
            topology: "deterministic-source-validation"
        )
    }

    private static func syntheticPtpProfile() -> AoipPtpProfile {
        AoipPtpProfile(
            version: "unknown",
            profile: "unknown",
            domain: "unknown",
            masterClockId: "unknown",
            lockState: "notTested"
        )
    }

    private static func syntheticSwitchProfile() -> AoipSwitchProfile {
        AoipSwitchProfile(
            model: "unknown",
            firmwareVersion: "unknown",
            linkRateMbps: 0,
            trafficClass: "unknown",
            streamReservation: "unknown",
            schedule: "unknown"
        )
    }

    private static func syntheticEndpointPair() -> AoipEndpointPair {
        AoipEndpointPair(
            sender: syntheticEndpointProfile(),
            receiver: syntheticEndpointProfile()
        )
    }

    private static func syntheticEndpointProfile() -> AoipEndpointProfile {
        AoipEndpointProfile(
            vendor: "unknown",
            model: "unknown",
            firmwareVersion: "unknown",
            profileName: "none",
            bufferFrames: 0
        )
    }

    private static func syntheticProfileEvidence() -> AoipProfileEvidence {
        AoipProfileEvidence(
            standardsRead: [
                "IEEE 802.1 AVB family requirements pending full profile access"
            ],
            vendorProfilesRead: [
                "none"
            ]
        )
    }

    private static func syntheticBaselineComparison() -> AoipBaselineComparison {
        AoipBaselineComparison(
            directUdpPcmRouteReportId: "m05-direct-link-pass-fixture",
            directUdpPcmVerdict: .pass,
            measuredOnSamePath: false,
            directUdpPcmP99Microseconds: 240,
            evaluatedModeP99Microseconds: nil,
            notes: "Synthetic source-validation report; no AVB endpoint measurement."
        )
    }

    private static func syntheticStressReport() -> AoipStressReport {
        AoipStressReport(
            measured: false,
            competingTrafficProfile: "not-run",
            packetAge: UdpPcmPacketAgeMetrics(
                p50Microseconds: 0,
                p95Microseconds: 0,
                p99Microseconds: 0,
                maxMicroseconds: 0
            ),
            packetLoss: 0,
            recoveryBehavior: "not-tested",
            notes: "No WCRT-style stress case was run."
        )
    }
}
