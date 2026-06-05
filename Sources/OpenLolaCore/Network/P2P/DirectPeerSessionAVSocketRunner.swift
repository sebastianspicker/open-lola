import Darwin
import CoreAudio
import Dispatch
import Foundation
import os

let directPeerAVMetricsSnapshotIntervalNanoseconds: UInt64 = 100_000_000

public extension DirectPeerSessionSocketRunner {
    static func runManualAddressAudioVideo(
        configuration: DirectPeerSessionAVRunConfiguration
    ) throws -> DirectPeerSessionReport {
        try runManualAddressAudioVideo(configuration: configuration, onReady: nil)
    }

    static func runManualAddressAudioVideo(
        configuration: DirectPeerSessionAVRunConfiguration,
        onReady: (() -> Void)?
    ) throws -> DirectPeerSessionReport {
        try validateAVConfiguration(configuration)
        let control = try DirectPeerSessionControlSocket.bindIPv4(
            host: configuration.manual.localHost,
            port: configuration.manual.controlPort,
            receiveTimeoutSeconds: configuration.manual.timeoutSeconds
        )
        defer { control.close() }

        var runner = try makeManualAVPeerSessionRunner(configuration: configuration, control: control)
        defer { runner.shutdown(reason: "manual-address audio-video run complete") }
        onReady?()

        let remoteControl = manualAVRemoteControlEndpoint(configuration)
        let avRuntime: DirectPeerSessionAVRuntimeResult
        switch configuration.manual.role {
        case .initiator:
            avRuntime = try runManualAVInitiator(
                runner: &runner,
                control: control,
                remoteControl: remoteControl,
                configuration: configuration
            )
        case .responder:
            avRuntime = try runManualAVResponder(
                runner: &runner,
                control: control,
                remoteControl: remoteControl,
                configuration: configuration
            )
        }
        try validateUsefulMediaMoved(runtime: avRuntime, policy: configuration.qualityPolicy)

        return try buildAVReport(
            configuration: configuration,
            runner: runner,
            control: control,
            runtime: avRuntime
        )
    }
}

func validateAVConfiguration(_ configuration: DirectPeerSessionAVRunConfiguration) throws {
    try validateAVTimingAndBufferPolicy(configuration)
    try configuration.manual.validateManualNetworkShape()
    try validateAVDeviceIdentifiers(configuration)
    try validateAVVideoConfiguration(configuration)
    try validateAVAudioTransportConfiguration(configuration)
    try validateProductionAVPreflight(configuration)
}

private func validateAVTimingAndBufferPolicy(_ configuration: DirectPeerSessionAVRunConfiguration) throws {
    _ = try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: configuration.avProfile,
        rxBufferProfile: configuration.rxBufferProfile,
        framesPerPacket: configuration.framesPerPacket,
        sampleRateHertz: configuration.sampleRateHertz
    )
    _ = try DirectPeerVideoPacketBudget.validate(configuration)
    guard configuration.durationSeconds > 0 else {
        throw DirectPeerSessionSocketRunnerError.invalidTimeoutSeconds(configuration.durationSeconds)
    }
    guard UInt64(configuration.durationSeconds) <= UInt64.max / 1_000_000_000 else {
        throw DirectPeerSessionSocketRunnerError.invalidTimeoutSeconds(configuration.durationSeconds)
    }
}

private func validateAVDeviceIdentifiers(_ configuration: DirectPeerSessionAVRunConfiguration) throws {
    guard !configuration.audioDeviceUID.isEmpty, !configuration.inputDeviceUID.isEmpty else {
        throw DirectPeerSessionAVRuntimeError.missingAudioDeviceUID
    }
    guard !configuration.outputDeviceUID.isEmpty else {
        throw DirectPeerSessionAVRuntimeError.missingOutputDeviceUID
    }
    guard !configuration.videoDeviceID.isEmpty else {
        throw DirectPeerSessionSocketRunnerError.missingExpectedControlMessage("--video-device-id")
    }
}

