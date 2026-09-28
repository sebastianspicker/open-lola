// Protects codec independence when raw PCM session packetization is prepared once.
import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaTransport
@testable import OpenLolaApplication
import Testing

@Test func rawAudioPlanPreparationDoesNotConstrainCompressedOrRTPStreams() throws {
    let endpoint = SessionNetworkEndpoint(host: "127.0.0.1", port: 19788)
    let streams = [
        transmitPlanStream(id: 1, payloadType: .audioPcmV2, frames: 32),
        transmitPlanStream(id: 2, payloadType: .audioOpusCeltLowDelayFrame, frames: 120),
        transmitPlanStream(id: 3, payloadType: .audioRtpL24, frames: 48)
    ]
    let configuration = SessionConfiguration(
        identity: .init(sessionID: "plan-fixture", peers: []),
        profile: .init(latencyProfile: .directAudioFirst, rxBufferProfile: .direct),
        streams: .init(audioStreams: streams, videoStreams: []),
        endpoints: .init(control: endpoint, audio: endpoint, video: endpoint, metrics: endpoint),
        transport: .init(mtuBytes: 256, metricIntervalMilliseconds: 100, reconnectDeadlineMilliseconds: 1000)
    )
    let plans = try PeerSessionRunner.audioTransmitPlans(for: configuration)
    #expect(Set(plans.keys) == [1])
    #expect(plans[1]?.mode.framesPerPacket == 32)
    // The compressed stream's PCM input cannot fit the unrelated raw fragmentation limit.
    #expect(throws: UdpPcmV2FragmentPlanningError.self) {
        try PeerSessionRunner.audioMode(for: streams[1], mtuBytes: 256)
    }
}

private func transmitPlanStream(id: Int, payloadType: SessionPayloadType, frames: Int) -> AudioStreamDescription {
    AudioStreamDescription(
        identity: .init(id: id, direction: .bidirectional, clockDomain: "plan-fixture"),
        format: .init(
            sampleRateHertz: 48_000, sampleFormat: .float32LittleEndian, channelCount: 2,
            channelOrder: AudioChannelSet.defaultInput(count: 2).sortedByStableSourceIndex
        ),
        packet: .init(framesPerPacket: frames, payloadType: payloadType)
    )
}
