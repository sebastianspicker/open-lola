import Foundation
import Testing

@testable import OpenLolaCore

@Test
func integratedAvReportRejectsVideoChangingAudioPlayoutTarget() throws {
    var report = try integratedAvPassCandidateReport()
    report.sync.videoMayChangeAudioPlayoutTarget = true

    #expect(throws: IntegratedAvValidationError.videoMayChangeAudioPlayoutTarget) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsSyncWithoutVideoPreAudioImpactDegradation() throws {
    var report = try integratedAvPassCandidateReport()
    report.sync.videoDegradesBeforeAudioImpact = false

    #expect(throws: IntegratedAvValidationError.videoWithoutPreAudioImpactDegradation) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutVideoDegradationBeforeRouteOrAudioImpact() throws {
    var report = try integratedAvPassCandidateReport()
    report.video.degradation.triggeredBeforeAudioOrRouteImpact = false

    #expect(throws: IntegratedAvValidationError.videoWithoutPreAudioImpactDegradation) {
        try report.validate()
    }
}

@Test
func integratedAvRunAggregatesDegradedNetworkBeforeAudioImpact() throws {
    let videoTransport = try localhostIntegratedAvVideoTransport()
    let impairment = try deterministicIntegratedAvNetworkImpairment(for: videoTransport)
    let degradedVideoTransport = try degradedIntegratedAvVideoTransport(
        videoTransport,
        impairment: impairment
    )
    let report = IntegratedAvRunner.run(
        configuration: integratedAvDegradeFirstRunConfiguration(),
        videoTransportReport: degradedVideoTransport
    )
    try report.validate()

    expectIntegratedAvDegradedNetworkReport(
        report,
        originalVideoTransport: videoTransport,
        degradedVideoTransport: degradedVideoTransport,
        impairment: impairment
    )
}

private func localhostIntegratedAvVideoTransport() throws -> VideoTransportReport {
    let report = try VideoTransportRunner.run(
        configuration: VideoTransportRunConfiguration(
            mode: .raw,
            streamCount: 1,
            visibleStreamCount: 4,
            peer: "127.0.0.1",
            port: 0,
            durationSeconds: 1,
            outputPath: "unused",
            width: 32,
            height: 18,
            frameRate: 6,
            queueDepth: 4,
            routeKind: .localhost,
            packetCapturePoint: "local-udp-socket-loopback"
        )
    )
    try report.validate()
    return report
}

private func deterministicIntegratedAvNetworkImpairment(
    for videoTransport: VideoTransportReport
) throws -> RxImpairmentSimulationResult {
    let impairment = try RxImpairmentSimulator.run(profile: RxImpairmentProfile(
        seed: 24,
        packetCount: videoTransport.transmitted.framesSent,
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        baseTransitMicroseconds: 400,
        jitterAmplitudeMicroseconds: 250,
        lossEveryNthPacket: 5,
        duplicateEveryNthPacket: nil,
        reorderEveryNthPacket: 3,
        lateEveryNthPacket: 2,
        fragmentCount: max(videoTransport.fragmentation?.maxFragmentsPerFrame ?? 1, 2),
        fragmentLossEveryNthPacket: 4
    ))
    #expect(impairment.summary.wholePacketLosses > 0)
    #expect(impairment.summary.fragmentLosses > 0)
    #expect(impairment.summary.reorderedPackets > 0)
    #expect(impairment.summary.jitter.maxMicroseconds > 0)
    return impairment
}

private func degradedIntegratedAvVideoTransport(
    _ videoTransport: VideoTransportReport,
    impairment: RxImpairmentSimulationResult
) throws -> VideoTransportReport {
    let degraded = IntegratedAvNetworkDegradation.apply(
        impairment: impairment,
        to: videoTransport
    )
    try degraded.validate()
    return degraded
}

private func integratedAvDegradeFirstRunConfiguration() -> IntegratedAvRunConfiguration {
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
        durationSeconds: 60
    )
}

private func expectIntegratedAvDegradedNetworkReport(
    _ report: IntegratedAvReport,
    originalVideoTransport videoTransport: VideoTransportReport,
    degradedVideoTransport: VideoTransportReport,
    impairment: RxImpairmentSimulationResult
) {
    #expect(report.runMode == .measured)
    #expect(report.video.receiverDroppedFrames > videoTransport.receiver.droppedFrames)
    #expect(report.video.receiverLateFrames > 0)
    #expect(report.video.transportFrameAge == impairment.summary.packetAge)
    #expect(report.video.degradation.triggeredBeforeAudioTargetChange)
    #expect(report.video.degradation.triggeredBeforeAudioOrRouteImpact == true)
    #expect(report.audio.integratedPlayoutTargetFrames == report.audio.baselinePlayoutTargetFrames)
    #expect(report.audio.integratedCallbackP99Microseconds == report.audio.baselineCallbackP99Microseconds)
    #expect(report.audio.underruns == 0)
    #expect(report.proof?.videoTransportReportId == degradedVideoTransport.id)
    #expect(report.proof?.videoTransportPacketCapturePoint == "local-udp-socket-loopback")
    #expect(report.verdict == .partial)
}
