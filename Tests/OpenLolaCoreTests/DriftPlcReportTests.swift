import Foundation
import Testing

@testable import OpenLolaCore

@Test
func driftPlcReportFixtureDecodesAndValidates() throws {
    let report = try loadDriftPlcFixture(named: "drift-plc-partial")

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.metrics.playoutTargetFrames == 32)
    #expect(report.telemetry.count == 4)
    #expect(report.plcEvents.first?.policy == .silence)
    #expect(report.metrics.plcEvents == 1)
}

@Test
func driftPlcReportRejectsRetransmissionWait() throws {
    var report = try loadDriftPlcFixture(named: "drift-plc-partial")
    report.plcEvents[0].waitedForRetransmission = true

    #expect(throws: DriftPlcValidationError.plcWaitedForRetransmission(
        missingSequenceNumber: 3
    )) {
        try report.validate()
    }
}

@Test
func driftPlcReportRejectsPlayoutTargetGrowth() throws {
    var report = try loadDriftPlcFixture(named: "drift-plc-partial")
    report.plcEvents[0].playoutTargetFramesAfter = 48

    #expect(throws: DriftPlcValidationError.plcChangedPlayoutTarget(
        dueFrameIndex: 96,
        before: 32,
        after: 48
    )) {
        try report.validate()
    }
}

@Test
func driftPlcReportRejectsHiddenTargetDepthBeyondOneBlock() throws {
    var report = try loadDriftPlcFixture(named: "drift-plc-partial")
    report.metrics.playoutTargetFrames = 64
    report.plcEvents[0].playoutTargetFramesBefore = 64
    report.plcEvents[0].playoutTargetFramesAfter = 64

    #expect(throws: DriftPlcValidationError.invalidFixedPlayoutTarget(
        playoutTargetFrames: 64,
        framesPerPacket: 32
    )) {
        try report.validate()
    }
}

@Test
func driftPlcReportRejectsZeroPlayoutTargetFrames() throws {
    var report = try loadDriftPlcFixture(named: "drift-plc-partial")
    report.metrics.playoutTargetFrames = 0
    report.plcEvents[0].playoutTargetFramesBefore = 0
    report.plcEvents[0].playoutTargetFramesAfter = 0

    #expect(throws: DriftPlcValidationError.invalidFixedPlayoutTarget(
        playoutTargetFrames: 0,
        framesPerPacket: 32
    )) {
        try report.validate()
    }
}

@Test
func driftPlcFixedPlayoutTargetDoesNotClampInvalidPacketMode() throws {
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Timing/DriftPlcHelpers.swift")

    #expect(source.contains("func fixedPlayoutTargetFrames(routeReport: UdpPcmRouteReport) -> Int"))
    #expect(source.contains("routeReport.packetMode.framesPerPacket"))
    #expect(!source.contains("max(1, routeReport.packetMode.framesPerPacket)"))
}

@Test
func driftPlcFixedTargetCertificationReportsAllMissingRequiredPassReports() throws {
    var report = DriftPlcFixedTargetCertificationSyntheticSmoke.run()
    report.runMode = .measured
    report.verdict = .pass

    #expect(throws: DriftPlcFixedTargetCertificationValidationError.passWithoutRequiredReports([
        "routeCertificationReport",
        "driftPlcReport",
        "sourceRealtimeEngineReport",
        "lolaBaselineComparison",
    ])) {
        try report.validate()
    }
}

@Test
func driftPlcReportRejectsUnboundedCallbackCorrection() throws {
    var report = try loadDriftPlcFixture(named: "drift-plc-partial")
    report.correctionEvents[0].location = .unboundedInsideCallback

    #expect(throws: DriftPlcValidationError.correctionInsideUnboundedCallback(
        playoutFrameIndex: 96
    )) {
        try report.validate()
    }
}

@Test
func driftPlcReportRejectsPassCorrectionInsideCallback() throws {
    var report = try DriftPlcFixedTargetRunner.makeReport(
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
    report.correctionEvents[0].location = .branchBoundedInsideDueBlock

    #expect(throws: DriftPlcValidationError.passCorrectionNotOutsideCallback(
        playoutFrameIndex: 57_600_000
    )) {
        try report.validate()
    }
}

@Test
func driftPlcReportRejectsHiddenPlayoutGrowth() throws {
    var report = try loadDriftPlcFixture(named: "drift-plc-partial")
    report.metrics.hiddenPlayoutGrowthDetected = true

    #expect(throws: DriftPlcValidationError.hiddenPlayoutGrowthDetected) {
        try report.validate()
    }
}

@Test
func driftPlcReportRejectsNonMonotonicTelemetrySenderFrameIndex() throws {
    var report = try loadDriftPlcFixture(named: "drift-plc-partial")
    report.telemetry[2].senderFrameIndex = 16
    report.telemetry[2].receiverPlayoutFrameIndex = 16
    report.telemetry[2].driftFrames = 0

    #expect(throws: DriftPlcValidationError.nonMonotonicTelemetrySenderFrameIndex(
        previous: 32,
        current: 16
    )) {
        try report.validate()
    }
}

