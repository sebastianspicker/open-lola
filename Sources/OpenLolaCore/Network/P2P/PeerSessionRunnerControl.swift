// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Dispatch
import Foundation

extension PeerSessionRunner {
    mutating func receiveControlMessage(_ message: SessionControlMessage) throws {
        if message.type.isInboundUnsupportedForRunner {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        if message.type.isPeerSessionSetupMessage {
            try receiveSessionSetupMessage(message)
        } else {
            try receiveRuntimeMessage(message)
        }
    }

    mutating func receiveSessionSetupMessage(_ message: SessionControlMessage) throws {
        switch message.type {
        case .hello:
            try receiveHello(message)
        case .capabilities:
            try receiveCapabilities(message)
        case .sessionAccept:
            try receiveSessionAccept(message)
        default:
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
    }

    mutating func receiveRuntimeMessage(_ message: SessionControlMessage) throws {
        switch message.type {
        case .mediaStart:
            try receiveMediaStart(message)
        case .mediaPause:
            try receiveMediaPause(message)
        case .shutdown:
            try receiveShutdown(message)
        case .audioMetadata:
            try receiveAudioMetadata(message)
        case .metrics:
            try receiveMetrics(message)
        case .error:
            try receiveError(message)
        default:
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
    }

    mutating func receiveHello(_ message: SessionControlMessage) throws {
        try applyControlTransition(message)
        state = .handshaking
    }

    mutating func receiveCapabilities(_ message: SessionControlMessage) throws {
        guard let capabilities = message.capabilities else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        try applyControlTransition(message)
        remoteCapabilities = capabilities
    }

    mutating func receiveSessionAccept(_ message: SessionControlMessage) throws {
        guard let configuration = message.configuration else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        try validateAcceptedConfiguration(configuration)
        try applyControlTransition(message)
        acceptedConfiguration = configuration
        peerMediaStarted = false
        state = .configured
    }

    mutating func receiveMediaStart(_ message: SessionControlMessage) throws {
        guard let command = message.mediaCommand,
              acceptsControlSessionID(command.sessionID) else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        try applyControlTransition(message)
        peerMediaStarted = true
        if state == .mediaStarting {
            state = .running
        }
    }

    mutating func receiveMediaPause(_ message: SessionControlMessage) throws {
        guard let command = message.mediaCommand,
              acceptsControlSessionID(command.sessionID) else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        if state == .running {
            metrics.mediaStopBoundaries += 1
        }
        try applyControlTransition(message)
        peerMediaStarted = false
        state = .recovering
    }

    mutating func receiveShutdown(_ message: SessionControlMessage) throws {
        guard let shutdown = message.shutdown,
              acceptsShutdownSessionID(shutdown.sessionID) else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        try applyControlTransition(message)
        peerMediaStarted = false
        closeMediaTransportsForStopBoundary()
        clearClosedSessionState()
        state = .closed
    }

    mutating func receiveAudioMetadata(_ message: SessionControlMessage) throws {
        guard let snapshot = message.audioMetadata else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        try snapshot.validate()
        try applyControlTransition(message)
        remoteAudioMetadata = snapshot
        metrics.audioMetadataMessagesReceived += 1
    }

    mutating func receiveMetrics(_ message: SessionControlMessage) throws {
        guard let remoteMetrics = message.metrics else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        guard acceptsControlSessionID(remoteMetrics.sessionID) else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        try applyControlTransition(message)
        recordRemoteMetrics(remoteMetrics)
    }

    mutating func receiveError(_ message: SessionControlMessage) throws {
        guard let error = message.error,
              acceptsErrorMessage(error) else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        try applyControlTransition(message)
        if error.fatal {
            peerMediaStarted = false
            closeMediaTransportsForStopBoundary()
        }
        state = .failed
    }
}

extension PeerSessionRunner {
    mutating func applyControlTransition(_ message: SessionControlMessage) throws {
        var candidate = controlStateMachine
        try candidate.apply(message)
        controlStateMachine = candidate
    }

    func acceptsControlSessionID(_ sessionID: String) -> Bool {
        acceptedConfiguration?.sessionID == sessionID
    }

    func acceptsShutdownSessionID(_ sessionID: String?) -> Bool {
        guard let acceptedSessionID = acceptedConfiguration?.sessionID else {
            return false
        }
        return sessionID == acceptedSessionID
    }

    func acceptsErrorMessage(_ error: SessionErrorMessage) -> Bool {
        guard let acceptedSessionID = acceptedConfiguration?.sessionID else {
            return false
        }
        return error.sessionID == acceptedSessionID
    }

    func validateAcceptedConfiguration(_ configuration: SessionConfiguration) throws {
        guard let proposal = lastSentSessionProposal(),
              let remoteCapabilities else {
            throw PeerSessionRunnerError.unsupportedControlMessage(.sessionAccept)
        }
        var expected = try SessionNegotiation.negotiate(
            proposal: proposal,
            proposerCapabilities: localCapabilities,
            responderCapabilities: remoteCapabilities
        )
        expected.peerMediaEndpoints = configuration.peerMediaEndpoints
        guard configuration == expected else {
            throw PeerSessionRunnerError.unsupportedControlMessage(.sessionAccept)
        }
        try configuration.validatePeerMediaTopology()
        guard configuration.peerMediaEndpoints?.contains(localEndpoints) == true else {
            throw PeerSessionRunnerError.missingPeerMediaEndpoint(localCapabilities.peer.peerID)
        }
        guard configuration.peerMediaEndpoints?.contains(where: { $0.peerID == remotePeerID }) == true else {
            throw PeerSessionRunnerError.missingPeerMediaEndpoint(remotePeerID)
        }
    }

    func lastSentSessionProposal() -> SessionProposal? {
        lastSentProposal
    }

    func makeAudioVideoProposal(
        remoteCapabilities: CapabilitySet,
        draft: PeerSessionAVProposalDraft
    ) throws -> SessionProposal {
        let bufferPolicy = try makeAudioVideoBufferPolicy(draft)
        return SessionProposal(
            identity: .init(sessionID: Self.sessionID(
                kind: "av",
                localPeerID: localCapabilities.peer.peerID,
                remotePeerID: remoteCapabilities.peer.peerID
            ), proposer: localCapabilities.peer, responder: remoteCapabilities.peer),
            profile: .init(latencyProfile: bufferPolicy.latencyProfile, rxBufferProfile: bufferPolicy.rxBufferProfile),
            streams: .init(audioStreams: [makeAudioVideoAudioStream(draft)], videoStreams: [try makeAudioVideoVideoStream(draft)]),
            endpoints: .init(control: localEndpoints.controlEndpoint, audio: localEndpoints.audioEndpoint,
                             video: localEndpoints.videoEndpoint, metrics: localEndpoints.metricsEndpoint),
            transport: .init(mtuBytes: 1_200)
        )
    }

    func makeAudioVideoBufferPolicy(
        _ draft: PeerSessionAVProposalDraft
    ) throws -> DirectPeerSessionAVBufferPolicy {
        try DirectPeerSessionAVBufferPolicy.resolve(
            avProfile: draft.avProfile,
            rxBufferProfile: draft.rxBufferProfile ?? draft.avProfile.defaultRXBufferProfile,
            framesPerPacket: draft.framesPerPacket,
            sampleRateHertz: draft.sampleRateHertz
        )
    }

    func makeAudioVideoAudioStream(_ draft: PeerSessionAVProposalDraft) -> AudioStreamDescription {
        makeAudioStream(
            channelCount: audioVideoChannelCount(draft.audioChannelCount),
            sampleRateHertz: draft.sampleRateHertz,
            framesPerPacket: draft.framesPerPacket,
            sampleFormat: draft.sampleFormat,
            payloadType: draft.audioTransport.payloadType
        )
    }

    func audioVideoChannelCount(_ requestedChannelCount: Int?) -> Int {
        min(
            requestedChannelCount ?? localCapabilities.audio.channelSet.channels.count,
            localCapabilities.audio.channelSet.channels.count
        )
    }

    func makeAudioVideoVideoStream(
        _ draft: PeerSessionAVProposalDraft
    ) throws -> VideoStreamDescription {
        VideoStreamDescription(
            identity: .init(
                id: draft.videoStreamID,
                direction: .bidirectional,
                role: .avFoundationDevice,
                sourceLabel: audioVideoSourceLabel(draft),
                payloadType: draft.videoCompression.payloadType
            ),
            format: .init(
                resolution: .init(width: draft.videoWidth, height: draft.videoHeight),
                frameRate: .init(numerator: draft.videoFrameRate, denominator: 1),
                pixelFormat: try videoPixelFormatDescription(draft.videoPixelFormat),
                transportFormat: draft.videoCompression.transportFormat
            ),
            capture: .init(
                queueDepth: draft.avProfile == .fastest ? 1 : 2,
                bandwidthBudgetMegabitsPerSecond: 16_000
            )
        )
    }

    func audioVideoSourceLabel(_ draft: PeerSessionAVProposalDraft) -> String {
        let normalizedPixelFormat = directPeerNormalizedVideoPixelFormat(draft.videoPixelFormat)
        return "avfoundation-\(normalizedPixelFormat)-\(draft.videoCompression.rawValue)"
    }

    mutating func closeMediaTransportsForStopBoundary() {
        if metrics.mediaStopBoundaries == 0 {
            metrics.mediaStopBoundaries += 1
        }
        audioTransport?.close()
        videoTransport?.close()
        metricsTransport?.close()
    }

    mutating func clearClosedSessionState() {
        let shutdownRequests = metrics.shutdownRequests
        let mediaStopBoundaries = metrics.mediaStopBoundaries
        acceptedConfiguration = nil
        remoteCapabilities = nil
        remoteAudioMetadata = nil
        audioRouter = nil
        peerMediaStarted = false
        lastSentProposal = nil
        controlStateMachine = SessionStateMachine()
        audioMetadataControlState = RmeMatrixMetadataControlState(
            minUpdateIntervalNanoseconds: 1_000_000_000
        )
        controlTranscript.removeAll(keepingCapacity: true)
        metrics = DirectPeerSessionMetrics()
        metrics.shutdownRequests = shutdownRequests
        metrics.mediaStopBoundaries = mediaStopBoundaries
    }

    mutating func resetMediaReceiveContinuity() throws {
        let maxByteCount = peerSessionMediaReceiveByteBudget(acceptedConfiguration: acceptedConfiguration)
        try audioTransport?.resetReceiveContinuity(maxByteCount: maxByteCount, drainLimit: 256)
        try videoTransport?.resetReceiveContinuity(maxByteCount: maxByteCount, drainLimit: 256)
        try metricsTransport?.resetReceiveContinuity(maxByteCount: maxByteCount, drainLimit: 256)
        audioRouter = nil
    }

    mutating func recordSent(_ messages: [SessionControlMessage]) {
        for message in messages {
            recordSent(message)
        }
    }

    mutating func recordSent(_ message: SessionControlMessage) {
        if let proposal = message.proposal {
            lastSentProposal = proposal
        }
        appendControlTranscript(message)
        metrics.controlMessagesSent += 1
    }

    mutating func appendControlTranscript(_ message: SessionControlMessage) {
        controlTranscript.append(message)
        let overflowCount = controlTranscript.count - Self.maxControlTranscriptEntries
        if overflowCount > 0 {
            controlTranscript.removeFirst(overflowCount)
        }
    }
}

struct PeerSessionAVProposalDraft {
    let sampleRateHertz: Int
    let framesPerPacket: Int
    let sampleFormat: UdpPcmSampleFormat
    let audioTransport: DirectPeerSessionAudioTransport
    let audioChannelCount: Int?
    let videoStreamID: Int
    let videoWidth: Int
    let videoHeight: Int
    let videoPixelFormat: String
    let videoCompression: DirectPeerSessionVideoCompression
    let videoFrameRate: Int
    let avProfile: DirectPeerSessionAVProfile
    let rxBufferProfile: RxBufferProfile?
}

private extension SessionControlMessageType {
    var isInboundUnsupportedForRunner: Bool {
        self == .sessionPropose || self == .sessionReject
    }

    var isPeerSessionSetupMessage: Bool {
        switch self {
        case .hello, .capabilities, .sessionAccept:
            true
        case .sessionPropose,
             .sessionReject,
             .audioMetadata,
             .mediaStart,
             .mediaPause,
             .metrics,
             .error,
             .shutdown:
            false
        }
    }
}
