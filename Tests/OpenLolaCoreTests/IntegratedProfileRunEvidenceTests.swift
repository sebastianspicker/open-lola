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
    var fastestAudio = try LatencyProfileBenchmarkSyntheticSmoke.run()
    fastestAudio.id = "m07-fastest-audio-measured-partial"
    fastestAudio.runMode = .measured
    fastestAudio.evidenceKind = .sandboxLimited
    fastestAudio.verdict = .partial
    try fastestAudio.validate()

    let videoTransport = try VideoTransportRunner.run(
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
    try videoTransport.validate()

    let integratedAv = IntegratedAvRunner.run(
        configuration: IntegratedAvRunConfiguration(
            audioBaselineReportId: "m05-route-baseline-required",
            videoCaptureEnabled: true,
            videoTransportEnabled: true,
            videoPreviewEnabled: false,
            oscControlEnabled: true,
            atemReadOnlyHost: "192.0.2.10",
            durationSeconds: 60,
            videoTransportReportPath: "reports/m09-video-transport.json",
            outputPath: "reports/m10-integrated-av-run.json"
        ),
        videoTransportReport: videoTransport
    )
    try integratedAv.validate()

    var lightingControl = try LightingGateRunner.run(
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
            durationSeconds: 60,
            outputPath: "reports/m12-lighting-gate-run.json"
        )
    )
    lightingControl.id = "synthetic-rig-lighting-gate-measured"
    try lightingControl.validate()

    let configuration = IntegratedProfileRunConfiguration(
        fastestAudioReportId: "m07-fastest-audio-required",
        integratedAvReportId: "m10-integrated-av-required",
        lightingControlReportId: "m12-lighting-gate-required",
        matrixReportIds: [
            .audioOnly: "matrix-audio-only-required",
            .audioVideo: "matrix-audio-video-required",
            .audioControl: "matrix-audio-control-required",
            .audioVideoControl: "matrix-audio-video-control-required",
        ],
        fastestAudioReportPath: "reports/m07-latency-profile.json",
        integratedAvReportPath: "reports/m10-integrated-av.json",
        lightingControlReportPath: "reports/m12-lighting-gate.json",
        outputPath: "reports/m12-integrated-profile-run.json"
    )

    let report = IntegratedProfileRunner.run(
        configuration: configuration,
        runtimeEvidence: IntegratedProfileRuntimeEvidence(
            fastestAudio: fastestAudio,
            integratedAv: integratedAv,
            lightingControl: lightingControl
        )
    )

    try report.validate()

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
    let videoTransport = try VideoTransportRunner.run(
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
    var integratedAv = IntegratedAvRunner.run(
        configuration: IntegratedAvRunConfiguration(
            audioBaselineReportId: "m05-route-baseline-required",
            videoCaptureEnabled: true,
            videoTransportEnabled: true,
            videoPreviewEnabled: false,
            oscControlEnabled: true,
            atemReadOnlyHost: "192.0.2.10",
            durationSeconds: 60,
            videoTransportReportPath: "reports/m09-video-transport.json",
            outputPath: "reports/m10-integrated-av-run.json"
        ),
        videoTransportReport: videoTransport
    )
    integratedAv.runMode = .measured
    integratedAv.audio.integratedCallbackP99Microseconds = 420
    integratedAv.audio.packetAge.p99Microseconds = 80
    integratedAv.audio.lostPackets = 2
    integratedAv.audio.latePackets = 3
    integratedAv.audio.underruns = 4
    integratedAv.audio.hiddenPlayoutGrowthDetected = true
    integratedAv.video.receiverDroppedFrames = 5
    integratedAv.systemLoad.cpuP99Percent = 73

    var lightingControl = try LightingGateRunner.run(
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
            durationSeconds: 60,
            outputPath: "reports/m12-lighting-gate-run.json"
        )
    )
    lightingControl.runMode = .measured
    lightingControl.audioImpact.lightingCallbackP99Microseconds = 500
    lightingControl.audioImpact.lightingCallbackMaxMicroseconds = 610
    lightingControl.audioImpact.underruns = 7
    lightingControl.audioImpact.hiddenAudioImpactDetected = true

    let report = IntegratedProfileRunner.run(
        configuration: IntegratedProfileRunConfiguration(
            fastestAudioReportId: "m07-fastest-audio-required",
            integratedAvReportId: "m10-integrated-av-required",
            lightingControlReportId: "m12-lighting-gate-required",
            matrixReportIds: [
                .audioOnly: "matrix-audio-only-required",
                .audioVideo: "matrix-audio-video-required",
                .audioControl: "matrix-audio-control-required",
                .audioVideoControl: "matrix-audio-video-control-required",
            ],
            outputPath: "reports/m12-integrated-profile-run.json"
        ),
        runtimeEvidence: IntegratedProfileRuntimeEvidence(
            integratedAv: integratedAv,
            lightingControl: lightingControl
        )
    )

    try report.validate()

    let row = try #require(report.benchmarkMatrix.first { $0.scenario == .audioVideoControl })
    #expect(row.metrics.audioLatencyP99Microseconds == 500)
    #expect(row.metrics.audioJitterP99Microseconds == 110)
    #expect(row.metrics.lostPackets == 2)
    #expect(row.metrics.latePackets == 3)
    #expect(row.metrics.underruns == 11)
    #expect(row.metrics.droppedVideoFrames == 5)
    #expect(row.metrics.cpuP99Percent == 73)
    #expect(row.metrics.measurementDurationSeconds == 60)
    #expect(row.metrics.durationMismatch == false)
    #expect(row.metrics.callbackDeadlineWarnings == 2)
}

@Test
func integratedProfileRunRejectsCombinedRuntimeMetricsWithMismatchedDurations() throws {
    let videoTransport = try VideoTransportRunner.run(
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
    let integratedAv = IntegratedAvRunner.run(
        configuration: IntegratedAvRunConfiguration(
            audioBaselineReportId: "m05-route-baseline-required",
            videoCaptureEnabled: true,
            videoTransportEnabled: true,
            videoPreviewEnabled: false,
            oscControlEnabled: true,
            atemReadOnlyHost: "192.0.2.10",
            durationSeconds: 60,
            videoTransportReportPath: "reports/m09-video-transport.json",
            outputPath: "reports/m10-integrated-av-run.json"
        ),
        videoTransportReport: videoTransport
    )
    let lightingControl = try LightingGateRunner.run(
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
            durationSeconds: 30,
            outputPath: "reports/m12-lighting-gate-run.json"
        )
    )

    let report = IntegratedProfileRunner.run(
        configuration: IntegratedProfileRunConfiguration(
            fastestAudioReportId: "m07-fastest-audio-required",
            integratedAvReportId: "m10-integrated-av-required",
            lightingControlReportId: "m12-lighting-gate-required",
            matrixReportIds: [
                .audioOnly: "matrix-audio-only-required",
                .audioVideo: "matrix-audio-video-required",
                .audioControl: "matrix-audio-control-required",
                .audioVideoControl: "matrix-audio-video-control-required",
            ],
            outputPath: "reports/m12-integrated-profile-run.json"
        ),
        runtimeEvidence: IntegratedProfileRuntimeEvidence(
            integratedAv: integratedAv,
            lightingControl: lightingControl
        )
    )

    #expect(throws: IntegratedProfileValidationError.benchmarkDurationMismatch(.audioVideoControl)) {
        try report.validate()
    }
}
