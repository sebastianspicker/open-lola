// Verifies that AoIP evaluation rejects invalid pass evidence.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func aoipEvaluationRejectsInvalidPassEvidence() throws {
    var report = try loadAoipFixture(named: "aoip-avb-partial")
    report.verdict = .pass
    report.usage = .interop
    report.baselineComparison.measuredOnSamePath = true
    report.baselineComparison.evaluatedModeP99Microseconds = 200
    report.stress.measured = true
    report.stress.packetAge = UdpPcmPacketAgeMetrics(
        p50Microseconds: 100,
        p95Microseconds: 150,
        p99Microseconds: 200,
        maxMicroseconds: 220
    )
    report.switchProfile.linkRateMbps = 1_000
    report.ptp.profile = ""

    #expect(throws: AoipEvaluationValidationError.missingPtpField("ptp.profile")) {
        try report.validate()
    }

    report = try passCandidateReport()
    report.baselineComparison.measuredOnSamePath = false

    #expect(throws: AoipEvaluationValidationError.passWithoutSamePathBaseline) {
        try report.validate()
    }

    report = try passCandidateReport()
    report.stress.measured = false

    #expect(throws: AoipEvaluationValidationError.passWithoutMeasuredStress) {
        try report.validate()
    }

    report = try passCandidateReport()
    report.usage = .defaultReplacement

    #expect(throws: AoipEvaluationValidationError.defaultReplacementNotAllowed) {
        try report.validate()
    }

    report = try passCandidateReport()
    report.baselineComparison.evaluatedModeP99Microseconds = 260

    #expect(throws: AoipEvaluationValidationError.passWithoutMeasuredSuperiority(
        evaluatedP99Microseconds: 260,
        baselineP99Microseconds: 240
    )) {
        try report.validate()
    }
}

private func passCandidateReport() throws -> AoipEvaluationReport {
    var report = try loadAoipFixture(named: "aoip-avb-partial")
    report.verdict = .pass
    report.usage = .interop
    report.baselineComparison.measuredOnSamePath = true
    report.baselineComparison.evaluatedModeP99Microseconds = 200
    report.stress.measured = true
    report.stress.competingTrafficProfile = "synthetic competing traffic"
    report.stress.recoveryBehavior = "bounded"
    report.stress.packetAge = UdpPcmPacketAgeMetrics(
        p50Microseconds: 100,
        p95Microseconds: 150,
        p99Microseconds: 200,
        maxMicroseconds: 220
    )
    report.switchProfile.linkRateMbps = 1_000
    report.switchProfile.trafficClass = "audio"
    report.switchProfile.streamReservation = "documented"
    report.switchProfile.schedule = "documented"
    report.ptp = AoipPtpProfile(
        version: "IEEE 1588-2019",
        profile: "802.1AS",
        domain: "0",
        masterClockId: "synthetic-master",
        lockState: "locked"
    )
    return report
}

private func loadAoipFixture(named name: String) throws -> AoipEvaluationReport {
    let url = try aoipFixtureURL(named: name)
    return try AoipEvaluationReport.decode(from: Data(contentsOf: url))
}

private func aoipFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "AoipEvaluationReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "AoipEvaluationReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}
