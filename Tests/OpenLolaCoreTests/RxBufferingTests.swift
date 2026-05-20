import Foundation
import Testing

@testable import OpenLolaCore


@Test
func rxBufferPoliciesExposeExplicitBoundsCostAndFastestEligibility() throws {
    let direct = try RxBufferPolicy.direct(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        targetPackets: 1
    )
    let small = try RxBufferPolicy.small(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        targetPackets: 2
    )
    let adaptive = try RxBufferPolicy.adaptive(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        minimumPackets: 1,
        initialPackets: 1,
        maximumPackets: 4
    )
    let stableWan = try RxBufferPolicy.stableWan(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        targetPackets: 8,
        maximumPackets: 16
    )

    try direct.validate()
    try small.validate()
    try adaptive.validate()
    try stableWan.validate()

    #expect(direct.minimumTargetFrames == 0)
    #expect(direct.maximumTargetFrames == 32)
    #expect(direct.targetFrames == 32)
    #expect(direct.fastestAudioPassEligible)

    #expect(small.minimumTargetFrames == 32)
    #expect(small.maximumTargetFrames == 64)
    #expect(small.latencyCostPackets == 2)
    #expect(small.latencyCostMicroseconds == 1_333.3333333333333)
    #expect(!small.fastestAudioPassEligible)

    #expect(adaptive.maximumTargetFrames == 128)
    #expect(adaptive.adaptationChangesOutsideCallback)
    #expect(!adaptive.fastestAudioPassEligible)

    #expect(stableWan.targetFrames == 256)
    #expect(stableWan.maximumTargetFrames == 512)
    #expect(!stableWan.fastestAudioPassEligible)
}

@Test
func rxBufferPolicyInvalidFramesPerPacketReturnsTypedValidationError() throws {
    let policy = RxBufferPolicy(
        profile: .direct,
        framesPerPacket: 0,
        sampleRateHertz: 48_000,
        minimumTargetFrames: 0,
        targetFrames: 0,
        maximumTargetFrames: 0,
        fastestAudioPassEligible: true,
        adaptationChangesOutsideCallback: true,
        notes: "Invalid policy fixture for typed validation."
    )

    #expect(policy.targetPackets == 0)
    #expect(policy.maximumTargetPackets == 0)
    #expect(throws: RxBufferPolicyValidationError.nonPositiveField("framesPerPacket")) {
        try policy.validate()
    }
    #expect(throws: RxBufferPolicyValidationError.nonPositiveField("framesPerPacket")) {
        _ = try RxBufferPolicy.direct(framesPerPacket: 0, sampleRateHertz: 48_000)
    }
}

@Test
func rxBufferPolicyValidatorPreservesTypedPrimitiveErrors() throws {
    var emptyNotes = try RxBufferPolicy.direct(framesPerPacket: 32, sampleRateHertz: 48_000)
    emptyNotes.notes = ""
    #expect(throws: RxBufferPolicyValidationError.emptyField("notes")) {
        try emptyNotes.validate()
    }

    var negativeSnapshot = RxBufferRuntimeSnapshot(policy: try .direct(framesPerPacket: 32, sampleRateHertz: 48_000))
    negativeSnapshot.latePackets = -1
    #expect(throws: RxBufferPolicyValidationError.negativeField("latePackets")) {
        try negativeSnapshot.validate()
    }

    let nonFiniteEvent = RxBufferTargetChangeEvent(
        sequenceNumber: 1,
        targetFramesBefore: 32,
        targetFramesAfter: 64,
        reason: "test",
        changedInsideAudioCallback: false,
        latencyCostMicrosecondsBefore: .nan,
        latencyCostMicrosecondsAfter: 1
    )
    #expect(throws: RxBufferPolicyValidationError.nonFiniteField("latencyCostMicrosecondsBefore")) {
        try nonFiniteEvent.validate()
    }
}

