import Testing

@testable import OpenLolaCore

@Test
func sessionNegotiatesZeroVideoStreams() throws {
    let proposal = m10Proposal(video: [])

    let configuration = try SessionNegotiation.negotiate(
        proposal: proposal,
        proposerCapabilities: m10Capabilities(peer: m10PeerA()),
        responderCapabilities: m10Capabilities(peer: m10PeerB())
    )

    #expect(configuration.videoStreams.isEmpty)
    #expect(configuration.latencyProfile == .directAudioFirst)
}

@Test
func sessionNegotiatesPrimaryAndDisabledPerspectiveStreams() throws {
    let proposal = m10Proposal(
        video: [
            m10VideoStream(id: 100, label: "ATEM program", role: .atemProgram, priority: 100),
            .disabled(id: 101, sourceLabel: "ATEM preview"),
            .disabled(id: 102, sourceLabel: "Instrument close"),
        ],
        latencyProfile: .multiVideoPerformance,
        rxBufferProfile: .adaptive
    )

    let configuration = try SessionNegotiation.negotiate(
        proposal: proposal,
        proposerCapabilities: m10Capabilities(peer: m10PeerA()),
        responderCapabilities: m10Capabilities(peer: m10PeerB())
    )

    #expect(configuration.videoStreams.count == 3)
    #expect(configuration.videoStreams.filter(\.isEnabled).map(\.id) == [100])
    #expect(configuration.videoStreams[0].sourceLabel == "ATEM program")
    #expect(configuration.videoStreams[0].priority == 100)
    #expect(configuration.videoStreams[0].captureEnabled)
    #expect(!configuration.videoStreams[1].canSendMedia)
}

@Test
func sessionNegotiatesTwoEnabledVideoStreamsWithIndependentBudgets() throws {
    let proposal = m10Proposal(
        video: [
            m10VideoStream(id: 100, label: "Conductor", role: .blackmagicInput, priority: 100),
            m10VideoStream(id: 101, label: "Stage wide", role: .atemPreview, priority: 60),
        ],
        latencyProfile: .multiVideoPerformance,
        rxBufferProfile: .adaptive
    )

    let configuration = try SessionNegotiation.negotiate(
        proposal: proposal,
        proposerCapabilities: m10Capabilities(peer: m10PeerA()),
        responderCapabilities: m10Capabilities(peer: m10PeerB())
    )

    #expect(configuration.videoStreams.filter(\.canSendMedia).map(\.id) == [100, 101])
    #expect(configuration.videoStreams.map(\.queueDepth) == [1, 1])
    #expect(configuration.videoStreams.allSatisfy { $0.bandwidthBudgetMegabitsPerSecond > 0 })
}

@Test
func sessionRejectsDuplicateVideoStreamIDs() {
    let proposal = m10Proposal(
        video: [
            m10VideoStream(id: 100, label: "Program", role: .atemProgram),
            m10VideoStream(id: 100, label: "Preview", role: .atemPreview),
        ],
        latencyProfile: .multiVideoPerformance,
        rxBufferProfile: .adaptive
    )

    #expect(throws: SessionValidationError.duplicateStreamID(100)) {
        _ = try SessionNegotiation.negotiate(
            proposal: proposal,
            proposerCapabilities: m10Capabilities(peer: m10PeerA()),
            responderCapabilities: m10Capabilities(peer: m10PeerB())
        )
    }
}

@Test
func sessionRejectsStreamThatExceedsItsBandwidthBudget() {
    let proposal = m10Proposal(
        video: [
            m10VideoStream(
                id: 100,
                label: "Program",
                role: .atemProgram,
                bandwidthBudgetMegabitsPerSecond: 1
            ),
        ],
        latencyProfile: .multiVideoPerformance,
        rxBufferProfile: .adaptive
    )

    #expect(throws: SessionValidationError.videoBandwidthBudgetExceeded(
        streamID: 100,
        requiredMegabitsPerSecond: m10VideoStream().estimatedBandwidthMegabitsPerSecond,
        budgetMegabitsPerSecond: 1
    )) {
        _ = try SessionNegotiation.negotiate(
            proposal: proposal,
            proposerCapabilities: m10Capabilities(peer: m10PeerA()),
            responderCapabilities: m10Capabilities(peer: m10PeerB())
        )
    }
}

