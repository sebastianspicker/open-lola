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
func rxBufferPolicyPreconditionsPositiveFramesPerPacketBeforeTargetPacketDivision() throws {
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Timing/RxBuffering.swift")

    #expect(source.contains("precondition(framesPerPacket > 0"))
    #expect(source.range(of: "precondition(framesPerPacket > 0")?.lowerBound ?? source.endIndex
        < source.range(of: "self.framesPerPacket = framesPerPacket")?.lowerBound ?? source.startIndex)
}

@Test
func rxBufferDirectPolicyRejectsZeroTargetPackets() {
    #expect(throws: RxBufferPolicyValidationError.directTargetOutOfRange(targetPackets: 0)) {
        _ = try RxBufferPolicy.direct(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            targetPackets: 0
        )
    }
}

@Test
func rxBufferValidationUsesEmptyAndNonFiniteErrors() throws {
    var policy = try RxBufferPolicy.direct(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        targetPackets: 1
    )
    policy.notes = ""

    #expect(throws: RxBufferPolicyValidationError.emptyField("notes")) {
        try policy.validate()
    }
    #expect(throws: RxBufferPolicyValidationError.nonFiniteField("latencyCostMicrosecondsBefore")) {
        try RxBufferTargetChangeEvent(
            sequenceNumber: 1,
            targetFramesBefore: 32,
            targetFramesAfter: 64,
            reason: "test",
            changedInsideAudioCallback: false,
            latencyCostMicrosecondsBefore: .nan,
            latencyCostMicrosecondsAfter: 1
        ).validate()
    }
}

@Test
func realtimePacketHandoffDirectPolicyPreservesLateDropBehavior() throws {
    var handoff = RealtimeAudioPacketHandoff(
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

    #expect(handoff.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    #expect(handoff.renderCallback() == .silence(startFrame: 32, frameCount: 32))
    #expect(try handoff.receive(latePacket) == .droppedLate)

    #expect(handoff.metrics.latePackets == 1)
    #expect(handoff.metrics.droppedNetworkBlocks == 1)
    #expect(handoff.metrics.rxBuffer?.latePackets == 1)
    #expect(handoff.metrics.rxBuffer?.currentTargetFrames == 32)
    #expect(!handoff.metrics.hiddenPlayoutGrowthDetected)
}

@Test
func realtimePacketHandoffSmallPolicyUsesFixedVisibleTarget() throws {
    let policy = try RxBufferPolicy.small(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        targetPackets: 2
    )
    var handoff = RealtimeAudioPacketHandoff(
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

    #expect(try handoff.receive(packet) == .queued)
    #expect(handoff.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    #expect(handoff.renderCallback() == .silence(startFrame: 32, frameCount: 32))
    #expect(handoff.renderCallback() == .played(
        RealtimeAudioFrameBlock(
            startFrame: 64,
            frameCount: 32,
            payloadByteCount: 128,
            hostTimeNanoseconds: 100
        )
    ))

    #expect(handoff.metrics.rxBuffer?.policy == policy)
    #expect(handoff.metrics.rxBuffer?.maximumObservedTargetFrames == 64)
    #expect(handoff.metrics.rxBuffer?.latencyCostMicroseconds == 1_333.3333333333333)
    #expect(handoff.metrics.outputUnderrunBlocks == 2)
}

@Test
func adaptiveRxBufferControllerUsesHysteresisAndBounds() throws {
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
}

@Test
func adaptiveRxBufferControllerDecreasesAfterSustainedQuietFollowingGrowth() throws {
    let policy = try RxBufferPolicy.adaptive(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        minimumPackets: 1,
        initialPackets: 1,
        maximumPackets: 2
    )
    var controller = try RxBufferAdaptiveController(
        policy: policy,
        increaseAfterSamples: 1,
        decreaseAfterSamples: 2,
        highJitterMicroseconds: 900,
        lowJitterMicroseconds: 250
    )

    #expect(controller.observe(.sample(1, jitterP99Microseconds: 950)).targetFrames == 64)
    #expect(controller.observe(.sample(2, jitterP99Microseconds: 200)).targetFrames == 64)
    #expect(controller.observe(.sample(3, jitterP99Microseconds: 200)).targetFrames == 32)
    #expect(controller.targetChangeEvents.map(\.targetFramesAfter) == [64, 32])
}

@Test
func stableWanRxBufferIsRejectedForFastestRealtimePass() throws {
    var report = try realtimeAudioEnginePassCandidateReport()
    report.configuration.rxBufferPolicy = try .stableWan(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        targetPackets: 8,
        maximumPackets: 16
    )
    report.configuration.playoutTargetFrames = 256
    report.runtime.handoff.rxBuffer = RxBufferRuntimeSnapshot(policy: report.configuration.rxBufferPolicy!)

    #expect(throws: RealtimeAudioEngineValidationError.passWithFastestIneligibleRxBuffer(
        .stableWan
    )) {
        try report.validate()
    }
}

@Test
func deterministicImpairmentSimulatorDistinguishesLossLateDuplicateAndFragmentLoss() throws {
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
}

@Test
func deterministicImpairmentSimulatorRejectsUnboundedPacketCounts() throws {
    let profile = RxImpairmentProfile(
        seed: 42,
        packetCount: RxImpairmentSimulator.maximumPacketCount + 1,
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        baseTransitMicroseconds: 100,
        jitterAmplitudeMicroseconds: 80,
        lossEveryNthPacket: nil,
        duplicateEveryNthPacket: nil,
        reorderEveryNthPacket: nil,
        lateEveryNthPacket: nil,
        fragmentCount: 1,
        fragmentLossEveryNthPacket: nil
    )

    #expect(throws: RxImpairmentSimulationError.packetCountAboveMaximum(
        packetCount: RxImpairmentSimulator.maximumPacketCount + 1,
        maximum: RxImpairmentSimulator.maximumPacketCount
    )) {
        try RxImpairmentSimulator.run(profile: profile)
    }
}

