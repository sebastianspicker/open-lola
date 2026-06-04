import Foundation

struct DirectPeerVideoRXDrainResult {
    var fragmentsReceived = 0
    var fragmentsDroppedCorrupt = 0
    var unexpectedPayloadTypes = 0
    var framesReassembled = 0
    var framesDroppedDuringReassembly = 0
    var fragmentsDroppedOversize = 0
    var reassemblyMissingFragments = 0
    var reassemblyLateFragments = 0
    var reassemblyDuplicateFragments = 0
    var previewFramesSubmitted = 0
    var previewFramesDropped = 0
    var previewFramesFailed = 0
    var framesDroppedOutsideAudioWindow = 0
    var framesAlignedForSync = 0
    var framesDeferredForSync = 0
    var framesDroppedForSync = 0
    var framesReplacedDuringSyncDefer = 0
    var framesAcceptedForProof = 0
    var firstFrameProof: DirectPeerSessionVideoFrameProof?
    var latestFrameProof: DirectPeerSessionVideoFrameProof?
}

struct DirectPeerAVPlayoutAnchor {
    var latestAudioHostTimeNanoseconds: UInt64?
    var policy: AVSyncPolicy

    mutating func observeAudio(hostTimeNanoseconds: UInt64) {
        latestAudioHostTimeNanoseconds = max(latestAudioHostTimeNanoseconds ?? 0, hostTimeNanoseconds)
    }

    func decision(forVideoTimestampNanoseconds timestampNanoseconds: UInt64) -> AVSyncDecision? {
        directPeerVideoSyncDecision(
            videoTimestampNanoseconds: timestampNanoseconds,
            playoutAnchor: self
        )
    }
}

func directPeerVideoSyncDecision(
    videoTimestampNanoseconds: UInt64,
    playoutAnchor: DirectPeerAVPlayoutAnchor
) -> AVSyncDecision? {
    guard let latestAudioHostTimeNanoseconds = playoutAnchor.latestAudioHostTimeNanoseconds else {
        return nil
    }
    return AVTimestampAligner.decision(
        videoTimestampNanoseconds: videoTimestampNanoseconds,
        audioPlayoutTimestampNanoseconds: latestAudioHostTimeNanoseconds,
        policy: playoutAnchor.policy
    )
}

struct DirectPeerVideoRXLoopConfiguration {
    var previewSink: RawBGRAPreviewSink?
    var playoutAnchor: DirectPeerAVPlayoutAnchor
    var compression: DirectPeerSessionVideoCompression
    var maxPackets: Int
}

func runVideoRXLoop(
    runner: inout PeerSessionRunner,
    reassembler: inout VideoFrameReassembler,
    deferredFrame: inout RawCapturedVideoFrame?,
    configuration: DirectPeerVideoRXLoopConfiguration
) throws -> DirectPeerVideoRXDrainResult {
    var result = DirectPeerVideoRXDrainResult()
    let reassemblyMetricsBefore = reassembler.metrics
    if let frame = deferredFrame {
        switch try processVideoFrameForSync(
            frame,
            previewSink: configuration.previewSink,
            playoutAnchor: configuration.playoutAnchor,
            result: &result
        ) {
        case .accepted, .dropped:
            deferredFrame = nil
        case .deferred:
            break
        }
    }
    var drainedPackets = 0
    while drainedPackets < configuration.maxPackets {
        let receivedPacket: PeerSessionReceivedVideoMediaPacket
        do {
            guard let packet = try runner.receiveDecodedVideoMediaPacketIfAvailable() else {
                break
            }
            receivedPacket = packet
        } catch is UdpMediaMalformedDatagramError {
            drainedPackets += 1
            result.fragmentsDroppedCorrupt += 1
            continue
        }
        drainedPackets += 1
        let packet = receivedPacket.packet
        guard packet.header.payloadType == configuration.compression.payloadType else {
            result.unexpectedPayloadTypes += 1
            continue
        }
        result.fragmentsReceived += 1
        guard let fragment = receivedPacket.decodedFragment else {
            result.fragmentsDroppedCorrupt += 1
            continue
        }
        let receivedFrame: RawCapturedVideoFrame?
        do {
            receivedFrame = try reassembler.receiveRaw(fragment)
        } catch VideoTransportFragmentError.invalidFragmentCount {
            result.fragmentsDroppedOversize += 1
            result.framesDroppedDuringReassembly += 1
            continue
        } catch {
            result.framesDroppedDuringReassembly += 1
            continue
        }
        guard let receivedFrame else {
            continue
        }
        result.framesReassembled += 1
        let frame: RawCapturedVideoFrame
        do {
            frame = try decodedVideoTransportFrame(receivedFrame, compression: configuration.compression)
        } catch {
            result.framesDroppedDuringReassembly += 1
            continue
        }
        switch try processVideoFrameForSync(
            frame,
            previewSink: configuration.previewSink,
            playoutAnchor: configuration.playoutAnchor,
            result: &result
        ) {
        case .accepted, .dropped:
            continue
        case .deferred:
            deferVideoFrameForSync(frame, deferredFrame: &deferredFrame, result: &result)
            continue
        }
    }
    mergeDirectPeerVideoReassemblyMetricDelta(
        directPeerVideoReassemblyMetricDelta(
            before: reassemblyMetricsBefore,
            after: reassembler.metrics
        ),
        into: &result
    )
    return result
}

