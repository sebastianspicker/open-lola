import Foundation
import Testing

@testable import OpenLolaCore

@Test
func networkAoipCertificationPartialFixtureDecodesAndValidates() throws {
    let report = try loadNetworkAoipCertificationFixture(
        named: "g06-network-aoip-certification-partial"
    )

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.runMode == .synthetic)
    #expect(report.routeCertificationReport == nil)
    #expect(report.aoipEvaluationReport == nil)
}

@Test
func networkAoipCertificationSyntheticSmokeEmitsPartialReport() throws {
    let report = NetworkAoipCertificationSyntheticSmoke.run()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.runMode == .synthetic)
}

@Test
func networkAoipCertificationPartialRequiresNotTestedReasonWhenReportsAreMissing() throws {
    var report = try loadNetworkAoipCertificationFixture(
        named: "g06-network-aoip-certification-partial"
    )
    report.notTestedReason = nil

    #expect(throws: NetworkAoipCertificationValidationError.partialWithoutReason) {
        try report.validate()
    }
}

@Test
func networkAoipCertificationRejectsPassWithoutMeasuredRun() throws {
    var report = try makeNetworkAoipCertificationPassCandidate()
    report.runMode = .synthetic

    #expect(throws: NetworkAoipCertificationValidationError.passWithoutMeasuredRun) {
        try report.validate()
    }
}

@Test
func networkAoipCertificationRejectsPassWithoutRouteCertification() throws {
    var report = try makeNetworkAoipCertificationPassCandidate()
    report.routeCertificationReport = nil

    #expect(throws: NetworkAoipCertificationValidationError.passWithoutRouteCertification) {
        try report.validate()
    }
}

@Test
func networkAoipCertificationRejectsPassWithoutDriftCertification() throws {
    var report = try makeNetworkAoipCertificationPassCandidate()
    report.driftPlcCertificationReport = nil

    #expect(throws: NetworkAoipCertificationValidationError.passWithoutDriftPlcCertification) {
        try report.validate()
    }
}

@Test
func networkAoipCertificationRejectsPassWithoutAoipReport() throws {
    var report = try makeNetworkAoipCertificationPassCandidate()
    report.aoipEvaluationReport = nil

    #expect(throws: NetworkAoipCertificationValidationError.passWithoutAoipEvaluation) {
        try report.validate()
    }
}

@Test
func networkAoipCertificationRejectsPassWithoutAcceptedRouteCertification() throws {
    var report = try makeNetworkAoipCertificationPassCandidate()
    report.routeCertificationReport?.verdict = .partial

    #expect(throws: NetworkAoipCertificationValidationError.passWithoutAcceptedRouteCertification) {
        try report.validate()
    }
}

@Test
func networkAoipCertificationRejectsPassWithoutAcceptedDriftCertification() throws {
    var report = try makeNetworkAoipCertificationPassCandidate()
    report.driftPlcCertificationReport?.verdict = .partial

    #expect(throws: NetworkAoipCertificationValidationError.passWithoutAcceptedDriftPlcCertification) {
        try report.validate()
    }
}

@Test
func networkAoipCertificationRejectsPassWithoutAcceptedAoipEvaluation() throws {
    var report = try makeNetworkAoipCertificationPassCandidate()
    report.aoipEvaluationReport?.verdict = .partial

    #expect(throws: NetworkAoipCertificationValidationError.passWithoutAcceptedAoipEvaluation) {
        try report.validate()
    }
}

@Test
func networkAoipCertificationRejectsPassWithBaselineMismatch() throws {
    var report = try makeNetworkAoipCertificationPassCandidate()
    report.aoipEvaluationReport?.baselineComparison.directUdpPcmRouteReportId = "other-route"

    #expect(throws: NetworkAoipCertificationValidationError.passWithBaselineMismatch) {
        try report.validate()
    }
}

@Test
func networkAoipCertificationRejectsPassWithoutArtifacts() throws {
    var report = try makeNetworkAoipCertificationPassCandidate()
    report.ptpArtifactPath = nil

    #expect(throws: NetworkAoipCertificationValidationError.passWithoutPtpArtifact) {
        try report.validate()
    }
}

@Test
func networkAoipCertificationRejectsPassWithPlaceholderEvidence() throws {
    var report = try makeNetworkAoipCertificationPassCandidate()
    report.profileArtifactPath = "docs/mac-port/reports/fixture-profile.md"

    #expect(throws: NetworkAoipCertificationValidationError.passWithPlaceholderField(
        "profileArtifactPath"
    )) {
        try report.validate()
    }
}

@Test
func networkAoipCertificationPassCandidateValidates() throws {
    let report = try makeNetworkAoipCertificationPassCandidate()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.aoipEvaluationReport?.mode == .avb)
}

@Test
func networkAoipCertificationJSONRoundTripPreservesReport() throws {
    let report = try loadNetworkAoipCertificationFixture(
        named: "g06-network-aoip-certification-partial"
    )
    let jsonData = try report.prettyJSONData()
    let decoded = try NetworkAoipCertificationReport.decode(from: jsonData)

    #expect(decoded == report)
}
