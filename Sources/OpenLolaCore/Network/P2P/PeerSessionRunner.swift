import Darwin
import Foundation

public struct PeerSessionIPv4BindingRequest: Sendable {
    public var peerID: String
    public var remotePeerID: String
    public var localHost: String
    public var controlEndpoint: SessionNetworkEndpoint
    public var audioPort: UInt16
    public var videoPort: UInt16
    public var metricsPort: UInt16
    public var audioChannelCount = 2
    public var dscp: Int?
}

public struct PeerSessionAVProposalRequest: Sendable {
    public var sampleRateHertz = 48_000
    public var framesPerPacket = 32
    public var sampleFormat: UdpPcmSampleFormat = .float32LittleEndian
    public var audioTransport: DirectPeerSessionAudioTransport?
    public var audioCompression: DirectPeerSessionAudioCompression = .raw
    public var audioChannelCount: Int?
    public var videoStreamID = 100
    public var videoWidth = 1_920
    public var videoHeight = 1_080
    public var videoPixelFormat = "bgra8"
    public var videoCompression: DirectPeerSessionVideoCompression = .raw
    public var videoFrameRate = 30
    public var avProfile: DirectPeerSessionAVProfile = .balanced
    public var rxBufferProfile: RxBufferProfile?

    public init() {}
}

public struct PeerSessionRunner: Sendable {
    public let localCapabilities: CapabilitySet
    public let remotePeerID: String
    public private(set) var localEndpoints: SessionPeerMediaEndpoints
    public private(set) var state: PeerSessionLifecycleState = .idle
    public private(set) var acceptedConfiguration: SessionConfiguration?
    public private(set) var remoteCapabilities: CapabilitySet?
    public private(set) var remoteAudioMetadata: RmeMatrixMetadataSnapshot?
    public internal(set) var metrics = DirectPeerSessionMetrics()
    public private(set) var controlTranscript: [SessionControlMessage] = []
    private static let maxControlTranscriptEntries = 1_000

    var audioTransport: UdpMediaTransport?
    var videoTransport: UdpMediaTransport?
    var metricsTransport: UdpMediaTransport?
    var audioRouter: DirectAudioMediaRouter?
    private var controlStateMachine = SessionStateMachine()
    private var lastSentProposal: SessionProposal?
    private var peerMediaStarted = false
    private var audioMetadataControlState = RmeMatrixMetadataControlState(
        minUpdateIntervalNanoseconds: 1_000_000_000
    )

    private init(
        localCapabilities: CapabilitySet,
        remotePeerID: String,
        localEndpoints: SessionPeerMediaEndpoints,
        audioTransport: UdpMediaTransport,
        videoTransport: UdpMediaTransport,
        metricsTransport: UdpMediaTransport
    ) {
        self.localCapabilities = localCapabilities
        self.remotePeerID = remotePeerID
        self.localEndpoints = localEndpoints
        self.audioTransport = audioTransport
        self.videoTransport = videoTransport
        self.metricsTransport = metricsTransport
    }
}

extension PeerSessionRunner {
    public static func localhost(
        peerID: String,
        remotePeerID: String,
        audioChannelCount: Int = 2,
        controlEndpoint: SessionNetworkEndpoint? = nil
    ) throws -> PeerSessionRunner {
        var audioTransport: UdpMediaTransport?
        var videoTransport: UdpMediaTransport?
        var metricsTransport: UdpMediaTransport?
        var shouldCloseTransports = true
        defer {
            if shouldCloseTransports {
                audioTransport?.close()
                videoTransport?.close()
                metricsTransport?.close()
            }
        }
        audioTransport = try UdpMediaTransport.bindLoopback()
        videoTransport = try UdpMediaTransport.bindLoopback()
        metricsTransport = try UdpMediaTransport.bindLoopback()
        let audio = try Self.requirePeerSessionTransport(audioTransport, "audio")
        let video = try Self.requirePeerSessionTransport(videoTransport, "video")
        let metrics = try Self.requirePeerSessionTransport(metricsTransport, "metrics")
        let controlEndpoint = try controlEndpoint ?? allocatedControlEndpoint()
        var capabilities = OpenLolaCLI.localCapabilitySet()
        capabilities.peer = PeerIdentity(
            peerID: peerID,
            displayName: "Localhost \(peerID)",
            implementationName: "open-lola",
            implementationVersion: OpenLolaCLI.implementationVersion
        )
        capabilities.audio.channelSet = .defaultInput(count: audioChannelCount)
        let endpoints = SessionPeerMediaEndpoints(
            peerID: peerID,
            controlEndpoint: controlEndpoint,
            audioEndpoint: audio.localEndpoint,
            videoEndpoint: video.localEndpoint,
            metricsEndpoint: metrics.localEndpoint
        )
        let runner = PeerSessionRunner(
            localCapabilities: capabilities,
            remotePeerID: remotePeerID,
            localEndpoints: endpoints,
            audioTransport: audio,
            videoTransport: video,
            metricsTransport: metrics
        )
        shouldCloseTransports = false
        return runner
    }

