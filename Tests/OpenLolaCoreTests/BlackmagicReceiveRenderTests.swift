import Foundation
import Testing

@testable import OpenLolaCore

@Test
func videoReassemblerKeepsStreamsIndependentAndCountsIncompleteFragments() throws {
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

    let duplicateSource = TestPatternCameraSource(width: 32, height: 24, frameIntervalNanoseconds: 1)
    let duplicateFragments = try RawVideoFrameTransport.fragments(
        for: try #require(duplicateSource.nextFrame()),
        maxPacketBytes: 320
    )
    let duplicateFirst = try #require(duplicateFragments.first)
    _ = try #require(duplicateFragments.dropFirst().first)
    let duplicateReassembler = VideoFrameReassembler()

    #expect(try duplicateReassembler.receive(duplicateFirst) == nil)
    #expect(try duplicateReassembler.receive(duplicateFirst) == nil)

    #expect(duplicateReassembler.metrics.duplicateFragments == 1)
    #expect(duplicateReassembler.metrics.framesReassembled == 0)

    let flushSource = TestPatternCameraSource(width: 32, height: 24, frameIntervalNanoseconds: 1)
    let flushFragments = try RawVideoFrameTransport.fragments(
        for: try #require(flushSource.nextFrame()),
        maxPacketBytes: 320
    )
    let flushFirst = try #require(flushFragments.first)
    _ = try #require(flushFragments.dropFirst().first)
    let flushReassembler = VideoFrameReassembler()

    #expect(try flushReassembler.receive(flushFirst) == nil)
    flushReassembler.flushIncomplete()

    #expect(flushReassembler.metrics.framesDroppedIncomplete == 1)
    #expect(flushReassembler.metrics.missingFragments == flushFragments.count - 1)
}