private func m10PeerA() -> PeerIdentity {
    PeerIdentity(
        peerID: "peer-a",
        displayName: "M10 Mac A",
        implementationName: "open-lola",
        implementationVersion: "0.0.0-m10"
    )
}

private func m10PeerB() -> PeerIdentity {
    PeerIdentity(
        peerID: "peer-b",
        displayName: "M10 Mac B",
        implementationName: "open-lola",
        implementationVersion: "0.0.0-m10"
    )
}

private func m10Capabilities(peer: PeerIdentity) -> CapabilitySet {
    CapabilitySet(
        peer: peer,
        supportedControlVersions: [SessionControlProtocol.currentVersion],
        audio: AudioTransportCapabilities(
            supportedProtocolVersions: [.udpPcmV2],
            channelSet: .defaultInput(count: 64),
            sampleRatesHertz: [48_000, 96_000],
            framesPerPacketOptions: [32, 64],
            sampleFormats: [.float32LittleEndian, .int16LittleEndian],
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            latencyProfiles: [.safeLowLatency],
            rxBufferProfiles: [.direct, .small],
            supportsMatrixMetadata: true
        ),
        video: VideoCapabilities(
            supportedRoles: [.disabled, .blackmagicInput, .atemProgram, .atemPreview],
            supportedPixelFormats: [.bgra8],
            supportedTransportFormats: [.disabled, .rawFrameFragment],
            maxWidth: 1_920,
            maxHeight: 1_080,
            maxFrameRateNumerator: 60,
            maxEnabledStreams: 4
        ),
        transport: SessionTransportCapabilities(
            supportsDirectUDP: true,
            supportsRendezvous: true,
            minMTUBytes: 576,
            maxMTUBytes: 1_200
        ),
        latencyProfiles: [.directAudioFirst, .balancedAV, .multiVideoPerformance],
        rxBufferProfiles: [.direct, .small, .adaptive]
    )
}

private func m10VideoStream(
    id: Int = 100,
    label: String = "Program",
    role: VideoStreamRole = .atemProgram,
    priority: Int = 100,
    bandwidthBudgetMegabitsPerSecond: Double = 10_000
) -> VideoStreamDescription {
    VideoStreamDescription(
        id: id,
        direction: .send,
        role: role,
        resolution: VideoResolution(width: 1_920, height: 1_080),
        frameRate: VideoFrameRate(numerator: 60, denominator: 1),
        pixelFormat: .bgra8,
        transportFormat: .rawFrameFragment,
        sourceLabel: label,
        payloadType: .videoRawFrameFragment,
        priority: priority,
        captureEnabled: true,
        queueDepth: 1,
        bandwidthBudgetMegabitsPerSecond: bandwidthBudgetMegabitsPerSecond
    )
}

private func m10AudioStream() -> AudioStreamDescription {
    AudioStreamDescription(
        id: 1,
        direction: .bidirectional,
        sampleRateHertz: 48_000,
        sampleFormat: .float32LittleEndian,
        channelCount: 64,
        channelOrder: AudioChannelSet.defaultInput(count: 64).sortedByStableSourceIndex,
        clockDomain: "core-audio-device:rme-madi",
        framesPerPacket: 32,
        payloadType: .audioPcmV2
    )
}

private func m10Proposal(
    video: [VideoStreamDescription],
    latencyProfile: SessionLatencyProfile = .directAudioFirst,
    rxBufferProfile: RxBufferProfile = .direct
) -> SessionProposal {
    SessionProposal(
        sessionID: "m10-session",
        proposer: m10PeerA(),
        responder: m10PeerB(),
        latencyProfile: latencyProfile,
        rxBufferProfile: rxBufferProfile,
        audioStreams: [m10AudioStream()],
        videoStreams: video,
        controlEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_000),
        audioEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_001),
        videoEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_002),
        metricsEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_003),
        mtuBytes: 1_200
    )
}
