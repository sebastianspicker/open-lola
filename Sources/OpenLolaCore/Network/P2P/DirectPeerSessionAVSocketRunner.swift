import Darwin
import CoreAudio
import Dispatch
import Foundation

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

        var runner = try PeerSessionRunner.boundIPv4(
            peerID: configuration.manual.localPeerID,
            remotePeerID: configuration.manual.remotePeerID,
            localHost: configuration.manual.localHost,
            controlEndpoint: control.endpoint,
            audioPort: configuration.manual.audioPort,
            videoPort: configuration.manual.videoPort,
            metricsPort: configuration.manual.metricsPort,
            audioChannelCount: configuration.manual.audioChannelCount,
            dscp: configuration.manual.dscp
        )
        defer { try? runner.shutdown(reason: "manual-address audio-video run complete") }
        onReady?()

        let remoteControl = SessionNetworkEndpoint(
            host: configuration.manual.remoteHost,
            port: configuration.manual.remoteControlPort
        )
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

private func validateAVConfiguration(_ configuration: DirectPeerSessionAVRunConfiguration) throws {
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
    try configuration.manual.validateManualNetworkShape()
    guard !configuration.audioDeviceUID.isEmpty else {
        throw DirectPeerSessionAVRuntimeError.missingAudioDeviceUID
    }
    guard !configuration.videoDeviceID.isEmpty else {
        throw DirectPeerSessionSocketRunnerError.missingExpectedControlMessage("--video-device-id")
    }
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
        try runner.makeAudioVideoSessionProposal(
            sampleRateHertz: configuration.sampleRateHertz,
            framesPerPacket: configuration.framesPerPacket,
            sampleFormat: configuration.sampleFormat,
            audioTransport: configuration.audioTransport,
            audioChannelCount: configuration.manual.audioChannelCount,
            videoStreamID: configuration.videoStreamID,
        videoWidth: configuration.videoWidth,
        videoHeight: configuration.videoHeight,
        videoPixelFormat: configuration.videoPixelFormat,
        videoCompression: configuration.videoCompression,
        videoFrameRate: configuration.videoFrameRate,
            avProfile: configuration.avProfile,
            rxBufferProfile: configuration.rxBufferProfile
        ),
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
    let audioGraph = try DirectPeerRealtimeAudioGraph(configuration: try audioGraphConfiguration(for: configuration))
    let opusEncoder = configuration.audioTransport == .openLolaOpusCeltLowDelay
        ? try OpusCELTLowDelayEncoder(channelCount: configuration.manual.audioChannelCount)
        : nil
    let opusDecoder = configuration.audioTransport == .openLolaOpusCeltLowDelay
        ? try OpusCELTLowDelayDecoder(channelCount: configuration.manual.audioChannelCount)
        : nil
    let rtpSSRC = directPeerAES67SSRC(peerID: configuration.manual.localPeerID)
    let liveVideoSource = DirectPeerAVFoundationRawFrameSource(configuration: configuration)
    var previewSink: RawBGRAPreviewSink?
    var videoReassembler = try directPeerVideoReassembler(for: configuration)
    if configuration.preview == .on {
        previewSink = makeDirectPeerPreviewSink(for: configuration)
    }
    var audioGraphStarted = false
    var liveVideoSourceStarted = false
    defer {
        if audioGraphStarted {
            audioGraph.stop()
        }
        if liveVideoSourceStarted {
            liveVideoSource.stop()
        }
        previewSink?.close()
    }
    if configuration.mediaSourceMode == .production {
        let inventory = try CoreAudioInventoryReader().capture()
        let preflight = try DirectPeerRealtimeAudioGraph.preflight(
            configuration: audioGraph.configuration,
            inventory: inventory
        )
        guard let inputDeviceID = preflight.device?.id else {
            throw DirectPeerAudioGraphError.missingDeviceUID(configuration.audioDeviceUID)
        }
        guard let outputDeviceID = preflight.outputDevice?.id else {
            throw DirectPeerAudioGraphError.missingDeviceUID(configuration.outputDeviceUID)
        }
        try audioGraph.start(
            inputDeviceID: CoreAudio.AudioObjectID(inputDeviceID),
            outputDeviceID: CoreAudio.AudioObjectID(outputDeviceID)
        )
        audioGraphStarted = true
        try liveVideoSource.start()
        liveVideoSourceStarted = true
    }
    let deadline = try directPeerAVRunDeadlineNanoseconds(
        now: DispatchTime.now().uptimeNanoseconds,
        durationSeconds: configuration.durationSeconds
    )
    let videoFrameIntervalNanoseconds = UInt64(max(1, 1_000_000_000 / configuration.videoFrameRate))
    // Poll twice per audio packet period so control/video receive work is not
    // forced to wait for a full packet duration when audio is idle.
    let audioPollsPerPacketPeriod = 2
    let audioPollIntervalMicroseconds = max(
        250,
        configuration.framesPerPacket * 1_000_000 / configuration.sampleRateHertz / audioPollsPerPacketPeriod
    )
    var audioSequence: UInt64 = 1
    var videoSequence: UInt64 = 1
    var nextVideoFrameTime = DispatchTime.now().uptimeNanoseconds
    var metrics = DirectPeerSessionAVRuntimeMetrics()
    var videoFormat = configuration.mediaSourceMode == .syntheticFixture
        ? syntheticAVVideoFormatReport(for: configuration)
        : nil
    var receiveProof: DirectPeerSessionVideoReceiveProofArtifact?
    var rtpValidator = AES67ST2110L24RTPReceiveValidator()
    var aes67ClockMapper = DirectPeerAES67RTPHostTimeMapper(sampleRateHertz: configuration.sampleRateHertz)
    let bufferPolicy = try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: configuration.avProfile,
        rxBufferProfile: configuration.rxBufferProfile,
        framesPerPacket: configuration.framesPerPacket,
        sampleRateHertz: configuration.sampleRateHertz
    )
    let avSyncPolicy = directPeerAVSyncPolicy(
        configuration: configuration,
        bufferPolicy: bufferPolicy,
        videoFrameIntervalNanoseconds: videoFrameIntervalNanoseconds
    )
    var playoutAnchor = DirectPeerAVPlayoutAnchor(
        policy: avSyncPolicy
    )
    var rawAudioReassembly = DirectPeerOpenLolaRawAudioReassemblyState()
    var deferredVideoFrame: RawCapturedVideoFrame?
    var nextMetricsPublishTimeNanoseconds = DispatchTime.now().uptimeNanoseconds
    // Bound one nonblocking video-drain pass so a fragment burst cannot starve
    // audio polling; 2048 fragments still covers multiple jumbo raw frames.
    let videoReceiveDrainPacketLimit = 2_048
    if configuration.mediaSourceMode == .production {
        videoFormat = liveVideoSource.videoFormat
    }
    while DispatchTime.now().uptimeNanoseconds < deadline {
        let now = DispatchTime.now().uptimeNanoseconds
        let controlService = try serviceDirectPeerAVControl(
            runner: &runner,
            control: control,
            remoteControl: remoteControl
        )
        if controlService.shouldStop {
            break
        }
        if configuration.mediaSourceMode == .syntheticFixture {
            _ = audioGraph.captureInjectedPayload(
                syntheticAudioPayload(configuration: configuration, sequenceNumber: audioSequence),
                hostTimeNanoseconds: now
            )
            audioSequence = try nextDirectPeerMediaSequence(after: audioSequence)
            playoutAnchor.observeAudio(hostTimeNanoseconds: now)
        }
        metrics.audioPayloadsSent += try runAudioTXLoop(
            runner: &runner,
            audioGraph: audioGraph,
            transport: configuration.audioTransport,
            opusEncoder: opusEncoder,
            rtpSSRC: rtpSSRC
        )
        let audioRX = try runAudioRXLoop(
            runner: &runner,
            audioGraph: audioGraph,
            transport: configuration.audioTransport,
            opusDecoder: opusDecoder,
            rtpValidator: &rtpValidator,
            aes67ClockMapper: &aes67ClockMapper,
            rawAudioReassembly: &rawAudioReassembly,
            maxPackets: 32
        )
        metrics.audioPayloadsQueuedForPlayout += audioRX.queuedForPlayout
        metrics.audioPayloadsDroppedBeforePlayout += audioRX.droppedBeforePlayout
        metrics.audioPayloadsDroppedBeforePlayout += audioRX.droppedByPlayoutQueue
        metrics.audioPayloadsDroppedByPlayoutQueue += audioRX.droppedByPlayoutQueue
        if let latestAudioHostTimeNanoseconds = audioRX.latestHostTimeNanoseconds {
            playoutAnchor.observeAudio(hostTimeNanoseconds: latestAudioHostTimeNanoseconds)
        }
        metrics.audioReceiveDrainIterations += 1
        let videoRX = try runVideoRXLoop(
            runner: &runner,
            reassembler: &videoReassembler,
            previewSink: previewSink,
            playoutAnchor: playoutAnchor,
            deferredFrame: &deferredVideoFrame,
            compression: configuration.videoCompression,
            maxPackets: videoReceiveDrainPacketLimit
        )
        metrics.videoFragmentsReceived += videoRX.fragmentsReceived
        metrics.videoFragmentsDroppedCorrupt += videoRX.fragmentsDroppedCorrupt
        metrics.videoFragmentsDroppedOversize += videoRX.fragmentsDroppedOversize
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
        if let first = videoRX.firstFrameProof, let latest = videoRX.latestFrameProof {
            let acceptedFrames = videoRX.framesAcceptedForProof
            if var proof = receiveProof {
                proof.framesProven += acceptedFrames
                proof.previewFramesSubmitted += videoRX.previewFramesSubmitted
                proof.latestFrame = latest
                receiveProof = proof
            } else {
                receiveProof = DirectPeerSessionVideoReceiveProofArtifact(
                    framesProven: acceptedFrames,
                    previewFramesSubmitted: videoRX.previewFramesSubmitted,
                    firstFrame: first,
                    latestFrame: latest
                )
            }
        }
        let metricsService = serviceDirectPeerAVMetrics(
            runner: &runner,
            nextMetricsPublishTimeNanoseconds: &nextMetricsPublishTimeNanoseconds,
            nowNanoseconds: now
        )
        metrics.metricsMessagesPublished += metricsService.metricsMessagesPublished
        metrics.metricsMessagesPublishFailures += metricsService.metricsMessagesPublishFailures
        metrics.peerMetricsMessagesReceived += metricsService.peerMetricsMessagesReceived
        metrics.peerMetricsMessagesDropped += metricsService.peerMetricsMessagesDropped

        if now >= nextVideoFrameTime {
            if let rawFrame = try nextAVRawFrame(
                source: liveVideoSource,
                configuration: configuration,
                sequenceNumber: videoSequence,
                timestampNanoseconds: now
            ) {
                metrics.videoFramesCaptured += 1
                let frameToSend = try videoTransportFrame(rawFrame, compression: configuration.videoCompression)
                metrics.videoFragmentsSent += try runner.sendRawVideoFrame(
                    frameToSend,
                    payloadType: configuration.videoCompression.payloadType
                )
                metrics.videoFramesSent += 1
                videoSequence = try nextDirectPeerVideoSequence(after: videoSequence)
                nextVideoFrameTime = now &+ videoFrameIntervalNanoseconds
            } else {
                metrics.cameraWarmupWaits += 1
            }
        }
        let waitTimeoutMicroseconds = directPeerAVLoopWaitTimeoutMicroseconds(
            nowNanoseconds: DispatchTime.now().uptimeNanoseconds,
            deadlineNanoseconds: deadline,
            audioPollIntervalMicroseconds: UInt64(audioPollIntervalMicroseconds),
            nextVideoFrameTimeNanoseconds: nextVideoFrameTime,
            nextMetricsPublishTimeNanoseconds: nextMetricsPublishTimeNanoseconds
        )
        _ = try runner.waitForIncomingMedia(timeoutMicroseconds: waitTimeoutMicroseconds)
    }
        metrics.audioPayloadsDroppedBeforePlayout += rawAudioReassembly.flushIncomplete()
        let videoReassemblyBeforeFlush = videoReassembler.metrics
        videoReassembler.flushIncomplete()
        mergeDirectPeerVideoReassemblyMetricDelta(
            directPeerVideoReassemblyMetricDelta(
                before: videoReassemblyBeforeFlush,
                after: videoReassembler.metrics
            ),
            into: &metrics
        )
        let audioCounters = audioGraph.runtimeCounters()
        metrics.audioPayloadsCaptured = audioCounters.capturedInputBlocks
        metrics.audioPayloadsDroppedBeforeSend = audioCounters.droppedInputBlocks
        metrics.audioPayloadsDroppedBeforePlayout += audioCounters.droppedOutputBlocks
        metrics.audioPlayoutUnderruns = audioCounters.outputUnderrunBlocks
        metrics.audioCallbackOverruns = audioCounters.callbackOverrunBlocks
        metrics.audioRXBuffer = audioGraph.rxBufferRuntimeSnapshot()
        return DirectPeerSessionAVRuntimeResult(metrics: metrics, videoFormat: videoFormat, receiveProof: receiveProof)
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
    let metrics = runtime.metrics
    var missing: [String] = []
    if metrics.audioPayloadsSent <= 0 {
        missing.append("audio sent")
    }
    if metrics.audioPayloadsQueuedForPlayout <= 0 {
        missing.append("audio received for playout")
    }
    if metrics.videoFramesSent <= 0 {
        missing.append("video frames sent")
    }
    if metrics.videoFramesReassembled <= 0 {
        missing.append("video frames reassembled")
    }
    if metrics.videoFramesReassembled <= metrics.videoFramesDroppedOutsideAudioWindow {
        missing.append("video frames accepted inside audio window")
    }
    if runtime.receiveProof == nil {
        missing.append("video receive proof")
    }
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
