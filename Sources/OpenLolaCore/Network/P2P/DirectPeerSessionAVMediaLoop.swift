// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Darwin
import CoreAudio
import Dispatch
import Foundation
import os

struct DirectPeerAVMediaLoopResources {
    var audioGraph: DirectPeerRealtimeAudioGraph
    var opusEncoder: OpusCELTLowDelayEncoder?
    var opusDecoder: OpusCELTLowDelayDecoder?
    var opusScratch: DirectPeerOpusSessionScratch?
    var rtpSSRC: UInt32
    var liveVideoSource: DirectPeerAVFoundationRawFrameSource
    var videoPreparationWorker: DirectPeerVideoPreparationWorker
    var videoDecodeWorker: DirectPeerVideoDecodeWorker?
    var previewSink: RawBGRAPreviewSink?
    var videoReassembler: VideoFrameReassembler
}

struct DirectPeerAVMediaLoopLifecycle {
    var audioGraphStarted = false
    var liveVideoSourceStarted = false
}

struct DirectPeerAVMediaLoopTiming {
    var deadlineNanoseconds: UInt64
    var videoFrameIntervalNanoseconds: UInt64
    var audioPollIntervalMicroseconds: UInt64
    var audioPacketIntervalNanoseconds: UInt64
    var videoReceiveDrainPacketLimit = 32
    /// One datagram is the maximum video quantum. Audio gets another service
    /// opportunity before a second fragment, including at a capture deadline.
    var videoTransmitPacketLimit = 1
    var audioTransmitDrainPacketLimit = 32

    init(configuration: DirectPeerSessionAVRunConfiguration) throws {
        deadlineNanoseconds = try directPeerAVRunDeadlineNanoseconds(
            now: DispatchTime.now().uptimeNanoseconds,
            durationSeconds: configuration.durationSeconds
        )
        videoFrameIntervalNanoseconds = UInt64(max(1, 1_000_000_000 / configuration.videoFrameRate))
        audioPacketIntervalNanoseconds = max(
            1,
            MediaClock.nanoseconds(
                forFrameCount: UInt64(configuration.framesPerPacket),
                sampleRateHertz: configuration.sampleRateHertz
            )
        )
        // Poll twice per audio packet period so control/video receive work is
        // not forced to wait for a full packet duration when audio is idle.
        let audioPollsPerPacketPeriod = 2
        audioPollIntervalMicroseconds = UInt64(max(
            250,
            configuration.framesPerPacket * 1_000_000 / configuration.sampleRateHertz / audioPollsPerPacketPeriod
        ))
    }
}

private let directPeerFastestAudioReceiveDrainPacketLimit = 256

struct DirectPeerPendingVideoTransmit {
    var packets: [UdpMediaPacket]
    var nextPacketIndex = 0
    var frameSequenceNumber: UInt64
    var timestampNanoseconds: UInt64

    init(
        packets: [UdpMediaPacket],
        frameSequenceNumber: UInt64 = 0,
        timestampNanoseconds: UInt64 = 0
    ) {
        self.packets = packets
        self.frameSequenceNumber = frameSequenceNumber
        self.timestampNanoseconds = timestampNanoseconds
    }

    var isComplete: Bool { nextPacketIndex >= packets.count }

    func nextPackets(limit: Int) -> ArraySlice<UdpMediaPacket> {
        let end = min(packets.count, nextPacketIndex + max(1, limit))
        return packets[nextPacketIndex..<end]
    }
}

@discardableResult
func supersedePendingVideoTransmit(
    with prepared: DirectPeerPreparedVideoTransmit,
    pending: inout DirectPeerPendingVideoTransmit?
) -> Int {
    let droppedFrames = pending == nil ? 0 : 1
    pending = DirectPeerPendingVideoTransmit(
        packets: prepared.packets,
        frameSequenceNumber: prepared.frameSequenceNumber,
        timestampNanoseconds: prepared.timestampNanoseconds
    )
    return droppedFrames
}

struct DirectPeerAVMediaLoopIterationContext {
    var control: DirectPeerSessionControlSocket
    var remoteControl: SessionNetworkEndpoint
    var configuration: DirectPeerSessionAVRunConfiguration
    var timing: DirectPeerAVMediaLoopTiming
}

struct DirectPeerAVVideoTransmitContext {
    var resources: DirectPeerAVMediaLoopResources
    var configuration: DirectPeerSessionAVRunConfiguration
    var timing: DirectPeerAVMediaLoopTiming
    var now: UInt64
}