private func validateAVVideoConfiguration(_ configuration: DirectPeerSessionAVRunConfiguration) throws {
    guard configuration.videoWidth > 0 else {
        throw DirectPeerSessionAVRuntimeError.avFoundationCaptureStartFailed("invalid video width")
    }
    guard configuration.videoHeight > 0 else {
        throw DirectPeerSessionAVRuntimeError.avFoundationCaptureStartFailed("invalid video height")
    }
    guard directPeerNormalizedVideoPixelFormat(configuration.videoPixelFormat) == "bgra8" else {
        throw DirectPeerSessionAVRuntimeError.avFoundationCaptureStartFailed("unsupported video pixel format")
    }
    guard configuration.videoFrameRate > 0 else {
        throw DirectPeerSessionAVRuntimeError.invalidVideoFrameRate(configuration.videoFrameRate)
    }
}

private func validateAVAudioTransportConfiguration(_ configuration: DirectPeerSessionAVRunConfiguration) throws {
    switch configuration.audioTransport {
    case .openLolaRaw:
        break
    case .openLolaOpusCeltLowDelay:
        do {
            try OpusCELTLowDelayCodecValidation.validate(
                sampleRateHertz: configuration.sampleRateHertz,
                frameCount: configuration.framesPerPacket,
                sampleFormat: configuration.sampleFormat,
                channelCount: configuration.manual.audioChannelCount
            )
        } catch {
            throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape("\(error)")
        }
    case .aes67ST2110L24:
        guard configuration.sampleRateHertz == AES67ST2110L24Profile.clockRateHertz,
              configuration.framesPerPacket == AES67ST2110L24Profile.framesPerPacket,
              configuration.sampleFormat == .float32LittleEndian,
              configuration.manual.audioChannelCount == AES67ST2110L24Profile.channelCount else {
            throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape(
                "aes67-st2110-l24 requires 48000 Hz, 48 frames, float32, and 2 channels"
            )
        }
    }
}

private func validateProductionAVPreflight(_ configuration: DirectPeerSessionAVRunConfiguration) throws {
    if configuration.mediaSourceMode == .production {
        let inventory = try CoreAudioInventoryReader().capture()
        let graphConfiguration = try audioGraphConfiguration(for: configuration)
        let preflight = try DirectPeerRealtimeAudioGraph.preflight(
            configuration: graphConfiguration,
            inventory: inventory
        )
        if configuration.avProfile == .fastest, !preflight.canStart {
            throw DirectPeerAudioGraphError.unsupportedFrameSize(
                uid: configuration.audioDeviceUID,
                framesPerBuffer: configuration.framesPerPacket
            )
        }
    }
}

private func validateAcceptedVideoStream(
    configuration: DirectPeerSessionAVRunConfiguration,
    accepted: SessionConfiguration?
) throws {
    guard let stream = accepted?.videoStreams.first(where: { $0.id == configuration.videoStreamID }) else {
        throw DirectPeerSessionAVRuntimeError.acceptedVideoStreamMismatch("missing video stream")
    }
    let pixelFormat = directPeerNormalizedVideoPixelFormat(configuration.videoPixelFormat)
    guard stream.resolution.width == configuration.videoWidth else {
        throw DirectPeerSessionAVRuntimeError.acceptedVideoStreamMismatch("video width")
    }
    guard stream.resolution.height == configuration.videoHeight else {
        throw DirectPeerSessionAVRuntimeError.acceptedVideoStreamMismatch("video height")
    }
    guard acceptedVideoFrameRateMatchesConfiguration(stream, configuration: configuration) else {
        throw DirectPeerSessionAVRuntimeError.acceptedVideoStreamMismatch("video frame rate")
    }
    guard stream.pixelFormat.rawValue == pixelFormat else {
        throw DirectPeerSessionAVRuntimeError.acceptedVideoStreamMismatch("video pixel format")
    }
    guard stream.transportFormat == configuration.videoCompression.transportFormat,
          stream.payloadType == configuration.videoCompression.payloadType else {
        throw DirectPeerSessionAVRuntimeError.acceptedVideoStreamMismatch("video compression")
    }
}

private func validateAcceptedAudioStream(
    configuration: DirectPeerSessionAVRunConfiguration,
    accepted: SessionConfiguration?
) throws {
    guard let stream = accepted?.audioStreams.first(where: { $0.id == 1 }) else {
        throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape("missing accepted audio stream")
    }
    guard stream.payloadType == configuration.audioTransport.payloadType else {
        throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape("accepted audio transport")
    }
}

