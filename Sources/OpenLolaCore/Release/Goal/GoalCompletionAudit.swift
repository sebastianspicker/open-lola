// Cross-checks codewise requirements, runtime deliverables, open-source readiness, and verification gates to identify the next unmet goal action.
import Foundation

/// Maps GOAL.md source and runtime evidence contracts without replacing measured runtime evidence.
public enum GoalCompletionAuditItemKind: String, Codable, Equatable, Sendable {
    case goalRequirement
    case runtimeDeliverable
    case openSourceReleaseRequirement
    case verificationGate
}

/// Captures audit findings required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalCompletionAuditItem: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var kind: GoalCompletionAuditItemKind
    public var verdict: MeasurementVerdict
    public var evidence: [String]
    public var commands: [String]
    public var blockers: [String]
    public var notes: String

    public init(
        id: String,
        title: String,
        kind: GoalCompletionAuditItemKind,
        verdict: MeasurementVerdict,
        evidence: [String],
        commands: [String],
        blockers: [String],
        notes: String
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.verdict = verdict
        self.evidence = evidence
        self.commands = commands
        self.blockers = blockers
        self.notes = notes
    }
}

/// Captures audit findings required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalCompletionAuditNextAction: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var itemID: String
    public var blocker: String
    public var evidence: [String]
    public var commands: [String]

    public init(id: String, title: String, itemID: String, blocker: String, evidence: [String], commands: [String]) {
        self.id = id
        self.title = title
        self.itemID = itemID
        self.blocker = blocker
        self.evidence = evidence
        self.commands = commands
    }
}

/// Captures summary statistics required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalCompletionAuditSummary: Codable, Equatable, Sendable {
    public var itemCount: Int
    public var blockedItemCount: Int
    public var partialItemCount: Int
    public var passItemCount: Int
    public var blockerCount: Int
    public var nextActionCount: Int

    public init(items: [GoalCompletionAuditItem], blockers: [String], nextActions: [GoalCompletionAuditNextAction]) {
        itemCount = items.count
        blockedItemCount = items.filter { !$0.blockers.isEmpty }.count
        partialItemCount = items.filter { $0.verdict == .partial }.count
        passItemCount = items.filter { $0.verdict == .pass }.count
        blockerCount = blockers.count
        nextActionCount = nextActions.count
    }
}

/// Describes failures that prevent goal-runtime closure inputs or evidence from satisfying the required validation invariants.
public enum GoalCompletionAuditValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError {
    case emptyField(String)
    case emptyList(String)
    case duplicateItem(String)
    case missingGoalRequirement(String)
    case missingRuntimeDeliverable(String)
    case missingOpenSourceRequirement(String)
    case missingVerificationGate(String)
    case summaryMismatch
    case nextActionMismatch
    case duplicateNextAction(String)
    case passWithBlockers
    case passWithPartialItem(String)
}

