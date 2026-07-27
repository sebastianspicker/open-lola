// Verifies that direct audio media router rejects packets for unconfigured streams.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directAudioMediaRouterRejectsPacketsForUnconfiguredStreams() throws {
    let router = try DirectAudioMediaRouter(configuration: directAudioRouterSessionConfiguration())
    let packet = directAudioRouterPacket(streamID: 99, sequenceNumber: 1, senderFrameIndex: 0)

    #expect(throws: PeerSessionRunnerError.missingAudioStream) {
        _ = try router.route(packet)
    }
}

@Test
func directAudioMediaRouterRoutesConfiguredStreamPacket() throws {
    let router = try DirectAudioMediaRouter(configuration: directAudioRouterSessionConfiguration())
    let packet = directAudioRouterPacket(streamID: 1, sequenceNumber: 1, senderFrameIndex: 0)

    #expect(try router.route(packet) == .queued)
}

@Test
func directAudioMediaRouterAcceptsFragmentedChannelOffsetPlan() throws {
    let router = try DirectAudioMediaRouter(
        configuration: directAudioRouterSessionConfiguration(
            mtuBytes: 400,
            audioStreams: [
                directAudioRouterStream(id: 1, channelCount: 4)
            ]
        )
    )
    let first = directAudioRouterPacket(
        streamID: 1,
        sequenceNumber: 1,
        senderFrameIndex: 0,
        totalChannelCount: 4,
        channelOffset: 0,
        channelsInFragment: 2,
        fragmentIndex: 0,
        fragmentCount: 2
    )
    let second = directAudioRouterPacket(
        streamID: 1,
        sequenceNumber: 1,
        senderFrameIndex: 0,
        totalChannelCount: 4,
        channelOffset: 2,
        channelsInFragment: 2,
        fragmentIndex: 1,
        fragmentCount: 2
    )

    #expect(try router.route(first) == .waitingForFragments(receivedFragmentCount: 1, expectedFragmentCount: 2))
    #expect(try router.route(second) == .queued)
}

@Test
func directAudioMediaRouterKeepsConfiguredStreamsIsolated() throws {
    let router = try DirectAudioMediaRouter(
        configuration: directAudioRouterSessionConfiguration(
            audioStreams: [
                directAudioRouterStream(id: 1, channelCount: 2),
                directAudioRouterStream(id: 2, channelCount: 2)
            ]
        )
    )

    #expect(try router.route(directAudioRouterPacket(streamID: 1, sequenceNumber: 1, senderFrameIndex: 0)) == .queued)
    #expect(try router.route(directAudioRouterPacket(streamID: 2, sequenceNumber: 1, senderFrameIndex: 0)) == .queued)
}

@Test
func directAudioMediaRouterReportsFullBufferWithoutCrashOrOverwrite() throws {
    let router = try DirectAudioMediaRouter(configuration: directAudioRouterSessionConfiguration())
    let results = try (0..<5).map { index in
        try router.route(directAudioRouterPacket(
            streamID: 1,
            sequenceNumber: UInt64(index + 1),
            senderFrameIndex: UInt64(index * 32)
        ))
    }

    #expect(results.prefix(4).allSatisfy { $0 == .queued })
    #expect(results.last == .droppedFull)
}

@Test
func directAudioMediaRouterRejectsStreamsBeyondLocalAudioCapabilities() throws {
    let localCapabilities = directAudioRouterCapabilities(channelCount: 1)

    #expect(throws: DirectAudioMediaRouterError.unsupportedChannelCount(
        requested: 2,
        available: 1
    )) {
        _ = try DirectAudioMediaRouter(
            configuration: directAudioRouterSessionConfiguration(),
            localAudioCapabilities: localCapabilities
        )
    }

    #expect(throws: DirectAudioMediaRouterError.unsupportedSampleRate(96_000)) {
        _ = try DirectAudioMediaRouter(
            configuration: directAudioRouterSessionConfiguration(audioStreams: [
                directAudioRouterStream(id: 1, channelCount: 1, sampleRateHertz: 96_000)
            ]),
            localAudioCapabilities: localCapabilities
        )
    }

    #expect(throws: DirectAudioMediaRouterError.unsupportedFramesPerPacket(64)) {
        _ = try DirectAudioMediaRouter(
            configuration: directAudioRouterSessionConfiguration(audioStreams: [
                directAudioRouterStream(id: 1, channelCount: 1, framesPerPacket: 64)
            ]),
            localAudioCapabilities: localCapabilities
        )
    }
}

