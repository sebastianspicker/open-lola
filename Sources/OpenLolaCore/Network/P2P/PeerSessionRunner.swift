import Darwin
import Foundation

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

    var audioTransport: UdpMediaTransport?
    var videoTransport: UdpMediaTransport?
    var metricsTransport: UdpMediaTransport?
    var audioRouter: DirectAudioMediaRouter?
    private var controlStateMachine = SessionStateMachine()
    private var audioMetadataControlState = RmeMatrixMetadataControlState(
        minUpdateIntervalNanoseconds: 1_000_000_000
    )

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
            implementationVersion: "0.0.0-m06"
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
        peerID: String,
        remotePeerID: String,
        localHost: String,
        controlEndpoint: SessionNetworkEndpoint,
        audioPort: UInt16,
        videoPort: UInt16,
        metricsPort: UInt16,
        audioChannelCount: Int = 2,
        dscp: Int? = nil
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
        audioTransport = try UdpMediaTransport.bindIPv4(host: localHost, port: audioPort, dscp: dscp)
        videoTransport = try UdpMediaTransport.bindIPv4(host: localHost, port: videoPort, dscp: dscp)
        metricsTransport = try UdpMediaTransport.bindIPv4(host: localHost, port: metricsPort, dscp: dscp)
        let audio = try Self.requirePeerSessionTransport(audioTransport, "audio")
        let video = try Self.requirePeerSessionTransport(videoTransport, "video")
        let metrics = try Self.requirePeerSessionTransport(metricsTransport, "metrics")
        var capabilities = OpenLolaCLI.localCapabilitySet()
        capabilities.peer = PeerIdentity(
            peerID: peerID,
            displayName: "Peer \(peerID)",
            implementationName: "open-lola",
            implementationVersion: "0.0.0-m06"
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

    public mutating func beginHandshake() throws -> [SessionControlMessage] {
        state = .handshaking
        let messages: [SessionControlMessage] = [
            .hello(
                peer: localCapabilities.peer,
                supportedControlVersions: [SessionControlProtocol.currentVersion]
            ),
            .capabilities(localCapabilities),
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
        sampleRateHertz: Int = 48_000,
        framesPerPacket: Int = 32,
        sampleFormat: UdpPcmSampleFormat = .float32LittleEndian,
        audioTransport: DirectPeerSessionAudioTransport? = nil,
        audioCompression: DirectPeerSessionAudioCompression = .raw,
        audioChannelCount: Int? = nil,
        videoStreamID: Int = 100,
        videoWidth: Int = 1_920,
        videoHeight: Int = 1_080,
        videoPixelFormat: String = "bgra8",
        videoCompression: DirectPeerSessionVideoCompression = .raw,
        videoFrameRate: Int = 30,
        avProfile: DirectPeerSessionAVProfile = .balanced,
        rxBufferProfile: RxBufferProfile? = nil
    ) throws -> SessionControlMessage {
        guard let remoteCapabilities else {
            throw PeerSessionRunnerError.missingRemoteCapabilities
        }
        let bufferPolicy = try DirectPeerSessionAVBufferPolicy.resolve(
            avProfile: avProfile,
            rxBufferProfile: rxBufferProfile ?? avProfile.defaultRXBufferProfile,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: sampleRateHertz
        )
        let channelCount = min(
            audioChannelCount ?? localCapabilities.audio.channelSet.channels.count,
            localCapabilities.audio.channelSet.channels.count
        )
        let resolvedAudioTransport = audioTransport ?? audioCompression.audioTransport
        let proposal = SessionProposal(
            sessionID: Self.sessionID(
                kind: "av",
                localPeerID: localCapabilities.peer.peerID,
                remotePeerID: remoteCapabilities.peer.peerID
            ),
            proposer: localCapabilities.peer,
            responder: remoteCapabilities.peer,
            latencyProfile: bufferPolicy.latencyProfile,
            rxBufferProfile: bufferPolicy.rxBufferProfile,
            audioStreams: [makeAudioStream(
                channelCount: channelCount,
                sampleRateHertz: sampleRateHertz,
                framesPerPacket: framesPerPacket,
                sampleFormat: sampleFormat,
                payloadType: resolvedAudioTransport.payloadType
            )],
            videoStreams: [VideoStreamDescription(
                id: videoStreamID,
                direction: .bidirectional,
                role: .avFoundationDevice,
                resolution: VideoResolution(width: videoWidth, height: videoHeight),
                frameRate: VideoFrameRate(numerator: videoFrameRate, denominator: 1),
                pixelFormat: try videoPixelFormatDescription(videoPixelFormat),
                transportFormat: videoCompression.transportFormat,
                sourceLabel: "avfoundation-\(directPeerNormalizedVideoPixelFormat(videoPixelFormat))-\(videoCompression.rawValue)",
                payloadType: videoCompression.payloadType,
                priority: 100,
                captureEnabled: true,
                queueDepth: 2,
                bandwidthBudgetMegabitsPerSecond: 16_000
            )],
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
            localEndpoints,
        ]
        try applyControlTransition(proposalMessage)
        remoteCapabilities = proposerCapabilities
        acceptedConfiguration = configuration
        state = .configured

        let message = SessionControlMessage.sessionAccept(configuration)
        try applyControlTransition(message)
        recordSent(message)
        return message
    }

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
        try audioTransport.connect(to: remote.audioEndpoint)
        try videoTransport.connect(to: remote.videoEndpoint)
        try metricsTransport.connect(to: remote.metricsEndpoint)
        audioRouter = try DirectAudioMediaRouter(configuration: configuration)
        metrics.mediaStartBoundaries += 1
        state = .running
        let mediaStart = SessionControlMessage.mediaStart(SessionMediaCommand(
            sessionID: configuration.sessionID,
            hostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
        ))
        try applyControlTransition(mediaStart)
        recordSent(mediaStart)
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

    public mutating func shutdown(reason: String) throws {
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
        state = .closed
    }

    private mutating func receiveControlMessage(_ message: SessionControlMessage) throws {
        switch message.type {
        case .hello:
            try applyControlTransition(message)
            state = .handshaking
        case .capabilities:
            guard let capabilities = message.capabilities else {
                throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
            }
            try applyControlTransition(message)
            remoteCapabilities = capabilities
        case .sessionAccept:
            guard let configuration = message.configuration else {
                throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
            }
            try validateAcceptedConfiguration(configuration)
            try applyControlTransition(message)
            acceptedConfiguration = configuration
            state = .configured
        case .mediaStart:
            guard let command = message.mediaCommand,
                  acceptsControlSessionID(command.sessionID) else {
                throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
            }
            try applyControlTransition(message)
            if state == .configured || state == .mediaStarting {
                state = .running
            }
        case .mediaPause:
            guard let command = message.mediaCommand,
                  acceptsControlSessionID(command.sessionID) else {
                throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
            }
            try applyControlTransition(message)
            state = .recovering
        case .shutdown:
            guard let shutdown = message.shutdown,
                  acceptsShutdownSessionID(shutdown.sessionID) else {
                throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
            }
            try applyControlTransition(message)
            closeMediaTransportsForStopBoundary()
            state = .closed
        case .audioMetadata:
            guard let snapshot = message.audioMetadata else {
                throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
            }
            try snapshot.validate()
            try applyControlTransition(message)
            remoteAudioMetadata = snapshot
            metrics.audioMetadataMessagesReceived += 1
        case .metrics:
            guard let remoteMetrics = message.metrics else {
                throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
            }
            guard acceptsControlSessionID(remoteMetrics.sessionID) else {
                throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
            }
            try applyControlTransition(message)
            recordRemoteMetrics(remoteMetrics)
        case .error:
            guard let error = message.error,
                  acceptsErrorMessage(error) else {
                throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
            }
            try applyControlTransition(message)
            if error.fatal {
                closeMediaTransportsForStopBoundary()
            }
            state = .failed
        case .sessionPropose, .sessionReject:
            throw PeerSessionRunnerError.unsupportedControlMessage(message.type)
        }
    }

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
        controlTranscript.reversed().compactMap(\.proposal).first
    }

    private mutating func closeMediaTransportsForStopBoundary() {
        if metrics.mediaStopBoundaries == 0 {
            metrics.mediaStopBoundaries += 1
        }
        audioTransport?.close()
        videoTransport?.close()
        metricsTransport?.close()
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
        controlTranscript.append(message)
        metrics.controlMessagesSent += 1
    }

}
