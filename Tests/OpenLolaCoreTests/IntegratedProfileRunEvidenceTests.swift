import Foundation
import Testing

@testable import OpenLolaCore

@Test
func integratedProfileRunConfigurationParsesRuntimeReportPaths() throws {
    let configuration = try IntegratedProfileRunConfiguration.parse([
        "--fastest-audio", "m07-fastest-audio-required",
        "--integrated-av", "m10-integrated-av-required",
        "--lighting-control", "m12-lighting-gate-required",
        "--audio-only", "matrix-audio-only-required",
        "--audio-video", "matrix-audio-video-required",
        "--audio-control", "matrix-audio-control-required",
        "--audio-video-control", "matrix-audio-video-control-required",
        "--fastest-audio-report", "reports/m07-latency-profile.json",
        "--integrated-av-report", "reports/m10-integrated-av.json",
        "--lighting-control-report", "reports/m12-lighting-gate.json",
        "--output", "reports/m12-integrated-profile-run.json",
    ])

    #expect(configuration.fastestAudioReportPath == "reports/m07-latency-profile.json")
    #expect(configuration.integratedAvReportPath == "reports/m10-integrated-av.json")
    #expect(configuration.lightingControlReportPath == "reports/m12-lighting-gate.json")
}

@Test
func integratedProfileRunAggregatesMeasuredPartialRuntimeEvidence() throws {
    let fastestAudio = try measuredPartialFastestAudioReport()
    let videoTransport = try localhostVideoTransportReport()
    let integratedAv = try integratedAvReport(videoTransport: videoTransport)
    var lightingControl = try lightingGateReport(durationSeconds: 60)
    lightingControl.id = "synthetic-rig-lighting-gate-measured"
    try lightingControl.validate()

    let report = IntegratedProfileRunner.run(
        configuration: integratedProfileRunConfigurationWithReportPaths(),
        runtimeEvidence: IntegratedProfileRuntimeEvidence(
            fastestAudio: fastestAudio,
            integratedAv: integratedAv,
            lightingControl: lightingControl
        )
    )

    try report.validate()
    expectMeasuredPartialIntegratedProfileRun(
        report,
        fastestAudio: fastestAudio,
        integratedAv: integratedAv,
        lightingControl: lightingControl,
        videoTransport: videoTransport
    )
}

private func expectMeasuredPartialIntegratedProfileRun(
    _ report: IntegratedProfileReport,
    fastestAudio: LatencyBenchmarkReport,
    integratedAv: IntegratedAvReport,
    lightingControl: LightingFixtureGateReport,
    videoTransport: VideoTransportReport
) {
    #expect(report.runMode == .measured)
    #expect(report.verdict == .partial)
    #expect(report.aggregateSubordinateVerdict == .partial)
    #expect(report.profileOptions.first { $0.label == .fastestAudio }?.sourceReportId == fastestAudio.id)
    #expect(report.profileOptions.first { $0.label == .audioVideo }?.sourceReportId == integratedAv.id)
    #expect(report.profileOptions.first { $0.label == .audioLighting }?.sourceReportId == lightingControl.id)
    #expect(report.subordinateEvidence.first { $0.lane == .audioRoute }?.measured == true)
    #expect(report.subordinateEvidence.first { $0.lane == .videoTransport }?.reportId == videoTransport.id)
    #expect(report.subordinateEvidence.first { $0.lane == .lightingControl }?.measured == true)
    #expect(report.subordinateEvidence.allSatisfy { !$0.physicalPassEvidence })
    #expect(report.benchmarkMatrix.first { $0.scenario == .audioOnly }?.reportId == fastestAudio.id)
    #expect(report.benchmarkMatrix.first { $0.scenario == .audioVideo }?.reportId == integratedAv.id)
    #expect(report.benchmarkMatrix.first { $0.scenario == .audioControl }?.reportId == lightingControl.id)
    #expect(report.benchmarkMatrix.first { $0.scenario == .audioVideoControl }?.measured == true)
    #expect(report.benchmarkMatrix.allSatisfy { !$0.physicalEvidence })
}

