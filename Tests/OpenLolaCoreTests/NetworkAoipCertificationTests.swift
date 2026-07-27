// Verifies that a partial network AoIP certification requires a not-tested reason for missing reports.
import Foundation
import Testing

@testable import OpenLolaCore

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
func networkAoipCertificationRejectsInvalidPassEvidence() throws {
    try expectNetworkAoipCertificationError(.passWithoutMeasuredRun) {
        $0.runMode = .synthetic
    }
    try expectNetworkAoipCertificationError(.passWithoutRouteCertification) {
        $0.routeCertificationReport = nil
    }
    try expectNetworkAoipCertificationError(.passWithoutDriftPlcCertification) {
        $0.driftPlcCertificationReport = nil
    }
    try expectNetworkAoipCertificationError(.passWithoutAoipEvaluation) {
        $0.aoipEvaluationReport = nil
    }
    try expectNetworkAoipCertificationError(.passWithoutAcceptedRouteCertification) {
        $0.routeCertificationReport?.verdict = .partial
    }
    try expectNetworkAoipCertificationError(.passWithoutAcceptedDriftPlcCertification) {
        $0.driftPlcCertificationReport?.verdict = .partial
    }
    try expectNetworkAoipCertificationError(.passWithoutAcceptedAoipEvaluation) {
        $0.aoipEvaluationReport?.verdict = .partial
    }
    try expectNetworkAoipCertificationError(.passWithBaselineMismatch) {
        $0.aoipEvaluationReport?.baselineComparison.directUdpPcmRouteReportId = "other-route"
    }
    try expectNetworkAoipCertificationError(.passWithoutPtpArtifact) {
        $0.ptpArtifactPath = nil
    }
    try expectNetworkAoipCertificationError(.passWithPlaceholderField(
        "profileArtifactPath"
    )) {
        $0.profileArtifactPath = "private/reports/fixture-profile.md"
    }
}

@Test
func networkAoipCertificationPassCandidateValidates() throws {
    let report = try makeNetworkAoipCertificationPassCandidate()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.aoipEvaluationReport?.mode == .avb)
}

private func expectNetworkAoipCertificationError(
    _ expected: NetworkAoipCertificationValidationError,
    mutate: (inout NetworkAoipCertificationReport) throws -> Void
) throws {
    var report = try makeNetworkAoipCertificationPassCandidate()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}
