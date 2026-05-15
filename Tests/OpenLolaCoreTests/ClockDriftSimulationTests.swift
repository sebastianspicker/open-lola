import Testing

@testable import OpenLolaCore

@Test
func clockDriftEstimatorReportsOffsetAndSlopeFromTimingPackets() throws {
    let packets = [
        MediaTimingPacket(
            streamID: 1,
            sequenceNumber: 1,
            observedPayloadType: .audioPcmV2,
            senderFrameIndex: 0,
            remoteSenderTimeNanoseconds: 1_000_000_000,
            localObservationTimeNanoseconds: 1_000_100_000,
            timestampOrigin: .audioPacketSenderHostTimeNanoseconds
        ),
        MediaTimingPacket(
            streamID: 1,
            sequenceNumber: 2,
            observedPayloadType: .audioPcmV2,
            senderFrameIndex: 48_000,
            remoteSenderTimeNanoseconds: 2_000_000_000,
            localObservationTimeNanoseconds: 2_000_600_000,
            timestampOrigin: .audioPacketSenderHostTimeNanoseconds
        ),
    ]

    let estimate = try MediaClockDriftEstimator.estimate(from: packets)

    #expect(estimate.sampleCount == 2)
    #expect(estimate.remoteDurationNanoseconds == 1_000_000_000)
    #expect(estimate.localDurationNanoseconds == 1_000_500_000)
    #expect(estimate.offsetMicroseconds == 600)
    #expect(abs(estimate.driftSlopePartsPerMillion - 500) < 0.0001)
    #expect(estimate.correctionBoundary == .outsideCallback)
}

@Test
func clockDriftEstimatorRejectsBackwardsObservations() {
    let packets = [
        MediaTimingPacket(
            streamID: 1,
            sequenceNumber: 1,
            observedPayloadType: .audioPcmV2,
            senderFrameIndex: 0,
            remoteSenderTimeNanoseconds: 2_000,
            localObservationTimeNanoseconds: 4_000,
            timestampOrigin: .audioPacketSenderHostTimeNanoseconds
        ),
        MediaTimingPacket(
            streamID: 1,
            sequenceNumber: 2,
            observedPayloadType: .audioPcmV2,
            senderFrameIndex: 32,
            remoteSenderTimeNanoseconds: 3_000,
            localObservationTimeNanoseconds: 3_999,
            timestampOrigin: .audioPacketSenderHostTimeNanoseconds
        ),
    ]

    #expect(throws: MediaClockValidationError.nonMonotonicTimestamp(
        previous: 4_000,
        next: 3_999
    )) {
        _ = try MediaClockDriftEstimator.estimate(from: packets)
    }
}
