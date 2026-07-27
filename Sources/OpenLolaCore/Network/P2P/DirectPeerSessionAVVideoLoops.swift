// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Dispatch
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
    /// Accepted by the preview queue. This is intentionally distinct from the
    /// runtime report's rendered-frame count.
    var previewFramesEnqueued = 0
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

final class DirectPeerRemoteVideoHostTimeMapper {
    private var anchorRemoteHostTimeNanoseconds: UInt64?
    private var anchorLocalHostTimeNanoseconds: UInt64?

    func map(
        _ frame: RawCapturedVideoFrame,
        observedLocalHostTimeNanoseconds: UInt64
    ) -> RawCapturedVideoFrame {
        let remoteHostTimeNanoseconds = frame.metadata.timestampNanoseconds
        let mappedHostTimeNanoseconds: UInt64
        if let anchorRemoteHostTimeNanoseconds,
           let anchorLocalHostTimeNanoseconds,
           remoteHostTimeNanoseconds >= anchorRemoteHostTimeNanoseconds {
            let delta = remoteHostTimeNanoseconds - anchorRemoteHostTimeNanoseconds
            let mapped = anchorLocalHostTimeNanoseconds.addingReportingOverflow(delta)
            if mapped.overflow {
                mappedHostTimeNanoseconds = reanchor(
                    remoteHostTimeNanoseconds: remoteHostTimeNanoseconds,
                    localHostTimeNanoseconds: observedLocalHostTimeNanoseconds
                )
            } else {
                mappedHostTimeNanoseconds = mapped.partialValue
            }
        } else {
            mappedHostTimeNanoseconds = reanchor(
                remoteHostTimeNanoseconds: remoteHostTimeNanoseconds,
                localHostTimeNanoseconds: observedLocalHostTimeNanoseconds
            )
        }
        var mappedFrame = frame
        mappedFrame.metadata.timestampNanoseconds = mappedHostTimeNanoseconds
        return mappedFrame
    }

