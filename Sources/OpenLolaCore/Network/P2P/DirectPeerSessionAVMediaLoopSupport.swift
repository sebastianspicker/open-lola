// Waits on media readiness, aggregates audio and video counters, builds reassemblers, and verifies useful-media movement at loop shutdown.
import Darwin
import CoreAudio
import Dispatch
import Foundation
import os

struct DirectPeerAVLoopWaitRequest {
    let audioGraph: DirectPeerRealtimeAudioGraph
    let liveVideoSource: DirectPeerAVFoundationRawFrameSource
    let videoPreparationWorker: DirectPeerVideoPreparationWorker
    let videoDecodeWorker: DirectPeerVideoDecodeWorker?
    let useCaptureReadiness: Bool
    let state: DirectPeerAVMediaLoopState
    let timing: DirectPeerAVMediaLoopTiming
}

func waitForNextDirectPeerAVLoop(
    runner: inout PeerSessionRunner,
    request: DirectPeerAVLoopWaitRequest
) throws {
    let captureReadinessDescriptor = request.useCaptureReadiness
        ? request.audioGraph.captureReadinessDescriptor
        : nil
    let videoCaptureReadinessDescriptor = request.useCaptureReadiness
        ? request.liveVideoSource.readinessDescriptor
        : nil
    let waitTimeoutMicroseconds = directPeerAVLoopWaitTimeoutMicroseconds(
        nowNanoseconds: DispatchTime.now().uptimeNanoseconds,
        deadlineNanoseconds: request.timing.deadlineNanoseconds,
        audioPollIntervalMicroseconds: captureReadinessDescriptor == nil
            ? request.timing.audioPollIntervalMicroseconds
            : nil,
        nextVideoFrameTimeNanoseconds: videoCaptureReadinessDescriptor == nil
            ? request.state.nextVideoFrameTimeNanoseconds
            : UInt64.max,
        nextMetricsPublishTimeNanoseconds: request.state.nextMetricsPublishTimeNanoseconds
    )
    _ = try runner.waitForIncomingMedia(
        timeoutMicroseconds: waitTimeoutMicroseconds,
        additionalReadDescriptors: [
            captureReadinessDescriptor,
            videoCaptureReadinessDescriptor,
            request.videoPreparationWorker.readinessDescriptor,
            request.videoDecodeWorker?.readinessDescriptor
        ].compactMap { $0 }
    )
}

func finishDirectPeerAVMediaLoop(
    resources: inout DirectPeerAVMediaLoopResources,
    state: inout DirectPeerAVMediaLoopState
) {
    state.metrics.videoFramesDroppedBeforeSend += resources.videoPreparationWorker.cancelAndTakeDroppedFrameCount()
    state.metrics.videoFramesDroppedDuringReassembly += resources.videoDecodeWorker?.cancelAndTakeDroppedFrameCount() ?? 0
    if state.pendingVideoTransmit != nil {
        state.metrics.videoFramesDroppedBeforeSend += 1
        state.pendingVideoTransmit = nil
    }
    dropDeferredVideoFrameAtShutdown(&state.deferredVideoFrame, metrics: &state.metrics)
    state.metrics.audioPayloadsDroppedBeforePlayout += state.audioRXState.rawAudioReassembly.flushIncomplete()
    let videoReassemblyBeforeFlush = resources.videoReassembler.metrics
    resources.videoReassembler.flushIncomplete()
    mergeDirectPeerVideoReassemblyMetricDelta(
        directPeerVideoReassemblyMetricDelta(
            before: videoReassemblyBeforeFlush,
            after: resources.videoReassembler.metrics
        ),
        into: &state.metrics
    )
    accumulateDirectPeerAVAudioGraphRuntimeCounters(resources.audioGraph, into: &state.metrics)
}

