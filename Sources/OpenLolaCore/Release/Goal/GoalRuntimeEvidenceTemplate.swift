// Collects release-goal evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Defines operator-handoff command and report blueprints without asserting measured runtime closure.
public enum GoalRuntimeEvidenceDeliverableID: String, CaseIterable, Codable, Equatable, Sendable {
    case twoMacRmeMadiBidirectional
    case receiverSideRoutingMixing
    case directP2PSessionUdpMedia
    case audioLatencyJitterLossUnderrunsOverruns
    case rxBufferBenchmarks
    case blackmagicAtemVideoTxRx
    case multiVideoRuntime
    case avTimingRealRuns
    case oscLightingNoAudioImpact
    case packagingSigningCleanMac
}

/// Captures evidence provenance required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalRuntimeEvidenceDeliverableReferences: Equatable, Sendable {
    public var localRunnableSurfaces: [String]
    public var requiredPhysicalInputs: [String]
    public var commandTemplates: [String]
    public var reportPaths: [String]
    public var validators: [String]

    public init(
        localRunnableSurfaces: [String],
        requiredPhysicalInputs: [String],
        commandTemplates: [String],
        reportPaths: [String],
        validators: [String]
    ) {
        self.localRunnableSurfaces = localRunnableSurfaces
        self.requiredPhysicalInputs = requiredPhysicalInputs
        self.commandTemplates = commandTemplates
        self.reportPaths = reportPaths
        self.validators = validators
    }
}

/// Captures evidence provenance required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalRuntimeEvidenceDeliverable: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var currentVerdict: MeasurementVerdict
    public var localRunnableSurfaces: [String]
    public var requiredPhysicalInputs: [String]
    public var commandTemplates: [String]
    public var reportPaths: [String]
    public var validators: [String]
    public var passCriteria: String

    public init(
        id: GoalRuntimeEvidenceDeliverableID,
        title: String,
        currentVerdict: MeasurementVerdict,
        references: GoalRuntimeEvidenceDeliverableReferences,
        passCriteria: String
    ) {
        self.id = id.rawValue
        self.title = title
        self.currentVerdict = currentVerdict
        self.localRunnableSurfaces = references.localRunnableSurfaces
        self.requiredPhysicalInputs = references.requiredPhysicalInputs
        self.commandTemplates = references.commandTemplates
        self.reportPaths = references.reportPaths
        self.validators = references.validators
        self.passCriteria = passCriteria
    }
}

/// Captures evidence provenance required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalRuntimeEvidenceTemplateSummary: Codable, Equatable, Sendable {
    public var deliverableCount: Int
    public var partialDeliverableCount: Int

    public init(deliverables: [GoalRuntimeEvidenceDeliverable]) {
        deliverableCount = deliverables.count
        partialDeliverableCount = deliverables.filter { $0.currentVerdict == .partial }.count
    }
}

// swiftlint:disable:next type_name
/// Describes failures that prevent goal-runtime closure inputs or evidence from satisfying the required validation invariants.
public enum GoalRuntimeEvidenceTemplateValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError {
    case emptyField(String)
    case emptyList(String)
    case duplicateDeliverable(String)
    case missingDeliverable(String)
    case deliverablePassWithoutPhysicalEvidence(String)
    case summaryMismatch
}

/// Captures evidence provenance required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalRuntimeEvidenceTemplateMetadata: Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var goalDocument: String
    public var sourceOfTruth: String
    public var runDirectoryTemplate: String
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        goalDocument: String,
        sourceOfTruth: String,
        runDirectoryTemplate: String,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.goalDocument = goalDocument
        self.sourceOfTruth = sourceOfTruth
        self.runDirectoryTemplate = runDirectoryTemplate
        self.notes = notes
    }
}

/// Captures evidence provenance required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalRuntimeEvidenceTemplateVerdicts: Equatable, Sendable {
    public var verdict: MeasurementVerdict
    public var realWorldVerdict: MeasurementVerdict

    public init(verdict: MeasurementVerdict, realWorldVerdict: MeasurementVerdict) {
        self.verdict = verdict
        self.realWorldVerdict = realWorldVerdict
    }
}

