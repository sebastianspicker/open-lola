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
                directAudioRouterStream(id: 1, channelCount: 4),
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
                directAudioRouterStream(id: 2, channelCount: 2),
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

private func directAudioRouterSessionConfiguration(
    mtuBytes: Int = 1_200,
    audioStreams: [AudioStreamDescription] = [
        directAudioRouterStream(id: 1, channelCount: 2),
    ]
) -> SessionConfiguration {
    SessionConfiguration(
        sessionID: "router-test",
        peers: [
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
            ),
        ],
        latencyProfile: .directAudioFirst,
        rxBufferProfile: .direct,
        audioStreams: audioStreams,
        videoStreams: [],
        controlEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49152),
        audioEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49153),
        videoEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49154),
        metricsEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49155),
        mtuBytes: mtuBytes,
        metricIntervalMilliseconds: 1_000,
        reconnectDeadlineMilliseconds: 2_000
    )
}

private func directAudioRouterStream(
    id: Int,
    channelCount: Int
) -> AudioStreamDescription {
    AudioStreamDescription(
        id: id,
        direction: .bidirectional,
        sampleRateHertz: 48_000,
        sampleFormat: .float32LittleEndian,
        channelCount: channelCount,
        channelOrder: (0..<channelCount).map {
            AudioChannelDescriptor(stableSourceIndex: $0)
        },
        clockDomain: "local-clock",
        framesPerPacket: 32,
        payloadType: .audioPcmV2
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
            streamID: streamID,
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            senderHostTimeNanoseconds: 0,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            totalChannelCount: totalChannelCount,
            channelOffset: channelOffset,
            channelsInFragment: channelsInFragment,
            fragmentIndex: fragmentIndex,
            fragmentCount: fragmentCount,
            sampleFormat: .float32LittleEndian,
            metadataRevision: 0,
            packingMode: .interleavedChannelRange
        ),
        payload: Data(repeating: 0, count: 32 * Int(channelsInFragment) * 4)
    )
}