    public static func boundIPv4(
        _ request: PeerSessionIPv4BindingRequest
    ) throws -> PeerSessionRunner {
        var transports = PeerSessionIPv4Transports()
        var shouldCloseTransports = true
        defer {
            if shouldCloseTransports {
                transports.close()
            }
        }
        try transports.bind(request)
        let runner = try PeerSessionRunner(
            localCapabilities: makeIPv4Capabilities(request),
            remotePeerID: request.remotePeerID,
            localEndpoints: makeIPv4Endpoints(request, transports: transports),
            audioTransport: transports.requireAudio(),
            videoTransport: transports.requireVideo(),
            metricsTransport: transports.requireMetrics()
        )
        shouldCloseTransports = false
        return runner
    }
}

private extension PeerSessionRunner {
    static func makeIPv4Capabilities(
        _ request: PeerSessionIPv4BindingRequest
    ) -> CapabilitySet {
        var capabilities = OpenLolaCLI.localCapabilitySet()
        capabilities.peer = PeerIdentity(
            peerID: request.peerID,
            displayName: "Peer \(request.peerID)",
            implementationName: "open-lola",
            implementationVersion: OpenLolaCLI.implementationVersion
        )
        capabilities.audio.channelSet = .defaultInput(count: request.audioChannelCount)
        return capabilities
    }

    static func makeIPv4Endpoints(
        _ request: PeerSessionIPv4BindingRequest,
        transports: PeerSessionIPv4Transports
    ) throws -> SessionPeerMediaEndpoints {
        SessionPeerMediaEndpoints(
            peerID: request.peerID,
            controlEndpoint: request.controlEndpoint,
            audioEndpoint: try transports.requireAudio().localEndpoint,
            videoEndpoint: try transports.requireVideo().localEndpoint,
            metricsEndpoint: try transports.requireMetrics().localEndpoint
        )
    }
}

private struct PeerSessionIPv4Transports {
    var audioTransport: UdpMediaTransport?
    var videoTransport: UdpMediaTransport?
    var metricsTransport: UdpMediaTransport?

    mutating func bind(_ request: PeerSessionIPv4BindingRequest) throws {
        var audioTransport: UdpMediaTransport?
        var videoTransport: UdpMediaTransport?
        var metricsTransport: UdpMediaTransport?
        defer {
            if self.audioTransport == nil {
                audioTransport?.close()
                videoTransport?.close()
                metricsTransport?.close()
            }
        }
        audioTransport = try UdpMediaTransport.bindIPv4(
            host: request.localHost,
            port: request.audioPort,
            dscp: request.dscp
        )
        videoTransport = try UdpMediaTransport.bindIPv4(
            host: request.localHost,
            port: request.videoPort,
            dscp: request.dscp
        )
        metricsTransport = try UdpMediaTransport.bindIPv4(
            host: request.localHost,
            port: request.metricsPort,
            dscp: request.dscp
        )
        self.audioTransport = audioTransport
        self.videoTransport = videoTransport
        self.metricsTransport = metricsTransport
    }

    func close() {
        audioTransport?.close()
        videoTransport?.close()
        metricsTransport?.close()
    }