private func acceptedVideoFrameRateMatchesConfiguration(
    _ stream: VideoStreamDescription,
    configuration: DirectPeerSessionAVRunConfiguration
) -> Bool {
    stream.frameRate.denominator > 0 &&
        stream.frameRate.numerator == configuration.videoFrameRate * stream.frameRate.denominator
}

private func makeManualAVPeerSessionRunner(
    configuration: DirectPeerSessionAVRunConfiguration,
    control: DirectPeerSessionControlSocket
) throws -> PeerSessionRunner {
    try PeerSessionRunner.boundIPv4(PeerSessionIPv4BindingRequest(
        peerID: configuration.manual.localPeerID,
        remotePeerID: configuration.manual.remotePeerID,
        localHost: configuration.manual.localHost,
        controlEndpoint: control.endpoint,
        audioPort: configuration.manual.audioPort,
        videoPort: configuration.manual.videoPort,
        metricsPort: configuration.manual.metricsPort,
        audioChannelCount: configuration.manual.audioChannelCount,
        dscp: configuration.manual.dscp
    ))
}

private func manualAVRemoteControlEndpoint(
    _ configuration: DirectPeerSessionAVRunConfiguration
) -> SessionNetworkEndpoint {
    SessionNetworkEndpoint(
        host: configuration.manual.remoteHost,
        port: configuration.manual.remoteControlPort
    )
}

private func runManualAVInitiator(
    runner: inout PeerSessionRunner,
    control: DirectPeerSessionControlSocket,
    remoteControl: SessionNetworkEndpoint,
    configuration: DirectPeerSessionAVRunConfiguration
) throws -> DirectPeerSessionAVRuntimeResult {
    try DirectPeerSessionSocketRunner.send(try runner.beginHandshake(), from: control, to: remoteControl)
    try runner.receiveControlMessages(try control.receiveMessages(
        count: 2,
        label: "responder handshake",
        expectedSource: remoteControl
    ))
    try control.send(
        try makeManualAVSessionProposal(runner: &runner, configuration: configuration),
        to: remoteControl
    )
    try runner.receiveControlMessages([try control.receiveMessage(
        label: "session accept",
        expectedSource: remoteControl
    )])
    try validateAcceptedAudioStream(configuration: configuration, accepted: runner.acceptedConfiguration)
    try validateAcceptedVideoStream(configuration: configuration, accepted: runner.acceptedConfiguration)
    try DirectPeerSessionSocketRunner.publishAndExchangeAudioMetadata(
        runner: &runner,
        control: control,
        remoteControl: remoteControl
    )
    try DirectPeerSessionSocketRunner.startAndExchangeMediaStart(
        runner: &runner,
        control: control,
        remoteControl: remoteControl
    )
    return try runAVMediaLoops(
        runner: &runner,
        control: control,
        remoteControl: remoteControl,
        configuration: configuration
    )
}

private func makeManualAVSessionProposal(
    runner: inout PeerSessionRunner,
    configuration: DirectPeerSessionAVRunConfiguration
) throws -> SessionControlMessage {
    var request = PeerSessionAVProposalRequest()
    request.sampleRateHertz = configuration.sampleRateHertz
    request.framesPerPacket = configuration.framesPerPacket
    request.sampleFormat = configuration.sampleFormat
    request.audioTransport = configuration.audioTransport
    request.audioChannelCount = configuration.manual.audioChannelCount
    request.videoStreamID = configuration.videoStreamID
    request.videoWidth = configuration.videoWidth
    request.videoHeight = configuration.videoHeight
    request.videoPixelFormat = configuration.videoPixelFormat
    request.videoCompression = configuration.videoCompression
    request.videoFrameRate = configuration.videoFrameRate
    request.avProfile = configuration.avProfile
    request.rxBufferProfile = configuration.rxBufferProfile
    return try runner.makeAudioVideoSessionProposal(request)
}