/// Captures evidence provenance required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalRuntimeEvidenceTemplateReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var goalDocument: String
    public var sourceOfTruth: String
    public var runDirectoryTemplate: String
    public var verdict: MeasurementVerdict
    public var realWorldVerdict: MeasurementVerdict
    public var summary: GoalRuntimeEvidenceTemplateSummary
    public var deliverables: [GoalRuntimeEvidenceDeliverable]
    public var notes: String

    public init(
        metadata: GoalRuntimeEvidenceTemplateMetadata,
        verdicts: GoalRuntimeEvidenceTemplateVerdicts,
        deliverables: [GoalRuntimeEvidenceDeliverable]
    ) {
        self.id = metadata.id
        self.title = metadata.title
        self.capturedAt = metadata.capturedAt
        self.goalDocument = metadata.goalDocument
        self.sourceOfTruth = metadata.sourceOfTruth
        self.runDirectoryTemplate = metadata.runDirectoryTemplate
        self.verdict = verdicts.verdict
        self.realWorldVerdict = verdicts.realWorldVerdict
        self.summary = GoalRuntimeEvidenceTemplateSummary(deliverables: deliverables)
        self.deliverables = deliverables
        self.notes = metadata.notes
    }

    public static func template() -> GoalRuntimeEvidenceTemplateReport {
        let deliverables = goalRuntimeEvidenceDeliverables()
        return GoalRuntimeEvidenceTemplateReport(
            metadata: GoalRuntimeEvidenceTemplateMetadata(
                id: "goal-runtime-evidence-template-2026-05-05",
                title: "GOAL.md runtime evidence template",
                capturedAt: "2026-05-05T00:00:00Z",
                goalDocument: "GOAL.md",
                sourceOfTruth: "docs/current-state.md",
                runDirectoryTemplate: "/private/tmp/open-lola-real-runs/<yyyy-mm-dd>",
                notes: "Machine-readable handoff for physical runtime evidence. Replace placeholders with " +
                           "measured values and keep every row PARTIAL until real hardware, route, signing, and " +
                           "clean-Mac reports validate."
            ),
            verdicts: GoalRuntimeEvidenceTemplateVerdicts(verdict: .partial, realWorldVerdict: .partial),
            deliverables: deliverables
        )
    }

    public func validate() throws {
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(id, "id")
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(title, "title")
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(capturedAt, "capturedAt")
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(goalDocument, "goalDocument")
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(sourceOfTruth, "sourceOfTruth")
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(runDirectoryTemplate, "runDirectoryTemplate")
        try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(notes, "notes")
        guard summary == GoalRuntimeEvidenceTemplateSummary(deliverables: deliverables) else {
            throw GoalRuntimeEvidenceTemplateValidationError.summaryMismatch
        }
        try validateDeliverables()
    }

    private func validateDeliverables() throws {
        guard !deliverables.isEmpty else {
            throw GoalRuntimeEvidenceTemplateValidationError.emptyList("deliverables")
        }

        var seen = Set<String>()
        for deliverable in deliverables {
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(deliverable.id, "deliverables.id")
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(deliverable.title, "deliverables.title")
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmpty(
                deliverable.passCriteria,
                "deliverables.passCriteria"
            )
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmptyStrings(
                deliverable.localRunnableSurfaces,
                "deliverables.localRunnableSurfaces"
            )
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmptyStrings(
                deliverable.requiredPhysicalInputs,
                "deliverables.requiredPhysicalInputs"
            )
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmptyStrings(
                deliverable.commandTemplates,
                "deliverables.commandTemplates"
            )
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmptyStrings(
                deliverable.reportPaths,
                "deliverables.reportPaths"
            )
            try GoalRuntimeEvidenceTemplateValidator.requireNonEmptyStrings(
                deliverable.validators,
                "deliverables.validators"
            )
            guard seen.insert(deliverable.id).inserted else {
                throw GoalRuntimeEvidenceTemplateValidationError.duplicateDeliverable(deliverable.id)
            }
            if deliverable.currentVerdict == .pass {
                throw GoalRuntimeEvidenceTemplateValidationError.deliverablePassWithoutPhysicalEvidence(deliverable.id)
            }
        }

        for id in GoalRuntimeEvidenceDeliverableID.allCases.map(\.rawValue) where !seen.contains(id) {
            throw GoalRuntimeEvidenceTemplateValidationError.missingDeliverable(id)
        }
    }
}