@Test
func integratedProfileCombinedMetricsUseWorstCaseGaugesAndSummedEvents() throws {
    let videoTransport = try localhostVideoTransportReport()
    let integratedAv = try measuredIntegratedAvReportWithAudioVideoLoad(videoTransport: videoTransport)
    let lightingControl = try measuredLightingGateReportWithAudioImpact()

    let report = IntegratedProfileRunner.run(
        configuration: integratedProfileRunConfiguration(),
        runtimeEvidence: IntegratedProfileRuntimeEvidence(
            integratedAv: integratedAv,
            lightingControl: lightingControl
        )
    )

    try report.validate()

    let row = try #require(report.benchmarkMatrix.first { $0.scenario == .audioVideoControl })
    expectCombinedAudioVideoControlMetrics(row.metrics)
}

private func expectCombinedAudioVideoControlMetrics(_ metrics: IntegratedProfileBenchmarkMetrics) {
    #expect(metrics.audioLatencyP99Microseconds == 500)
    #expect(metrics.audioJitterP99Microseconds == 110)
    #expect(metrics.lostPackets == 2)
    #expect(metrics.latePackets == 3)
    #expect(metrics.underruns == 11)
    #expect(metrics.droppedVideoFrames == 5)
    #expect(metrics.cpuP99Percent == 73)
    #expect(metrics.measurementDurationSeconds == 60)
    #expect(metrics.durationMismatch == false)
    #expect(metrics.callbackDeadlineWarnings == 2)
}

@Test
func integratedProfileRunRejectsCombinedRuntimeMetricsWithMismatchedDurations() throws {
    let videoTransport = try localhostVideoTransportReport()
    let integratedAv = IntegratedAvRunner.run(
        configuration: integratedAvRunConfiguration(durationSeconds: 60),
        videoTransportReport: videoTransport
    )
    let lightingControl = try lightingGateReport(durationSeconds: 30)

    let report = IntegratedProfileRunner.run(
        configuration: integratedProfileRunConfiguration(),
        runtimeEvidence: IntegratedProfileRuntimeEvidence(
            integratedAv: integratedAv,
            lightingControl: lightingControl
        )
    )

    #expect(throws: IntegratedProfileValidationError.benchmarkDurationMismatch(.audioVideoControl)) {
        try report.validate()
    }
}

private func measuredPartialFastestAudioReport() throws -> LatencyBenchmarkReport {
    var fastestAudio = try LatencyProfileBenchmarkSyntheticSmoke.run()
    fastestAudio.id = "m07-fastest-audio-measured-partial"
    fastestAudio.runMode = .measured
    fastestAudio.evidenceKind = .sandboxLimited
    fastestAudio.verdict = .partial
    try fastestAudio.validate()
    return fastestAudio
}

private func localhostVideoTransportReport() throws -> VideoTransportReport {
    let report = try VideoTransportRunner.run(
        configuration: VideoTransportRunConfiguration(
            mode: .raw,
            peer: "127.0.0.1",
            port: 0,
            durationSeconds: 1,
            outputPath: "unused",
            width: 32,
            height: 18,
            frameRate: 2,
            queueDepth: 1,
            routeKind: .localhost,
            packetCapturePoint: "local-udp-socket-loopback"
        )
    )
    try report.validate()
    return report
}

private func integratedAvReport(videoTransport: VideoTransportReport) throws -> IntegratedAvReport {
    let report = IntegratedAvRunner.run(
        configuration: integratedAvRunConfiguration(durationSeconds: 60),
        videoTransportReport: videoTransport
    )
    try report.validate()
    return report
}

