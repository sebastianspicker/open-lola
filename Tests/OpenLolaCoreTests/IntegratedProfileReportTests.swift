import Foundation
import Testing

@testable import OpenLolaCore

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
func integratedProfileRejectsInvalidPassEvidence() throws {
    try expectIntegratedProfileError(.defaultProfileMustBeFastestAudio(.audioVideo), passCandidate: false) {
        $0.defaultProfile = .audioVideo
    }
    try expectIntegratedProfileError(.optionalProfilePromotedToDefault(.audioVideo), passCandidate: false) {
        let fastestIndex = try #require($0.profileOptions.firstIndex { $0.label == .fastestAudio })
        let videoIndex = try #require($0.profileOptions.firstIndex { $0.label == .audioVideo })
        $0.profileOptions[fastestIndex].defaultProfile = false
        $0.profileOptions[videoIndex].defaultProfile = true
    }
    try expectIntegratedProfileError(.passWithoutPassSubordinateEvidence(.integratedAv, .partial)) {
        let index = try #require($0.subordinateEvidence.firstIndex { $0.lane == .integratedAv })
        $0.subordinateEvidence[index].verdict = .partial
    }
    try expectIntegratedProfileError(.passWithoutBenchmarkScenario(.audioVideoControl)) {
        $0.benchmarkMatrix.removeAll { $0.scenario == .audioVideoControl }
    }
    try expectIntegratedProfileError(.audioLatencyDegradationMustBeLast) {
        $0.degradationOrder = [
            .reduceVideoQuality,
            .increaseAudioLatency,
            .reduceVideoFrameRate,
            .disableLighting,
        ]
    }
    try expectIntegratedProfileError(.videoDisableMustPrecedeAudioLatency) {
        $0.degradationOrder = [
            .reduceVideoQuality,
            .reduceVideoFrameRate,
            .disableLighting,
            .increaseAudioLatency,
        ]
    }
    try expectIntegratedProfileError(.duplicateDegradationStep(.reduceVideoFrameRate)) {
        $0.degradationOrder = [
            .reduceVideoQuality,
            .reduceVideoFrameRate,
            .reduceVideoFrameRate,
            .disableLighting,
            .disableVideo,
            .increaseAudioLatency,
        ]
    }
    try expectIntegratedProfileError(.passUnderreportsProfileLatencyCost(
        profile: .audioVideo,
        reportedMicroseconds: 1,
        observedMicroseconds: 300
    )) {
        let audioOnlyIndex = try #require($0.benchmarkMatrix.firstIndex { $0.scenario == .audioOnly })
        let index = try #require($0.profileOptions.firstIndex { $0.label == .audioVideo })
        let rowIndex = try #require($0.benchmarkMatrix.firstIndex { $0.scenario == .audioVideo })
        $0.profileOptions[index].latencyCostMicroseconds = 1
        $0.benchmarkMatrix[rowIndex].metrics.audioLatencyP99Microseconds =
            $0.benchmarkMatrix[audioOnlyIndex].metrics.audioLatencyP99Microseconds + 300
    }
    try expectIntegratedProfileError(.passProfileLatencyBelowAudioOnly(
        profile: .audioVideo,
        observedMicroseconds: -500
    )) {
        let audioOnlyIndex = try #require($0.benchmarkMatrix.firstIndex { $0.scenario == .audioOnly })
        let rowIndex = try #require($0.benchmarkMatrix.firstIndex { $0.scenario == .audioVideo })
        $0.benchmarkMatrix[audioOnlyIndex].metrics.audioLatencyP99Microseconds = 2_500
        $0.benchmarkMatrix[rowIndex].metrics.audioLatencyP99Microseconds = 2_000
    }
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

private func expectIntegratedProfileError(
    _ expected: IntegratedProfileValidationError,
    passCandidate: Bool = true,
    mutate: (inout IntegratedProfileReport) throws -> Void
) throws {
    var report = passCandidate ? try passCandidateReport() : IntegratedProfileSyntheticSmoke.run()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
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