struct DirectPeerVideoReassemblyMetricDelta: Equatable, Sendable {
    var framesDroppedIncomplete: Int
    var missingFragments: Int
    var lateFragments: Int
    var duplicateFragments: Int
}

func directPeerVideoReassemblyMetricDelta(
    before: VideoReassemblyMetrics,
    after: VideoReassemblyMetrics
) -> DirectPeerVideoReassemblyMetricDelta {
    DirectPeerVideoReassemblyMetricDelta(
        framesDroppedIncomplete: max(0, after.framesDroppedIncomplete - before.framesDroppedIncomplete),
        missingFragments: max(0, after.missingFragments - before.missingFragments),
        lateFragments: max(0, after.lateFragments - before.lateFragments),
        duplicateFragments: max(0, after.duplicateFragments - before.duplicateFragments)
    )
}

func mergeDirectPeerVideoReassemblyMetricDelta(
    _ delta: DirectPeerVideoReassemblyMetricDelta,
    into result: inout DirectPeerVideoRXDrainResult
) {
    result.framesDroppedDuringReassembly += delta.framesDroppedIncomplete
    result.reassemblyMissingFragments += delta.missingFragments
    result.reassemblyLateFragments += delta.lateFragments
    result.reassemblyDuplicateFragments += delta.duplicateFragments
}

func mergeDirectPeerVideoReassemblyMetricDelta(
    _ delta: DirectPeerVideoReassemblyMetricDelta,
    into metrics: inout DirectPeerSessionAVRuntimeMetrics
) {
    metrics.videoFramesDroppedDuringReassembly += delta.framesDroppedIncomplete
    metrics.videoReassemblyMissingFragments += delta.missingFragments
    metrics.videoReassemblyLateFragments += delta.lateFragments
    metrics.videoReassemblyDuplicateFragments += delta.duplicateFragments
}

func deferVideoFrameForSync(
    _ frame: RawCapturedVideoFrame,
    deferredFrame: inout RawCapturedVideoFrame?,
    result: inout DirectPeerVideoRXDrainResult
) {
    if deferredFrame != nil {
        result.framesReplacedDuringSyncDefer += 1
        result.framesDroppedForSync += 1
    }
    deferredFrame = frame
}

func dropDeferredVideoFrameAtShutdown(
    _ deferredFrame: inout RawCapturedVideoFrame?,
    metrics: inout DirectPeerSessionAVRuntimeMetrics
) {
    guard deferredFrame != nil else {
        return
    }
    metrics.videoFramesDroppedForSync += 1
    deferredFrame = nil
}

private enum DirectPeerVideoSyncFrameOutcome {
    case accepted
    case deferred
    case dropped
}

private func processVideoFrameForSync(
    _ frame: RawCapturedVideoFrame,
    previewSink: RawBGRAPreviewSink?,
    playoutAnchor: DirectPeerAVPlayoutAnchor,
    result: inout DirectPeerVideoRXDrainResult
) throws -> DirectPeerVideoSyncFrameOutcome {
    guard let syncDecision = playoutAnchor.decision(
        forVideoTimestampNanoseconds: frame.metadata.timestampNanoseconds
    ) else {
        result.framesDeferredForSync += 1
        return .deferred
    }
    switch syncDecision.action {
    case .renderNow:
        result.framesAlignedForSync += 1
    case .deferVideo:
        result.framesDeferredForSync += 1
        return .deferred
    case .dropVideo:
        result.framesDroppedOutsideAudioWindow += 1
        result.framesDroppedForSync += 1
        return .dropped
    }
    if let previewSink {
        let droppedBeforeSubmit = previewSink.droppedFrameCount
        do {
            try previewSink.submit(frame: frame)
            let droppedAfterSubmit = previewSink.droppedFrameCount
            if droppedAfterSubmit > droppedBeforeSubmit {
                result.previewFramesDropped += droppedAfterSubmit - droppedBeforeSubmit
            } else {
                result.previewFramesSubmitted += 1
            }
        } catch {
            result.previewFramesFailed += 1
        }
    }
    let proof = directPeerSessionVideoFrameProof(for: frame)
    result.framesAcceptedForProof += 1
    result.firstFrameProof = result.firstFrameProof ?? proof
    result.latestFrameProof = proof
    return .accepted
}

func videoTransportFrame(
    _ rawFrame: RawCapturedVideoFrame,
    compression: DirectPeerSessionVideoCompression
) throws -> RawCapturedVideoFrame {
    switch compression {
    case .raw:
        return rawFrame
    case .jpegXS:
        return RawCapturedVideoFrame(
            metadata: rawFrame.metadata,
            payload: try JPEGXSReferenceCodec.encode(frame: rawFrame)
        )
    }
}

func decodedVideoTransportFrame(
    _ frame: RawCapturedVideoFrame,
    compression: DirectPeerSessionVideoCompression
) throws -> RawCapturedVideoFrame {
    switch compression {
    case .raw:
        return frame
    case .jpegXS:
        return try JPEGXSReferenceCodec.decode(codestream: frame.payload, metadata: frame.metadata)
    }
}
