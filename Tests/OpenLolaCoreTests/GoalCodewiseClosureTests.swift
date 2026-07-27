// Verifies that goal codewise closure report maps every goal requirement.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func goalCodewiseClosureReportMapsEveryGoalRequirement() throws {
    let report = GoalCodewiseClosureReport.codewiseClosure()

    try report.validate()

    let requirementIDs = Set(report.requirements.map(\.id))
    let requiredIDs = Set(GoalCodewiseRequirementID.allCases.map(\.rawValue))

    #expect(report.goalDocument == "GOAL.md")
    #expect(report.verdict == .pass)
    #expect(report.realWorldVerdict == .partial)
    #expect(requirementIDs == requiredIDs)
    #expect(report.summary.requirementCount == requiredIDs.count)
    #expect(report.summary.assumedPendingMeasurementCount == 0)
    #expect(report.summary.codeImplementedCount == requiredIDs.count)
    #expect(report.assumptions.contains { $0.contains("Codewise closure") })
    #expect(report.assumptions.contains { $0.contains("Physical two-Mac") })
}

@Test
func goalCodewiseClosureTracksRequiredDocumentationAreas() throws {
    let report = GoalCodewiseClosureReport.codewiseClosure()
    let requiredPaths = Set(GoalCodewiseDocumentationArea.required.map(\.path))
    let reportPaths = Set(report.requiredDocumentationAreas.map(\.path))

    #expect(reportPaths == requiredPaths)

    let root = repositoryRoot
    for path in requiredPaths {
        #expect(FileManager.default.fileExists(
            atPath: root.appendingPathComponent(path).path
        ))
    }
}

@Test
func goalCodewiseClosureEvidencePathsExist() {
    let root = repositoryRoot
    let report = GoalCodewiseClosureReport.codewiseClosure()

    for path in report.requirements.flatMap(\.evidence) {
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
    }
}

@Test
func goalCodewiseClosureRejectsFalseRealWorldPass() throws {
    var report = GoalCodewiseClosureReport.codewiseClosure()
    report.realWorldVerdict = .pass

    #expect(throws: GoalCodewiseClosureValidationError.passWithAssumedRealWorldClosure) {
        try report.validate()
    }
}

@Test
func goalCodewiseClosureKeepsPhysicalEvidenceOutOfSourceLevelPass() throws {
    let report = GoalCodewiseClosureReport.codewiseClosure()
    let physicalGateIDs: Set<String> = [
        GoalCodewiseRequirementID.dodMultichannelAudioBothDirections.rawValue,
        GoalCodewiseRequirementID.dodAudioLatencyMeasured.rawValue,
        GoalCodewiseRequirementID.dodJitterLossUnderrunMeasured.rawValue,
        GoalCodewiseRequirementID.dodBlackmagicVideoTXRX.rawValue
    ]
    let physicalGateItems = report.requirements.filter { physicalGateIDs.contains($0.id) }

    #expect(physicalGateItems.count == physicalGateIDs.count)
    for item in physicalGateItems {
        #expect(item.status == .codeImplemented)
        #expect(item.assumption == nil)
        #expect(item.notes.contains("real-world gate"))
    }
    #expect(report.verdict == .pass)
    #expect(report.realWorldVerdict == .partial)
}

@Test
func goalCodewiseClosureRejectsMissingRequirement() throws {
    var report = GoalCodewiseClosureReport.codewiseClosure()
    report.requirements.removeAll { $0.id == GoalCodewiseRequirementID.primaryProductGoal.rawValue }
    report.summary = GoalCodewiseClosureSummary(requirements: report.requirements)

    #expect(throws: GoalCodewiseClosureValidationError.missingRequiredRequirement(
        GoalCodewiseRequirementID.primaryProductGoal.rawValue
    )) {
        try report.validate()
    }
}

@Test
func goalCodewiseClosureValidatorPrintsBothVerdicts() throws {
    let data = try GoalCodewiseClosureReport.codewiseClosure().prettyJSONData()
    let output = try ReportValidatorSurface.validate(
        data,
        as: GoalCodewiseClosureReport.self,
        label: "GOAL.md codewise closure report",
        extraLines: { ["real-world-verdict: \($0.realWorldVerdict.rawValue)"] }
    )

    #expect(output.lines == [
        "GOAL.md codewise closure report valid: goal-codewise-closure-2026-05-05",
        "real-world-verdict: partial",
        "VERDICT: PASS"
    ])
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
