// Declares release-goal configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Foundation

/// Defines the finite structured result values recorded by goal-runtime closure artifacts for deterministic validation and report interpretation.
public enum GoalCodewiseRequirementArea: String, Codable, Equatable, Sendable {
    case productGoal
    case priority
    case principle
    case compliance
    case architecture
    case definitionOfDone
    case artifact
    case validation
    case performance
    case decisionRule
}

/// Defines the finite structured result values recorded by goal-runtime closure artifacts for deterministic validation and report interpretation.
public enum GoalCodewiseRequirementStatus: String, Codable, Equatable, Sendable {
    case codeImplemented
    case assumedPassedPendingMeasurement
}

/// Defines the finite structured result values recorded by goal-runtime closure artifacts for deterministic validation and report interpretation.
public enum GoalCodewiseRequirementID: String, CaseIterable, Codable, Equatable, Sendable {
    case primaryProductGoal
    case priorityStableAudioLatency
    case priorityFullDuplexMultichannelAudio
    case priorityDirectP2PSession
    case priorityBlackmagicVideo
    case priorityMultipleVideoStreams
    case priorityLightingControl
    case priorityDocsBenchmarksRelease
    case principleAudioFirst
    case principleFastestProfileSimpleDirect
    case principleVideoNeverBlocksAudio
    case principleLightingNonBlocking
    case principleVisibleLatencyBudget
    case principleBenchmarkOrUnvalidated
    case principleSmallMilestones
    case complianceNoProprietaryCopy
// swiftlint:disable:next identifier_name
case complianceResearchToIndependentRequirement
// swiftlint:disable:next identifier_name
case compliancePublicAPIsStandardsOriginalTestsMeasurements
    case complianceSeparateReverseEngineering
    case compliancePublicDocsSanitized
    case complianceNoBypassExploit
    case architectureMacOSAppleSilicon
    case architectureProfessionalAudioRmeMadi
// swiftlint:disable:next identifier_name
case architectureProfessionalVideoBlackmagicAtem
    case architectureDirectP2PGoldStandard
    case architectureUDPFirstTransport
    case architectureSeparateControlMediaChannels
    case architectureExplicitNegotiationMetadata
    case architectureReceiverSideRoutingMixing
    case architectureRXBufferProfiles
    case architectureDirectLowLatencyMeasurable
    case dodMultichannelAudioBothDirections
    case dodReceiverRoutingMixing
    case dodDirectP2PSetup
    case dodAudioLatencyMeasured
    case dodJitterLossUnderrunMeasured
    case dodRXBuffersBenchmarked
    case dodBlackmagicVideoTXRX
    case dodMultiVideoSupportedOrStaged
    case dodAVTimingDocumented
    case dodPerformanceProfilesDocumented
    case dodTestsBenchmarksCriticalPaths
    case dodCleanRoomDefensible
    case dodPublicDocsSafe
    case artifactArchitectureDocs
    case artifactMilestoneDocs
    case artifactBenchmarkDocs
    case artifactResearchDocs
    case artifactReverseEngineeringDocs
    case artifactComplianceDocs
    case artifactTestingDocs
    case artifactDiagramDocs
    case validationEvidenceRationale
    case validationTestsBenchmarkMethod
    case validationLatencyImpact
    case validationFailureModes
    case validationMilestoneProgress
    case validationArchitectureDocs
    case performanceNoBlockingIOCallbacks
    case performanceNoHeapAllocationCallbacks
    case performanceNoLocksCallbacks
    case performanceNoLoggingCallbacks
// swiftlint:disable:next identifier_name
case performanceNoVideoUILightingOnAudioThreads
    case performanceNoHiddenBuffering
    case performanceNoUnnecessaryConversions
    case performanceNoAvoidableCopies
    case performanceBenchmarkSensitiveChanges
    case decisionRulePriorityOrder
}

/// Captures structured result required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalCodewiseRequirement: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var area: GoalCodewiseRequirementArea
    public var status: GoalCodewiseRequirementStatus
    public var evidence: [String]
    public var assumption: String?
    public var notes: String

    public init(
        id: GoalCodewiseRequirementID,
        title: String,
        area: GoalCodewiseRequirementArea,
        status: GoalCodewiseRequirementStatus,
        evidence: [String],
        assumption: String? = nil,
        notes: String
    ) {
        self.id = id.rawValue
        self.title = title
        self.area = area
        self.status = status
        self.evidence = evidence
        self.assumption = assumption
        self.notes = notes
    }
}

/// Captures structured result required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalCodewiseDocumentationArea: Codable, Equatable, Sendable {
    public var path: String
    public var purpose: String

    public init(path: String, purpose: String) {
        self.path = path
        self.purpose = purpose
    }

    public static let required: [GoalCodewiseDocumentationArea] = [
        .init(path: "docs/latency-first-architecture.md", purpose: "sanitized architecture and latency design"),
        .init(path: "docs/current-state.md", purpose: "active public implementation posture and blockers"),
        .init(path: "docs/benchmark-methodology.md", purpose: "benchmark and measurement methodology"),
        .init(path: "docs/validation-methodology.md", purpose: "publication-safe validation and background synthesis"),
        .init(path: "docs/release-boundary.md", purpose: "clean-room, release, and notice gates"),
        .init(path: "docs/testing.md", purpose: "verification and surface-probe handoff"),
        .init(path: "docs/README.md", purpose: "flat public documentation map")
    ]
}

/// Captures summary statistics required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalCodewiseClosureSummary: Codable, Equatable, Sendable {
    public var requirementCount: Int
    public var codeImplementedCount: Int
    public var assumedPendingMeasurementCount: Int
    public var requiredDocumentationAreaCount: Int

    public init(requirements: [GoalCodewiseRequirement]) {
        requirementCount = requirements.count
        codeImplementedCount = requirements.filter { $0.status == .codeImplemented }.count
        assumedPendingMeasurementCount = requirements
            .filter { $0.status == .assumedPassedPendingMeasurement }
            .count
        requiredDocumentationAreaCount = GoalCodewiseDocumentationArea.required.count
    }
}