private func directAudioRouterSessionConfiguration(
    mtuBytes: Int = 1_200,
    audioStreams: [AudioStreamDescription] = [
        directAudioRouterStream(id: 1, channelCount: 2)
    ]
) -> SessionConfiguration {
    SessionConfiguration(
        identity: .init(sessionID: "router-test", peers: [
            PeerIdentity(
                peerID: "peer-a",
                displayName: "Peer A",
                implementationName: "open-lola",
                implementationVersion: "test"
            ),
            PeerIdentity(
                peerID: "peer-b",
                displayName: "Peer B",
                implementationName: "open-lola",
                implementationVersion: "test"
            )
        ]),
        profile: .init(latencyProfile: .directAudioFirst, rxBufferProfile: .direct),
        streams: .init(audioStreams: audioStreams, videoStreams: []),
        endpoints: referenceSessionEndpoints(),
        transport: .init(mtuBytes: mtuBytes, metricIntervalMilliseconds: 1_000, reconnectDeadlineMilliseconds: 2_000)
    )
}

private func directAudioRouterStream(
    id: Int,
    channelCount: Int,
    sampleRateHertz: Int = 48_000,
    framesPerPacket: Int = 32
) -> AudioStreamDescription {
    AudioStreamDescription(
            identity: .init(id: id, direction: .bidirectional, clockDomain: "local-clock"),
            format: .init(sampleRateHertz: sampleRateHertz, sampleFormat: .float32LittleEndian, channelCount: channelCount, channelOrder: (0..<channelCount).map {
            AudioChannelDescriptor(stableSourceIndex: $0)
        }),
            packet: .init(framesPerPacket: framesPerPacket, payloadType: .audioPcmV2)
        )
}

private func directAudioRouterCapabilities(
    channelCount: Int = 2,
    sampleRatesHertz: [Int] = [48_000],
    framesPerPacketOptions: [Int] = [32],
    sampleFormats: [UdpPcmSampleFormat] = [.float32LittleEndian]
) -> AudioTransportCapabilities {
    AudioTransportCapabilities(
        transport: .init(protocolVersions: [.udpPcmV2]),
        audio: .init(
            channelSet: .defaultInput(count: channelCount),
            sampleRatesHertz: sampleRatesHertz,
            framesPerPacketOptions: framesPerPacketOptions,
            sampleFormats: sampleFormats
        ),
        limits: .init(
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            latencyProfiles: [.ultraLowLatency16],
            rxBufferProfiles: [.direct],
            supportsMatrixMetadata: true
        )
    )
}

private func directAudioRouterPacket(
    streamID: UInt32,
    sequenceNumber: UInt64,
    senderFrameIndex: UInt64,
    totalChannelCount: UInt16 = 2,
    channelOffset: UInt16 = 0,
    channelsInFragment: UInt16 = 2,
    fragmentIndex: UInt16 = 0,
    fragmentCount: UInt16 = 1
) -> UdpPcmV2Packet {
    UdpPcmV2Packet(
        header: UdpPcmV2PacketHeader(
            stream: .init(streamID: streamID),
            timing: .init(
                sequenceNumber: sequenceNumber,
                senderFrameIndex: senderFrameIndex,
                senderHostTimeNanoseconds: 0
            ),
            format: .init(
                sampleRateHertz: 48_000,
                framesPerPacket: 32,
                totalChannelCount: totalChannelCount,
                sampleFormat: .float32LittleEndian,
                metadataRevision: 0,
                packingMode: .interleavedChannelRange
            ),
            fragment: .init(
                channelOffset: channelOffset,
                channelsInFragment: channelsInFragment,
                fragmentIndex: fragmentIndex,
                fragmentCount: fragmentCount
            )
        ),
        payload: Data(repeating: 0, count: 32 * Int(channelsInFragment) * 4)
    )
}