@Test
func driftPlcReportRejectsPassWithoutSixtyMinuteRun() throws {
    var report = try loadDriftPlcFixture(named: "drift-plc-partial")
    report.verdict = .pass

    #expect(throws: DriftPlcValidationError.passRunTooShort(
        seconds: 60,
        minimumSeconds: 3_600
    )) {
        try report.validate()
    }
}

@Test
func driftPlcRunConfigurationParsesRequiredArguments() throws {
    let configuration = try DriftPlcRunConfiguration.parse([
        "--route-report", "reports/m05-direct.json",
        "--duration-seconds", "3600",
        "--policy", "silence",
        "--artifact-assessment-completed", "true",
        "--artifact-notes", "No audible artifacts during silence baseline.",
        "--output", "reports/m06-drift.json"
    ])

    #expect(configuration.routeReportPath == "reports/m05-direct.json")
    #expect(configuration.durationSeconds == 3_600)
    #expect(configuration.policy == .silence)
    #expect(configuration.artifactAssessmentCompleted)
    #expect(configuration.artifactNotes == "No audible artifacts during silence baseline.")
    #expect(configuration.outputPath == "reports/m06-drift.json")
}

@Test
func driftPlcRunConfigurationRejectsUnknownPolicy() {
    #expect(throws: DriftPlcRunConfigurationError.invalidPolicy("unbounded")) {
        _ = try DriftPlcRunConfiguration.parse([
            "--route-report", "reports/m05-direct.json",
            "--duration-seconds", "3600",
            "--policy", "unbounded",
            "--artifact-assessment-completed", "true",
            "--artifact-notes", "No audible artifacts.",
            "--output", "reports/m06-drift.json"
        ])
    }
}

@Test
func driftPlcRunConfigurationUsesSharedKeyValueParser() throws {
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Timing/DriftPlcRun.swift")

    #expect(source.contains("KeyValueArgumentParser.parseValues"))
    #expect(!source.contains("while index < arguments.count"))
}

@Test
func driftPlcFixedTargetRunnerEmitsValidatedSixtyMinutePassReport() throws {
    let report = try DriftPlcFixedTargetRunner.makeReport(
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

    try report.validate()

    #expect(report.verdict == .pass)
    #expect(report.metrics.durationSeconds == 3_600)
    #expect(report.metrics.playoutTargetFrames == 32)
    #expect(report.metrics.hiddenPlayoutGrowthDetected == false)
    #expect(report.artifactAssessmentCompleted)
    #expect(report.plcEvents.allSatisfy { $0.policy == .silence })
    #expect(report.correctionEvents.allSatisfy { $0.location == .outsideCallback })
}

@Test
func driftPlcFixedTargetRunnerKeepsRepeatPolicySameDeadline() throws {
    let report = try DriftPlcFixedTargetRunner.makeReport(
        routeReport: loadRouteFixture(named: "direct-link-pass"),
        configuration: DriftPlcRunConfiguration(
            routeReportPath: "route.json",
            durationSeconds: 60,
            policy: .repeatLastGoodBlock,
            artifactAssessmentCompleted: false,
            artifactNotes: "Repeat substitute test only; silence baseline remains canonical.",
            outputPath: "reports/m06-repeat.json"
        )
    )

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.plcEvents.allSatisfy { event in
        event.policy == .repeatLastGoodBlock
            && event.playoutTargetFramesBefore == event.playoutTargetFramesAfter
            && event.branchBounded
            && !event.waitedForRetransmission
    })
}

@Test
func driftPlcReportJSONRoundTripPreservesReport() throws {
    let report = try loadDriftPlcFixture(named: "drift-plc-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try DriftPlcReport.decode(from: jsonData)

    #expect(decoded == report)
}

@Test
func driftPlcSyntheticSmokeEmitsPartialReport() throws {
    let report = try DriftPlcSyntheticSmoke.run()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.metrics.playoutTargetFrames == 32)
    #expect(report.metrics.hiddenPlayoutGrowthDetected == false)
    #expect(report.plcEvents.allSatisfy { !$0.waitedForRetransmission })
}

