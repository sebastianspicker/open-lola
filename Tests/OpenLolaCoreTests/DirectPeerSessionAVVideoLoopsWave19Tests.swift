// Exercise Wave 19 direct-peer video synchronization, reassembly, and transport metadata behavior boundaries.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func wave19VideoPlayoutAnchorUsesLatestAudioAndClassifiesDirectDecisionBoundary() {
    let policy = AVSyncPolicy(
        profile: .balancedAV,
        audioMaster: true,
        audioMayDelayForVideo: false,
        videoAlignmentToleranceMicroseconds: 10,
        staleVideoDropThresholdMicroseconds: 20,
        earlyVideoDeferThresholdMicroseconds: 30
    )
    var anchor = DirectPeerAVPlayoutAnchor(policy: policy)

    anchor.observeAudio(hostTimeNanoseconds: 1_000_000)
    anchor.observeAudio(hostTimeNanoseconds: 999_999)

    let boundary = anchor.decision(forVideoTimestampNanoseconds: 1_010_000)
    let ahead = directPeerVideoSyncDecision(
        videoTimestampNanoseconds: 1_030_001,
        playoutAnchor: anchor
    )

    #expect(anchor.latestAudioHostTimeNanoseconds == 1_000_000)
    #expect(boundary?.action == .renderNow)
    #expect(boundary?.reason == .insideAlignmentWindow)
    #expect(ahead?.action == .deferVideo)
    #expect(ahead?.reason == .videoAheadOfAudio)
}

@Test
func wave19VideoHostTimeMapperUsesExistingAnchorForRepeatedRemoteTimestamp() {
    let mapper = DirectPeerRemoteVideoHostTimeMapper()
    let first = mapper.map(
        wave19VideoFrame(sequence: 1, timestamp: 100),
        observedLocalHostTimeNanoseconds: 900
    )
    let repeated = mapper.map(
        wave19VideoFrame(sequence: 2, timestamp: 100),
        observedLocalHostTimeNanoseconds: 1_500
    )
    let later = mapper.map(
        wave19VideoFrame(sequence: 3, timestamp: 125),
        observedLocalHostTimeNanoseconds: 2_000
    )

    #expect(first.metadata.timestampNanoseconds == 900)
    #expect(repeated.metadata.timestampNanoseconds == 900)
    #expect(later.metadata.timestampNanoseconds == 925)
    #expect(repeated.metadata.sequenceNumber == 2)
    #expect(repeated.payload == wave19VideoFrame(sequence: 2, timestamp: 100).payload)
}

@Test
func wave19VideoReassemblyDeltaAccumulatesIntoPrepopulatedMetrics() {
    let delta = directPeerVideoReassemblyMetricDelta(
        before: .init(
            framesReassembled: 4,
            framesDroppedIncomplete: 3,
            missingFragments: 2,
            lateFragments: 1,
            duplicateFragments: 5
        ),
        after: .init(
            framesReassembled: 8,
            framesDroppedIncomplete: 7,
            missingFragments: 5,
            lateFragments: 3,
            duplicateFragments: 6
        )
    )
    var drain = DirectPeerVideoRXDrainResult(
        framesDroppedDuringReassembly: 10,
        reassemblyMissingFragments: 20,
        reassemblyLateFragments: 30,
        reassemblyDuplicateFragments: 40
    )
    var runtime = DirectPeerSessionAVRuntimeMetrics()
    runtime.videoFramesDroppedDuringReassembly = 50
    runtime.videoReassemblyMissingFragments = 60
    runtime.videoReassemblyLateFragments = 70
    runtime.videoReassemblyDuplicateFragments = 80

    mergeDirectPeerVideoReassemblyMetricDelta(delta, into: &drain)
    mergeDirectPeerVideoReassemblyMetricDelta(delta, into: &runtime)

    #expect(delta == .init(
        framesDroppedIncomplete: 4,
        missingFragments: 3,
        lateFragments: 2,
        duplicateFragments: 1
    ))
    #expect(drain.framesDroppedDuringReassembly == 14)
    #expect(drain.reassemblyMissingFragments == 23)
    #expect(drain.reassemblyLateFragments == 32)
    #expect(drain.reassemblyDuplicateFragments == 41)
    #expect(runtime.videoFramesDroppedDuringReassembly == 54)
    #expect(runtime.videoReassemblyMissingFragments == 63)
    #expect(runtime.videoReassemblyLateFragments == 72)
    #expect(runtime.videoReassemblyDuplicateFragments == 81)
}

