// Collects performance-audit evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation
import OpenLolaContracts

/// Captures report contents required to validate, interpret, and reproduce a performance audit result.
public struct PerformanceAuditReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Identity: Sendable {
        public let id: String
        public let title: String
        public let capturedAt: String
        public let runMode: ReportRunMode
        public let evidenceKind: PerformanceAuditEvidenceKind

        public init(
            id: String,
            title: String,
            capturedAt: String,
            runMode: ReportRunMode,
            evidenceKind: PerformanceAuditEvidenceKind
        ) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.runMode = runMode
            self.evidenceKind = evidenceKind
        }
    }

    public struct Context: Sendable {
        public let hardware: HardwareIdentity
        public let process: PerformanceProcessContext
        public let appleSiliconPolicy: AppleSiliconRuntimePolicy
        public let sourceReportIDs: [String]

        public init(
            hardware: HardwareIdentity,
            process: PerformanceProcessContext,
            appleSiliconPolicy: AppleSiliconRuntimePolicy,
            sourceReportIDs: [String]
        ) {
            self.hardware = hardware
            self.process = process
            self.appleSiliconPolicy = appleSiliconPolicy
            self.sourceReportIDs = sourceReportIDs
        }
    }

    public struct Audit: Sendable {
        public let hotPaths: [PerformanceHotPathAudit]
        public let copyEntries: [PerformanceCopyAuditEntry]
        public let workerAssignments: [PerformanceWorkerAssignment]
        public let counters: PerformanceAuditCounters
        public let accelerationDecisions: [PerformanceAccelerationDecision]

        public init(
            hotPaths: [PerformanceHotPathAudit],
            copyEntries: [PerformanceCopyAuditEntry],
            workerAssignments: [PerformanceWorkerAssignment],
            counters: PerformanceAuditCounters,
            accelerationDecisions: [PerformanceAccelerationDecision]
        ) {
            self.hotPaths = hotPaths
            self.copyEntries = copyEntries
            self.workerAssignments = workerAssignments
            self.counters = counters
            self.accelerationDecisions = accelerationDecisions
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = ImmutableReportOutcome<OutcomeDomain>

    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: ReportRunMode
    public var evidenceKind: PerformanceAuditEvidenceKind
    public var hardware: HardwareIdentity
    public var processContext: PerformanceProcessContext
    public var appleSiliconPolicy: AppleSiliconRuntimePolicy
    public var sourceReportIds: [String]
    public var hotPaths: [PerformanceHotPathAudit]
    public var copyAudit: [PerformanceCopyAuditEntry]
    public var workerAssignments: [PerformanceWorkerAssignment]
    public var counters: PerformanceAuditCounters
    public var accelerationDecisions: [PerformanceAccelerationDecision]
    public var profileReports: [PerformanceProfileReportReference]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        identity: Identity,
        context: Context,
        audit: Audit,
        profileReports: [PerformanceProfileReportReference],
        outcome: Outcome
    ) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.runMode = identity.runMode
        self.evidenceKind = identity.evidenceKind
        self.hardware = context.hardware
        self.processContext = context.process
        self.appleSiliconPolicy = context.appleSiliconPolicy
        self.sourceReportIds = context.sourceReportIDs
        self.hotPaths = audit.hotPaths
        self.copyAudit = audit.copyEntries
        self.workerAssignments = audit.workerAssignments
        self.counters = audit.counters
        self.accelerationDecisions = audit.accelerationDecisions
        self.profileReports = profileReports
        self.verdict = outcome.verdict
        self.notes = outcome.notes
    }

}
