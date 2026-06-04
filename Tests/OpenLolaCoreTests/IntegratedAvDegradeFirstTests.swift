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
    let videoTransport = try VideoTransportRunner.run(
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
    try videoTransport.validate()

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

    let degradedVideoTransport = IntegratedAvNetworkDegradation.apply(
        impairment: impairment,
        to: videoTransport
    )
    try degradedVideoTransport.validate()

    let report = IntegratedAvRunner.run(
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
        videoTransportReport: degradedVideoTransport
    )
    try report.validate()

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
