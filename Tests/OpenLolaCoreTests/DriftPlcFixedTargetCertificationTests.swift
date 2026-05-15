import Foundation
import Testing

@testable import OpenLolaCore

@Test
func driftPlcFixedTargetCertificationPartialFixtureDecodesAndValidates() throws {
    let report = try loadDriftPlcFixedTargetCertificationFixture(
        named: "g05-drift-plc-certification-partial"
    )

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.runMode == .synthetic)
    #expect(report.routeCertificationReport == nil)
    #expect(report.driftPlcReport == nil)
}

@Test
func driftPlcFixedTargetCertificationSyntheticSmokeEmitsPartialReport() throws {
    let report = DriftPlcFixedTargetCertificationSyntheticSmoke.run()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.runMode == .synthetic)
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithoutMeasuredRun() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.runMode = .synthetic

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithoutMeasuredRun) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithoutRouteCertification() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.routeCertificationReport = nil

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithoutRouteCertification) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithoutDriftReport() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.driftPlcReport = nil

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithoutDriftPlcReport) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithoutRealtimeEngineReport() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.sourceRealtimeEngineReport = nil

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithoutRealtimeEngineReport) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithoutAcceptedRealtimeEngineReport() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.sourceRealtimeEngineReport?.verdict = .partial

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithoutAcceptedRealtimeEngineReport) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithoutAcceptedRouteCertification() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.routeCertificationReport?.verdict = .partial

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithoutAcceptedRouteCertification) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithoutAcceptedDriftReport() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.driftPlcReport?.verdict = .partial

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithoutAcceptedDriftPlcReport) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithRealtimeRouteMismatch() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.sourceRealtimeEngineReport?.sourceRouteCertificationReport?.id = "different-g04-route"

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithRealtimeRouteMismatch(
        expected: "g04-direct-link-certification-measured",
        actual: "different-g04-route"
    )) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithPacketModeMismatch() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.driftPlcReport?.packetMode.framesPerPacket = 64

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithPacketModeMismatch) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithRouteMismatch() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.driftPlcReport?.route = RouteIdentity(
        label: "dedicated-switch-reference",
        topology: "mac-to-mac-direct-cable"
    )

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithRouteMismatch) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithoutLolaBaselineComparison() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.lolaBaselineComparison = nil

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithoutLolaBaselineComparison) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithoutMeasuredLolaBaseline() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.lolaBaselineComparison?.availability = .unavailable
    report.lolaBaselineComparison?.notTestedReason = "LoLa host was unavailable for this run."

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithoutMeasuredLolaBaseline) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithLolaPacketModeMismatch() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.lolaBaselineComparison?.packetMode.framesPerPacket = 64

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithLolaPacketModeMismatch) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithLolaRouteMismatch() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.lolaBaselineComparison?.route = RouteIdentity(
        label: "other-route",
        topology: "mac-to-mac-direct-cable"
    )

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithLolaRouteMismatch) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithTrailingLolaBaseline() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.lolaBaselineComparison?.result = .openLolaSlower

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithLolaTrailingBaseline(
        .openLolaSlower
    )) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithoutRunArtifactPath() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.runArtifactPath = nil

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithoutRunArtifactPath) {
        try report.validate()
    }
}

@Test
func driftPlcFixedTargetCertificationRejectsPassWithPlaceholderEvidence() throws {
    var report = try makeDriftPlcFixedTargetCertificationPassCandidate()
    report.runArtifactPath = "docs/mac-port/reports/fixture-drift-plc.json"

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithPlaceholderField(
        "runArtifactPath"
    )) {
        try report.validate()
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

@Test
func driftPlcFixedTargetCertificationJSONRoundTripPreservesReport() throws {
    let report = try loadDriftPlcFixedTargetCertificationFixture(
        named: "g05-drift-plc-certification-partial"
    )
    let jsonData = try report.prettyJSONData()
    let decoded = try DriftPlcFixedTargetCertificationReport.decode(from: jsonData)

    #expect(decoded == report)
}
