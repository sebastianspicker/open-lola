import Foundation
import Testing

@testable import OpenLolaCore

@Test
func integratedProfileFixtureDecodesAndValidates() throws {
    let report = try loadIntegratedProfileFixture(named: "integrated-profile-partial")

    try report.validate()

    #expect(report.defaultProfile == .fastestAudio)
    #expect(report.verdict == .partial)
    #expect(report.profileOptions.contains { $0.label == .audioVideo && $0.latencyCostMicroseconds > 0 })
    #expect(report.profileOptions.contains { $0.label == .audioLighting && $0.latencyCostMicroseconds > 0 })
    #expect(report.benchmarkMatrix.map(\.scenario) == [
        .audioOnly,
        .audioVideo,
        .audioControl,
        .audioVideoControl,
    ])
    #expect(report.degradationOrder.first == .reduceVideoQuality)
    #expect(report.degradationOrder == [
        .reduceVideoQuality,
        .reduceVideoFrameRate,
        .disableLighting,
        .disableVideo,
        .increaseAudioLatency,
    ])
    #expect(report.degradationOrder.last == .increaseAudioLatency)
}

@Test
func integratedProfileSyntheticSmokeEmitsPartialReport() throws {
    let report = IntegratedProfileSyntheticSmoke.run()

    try report.validate()

    #expect(report.id == "m12-integrated-profile-synthetic-smoke")
    #expect(report.defaultProfile == .fastestAudio)
    #expect(report.verdict == .partial)
    #expect(report.aggregateSubordinateVerdict == .partial)
    #expect(report.profileOptions.first { $0.label == .fastestAudio }?.defaultProfile == true)
    #expect(report.profileOptions.filter(\.defaultProfile).count == 1)
}

@Test
func integratedProfileRunConfigurationParsesRequiredArguments() throws {
    let configuration = try IntegratedProfileRunConfiguration.parse([
        "--fastest-audio", "m07-fastest-audio-required",
        "--integrated-av", "m10-integrated-av-required",
        "--lighting-control", "m11-lighting-control-required",
        "--audio-only", "matrix-audio-only-required",
        "--audio-video", "matrix-audio-video-required",
        "--audio-control", "matrix-audio-control-required",
        "--audio-video-control", "matrix-audio-video-control-required",
        "--output", "reports/m12-integrated-profile-run.json",
    ])

    #expect(configuration.fastestAudioReportId == "m07-fastest-audio-required")
    #expect(configuration.integratedAvReportId == "m10-integrated-av-required")
    #expect(configuration.lightingControlReportId == "m11-lighting-control-required")
    #expect(configuration.matrixReportIds[.audioVideoControl] == "matrix-audio-video-control-required")
    #expect(configuration.outputPath == "reports/m12-integrated-profile-run.json")
}

@Test
func integratedProfileRunnerAggregatesPartialReferences() throws {
    let configuration = IntegratedProfileRunConfiguration(
        fastestAudioReportId: "m07-fastest-audio-required",
        integratedAvReportId: "m10-integrated-av-required",
        lightingControlReportId: "m11-lighting-control-required",
        matrixReportIds: [
            .audioOnly: "matrix-audio-only-required",
            .audioVideo: "matrix-audio-video-required",
            .audioControl: "matrix-audio-control-required",
            .audioVideoControl: "matrix-audio-video-control-required",
        ],
        outputPath: "reports/m12-integrated-profile-run.json"
    )

    let report = IntegratedProfileRunner.run(configuration: configuration)

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.aggregateSubordinateVerdict == .partial)
    #expect(report.subordinateEvidence.map(\.reportId).contains("m10-integrated-av-required"))
    #expect(report.benchmarkMatrix.first { $0.scenario == .audioControl }?.reportId == "matrix-audio-control-required")
}

@Test
func integratedProfilePassCandidateValidates() throws {
    let report = try passCandidateReport()

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.aggregateSubordinateVerdict == .pass)
}

@Test
func integratedProfileRejectsNonFastestDefaultProfile() throws {
    var report = IntegratedProfileSyntheticSmoke.run()
    report.defaultProfile = .audioVideo

    #expect(throws: IntegratedProfileValidationError.defaultProfileMustBeFastestAudio(.audioVideo)) {
        try report.validate()
    }
}

@Test
func integratedProfileRejectsOptionalProfileAsDefault() throws {
    var report = IntegratedProfileSyntheticSmoke.run()
    let fastestIndex = try #require(report.profileOptions.firstIndex { $0.label == .fastestAudio })
    let videoIndex = try #require(report.profileOptions.firstIndex { $0.label == .audioVideo })
    report.profileOptions[fastestIndex].defaultProfile = false
    report.profileOptions[videoIndex].defaultProfile = true

    #expect(throws: IntegratedProfileValidationError.optionalProfilePromotedToDefault(.audioVideo)) {
        try report.validate()
    }
}

