import Foundation
import Testing

@testable import OpenLolaCore


@Test
func driftPlcReportsRejectInvalidFixedTargetPassAndCertificationEvidence() throws {
    try expectDriftPlcError(.plcWaitedForRetransmission(
        missingSequenceNumber: 3
    )) {
        $0.plcEvents[0].waitedForRetransmission = true
    }
    try expectDriftPlcError(.plcChangedPlayoutTarget(
        dueFrameIndex: 96,
        before: 32,
        after: 48
    )) {
        $0.plcEvents[0].playoutTargetFramesAfter = 48
    }
    try expectDriftPlcError(.invalidFixedPlayoutTarget(
        playoutTargetFrames: 64,
        framesPerPacket: 32
    )) {
        $0.metrics.playoutTargetFrames = 64
        $0.plcEvents[0].playoutTargetFramesBefore = 64
        $0.plcEvents[0].playoutTargetFramesAfter = 64
    }
    try expectDriftPlcError(.invalidFixedPlayoutTarget(
        playoutTargetFrames: 0,
        framesPerPacket: 32
    )) {
        $0.metrics.playoutTargetFrames = 0
        $0.plcEvents[0].playoutTargetFramesBefore = 0
        $0.plcEvents[0].playoutTargetFramesAfter = 0
    }
    try expectDriftPlcError(.correctionInsideUnboundedCallback(
        playoutFrameIndex: 96
    )) {
        $0.correctionEvents[0].location = .unboundedInsideCallback
    }
    try expectDriftPlcError(.hiddenPlayoutGrowthDetected) {
        $0.metrics.hiddenPlayoutGrowthDetected = true
    }
    try expectDriftPlcError(.nonMonotonicTelemetrySenderFrameIndex(
        previous: 32,
        current: 16
    )) {
        $0.telemetry[2].senderFrameIndex = 16
        $0.telemetry[2].receiverPlayoutFrameIndex = 16
        $0.telemetry[2].driftFrames = 0
    }
    try expectDriftPlcError(.passRunTooShort(
        seconds: 60,
        minimumSeconds: 3_600
    )) {
        $0.verdict = .pass
    }

    var routeReport = try loadRouteFixture(named: "direct-link-pass")
    routeReport.packetMode.framesPerPacket = 0

    #expect(fixedPlayoutTargetFrames(routeReport: routeReport) == 0)

    var certification = DriftPlcFixedTargetCertificationSyntheticSmoke.run()
    certification.runMode = .measured
    certification.verdict = .pass

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithoutRequiredReports([
        "routeCertificationReport",
        "driftPlcReport",
        "sourceRealtimeEngineReport",
        "lolaBaselineComparison",
    ])) {
        try certification.validate()
    }

    var passCandidate = try DriftPlcFixedTargetRunner.makeReport(
        routeReport: loadRouteFixture(named: "direct-link-pass"),
        configuration: DriftPlcRunConfiguration(
            routeReportPath: "route.json",
            durationSeconds: 3_600,
            policy: .silence,
            artifactAssessmentCompleted: true,
            artifactNotes: "No audible artifact in fixed-target silence baseline.",
            outputPath: "reports/m06.json"
        )
    )
    passCandidate.correctionEvents[0].location = .branchBoundedInsideDueBlock

    #expect(throws: DriftPlcValidationError.passCorrectionNotOutsideCallback(
        playoutFrameIndex: 57_600_000
    )) {
        try passCandidate.validate()
    }
}