struct DirectPeerAVMediaLoopState {
    var audioSequence: UInt64 = 1
    var videoSequence: UInt64 = 1
    var nextVideoFrameTimeNanoseconds = DispatchTime.now().uptimeNanoseconds
    var metrics = DirectPeerSessionAVRuntimeMetrics()
    var videoFormat: DirectPeerSessionVideoFormatReport?
    var receiveProof: DirectPeerSessionVideoReceiveProofArtifact?
    var audioRXState: DirectPeerAudioRXLoopState
    var playoutAnchor: DirectPeerAVPlayoutAnchor
    var deferredVideoFrame: DirectPeerPreparedVideoFrame?
    var pendingVideoTransmit: DirectPeerPendingVideoTransmit?
    var remoteVideoHostTimeMapper: DirectPeerRemoteVideoHostTimeMapper?
    var nextMetricsPublishTimeNanoseconds = DispatchTime.now().uptimeNanoseconds

    init(
        configuration: DirectPeerSessionAVRunConfiguration,
        timing: DirectPeerAVMediaLoopTiming
    ) throws {
        videoFormat = configuration.mediaSourceMode == .syntheticFixture
            ? syntheticAVVideoFormatReport(for: configuration)
            : nil
        audioRXState = DirectPeerAudioRXLoopState(
            rtpValidator: AES67ST2110L24RTPReceiveValidator(
                packetTime: try directPeerAES67PacketTime(for: configuration)
            ),
            aes67ClockMapper: DirectPeerAES67RTPHostTimeMapper(sampleRateHertz: configuration.sampleRateHertz),
            rawAudioReassembly: DirectPeerOpenLolaRawAudioReassemblyState()
        )
        let bufferPolicy = try DirectPeerSessionAVBufferPolicy.resolve(
            avProfile: configuration.avProfile,
            rxBufferProfile: configuration.rxBufferProfile,
            framesPerPacket: configuration.framesPerPacket,
            sampleRateHertz: configuration.sampleRateHertz
        )
        playoutAnchor = DirectPeerAVPlayoutAnchor(policy: directPeerAVSyncPolicy(
            configuration: configuration,
            bufferPolicy: bufferPolicy,
            videoFrameIntervalNanoseconds: timing.videoFrameIntervalNanoseconds
        ))
        remoteVideoHostTimeMapper = configuration.audioTransport == .aes67ST2110L24
            ? DirectPeerRemoteVideoHostTimeMapper()
            : nil
    }
}

private func directPeerAES67PacketTime(
    for configuration: DirectPeerSessionAVRunConfiguration
) throws -> AES67ST2110L24PacketTime {
    guard configuration.audioTransport == .aes67ST2110L24 else {
        return AES67ST2110L24Profile.packetTime
    }
    guard let packetTime = AES67ST2110L24Profile.packetTime(
        forFramesPerPacket: configuration.framesPerPacket
    ) else {
        throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape(
            "unsupported aes67-st2110-l24 packet time"
        )
    }
    return packetTime
}

func makeDirectPeerAVMediaLoopResources(
    _ configuration: DirectPeerSessionAVRunConfiguration
) throws -> DirectPeerAVMediaLoopResources {
    let usesOpus = configuration.audioTransport == .openLolaOpusCeltLowDelay
    let opusDecoder = usesOpus ? try OpusCELTLowDelayDecoder(channelCount: configuration.manual.audioChannelCount) : nil
    return DirectPeerAVMediaLoopResources(
        audioGraph: try DirectPeerRealtimeAudioGraph(configuration: try audioGraphConfiguration(for: configuration)),
        opusEncoder: usesOpus ? try OpusCELTLowDelayEncoder(channelCount: configuration.manual.audioChannelCount) : nil,
        opusDecoder: opusDecoder,
        opusScratch: opusDecoder.map { DirectPeerOpusSessionScratch(decodedByteCount: $0.outputPCMByteCount) },
        rtpSSRC: directPeerAES67SSRC(peerID: configuration.manual.localPeerID),
        liveVideoSource: DirectPeerAVFoundationRawFrameSource(configuration: configuration),
        videoPreparationWorker: DirectPeerVideoPreparationWorker(),
        videoDecodeWorker: configuration.mediaSourceMode == .production
            ? DirectPeerVideoDecodeWorker()
            : nil,
        previewSink: configuration.preview == .on ? makeDirectPeerPreviewSink(for: configuration) : nil,
        videoReassembler: try directPeerVideoReassembler(for: configuration)
    )
}

func startDirectPeerAVMediaLoopProductionResources(
    resources: DirectPeerAVMediaLoopResources,
    lifecycle: inout DirectPeerAVMediaLoopLifecycle,
    configuration: DirectPeerSessionAVRunConfiguration
) throws {
    guard configuration.mediaSourceMode == .production else {
        return
    }
    let inventory = try CoreAudioInventoryReader().capture()
    let preflight = try DirectPeerRealtimeAudioGraph.preflight(
        configuration: resources.audioGraph.configuration,
        inventory: inventory
    )
    guard let inputDeviceID = preflight.device?.id else {
        throw DirectPeerAudioGraphError.missingDeviceUID(configuration.audioDeviceUID)
    }
    guard let outputDeviceID = preflight.outputDevice?.id else {
        throw DirectPeerAudioGraphError.missingDeviceUID(configuration.outputDeviceUID)
    }
    try resources.audioGraph.start(
        inputDeviceID: CoreAudio.AudioObjectID(inputDeviceID),
        outputDeviceID: CoreAudio.AudioObjectID(outputDeviceID)
    )
    lifecycle.audioGraphStarted = true
    try resources.liveVideoSource.start()
    lifecycle.liveVideoSourceStarted = true
}