@Test
func fixedTargetJitterBufferPlaysDuePacketAndRecordsPacketAge() throws {
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
func fixedTargetJitterBufferDropsLatePacketsWithoutGrowingTarget() throws {
    var buffer = RealtimeAudioFixedTargetJitterBuffer(
        mode: driftPlcPacketMode(),
        playoutTargetFrames: 32,
        capacityBlocks: 1,
        plcPolicy: .silence
    )
    let latePacket = UdpPcmPacket.silence(
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1_000,
        mode: driftPlcPacketMode()
    )

    _ = buffer.renderNextBlock()
    _ = buffer.renderNextBlock()
    _ = buffer.renderNextBlock()

    #expect(buffer.enqueue(latePacket, receivedAtHostTimeNanoseconds: 2_000) == .droppedLate)
    #expect(buffer.droppedLatePackets == 1)
    #expect(buffer.maximumBufferedBlocks == 0)
    #expect(!buffer.hiddenPlayoutGrowthDetected)
}

@Test
func fixedTargetJitterBufferPlaysReorderedPacketsAtDueFrames() throws {
    var buffer = RealtimeAudioFixedTargetJitterBuffer(
        mode: driftPlcPacketMode(),
        playoutTargetFrames: 32,
        capacityBlocks: 2,
        plcPolicy: .silence
    )
    let secondPacket = UdpPcmPacket.silence(
        sequenceNumber: 1,
        senderFrameIndex: 32,
        senderHostTimeNanoseconds: 2_000,
        mode: driftPlcPacketMode()
    )
    let firstPacket = UdpPcmPacket.silence(
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1_000,
        mode: driftPlcPacketMode()
    )

    #expect(buffer.enqueue(secondPacket, receivedAtHostTimeNanoseconds: 12_000) == .queued)
    #expect(buffer.enqueue(firstPacket, receivedAtHostTimeNanoseconds: 11_000) == .queued)
    #expect(buffer.renderNextBlock() == .silence(startFrame: 0, frameCount: 32))

    guard case let .played(firstBlock, firstTelemetry) = buffer.renderNextBlock() else {
        Issue.record("expected reordered first packet at its due frame")
        return
    }
    guard case let .played(secondBlock, secondTelemetry) = buffer.renderNextBlock() else {
        Issue.record("expected reordered second packet at its due frame")
        return
    }

    #expect(firstBlock.startFrame == 32)
    #expect(firstTelemetry.sequenceNumber == 0)
    #expect(secondBlock.startFrame == 64)
    #expect(secondTelemetry.sequenceNumber == 1)
    #expect(buffer.droppedLatePackets == 0)
}

@Test
func fixedTargetJitterBufferSeparatesInvalidShapeFromFullPressure() throws {
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
}

@Test
func fixedTargetJitterBufferRejectsPlayoutFrameOverflowAsInvalid() throws {
    var buffer = RealtimeAudioFixedTargetJitterBuffer(
        mode: driftPlcPacketMode(),
        playoutTargetFrames: 32,
        capacityBlocks: 1,
        plcPolicy: .silence
    )
    let packet = UdpPcmPacket.silence(
        sequenceNumber: 0,
        senderFrameIndex: UInt64.max - 31,
        senderHostTimeNanoseconds: 1_000,
        mode: driftPlcPacketMode()
    )

    #expect(buffer.enqueue(packet, receivedAtHostTimeNanoseconds: 2_000) == .droppedInvalid)
    #expect(buffer.droppedInvalidPackets == 1)
    #expect(buffer.bufferedBlockCount == 0)
}

@Test
func fixedTargetJitterBufferSourceKeepsCallbackPathPreallocated() throws {
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift")

    #expect(source.contains("private var packetSlots: [RealtimeAudioJitterBufferPacket?]"))
    #expect(source.contains("if bufferedPackets > capacityBlocks {\n                hiddenPlayoutGrowthDetected = true\n            }"))
    #expect(!source.contains("packetsByPlayoutFrame"))
    #expect(!source.contains("reserveCapacity(capacityBlocks)"))
    #expect(!source.contains("hiddenPlayoutGrowthDetected = bufferedPackets > capacityBlocks"))
}

@Test
func driftPlcFixedTargetRunnerUsesNonzeroDirectRxTarget() throws {
    let source = try readOpenLolaCoreSource("Sources/OpenLolaCore/Timing/DriftPlcRun.swift")

    #expect(source.contains("targetPackets: 1"))
    #expect(!source.contains("playoutTargetFrames == 0 ? 0 : 1"))
}

@Test
func driftClockEstimatorComputesSlopeAndOutsideCallbackCorrection() throws {
    var estimator = DriftClockEstimator(
        sampleRateHertz: 48_000,
        correctionStepFrames: 8
    )
    _ = estimator.observe(
        sequenceNumber: 0,
        senderFrameIndex: 0,
        receiverPlayoutFrameIndex: 0,
        packetAgeMicroseconds: 100
    )
    let sample = estimator.observe(
        sequenceNumber: 90_000,
        senderFrameIndex: 2_880_000,
        receiverPlayoutFrameIndex: 2_879_976,
        packetAgeMicroseconds: 120
    )
    let estimate = estimator.estimate
    let correction = try #require(estimator.correctionEventIfNeeded(
        playoutFrameIndex: sample.receiverPlayoutFrameIndex
    ))

    #expect(sample.driftFrames == 24)
    #expect(estimate.sampleCount == 2)
    #expect(estimate.maxAbsoluteDriftFrames == 24)
    #expect(estimate.driftSlopeFramesPerMinute == 24)
    #expect(correction.location == .outsideCallback)
    #expect(correction.driftFramesBefore == 24)
    #expect(correction.driftFramesAfter == 16)
    #expect(correction.targetGrowthFrames == 0)
}

private func loadDriftPlcFixture(named name: String) throws -> DriftPlcReport {
    let url = try driftPlcFixtureURL(named: name)
    return try DriftPlcReport.decode(from: Data(contentsOf: url))
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

private func readOpenLolaCoreSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
