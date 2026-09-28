// Protects the E2E benchmark PASS gate's methodology reference against the documented methodology file.
import OpenLolaContracts
@testable import OpenLolaApplication
import Testing

@Test func measuredPassCandidateCitingCurrentMethodologyValidates() throws {
    let report = E2EBenchmarkSyntheticSmoke.passCandidate()
    #expect(report.thresholds.methodologyDocument == "docs/benchmark-methodology.md")
    try report.validate()
}

@Test func measuredPassCitingRetiredMethodologyDocumentStillValidates() throws {
    var report = E2EBenchmarkSyntheticSmoke.passCandidate()
    report.thresholds.methodologyDocument = "docs/benchmark-e2e-av.md"
    try report.validate()
}

@Test func measuredPassWithoutMethodologyReferenceIsRejected() {
    var report = E2EBenchmarkSyntheticSmoke.passCandidate()
    report.thresholds.methodologyDocument = "docs/unrelated.md"
    #expect(throws: E2EBenchmarkValidationError.passWithoutMethodologyReference("docs/unrelated.md")) {
        try report.validate()
    }
}