private func runManualAVResponder(
    runner: inout PeerSessionRunner,
    control: DirectPeerSessionControlSocket,
    remoteControl: SessionNetworkEndpoint,
    configuration: DirectPeerSessionAVRunConfiguration
) throws -> DirectPeerSessionAVRuntimeResult {
    try runner.receiveControlMessages(try control.receiveMessages(
        count: 2,
        label: "initiator handshake",
        expectedSource: remoteControl
    ))
    try DirectPeerSessionSocketRunner.send(try runner.beginHandshake(), from: control, to: remoteControl)
    let proposal = try control.receiveMessage(
        label: "session proposal",
        expectedSource: remoteControl
    )
    guard let proposerCapabilities = runner.remoteCapabilities else {
        throw DirectPeerSessionSocketRunnerError.missingRemoteCapabilities
    }
    try control.send(
        try runner.acceptProposal(proposal, proposerCapabilities: proposerCapabilities),
        to: remoteControl
    )
    try validateAcceptedAudioStream(configuration: configuration, accepted: runner.acceptedConfiguration)
    try validateAcceptedVideoStream(configuration: configuration, accepted: runner.acceptedConfiguration)
    try DirectPeerSessionSocketRunner.publishAndExchangeAudioMetadata(
        runner: &runner,
        control: control,
        remoteControl: remoteControl
    )
    try DirectPeerSessionSocketRunner.startAndExchangeMediaStart(
        runner: &runner,
        control: control,
        remoteControl: remoteControl
    )
    return try runAVMediaLoops(
        runner: &runner,
        control: control,
        remoteControl: remoteControl,
        configuration: configuration
    )
}

private func runAVMediaLoops(
    runner: inout PeerSessionRunner,
    control: DirectPeerSessionControlSocket,
    remoteControl: SessionNetworkEndpoint,
    configuration: DirectPeerSessionAVRunConfiguration
) throws -> DirectPeerSessionAVRuntimeResult {
    var resources = try makeDirectPeerAVMediaLoopResources(configuration)
    var lifecycle = DirectPeerAVMediaLoopLifecycle()
    defer { stopDirectPeerAVMediaLoopResources(resources, lifecycle: lifecycle) }

    try startDirectPeerAVMediaLoopProductionResources(
        resources: resources,
        lifecycle: &lifecycle,
        configuration: configuration
    )
    let timing = try DirectPeerAVMediaLoopTiming(configuration: configuration)
    var state = try DirectPeerAVMediaLoopState(configuration: configuration, timing: timing)
    if configuration.mediaSourceMode == .production {
        state.videoFormat = resources.liveVideoSource.videoFormat
    }

    let iterationContext = DirectPeerAVMediaLoopIterationContext(
        control: control,
        remoteControl: remoteControl,
        configuration: configuration,
        timing: timing
    )
    while DispatchTime.now().uptimeNanoseconds < timing.deadlineNanoseconds {
        let shouldStop = try runDirectPeerAVMediaLoopIteration(
            runner: &runner,
            resources: &resources,
            state: &state,
            context: iterationContext
        )
        if shouldStop {
            break
        }
    }
    finishDirectPeerAVMediaLoop(resources: &resources, state: &state)
    return DirectPeerSessionAVRuntimeResult(
        metrics: state.metrics,
        videoFormat: state.videoFormat,
        receiveProof: state.receiveProof
    )
}

private struct DirectPeerAVMediaLoopResources {
    var audioGraph: DirectPeerRealtimeAudioGraph
    var opusEncoder: OpusCELTLowDelayEncoder?
    var opusDecoder: OpusCELTLowDelayDecoder?
    var rtpSSRC: UInt32
    var liveVideoSource: DirectPeerAVFoundationRawFrameSource
    var previewSink: RawBGRAPreviewSink?
    var videoReassembler: VideoFrameReassembler
}

private struct DirectPeerAVMediaLoopLifecycle {
    var audioGraphStarted = false
    var liveVideoSourceStarted = false
}

private struct DirectPeerAVMediaLoopTiming {
    var deadlineNanoseconds: UInt64
    var videoFrameIntervalNanoseconds: UInt64
    var audioPollIntervalMicroseconds: UInt64
    var videoReceiveDrainPacketLimit = 2_048
    var audioTransmitDrainPacketLimit = 32

