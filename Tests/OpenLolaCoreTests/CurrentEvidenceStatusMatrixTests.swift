// Verifies that current evidence status matrix captures non-source-completable gates.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func currentEvidenceStatusMatrixCapturesNonSourceCompletableGates() throws {
    let report = CurrentEvidenceStatusMatrixReport.current()
    let sourceCompletability = report.realWorldTests.map(\.sourceCompletability).joined(separator: "\n")
    let release = try #require(report.crosswalk.first { $0.lane == .releaseFieldClosure })
    let windows = try #require(report.crosswalk.first { $0.lane == .windowsLoLaCompatibility })

    #expect(sourceCompletability.contains("Not source-completable"))
    #expect(sourceCompletability.contains("Windows peer evidence is external"))
    #expect(release.status == .blocked)
    #expect(windows.status == .partial)
    #expect(release.missingBeforePass.joined(separator: "\n").contains("notarized app evidence"))
}

@Test
func currentEvidenceStatusMatrixUsesUniqueTrackedPublicSources() {
    let report = CurrentEvidenceStatusMatrixReport.current()
    let paths = report.sources.map(\.path)
    let root = currentEvidenceRepositoryRoot()

    #expect(Set(paths).count == paths.count)
    #expect(paths.contains(report.sourceMatrixPath))
    for path in paths {
        #expect(!path.hasPrefix("archive/"))
        #expect(!path.hasPrefix("private/"))
        #expect(path != "docs/implementation-handoff.md")
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
    }
}

@Test
func currentEvidenceStatusMatrixRejectsFalsePass() {
    let report = CurrentEvidenceStatusMatrixReport(
        id: "current-evidence-status-matrix-2026-05-11",
        title: "Current evidence status matrix",
        capturedAt: "2026-05-11T00:00:00Z",
        sourceMatrixPath: "archive/2026-05-11-research-archive/docs/research/RESEARCH_CURRENT_STATUS_MATRIX_2026.md",
        verdict: .pass,
        summary: CurrentEvidenceStatusMatrixReport.current().summary,
        sources: CurrentEvidenceStatusMatrixReport.current().sources,
        crosswalk: CurrentEvidenceStatusMatrixReport.current().crosswalk,
        realWorldTests: CurrentEvidenceStatusMatrixReport.current().realWorldTests,
        notes: "false pass fixture"
    )

    #expect(throws: CurrentEvidenceStatusMatrixValidationError.passForbidden) {
        try report.validate()
    }
}

@Test
func currentEvidenceStatusMatrixValidatorPrintsSourceAndTaskSummary() throws {
    let data = try CurrentEvidenceStatusMatrixReport.current().prettyJSONData()
    let output = try ReportValidatorSurface.validate(
        data,
        as: CurrentEvidenceStatusMatrixReport.self,
        label: "current evidence status matrix report",
        extraLines: {
            [
                "source-matrix: \($0.sourceMatrixPath)",
                "real-world-tasks: \($0.summary.realWorldTaskCount)"
            ]
        }
    )

    #expect(output.lines == [
        "current evidence status matrix report valid: current-evidence-status-matrix-2026-07-24",
        "source-matrix: docs/current-state.md",
        "real-world-tasks: 11",
        "VERDICT: PARTIAL"
    ])
}

private func currentEvidenceRepositoryRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