@Test
func fixedTargetJitterBufferPlaysDueAndReorderedPacketsAtDueFrames() throws {
    var buffer = RealtimeAudioFixedTargetJitterBuffer(
        mode: driftPlcPacketMode(),
        playoutTargetFrames: 32,
        capacityBlocks: 2,
        plcPolicy: .silence
    )
    let packet = UdpPcmPacket.silence(
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1_000,
        mode: driftPlcPacketMode()
    )

    #expect(buffer.enqueue(packet, receivedAtHostTimeNanoseconds: 51_000) == .queued)
    #expect(buffer.renderNextBlock() == .silence(startFrame: 0, frameCount: 32))

    guard case let .played(block, telemetry) = buffer.renderNextBlock() else {
        Issue.record("expected the packet to play at its fixed one-block target")
        return
    }

    #expect(block.startFrame == 32)
    #expect(telemetry.sequenceNumber == 0)
    #expect(telemetry.senderFrameIndex == 0)
    #expect(telemetry.receiverPlayoutFrameIndex == 0)
    #expect(telemetry.driftFrames == 0)
    #expect(telemetry.packetAgeMicroseconds == 50)
    #expect(buffer.maximumBufferedBlocks == 1)
    #expect(!buffer.hiddenPlayoutGrowthDetected)

    var reorderedBuffer = RealtimeAudioFixedTargetJitterBuffer(
        mode: driftPlcPacketMode(),
        playoutTargetFrames: 32,
        capacityBlocks: 2,
        plcPolicy: .silence
    )
    let reorderedSecond = UdpPcmPacket.silence(
        sequenceNumber: 1,
        senderFrameIndex: 32,
        senderHostTimeNanoseconds: 2_000,
        mode: driftPlcPacketMode()
    )
    let reorderedFirst = UdpPcmPacket.silence(
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1_000,
        mode: driftPlcPacketMode()
    )

    #expect(reorderedBuffer.enqueue(reorderedSecond, receivedAtHostTimeNanoseconds: 12_000) == .queued)
    #expect(reorderedBuffer.enqueue(reorderedFirst, receivedAtHostTimeNanoseconds: 11_000) == .queued)
    #expect(reorderedBuffer.renderNextBlock() == .silence(startFrame: 0, frameCount: 32))

    guard case let .played(firstReorderedBlock, firstReorderedTelemetry) = reorderedBuffer.renderNextBlock() else {
        Issue.record("expected reordered first packet at its due frame")
        return
    }
    guard case let .played(secondReorderedBlock, secondReorderedTelemetry) = reorderedBuffer.renderNextBlock() else {
        Issue.record("expected reordered second packet at its due frame")
        return
    }

    #expect(firstReorderedBlock.startFrame == 32)
    #expect(firstReorderedTelemetry.sequenceNumber == 0)
    #expect(secondReorderedBlock.startFrame == 64)
    #expect(secondReorderedTelemetry.sequenceNumber == 1)
    #expect(reorderedBuffer.droppedLatePackets == 0)
}

@Test
func fixedTargetJitterBufferUsesSameDeadlinePlcOnlyWhenDueMediaIsMissing() throws {
    var buffer = RealtimeAudioFixedTargetJitterBuffer(
        mode: driftPlcPacketMode(),
        playoutTargetFrames: 32,
        capacityBlocks: 2,
        plcPolicy: .repeatLastGoodBlock
    )
    let firstPacket = UdpPcmPacket.silence(
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1_000,
        mode: driftPlcPacketMode()
    )

    #expect(buffer.enqueue(firstPacket, receivedAtHostTimeNanoseconds: 2_000) == .queued)
    #expect(buffer.renderNextBlock() == .silence(startFrame: 0, frameCount: 32))
    guard case .played = buffer.renderNextBlock() else {
        Issue.record("expected first packet to play before testing the missing packet")
        return
    }
    guard case let .sameDeadlinePlc(event, block) = buffer.renderNextBlock() else {
        Issue.record("expected same-deadline PLC for the missing second packet")
        return
    }

    #expect(event.dueFrameIndex == 64)
    #expect(event.missingSequenceNumber == 1)
    #expect(event.policy == .repeatLastGoodBlock)
    #expect(!event.waitedForRetransmission)
    #expect(event.playoutTargetFramesBefore == 32)
    #expect(event.playoutTargetFramesAfter == 32)
    #expect(event.branchBounded)
    #expect(block.startFrame == 64)
    #expect(block.frameCount == 32)
    #expect(block.payloadByteCount == driftPlcPacketMode().payloadByteCount)
    #expect(!buffer.hiddenPlayoutGrowthDetected)
}