@Test
func realtimePacketHandoffRxPoliciesPreserveDirectDropsAndSmallFixedTarget() throws {
    var directHandoff = try RealtimeAudioPacketHandoff(
        configuration: realtimeRxBufferConfiguration(
            rxBufferPolicy: try .direct(
                framesPerPacket: 32,
                sampleRateHertz: 48_000,
                targetPackets: 1
            )
        )
    )
    let latePacket = UdpPcmPacket.silence(
        sequenceNumber: 7,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 100,
        mode: rxBufferPacketMode()
    )

    #expect(directHandoff.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    #expect(directHandoff.renderCallback() == .silence(startFrame: 32, frameCount: 32))
    #expect(try directHandoff.receive(latePacket) == .droppedLate)

    #expect(directHandoff.metrics.latePackets == 1)
    #expect(directHandoff.metrics.droppedNetworkBlocks == 1)
    #expect(directHandoff.metrics.rxBuffer?.latePackets == 1)
    #expect(directHandoff.metrics.rxBuffer?.currentTargetFrames == 32)
    #expect(!directHandoff.metrics.hiddenPlayoutGrowthDetected)

    let policy = try RxBufferPolicy.small(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        targetPackets: 2
    )
    var smallHandoff = try RealtimeAudioPacketHandoff(
        configuration: realtimeRxBufferConfiguration(
            playoutTargetFrames: 64,
            rxBufferPolicy: policy
        )
    )
    let packet = UdpPcmPacket.silence(
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 100,
        mode: rxBufferPacketMode()
    )

    #expect(try smallHandoff.receive(packet) == .queued)
    #expect(smallHandoff.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    #expect(smallHandoff.renderCallback() == .silence(startFrame: 32, frameCount: 32))
    #expect(smallHandoff.renderCallback() == .played(
        RealtimeAudioFrameBlock(
            startFrame: 64,
            frameCount: 32,
            payloadByteCount: 128,
            hostTimeNanoseconds: 100
        )
    ))

    #expect(smallHandoff.metrics.rxBuffer?.policy == policy)
    #expect(smallHandoff.metrics.rxBuffer?.maximumObservedTargetFrames == 64)
    #expect(smallHandoff.metrics.rxBuffer?.latencyCostMicroseconds == 1_333.3333333333333)
    #expect(smallHandoff.metrics.outputUnderrunBlocks == 2)
}

@Test
func adaptiveRxBufferControllerUsesHysteresisBoundsAndQuietDecrease() throws {
    let policy = try RxBufferPolicy.adaptive(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        minimumPackets: 1,
        initialPackets: 1,
        maximumPackets: 3
    )
    var controller = try RxBufferAdaptiveController(
        policy: policy,
        increaseAfterSamples: 2,
        decreaseAfterSamples: 3,
        highJitterMicroseconds: 900,
        lowJitterMicroseconds: 250
    )

    #expect(controller.observe(.sample(1, jitterP99Microseconds: 950)).targetFrames == 32)
    #expect(controller.observe(.sample(2, jitterP99Microseconds: 980)).targetFrames == 64)
    #expect(controller.observe(.sample(3, jitterP99Microseconds: 1_200, latePackets: 1)).targetFrames == 64)
    #expect(controller.observe(.sample(4, jitterP99Microseconds: 1_100, underruns: 1)).targetFrames == 96)
    #expect(controller.observe(.sample(5, jitterP99Microseconds: 1_500, latePackets: 1)).targetFrames == 96)
    #expect(controller.observe(.sample(6, jitterP99Microseconds: 1_500, underruns: 1)).targetFrames == 96)

    #expect(controller.observe(.sample(7, jitterP99Microseconds: 200)).targetFrames == 96)
    #expect(controller.observe(.sample(8, jitterP99Microseconds: 210)).targetFrames == 96)
    #expect(controller.observe(.sample(9, jitterP99Microseconds: 220)).targetFrames == 64)
    #expect(controller.targetChangeEvents.count == 3)
    #expect(controller.targetChangeEvents.allSatisfy { !$0.changedInsideAudioCallback })

    let quietPolicy = try RxBufferPolicy.adaptive(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        minimumPackets: 1,
        initialPackets: 1,
        maximumPackets: 2
    )
    var quietController = try RxBufferAdaptiveController(
        policy: quietPolicy,
        increaseAfterSamples: 1,
        decreaseAfterSamples: 2,
        highJitterMicroseconds: 900,
        lowJitterMicroseconds: 250
    )

    #expect(quietController.observe(.sample(1, jitterP99Microseconds: 950)).targetFrames == 64)
    #expect(quietController.observe(.sample(2, jitterP99Microseconds: 200)).targetFrames == 64)
    #expect(quietController.observe(.sample(3, jitterP99Microseconds: 200)).targetFrames == 32)
    #expect(quietController.targetChangeEvents.map(\.targetFramesAfter) == [64, 32])
}