func stopDirectPeerAVMediaLoopResources(
    _ resources: DirectPeerAVMediaLoopResources,
    lifecycle: DirectPeerAVMediaLoopLifecycle
) {
    if lifecycle.audioGraphStarted {
        let cleanupResult = resources.audioGraph.stop()
        if !cleanupResult.succeeded {
            os_log(
                .error,
                "Direct peer AV audio graph cleanup failures: %{public}@",
                directPeerRealtimeAudioCleanupFailureSummary(cleanupResult)
            )
        }
    }
    if lifecycle.liveVideoSourceStarted {
        resources.liveVideoSource.stop()
    }
    resources.videoPreparationWorker.cancel()
    resources.videoDecodeWorker?.cancel()
    resources.previewSink?.close()
}

func captureSyntheticAVAudioIfNeeded(
    resources: DirectPeerAVMediaLoopResources,
    state: inout DirectPeerAVMediaLoopState,
    configuration: DirectPeerSessionAVRunConfiguration,
    now: UInt64
) throws {
    guard configuration.mediaSourceMode == .syntheticFixture else {
        return
    }
    _ = resources.audioGraph.captureInjectedPayload(
        syntheticAudioPayload(configuration: configuration, sequenceNumber: state.audioSequence),
        hostTimeNanoseconds: now
    )
    state.audioSequence = try nextDirectPeerMediaSequence(after: state.audioSequence)
    state.playoutAnchor.observeAudio(hostTimeNanoseconds: now)
}

func drainDirectPeerAVAudio(
    runner: inout PeerSessionRunner,
    resources: DirectPeerAVMediaLoopResources,
    state: inout DirectPeerAVMediaLoopState,
    configuration: DirectPeerSessionAVRunConfiguration,
    timing: DirectPeerAVMediaLoopTiming
) throws {
    resources.audioGraph.consumeCapturedReadiness()
    let audioTX = try runAudioTXLoop(
        runner: &runner,
        audioGraph: resources.audioGraph,
        configuration: DirectPeerAudioTXLoopConfiguration(
            transport: configuration.audioTransport,
            opusEncoder: resources.opusEncoder,
            opusScratch: resources.opusScratch,
            rtpSSRC: resources.rtpSSRC,
            maxPackets: timing.audioTransmitDrainPacketLimit,
            preferLatestPayload: configuration.avProfile == .fastest
                && configuration.rxBufferProfile == .direct
        )
    )
    state.metrics.audioPayloadsSent += audioTX.payloadsSent
    state.metrics.audioPayloadsDroppedBeforeSend += audioTX.payloadsDroppedBeforeSend
    if audioTX.budgetExhausted {
        state.metrics.audioTXBudgetExhaustions += 1
    }
    try drainDirectPeerAVReceivedAudio(
runner: &runner,
resources: resources,
state: &state,
configuration: configuration
)
}

private func drainDirectPeerAVReceivedAudio(
    runner: inout PeerSessionRunner,
    resources: DirectPeerAVMediaLoopResources,
    state: inout DirectPeerAVMediaLoopState,
    configuration: DirectPeerSessionAVRunConfiguration
) throws {
    let audioRX = try runAudioRXLoop(
        runner: &runner,
        audioGraph: resources.audioGraph,
        state: &state.audioRXState,
        configuration: DirectPeerAudioRXLoopConfiguration(
            transport: configuration.audioTransport,
            opusDecoder: resources.opusDecoder,
            opusScratch: resources.opusScratch,
            maxPackets: configuration.avProfile == .fastest && configuration.rxBufferProfile == .direct
                ? directPeerFastestAudioReceiveDrainPacketLimit
                : 32,
            preferNewestPayload: configuration.avProfile == .fastest && configuration.rxBufferProfile == .direct
        )
    )
    accumulateAudioRXDrainMetrics(audioRX, into: &state.metrics)
    if let latestAudioHostTimeNanoseconds = audioRX.latestHostTimeNanoseconds {
        state.playoutAnchor.observeAudio(hostTimeNanoseconds: latestAudioHostTimeNanoseconds)
    }
    state.metrics.audioReceiveDrainIterations += 1
}

