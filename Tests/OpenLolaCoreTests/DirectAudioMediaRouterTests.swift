import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directAudioMediaRouterRejectsPacketsForUnconfiguredStreams() throws {
    let router = try DirectAudioMediaRouter(configuration: directAudioRouterSessionConfiguration())
    let packet = UdpPcmV2Packet(
        header: UdpPcmV2PacketHeader(
            streamID: 99,
            sequenceNumber: 1,
            senderFrameIndex: 0,
            senderHostTimeNanoseconds: 0,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            totalChannelCount: 2,
            channelOffset: 0,
            channelsInFragment: 2,
            fragmentIndex: 0,
            fragmentCount: 1,
            sampleFormat: .float32LittleEndian,
            metadataRevision: 0,
            packingMode: .interleavedChannelRange
        ),
        payload: Data(repeating: 0, count: 32 * 2 * 4)
    )

    #expect(throws: PeerSessionRunnerError.missingAudioStream) {
        _ = try router.route(packet)
    }
}

private func directAudioRouterSessionConfiguration() -> SessionConfiguration {
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
        audioStreams: [
            AudioStreamDescription(
                id: 1,
                direction: .bidirectional,
                sampleRateHertz: 48_000,
                sampleFormat: .float32LittleEndian,
                channelCount: 2,
                channelOrder: [
                    AudioChannelDescriptor(stableSourceIndex: 0),
                    AudioChannelDescriptor(stableSourceIndex: 1),
                ],
                clockDomain: "local-clock",
                framesPerPacket: 32,
                payloadType: .audioPcmV2
            ),
        ],
        videoStreams: [],
        controlEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49152),
        audioEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49153),
        videoEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49154),
        metricsEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 49155),
        mtuBytes: 1_200,
        metricIntervalMilliseconds: 1_000,
        reconnectDeadlineMilliseconds: 2_000
    )
}
