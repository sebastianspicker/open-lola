// Verifies decoded connector audio reaches the realtime playout boundary with bounded, truthful accounting.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func decodedAudioPlayoutSinkConvertsInt16AndQueuesOneExactBlock() throws {
    let target = DecodedAudioPlayoutTestTarget(nextOutputFrame: 1_000)
    let sink = DecodedAudioPlayoutSink(
        target: target,
        outputRate: 48_000,
        channels: 2,
        framesPerBlock: 2
    )
    sink.start()

    let outcome = try sink.enqueue(.init(
        payload: int16LittleEndianData(fromInterleavedFloat: [-1, -0.5, 0.5, 1]),
        sampleRateHertz: 48_000,
        channels: 2,
        representation: .int16LittleEndian
    ), hostTimeNanoseconds: 77)
    #expect(outcome == .init(queuedBlocks: 1, droppedBlocks: 0))

    let queued = try #require(target.queued.first)
    let samples = queued.payload.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    #expect(samples.count == 4)
    #expect(samples[0] < -0.99)
    #expect(samples[1] < -0.49 && samples[1] > -0.51)
    #expect(samples[2] > 0.49 && samples[2] < 0.51)
    #expect(samples[3] > 0.99)
    #expect(queued.startFrame == 1_002)
    #expect(queued.hostTimeNanoseconds == 77)
    #expect(sink.snapshot == .init(
        receivedBlocks: 1,
        queuedBlocks: 1,
        droppedBlocks: 0,
        underrunBlocks: 0
    ))
}

@Test
func decodedAudioPlayoutSinkRejectsMalformedShapeAndAccountsBackpressure() throws {
    let target = DecodedAudioPlayoutTestTarget(nextOutputFrame: 0, result: .full)
    let sink = DecodedAudioPlayoutSink(
        target: target,
        outputRate: 48_000,
        channels: 2,
        framesPerBlock: 1
    )
    sink.start()

    #expect(throws: DecodedAudioPlayoutSinkError.malformedPayload) {
        try sink.enqueue(.init(
            payload: Data([0]),
            sampleRateHertz: 48_000,
            channels: 2,
            representation: .int16LittleEndian
        ), hostTimeNanoseconds: 0)
    }
    let outcome = try sink.enqueue(.init(
        payload: int16LittleEndianData(fromInterleavedFloat: [0, 0]),
        sampleRateHertz: 48_000,
        channels: 2,
        representation: .int16LittleEndian
    ), hostTimeNanoseconds: 1)
    #expect(outcome == .init(queuedBlocks: 0, droppedBlocks: 1))
    #expect(outcome.wasEntirelyDropped)
    #expect(sink.snapshot.droppedBlocks == 1)

    sink.stop()
    try sink.enqueue(.init(
        payload: int16LittleEndianData(fromInterleavedFloat: [0, 0]),
        sampleRateHertz: 48_000,
        channels: 2,
        representation: .int16LittleEndian
    ), hostTimeNanoseconds: 2)
    #expect(sink.snapshot.receivedBlocks == 1)
}

private final class DecodedAudioPlayoutTestTarget: DecodedAudioPlayoutTarget, @unchecked Sendable {
    struct Queued {
        let payload: Data
        let startFrame: UInt64
        let hostTimeNanoseconds: UInt64
    }

    var nextOutputFrameForPlayout: UInt64
    var outputUnderrunBlocksForPlayout = 0
    var queued: [Queued] = []
    var result: SPSCAtomicRingResult

    init(nextOutputFrame: UInt64, result: SPSCAtomicRingResult = .stored) {
        nextOutputFrameForPlayout = nextOutputFrame
        self.result = result
    }

    func queuePlayoutForDecodedAudio(
        _ payload: Data,
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64
    ) -> SPSCAtomicRingResult {
        queued.append(.init(
            payload: payload,
            startFrame: startFrame,
            hostTimeNanoseconds: hostTimeNanoseconds
        ))
        return result
    }
}
