/// Negotiates a session proposal against local capabilities and returns a validated configuration.
public enum SessionNegotiation {
    public static let defaultReconnectDeadlineMilliseconds = 5_000

    public static func negotiate(
        proposal: SessionProposal,
        proposerCapabilities: CapabilitySet,
        responderCapabilities: CapabilitySet
    ) throws -> SessionConfiguration {
        try validateNegotiation(
            proposal: proposal,
            proposerCapabilities: proposerCapabilities,
            responderCapabilities: responderCapabilities
        )
        return SessionConfiguration(
            identity: .init(sessionID: proposal.sessionID, peers: [proposal.proposer, proposal.responder]),
            profile: .init(latencyProfile: proposal.latencyProfile, rxBufferProfile: proposal.rxBufferProfile),
            streams: .init(audioStreams: proposal.audioStreams, videoStreams: proposal.videoStreams),
            endpoints: .init(control: proposal.controlEndpoint, audio: proposal.audioEndpoint,
                             video: proposal.videoEndpoint, metrics: proposal.metricsEndpoint),
            transport: .init(mtuBytes: proposal.mtuBytes, metricIntervalMilliseconds: 1_000,
                             reconnectDeadlineMilliseconds: proposal.reconnectDeadlineMilliseconds
                                 ?? defaultReconnectDeadlineMilliseconds)
        )
    }

    private static func validateNegotiation(
        proposal: SessionProposal,
        proposerCapabilities: CapabilitySet,
        responderCapabilities: CapabilitySet
    ) throws {
        try proposerCapabilities.validate()
        try responderCapabilities.validate()
        try validatePeerMatch(proposal.proposer, proposerCapabilities.peer)
        try validatePeerMatch(proposal.responder, responderCapabilities.peer)
        try validateProposalShape(proposal)
        try validateLatencyProfile(
            proposal.latencyProfile,
            rxBufferProfile: proposal.rxBufferProfile,
            enabledVideoStreamCount: proposal.videoStreams.filter(\.isEnabled).count,
            proposer: proposerCapabilities,
            responder: responderCapabilities
        )
        try validateMTU(
            proposal.mtuBytes,
            proposer: proposerCapabilities.transport,
            responder: responderCapabilities.transport
        )
        for stream in proposal.audioStreams {
            try validateAudioStream(
                stream,
                proposer: proposerCapabilities.audio,
                responder: responderCapabilities.audio
            )
        }
        try validateVideoStreams(
            proposal.videoStreams,
            proposer: proposerCapabilities.video,
            responder: responderCapabilities.video
        )
    }

    private static func validatePeerMatch(_ expected: PeerIdentity, _ actual: PeerIdentity) throws {
        guard expected.peerID == actual.peerID else {
            throw SessionValidationError.peerMismatch(
                expected: expected.peerID,
                actual: actual.peerID
            )
        }
    }

    private static func validateProposalShape(_ proposal: SessionProposal) throws {
        try SessionValidation.requireNonEmpty(proposal.sessionID, "proposal.sessionID")
        try proposal.proposer.validate(fieldPrefix: "proposal.proposer")
        try proposal.responder.validate(fieldPrefix: "proposal.responder")
        try proposal.controlEndpoint.validate(fieldPrefix: "proposal.controlEndpoint")
        try proposal.audioEndpoint.validate(fieldPrefix: "proposal.audioEndpoint")
        try proposal.videoEndpoint.validate(fieldPrefix: "proposal.videoEndpoint")
        try proposal.metricsEndpoint.validate(fieldPrefix: "proposal.metricsEndpoint")
        try SessionValidation.requirePositive(proposal.mtuBytes, "proposal.mtuBytes")
        if let reconnectDeadlineMilliseconds = proposal.reconnectDeadlineMilliseconds {
            try SessionValidation.requirePositive(
                reconnectDeadlineMilliseconds,
                "proposal.reconnectDeadlineMilliseconds"
            )
        }
        guard !proposal.audioStreams.isEmpty else {
            throw SessionValidationError.emptyField("proposal.audioStreams")
        }
        var streamIDs = Set<Int>()
        for stream in proposal.audioStreams {
            try insertUniqueStreamID(stream.id, into: &streamIDs)
            try stream.validate()
        }
        for stream in proposal.videoStreams {
            try insertUniqueStreamID(stream.id, into: &streamIDs)
            try stream.validate()
        }
    }

    private static func insertUniqueStreamID(_ id: Int, into streamIDs: inout Set<Int>) throws {
        guard id > 0 else {
            throw SessionValidationError.invalidStreamID(id)
        }
        if !streamIDs.insert(id).inserted {
            throw SessionValidationError.duplicateStreamID(id)
        }
    }

    private static func validateLatencyProfile(
        _ profile: SessionLatencyProfile,
        rxBufferProfile: RxBufferProfile,
        enabledVideoStreamCount: Int,
        proposer: CapabilitySet,
        responder: CapabilitySet
    ) throws {
        guard proposer.latencyProfiles.contains(profile),
              responder.latencyProfiles.contains(profile) else {
            throw SessionValidationError.unsupportedLatencyProfile(profile)
        }
        guard proposer.rxBufferProfiles.contains(rxBufferProfile),
              responder.rxBufferProfiles.contains(rxBufferProfile) else {
            throw SessionValidationError.unsupportedRxBufferProfile(rxBufferProfile)
        }
        let policy = SessionLatencyProfilePolicy.policy(for: profile)
        guard policy.allowedRxBufferProfiles.contains(rxBufferProfile) else {
            throw SessionValidationError.unsupportedRxBufferProfile(rxBufferProfile)
        }
        if enabledVideoStreamCount > policy.maximumEnabledVideoStreams {
            if policy.maximumEnabledVideoStreams == 0 {
                throw SessionValidationError.profileDisallowsEnabledVideo(profile)
            }
            throw SessionValidationError.tooManyEnabledVideoStreams(
                requested: enabledVideoStreamCount,
                maximum: policy.maximumEnabledVideoStreams
            )
        }
        if policy.requiresEnabledVideo, enabledVideoStreamCount == 0 {
            throw SessionValidationError.profileRequiresEnabledVideo(profile)
        }
    }

