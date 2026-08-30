// Verifies deterministic codec policy and playout lifecycle behavior without media hardware.
import Foundation
@testable import OpenLolaMediaPlatform
import OpenLolaSessionDomain
import Testing

@Test func lowDelayOpusPolicyAcceptsOnlyItsFixedWireShape() throws {
    try OpusCELTLowDelayCodecValidation.validate(
        sampleRateHertz: OpusCELTLowDelayConstants.sampleRateHertz,
        frameCount: OpusCELTLowDelayConstants.frameCount,
        sampleFormat: .float32LittleEndian,
        channelCount: 2
    )
    #expect(throws: OpusCELTLowDelayCodecError.self) {
        try OpusCELTLowDelayCodecValidation.validate(
            sampleRateHertz: 44_100,
            frameCount: OpusCELTLowDelayConstants.frameCount,
            sampleFormat: .float32LittleEndian,
            channelCount: 2
        )
    }
}

@Test func decodedAudioPlayoutLifecycleEncodesForInjectedTargetAndReportsDrops() throws {
    let target = RecordingDecodedAudioTarget(results: [.stored, .full])
    let sink = DecodedAudioPlayoutSink(
        target: target,
        outputRate: 48_000,
        channels: 2,
        framesPerBlock: 2
    )
    let block = DecodedInterleavedPCM(
        payload: floatData([0.25, -0.25, 0.5, -0.5]),
        sampleRateHertz: 48_000,
        channels: 2,
        representation: .float32LittleEndian
    )

    sink.start()
    let queued = try sink.enqueue(block, hostTimeNanoseconds: 123)
    #expect(queued == .init(queuedBlocks: 1, droppedBlocks: 0))
    #expect(target.writes.count == 1)
    #expect(target.writes[0].startFrame == 66)
    #expect(target.writes[0].payload == block.payload)

    let dropped = try sink.enqueue(block, hostTimeNanoseconds: 124)
    #expect(dropped == .init(queuedBlocks: 0, droppedBlocks: 1))
    #expect(sink.snapshot == .init(receivedBlocks: 2, queuedBlocks: 1, droppedBlocks: 1, underrunBlocks: 4))

    sink.stop()
    #expect(try sink.enqueue(block, hostTimeNanoseconds: 125) == .init())
    #expect(target.writes.count == 2)
}

private final class RecordingDecodedAudioTarget: DecodedAudioPlayoutTarget {
    struct Write: Equatable {
        var payload: Data
        var startFrame: UInt64
        var hostTimeNanoseconds: UInt64
    }

    var nextOutputFrameForPlayout: UInt64 = 64
    var outputUnderrunBlocksForPlayout: Int = 4
    var writes: [Write] = []
    private var results: [SPSCAtomicRingResult]

    init(results: [SPSCAtomicRingResult]) {
        self.results = results
    }

    func queuePlayoutForDecodedAudio(
        _ payload: Data,
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64
    ) -> SPSCAtomicRingResult {
        writes.append(.init(payload: payload, startFrame: startFrame, hostTimeNanoseconds: hostTimeNanoseconds))
        return results.removeFirst()
    }
}

private func floatData(_ values: [Float]) -> Data {
    var values = values
    return values.withUnsafeMutableBytes { Data($0) }
}
