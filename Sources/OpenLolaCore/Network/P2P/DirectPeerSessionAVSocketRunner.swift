// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Darwin
import CoreAudio
import Dispatch
import Foundation
import os

// swiftlint:disable:next identifier_name
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
              AES67ST2110L24Profile.packetTime(
                  forFramesPerPacket: configuration.framesPerPacket
              ) != nil,
              configuration.sampleFormat == .float32LittleEndian,
              configuration.manual.audioChannelCount == AES67ST2110L24Profile.channelCount else {
            throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape(
                "aes67-st2110-l24 requires 48000 Hz, 48 or 6 frames, float32, and 2 channels"
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
    return try finishManualAVSession(
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
    try DirectPeerSessionSocketRunner.completeResponderControlHandshake(
        runner: &runner,
        control: control,
        remoteControl: remoteControl
    )
    return try finishManualAVSession(
        runner: &runner,
        control: control,
        remoteControl: remoteControl,
        configuration: configuration
    )
}

private func finishManualAVSession(
    runner: inout PeerSessionRunner,
    control: DirectPeerSessionControlSocket,
    remoteControl: SessionNetworkEndpoint,
    configuration: DirectPeerSessionAVRunConfiguration
) throws -> DirectPeerSessionAVRuntimeResult {
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
    var stopReason: DirectPeerAVControlStopReason?
    while DispatchTime.now().uptimeNanoseconds < timing.deadlineNanoseconds {
        stopReason = try runDirectPeerAVMediaLoopIteration(
            runner: &runner,
            resources: &resources,
            state: &state,
            context: iterationContext
        )
        if stopReason != nil {
            break
        }
    }
    if stopReason != .terminal {
        try DirectPeerSessionSocketRunner.exchangeMediaPauseForStopBoundary(
            runner: &runner,
            control: control,
            remoteControl: remoteControl,
            peerMediaPauseReceived: stopReason == .peerMediaPause
        )
    }
    finishDirectPeerAVMediaLoop(resources: &resources, state: &state)
    return DirectPeerSessionAVRuntimeResult(
        metrics: state.metrics,
        videoFormat: state.videoFormat,
        receiveProof: state.receiveProof
    )
}
