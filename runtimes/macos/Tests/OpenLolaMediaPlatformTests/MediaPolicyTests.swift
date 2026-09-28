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

@Test func decodedAudioPlayoutRejectsMalformedBlocksBeforeItsLifecycleStateChanges() throws {
    let target = RecordingDecodedAudioTarget(results: [.stored])
    let sink = DecodedAudioPlayoutSink(
        target: target,
        outputRate: 48_000,
        channels: 2,
        framesPerBlock: 2
    )
    let malformed = DecodedInterleavedPCM(
        payload: Data([0, 1, 2]),
        sampleRateHertz: 48_000,
        channels: 2,
        representation: .float32LittleEndian
    )

    sink.start()
    #expect(throws: DecodedAudioPlayoutSinkError.malformedPayload) {
        try sink.enqueue(malformed, hostTimeNanoseconds: 123)
    }
    #expect(sink.snapshot == .init(receivedBlocks: 0, queuedBlocks: 0, droppedBlocks: 0, underrunBlocks: 4))
    #expect(target.writes.isEmpty)
}

@Test func linearPCMResamplerAppendAndProduceMatchesSeparateAppendAndProduce() {
    let input: [Float] = [0, 0, 1, -1, 0.5, 0.25]
    let combined = LoLaLinearPCMResampler(inputRate: 48_000, outputRate: 24_000, channels: 2)
    let separate = LoLaLinearPCMResampler(inputRate: 48_000, outputRate: 24_000, channels: 2)

    let combinedOutput = combined.appendAndProduce(input)
    separate.append(input)
    let separateOutput = separate.produce()

    #expect(combinedOutput == separateOutput)
    // The terminal frame is retained for interpolation when the next block arrives.
    #expect(combinedOutput == [0, 0])
    separate.reset()
    #expect(separate.produce().isEmpty)
}

@Test func madiReceiverUsesPreparedMixPlanForPanMuteAndRevision() throws {
    let mode = try madiSyntheticUdpPcmV2AudioTransportMode(
        channelCount: 2,
        framesPerPacket: 2,
        sampleRateHertz: 48_000,
        sampleFormat: .float32LittleEndian,
        maxTransmissionUnitBytes: 1_200
    )
    let receiverMix = ReceiverMixSnapshot(
        routes: [
            .init(
                sourceChannelIndex: 0,
                destinationChannelIndex: 0,
                gainDb: 0,
                muted: false,
                pan: 1
            ),
            .init(
                sourceChannelIndex: 1,
                destinationChannelIndex: 1,
                gainDb: 0,
                muted: true,
                pan: 0
            )
        ],
        requiresDestructiveDownmix: false
    )
    var receiver = try MadiReceiveEngine(configuration: .init(
        mode: mode,
        receiverMix: receiverMix,
        outputChannelCount: 2
    ))
    let packets = try UdpPcmV2Packetizer.packetize(
        floatData([0.5, 0.75, -0.5, -0.75]),
        sequenceNumber: 0,
        senderFrameIndex: 0,
        senderHostTimeNanoseconds: 1,
        mode: mode
    )

    for packet in packets {
        _ = try receiver.receive(packet, receivedAtHostTimeNanoseconds: 2)
    }
    _ = receiver.renderCallback()
    let rendered = receiver.renderCallback()

    guard case .played(let block) = rendered else {
        Issue.record("expected prepared mix playout")
        return
    }
    #expect(block.payload == floatData([0, 0.5, 0, -0.5]))
    #expect(block.mixRevision == 1)
    #expect(receiver.metrics.allocationWarnings == 0)
}

@Test @MainActor func previewCloseClearsPendingFrameAndPreventsPresentation() async throws {
    let preview = RawBGRAAppKitPreviewWindow()
    let frame = RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 1,
            sequenceNumber: 1,
            timestampNanoseconds: 1,
            timestampBasis: .syntheticMonotonicNanoseconds,
            sourceRole: .testPattern,
            width: 1,
            height: 1,
            pixelFormat: "bgra8",
            frameRate: .init(numerator: 30, denominator: 1),
            fingerprint: "preview-close"
        ),
        payload: Data([0, 0, 0, 255])
    )

    try preview.submit(frame: frame)
    preview.close()
    try await Task.sleep(for: .milliseconds(10))

    #expect(preview.renderedFrameCount == 0)
    #expect(preview.droppedFrameCount == 1)
    #expect(preview.hasPreviewWindowForTesting == false)
    #expect(throws: RawBGRAPreviewError.closed) {
        try preview.submit(frame: frame)
    }
    #expect(preview.droppedFrameCount == 2)
}

#if DEBUG
@Test @MainActor func previewSupersedesPreparedImageOnceBeforeMainActorDelivery() throws {
    let preview = RawBGRAAppKitPreviewWindow()
    let image = try RawBGRAImageFactory.makeCGImage(frame: previewTestFrame(sequenceNumber: 1, blue: 1))

    for _ in 0..<8 {
        preview.submitPreparedImageForTesting(image: image, width: 1, height: 1)
    }

    #expect(preview.droppedFrameCount == 7)
    #expect(preview.scheduledDeliveryCountForTesting == 1)
    preview.deliverNewestPreparedImage()
    #expect(preview.renderedFrameCount == 1)
    #expect(preview.scheduledDeliveryCountForTesting == 1)
    preview.close()
}
#endif

@Test @MainActor func previewCloseAfterPreparationBarrierPreventsAnyLaterPresentation() async throws {
    let enteredPreparation = DispatchSemaphore(value: 0)
    let releasePreparation = DispatchSemaphore(value: 0)
    let preview = RawBGRAAppKitPreviewWindow(beforeMainActorDelivery: {
        enteredPreparation.signal()
        releasePreparation.wait()
    })

    try preview.submit(frame: previewTestFrame(sequenceNumber: 2, blue: 2))
    await waitForPreviewSignal(enteredPreparation)
    await closePreviewOffMainActor(preview)
    releasePreparation.signal()
    await preview.waitForRenderQueueForTesting()

    #expect(preview.renderedFrameCount == 0)
    #expect(preview.droppedFrameCount == 1)
    #expect(preview.hasPreviewWindowForTesting == false)
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

private func previewTestFrame(sequenceNumber: UInt64, blue: UInt8) -> RawCapturedVideoFrame {
    RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 1,
            sequenceNumber: sequenceNumber,
            timestampNanoseconds: sequenceNumber,
            timestampBasis: .syntheticMonotonicNanoseconds,
            sourceRole: .testPattern,
            width: 1,
            height: 1,
            pixelFormat: "bgra8",
            frameRate: .init(numerator: 30, denominator: 1),
            fingerprint: "preview-\(sequenceNumber)"
        ),
        payload: Data([blue, 0, 0, 255])
    )
}

private func waitForPreviewSignal(_ signal: DispatchSemaphore) async {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            signal.wait()
            continuation.resume()
        }
    }
}

private func closePreviewOffMainActor(_ preview: RawBGRAAppKitPreviewWindow) async {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            preview.close()
            continuation.resume()
        }
    }
}
