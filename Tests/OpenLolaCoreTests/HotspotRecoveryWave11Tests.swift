// Covers deterministic recovery paths in timing, LoLa memory media, and peer media budgets.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func wave11PeerSessionMediaBudgetUsesDefaultWhenConfigurationIsMissing() {
    #expect(peerSessionMediaReceiveByteBudget(acceptedConfiguration: nil) == 1_200)
}

@Test
func wave11LoLaMemoryTransmitterRetainsDatagramsAndReportsTheirSizes() throws {
    let transmitter = LoLaMemoryUdpMediaTransmitter()
    let datagrams = [
        LoLaUdpMediaDatagram(stream: .audio, port: 19_788, payload: Data([1, 2])),
        LoLaUdpMediaDatagram(stream: .video, port: 19_798, payload: Data([3]))
    ]

    let outcome = try transmitter.transmitResult(
        datagrams,
        localHost: "192.0.2.10",
        peer: "192.0.2.20"
    )

    #expect(!transmitter.usesRealLink)
    #expect(transmitter.transmittedDatagrams == datagrams)
    #expect(outcome.sentByteCounts == [2, 1])
    #expect(outcome.droppedAudioPackets == 0)
    #expect(outcome.deadlineAbandonedVideoFrames == 0)
}

@Test
func wave11LoLaMemoryReceiverFiltersPeerPortAndBoundedPrefix() throws {
    let receiver = LoLaMemoryUdpMediaReceiver(datagrams: [
        .init(stream: .audio, port: 19_788, sourceHost: "192.0.2.20", payload: Data([1])),
        .init(stream: .video, port: 19_798, sourceHost: "192.0.2.20", payload: Data([2])),
        .init(stream: .audio, port: 19_788, sourceHost: "198.51.100.7", payload: Data([3])),
        .init(stream: .audio, port: 19_799, sourceHost: "192.0.2.20", payload: Data([4]))
    ])

    let received = try receiver.receive(
        maxDatagrams: 1,
        localHost: "192.0.2.10",
        peer: "192.0.2.20",
        audioPort: 19_788,
        videoPort: 19_798
    )

    #expect(received.map(\.payload) == [Data([1])])
}

@Test
func wave11MediaClockHandlesInvalidRatesAndAnEmptySeries() throws {
    #expect(MediaClock.nanoseconds(forFrameCount: 96, sampleRateHertz: 0) == 0)
    #expect(MediaClock.nanoseconds(forFrameCount: 96, sampleRateHertz: -48_000) == 0)
    try MediaClock.validateMonotonicHostTimes([])
}

@Test
func wave11MediaClockAnchorPreservesHostTimeForInvalidOrEarlierFrames() {
    let invalidRate = MediaClockAnchor(
        senderFrameIndex: 10,
        hostTimeNanoseconds: 100,
        sampleRateHertz: 0
    )
    let valid = MediaClockAnchor(
        senderFrameIndex: 10,
        hostTimeNanoseconds: 100,
        sampleRateHertz: 48_000
    )

    #expect(invalidRate.hostTimeNanoseconds(forFrameIndex: 12) == 100)
    #expect(valid.hostTimeNanoseconds(forFrameIndex: 9) == 100)
    #expect(valid.ageMicroseconds(observedAtNanoseconds: 50) == -0.05)
}

@Test
func wave11MediaClockAnchorRejectsBothValidationFields() {
    let invalidRate = MediaClockAnchor(senderFrameIndex: 0, hostTimeNanoseconds: 1, sampleRateHertz: 0)
    let invalidTimestamp = MediaClockAnchor(senderFrameIndex: 0, hostTimeNanoseconds: 0, sampleRateHertz: 48_000)

    #expect(throws: MediaClockValidationError.invalidSampleRate(0)) {
        try invalidRate.validate()
    }
    #expect(throws: MediaClockValidationError.invalidTimestamp(0)) {
        try invalidTimestamp.validate()
    }
}

@Test
func wave11MediaClockRejectsDuplicateTimestamps() {
    #expect(throws: MediaClockValidationError.nonMonotonicTimestamp(previous: 20, next: 20)) {
        try MediaClock.validateMonotonicHostTimes([10, 20, 20])
    }
}