    init(configuration: DirectPeerSessionAVRunConfiguration) throws {
        deadlineNanoseconds = try directPeerAVRunDeadlineNanoseconds(
            now: DispatchTime.now().uptimeNanoseconds,
            durationSeconds: configuration.durationSeconds
        )
        videoFrameIntervalNanoseconds = UInt64(max(1, 1_000_000_000 / configuration.videoFrameRate))
        // Poll twice per audio packet period so control/video receive work is
        // not forced to wait for a full packet duration when audio is idle.
        let audioPollsPerPacketPeriod = 2
        audioPollIntervalMicroseconds = UInt64(max(
            250,
            configuration.framesPerPacket * 1_000_000 / configuration.sampleRateHertz / audioPollsPerPacketPeriod
        ))
    }
}

private struct DirectPeerAVMediaLoopIterationContext {
    var control: DirectPeerSessionControlSocket
    var remoteControl: SessionNetworkEndpoint
    var configuration: DirectPeerSessionAVRunConfiguration
    var timing: DirectPeerAVMediaLoopTiming
}

private struct DirectPeerAVVideoTransmitContext {
    var resources: DirectPeerAVMediaLoopResources
    var configuration: DirectPeerSessionAVRunConfiguration
    var timing: DirectPeerAVMediaLoopTiming
    var now: UInt64
}

private struct DirectPeerAVMediaLoopState {
    var audioSequence: UInt64 = 1
    var videoSequence: UInt64 = 1
    var nextVideoFrameTimeNanoseconds = DispatchTime.now().uptimeNanoseconds
    var metrics = DirectPeerSessionAVRuntimeMetrics()
    var videoFormat: DirectPeerSessionVideoFormatReport?
    var receiveProof: DirectPeerSessionVideoReceiveProofArtifact?
    var audioRXState: DirectPeerAudioRXLoopState
    var playoutAnchor: DirectPeerAVPlayoutAnchor
    var deferredVideoFrame: RawCapturedVideoFrame?
    var nextMetricsPublishTimeNanoseconds = DispatchTime.now().uptimeNanoseconds

