// Validates CurrentEvidenceStatusMatrixValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

// swiftlint:disable:next type_name
/// Describes failures that prevent current-evidence status inputs or evidence from satisfying the required validation invariants.
public enum CurrentEvidenceStatusMatrixValidationError: Error, Equatable {
    case emptyField(String)
    case emptyList(String)
    case malformedField(String)
    case duplicateLane(CurrentEvidenceLaneID)
    case missingLane(CurrentEvidenceLaneID)
    case duplicateRealWorldTask(CurrentRealWorldTestID)
    case missingRealWorldTask(CurrentRealWorldTestID)
    case unknownTaskReference(CurrentRealWorldTestID)
    case summaryMismatch
    case passForbidden
}

extension CurrentEvidenceStatusMatrixValidationError: ValidationEmptyFieldError, ValidationEmptyListError,
    ValidationMalformedFieldError {}

enum CurrentEvidenceStatusMatrixValidator: ReportPrimitiveValidating {
    typealias ValidationError = CurrentEvidenceStatusMatrixValidationError

    static func validate(_ report: CurrentEvidenceStatusMatrixReport) throws {
        try requireNonEmpty(report.id, "id")
        try requireNonEmpty(report.title, "title")
        try requireNonEmpty(report.capturedAt, "capturedAt")
        try requireISO8601Date(report.capturedAt, "capturedAt")
        try requireNonEmpty(report.sourceMatrixPath, "sourceMatrixPath")
        try requireNonEmpty(report.notes, "notes")
        try requireNonEmpty(report.sources, "sources")
        try requireNonEmpty(report.crosswalk, "crosswalk")
        try requireNonEmpty(report.realWorldTests, "realWorldTests")
        if report.verdict == .pass {
            throw CurrentEvidenceStatusMatrixValidationError.passForbidden
        }

        try validateSources(report.sources)
        try validateCrosswalk(report.crosswalk, tasks: report.realWorldTests.map(\.id))
        try validateRealWorldTests(report.realWorldTests)

        let expectedSummary = CurrentEvidenceStatusMatrixSummary(
            sources: report.sources,
            crosswalk: report.crosswalk,
            realWorldTests: report.realWorldTests
        )
        if report.summary != expectedSummary {
            throw CurrentEvidenceStatusMatrixValidationError.summaryMismatch
        }
    }

    private static func validateSources(_ sources: [CurrentEvidenceStatusMatrixSource]) throws {
        for source in sources {
            try requireNonEmpty(source.title, "sources.title")
            try requireNonEmpty(source.path, "sources.path")
            try requireNonEmpty(source.role, "sources.role")
        }
    }

    private static func validateCrosswalk(
        _ rows: [CurrentEvidenceCrosswalkRow],
        tasks: [CurrentRealWorldTestID]
    ) throws {
        let taskSet = Set(tasks)
        var seen = Set<CurrentEvidenceLaneID>()
        for row in rows {
            if !seen.insert(row.lane).inserted {
                throw CurrentEvidenceStatusMatrixValidationError.duplicateLane(row.lane)
            }
            try requireNonEmpty(row.finding, "crosswalk.finding")
            try requireNonEmptyStrings(row.doneNow, "crosswalk.doneNow")
            try requireNonEmptyStrings(row.missingBeforePass, "crosswalk.missingBeforePass")
            try requireNonEmpty(row.realWorldTaskIDs, "crosswalk.realWorldTaskIDs")
            try requireNonEmptyStrings(row.sourceEvidence, "crosswalk.sourceEvidence")
            for taskID in row.realWorldTaskIDs where !taskSet.contains(taskID) {
                throw CurrentEvidenceStatusMatrixValidationError.unknownTaskReference(taskID)
            }
        }
        for lane in CurrentEvidenceLaneID.allCases where !seen.contains(lane) {
            throw CurrentEvidenceStatusMatrixValidationError.missingLane(lane)
        }
    }

    private static func validateRealWorldTests(_ tasks: [CurrentRealWorldTestTask]) throws {
        var seen = Set<CurrentRealWorldTestID>()
        for task in tasks {
            if !seen.insert(task.id).inserted {
                throw CurrentEvidenceStatusMatrixValidationError.duplicateRealWorldTask(task.id)
            }
            try requireNonEmpty(task.title, "realWorldTests.title")
            try requireNonEmptyStrings(task.blocks, "realWorldTests.blocks")
            try requireNonEmptyStrings(task.requiredEvidence, "realWorldTests.requiredEvidence")
            try requireNonEmpty(task.acceptanceCondition, "realWorldTests.acceptanceCondition")
            try requireNonEmpty(task.sourceCompletability, "realWorldTests.sourceCompletability")
        }
        for taskID in CurrentRealWorldTestID.allCases where !seen.contains(taskID) {
            throw CurrentEvidenceStatusMatrixValidationError.missingRealWorldTask(taskID)
        }
    }
}