private func accumulateDirectPeerAVAudioGraphRuntimeCounters(
    _ audioGraph: DirectPeerRealtimeAudioGraph,
    into metrics: inout DirectPeerSessionAVRuntimeMetrics
) {
    let audioCounters = audioGraph.runtimeCounters()
    metrics.audioPayloadsCaptured = audioCounters.capturedInputBlocks
    metrics.audioPayloadsDroppedBeforeSend += audioCounters.droppedInputBlocks
    metrics.audioPayloadsDroppedBeforePlayout += audioCounters.droppedOutputBlocks
    metrics.audioPlayoutUnderruns = audioCounters.outputUnderrunBlocks
    metrics.audioCallbackMaxMicroseconds = audioCounters.callbackMaxMicroseconds
    metrics.audioCallbackDeadlineMisses = audioCounters.callbackDeadlineMisses
    metrics.audioCallbackOverruns = audioCounters.callbackOverrunBlocks
    metrics.audioHostTimeConversionFailures = audioCounters.hostTimeConversionFailures
    metrics.audioRXBuffer = audioGraph.rxBufferRuntimeSnapshot()
}

func accumulateAudioRXDrainMetrics(
    _ audioRX: DirectPeerAudioRXDrainResult,
    into metrics: inout DirectPeerSessionAVRuntimeMetrics
) {
    metrics.audioPayloadsQueuedForPlayout += audioRX.queuedForPlayout
    metrics.audioPayloadsDroppedBeforePlayout += audioRX.droppedBeforePlayout
    metrics.audioPayloadsDroppedByPlayoutQueue += audioRX.droppedByPlayoutQueue
    metrics.audioUnexpectedPayloadTypes += audioRX.unexpectedPayloadTypes
}

func directPeerVideoReassembler(
for configuration: DirectPeerSessionAVRunConfiguration
) throws -> VideoFrameReassembler {
    let videoPacketBudget = try DirectPeerVideoPacketBudget.validate(configuration)
    return VideoFrameReassembler(maxFragmentsPerFrame: videoPacketBudget.maxFragmentsPerFrame)
}

func directPeerAVLoopWaitTimeoutMicroseconds(
    nowNanoseconds: UInt64,
    deadlineNanoseconds: UInt64,
    audioPollIntervalMicroseconds: UInt64?,
    nextVideoFrameTimeNanoseconds: UInt64,
    nextMetricsPublishTimeNanoseconds: UInt64
) -> UInt64 {
    var earliestDeadline = min(
        deadlineNanoseconds,
        nextVideoFrameTimeNanoseconds,
        nextMetricsPublishTimeNanoseconds
    )
    if let audioPollIntervalMicroseconds {
        let audioPollNanoseconds = audioPollIntervalMicroseconds.multipliedReportingOverflow(by: 1_000)
        let audioDueTime = nowNanoseconds.addingReportingOverflow(
            audioPollNanoseconds.overflow ? UInt64.max : audioPollNanoseconds.partialValue
        )
        earliestDeadline = min(
            earliestDeadline,
            audioDueTime.overflow ? UInt64.max : audioDueTime.partialValue
        )
    }
    guard earliestDeadline > nowNanoseconds else {
        return 1
    }
    return max(1, (earliestDeadline - nowNanoseconds) / 1_000)
}

func makeDirectPeerPreviewSink(for configuration: DirectPeerSessionAVRunConfiguration) -> RawBGRAPreviewSink {
    if configuration.mediaSourceMode == .syntheticFixture
        || ProcessInfo.processInfo.environment["OPEN_LOLA_DISABLE_APPKIT_PREVIEW"] == "1" {
        return RawBGRATestablePreviewSink()
    }
    return RawBGRAAppKitPreviewWindow()
}

func validateUsefulMediaMoved(
    runtime: DirectPeerSessionAVRuntimeResult,
    policy: DirectPeerSessionAVRunQualityPolicy
) throws {
    guard policy == .requireUsefulMedia else {
        return
    }
    let missing = directPeerUsefulMediaMissingReasons(runtime: runtime)
    if !missing.isEmpty {
        throw DirectPeerSessionAVRuntimeError.noUsefulMediaMoved(missing.joined(separator: ", "))
    }
}

func nextDirectPeerVideoSequence(after sequence: UInt64) throws -> UInt64 {
    try nextDirectPeerMediaSequence(after: sequence)
}

func nextDirectPeerMediaSequence(after sequence: UInt64) throws -> UInt64 {
    guard sequence < UInt64.max else {
        throw DirectPeerSessionAVRuntimeError.videoSequenceExhausted
    }
    return sequence + 1
}

