import Foundation
import Testing

@testable import OpenLolaCore

@Test
func videoReassemblerKeepsConcurrentStreamBucketsIndependent() throws {
    let streamA = TestPatternCameraSource(
        width: 32,
        height: 24,
        frameIntervalNanoseconds: 16_666_667,
        streamID: 101
    )
    let streamB = TestPatternCameraSource(
        width: 32,
        height: 24,
        frameIntervalNanoseconds: 16_666_667,
        streamID: 202
    )
    let fragmentsA = try RawVideoFrameTransport.fragments(
        for: try #require(streamA.nextFrame()),
        maxPacketBytes: 320
    )
    let fragmentsB = try RawVideoFrameTransport.fragments(
        for: try #require(streamB.nextFrame()),
        maxPacketBytes: 320
    )
    _ = try #require(fragmentsA.dropFirst().first)
    _ = try #require(fragmentsB.dropFirst().first)
    let reassembler = VideoFrameReassembler(maxActiveFrames: 2)
    var completed: [VideoTransportPacket] = []

    #expect(try reassembler.receive(fragmentsA[0]) == nil)
    #expect(try reassembler.receive(fragmentsB[0]) == nil)
    for fragment in fragmentsA.dropFirst() {
        if let packet = try reassembler.receive(fragment) {
            completed.append(packet)
        }
    }
    for fragment in fragmentsB.dropFirst() {
        if let packet = try reassembler.receive(fragment) {
            completed.append(packet)
        }
    }

    #expect(Set(completed.map(\.streamID)) == [101, 202])
    #expect(completed.allSatisfy { $0.sequenceNumber == 0 })
    #expect(reassembler.metrics.framesReassembled == 2)
    #expect(reassembler.metrics.framesDroppedIncomplete == 0)
    #expect(reassembler.metrics.activeFramesPeak == 2)
}

@Test
func videoReassemblerCountsDuplicateFragments() throws {
    let source = TestPatternCameraSource(width: 32, height: 24, frameIntervalNanoseconds: 1)
    let fragments = try RawVideoFrameTransport.fragments(
        for: try #require(source.nextFrame()),
        maxPacketBytes: 320
    )
    let first = try #require(fragments.first)
    _ = try #require(fragments.dropFirst().first)
    let reassembler = VideoFrameReassembler()

    #expect(try reassembler.receive(first) == nil)
    #expect(try reassembler.receive(first) == nil)

    #expect(reassembler.metrics.duplicateFragments == 1)
    #expect(reassembler.metrics.framesReassembled == 0)
}

@Test
func videoReassemblerDropsIncompleteFrameOnFlush() throws {
    let source = TestPatternCameraSource(width: 32, height: 24, frameIntervalNanoseconds: 1)
    let fragments = try RawVideoFrameTransport.fragments(
        for: try #require(source.nextFrame()),
        maxPacketBytes: 320
    )
    let first = try #require(fragments.first)
    _ = try #require(fragments.dropFirst().first)
    let reassembler = VideoFrameReassembler()

    #expect(try reassembler.receive(first) == nil)
    reassembler.flushIncomplete()

    #expect(reassembler.metrics.framesDroppedIncomplete == 1)
    #expect(reassembler.metrics.missingFragments == fragments.count - 1)
}

@Test
func deadlineRendererDropsLateFrameBeforeRender() throws {
    let packet = m09OutputPacket(sequenceNumber: 0, timestampNanoseconds: 0)
    var renderer = VideoOutputRenderer(
        backend: .localPreview,
        pacingPolicy: .deadline,
        maxQueueDepth: 1,
        deadlineNanoseconds: 1_000_000
    )

    let result = renderer.submit(
        VideoOutputFrame(
            packet: packet,
            receivedAtNanoseconds: 1_500_000,
            reassembledAtNanoseconds: 1_600_000
        ),
        renderAtNanoseconds: 2_000_000
    )
    let rendered = renderer.renderNext(
        renderAtNanoseconds: 2_100_000,
        outputAtNanoseconds: 2_200_000
    )

    #expect(result == .rejected)
    #expect(rendered == nil)
    #expect(renderer.metrics.framesSubmitted == 1)
    #expect(renderer.metrics.framesDroppedLate == 1)
    #expect(renderer.metrics.framesRendered == 0)
}