@Test
func integratedProfileRejectsPassWithPartialSubordinateEvidence() throws {
    var report = try passCandidateReport()
    let index = try #require(report.subordinateEvidence.firstIndex { $0.lane == .integratedAv })
    report.subordinateEvidence[index].verdict = .partial

    #expect(throws: IntegratedProfileValidationError.passWithoutPassSubordinateEvidence(.integratedAv, .partial)) {
        try report.validate()
    }
}

@Test
func integratedProfileRejectsPassWithMissingBenchmarkScenario() throws {
    var report = try passCandidateReport()
    report.benchmarkMatrix.removeAll { $0.scenario == .audioVideoControl }

    #expect(throws: IntegratedProfileValidationError.passWithoutBenchmarkScenario(.audioVideoControl)) {
        try report.validate()
    }
}

@Test
func integratedProfileRejectsPassWhenAudioLatencyIsNotLastDegradationStep() throws {
    var report = try passCandidateReport()
    report.degradationOrder = [
        .reduceVideoQuality,
        .increaseAudioLatency,
        .reduceVideoFrameRate,
        .disableLighting,
    ]

    #expect(throws: IntegratedProfileValidationError.audioLatencyDegradationMustBeLast) {
        try report.validate()
    }
}

@Test
func integratedProfileRejectsVideoProfileWithoutDisableVideoBeforeAudioLatency() throws {
    var report = try passCandidateReport()
    report.degradationOrder = [
        .reduceVideoQuality,
        .reduceVideoFrameRate,
        .disableLighting,
        .increaseAudioLatency,
    ]

    #expect(throws: IntegratedProfileValidationError.videoDisableMustPrecedeAudioLatency) {
        try report.validate()
    }
}

@Test
func integratedProfileRejectsDuplicateDegradationStep() throws {
    var report = try passCandidateReport()
    report.degradationOrder = [
        .reduceVideoQuality,
        .reduceVideoFrameRate,
        .reduceVideoFrameRate,
        .disableLighting,
        .disableVideo,
        .increaseAudioLatency,
    ]

    #expect(throws: IntegratedProfileValidationError.duplicateDegradationStep(.reduceVideoFrameRate)) {
        try report.validate()
    }
}

@Test
func integratedProfileRejectsPassWithUnderreportedOptionalCost() throws {
    var report = try passCandidateReport()
    let index = try #require(report.profileOptions.firstIndex { $0.label == .audioVideo })
    report.profileOptions[index].latencyCostMicroseconds = 1

    #expect(throws: IntegratedProfileValidationError.passUnderreportsProfileLatencyCost(
        profile: .audioVideo,
        reportedMicroseconds: 1,
        observedMicroseconds: 300
    )) {
        try report.validate()
    }
}

@Test
func integratedProfileRejectsPassWhenOptionalLatencyIsBelowAudioOnly() throws {
    var report = try passCandidateReport()
    let rowIndex = try #require(report.benchmarkMatrix.firstIndex { $0.scenario == .audioVideo })
    report.benchmarkMatrix[rowIndex].metrics.audioLatencyP99Microseconds = 2_000

    #expect(throws: IntegratedProfileValidationError.passProfileLatencyBelowAudioOnly(
        profile: .audioVideo,
        observedMicroseconds: -500
    )) {
        try report.validate()
    }
}

@Test
func integratedProfileJSONRoundTripPreservesReport() throws {
    let report = IntegratedProfileSyntheticSmoke.run()
    let decoded = try IntegratedProfileReport.decode(from: report.prettyJSONData())

    #expect(decoded == report)
}

private func passCandidateReport() throws -> IntegratedProfileReport {
    var report = IntegratedProfileSyntheticSmoke.run()
    report.id = "m12-integrated-profile-pass-candidate"
    report.title = "M12 integrated profile pass candidate"
    report.runMode = .measured
    report.verdict = .pass
    report.notes = "Measured pass candidate for integrated-profile validator behavior."

    for index in report.profileOptions.indices {
        report.profileOptions[index].sourceReportId = "measured-\(report.profileOptions[index].label.rawValue)-source"
        report.profileOptions[index].costReportId = "measured-\(report.profileOptions[index].label.rawValue)-cost"
        report.profileOptions[index].verdict = .pass
    }

    for index in report.subordinateEvidence.indices {
        report.subordinateEvidence[index].reportId = "measured-\(report.subordinateEvidence[index].lane.rawValue)-report"
        report.subordinateEvidence[index].verdict = .pass
        report.subordinateEvidence[index].measured = true
        report.subordinateEvidence[index].physicalPassEvidence = true
    }

    for index in report.benchmarkMatrix.indices {
        report.benchmarkMatrix[index].reportId = "measured-\(report.benchmarkMatrix[index].scenario.rawValue)-matrix"
        report.benchmarkMatrix[index].verdict = .pass
        report.benchmarkMatrix[index].measured = true
        report.benchmarkMatrix[index].physicalEvidence = true
    }

    return report
}

private func loadIntegratedProfileFixture(named name: String) throws -> IntegratedProfileReport {
    let url = try integratedProfileFixtureURL(named: name)
    return try IntegratedProfileReport.decode(from: Data(contentsOf: url))
}

private func integratedProfileFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "IntegratedProfileReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "IntegratedProfileReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}
