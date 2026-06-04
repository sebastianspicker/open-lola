import Testing

@testable import OpenLolaCore

@Test
func directAudioFirstDropsLateVideoWithoutAddingAudioDelay() throws {
    let policy = AVSyncPolicy.policy(for: .directAudioFirst)
    let decision = AVTimestampAligner.decision(
        videoTimestampNanoseconds: 80_000_000,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: policy
    )

    #expect(policy.audioMayDelayForVideo == false)
    #expect(decision.action == .dropVideo)
    #expect(decision.reason == .staleVideo)
    #expect(decision.audioDelayFramesAddedForVideo == 0)
}

@Test
func balancedAVRendersFramesInsideAlignmentWindow() throws {
    let policy = AVSyncPolicy.policy(for: .balancedAV)
    let decision = AVTimestampAligner.decision(
        videoTimestampNanoseconds: 112_000_000,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: policy
    )

    #expect(decision.action == .renderNow)
    #expect(decision.reason == .insideAlignmentWindow)
    #expect(decision.avOffsetMicroseconds == 12_000)
    #expect(decision.audioDelayFramesAddedForVideo == 0)
}

@Test
func balancedAVUsesStaleVideoThresholdBeforeDroppingBehindAudio() throws {
    let policy = AVSyncPolicy.policy(for: .balancedAV)
    let behindButUsable = AVTimestampAligner.decision(
        videoTimestampNanoseconds: 70_000_000,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: policy
    )
    let stale = AVTimestampAligner.decision(
        videoTimestampNanoseconds: 59_000_000,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: policy
    )

    #expect(policy.videoAlignmentToleranceMicroseconds == 20_000)
    #expect(policy.staleVideoDropThresholdMicroseconds == 40_000)
    #expect(behindButUsable.action == .renderNow)
    #expect(behindButUsable.reason == .videoBehindWithinStaleThreshold)
    #expect(behindButUsable.audioDelayFramesAddedForVideo == 0)
    #expect(stale.action == .dropVideo)
    #expect(stale.reason == .staleVideo)
    #expect(stale.audioDelayFramesAddedForVideo == 0)
}

@Test
func multiVideoPerformanceDropsVideoBeforeAudioImpact() throws {
    let policy = AVSyncPolicy.policy(for: .multiVideoPerformance)
    let decision = AVTimestampAligner.decision(
        videoTimestampNanoseconds: 70_000_000,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: policy
    )

    #expect(policy.profile == .multiVideoPerformance)
    #expect(decision.action == .dropVideo)
    #expect(decision.reason == .staleVideo)
    #expect(decision.audioDelayFramesAddedForVideo == 0)
}

@Test
func balancedAVDefersFutureVideoOnVideoWorkerOnly() throws {
    let policy = AVSyncPolicy.policy(for: .balancedAV)
    let decision = AVTimestampAligner.decision(
        videoTimestampNanoseconds: 160_000_000,
        audioPlayoutTimestampNanoseconds: 100_000_000,
        policy: policy
    )

    #expect(decision.action == .deferVideo)
    #expect(decision.reason == .videoAheadOfAudio)
    #expect(decision.audioDelayFramesAddedForVideo == 0)
}

@Test
func avTimestampDecisionUsesCurrentPolicyAfterProfileSwitch() throws {
    let queuedVideoTimestampNanoseconds: UInt64 = 112_000_000
    let audioPlayoutTimestampNanoseconds: UInt64 = 100_000_000
    let directAudioFirst = AVSyncPolicy.policy(for: .directAudioFirst)
    let balancedAV = AVSyncPolicy.policy(for: .balancedAV)

    let beforeSwitch = AVTimestampAligner.decision(
        videoTimestampNanoseconds: queuedVideoTimestampNanoseconds,
        audioPlayoutTimestampNanoseconds: audioPlayoutTimestampNanoseconds,
        policy: directAudioFirst
    )
    let afterSwitch = AVTimestampAligner.decision(
        videoTimestampNanoseconds: queuedVideoTimestampNanoseconds,
        audioPlayoutTimestampNanoseconds: audioPlayoutTimestampNanoseconds,
        policy: balancedAV
    )

    #expect(beforeSwitch.action == .deferVideo)
    #expect(beforeSwitch.reason == .videoAheadOfAudio)
    #expect(afterSwitch.action == .renderNow)
    #expect(afterSwitch.reason == .insideAlignmentWindow)
    #expect(afterSwitch.audioDelayFramesAddedForVideo == 0)
}

@Test
func videoTransportSyntheticSmokeReportsAVSyncMetrics() throws {
    let report = try VideoTransportSyntheticSmoke.run()

    try report.validate()

    let avSync = try #require(report.avSync)
    #expect(avSync.audioTimestampOrigin == .audioPacketSenderHostTimeNanoseconds)
    #expect(avSync.videoTimestampOrigin == .videoPacketTimestampNanoseconds)
    #expect(avSync.audioRouteAge.p99Microseconds == 80)
    #expect(avSync.videoFrameAge == report.frameAge)
    #expect(avSync.avOffset.p99Microseconds > 0)
    #expect(avSync.audioDelayFramesAddedForVideo == 0)
    #expect(avSync.offsetMeasurementMethod.contains("measured"))
}
