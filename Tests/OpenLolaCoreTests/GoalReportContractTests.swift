import Foundation
import Testing

@Test
func goalReportFilesDeclareTemplateAndEvidenceBoundaries() throws {
    let expectations: [(path: String, markers: [String])] = [
        (
            "Sources/OpenLolaCore/Release/Goal/GoalCodewiseClosure.swift",
            [
                "Source-level GOAL.md closure ledger",
                "does not replace measured runtime evidence",
            ]
        ),
        (
            "Sources/OpenLolaCore/Release/Goal/GoalRuntimeEvidenceTemplate.swift",
            [
                "Runtime evidence template for operator handoff",
                "not measured runtime closure",
            ]
        ),
        (
            "Sources/OpenLolaCore/Release/Goal/GoalRuntimePreflight.swift",
            [
                "Current-host preflight probe",
                "does not execute the two-Mac runtime closure",
            ]
        ),
        (
            "Sources/OpenLolaCore/Release/Goal/GoalCompletionAudit.swift",
            [
                "Traceability audit template",
                "does not replace measured runtime evidence",
            ]
        ),
    ]

    for expectation in expectations {
        let source = try String(
            contentsOf: repositoryRoot().appendingPathComponent(expectation.path),
            encoding: .utf8
        )
        for marker in expectation.markers {
            #expect(source.contains(marker))
        }
    }
}

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