    init(
        configuration: DirectPeerSessionAVRunConfiguration,
        timing: DirectPeerAVMediaLoopTiming
    ) throws {
        videoFormat = configuration.mediaSourceMode == .syntheticFixture
            ? syntheticAVVideoFormatReport(for: configuration)
            : nil
        audioRXState = DirectPeerAudioRXLoopState(
            rtpValidator: AES67ST2110L24RTPReceiveValidator(),
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
    }
}

private func makeDirectPeerAVMediaLoopResources(
    _ configuration: DirectPeerSessionAVRunConfiguration
) throws -> DirectPeerAVMediaLoopResources {
    let usesOpus = configuration.audioTransport == .openLolaOpusCeltLowDelay
    return DirectPeerAVMediaLoopResources(
        audioGraph: try DirectPeerRealtimeAudioGraph(configuration: try audioGraphConfiguration(for: configuration)),
        opusEncoder: usesOpus ? try OpusCELTLowDelayEncoder(channelCount: configuration.manual.audioChannelCount) : nil,
        opusDecoder: usesOpus ? try OpusCELTLowDelayDecoder(channelCount: configuration.manual.audioChannelCount) : nil,
        rtpSSRC: directPeerAES67SSRC(peerID: configuration.manual.localPeerID),
        liveVideoSource: DirectPeerAVFoundationRawFrameSource(configuration: configuration),
        previewSink: configuration.preview == .on ? makeDirectPeerPreviewSink(for: configuration) : nil,
        videoReassembler: try directPeerVideoReassembler(for: configuration)
    )
}

private func startDirectPeerAVMediaLoopProductionResources(
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

private func stopDirectPeerAVMediaLoopResources(
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
    resources.previewSink?.close()
}

private func runDirectPeerAVMediaLoopIteration(
    runner: inout PeerSessionRunner,
    resources: inout DirectPeerAVMediaLoopResources,
    state: inout DirectPeerAVMediaLoopState,
    context: DirectPeerAVMediaLoopIterationContext
) throws -> Bool {
    let now = DispatchTime.now().uptimeNanoseconds
    let controlService = try serviceDirectPeerAVControl(
        runner: &runner,
        control: context.control,
        remoteControl: context.remoteControl
    )
    if controlService.shouldStop {
        return true
    }
    try captureSyntheticAVAudioIfNeeded(
        resources: resources,
        state: &state,
        configuration: context.configuration,
        now: now
    )
    try drainDirectPeerAVAudio(
        runner: &runner,
        resources: resources,
        state: &state,
        configuration: context.configuration,
        timing: context.timing
    )
    try drainDirectPeerAVVideo(
        runner: &runner,
        resources: &resources,
        state: &state,
        configuration: context.configuration,
        timing: context.timing
    )
    serviceDirectPeerAVMetrics(runner: &runner, state: &state, now: now)
    try transmitDirectPeerAVVideoIfDue(
        runner: &runner,
        state: &state,
        context: DirectPeerAVVideoTransmitContext(
            resources: resources,
            configuration: context.configuration,
            timing: context.timing,
            now: now
        )
    )
    try waitForNextDirectPeerAVLoop(runner: &runner, state: state, timing: context.timing)
    return false
}

private func captureSyntheticAVAudioIfNeeded(
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

private func drainDirectPeerAVAudio(
    runner: inout PeerSessionRunner,
    resources: DirectPeerAVMediaLoopResources,
    state: inout DirectPeerAVMediaLoopState,
    configuration: DirectPeerSessionAVRunConfiguration,
    timing: DirectPeerAVMediaLoopTiming
) throws {
    let audioTX = try runAudioTXLoop(
        runner: &runner,
        audioGraph: resources.audioGraph,
        configuration: DirectPeerAudioTXLoopConfiguration(
            transport: configuration.audioTransport,
            opusEncoder: resources.opusEncoder,
            rtpSSRC: resources.rtpSSRC,
            maxPackets: timing.audioTransmitDrainPacketLimit
        )
    )
    state.metrics.audioPayloadsSent += audioTX.payloadsSent
    if audioTX.budgetExhausted {
        state.metrics.audioTXBudgetExhaustions += 1
    }
    try drainDirectPeerAVReceivedAudio(runner: &runner, resources: resources, state: &state, configuration: configuration)
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
            maxPackets: 32
        )
    )
    accumulateAudioRXDrainMetrics(audioRX, into: &state.metrics)
    if let latestAudioHostTimeNanoseconds = audioRX.latestHostTimeNanoseconds {
        state.playoutAnchor.observeAudio(hostTimeNanoseconds: latestAudioHostTimeNanoseconds)
    }
    state.metrics.audioReceiveDrainIterations += 1
}

private func drainDirectPeerAVVideo(
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
            maxPackets: timing.videoReceiveDrainPacketLimit
        )
    )
    accumulateDirectPeerAVVideoRXMetrics(videoRX, into: &state.metrics)
    mergeDirectPeerAVVideoProof(videoRX, into: &state.receiveProof)
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
    metrics.previewFramesSubmitted += videoRX.previewFramesSubmitted
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
    into receiveProof: inout DirectPeerSessionVideoReceiveProofArtifact?
) {
    guard let first = videoRX.firstFrameProof, let latest = videoRX.latestFrameProof else {
        return
    }
    if var proof = receiveProof {
        proof.framesProven += videoRX.framesAcceptedForProof
        proof.previewFramesSubmitted += videoRX.previewFramesSubmitted
        proof.latestFrame = latest
        receiveProof = proof
    } else {
        receiveProof = DirectPeerSessionVideoReceiveProofArtifact(
            framesProven: videoRX.framesAcceptedForProof,
            previewFramesSubmitted: videoRX.previewFramesSubmitted,
            firstFrame: first,
            latestFrame: latest
        )
    }
}

