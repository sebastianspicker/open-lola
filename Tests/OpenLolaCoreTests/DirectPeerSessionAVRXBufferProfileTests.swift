import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionAVBufferPolicyMapsProfilesAndRingCapacity() throws {
    #expect(try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: .fastest,
        rxBufferProfile: .direct
    ) == DirectPeerSessionAVBufferPolicy(
        latencyProfile: .directAudioFirst,
        rxBufferProfile: .direct,
        ringCapacityBlocks: 4,
        rxBufferPolicy: try .direct(framesPerPacket: 32, sampleRateHertz: 48_000)
    ))
    #expect(try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: .balanced,
        rxBufferProfile: .small
    ) == DirectPeerSessionAVBufferPolicy(
        latencyProfile: .balancedAV,
        rxBufferProfile: .small,
        ringCapacityBlocks: 8,
        rxBufferPolicy: try .small(framesPerPacket: 32, sampleRateHertz: 48_000)
    ))
    #expect(try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: .balanced,
        rxBufferProfile: .adaptive
    ) == DirectPeerSessionAVBufferPolicy(
        latencyProfile: .multiVideoPerformance,
        rxBufferProfile: .adaptive,
        ringCapacityBlocks: 16,
        rxBufferPolicy: try .adaptive(framesPerPacket: 32, sampleRateHertz: 48_000)
    ))
    #expect(try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: .balanced,
        rxBufferProfile: .stableWan
    ) == DirectPeerSessionAVBufferPolicy(
        latencyProfile: .wanStable,
        rxBufferProfile: .stableWan,
        ringCapacityBlocks: 32,
        rxBufferPolicy: try .stableWan(framesPerPacket: 32, sampleRateHertz: 48_000)
    ))
}

@Test
func directPeerSessionAVBufferPolicyUsesRuntimePacketShape() throws {
    let policy = try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: .balanced,
        rxBufferProfile: .small,
        framesPerPacket: 64,
        sampleRateHertz: 96_000
    )

    #expect(policy.rxBufferPolicy.framesPerPacket == 64)
    #expect(policy.rxBufferPolicy.sampleRateHertz == 96_000)
    #expect(policy.rxBufferPolicy.targetFrames == 128)
}

@Test
func directPeerAudioVideoGraphConfigurationCarriesSelectedRXBufferPolicy() throws {
    let stableWan = try audioGraphConfiguration(
        for: avConfiguration(avProfile: .balanced, rxBufferProfile: .stableWan)
    )
    let fastest = try audioGraphConfiguration(
        for: avConfiguration(avProfile: .fastest, rxBufferProfile: .direct)
    )

    #expect(stableWan.ringCapacityBlocks == 32)
    #expect(stableWan.rxBufferPolicy?.profile == .stableWan)
    #expect(stableWan.playoutTargetFrames == 256)
    #expect(fastest.ringCapacityBlocks == 4)
    #expect(fastest.rxBufferPolicy?.profile == .direct)
    #expect(fastest.playoutTargetFrames == 32)
}

@Test
func directAudioMediaRouterModeCarriesSessionRXBufferProfile() throws {
    let stream = AudioStreamDescription(
        id: 1,
        direction: .bidirectional,
        sampleRateHertz: 48_000,
        sampleFormat: .float32LittleEndian,
        channelCount: 2,
        channelOrder: AudioChannelSet.defaultInput(count: 2).sortedByStableSourceIndex,
        clockDomain: "core-audio-device:test",
        framesPerPacket: 32,
        payloadType: .audioPcmV2
    )

    let mode = try directAudioMediaRouterAudioMode(
        for: stream,
        mtuBytes: 1_200,
        latencyProfile: .wanStable,
        rxBufferProfile: .stableWan
    )

    #expect(mode.latencyProfile == .safeLowLatency)
    #expect(mode.rxBufferProfile == .stableWan)
    #expect(mode.framesPerPacket == 32)
    #expect(mode.channelCount == 2)
}

@Test
func directPeerSessionAVBufferPolicyRejectsInvalidCombinations() {
    #expect(throws: DirectPeerSessionAVRuntimeError.unsupportedRXBufferProfile(
        avProfile: .fastest,
        rxBufferProfile: .adaptive
    )) {
        _ = try DirectPeerSessionAVBufferPolicy.resolve(
            avProfile: .fastest,
            rxBufferProfile: .adaptive
        )
    }
    #expect(throws: DirectPeerSessionAVRuntimeError.unsupportedRXBufferProfile(
        avProfile: .balanced,
        rxBufferProfile: .direct
    )) {
        _ = try DirectPeerSessionAVBufferPolicy.resolve(
            avProfile: .balanced,
            rxBufferProfile: .direct
        )
    }
}

private func avConfiguration(
    avProfile: DirectPeerSessionAVProfile,
    rxBufferProfile: RxBufferProfile
) -> DirectPeerSessionAVRunConfiguration {
    DirectPeerSessionAVRunConfiguration(
        manual: DirectPeerSessionManualRunConfiguration(
            role: .initiator,
            localPeerID: "peer-a",
            remotePeerID: "peer-b",
            localHost: "127.0.0.1",
            remoteHost: "127.0.0.1",
            controlPort: 41_000,
            remoteControlPort: 42_000,
            audioPort: 41_001,
            videoPort: 41_002,
            metricsPort: 41_003,
            packetCount: 1,
            audioChannelCount: 2,
            timeoutSeconds: 10
        ),
        durationSeconds: 1,
        audioDeviceUID: "synthetic-audio",
        inputDeviceUID: "synthetic-audio",
        outputDeviceUID: "synthetic-audio",
        framesPerPacket: 32,
        videoDeviceID: "synthetic-video",
        avProfile: avProfile,
        rxBufferProfile: rxBufferProfile,
        preview: .off,
        mediaSourceMode: .syntheticFixture
    )
}

@Test
func directPeerSessionAudioVideoBalancedAdaptiveNegotiatesMultiVideoPerformance() throws {
    let configuration = try negotiateAVConfiguration(rxBufferProfile: .adaptive)

    #expect(configuration.latencyProfile == .multiVideoPerformance)
    #expect(configuration.rxBufferProfile == .adaptive)
}

@Test
func directPeerSessionAudioVideoBalancedStableWanNegotiatesWanStable() throws {
    let configuration = try negotiateAVConfiguration(rxBufferProfile: .stableWan)

    #expect(configuration.latencyProfile == .wanStable)
    #expect(configuration.rxBufferProfile == .stableWan)
}

private func negotiateAVConfiguration(
    rxBufferProfile: RxBufferProfile
) throws -> SessionConfiguration {
    var pair = try PeerSessionRunnerLoopbackPair.make()
    _ = try pair.first.beginHandshake()
    try pair.second.receiveControlMessages(pair.first.controlTranscript)
    _ = try pair.second.beginHandshake()
    try pair.first.receiveControlMessages(pair.second.controlTranscript)

    let proposal = try pair.first.makeAudioVideoSessionProposal(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        sampleFormat: .float32LittleEndian,
        audioChannelCount: 2,
        videoStreamID: 120,
        videoFrameRate: 30,
        avProfile: .balanced,
        rxBufferProfile: rxBufferProfile
    )
    let accept = try pair.second.acceptProposal(
        proposal,
        proposerCapabilities: pair.first.localCapabilities
    )
    try pair.first.receiveControlMessages([accept])
    return try #require(pair.first.acceptedConfiguration)
}