    func requireAudio() throws -> UdpMediaTransport {
        try PeerSessionRunner.requirePeerSessionTransport(audioTransport, "audio")
    }

    func requireVideo() throws -> UdpMediaTransport {
        try PeerSessionRunner.requirePeerSessionTransport(videoTransport, "video")
    }

    func requireMetrics() throws -> UdpMediaTransport {
        try PeerSessionRunner.requirePeerSessionTransport(metricsTransport, "metrics")
    }
}

extension PeerSessionRunner {
    public mutating func beginHandshake() throws -> [SessionControlMessage] {
        state = .handshaking
        let messages: [SessionControlMessage] = [
            .hello(
                peer: localCapabilities.peer,
                supportedControlVersions: [SessionControlProtocol.currentVersion]
            ),
            .capabilities(localCapabilities)
        ]
        recordSent(messages)
        return messages
    }

    public mutating func receiveControlMessages(_ messages: [SessionControlMessage]) throws {
        for message in messages {
            try receiveControlMessage(message)
        }
    }

    public mutating func makeSessionProposal() throws -> SessionControlMessage {
        guard let remoteCapabilities else {
            throw PeerSessionRunnerError.missingRemoteCapabilities
        }
        let proposal = SessionProposal(
            sessionID: Self.sessionID(
                kind: "audio",
                localPeerID: localCapabilities.peer.peerID,
                remotePeerID: remoteCapabilities.peer.peerID
            ),
            proposer: localCapabilities.peer,
            responder: remoteCapabilities.peer,
            latencyProfile: .directAudioFirst,
            rxBufferProfile: .direct,
            audioStreams: [makeDefaultAudioStream()],
            videoStreams: [.disabled(id: 100, sourceLabel: "synthetic-video-reserved")],
            controlEndpoint: localEndpoints.controlEndpoint,
            audioEndpoint: localEndpoints.audioEndpoint,
            videoEndpoint: localEndpoints.videoEndpoint,
            metricsEndpoint: localEndpoints.metricsEndpoint,
            mtuBytes: 1_200
        )
        let message = SessionControlMessage.sessionPropose(proposal)
        try applyControlTransition(message)
        recordSent(message)
        return message
    }

    public mutating func makeAudioVideoSessionProposal(
        _ request: PeerSessionAVProposalRequest = PeerSessionAVProposalRequest()
    ) throws -> SessionControlMessage {
        guard let remoteCapabilities else {
            throw PeerSessionRunnerError.missingRemoteCapabilities
        }
        let proposal = try makeAudioVideoProposal(
            remoteCapabilities: remoteCapabilities,
            draft: PeerSessionAVProposalDraft(
                sampleRateHertz: request.sampleRateHertz,
                framesPerPacket: request.framesPerPacket,
                sampleFormat: request.sampleFormat,
                audioTransport: request.audioTransport ?? request.audioCompression.audioTransport,
                audioChannelCount: request.audioChannelCount,
                videoStreamID: request.videoStreamID,
                videoWidth: request.videoWidth,
                videoHeight: request.videoHeight,
                videoPixelFormat: request.videoPixelFormat,
                videoCompression: request.videoCompression,
                videoFrameRate: request.videoFrameRate,
                avProfile: request.avProfile,
                rxBufferProfile: request.rxBufferProfile
            )
        )
        let message = SessionControlMessage.sessionPropose(proposal)
        try applyControlTransition(message)
        recordSent(message)
        return message
    }

    public mutating func acceptProposal(
        _ proposalMessage: SessionControlMessage,
        proposerCapabilities: CapabilitySet
    ) throws -> SessionControlMessage {
        guard let proposal = proposalMessage.proposal else {
            throw PeerSessionRunnerError.unsupportedControlMessage(proposalMessage.type)
        }
        var configuration = try SessionNegotiation.negotiate(
            proposal: proposal,
            proposerCapabilities: proposerCapabilities,
            responderCapabilities: localCapabilities
        )
        configuration.peerMediaEndpoints = [
            SessionPeerMediaEndpoints(
                peerID: proposal.proposer.peerID,
                controlEndpoint: proposal.controlEndpoint,
                audioEndpoint: proposal.audioEndpoint,
                videoEndpoint: proposal.videoEndpoint,
                metricsEndpoint: proposal.metricsEndpoint
            ),
            localEndpoints
        ]
        try applyControlTransition(proposalMessage)
        remoteCapabilities = proposerCapabilities
        acceptedConfiguration = configuration
        peerMediaStarted = false
        state = .configured

        let message = SessionControlMessage.sessionAccept(configuration)
        try applyControlTransition(message)
        recordSent(message)
        return message
    }
}