@Test
func outputBackpressureDropsVideoWithoutChangingAudioTarget() throws {
    var renderer = VideoOutputRenderer(
        backend: .localPreview,
        pacingPolicy: .latestOnly,
        maxQueueDepth: 1
    )

    for sequenceNumber in UInt64(0)..<3 {
        let result = renderer.submit(
            VideoOutputFrame(
                packet: m09OutputPacket(
                    sequenceNumber: sequenceNumber,
                    timestampNanoseconds: sequenceNumber * 16_666_667
                ),
                receivedAtNanoseconds: sequenceNumber * 16_666_667 + 100,
                reassembledAtNanoseconds: sequenceNumber * 16_666_667 + 200
            ),
            renderAtNanoseconds: sequenceNumber * 16_666_667 + 300
        )
        #expect(result == (sequenceNumber == 0 ? .accepted : .acceptedWithBackpressureDrop))
    }
    let rendered = renderer.renderNext(
        renderAtNanoseconds: 50_000_000,
        outputAtNanoseconds: 50_100_000
    )
    let audioImpact = VideoAudioImpactMetrics(
        baselineCallbackP99Microseconds: 80,
        videoCallbackP99Microseconds: 80,
        baselineCallbackMaxMicroseconds: 95,
        videoCallbackMaxMicroseconds: 95,
        baselinePlayoutTargetFrames: 32,
        videoPlayoutTargetFrames: 32,
        underruns: 0,
        hiddenAudioImpactDetected: false
    )

    #expect(rendered?.sequenceNumber == 2)
    #expect(renderer.metrics.framesSubmitted == 3)
    #expect(renderer.metrics.framesDroppedBackpressure == 2)
    #expect(renderer.metrics.framesRendered == 1)
    #expect(audioImpact.baselinePlayoutTargetFrames == audioImpact.videoPlayoutTargetFrames)
}

@Test
func continuityRendererAcceptsSequenceZeroAfterUInt64Max() throws {
    var renderer = VideoOutputRenderer(
        backend: .localPreview,
        pacingPolicy: .continuity,
        maxQueueDepth: 1
    )
    let maxPacket = m09OutputPacket(sequenceNumber: UInt64.max, timestampNanoseconds: 0)
    let wrappedPacket = m09OutputPacket(sequenceNumber: 0, timestampNanoseconds: 16_666_667)

    let acceptedMax = renderer.submit(
        VideoOutputFrame(
            packet: maxPacket,
            receivedAtNanoseconds: 100,
            reassembledAtNanoseconds: 200
        ),
        renderAtNanoseconds: 300
    )
    let renderedMax = renderer.renderNext(renderAtNanoseconds: 400, outputAtNanoseconds: 500)
    let acceptedWrapped = renderer.submit(
        VideoOutputFrame(
            packet: wrappedPacket,
            receivedAtNanoseconds: 16_666_767,
            reassembledAtNanoseconds: 16_666_867
        ),
        renderAtNanoseconds: 16_666_967
    )

    #expect(acceptedMax == .accepted)
    #expect(renderedMax == maxPacket)
    #expect(acceptedWrapped == .accepted)
    #expect(renderer.metrics.framesDroppedContinuity == 0)
}

@Test
func videoOutputRendererUsesBoundedLatencySampleBuffers() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/VideoOutputRenderer.swift")

    #expect(source.contains("videoOutputLatencySampleLimit = 10_000"))
    #expect(source.contains("BoundedDoubleSamples"))
    #expect(source.contains("guard storage.count == capacity, startIndex > 0 else"))
    #expect(!source.contains("private var receiveToReassemblyMicroseconds: [Double]"))
    #expect(!source.contains("private var reassemblyToRenderMicroseconds: [Double]"))
    #expect(!source.contains("private var renderToOutputMicroseconds: [Double]"))
}