    private static func validateMTU(
        _ mtuBytes: Int,
        proposer: SessionTransportCapabilities,
        responder: SessionTransportCapabilities
    ) throws {
        let minimum = max(proposer.minMTUBytes, responder.minMTUBytes)
        let maximum = min(proposer.maxMTUBytes, responder.maxMTUBytes)
        if minimum > maximum {
            throw SessionValidationError.invalidMTURange(minimum: minimum, maximum: maximum)
        }
        if mtuBytes < minimum || mtuBytes > maximum {
            throw SessionValidationError.mtuOutOfRange(
                requested: mtuBytes,
                minimum: minimum,
                maximum: maximum
            )
        }
    }

    private static func validateAudioStream(
        _ stream: AudioStreamDescription,
        proposer: some SessionAudioCapabilityNegotiating,
        responder: some SessionAudioCapabilityNegotiating
    ) throws {
        try validateAudioStreamFormat(stream, proposer: proposer, responder: responder)
        try validateAudioStreamChannelCount(stream, proposer: proposer, responder: responder)
        try validateAudioStreamPayload(stream, proposer: proposer, responder: responder)
    }

    private static func validateAudioStreamFormat(
        _ stream: AudioStreamDescription,
        proposer: some SessionAudioCapabilityNegotiating,
        responder: some SessionAudioCapabilityNegotiating
    ) throws {
        guard proposer.sampleRatesHertz.contains(stream.sampleRateHertz),
              responder.sampleRatesHertz.contains(stream.sampleRateHertz) else {
            throw SessionValidationError.unsupportedSampleRate(stream.sampleRateHertz)
        }
        guard proposer.framesPerPacketOptions.contains(stream.framesPerPacket),
              responder.framesPerPacketOptions.contains(stream.framesPerPacket) else {
            throw SessionValidationError.unsupportedFramesPerPacket(stream.framesPerPacket)
        }
        guard proposer.sampleFormats.contains(stream.sampleFormat),
              responder.sampleFormats.contains(stream.sampleFormat) else {
            throw SessionValidationError.unsupportedSampleFormat(stream.sampleFormat)
        }
    }

    private static func validateAudioStreamChannelCount(
        _ stream: AudioStreamDescription,
        proposer: some SessionAudioCapabilityNegotiating,
        responder: some SessionAudioCapabilityNegotiating
    ) throws {
        let availableChannels = min(
            proposer.channelSet.channels.count,
            responder.channelSet.channels.count
        )
        guard availableChannels >= stream.channelCount else {
            throw SessionValidationError.unsupportedChannelCount(
                requested: stream.channelCount,
                available: availableChannels
            )
        }
    }

    private static func validateAudioStreamPayload(
        _ stream: AudioStreamDescription,
        proposer: some SessionAudioCapabilityNegotiating,
        responder: some SessionAudioCapabilityNegotiating
    ) throws {
        guard proposer.supportedPayloadTypes.contains(stream.payloadType),
              responder.supportedPayloadTypes.contains(stream.payloadType) else {
            throw SessionValidationError.unsupportedPayloadType(stream.payloadType)
        }
        switch stream.payloadType {
        case .audioPcmV2:
            guard proposer.supportedProtocolVersions.contains(.udpPcmV2),
                  responder.supportedProtocolVersions.contains(.udpPcmV2),
                  proposer.supportedAudioTransports.contains(.openLolaRaw),
                  responder.supportedAudioTransports.contains(.openLolaRaw),
                  [48_000, 96_000].contains(stream.sampleRateHertz),
                  [8, 16, 32, 64].contains(stream.framesPerPacket) else {
                throw SessionValidationError.unsupportedPayloadType(.audioPcmV2)
            }
        case .audioOpusCeltLowDelayFrame:
            guard proposer.supportedAudioTransports.contains(.openLolaOpusCeltLowDelay),
                  responder.supportedAudioTransports.contains(.openLolaOpusCeltLowDelay) else {
                throw SessionValidationError.unsupportedPayloadType(.audioOpusCeltLowDelayFrame)
            }
            try OpusCELTLowDelayCodecValidation.validate(
                sampleRateHertz: stream.sampleRateHertz,
                frameCount: stream.framesPerPacket,
                sampleFormat: stream.sampleFormat,
                channelCount: stream.channelCount
            )
        case .audioRtpL24:
            guard proposer.supportedAudioTransports.contains(.aes67ST2110L24),
                  responder.supportedAudioTransports.contains(.aes67ST2110L24),
                  stream.sampleRateHertz == AES67ST2110L24Profile.clockRateHertz,
                  [6, 48].contains(stream.framesPerPacket),
                  stream.sampleFormat == .float32LittleEndian,
                  stream.channelCount == AES67ST2110L24Profile.channelCount else {
                throw SessionValidationError.unsupportedPayloadType(.audioRtpL24)
            }
        default:
            throw SessionValidationError.unsupportedPayloadType(stream.payloadType)
        }
    }

}
