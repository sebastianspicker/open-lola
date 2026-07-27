// Validates codewise requirement status and evidence references before the goal-closure report can claim a completed source surface.
import Foundation

/// Defines the executable GOAL.md closure schema for CLI validation without replacing measured runtime evidence.
public enum GoalCodewiseClosureValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError {
    case emptyField(String)
    case emptyList(String)
    case duplicateRequirement(String)
    case missingRequiredRequirement(String)
    case missingRequiredDocumentationArea(String)
    case requirementWithoutEvidence(String)
    case assumedRequirementWithoutAssumption(String)
    case summaryMismatch
    case passWithAssumedRealWorldClosure
}

/// Captures report contents required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalCodewiseClosureReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var goalDocument: String

        public init(id: String, title: String, capturedAt: String, goalDocument: String) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.goalDocument = goalDocument
        }
    }

    public struct Verdicts: Equatable, Sendable {
        public var codewise: MeasurementVerdict
        public var realWorld: MeasurementVerdict

        public init(codewise: MeasurementVerdict, realWorld: MeasurementVerdict) {
            self.codewise = codewise
            self.realWorld = realWorld
        }
    }

    public struct Evidence: Equatable, Sendable {
        public var requirements: [GoalCodewiseRequirement]
        public var requiredDocumentationAreas: [GoalCodewiseDocumentationArea]
        public var assumptions: [String]

        public init(
            requirements: [GoalCodewiseRequirement],
            requiredDocumentationAreas: [GoalCodewiseDocumentationArea],
            assumptions: [String]
        ) {
            self.requirements = requirements
            self.requiredDocumentationAreas = requiredDocumentationAreas
            self.assumptions = assumptions
        }
    }

    public var id: String
    public var title: String
    public var capturedAt: String
    public var goalDocument: String
    public var verdict: MeasurementVerdict
    public var realWorldVerdict: MeasurementVerdict
    public var summary: GoalCodewiseClosureSummary
    public var requirements: [GoalCodewiseRequirement]
    public var requiredDocumentationAreas: [GoalCodewiseDocumentationArea]
    public var assumptions: [String]
    public var notes: String

    public init(
        identity: Identity,
        verdicts: Verdicts,
        evidence: Evidence,
        notes: String
    ) {
        id = identity.id
        title = identity.title
        capturedAt = identity.capturedAt
        goalDocument = identity.goalDocument
        verdict = verdicts.codewise
        realWorldVerdict = verdicts.realWorld
        summary = GoalCodewiseClosureSummary(requirements: evidence.requirements)
        requirements = evidence.requirements
        requiredDocumentationAreas = evidence.requiredDocumentationAreas
        assumptions = evidence.assumptions
        self.notes = notes
    }

    public func validate() throws {
        try GoalCodewiseClosureValidator.requireNonEmpty(id, "id")
        try GoalCodewiseClosureValidator.requireNonEmpty(title, "title")
        try GoalCodewiseClosureValidator.requireNonEmpty(capturedAt, "capturedAt")
        try GoalCodewiseClosureValidator.requireNonEmpty(goalDocument, "goalDocument")
        try GoalCodewiseClosureValidator.requireNonEmpty(notes, "notes")
        try validateRequirements()
        try validateDocumentationAreas()
        try validateAssumptions()
        guard summary == GoalCodewiseClosureSummary(requirements: requirements) else {
            throw GoalCodewiseClosureValidationError.summaryMismatch
        }
        if verdict == .pass && realWorldVerdict != .partial {
            throw GoalCodewiseClosureValidationError.passWithAssumedRealWorldClosure
        }
    }

    private var hasAssumedMeasurements: Bool {
        requirements.contains { $0.status == .assumedPassedPendingMeasurement }
    }

    private func validateRequirements() throws {
        guard !requirements.isEmpty else {
            throw GoalCodewiseClosureValidationError.emptyList("requirements")
        }

        var seen = Set<String>()
        for requirement in requirements {
            try validateRequirement(requirement, seen: &seen)
        }

        try validateRequiredRequirementCoverage(seen)
    }

    private func validateRequirement(
        _ requirement: GoalCodewiseRequirement,
        seen: inout Set<String>
    ) throws {
        try GoalCodewiseClosureValidator.requireNonEmpty(requirement.id, "requirements.id")
        try GoalCodewiseClosureValidator.requireNonEmpty(requirement.title, "requirements.title")
        try GoalCodewiseClosureValidator.requireNonEmpty(requirement.notes, "requirements.notes")
        guard seen.insert(requirement.id).inserted else {
            throw GoalCodewiseClosureValidationError.duplicateRequirement(requirement.id)
        }
        try validateRequirementEvidence(requirement)
        try validateRequirementAssumption(requirement)
    }

    private func validateRequirementEvidence(_ requirement: GoalCodewiseRequirement) throws {
        guard !requirement.evidence.isEmpty else {
            throw GoalCodewiseClosureValidationError.requirementWithoutEvidence(requirement.id)
        }
        for evidence in requirement.evidence {
            try GoalCodewiseClosureValidator.requireNonEmpty(evidence, "requirements.evidence")
        }
    }

    private func validateRequirementAssumption(_ requirement: GoalCodewiseRequirement) throws {
        if requirement.status == .assumedPassedPendingMeasurement {
            guard let assumption = requirement.assumption, !assumption.isEmpty else {
                throw GoalCodewiseClosureValidationError.assumedRequirementWithoutAssumption(requirement.id)
            }
        }
    }

    private func validateRequiredRequirementCoverage(_ seen: Set<String>) throws {
        for id in GoalCodewiseRequirementID.allCases.map(\.rawValue) where !seen.contains(id) {
            throw GoalCodewiseClosureValidationError.missingRequiredRequirement(id)
        }
    }

    private func validateDocumentationAreas() throws {
        guard !requiredDocumentationAreas.isEmpty else {
            throw GoalCodewiseClosureValidationError.emptyList("requiredDocumentationAreas")
        }
        let paths = Set(requiredDocumentationAreas.map(\.path))
        for area in requiredDocumentationAreas {
            try GoalCodewiseClosureValidator.requireNonEmpty(area.path, "requiredDocumentationAreas.path")
            try GoalCodewiseClosureValidator.requireNonEmpty(area.purpose, "requiredDocumentationAreas.purpose")
        }
        for area in GoalCodewiseDocumentationArea.required where !paths.contains(area.path) {
            throw GoalCodewiseClosureValidationError.missingRequiredDocumentationArea(area.path)
        }
    }

    private func validateAssumptions() throws {
        if hasAssumedMeasurements {
            guard !assumptions.isEmpty else {
                throw GoalCodewiseClosureValidationError.emptyList("assumptions")
            }
        }
        for assumption in assumptions {
            try GoalCodewiseClosureValidator.requireNonEmpty(assumption, "assumptions")
        }
    }
}