@Test
func deterministicImpairmentSimulatorDistinguishesLossLateDuplicateFragmentLossAndJitterMetrics() throws {
    let profile = RxImpairmentProfile(
        seed: 42,
        packetCount: 12,
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        baseTransitMicroseconds: 100,
        jitterAmplitudeMicroseconds: 80,
        lossEveryNthPacket: 5,
        duplicateEveryNthPacket: 4,
        reorderEveryNthPacket: 3,
        lateEveryNthPacket: 6,
        fragmentCount: 4,
        fragmentLossEveryNthPacket: 7
    )

    let first = try RxImpairmentSimulator.run(profile: profile)
    let second = try RxImpairmentSimulator.run(profile: profile)

    #expect(first == second)
    #expect(first.summary.sentPackets == 12)
    #expect(first.summary.wholePacketLosses == 2)
    #expect(first.summary.fragmentLosses == 1)
    #expect(first.summary.deadlineLatePackets == 2)
    #expect(first.summary.duplicatePackets == 3)
    #expect(first.summary.reorderedPackets > 0)
    #expect(first.summary.deliveredPackets == first.events.count)
    #expect(first.summary.jitter.maxMicroseconds >= first.summary.jitter.p99Microseconds)

    var originals: Set<UInt64> = []
    for event in first.events {
        if event.duplicate {
            #expect(originals.contains(event.sequenceNumber))
        } else {
            originals.insert(event.sequenceNumber)
        }
    }

    let withDuplicates = try RxImpairmentSimulator.run(profile: RxImpairmentProfile(
        seed: 1,
        packetCount: 4,
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        baseTransitMicroseconds: 100,
        jitterAmplitudeMicroseconds: 0,
        lossEveryNthPacket: nil,
        duplicateEveryNthPacket: 1,
        reorderEveryNthPacket: nil,
        lateEveryNthPacket: nil,
        fragmentCount: 1,
        fragmentLossEveryNthPacket: nil
    ))
    let withoutDuplicates = try RxImpairmentSimulator.run(profile: RxImpairmentProfile(
        seed: 1,
        packetCount: 4,
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        baseTransitMicroseconds: 100,
        jitterAmplitudeMicroseconds: 0,
        lossEveryNthPacket: nil,
        duplicateEveryNthPacket: nil,
        reorderEveryNthPacket: nil,
        lateEveryNthPacket: nil,
        fragmentCount: 1,
        fragmentLossEveryNthPacket: nil
    ))

    #expect(withDuplicates.summary.duplicatePackets == 4)
    #expect(withDuplicates.summary.jitter == withoutDuplicates.summary.jitter)
}

@Test
func rxBufferImpairmentSimulator_isReproducibleWithSameSeed() throws {
    let profile = rxBufferImpairmentSimulatorDomainProfile()

    let first = try RxImpairmentSimulator.run(profile: profile)
    let second = try RxImpairmentSimulator.run(profile: profile)

    #expect(first.events.map(\.packetAgeMicroseconds) == second.events.map(\.packetAgeMicroseconds))
    #expect(first.summary.packetAge == second.summary.packetAge)
    #expect(first.summary.jitter == second.summary.jitter)
}

@Test
func rxBufferImpairmentSimulator_producesPacketAgesWithinDomainBounds() throws {
    let profile = rxBufferImpairmentSimulatorDomainProfile()
    let result = try RxImpairmentSimulator.run(profile: profile)
    let maxExpectedDelayMicroseconds = profile.baseTransitMicroseconds + profile.jitterAmplitudeMicroseconds

    #expect(result.events.isEmpty == false)
    #expect(result.events.allSatisfy { $0.packetAgeMicroseconds >= 0 })
    #expect(result.events.allSatisfy { $0.packetAgeMicroseconds <= maxExpectedDelayMicroseconds })
}

