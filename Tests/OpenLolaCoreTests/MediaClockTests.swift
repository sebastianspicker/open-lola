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
func mediaClockAnchorUsesIntegerFrameConversionForLargeIndexes() throws {
    let anchor = MediaClockAnchor(
        senderFrameIndex: 0,
        hostTimeNanoseconds: 1,
        sampleRateHertz: 48_000
    )

    try anchor.validate()

    #expect(anchor.hostTimeNanoseconds(forFrameIndex: 9_876_543_210) == 205_761_316_875_001)
}

@Test
func mediaClockConvertsFrameCountsWithFullWidthMath() {
    #expect(MediaClock.nanoseconds(forFrameCount: 480, sampleRateHertz: 48_000) == 10_000_000)
    #expect(MediaClock.nanoseconds(forFrameCount: 1, sampleRateHertz: 48_000) == 20_833)
    #expect(MediaClock.nanoseconds(forFrameCount: 480, sampleRateHertz: 0) == 0)
}

@Test
func mediaClockNanosecondsFailsFastInsteadOfClampingOverflow() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Timing/MediaClock.swift")

    #expect(source.contains("preconditionFailure(\"MediaClock.nanoseconds overflow\")"))
    #expect(!source.contains("return UInt64.max"))
    #expect(source.contains("divisor.dividingFullWidth(product)"))
    #expect(source.contains("let roundingThreshold = (divisor + 1) / 2"))
    #expect(!source.contains("(divisor / 2) + (divisor % 2)"))
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
func mediaClockRejectsDuplicateHostTimes() {
    #expect(throws: MediaClockValidationError.nonMonotonicTimestamp(
        previous: 2_000,
        next: 2_000
    )) {
        try MediaClock.validateMonotonicHostTimes([1_000, 2_000, 2_000])
    }
}

@Test
func mediaTimingPacketRoundTripPreservesTimingFields() throws {
    let packet = MediaTimingPacket(
        streamID: 7,
        sequenceNumber: 42,
        observedPayloadType: .audioPcmV2,
        senderFrameIndex: 480,
        remoteSenderTimeNanoseconds: 1_010_000_000,
        localObservationTimeNanoseconds: 1_010_120_000,
        timestampOrigin: .audioPacketSenderHostTimeNanoseconds
    )

    try packet.validate()

    let encoded = try JSONEncoder().encode(packet)
    let decoded = try JSONDecoder().decode(MediaTimingPacket.self, from: encoded)

    #expect(decoded == packet)
    #expect(decoded.observedAgeMicroseconds == 120)
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

@Test
func mediaTimingPacketCanBeDerivedFromAudioAndVideoPackets() throws {
    let audioMode = UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
    let audioPacket = UdpPcmPacket.silence(
        sequenceNumber: 9,
        senderFrameIndex: 320,
        senderHostTimeNanoseconds: 2_000_000,
        mode: audioMode
    )
    let audioTiming = try MediaTimingPacket(
        audioPacket: audioPacket,
        streamID: 3,
        localObservationTimeNanoseconds: 2_250_000
    )

    let videoPacket = VideoTransportPacket(
        streamID: 4,
        sequenceNumber: 10,
        timestampNanoseconds: 3_000_000,
        timestampBasis: .syntheticMonotonicNanoseconds,
        sourceRole: .testPattern,
        width: 64,
        height: 48,
        pixelFormat: "rgb24",
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        payloadByteCount: 9_216,
        frameFingerprint: "frame-10"
    )
    let videoTiming = try MediaTimingPacket(
        videoPacket: videoPacket,
        localObservationTimeNanoseconds: 3_500_000
    )

    #expect(audioTiming.streamID == 3)
    #expect(audioTiming.sequenceNumber == 9)
    #expect(audioTiming.senderFrameIndex == 320)
    #expect(audioTiming.observedPayloadType == .audioPcmV2)
    #expect(audioTiming.observedAgeMicroseconds == 250)

    #expect(videoTiming.streamID == 4)
    #expect(videoTiming.sequenceNumber == 10)
    #expect(videoTiming.senderFrameIndex == nil)
    #expect(videoTiming.timestampOrigin == .videoPacketTimestampNanoseconds)
    #expect(videoTiming.observedAgeMicroseconds == 500)
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

private func readRepositoryText(_ relativePath: String) throws -> String {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}