@Test
func wave11MediaClockDriftEstimatePreservesRequestedCorrectionBoundary() throws {
    let packets = [
        wave11TimingPacket(sequence: 0, remote: 1_000, local: 2_000),
        wave11TimingPacket(sequence: 1, remote: 2_000, local: 3_500)
    ]

    let estimate = try MediaClockDriftEstimator.estimate(
        from: packets,
        correctionBoundary: .branchBoundedInsideDueBlock
    )

    #expect(estimate.sampleCount == 2)
    #expect(estimate.remoteDurationNanoseconds == 1_000)
    #expect(estimate.localDurationNanoseconds == 1_500)
    #expect(estimate.offsetMicroseconds == 1.5)
    #expect(estimate.driftSlopePartsPerMillion == 500_000)
    #expect(estimate.correctionBoundary == .branchBoundedInsideDueBlock)
}

@Test
func wave11DriftPlcReportRejectsUnorderedCallbackMetrics() {
    var report = wave11DriftPlcReport()
    report.metrics.callbackP99Microseconds = 2
    report.metrics.callbackMaxMicroseconds = 1

    #expect(throws: DriftPlcValidationError.unorderedCallbackMetrics) {
        try report.validate()
    }
}

@Test
func wave11DriftPlcReportRejectsHiddenRxBufferGrowth() throws {
    var report = wave11DriftPlcReport()
    let policy = try RxBufferPolicy.direct(framesPerPacket: 32, sampleRateHertz: 48_000)
    report.metrics.rxBuffer = RxBufferRuntimeSnapshot(
        policy: policy,
        targetObservation: .init(hiddenGrowthDetected: true)
    )

    #expect(throws: DriftPlcValidationError.hiddenPlayoutGrowthDetected) {
        try report.validate()
    }
}

@Test
func wave11DriftPlcReportRejectsPlcEventCountMismatch() {
    var report = wave11DriftPlcReport()
    report.metrics.plcEvents = 1

    #expect(throws: DriftPlcValidationError.eventCountMismatch(
        field: "metrics.plcEvents", expected: 0, actual: 1
    )) {
        try report.validate()
    }
}

@Test
func wave11DriftPlcReportRejectsCorrectionEventCountMismatch() {
    var report = wave11DriftPlcReport()
    report.metrics.correctionEvents = 1

    #expect(throws: DriftPlcValidationError.eventCountMismatch(
        field: "metrics.correctionEvents", expected: 0, actual: 1
    )) {
        try report.validate()
    }
}

@Test
func wave11DriftPlcReportRejectsMissingTelemetry() {
    var report = wave11DriftPlcReport()
    report.telemetry = []
    report.metrics.maxAbsoluteDriftFrames = 0

    #expect(throws: DriftPlcValidationError.missingTelemetry) {
        try report.validate()
    }
}

@Test
func wave11DriftPlcReportRejectsTelemetryDriftMismatch() {
    var report = wave11DriftPlcReport()
    report.telemetry[0].driftFrames = 31

    #expect(throws: DriftPlcValidationError.telemetryDriftMismatch(
        sequenceNumber: 7, expected: 32, actual: 31
    )) {
        try report.validate()
    }
}

@Test
func wave11DriftPlcReportRejectsMaximumDriftMismatch() {
    var report = wave11DriftPlcReport()
    report.metrics.maxAbsoluteDriftFrames = 31

    #expect(throws: DriftPlcValidationError.maxDriftMismatch(expected: 32, actual: 31)) {
        try report.validate()
    }
}

@Test
func wave11DriftPlcReportRejectsPlcTargetMismatch() {
    var report = wave11DriftPlcReport()
    report.plcEvents = [wave11PlcEvent(playoutTargetFrames: 16)]
    report.metrics.plcEvents = 1

    #expect(throws: DriftPlcValidationError.plcTargetMismatch(dueFrameIndex: 64, target: 32)) {
        try report.validate()
    }
}

@Test
func wave11DriftPlcReportRejectsUnboundedPlcEvent() {
    var report = wave11DriftPlcReport()
    var event = wave11PlcEvent()
    event.branchBounded = false
    report.plcEvents = [event]
    report.metrics.plcEvents = 1

    #expect(throws: DriftPlcValidationError.plcNotBranchBounded(missingSequenceNumber: 8)) {
        try report.validate()
    }
}