@Test
func deterministicImpairmentSimulatorCanAffectFirstPacket() throws {
    let profile = RxImpairmentProfile(
        seed: 1,
        packetCount: 3,
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        baseTransitMicroseconds: 100,
        jitterAmplitudeMicroseconds: 0,
        lossEveryNthPacket: 1,
        duplicateEveryNthPacket: nil,
        reorderEveryNthPacket: nil,
        lateEveryNthPacket: nil,
        fragmentCount: 1,
        fragmentLossEveryNthPacket: nil
    )

    let result = try RxImpairmentSimulator.run(profile: profile)

    #expect(result.summary.wholePacketLosses == 3)
    #expect(result.events.isEmpty)
}

@Test
func deterministicImpairmentSimulatorSkipsReorderWhenArrivalWouldGoNegative() throws {
    let profile = RxImpairmentProfile(
        seed: 1,
        packetCount: 3,
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        baseTransitMicroseconds: 100,
        jitterAmplitudeMicroseconds: 0,
        lossEveryNthPacket: nil,
        duplicateEveryNthPacket: nil,
        reorderEveryNthPacket: 1,
        lateEveryNthPacket: nil,
        fragmentCount: 1,
        fragmentLossEveryNthPacket: nil
    )

    let result = try RxImpairmentSimulator.run(profile: profile)
    let first = try #require(result.events.first { $0.sequenceNumber == 0 })
    let second = try #require(result.events.first { $0.sequenceNumber == 1 })
    let third = try #require(result.events.first { $0.sequenceNumber == 2 })

    #expect(!first.reordered)
    #expect(!second.reordered)
    #expect(third.reordered)
    #expect(first.arrivalMicroseconds == 100)
}

@Test
func deterministicImpairmentSimulatorUsesLowerMedianForTwoSamplePercentiles() throws {
    let profile = RxImpairmentProfile(
        seed: 1,
        packetCount: 2,
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        baseTransitMicroseconds: 100,
        jitterAmplitudeMicroseconds: 0,
        lossEveryNthPacket: nil,
        duplicateEveryNthPacket: nil,
        reorderEveryNthPacket: nil,
        lateEveryNthPacket: 2,
        fragmentCount: 1,
        fragmentLossEveryNthPacket: nil
    )

    let result = try RxImpairmentSimulator.run(profile: profile)

    #expect(result.summary.packetAge.p50Microseconds == 100)
    #expect(result.summary.packetAge.maxMicroseconds > result.summary.packetAge.p50Microseconds)
}

@Test
func deterministicImpairmentSimulatorUsesPermutedJitterBits() throws {
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Timing/RxImpairmentSimulator.swift")

    #expect(source.contains("xorshifted"))
    #expect(source.contains("rotation"))
    #expect(!source.contains("state % 10_000"))
}

@Test
func deterministicImpairmentSimulatorExcludesDuplicatesFromJitterMetrics() throws {
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
func latencyBenchmarkReportCarriesRxBufferImpact() throws {
    let report = try LatencyBenchmarkSyntheticSmoke.run()

    try report.validate()

    let impact = try #require(report.rxBufferImpact)
    #expect(impact.profile.profile == .direct)
    #expect(impact.targetFramesOverTime == [32])
    #expect(impact.addedLatencyMicroseconds == 666.6666666666666)
    #expect(impact.impairmentSummary?.deadlineLatePackets == 1)
}

@Test
func latencyBenchmarkRejectsFastestPassWithAdaptiveRxBuffer() throws {
    var report = try latencyBenchmarkRxPassCandidate()
    report.rxBufferImpact = RxBufferBenchmarkImpact(
        profile: try .adaptive(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            minimumPackets: 1,
            initialPackets: 2,
            maximumPackets: 4
        ),
        targetFramesOverTime: [64, 96],
        targetChangeEvents: [
            RxBufferTargetChangeEvent(
                sequenceNumber: 10,
                targetFramesBefore: 64,
                targetFramesAfter: 96,
                reason: "sustained high jitter",
                changedInsideAudioCallback: false,
                latencyCostMicrosecondsBefore: 1_333.3333333333333,
                latencyCostMicrosecondsAfter: 2_000
            ),
        ],
        impairmentSummary: nil
    )

    #expect(throws: LatencyBenchmarkValidationError.passWithFastestIneligibleRxBuffer(
        .adaptive
    )) {
        try report.validate()
    }
}

@Test
func rxBufferBenchmarkRunnerMeasuresAllProfilesLocally() throws {
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
}

@Test
func rxBufferBenchmarkRunnerDefaultPacketCountSupportsAdaptiveStabilization() throws {
    let report = try RxBufferBenchmarkRunner.runLocal()
    let adaptive = try #require(report.rows.first { $0.profile == .adaptive })

    #expect(adaptive.benchmark.impairmentSummary?.sentPackets == 500)
    #expect(RxBufferBenchmarkRunner.defaultPacketCount >= 500)
}

@Test
func rxBufferBenchmarkRejectsPassWithoutPhysicalEvidence() throws {
    var report = try RxBufferBenchmarkRunner.runLocal(packetCount: 16)
    report.verdict = .pass

    #expect(throws: RxBufferBenchmarkValidationError.passWithoutPhysicalReferenceRig) {
        try report.validate()
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

private func readOpenLolaCoreSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