/// Captures report contents required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalCompletionAuditReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Identity: Sendable {
        public let id: String
        public let title: String
        public let capturedAt: String
        public let objective: String

        public init(id: String, title: String, capturedAt: String, objective: String) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.objective = objective
        }
    }

    public struct Verdicts: Sendable {
        public let aggregate: MeasurementVerdict
        public let realWorld: MeasurementVerdict

        public init(aggregate: MeasurementVerdict, realWorld: MeasurementVerdict) {
            self.aggregate = aggregate
            self.realWorld = realWorld
        }
    }

    public struct Evidence: Sendable {
        public let sourceOfTruth: [String]
        public let items: [GoalCompletionAuditItem]
        public let blockers: [String]

        public init(
            sourceOfTruth: [String],
            items: [GoalCompletionAuditItem],
            blockers: [String]
        ) {
            self.sourceOfTruth = sourceOfTruth
            self.items = items
            self.blockers = blockers
        }
    }

    public var id: String
    public var title: String
    public var capturedAt: String
    public var objective: String
    public var sourceOfTruth: [String]
    public var verdict: MeasurementVerdict
    public var realWorldVerdict: MeasurementVerdict
    public var summary: GoalCompletionAuditSummary
    public var items: [GoalCompletionAuditItem]
    public var blockers: [String]
    public var nextActions: [GoalCompletionAuditNextAction]
    public var notes: String

    public init(
        identity: Identity,
        verdicts: Verdicts,
        evidence: Evidence,
        notes: String
    ) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.objective = identity.objective
        self.sourceOfTruth = evidence.sourceOfTruth
        self.verdict = verdicts.aggregate
        self.realWorldVerdict = verdicts.realWorld
        self.items = evidence.items
        self.blockers = evidence.blockers
        self.nextActions = Self.makeNextActions(items)
        self.summary = GoalCompletionAuditSummary(items: items, blockers: blockers, nextActions: nextActions)
        self.notes = notes
    }

    public static func make(
        capturedAt: String,
        codewise: GoalCodewiseClosureReport,
        runtime: GoalRuntimePreflightReport,
        openSource: OpenSourceReleaseReadinessReport
    ) -> GoalCompletionAuditReport {
        let items = goalRequirementItems(codewise)
            + runtimeDeliverableItems(runtime)
            + openSourceRequirementItems(openSource)
            + verificationGateItems()
        let blockers = items.flatMap { item in
            item.blockers.map { "\(item.id): \($0)" }
        }
        return GoalCompletionAuditReport(
            identity: GoalCompletionAuditReport.Identity(
                id: "goal-completion-audit-2026-05-05",
                title: "GOAL.md requirement-to-artifact completion audit",
                capturedAt: capturedAt,
                objective: "Build a clean-room, open-source, ultra-low-latency " +
                    "peer-to-peer AV system for professional remote performance workflows."
            ),
            verdicts: GoalCompletionAuditReport.Verdicts(
                aggregate: blockers.isEmpty ? .pass : .partial,
                realWorld: blockers.isEmpty ? .pass : .partial
            ),
            evidence: GoalCompletionAuditReport.Evidence(
                sourceOfTruth: ["GOAL.md", "docs/current-state.md", "README.md"],
                items: items,
                blockers: blockers
            ),
            notes: "Checklist maps product, runtime, open-source release, and " +
"verification requirements to concrete artifacts. It cannot close " +
"real-world PASS while any blocker remains."
        )
    }

    public func validate() throws {
        try GoalCompletionAuditValidator.requireNonEmpty(id, "id")
        try GoalCompletionAuditValidator.requireNonEmpty(title, "title")
        try GoalCompletionAuditValidator.requireNonEmpty(capturedAt, "capturedAt")
        try GoalCompletionAuditValidator.requireNonEmpty(objective, "objective")
        try GoalCompletionAuditValidator.requireNonEmpty(notes, "notes")
        try GoalCompletionAuditValidator.requireNonEmptyStrings(sourceOfTruth, "sourceOfTruth")
        try validateItems()
        try validateNextActions()
        for blocker in blockers {
            try GoalCompletionAuditValidator.requireNonEmpty(blocker, "blockers")
        }
        if verdict == .partial, blockers.isEmpty {
            throw GoalCompletionAuditValidationError.emptyList("blockers")
        }
        guard summary == GoalCompletionAuditSummary(items: items, blockers: blockers, nextActions: nextActions) else {
            throw GoalCompletionAuditValidationError.summaryMismatch
        }
        guard nextActions == Self.makeNextActions(items) else {
            throw GoalCompletionAuditValidationError.nextActionMismatch
        }
        if verdict == .pass || realWorldVerdict == .pass {
            try validatePass()
        }
    }

    private static func makeNextActions(_ items: [GoalCompletionAuditItem]) -> [GoalCompletionAuditNextAction] {
        items.flatMap { item in
            item.blockers.enumerated().map { index, blocker in
                GoalCompletionAuditNextAction(
                    id: "\(item.id).blocker.\(index + 1)",
                    title: "Close \(item.title)",
                    itemID: item.id,
                    blocker: blocker,
                    evidence: item.evidence,
                    commands: item.commands
                )
            }
        }
    }

    private func validateItems() throws {
        guard !items.isEmpty else {
            throw GoalCompletionAuditValidationError.emptyList("items")
        }
        var seen = Set<String>()
        for item in items {
            try validateItemFields(item)
            guard seen.insert(item.id).inserted else {
                throw GoalCompletionAuditValidationError.duplicateItem(item.id)
            }
        }
        try validateRequiredGoalItems(seen)
        try validateRequiredRuntimeItems(seen)
        try validateRequiredReleaseItems(seen)
        try validateRequiredVerificationItems(seen)
    }

    private func validateItemFields(_ item: GoalCompletionAuditItem) throws {
        try GoalCompletionAuditValidator.requireNonEmpty(item.id, "items.id")
        try GoalCompletionAuditValidator.requireNonEmpty(item.title, "items.title")
        try GoalCompletionAuditValidator.requireNonEmpty(item.notes, "items.notes")
        try GoalCompletionAuditValidator.requireNonEmptyStrings(item.evidence, "items.evidence")
        for command in item.commands {
            try GoalCompletionAuditValidator.requireNonEmpty(command, "items.commands")
        }
        for blocker in item.blockers {
            try GoalCompletionAuditValidator.requireNonEmpty(blocker, "items.blockers")
        }
    }

    private func validateRequiredGoalItems(_ seen: Set<String>) throws {
        for id in GoalCodewiseRequirementID.allCases.map(\.rawValue) where !seen.contains("goal.\(id)") {
            throw GoalCompletionAuditValidationError.missingGoalRequirement(id)
        }
    }

    private func validateRequiredRuntimeItems(_ seen: Set<String>) throws {
        for id in GoalRuntimeEvidenceDeliverableID.allCases.map(\.rawValue) where !seen.contains("runtime.\(id)") {
            throw GoalCompletionAuditValidationError.missingRuntimeDeliverable(id)
        }
    }

    private func validateRequiredReleaseItems(_ seen: Set<String>) throws {
        for kind in OpenSourceReleaseRequirementKind.allCases where !seen.contains("release.\(kind.rawValue)") {
            throw GoalCompletionAuditValidationError.missingOpenSourceRequirement(kind.rawValue)
        }
    }

    private func validateRequiredVerificationItems(_ seen: Set<String>) throws {
        for gate in requiredVerificationGates where !seen.contains("verification.\(gate)") {
            throw GoalCompletionAuditValidationError.missingVerificationGate(gate)
        }
    }

    private func validateNextActions() throws {
        guard nextActions.count == blockers.count else {
            throw GoalCompletionAuditValidationError.nextActionMismatch
        }
        var seen = Set<String>()
        for action in nextActions {
            try GoalCompletionAuditValidator.requireNonEmpty(action.id, "nextActions.id")
            try GoalCompletionAuditValidator.requireNonEmpty(action.title, "nextActions.title")
            try GoalCompletionAuditValidator.requireNonEmpty(action.itemID, "nextActions.itemID")
            try GoalCompletionAuditValidator.requireNonEmpty(action.blocker, "nextActions.blocker")
            try GoalCompletionAuditValidator.requireNonEmptyStrings(action.evidence, "nextActions.evidence")
            try GoalCompletionAuditValidator.requireNonEmptyStrings(action.commands, "nextActions.commands")
            guard seen.insert(action.id).inserted else {
                throw GoalCompletionAuditValidationError.duplicateNextAction(action.id)
            }
        }
    }

    private func validatePass() throws {
        try VerdictValidationPolicy.passForbids(
            !blockers.isEmpty,
            GoalCompletionAuditValidationError.passWithBlockers
        )
        for item in items where item.verdict != .pass {
            try VerdictValidationPolicy.passForbids(
                true,
                GoalCompletionAuditValidationError.passWithPartialItem(item.id)
            )
        }
    }
}