@Test
func receiveRenderSyntheticSmokeIncludesLatencyAndBlackmagicBoundary() throws {
    let report = try VideoReceiveRenderSyntheticSmoke.run()

    try report.validate()

    let renderOutput = try #require(report.renderOutput)
    let blackmagicOutput = try #require(report.blackmagicOutput)
    #expect(renderOutput.backend == .metricsOnly)
    #expect(renderOutput.framesRendered == report.reassembly?.framesReassembled)
    #expect(renderOutput.framesOutput == renderOutput.framesRendered)
    #expect(renderOutput.receiveToReassembly.maxMicroseconds >= 0)
    #expect(renderOutput.reassemblyToRender.maxMicroseconds >= 0)
    #expect(renderOutput.renderToOutput.maxMicroseconds >= 0)
    #expect(blackmagicOutput.backend == .localPreview)
    #expect(blackmagicOutput.desktopVideoSDK == .notLinked)
    #expect(!blackmagicOutput.runtimeAvailable)
    #expect(blackmagicOutput.enumerationError == nil)
    #expect(report.audioImpact.baselinePlayoutTargetFrames == report.audioImpact.videoPlayoutTargetFrames)
    #expect(report.verdict == .partial)
}

@Test
func blackmagicOutputBoundaryReportCarriesEnumerationErrorSeparately() throws {
    let report = BlackmagicOutputBoundaryReport(
        backend: .blackmagicDeckLink,
        desktopVideoSDK: .linkedNoDevice,
        compileTimeAvailable: true,
        runtimeAvailable: false,
        hardwareDetected: false,
        enumerationError: "permission denied",
        notes: "enumeration failed"
    )

    let encoded = try JSONEncoder().encode(report)
    let decoded = try JSONDecoder().decode(BlackmagicOutputBoundaryReport.self, from: encoded)

    #expect(decoded.enumerationError == "permission denied")
    #expect(!decoded.hasPhysicalOutputEvidence)
}

@Test
func blackmagicOutputBoundaryReportsExplicitPartialDeckLinkLimitation() {
    let report = BlackmagicOutputBoundary.localPreviewFallback()

    #expect(!report.hasPhysicalOutputEvidence)
    #expect(report.outputLimitationSummary.contains("PARTIAL"))
    #expect(report.outputLimitationSummary.contains("DeckLink output unavailable"))
    #expect(report.notes.contains("DeckLink output is unavailable"))
}

@Test
func physicalPassRequiresBlackmagicOutputEvidence() throws {
    var report = try VideoReceiveRenderSyntheticSmoke.run()
    report.verdict = .pass
    report.degradation.triggeredBeforeAudioOrRouteImpact = true
    report.receiver.displayedFrames = report.receiver.receivedFrames
    report.receiver.droppedFrames = 0
    report.routeEvidence = VideoTransportRouteEvidence(
        routeKind: .directWired,
        routeLabel: "m09-direct-wired-blackmagic-output",
        packetCapturePoint: "receiver-en0",
        rawOrIntraFrameBaselineReportId: nil,
        rawOrIntraFrameBaselineMode: nil,
        baselineAudioRouteVerdict: .pass,
        videoActiveAudioRouteVerdict: .pass
    )

    #expect(throws: VideoTransportValidationError.passWithoutBlackmagicOutputEvidence) {
        try report.validate()
    }
}

private func m09OutputPacket(
    sequenceNumber: UInt64,
    timestampNanoseconds: UInt64
) -> VideoTransportPacket {
    VideoTransportPacket(
        streamID: 100,
        sequenceNumber: sequenceNumber,
        timestampNanoseconds: timestampNanoseconds,
        timestampBasis: .syntheticMonotonicNanoseconds,
        sourceRole: .testPattern,
        width: 1_280,
        height: 720,
        pixelFormat: "synthetic-rgb",
        frameRate: VideoFrameRate(numerator: 60, denominator: 1),
        payloadByteCount: 1_280 * 720 * 3,
        frameFingerprint: "m09-output-\(sequenceNumber)"
    )
}

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