@Test
func videoOutputRendererHandlesDeadlineBackpressureContinuityAndRecentLatency() throws {
    let packet = m09OutputPacket(sequenceNumber: 0, timestampNanoseconds: 0)
    var deadlineRenderer = VideoOutputRenderer(
        backend: .localPreview,
        pacingPolicy: .deadline,
        maxQueueDepth: 1,
        deadlineNanoseconds: 1_000_000
    )

    let deadlineResult = deadlineRenderer.submit(
        VideoOutputFrame(
            packet: packet,
            receivedAtNanoseconds: 1_500_000,
            reassembledAtNanoseconds: 1_600_000
        ),
        renderAtNanoseconds: 2_000_000
    )
    let deadlineRendered = deadlineRenderer.renderNext(
        renderAtNanoseconds: 2_100_000,
        outputAtNanoseconds: 2_200_000
    )

    #expect(deadlineResult == .rejected)
    #expect(deadlineRendered == nil)
    #expect(deadlineRenderer.metrics.framesSubmitted == 1)
    #expect(deadlineRenderer.metrics.framesDroppedLate == 1)
    #expect(deadlineRenderer.metrics.framesRendered == 0)

    var backpressureRenderer = VideoOutputRenderer(
        backend: .localPreview,
        pacingPolicy: .latestOnly,
        maxQueueDepth: 1
    )

    for sequenceNumber in UInt64(0)..<3 {
        let result = backpressureRenderer.submit(
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
    let backpressureRendered = backpressureRenderer.renderNext(
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

    #expect(backpressureRendered?.sequenceNumber == 2)
    #expect(backpressureRenderer.metrics.framesSubmitted == 3)
    #expect(backpressureRenderer.metrics.framesDroppedBackpressure == 2)
    #expect(backpressureRenderer.metrics.framesRendered == 1)
    #expect(audioImpact.baselinePlayoutTargetFrames == audioImpact.videoPlayoutTargetFrames)

    var continuityRenderer = VideoOutputRenderer(
        backend: .localPreview,
        pacingPolicy: .continuity,
        maxQueueDepth: 1
    )
    let maxPacket = m09OutputPacket(sequenceNumber: UInt64.max, timestampNanoseconds: 0)
    let wrappedPacket = m09OutputPacket(sequenceNumber: 0, timestampNanoseconds: 16_666_667)

    let acceptedMax = continuityRenderer.submit(
        VideoOutputFrame(
            packet: maxPacket,
            receivedAtNanoseconds: 100,
            reassembledAtNanoseconds: 200
        ),
        renderAtNanoseconds: 300
    )
    let renderedMax = continuityRenderer.renderNext(renderAtNanoseconds: 400, outputAtNanoseconds: 500)
    let acceptedWrapped = continuityRenderer.submit(
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
    #expect(continuityRenderer.metrics.framesDroppedContinuity == 0)

    var metricsRenderer = VideoOutputRenderer(
        backend: .metricsOnly,
        pacingPolicy: .latestOnly,
        maxQueueDepth: 1
    )
    var allSubmitsAccepted = true
    var allRenderedSequencesMatched = true

    for sequenceNumber in UInt64(0)..<10_005 {
        let receiveToReassemblyNanoseconds: UInt64 = sequenceNumber < 5 ? 1_000_000 : 1_000
        let receivedAtNanoseconds = sequenceNumber * 10_000_000
        let reassembledAtNanoseconds = receivedAtNanoseconds + receiveToReassemblyNanoseconds
        let renderAtNanoseconds = reassembledAtNanoseconds + 1_000
        let outputAtNanoseconds = renderAtNanoseconds + 1_000

        allSubmitsAccepted = allSubmitsAccepted && metricsRenderer.submit(
            VideoOutputFrame(
                packet: m09OutputPacket(
                    sequenceNumber: sequenceNumber,
                    timestampNanoseconds: receivedAtNanoseconds
                ),
                receivedAtNanoseconds: receivedAtNanoseconds,
                reassembledAtNanoseconds: reassembledAtNanoseconds
            ),
            renderAtNanoseconds: renderAtNanoseconds
        ) == .accepted
        allRenderedSequencesMatched = allRenderedSequencesMatched && metricsRenderer.renderNext(
            renderAtNanoseconds: renderAtNanoseconds,
            outputAtNanoseconds: outputAtNanoseconds
        )?.sequenceNumber == sequenceNumber
    }

    #expect(allSubmitsAccepted)
    #expect(allRenderedSequencesMatched)
    #expect(metricsRenderer.metrics.framesRendered == 10_005)
    #expect(metricsRenderer.metrics.receiveToReassembly.maxMicroseconds == 1)
    #expect(metricsRenderer.metrics.reassemblyToRender.maxMicroseconds == 1)
    #expect(metricsRenderer.metrics.renderToOutput.maxMicroseconds == 1)
}

@Test
func receiveRenderSyntheticSmokeAndBlackmagicBoundaryRequirePhysicalEvidence() throws {
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

    let boundaryReport = BlackmagicOutputBoundaryReport(
        backend: .blackmagicDeckLink,
        desktopVideoSDK: .linkedNoDevice,
        compileTimeAvailable: true,
        runtimeAvailable: false,
        hardwareDetected: false,
        enumerationError: "permission denied",
        notes: "enumeration failed"
    )

    let encoded = try JSONEncoder().encode(boundaryReport)
    let decoded = try JSONDecoder().decode(BlackmagicOutputBoundaryReport.self, from: encoded)

    #expect(decoded.enumerationError == "permission denied")
    #expect(!decoded.hasPhysicalOutputEvidence)

    let fallbackReport = BlackmagicOutputBoundary.localPreviewFallback()

    #expect(!fallbackReport.hasPhysicalOutputEvidence)
    #expect(fallbackReport.outputLimitationSummary.contains("PARTIAL"))
    #expect(fallbackReport.outputLimitationSummary.contains("DeckLink output unavailable"))
    #expect(fallbackReport.notes.contains("DeckLink output is unavailable"))

    var passCandidate = try VideoReceiveRenderSyntheticSmoke.run()
    passCandidate.verdict = .pass
    passCandidate.degradation.triggeredBeforeAudioOrRouteImpact = true
    passCandidate.receiver.displayedFrames = passCandidate.receiver.receivedFrames
    passCandidate.receiver.droppedFrames = 0
    passCandidate.routeEvidence = VideoTransportRouteEvidence(
        routeKind: .directWired,
        routeLabel: "m09-direct-wired-blackmagic-output",
        packetCapturePoint: "receiver-en0",
        rawOrIntraFrameBaselineReportId: nil,
        rawOrIntraFrameBaselineMode: nil,
        baselineAudioRouteVerdict: .pass,
        videoActiveAudioRouteVerdict: .pass
    )

    #expect(throws: VideoTransportValidationError.passWithoutBlackmagicOutputEvidence) {
        try passCandidate.validate()
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