func drainDirectPeerAVVideo(
    runner: inout PeerSessionRunner,
    resources: inout DirectPeerAVMediaLoopResources,
    state: inout DirectPeerAVMediaLoopState,
    configuration: DirectPeerSessionAVRunConfiguration,
    timing: DirectPeerAVMediaLoopTiming
) throws {
    let videoRX = try runVideoRXLoop(
        runner: &runner,
        reassembler: &resources.videoReassembler,
        deferredFrame: &state.deferredVideoFrame,
        configuration: DirectPeerVideoRXLoopConfiguration(
            previewSink: resources.previewSink,
            playoutAnchor: state.playoutAnchor,
            compression: configuration.videoCompression,
            maxPackets: timing.videoReceiveDrainPacketLimit,
            decodeWorker: resources.videoDecodeWorker,
            remoteHostTimeMapper: state.remoteVideoHostTimeMapper
        )
    )
    accumulateDirectPeerAVVideoRXMetrics(videoRX, into: &state.metrics)
    if let previewSink = resources.previewSink {
        // The persisted legacy field is a rendered-frame count, not an enqueue
        // acknowledgement. AppKit records it only after its main-actor render.
        state.metrics.previewFramesSubmitted = max(
            state.metrics.previewFramesSubmitted,
            previewSink.renderedFrameCount
        )
    }
    mergeDirectPeerAVVideoProof(
        videoRX,
        renderedPreviewFrameCount: state.metrics.previewFramesSubmitted,
        into: &state.receiveProof
    )
}

private func accumulateDirectPeerAVVideoRXMetrics(
    _ videoRX: DirectPeerVideoRXDrainResult,
    into metrics: inout DirectPeerSessionAVRuntimeMetrics
) {
    metrics.videoFragmentsReceived += videoRX.fragmentsReceived
    metrics.videoFragmentsDroppedCorrupt += videoRX.fragmentsDroppedCorrupt
    metrics.videoFragmentsDroppedOversize += videoRX.fragmentsDroppedOversize
    metrics.videoUnexpectedPayloadTypes += videoRX.unexpectedPayloadTypes
    metrics.videoFramesReassembled += videoRX.framesReassembled
    metrics.videoFramesDroppedDuringReassembly += videoRX.framesDroppedDuringReassembly
    metrics.videoReassemblyMissingFragments += videoRX.reassemblyMissingFragments
    metrics.videoReassemblyLateFragments += videoRX.reassemblyLateFragments
    metrics.videoReassemblyDuplicateFragments += videoRX.reassemblyDuplicateFragments
    metrics.previewFramesDropped += videoRX.previewFramesDropped
    metrics.previewFramesFailed += videoRX.previewFramesFailed
    metrics.videoFramesDroppedOutsideAudioWindow += videoRX.framesDroppedOutsideAudioWindow
    metrics.videoFramesAlignedForSync += videoRX.framesAlignedForSync
    metrics.videoFramesDeferredForSync += videoRX.framesDeferredForSync
    metrics.videoFramesDroppedForSync += videoRX.framesDroppedForSync
    metrics.videoFramesReplacedDuringSyncDefer += videoRX.framesReplacedDuringSyncDefer
    metrics.videoReceiveDrainIterations += 1
}

private func mergeDirectPeerAVVideoProof(
    _ videoRX: DirectPeerVideoRXDrainResult,
    renderedPreviewFrameCount: Int,
    into receiveProof: inout DirectPeerSessionVideoReceiveProofArtifact?
) {
    guard let first = videoRX.firstFrameProof, let latest = videoRX.latestFrameProof else {
        return
    }
    if var proof = receiveProof {
        proof.framesProven += videoRX.framesAcceptedForProof
        proof.previewFramesSubmitted = renderedPreviewFrameCount
        proof.latestFrame = latest
        receiveProof = proof
    } else {
        receiveProof = DirectPeerSessionVideoReceiveProofArtifact(
            framesProven: videoRX.framesAcceptedForProof,
            previewFramesSubmitted: renderedPreviewFrameCount,
            firstFrame: first,
            latestFrame: latest
        )
    }
}

func serviceDirectPeerAVMetrics(
    runner: inout PeerSessionRunner,
    state: inout DirectPeerAVMediaLoopState,
    now: UInt64
) {
    let metricsService = serviceDirectPeerAVMetrics(
        runner: &runner,
        nextMetricsPublishTimeNanoseconds: &state.nextMetricsPublishTimeNanoseconds,
        nowNanoseconds: now
    )
    state.metrics.metricsMessagesPublished += metricsService.metricsMessagesPublished
    state.metrics.metricsMessagesPublishFailures += metricsService.metricsMessagesPublishFailures
    state.metrics.peerMetricsMessagesReceived += metricsService.peerMetricsMessagesReceived
    state.metrics.peerMetricsMessagesDropped += metricsService.peerMetricsMessagesDropped
}