extension PeerSessionRunner {
    public mutating func startMedia() throws {
        guard let configuration = acceptedConfiguration else {
            throw PeerSessionRunnerError.mediaStartBeforeAcceptedConfiguration
        }
        state = .mediaStarting
        let remote = try remoteEndpoints(in: configuration)
        guard let audioTransport else {
            throw PeerSessionRunnerError.missingAudioTransport
        }
        guard let videoTransport else {
            throw PeerSessionRunnerError.missingVideoTransport
        }
        guard let metricsTransport else {
            throw PeerSessionRunnerError.missingMetricsTransport
        }
        var startedTransports: [UdpMediaTransport] = []
        do {
            try audioTransport.connect(to: remote.audioEndpoint)
            startedTransports.append(audioTransport)
            try videoTransport.connect(to: remote.videoEndpoint)
            startedTransports.append(videoTransport)
            try metricsTransport.connect(to: remote.metricsEndpoint)
            startedTransports.append(metricsTransport)
            audioRouter = try DirectAudioMediaRouter(
                configuration: configuration,
                localAudioCapabilities: localCapabilities.audio
            )
        } catch {
            for transport in startedTransports {
                transport.close()
            }
            peerMediaStarted = false
            state = .failed
            throw error
        }
        metrics.mediaStartBoundaries += 1
        let mediaStart = SessionControlMessage.mediaStart(SessionMediaCommand(
            sessionID: configuration.sessionID,
            hostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
        ))
        try applyControlTransition(mediaStart)
        recordSent(mediaStart)
        if peerMediaStarted {
            state = .running
        }
    }

    public mutating func publishAudioMetadata(
        _ snapshot: RmeMatrixMetadataSnapshot,
        nowNanoseconds: UInt64 = DispatchTime.now().uptimeNanoseconds
    ) throws -> SessionControlMessage? {
        try snapshot.validate()
        switch audioMetadataControlState.record(snapshot, nowNanoseconds: nowNanoseconds) {
        case .accepted:
            let message = SessionControlMessage.audioMetadata(snapshot)
            metrics.audioMetadataMessagesSent += 1
            recordSent(message)
            return message
        case .rateLimited:
            metrics.audioMetadataUpdatesRateLimited += 1
            return nil
        case .staleOrDuplicate:
            metrics.audioMetadataUpdatesStaleOrDuplicate += 1
            return nil
        }
    }

    public mutating func beginRecovery(reason: String) throws {
        guard acceptedConfiguration != nil else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        if state == .running {
            metrics.mediaStopBoundaries += 1
        }
        try resetMediaReceiveContinuity()
        state = .recovering
        recordSent(.mediaPause(SessionMediaCommand(
            sessionID: acceptedConfiguration?.sessionID ?? "unknown",
            hostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
        )))
    }

    public mutating func markMediaSocketFailed(reason: String) throws {
        try beginRecovery(reason: reason)
    }

    public mutating func restartMedia() throws {
        guard state == .recovering else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        metrics.recoveryEvents += 1
        try startMedia()
    }

    public mutating func shutdown(reason: String) {
        metrics.shutdownRequests += 1
        if state == .closed {
            return
        }
        state = .shuttingDown
        closeMediaTransportsForStopBoundary()
        recordSent(.shutdown(SessionShutdown(
            reason: reason,
            sessionID: acceptedConfiguration?.sessionID
        )))
        clearClosedSessionState()
        state = .closed
    }
}