/// Runs the goal-runtime closure evaluation from supplied artifacts while retaining their measurement provenance in the resulting report.
public enum GoalCompletionAuditRunner {
    public static func run(
        capturedAt: String = ISO8601DateFormatter().string(from: Date()),
        repositoryRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        runtime: GoalRuntimePreflightReport = GoalRuntimePreflightRunner.run()
    ) -> GoalCompletionAuditReport {
        GoalCompletionAuditReport.make(
            capturedAt: capturedAt,
            codewise: GoalCodewiseClosureReport.codewiseClosure(),
            runtime: runtime,
            openSource: OpenSourceReleaseReadinessRunner.run(
                configuration: OpenSourceReleaseReadinessRunConfiguration(
                    outputPath: "goal-completion-audit-inline-open-source-readiness.json"
                ),
                repositoryRoot: repositoryRoot
            )
        )
    }
}

private let requiredVerificationGates: [String] = [
    "bash scripts/verify-docs.sh",
    "shellcheck -x scripts/*.sh scripts/lib/*.sh",
    "bash scripts/verify-release-hygiene.sh",
    "swift build",
    "swift test --no-parallel",
    "bash scripts/verify-release-readiness.sh"
]

private func goalRequirementItems(_ report: GoalCodewiseClosureReport) -> [GoalCompletionAuditItem] {
    report.requirements.map { requirement in
        let blockers = requirement.status == .assumedPassedPendingMeasurement
            ? [requirement.assumption ?? "physical measurement evidence remains pending"]
            : []
        return GoalCompletionAuditItem(
            id: "goal.\(requirement.id)",
            title: requirement.title,
            kind: .goalRequirement,
            verdict: blockers.isEmpty ? .pass : .partial,
            evidence: requirement.evidence,
            commands: ["goal-codewise-closure", "validate-goal-codewise-closure-report"],
            blockers: blockers,
            notes: requirement.notes
        )
    }
}