private func serviceDirectPeerAVMetrics(
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

private func transmitDirectPeerAVVideoIfDue(
    runner: inout PeerSessionRunner,
    state: inout DirectPeerAVMediaLoopState,
    context: DirectPeerAVVideoTransmitContext
) throws {
    guard context.now >= state.nextVideoFrameTimeNanoseconds else {
        return
    }
    guard let rawFrame = try nextAVRawFrame(
        source: context.resources.liveVideoSource,
        configuration: context.configuration,
        sequenceNumber: state.videoSequence,
        timestampNanoseconds: context.now
    ) else {
        state.metrics.cameraWarmupWaits += 1
        return
    }
    state.metrics.videoFramesCaptured += 1
    let frameToSend = try videoTransportFrame(rawFrame, compression: context.configuration.videoCompression)
    state.metrics.videoFragmentsSent += try runner.sendRawVideoFrame(
        frameToSend,
        payloadType: context.configuration.videoCompression.payloadType
    )
    state.metrics.videoFramesSent += 1
    state.videoSequence = try nextDirectPeerVideoSequence(after: state.videoSequence)
    state.nextVideoFrameTimeNanoseconds = context.now &+ context.timing.videoFrameIntervalNanoseconds
}

private func waitForNextDirectPeerAVLoop(
    runner: inout PeerSessionRunner,
    state: DirectPeerAVMediaLoopState,
    timing: DirectPeerAVMediaLoopTiming
) throws {
    let waitTimeoutMicroseconds = directPeerAVLoopWaitTimeoutMicroseconds(
        nowNanoseconds: DispatchTime.now().uptimeNanoseconds,
        deadlineNanoseconds: timing.deadlineNanoseconds,
        audioPollIntervalMicroseconds: timing.audioPollIntervalMicroseconds,
        nextVideoFrameTimeNanoseconds: state.nextVideoFrameTimeNanoseconds,
        nextMetricsPublishTimeNanoseconds: state.nextMetricsPublishTimeNanoseconds
    )
    _ = try runner.waitForIncomingMedia(timeoutMicroseconds: waitTimeoutMicroseconds)
}

private func finishDirectPeerAVMediaLoop(
    resources: inout DirectPeerAVMediaLoopResources,
    state: inout DirectPeerAVMediaLoopState
) {
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
    metrics.audioPayloadsDroppedBeforeSend = audioCounters.droppedInputBlocks
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

func directPeerVideoReassembler(for configuration: DirectPeerSessionAVRunConfiguration) throws -> VideoFrameReassembler {
    let videoPacketBudget = try DirectPeerVideoPacketBudget.validate(configuration)
    return VideoFrameReassembler(maxFragmentsPerFrame: videoPacketBudget.maxFragmentsPerFrame)
}

func directPeerAVLoopWaitTimeoutMicroseconds(
    nowNanoseconds: UInt64,
    deadlineNanoseconds: UInt64,
    audioPollIntervalMicroseconds: UInt64,
    nextVideoFrameTimeNanoseconds: UInt64,
    nextMetricsPublishTimeNanoseconds: UInt64
) -> UInt64 {
    let audioPollNanoseconds = audioPollIntervalMicroseconds.multipliedReportingOverflow(by: 1_000)
    let audioDueTime = nowNanoseconds.addingReportingOverflow(
        audioPollNanoseconds.overflow ? UInt64.max : audioPollNanoseconds.partialValue
    )
    let earliestDeadline = min(
        deadlineNanoseconds,
        audioDueTime.overflow ? UInt64.max : audioDueTime.partialValue,
        nextVideoFrameTimeNanoseconds,
        nextMetricsPublishTimeNanoseconds
    )
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

private func validateUsefulMediaMoved(
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

private func nextDirectPeerMediaSequence(after sequence: UInt64) throws -> UInt64 {
    guard sequence < UInt64.max else {
        throw DirectPeerSessionAVRuntimeError.videoSequenceExhausted
    }
    return sequence + 1
}

private func directPeerAVRunDeadlineNanoseconds(now: UInt64, durationSeconds: Int) throws -> UInt64 {
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
        audioDeviceUID: configuration.audioDeviceUID,
        inputDeviceUID: configuration.inputDeviceUID,
        outputDeviceUID: configuration.outputDeviceUID,
        sampleRateHertz: configuration.sampleRateHertz,
        framesPerBuffer: configuration.framesPerPacket,
        channelCount: configuration.manual.audioChannelCount,
        sampleFormat: configuration.sampleFormat,
        inputChannelMap: configuration.inputChannels,
        outputChannelMap: configuration.outputChannels,
        ringCapacityBlocks: policy.ringCapacityBlocks,
        rxBufferPolicy: policy.rxBufferPolicy
    )
}

private func syntheticAudioPayload(
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