@Test
func fixedTargetJitterBufferReportsAccountingUnderflowWithoutCrash() throws {
    var buffer = RealtimeAudioFixedTargetJitterBuffer(
        mode: driftPlcPacketMode(),
        playoutTargetFrames: 32,
        capacityBlocks: 2,
        plcPolicy: .silence
    )
    let stalePacket = UdpPcmPacket.silence(
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1_000,
        mode: driftPlcPacketMode()
    )

    #expect(buffer.enqueue(stalePacket, receivedAtHostTimeNanoseconds: 2_000) == .queued)
    buffer.setBufferedPacketCountForTesting(0)
    buffer.setNextDueFrameForTesting(64)

    guard case .sameDeadlinePlc = buffer.renderNextBlock() else {
        Issue.record("expected PLC after stale packet accounting mismatch")
        return
    }

    #expect(buffer.bufferedBlockCount == 0)
    #expect(buffer.droppedLatePackets == 1)
    #expect(buffer.packetAccountingUnderflows == 1)
    #expect(buffer.hiddenPlayoutGrowthDetected)
}

@Test
func fixedTargetJitterBufferCountsInvalidShapeAndOverflowAsInvalid() throws {
    var buffer = RealtimeAudioFixedTargetJitterBuffer(
        mode: driftPlcPacketMode(),
        playoutTargetFrames: 32,
        capacityBlocks: 1,
        plcPolicy: .silence
    )
    let invalidMode = UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 1,
        sampleFormat: .int16LittleEndian
    )
    let packet = UdpPcmPacket.silence(
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1_000,
        mode: invalidMode
    )

    #expect(buffer.enqueue(packet, receivedAtHostTimeNanoseconds: 2_000) == .droppedInvalid)
    #expect(buffer.droppedInvalidPackets == 1)
    #expect(buffer.droppedFullPackets == 0)

    var overflowBuffer = RealtimeAudioFixedTargetJitterBuffer(
        mode: driftPlcPacketMode(),
        playoutTargetFrames: 32,
        capacityBlocks: 1,
        plcPolicy: .silence
    )
    let overflowPacket = UdpPcmPacket.silence(
        sequenceNumber: 0,
        senderFrameIndex: UInt64.max - 31,
        senderHostTimeNanoseconds: 1_000,
        mode: driftPlcPacketMode()
    )

    #expect(overflowBuffer.enqueue(overflowPacket, receivedAtHostTimeNanoseconds: 2_000) == .droppedInvalid)
    #expect(overflowBuffer.droppedInvalidPackets == 1)
    #expect(overflowBuffer.bufferedBlockCount == 0)
}

private func loadDriftPlcFixture(named name: String) throws -> DriftPlcReport {
    let url = try driftPlcFixtureURL(named: name)
    return try DriftPlcReport.decode(from: Data(contentsOf: url))
}

private func expectDriftPlcError(
    _ expected: DriftPlcValidationError,
    mutate: (inout DriftPlcReport) throws -> Void
) throws {
    var report = try loadDriftPlcFixture(named: "drift-plc-partial")
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func loadRouteFixture(named name: String) throws -> UdpPcmRouteReport {
    let url = try routeFixtureURL(named: name)
    return try UdpPcmRouteReport.decode(from: Data(contentsOf: url))
}

private func driftPlcFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "DriftPlcReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "DriftPlcReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}

private func routeFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "UdpPcmRoutes/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "UdpPcmRoutes/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}

private func driftPlcPacketMode() -> UdpPcmPacketMode {
    UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
}

private func driftPlcArguments(replacing replacements: [String: String] = [:]) -> [String] {
    [
        "--route-report", replacements["--route-report"] ?? "reports/m05-direct.json",
        "--duration-seconds", replacements["--duration-seconds"] ?? "3600",
        "--policy", replacements["--policy"] ?? "silence",
        "--artifact-assessment-completed", replacements["--artifact-assessment-completed"] ?? "true",
        "--artifact-notes", replacements["--artifact-notes"] ?? "No audible artifacts during silence baseline.",
        "--output", replacements["--output"] ?? "reports/m06-drift.json",
    ]
}
