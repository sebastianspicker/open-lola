// Characterizes pure evidence aggregation and stable report-validator console contracts.
import Foundation
import Testing
@testable import OpenLolaEvidenceModels
import OpenLolaContracts

@Test func performanceCounterRejectsInvalidSamplesWithoutChangingPercentiles() {
    let summary = PerformanceCounterSummary.fromSamples([10, 20, 30, -1, .infinity])

    #expect(summary.sampleCount == 3)
    #expect(summary.invalidSampleCount == 2)
    #expect(summary.p50Microseconds == 20)
    #expect(summary.p95Microseconds == 30)
    #expect(summary.maxMicroseconds == 30)
}

@Test func reportValidatorConsoleOutputPreservesLinesAndVerdict() throws {
    let report = EvidenceFixture(id: "evidence-7", verdict: .partial)
    let output = try ReportValidatorSurface.validate(
        report.prettyJSONData(),
        as: EvidenceFixture.self,
        label: "evidence",
        extraLines: { _ in ["scope: model"] }
    )

    #expect(output.lines == ["evidence valid: evidence-7", "scope: model", "VERDICT: PARTIAL"])
}

private struct EvidenceFixture: ReportValidatingArtifact, Equatable {
    let id: String
    let verdict: MeasurementVerdict

    func validate() throws {}
}