private func integratedAvRunConfiguration(durationSeconds: Int) -> IntegratedAvRunConfiguration {
    IntegratedAvRunConfiguration(
        artifacts: IntegratedAvRunConfiguration.ArtifactPaths(
            audioBaselineReportId: "m05-route-baseline-required",
            videoTransportReportPath: "reports/m09-video-transport.json",
            outputPath: "reports/m10-integrated-av-run.json"
        ),
        media: IntegratedAvRunConfiguration.MediaOptions(
            videoCaptureEnabled: true,
            videoTransportEnabled: true,
            videoPreviewEnabled: false
        ),
        control: IntegratedAvRunConfiguration.ControlOptions(
            oscControlEnabled: true,
            atemReadOnlyHost: "192.0.2.10"
        ),
        durationSeconds: durationSeconds
    )
}

private func lightingGateReport(durationSeconds: Double) throws -> LightingFixtureGateReport {
    try LightingGateRunner.run(
        configuration: LightingGateRunConfiguration(
            audioBaselineReportId: "m05-route-baseline-required",
            oscCueReportId: "m11-osc-loopback-required",
            protocolName: .sacn,
            interopTarget: .qlcPlus,
            universe: 1,
            networkMode: .loopbackUnicast,
            destinationAddress: "127.0.0.1",
            port: LightingControlProtocol.sacn.defaultPort,
            isolatedNetworkVerified: false,
            explicitlyArmed: false,
            captureTool: "not-run",
            capturePoint: "local-loopback",
            durationSeconds: durationSeconds,
            outputPath: "reports/m12-lighting-gate-run.json"
        )
    )
}

private func measuredIntegratedAvReportWithAudioVideoLoad(
    videoTransport: VideoTransportReport
) throws -> IntegratedAvReport {
    var report = try integratedAvReport(videoTransport: videoTransport)
    report.runMode = .measured
    report.audio.integratedCallbackP99Microseconds = 420
    report.audio.packetAge.p99Microseconds = 80
    report.audio.lostPackets = 2
    report.audio.latePackets = 3
    report.audio.underruns = 4
    report.audio.hiddenPlayoutGrowthDetected = true
    report.video.receiverDroppedFrames = 5
    report.systemLoad.cpuP99Percent = 73
    return report
}

private func measuredLightingGateReportWithAudioImpact() throws -> LightingFixtureGateReport {
    var report = try lightingGateReport(durationSeconds: 60)
    report.runMode = .measured
    report.audioImpact.lightingCallbackP99Microseconds = 500
    report.audioImpact.lightingCallbackMaxMicroseconds = 610
    report.audioImpact.underruns = 7
    report.audioImpact.hiddenAudioImpactDetected = true
    return report
}

private func integratedProfileRunConfigurationWithReportPaths() -> IntegratedProfileRunConfiguration {
    IntegratedProfileRunConfiguration(
        fastestAudioReportId: "m07-fastest-audio-required",
        integratedAvReportId: "m10-integrated-av-required",
        lightingControlReportId: "m12-lighting-gate-required",
        matrixReportIds: integratedProfileMatrixReportIds,
        fastestAudioReportPath: "reports/m07-latency-profile.json",
        integratedAvReportPath: "reports/m10-integrated-av.json",
        lightingControlReportPath: "reports/m12-lighting-gate.json",
        outputPath: "reports/m12-integrated-profile-run.json"
    )
}

private func integratedProfileRunConfiguration() -> IntegratedProfileRunConfiguration {
    IntegratedProfileRunConfiguration(
        fastestAudioReportId: "m07-fastest-audio-required",
        integratedAvReportId: "m10-integrated-av-required",
        lightingControlReportId: "m12-lighting-gate-required",
        matrixReportIds: integratedProfileMatrixReportIds,
        outputPath: "reports/m12-integrated-profile-run.json"
    )
}

private let integratedProfileMatrixReportIds: [IntegratedProfileBenchmarkScenario: String] = [
    .audioOnly: "matrix-audio-only-required",
    .audioVideo: "matrix-audio-video-required",
    .audioControl: "matrix-audio-control-required",
    .audioVideoControl: "matrix-audio-video-control-required",
]