@Test
func wave11DriftPlcReportRejectsTargetGrowthInCorrectionEvent() {
    var report = wave11DriftPlcReport()
    report.correctionEvents = [DriftCorrectionEvent(
        playoutFrameIndex: 64,
        driftFramesBefore: 32,
        driftFramesAfter: 0,
        location: .outsideCallback,
        targetGrowthFrames: 1,
        notes: "bounded correction"
    )]
    report.metrics.correctionEvents = 1

    #expect(throws: DriftPlcValidationError.correctionGrewTarget(
        playoutFrameIndex: 64, targetGrowthFrames: 1
    )) {
        try report.validate()
    }
}

@Test
func wave11DriftPlcPassRejectsUnderruns() {
    var report = wave11DriftPlcReport(verdict: .pass)
    report.metrics.underruns = 1

    #expect(throws: DriftPlcValidationError.passWithUnderruns(1)) {
        try report.validate()
    }
}

@Test
func wave11DriftPlcPassRequiresArtifactAssessment() {
    var report = wave11DriftPlcReport(verdict: .pass)
    report.artifactAssessmentCompleted = false

    #expect(throws: DriftPlcValidationError.passWithoutArtifactAssessment) {
        try report.validate()
    }
}

@Test
func wave11DriftPlcPassRequiresOutsideCallbackCorrection() {
    var report = wave11DriftPlcReport(verdict: .pass)
    report.correctionEvents = [DriftCorrectionEvent(
        playoutFrameIndex: 64,
        driftFramesBefore: 32,
        driftFramesAfter: 0,
        location: .branchBoundedInsideDueBlock,
        targetGrowthFrames: 0,
        notes: "bounded correction"
    )]
    report.metrics.correctionEvents = 1

    #expect(throws: DriftPlcValidationError.passCorrectionNotOutsideCallback(playoutFrameIndex: 64)) {
        try report.validate()
    }
}

private func wave11TimingPacket(sequence: UInt64, remote: UInt64, local: UInt64) -> MediaTimingPacket {
    MediaTimingPacket(
        streamID: 1,
        sequenceNumber: sequence,
        observedPayloadType: .audioPcmV2,
        senderFrameIndex: sequence * 32,
        remoteSenderTimeNanoseconds: remote,
        localObservationTimeNanoseconds: local,
        timestampOrigin: .audioPacketSenderHostTimeNanoseconds
    )
}

private func wave11DriftPlcReport(verdict: MeasurementVerdict = .partial) -> DriftPlcReport {
    let metrics = DriftPlcMetrics(
        callbackTiming: .init(
            durationSeconds: 3_600,
            playoutTargetFrames: 32,
            callbackP99Microseconds: 1,
            callbackMaxMicroseconds: 1
        ),
        recovery: .init(
            underruns: 0,
            correctionEvents: 0,
            plcEvents: 0,
            maxAbsoluteDriftFrames: 32,
            driftSlopeFramesPerMinute: 0,
            hiddenPlayoutGrowthDetected: false
        )
    )
    return DriftPlcReport(
        identity: .init(
            id: "wave11-drift",
            title: "Wave 11 deterministic drift report",
            capturedAt: "2026-08-05T00:00:00Z",
            route: RouteIdentity(label: "loopback", topology: "in-memory"),
            packetMode: UdpPcmPacketMode(
                sampleRateHertz: 48_000,
                framesPerPacket: 32,
                channelCount: 1,
                sampleFormat: .int16LittleEndian
            )
        ),
        measurements: .init(
            telemetry: [DriftTelemetrySample(
                sequenceNumber: 7,
                senderFrameIndex: 32,
                receiverPlayoutFrameIndex: 0,
                driftFrames: 32,
                packetAgeMicroseconds: 1
            )],
            plcEvents: [],
            correctionEvents: [],
            metrics: metrics
        ),
        assessment: .init(
            artifactAssessmentCompleted: true,
            artifactNotes: "Deterministic validation artifact.",
            verdict: verdict,
            notes: "No hardware or socket activity."
        )
    )
}

private func wave11PlcEvent(playoutTargetFrames: Int = 32) -> SameDeadlinePlcEvent {
    SameDeadlinePlcEvent(
        dueFrameIndex: 64,
        missingSequenceNumber: 8,
        policy: .silence,
        waitedForRetransmission: false,
        playoutTargetFramesBefore: playoutTargetFrames,
        playoutTargetFramesAfter: playoutTargetFrames,
        branchBounded: true,
        notes: "same deadline"
    )
}