func directPeerVideoTransmitPacketLimit(
    remainingPacketCount: Int,
    nowNanoseconds: UInt64,
    nextFrameNanoseconds: UInt64,
    audioPacketIntervalNanoseconds: UInt64,
    minimumQuantum: Int
) -> Int {
    guard remainingPacketCount > 0 else {
        return 0
    }
    // A fragment is not audio-critical work. Yield after every fragment so an
    // audio readiness event or run deadline is serviced before another send.
    _ = nowNanoseconds
    _ = nextFrameNanoseconds
    _ = audioPacketIntervalNanoseconds
    _ = minimumQuantum
    return 1
}

func directPeerAVRunDeadlineNanoseconds(now: UInt64, durationSeconds: Int) throws -> UInt64 {
    guard durationSeconds > 0 else {
        throw DirectPeerSessionSocketRunnerError.invalidTimeoutSeconds(durationSeconds)
    }
    let seconds = UInt64(durationSeconds)
    guard seconds <= UInt64.max / 1_000_000_000 else {
        throw DirectPeerSessionSocketRunnerError.invalidTimeoutSeconds(durationSeconds)
    }
    let durationNanoseconds = seconds * 1_000_000_000
    guard now <= UInt64.max - durationNanoseconds else {
        throw DirectPeerSessionSocketRunnerError.invalidTimeoutSeconds(durationSeconds)
    }
    return now + durationNanoseconds
}

func directPeerAVSyncPolicy(
    configuration: DirectPeerSessionAVRunConfiguration,
    bufferPolicy: DirectPeerSessionAVBufferPolicy,
    videoFrameIntervalNanoseconds: UInt64
) -> AVSyncPolicy {
    var policy = AVSyncPolicy.policy(for: bufferPolicy.latencyProfile)
    guard policy.profile == .directAudioFirst else {
        return policy
    }
    let toleranceFrameIntervals: UInt64 = configuration.mediaSourceMode == .syntheticFixture ? 2 : 1
    let toleranceNanoseconds = videoFrameIntervalNanoseconds.multipliedReportingOverflow(
        by: toleranceFrameIntervals
    )
    let toleranceMicroseconds = Double(toleranceNanoseconds.overflow ? UInt64.max : toleranceNanoseconds.partialValue)
        / 1_000
    policy.videoAlignmentToleranceMicroseconds = toleranceMicroseconds
    policy.earlyVideoDeferThresholdMicroseconds = toleranceMicroseconds
    policy.staleVideoDropThresholdMicroseconds = toleranceMicroseconds
    return policy
}

func audioGraphConfiguration(
    for configuration: DirectPeerSessionAVRunConfiguration
) throws -> DirectPeerRealtimeAudioGraphConfiguration {
    let policy = try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: configuration.avProfile,
        rxBufferProfile: configuration.rxBufferProfile,
        framesPerPacket: configuration.framesPerPacket,
        sampleRateHertz: configuration.sampleRateHertz
    )
    return DirectPeerRealtimeAudioGraphConfiguration(
        devices: .init(
            audioDeviceUID: configuration.audioDeviceUID,
            inputDeviceUID: configuration.inputDeviceUID,
            outputDeviceUID: configuration.outputDeviceUID
        ),
        format: .init(
            sampleRateHertz: configuration.sampleRateHertz,
            framesPerBuffer: configuration.framesPerPacket,
            channelCount: configuration.manual.audioChannelCount,
            sampleFormat: configuration.sampleFormat
        ),
        channelMaps: .init(input: configuration.inputChannels, output: configuration.outputChannels),
        buffering: .init(ringCapacityBlocks: policy.ringCapacityBlocks, rxBufferPolicy: policy.rxBufferPolicy)
    )
}

func syntheticAudioPayload(
    configuration: DirectPeerSessionAVRunConfiguration,
    sequenceNumber: UInt64
) -> Data {
    if configuration.sampleFormat == .float32LittleEndian {
        let sampleCount = configuration.framesPerPacket * configuration.manual.audioChannelCount
        let samples = (0..<sampleCount).map { index in
            Float((Double(index) + Double(sequenceNumber)) / Double(max(1, sampleCount))) * 0.25
        }
        return samples.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }
    let count = configuration.framesPerPacket
        * configuration.manual.audioChannelCount
        * configuration.sampleFormat.bytesPerSample
    return Data(repeating: UInt8((sequenceNumber % 251) + 1), count: count)
}