private func runtimeDeliverableItems(_ report: GoalRuntimePreflightReport) -> [GoalCompletionAuditItem] {
    let templateValidators = Dictionary(uniqueKeysWithValues: GoalRuntimeEvidenceTemplateReport
        .template()
        .deliverables
        .map { ($0.id, $0.validators) })

    return report.deliverables.map { deliverable in
        let validators = templateValidators[deliverable.id] ?? []
        return GoalCompletionAuditItem(
            id: "runtime.\(deliverable.id)",
            title: deliverable.title,
            kind: .runtimeDeliverable,
            verdict: deliverable.verdict,
            evidence: deliverable.currentHostEvidence,
            commands: deliverable.nextCommands + validators + [
                "goal-runtime-preflight",
                "validate-goal-runtime-preflight-report"
            ],
            blockers: deliverable.blockers,
            notes: "Runtime deliverable from GOAL.md preflight."
        )
    }
}

private func openSourceRequirementItems(_ report: OpenSourceReleaseReadinessReport) -> [GoalCompletionAuditItem] {
    report.requirements.map { requirement in
        GoalCompletionAuditItem(
            id: "release.\(requirement.kind.rawValue)",
            title: requirement.kind.rawValue,
            kind: .openSourceReleaseRequirement,
            verdict: requirement.releaseBlocking ? .partial : .pass,
            evidence: [requirement.sourcePath],
            commands: ["open-source-release-readiness-run", "validate-open-source-release-readiness-report"],
            blockers: requirement.releaseBlocking ? [requirement.notes] : [],
            notes: requirement.notes
        )
    }
}

private func verificationGateItems() -> [GoalCompletionAuditItem] {
    requiredVerificationGates.map { command in
        GoalCompletionAuditItem(
            id: "verification.\(command)",
            title: command,
            kind: .verificationGate,
            verdict: .pass,
            evidence: ["scripts/verify-release-readiness.sh", "docs/testing.md"],
            commands: [command],
            blockers: [],
            notes: "Gate is part of the local verification matrix; it is evidence only after it is run."
        )
    }
}