@Test
func rxBufferBenchmarkRunnerMeasuresProfilesAndRejectsFalsePass() throws {
    let report = try RxBufferBenchmarkRunner.runLocal(packetCount: 32)

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.evidenceKind == .localRuntime)
    #expect(report.rows.map(\.profile) == RxBufferProfile.allCases)
    #expect(report.rows.allSatisfy { !$0.physicalEvidence })

    let direct = try #require(report.rows.first { $0.profile == .direct })
    let adaptive = try #require(report.rows.first { $0.profile == .adaptive })
    let stableWan = try #require(report.rows.first { $0.profile == .stableWan })

    #expect(direct.fastestPassEligible)
    #expect(!adaptive.fastestPassEligible)
    #expect(adaptive.benchmark.targetChangeEvents.allSatisfy { !$0.changedInsideAudioCallback })
    #expect(adaptive.benchmark.targetFramesOverTime.count > 1)
    #expect(stableWan.addedLatencyFrames > direct.addedLatencyFrames)
    #expect(stableWan.addedLatencyMicroseconds > direct.addedLatencyMicroseconds)
    #expect(stableWan.faults.underruns <= direct.faults.underruns)

    let defaultReport = try RxBufferBenchmarkRunner.runLocal()
    let defaultAdaptive = try #require(defaultReport.rows.first { $0.profile == .adaptive })

    #expect(defaultAdaptive.benchmark.impairmentSummary?.sentPackets == 500)
    #expect(RxBufferBenchmarkRunner.defaultPacketCount >= 500)

    var falsePassReport = report
    falsePassReport.verdict = .pass

    #expect(throws: RxBufferBenchmarkValidationError.passWithoutPhysicalReferenceRig) {
        try falsePassReport.validate()
    }
}

private func realtimeRxBufferConfiguration(
    playoutTargetFrames: Int = 32,
    rxBufferPolicy: RxBufferPolicy
) -> RealtimeAudioEngineConfiguration {
    RealtimeAudioEngineConfiguration(
        inputDeviceUID: "rme-madi-uid",
        outputDeviceUID: "rme-madi-uid",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        packetFormat: .int16LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0, 1],
        playoutTargetFrames: playoutTargetFrames,
        preallocatedBlockCount: 4,
        rxBufferPolicy: rxBufferPolicy
    )
}

private func rxBufferPacketMode() -> UdpPcmPacketMode {
    UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
}

private func rxBufferImpairmentSimulatorDomainProfile() -> RxImpairmentProfile {
    RxImpairmentProfile(
        seed: 1,
        packetCount: 5,
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        baseTransitMicroseconds: 100,
        jitterAmplitudeMicroseconds: 100,
        lossEveryNthPacket: nil,
        duplicateEveryNthPacket: nil,
        reorderEveryNthPacket: nil,
        lateEveryNthPacket: nil,
        fragmentCount: 1,
        fragmentLossEveryNthPacket: nil
    )
}

private func latencyBenchmarkRxPassCandidate() throws -> LatencyBenchmarkReport {
    var report = try LatencyBenchmarkSyntheticSmoke.run()
    report.id = "rx-buffer-benchmark-physical-pass-candidate"
    report.title = "RX buffer benchmark physical pass candidate"
    report.category = .directPeerToPeer
    report.runMode = .measured
    report.evidenceKind = .physicalReferenceRig
    report.hardware = HardwareIdentity(
        referenceMac: "reference-mac-a",
        audioInterface: "RME MADIface USB",
        osVersion: "macOS 15.4",
        driverVersion: "RME 4.17"
    )
    report.route = RouteIdentity(label: "direct-wired-p2p", topology: "two-mac-direct-ethernet")
    report.timing = LatencyBenchmarkTimingMetrics(
        oneWayEstimateMicroseconds: 4_900,
        roundTripMicroseconds: 9_800,
        jitter: LatencyJitterMetrics(
            p50Microseconds: 60,
            p95Microseconds: 120,
            p99Microseconds: 180,
            maxMicroseconds: 240
        )
    )
    report.loss = LatencyBenchmarkLossMetrics(lostPackets: 0, latePackets: 0, lossPercent: 0)
    report.faults = LatencyBenchmarkFaultMetrics(
        underruns: 0,
        overruns: 0,
        missedDeadlines: 0,
        droppedFrames: 0
    )
    report.resources.allocationWarnings = []
    report.resources.threadWarnings = []
    report.rxBufferImpact = RxBufferBenchmarkImpact(
        profile: try .direct(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            targetPackets: 1
        ),
        targetFramesOverTime: [32],
        targetChangeEvents: [],
        impairmentSummary: nil
    )
    report.notes = "Physical reference-rig candidate used only for validator behavior."
    report.verdict = .pass
    try report.validate()
    return report
}