    private func reanchor(
        remoteHostTimeNanoseconds: UInt64,
        localHostTimeNanoseconds: UInt64
    ) -> UInt64 {
        anchorRemoteHostTimeNanoseconds = remoteHostTimeNanoseconds
        anchorLocalHostTimeNanoseconds = localHostTimeNanoseconds
        return localHostTimeNanoseconds
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
    var decodeWorker: DirectPeerVideoDecodeWorker? = nil
    var remoteHostTimeMapper: DirectPeerRemoteVideoHostTimeMapper? = nil
}

private enum DirectPeerVideoRXPacketDrain {
    case noPacket
    case skipped
    case frame(DirectPeerPreparedVideoFrame)
}

func runVideoRXLoop(
    runner: inout PeerSessionRunner,
    reassembler: inout VideoFrameReassembler,
    deferredFrame: inout DirectPeerPreparedVideoFrame?,
    configuration: DirectPeerVideoRXLoopConfiguration
) throws -> DirectPeerVideoRXDrainResult {
    var result = DirectPeerVideoRXDrainResult()
    let reassemblyMetricsBefore = reassembler.metrics
    try drainDeferredVideoFrame(&deferredFrame, configuration: configuration, result: &result)
    try drainDecodedVideoFrame(
        configuration.decodeWorker,
        deferredFrame: &deferredFrame,
        configuration: configuration,
        result: &result
    )
    var drainedPackets = 0
    packetDrainLoop:
    while drainedPackets < configuration.maxPackets {
        drainedPackets += 1
        switch try drainNextVideoRXPacket(
            runner: &runner,
            reassembler: &reassembler,
            configuration: configuration,
            result: &result
        ) {
        case .noPacket:
            drainedPackets -= 1
            break packetDrainLoop
        case .skipped:
            continue
        case .frame(let frame):
            try processReceivedVideoRXFrame(
frame,
deferredFrame: &deferredFrame,
configuration: configuration,
result: &result
)
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

private func drainDeferredVideoFrame(
    _ deferredFrame: inout DirectPeerPreparedVideoFrame?,
    configuration: DirectPeerVideoRXLoopConfiguration,
    result: inout DirectPeerVideoRXDrainResult
) throws {
    guard let frame = deferredFrame else {
        return
    }
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

private func drainDecodedVideoFrame(
    _ worker: DirectPeerVideoDecodeWorker?,
    deferredFrame: inout DirectPeerPreparedVideoFrame?,
    configuration: DirectPeerVideoRXLoopConfiguration,
    result: inout DirectPeerVideoRXDrainResult
) throws {
    guard let worker else {
        return
    }
    result.framesDroppedDuringReassembly += worker.takeDroppedFrameCount()
    guard let completion = worker.takeCompletion() else {
        return
    }
    switch completion {
    case .success(let frame):
        try processReceivedVideoRXFrame(
            frame,
            deferredFrame: &deferredFrame,
            configuration: configuration,
            result: &result
        )
    case .failure:
        result.framesDroppedDuringReassembly += 1
    }
}

private func drainNextVideoRXPacket(
    runner: inout PeerSessionRunner,
    reassembler: inout VideoFrameReassembler,
    configuration: DirectPeerVideoRXLoopConfiguration,
    result: inout DirectPeerVideoRXDrainResult
) throws -> DirectPeerVideoRXPacketDrain {
    let receivedPacket: PeerSessionReceivedVideoMediaPacket
    do {
        guard let packet = try runner.receiveDecodedVideoMediaPacketIfAvailable() else {
            return .noPacket
        }
        receivedPacket = packet
    } catch is UdpMediaMalformedDatagramError {
        result.fragmentsDroppedCorrupt += 1
        return .skipped
    }
    return try drainReceivedVideoRXPacket(
        receivedPacket,
        reassembler: &reassembler,
        configuration: configuration,
        result: &result
    )
}

private func drainReceivedVideoRXPacket(
    _ receivedPacket: PeerSessionReceivedVideoMediaPacket,
    reassembler: inout VideoFrameReassembler,
    configuration: DirectPeerVideoRXLoopConfiguration,
    result: inout DirectPeerVideoRXDrainResult
) throws -> DirectPeerVideoRXPacketDrain {
    guard receivedPacket.packet.header.payloadType == configuration.compression.payloadType else {
        result.unexpectedPayloadTypes += 1
        return .skipped
    }
    result.fragmentsReceived += 1
    guard let fragment = receivedPacket.decodedFragment else {
        result.fragmentsDroppedCorrupt += 1
        return .skipped
    }
    return try receiveVideoRXFragment(
fragment,
reassembler: &reassembler,
configuration: configuration,
result: &result
)
}

private func receiveVideoRXFragment(
    _ fragment: VideoTransportFragment,
    reassembler: inout VideoFrameReassembler,
    configuration: DirectPeerVideoRXLoopConfiguration,
    result: inout DirectPeerVideoRXDrainResult
) throws -> DirectPeerVideoRXPacketDrain {
    let receivedFrame: RawCapturedVideoFrame?
    do {
        receivedFrame = try reassembler.receiveRaw(fragment)
    } catch VideoTransportFragmentError.invalidFragmentCount {
        result.fragmentsDroppedOversize += 1
        result.framesDroppedDuringReassembly += 1
        return .skipped
    } catch {
        result.framesDroppedDuringReassembly += 1
        return .skipped
    }
    guard var receivedFrame else {
        return .skipped
    }
    result.framesReassembled += 1
    if let remoteHostTimeMapper = configuration.remoteHostTimeMapper {
        receivedFrame = remoteHostTimeMapper.map(
            receivedFrame,
            observedLocalHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
        )
    }
    if let decodeWorker = configuration.decodeWorker {
        decodeWorker.submitLatest(DirectPeerVideoDecodeRequest(
            frame: receivedFrame,
            compression: configuration.compression
        ))
        return .skipped
    }
    do {
        let frame = try decodedVideoTransportFrame(receivedFrame, compression: configuration.compression)
        return .frame(DirectPeerPreparedVideoFrame(
            frame: frame,
            proof: directPeerSessionVideoFrameProof(for: frame)
        ))
    } catch {
        result.framesDroppedDuringReassembly += 1
        return .skipped
    }
}

private func processReceivedVideoRXFrame(
    _ frame: DirectPeerPreparedVideoFrame,
    deferredFrame: inout DirectPeerPreparedVideoFrame?,
    configuration: DirectPeerVideoRXLoopConfiguration,
    result: inout DirectPeerVideoRXDrainResult
) throws {
    switch try processVideoFrameForSync(
        frame,
        previewSink: configuration.previewSink,
        playoutAnchor: configuration.playoutAnchor,
        result: &result
    ) {
    case .accepted, .dropped:
        break
    case .deferred:
        deferVideoFrameForSync(frame, deferredFrame: &deferredFrame, result: &result)
    }
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
    _ frame: DirectPeerPreparedVideoFrame,
    deferredFrame: inout DirectPeerPreparedVideoFrame?,
    result: inout DirectPeerVideoRXDrainResult
) {
    if deferredFrame != nil {
        result.framesReplacedDuringSyncDefer += 1
        result.framesDroppedForSync += 1
    }
    deferredFrame = frame
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
    _ deferredFrame: inout DirectPeerPreparedVideoFrame?,
    metrics: inout DirectPeerSessionAVRuntimeMetrics
) {
    guard deferredFrame != nil else {
        return
    }
    metrics.videoFramesDroppedForSync += 1
    deferredFrame = nil
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
    _ prepared: DirectPeerPreparedVideoFrame,
    previewSink: RawBGRAPreviewSink?,
    playoutAnchor: DirectPeerAVPlayoutAnchor,
    result: inout DirectPeerVideoRXDrainResult
) throws -> DirectPeerVideoSyncFrameOutcome {
    let frame = prepared.frame
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
                result.previewFramesEnqueued += 1
            }
        } catch {
            result.previewFramesFailed += 1
        }
    }
    result.framesAcceptedForProof += 1
    result.firstFrameProof = result.firstFrameProof ?? prepared.proof
    result.latestFrameProof = prepared.proof
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
