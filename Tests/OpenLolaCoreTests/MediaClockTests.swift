import Foundation
import Testing

@testable import OpenLolaCore


@Test
func mediaClockAnchorConvertsFrameIndexesToHostTime() throws {
    let anchor = MediaClockAnchor(
        senderFrameIndex: 1_000,
        hostTimeNanoseconds: 1_000_000_000,
        sampleRateHertz: 48_000
    )

    try anchor.validate()

    #expect(anchor.hostTimeNanoseconds(forFrameIndex: 1_480) == 1_010_000_000)
    #expect(anchor.ageMicroseconds(observedAtNanoseconds: 1_012_345_000) == 12_345)
}

@Test
func mediaClockNanosecondsUsesFullWidthMathAndHalfUpRounding() {
    #expect(
        MediaClock.nanoseconds(
            forFrameCount: UInt64.max,
            sampleRateHertz: 1_000_000_000
        ) == UInt64.max
    )
    #expect(MediaClock.nanoseconds(forFrameCount: 1, sampleRateHertz: 2_000_000_000) == 1)
    #expect(MediaClock.nanoseconds(forFrameCount: 1, sampleRateHertz: 4_000_000_000) == 0)
}

@Test
func mediaClockNanosecondsClampsOverflowInsteadOfTrapping() {
    #expect(MediaClock.nanoseconds(forFrameCount: UInt64.max, sampleRateHertz: 1) == UInt64.max)
}

@Test
func mediaClockRejectsBackwardsHostTimes() {
    #expect(throws: MediaClockValidationError.nonMonotonicTimestamp(
        previous: 2_000,
        next: 1_999
    )) {
        try MediaClock.validateMonotonicHostTimes([1_000, 2_000, 1_999])
    }
}

@Test
func mediaClockDriftEstimatorRejectsMidSequenceRemoteTimestampRegression() {
    let packets = [
        mediaTimingSample(sequence: 0, remote: 1_000, local: 2_000),
        mediaTimingSample(sequence: 1, remote: 900, local: 3_000),
        mediaTimingSample(sequence: 2, remote: 2_000, local: 4_000),
    ]

    #expect(throws: MediaClockValidationError.nonMonotonicTimestamp(
        previous: 1_000,
        next: 900
    )) {
        _ = try MediaClockDriftEstimator.estimate(from: packets)
    }
}

private func mediaTimingSample(sequence: UInt64, remote: UInt64, local: UInt64) -> MediaTimingPacket {
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
