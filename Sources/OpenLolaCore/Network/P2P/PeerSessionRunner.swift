// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Darwin
import Foundation

/// Configures PeerSessionIPv4BindingRequest so callers supply explicit inputs before starting direct peer sessions.
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

/// Configures PeerSessionAVProposalRequest so callers supply explicit inputs before starting direct peer sessions.
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

/// Runs PeerSessionRunner while keeping its stateful execution separate from report validation.
public struct PeerSessionRunner: Sendable {
    public let localCapabilities: CapabilitySet
    public let remotePeerID: String
    public private(set) var localEndpoints: SessionPeerMediaEndpoints
    public internal(set) var state: PeerSessionLifecycleState = .idle
    public internal(set) var acceptedConfiguration: SessionConfiguration?
    public internal(set) var remoteCapabilities: CapabilitySet?
    public internal(set) var remoteAudioMetadata: RmeMatrixMetadataSnapshot?
    public internal(set) var metrics = DirectPeerSessionMetrics()
    public internal(set) var controlTranscript: [SessionControlMessage] = []
    static let maxControlTranscriptEntries = 1_000

    var audioTransport: UdpMediaTransport?
    var videoTransport: UdpMediaTransport?
    var metricsTransport: UdpMediaTransport?
    var audioRouter: DirectAudioMediaRouter?
    var controlStateMachine = SessionStateMachine()
    var lastSentProposal: SessionProposal?
    var peerMediaStarted = false
    var audioMetadataControlState = RmeMatrixMetadataControlState(
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
        audioTransport = try UdpMediaTransport.bindLoopback(bufferProfile: .minimumLatencyAudio)
        videoTransport = try UdpMediaTransport.bindLoopback(bufferProfile: .realtimeVideo)
        metricsTransport = try UdpMediaTransport.bindLoopback(bufferProfile: .realtimeAudio)
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
            identity: .init(sessionID: Self.sessionID(
                kind: "audio",
                localPeerID: localCapabilities.peer.peerID,
                remotePeerID: remoteCapabilities.peer.peerID
            ), proposer: localCapabilities.peer, responder: remoteCapabilities.peer),
            profile: .init(latencyProfile: .directAudioFirst, rxBufferProfile: .direct),
            streams: .init(audioStreams: [makeDefaultAudioStream()],
                           videoStreams: [.disabled(id: 100, sourceLabel: "synthetic-video-reserved")]),
            endpoints: .init(control: localEndpoints.controlEndpoint, audio: localEndpoints.audioEndpoint,
                             video: localEndpoints.videoEndpoint, metrics: localEndpoints.metricsEndpoint),
            transport: .init(mtuBytes: 1_200)
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