@Test
func wave19VideoPreparedDeferredFrameReplacementAndShutdownAreIdempotent() {
    var deferred: DirectPeerPreparedVideoFrame?
    var drain = DirectPeerVideoRXDrainResult()
    let first = wave19PreparedVideoFrame(sequence: 1, timestamp: 1_000)
    let replacement = wave19PreparedVideoFrame(sequence: 2, timestamp: 2_000)

    deferVideoFrameForSync(first, deferredFrame: &deferred, result: &drain)
    deferVideoFrameForSync(replacement, deferredFrame: &deferred, result: &drain)
    var runtime = DirectPeerSessionAVRuntimeMetrics()
    runtime.videoFramesDroppedForSync = 9
    dropDeferredVideoFrameAtShutdown(&deferred, metrics: &runtime)
    dropDeferredVideoFrameAtShutdown(&deferred, metrics: &runtime)

    #expect(deferred == nil)
    #expect(drain.framesReplacedDuringSyncDefer == 1)
    #expect(drain.framesDroppedForSync == 1)
    #expect(runtime.videoFramesDroppedForSync == 10)
}

@Test
func wave19VideoTransportHelpersPreserveRawAndRoundTripJPEGXSMetadata() throws {
    let frame = wave19VideoFrame(sequence: 19, timestamp: 1_900)

    let rawTransport = try videoTransportFrame(frame, compression: .raw)
    let rawDecoded = try decodedVideoTransportFrame(rawTransport, compression: .raw)
    let jpegXSTransport = try videoTransportFrame(frame, compression: .jpegXS)
    let jpegXSDecoded = try decodedVideoTransportFrame(jpegXSTransport, compression: .jpegXS)

    #expect(rawTransport == frame)
    #expect(rawDecoded == frame)
    #expect(!jpegXSTransport.payload.isEmpty)
    #expect(jpegXSTransport.metadata == frame.metadata)
    #expect(jpegXSDecoded.metadata == frame.metadata)
    #expect(jpegXSDecoded.payload.count == frame.payload.count)
}

private func wave19PreparedVideoFrame(
    sequence: UInt64,
    timestamp: UInt64
) -> DirectPeerPreparedVideoFrame {
    let frame = wave19VideoFrame(sequence: sequence, timestamp: timestamp)
    return DirectPeerPreparedVideoFrame(
        frame: frame,
        proof: directPeerSessionVideoFrameProof(for: frame)
    )
}

private func wave19VideoFrame(sequence: UInt64, timestamp: UInt64) -> RawCapturedVideoFrame {
    let width = 64
    let height = 64
    var payload = Data(count: width * height * 4)
    payload.withUnsafeMutableBytes { rawBuffer in
        let bytes = rawBuffer.bindMemory(to: UInt8.self)
        for pixel in 0..<(width * height) {
            bytes[pixel * 4] = UInt8(truncatingIfNeeded: pixel)
            bytes[pixel * 4 + 1] = UInt8(truncatingIfNeeded: pixel / width)
            bytes[pixel * 4 + 2] = UInt8(truncatingIfNeeded: pixel / height)
            bytes[pixel * 4 + 3] = 255
        }
    }
    return RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 19,
            sequenceNumber: sequence,
            timestampNanoseconds: timestamp,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .testPattern,
            width: width,
            height: height,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "wave19-video-\(sequence)"
        ),
        payload: payload
    )
}
