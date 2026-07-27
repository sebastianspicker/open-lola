// Verifies that direct peer session AV buffer policy maps profiles and ring capacity.
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
            identity: .init(id: 1, direction: .bidirectional, clockDomain: "core-audio-device:test"),
            format: .init(sampleRateHertz: 48_000, sampleFormat: .float32LittleEndian, channelCount: 2, channelOrder: AudioChannelSet.defaultInput(count: 2).sortedByStableSourceIndex),
            packet: .init(framesPerPacket: 32, payloadType: .audioPcmV2)
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
    var manualFixture = DirectPeerManualTestFixture()
    manualFixture.ports = [41_000, 42_000, 41_001, 41_002, 41_003]
    manualFixture.timeoutSeconds = 10
    var fixture = DirectPeerSyntheticAVFixture(manual: manualFixture.configuration())
    fixture.audioDeviceUID = "synthetic-audio"
    fixture.inputDeviceUID = "synthetic-audio"
    fixture.outputDeviceUID = "synthetic-audio"
    fixture.videoDeviceID = "synthetic-video"
    fixture.videoWidth = 1_280
    fixture.videoHeight = 720
    fixture.avProfile = avProfile
    fixture.rxBufferProfile = rxBufferProfile
    return fixture.configuration()
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
    var request = PeerSessionAVProposalRequest()
    request.sampleRateHertz = 48_000
    request.framesPerPacket = 32
    request.sampleFormat = .float32LittleEndian
    request.audioChannelCount = 2
    request.videoStreamID = 120
    request.videoFrameRate = 30
    request.avProfile = .balanced
    request.rxBufferProfile = rxBufferProfile
    return try negotiatedAudioVideoConfiguration(request: request)
}
