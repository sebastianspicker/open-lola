// Keeps one direct-peer AV loop turn and its nonblocking video send steps together.
import Dispatch

func runDirectPeerAVMediaLoopIteration(
    runner: inout PeerSessionRunner,
    resources: inout DirectPeerAVMediaLoopResources,
    state: inout DirectPeerAVMediaLoopState,
    context: DirectPeerAVMediaLoopIterationContext
) throws -> DirectPeerAVControlStopReason? {
    let now = DispatchTime.now().uptimeNanoseconds
    let controlService = try serviceDirectPeerAVControl(
        runner: &runner, control: context.control, remoteControl: context.remoteControl
    )
    guard controlService.stopReason == nil else { return controlService.stopReason }
    try serviceDirectPeerAVMedia(runner: &runner, resources: &resources, state: &state, context: context, now: now)
    try waitForNextDirectPeerAVLoop(
        runner: &runner,
        request: DirectPeerAVLoopWaitRequest(
            audioGraph: resources.audioGraph,
            liveVideoSource: resources.liveVideoSource,
            videoPreparationWorker: resources.videoPreparationWorker,
            videoDecodeWorker: resources.videoDecodeWorker,
            useCaptureReadiness: context.configuration.mediaSourceMode == .production,
            state: state,
            timing: context.timing
        )
    )
    return nil
}

private func serviceDirectPeerAVMedia(
    runner: inout PeerSessionRunner,
    resources: inout DirectPeerAVMediaLoopResources,
    state: inout DirectPeerAVMediaLoopState,
    context: DirectPeerAVMediaLoopIterationContext,
    now: UInt64
) throws {
    try captureSyntheticAVAudioIfNeeded(resources: resources, state: &state, configuration: context.configuration, now: now)
    try drainDirectPeerAVAudio(runner: &runner, resources: resources, state: &state, configuration: context.configuration, timing: context.timing)
    try drainDirectPeerAVVideo(runner: &runner, resources: &resources, state: &state, configuration: context.configuration, timing: context.timing)
    serviceDirectPeerAVMetrics(runner: &runner, state: &state, now: now)
    try transmitDirectPeerAVVideoIfDue(
        runner: &runner,
        state: &state,
        context: DirectPeerAVVideoTransmitContext(resources: resources, configuration: context.configuration, timing: context.timing, now: now)
    )
}

private func transmitDirectPeerAVVideoIfDue(
    runner: inout PeerSessionRunner,
    state: inout DirectPeerAVMediaLoopState,
    context: DirectPeerAVVideoTransmitContext
) throws {
    try collectPreparedDirectPeerAVVideo(state: &state, context: context)
    try scheduleDirectPeerAVVideoIfDue(runner: &runner, state: &state, context: context)
    try transmitPendingDirectPeerAVVideo(runner: &runner, state: &state, context: context)
}

private func collectPreparedDirectPeerAVVideo(
    state: inout DirectPeerAVMediaLoopState,
    context: DirectPeerAVVideoTransmitContext
) throws {
    state.metrics.videoFramesDroppedBeforeSend += context.resources.videoPreparationWorker.takeDroppedFrameCount()
    guard let prepared = try context.resources.videoPreparationWorker.takeCompletedTransmit() else { return }
    state.metrics.videoFramesDroppedBeforeSend += supersedePendingVideoTransmit(with: prepared, pending: &state.pendingVideoTransmit)
}

private func scheduleDirectPeerAVVideoIfDue(
    runner: inout PeerSessionRunner,
    state: inout DirectPeerAVMediaLoopState,
    context: DirectPeerAVVideoTransmitContext
) throws {
    let frameIsDue = context.configuration.mediaSourceMode == .production || context.now >= state.nextVideoFrameTimeNanoseconds
    guard frameIsDue else { return }
    guard let rawFrame = try nextAVRawFrame(
        source: context.resources.liveVideoSource, configuration: context.configuration,
        sequenceNumber: state.videoSequence, timestampNanoseconds: context.now
    ) else {
        state.metrics.cameraWarmupWaits += 1
        return
    }
    state.metrics.videoFramesCaptured += 1
    context.resources.videoPreparationWorker.submitLatest(DirectPeerVideoPreparationRequest(
        frame: rawFrame, compression: context.configuration.videoCompression,
        maxPacketBytes: try runner.videoPacketByteLimit(), payloadType: context.configuration.videoCompression.payloadType
    ))
    state.videoSequence = try nextDirectPeerVideoSequence(after: state.videoSequence)
    state.nextVideoFrameTimeNanoseconds = context.now &+ context.timing.videoFrameIntervalNanoseconds
}

private func transmitPendingDirectPeerAVVideo(
    runner: inout PeerSessionRunner,
    state: inout DirectPeerAVMediaLoopState,
    context: DirectPeerAVVideoTransmitContext
) throws {
    guard var pending = state.pendingVideoTransmit else { return }
    let limit = directPeerVideoTransmitPacketLimit(
        remainingPacketCount: pending.packets.count - pending.nextPacketIndex,
        nowNanoseconds: context.now, nextFrameNanoseconds: state.nextVideoFrameTimeNanoseconds,
        audioPacketIntervalNanoseconds: context.timing.audioPacketIntervalNanoseconds,
        minimumQuantum: context.timing.videoTransmitPacketLimit
    )
    let sendAttempt = try runner.trySendVideoPackets(pending.nextPackets(limit: limit))
    pending.nextPacketIndex += sendAttempt.packetsSent
    state.metrics.videoFragmentsSent += sendAttempt.packetsSent
    if sendAttempt.wouldBlock {
        state.metrics.videoFramesDroppedBeforeSend += 1
        state.pendingVideoTransmit = nil
    } else if pending.isComplete {
        state.metrics.videoFramesSent += 1
        state.pendingVideoTransmit = nil
    } else {
        state.pendingVideoTransmit = pending
    }
}