private extension PeerSessionRunner {
    private mutating func receiveControlMessage(_ message: SessionControlMessage) throws {
        if message.type.isInboundUnsupportedForRunner {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        if message.type.isPeerSessionSetupMessage {
            try receiveSessionSetupMessage(message)
        } else {
            try receiveRuntimeMessage(message)
        }
    }

    private mutating func receiveSessionSetupMessage(_ message: SessionControlMessage) throws {
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

    private mutating func receiveRuntimeMessage(_ message: SessionControlMessage) throws {
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

    private mutating func receiveHello(_ message: SessionControlMessage) throws {
        try applyControlTransition(message)
        state = .handshaking
    }

    private mutating func receiveCapabilities(_ message: SessionControlMessage) throws {
        guard let capabilities = message.capabilities else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        try applyControlTransition(message)
        remoteCapabilities = capabilities
    }

    private mutating func receiveSessionAccept(_ message: SessionControlMessage) throws {
        guard let configuration = message.configuration else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        try validateAcceptedConfiguration(configuration)
        try applyControlTransition(message)
        acceptedConfiguration = configuration
        peerMediaStarted = false
        state = .configured
    }

    private mutating func receiveMediaStart(_ message: SessionControlMessage) throws {
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

    private mutating func receiveMediaPause(_ message: SessionControlMessage) throws {
        guard let command = message.mediaCommand,
              acceptsControlSessionID(command.sessionID) else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        try applyControlTransition(message)
        peerMediaStarted = false
        state = .recovering
    }

    private mutating func receiveShutdown(_ message: SessionControlMessage) throws {
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

    private mutating func receiveAudioMetadata(_ message: SessionControlMessage) throws {
        guard let snapshot = message.audioMetadata else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        try snapshot.validate()
        try applyControlTransition(message)
        remoteAudioMetadata = snapshot
        metrics.audioMetadataMessagesReceived += 1
    }

    private mutating func receiveMetrics(_ message: SessionControlMessage) throws {
        guard let remoteMetrics = message.metrics else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        guard acceptsControlSessionID(remoteMetrics.sessionID) else {
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
        try applyControlTransition(message)
        recordRemoteMetrics(remoteMetrics)
    }

    private mutating func receiveError(_ message: SessionControlMessage) throws {
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

private extension PeerSessionRunner {
    private mutating func applyControlTransition(_ message: SessionControlMessage) throws {
        var candidate = controlStateMachine
        try candidate.apply(message)
        controlStateMachine = candidate
    }

    private func acceptsControlSessionID(_ sessionID: String) -> Bool {
        acceptedConfiguration?.sessionID == sessionID
    }

    private func acceptsShutdownSessionID(_ sessionID: String?) -> Bool {
        guard let acceptedSessionID = acceptedConfiguration?.sessionID else {
            return false
        }
        return sessionID == acceptedSessionID
    }

    private func acceptsErrorMessage(_ error: SessionErrorMessage) -> Bool {
        guard let acceptedSessionID = acceptedConfiguration?.sessionID else {
            return false
        }
        return error.sessionID == acceptedSessionID
    }

    private func validateAcceptedConfiguration(_ configuration: SessionConfiguration) throws {
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

    private func lastSentSessionProposal() -> SessionProposal? {
        lastSentProposal
    }

    private func makeAudioVideoProposal(
        remoteCapabilities: CapabilitySet,
        draft: PeerSessionAVProposalDraft
    ) throws -> SessionProposal {
        let bufferPolicy = try makeAudioVideoBufferPolicy(draft)
        return SessionProposal(
            sessionID: Self.sessionID(
                kind: "av",
                localPeerID: localCapabilities.peer.peerID,
                remotePeerID: remoteCapabilities.peer.peerID
            ),
            proposer: localCapabilities.peer,
            responder: remoteCapabilities.peer,
            latencyProfile: bufferPolicy.latencyProfile,
            rxBufferProfile: bufferPolicy.rxBufferProfile,
            audioStreams: [makeAudioVideoAudioStream(draft)],
            videoStreams: [try makeAudioVideoVideoStream(draft)],
            controlEndpoint: localEndpoints.controlEndpoint,
            audioEndpoint: localEndpoints.audioEndpoint,
            videoEndpoint: localEndpoints.videoEndpoint,
            metricsEndpoint: localEndpoints.metricsEndpoint,
            mtuBytes: 1_200
        )
    }

    private func makeAudioVideoBufferPolicy(
        _ draft: PeerSessionAVProposalDraft
    ) throws -> DirectPeerSessionAVBufferPolicy {
        try DirectPeerSessionAVBufferPolicy.resolve(
            avProfile: draft.avProfile,
            rxBufferProfile: draft.rxBufferProfile ?? draft.avProfile.defaultRXBufferProfile,
            framesPerPacket: draft.framesPerPacket,
            sampleRateHertz: draft.sampleRateHertz
        )
    }

    private func makeAudioVideoAudioStream(_ draft: PeerSessionAVProposalDraft) -> AudioStreamDescription {
        makeAudioStream(
            channelCount: audioVideoChannelCount(draft.audioChannelCount),
            sampleRateHertz: draft.sampleRateHertz,
            framesPerPacket: draft.framesPerPacket,
            sampleFormat: draft.sampleFormat,
            payloadType: draft.audioTransport.payloadType
        )
    }

    private func audioVideoChannelCount(_ requestedChannelCount: Int?) -> Int {
        min(
            requestedChannelCount ?? localCapabilities.audio.channelSet.channels.count,
            localCapabilities.audio.channelSet.channels.count
        )
    }

    private func makeAudioVideoVideoStream(
        _ draft: PeerSessionAVProposalDraft
    ) throws -> VideoStreamDescription {
        VideoStreamDescription(
            id: draft.videoStreamID,
            direction: .bidirectional,
            role: .avFoundationDevice,
            resolution: VideoResolution(width: draft.videoWidth, height: draft.videoHeight),
            frameRate: VideoFrameRate(numerator: draft.videoFrameRate, denominator: 1),
            pixelFormat: try videoPixelFormatDescription(draft.videoPixelFormat),
            transportFormat: draft.videoCompression.transportFormat,
            sourceLabel: audioVideoSourceLabel(draft),
            payloadType: draft.videoCompression.payloadType,
            priority: 100,
            captureEnabled: true,
            queueDepth: 2,
            bandwidthBudgetMegabitsPerSecond: 16_000
        )
    }

    private func audioVideoSourceLabel(_ draft: PeerSessionAVProposalDraft) -> String {
        let normalizedPixelFormat = directPeerNormalizedVideoPixelFormat(draft.videoPixelFormat)
        return "avfoundation-\(normalizedPixelFormat)-\(draft.videoCompression.rawValue)"
    }

    private mutating func closeMediaTransportsForStopBoundary() {
        if metrics.mediaStopBoundaries == 0 {
            metrics.mediaStopBoundaries += 1
        }
        audioTransport?.close()
        videoTransport?.close()
        metricsTransport?.close()
    }

    private mutating func clearClosedSessionState() {
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

    private mutating func resetMediaReceiveContinuity() throws {
        let maxByteCount = peerSessionMediaReceiveByteBudget(acceptedConfiguration: acceptedConfiguration)
        try audioTransport?.resetReceiveContinuity(maxByteCount: maxByteCount, drainLimit: 256)
        try videoTransport?.resetReceiveContinuity(maxByteCount: maxByteCount, drainLimit: 256)
        try metricsTransport?.resetReceiveContinuity(maxByteCount: maxByteCount, drainLimit: 256)
        audioRouter = nil
    }

    private mutating func recordSent(_ messages: [SessionControlMessage]) {
        for message in messages {
            recordSent(message)
        }
    }

    private mutating func recordSent(_ message: SessionControlMessage) {
        if let proposal = message.proposal {
            lastSentProposal = proposal
        }
        appendControlTranscript(message)
        metrics.controlMessagesSent += 1
    }

    private mutating func appendControlTranscript(_ message: SessionControlMessage) {
        controlTranscript.append(message)
        let overflowCount = controlTranscript.count - Self.maxControlTranscriptEntries
        if overflowCount > 0 {
            controlTranscript.removeFirst(overflowCount)
        }
    }
}

private struct PeerSessionAVProposalDraft {
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
