// Verifies that drift PLC fixed target certification rejects invalid pass evidence.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func driftPlcFixedTargetCertificationRejectsInvalidPassEvidence() throws {
    try expectDriftPlcFixedTargetCertificationRejectsMissingEvidence()
    try expectDriftPlcFixedTargetCertificationRejectsPartialEvidence()
    try expectDriftPlcFixedTargetCertificationRejectsRouteMismatches()
    try expectDriftPlcFixedTargetCertificationRejectsLolaBaselineIssues()
}

private func expectDriftPlcFixedTargetCertificationRejectsMissingEvidence() throws {
    try expectDriftPlcFixedTargetCertificationError(.passWithoutMeasuredRun) {
        $0.runMode = .synthetic
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithoutRouteCertification) {
        $0.routeCertificationReport = nil
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithoutDriftPlcReport) {
        $0.driftPlcReport = nil
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithoutRealtimeEngineReport) {
        $0.sourceRealtimeEngineReport = nil
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithoutLolaBaselineComparison) {
        $0.lolaBaselineComparison = nil
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithoutRunArtifactPath) {
        $0.runArtifactPath = nil
    }
}

private func expectDriftPlcFixedTargetCertificationRejectsPartialEvidence() throws {
    try expectDriftPlcFixedTargetCertificationError(.passWithoutAcceptedRealtimeEngineReport) {
        $0.sourceRealtimeEngineReport?.verdict = .partial
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithoutAcceptedRouteCertification) {
        $0.routeCertificationReport?.verdict = .partial
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithoutAcceptedDriftPlcReport) {
        $0.driftPlcReport?.verdict = .partial
    }
}

private func expectDriftPlcFixedTargetCertificationRejectsRouteMismatches() throws {
    try expectDriftPlcFixedTargetCertificationError(.passWithRealtimeRouteMismatch(
        expected: "g04-direct-link-certification-measured",
        actual: "different-g04-route"
    )) {
        $0.sourceRealtimeEngineReport?.sourceRouteCertificationReport?.id = "different-g04-route"
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithPacketModeMismatch) {
        $0.driftPlcReport?.packetMode.framesPerPacket = 64
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithRouteMismatch) {
        $0.driftPlcReport?.route = RouteIdentity(
            label: "dedicated-switch-reference",
            topology: "mac-to-mac-direct-cable"
        )
    }
}

private func expectDriftPlcFixedTargetCertificationRejectsLolaBaselineIssues() throws {
    try expectDriftPlcFixedTargetCertificationError(.passWithoutMeasuredLolaBaseline) {
        $0.lolaBaselineComparison?.availability = .unavailable
        $0.lolaBaselineComparison?.notTestedReason = "LoLa host was unavailable for this run."
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithLolaPacketModeMismatch) {
        $0.lolaBaselineComparison?.packetMode.framesPerPacket = 64
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithLolaRouteMismatch) {
        $0.lolaBaselineComparison?.route = RouteIdentity(
            label: "other-route",
            topology: "mac-to-mac-direct-cable"
        )
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithLolaTrailingBaseline(.openLolaSlower)) {
        $0.lolaBaselineComparison?.result = .openLolaSlower
    }
    try expectDriftPlcFixedTargetCertificationError(.passWithPlaceholderField("runArtifactPath")) {
        $0.runArtifactPath = "private/reports/fixture-drift-plc.json"
    }
}

@Test
func driftPlcFixedTargetCertificationPassCandidateValidates() throws {
    let report = try makeDriftPlcFixedTargetCertificationPassCandidate()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.driftPlcReport?.metrics.durationSeconds == 3_600)
    #expect(report.lolaBaselineComparison?.result == .openLolaFaster)
}

private func expectDriftPlcFixedTargetCertificationError(
    _ expected: DriftPlcFixedTargetCertificationValidationError,
    mutate: (inout DriftPlcFixedTargetCertificationReport) throws -> Void
) throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}
