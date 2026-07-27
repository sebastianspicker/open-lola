// Shared rx buffering tests helpers keep related tests deterministic and focused on their contract.
import Foundation
import Testing

@testable import OpenLolaCore

func realtimeRxBufferConfiguration(
    playoutTargetFrames: Int = 32,
    rxBufferPolicy: RxBufferPolicy
) -> RealtimeAudioEngineConfiguration {
    standardRealtimeAudioEngineConfiguration(
        playoutTargetFrames: playoutTargetFrames,
        rxBufferPolicy: rxBufferPolicy
    )
}

func rxBufferPacketMode() -> UdpPcmPacketMode {
    UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
}

func rxBufferImpairmentSimulatorDomainProfile() -> RxImpairmentProfile {
    RxImpairmentProfile(
        transport: RxImpairmentProfile.Transport(
            seed: 1,
            packetCount: 5,
            framesPerPacket: 32,
            sampleRateHertz: 48_000
        ),
        transit: RxImpairmentProfile.Transit(baseMicroseconds: 100, jitterAmplitudeMicroseconds: 100),
        packetFaults: RxImpairmentProfile.PacketFaults(
            lossEveryNthPacket: nil,
            duplicateEveryNthPacket: nil,
            reorderEveryNthPacket: nil,
            lateEveryNthPacket: nil
        ),
        fragmentation: RxImpairmentProfile.Fragmentation(count: 1, lossEveryNthPacket: nil)
    )
}

func latencyBenchmarkRxPassCandidate() throws -> LatencyBenchmarkReport {
    let rxBufferImpact = RxBufferBenchmarkImpact(
        profile: try .direct(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            targetPackets: 1
        ),
        targetFramesOverTime: [32],
        targetChangeEvents: [],
        impairmentSummary: nil
    )
    return try latencyBenchmarkPhysicalValidationCandidate(
        id: "rx-buffer-benchmark-physical-pass-candidate",
        title: "RX buffer benchmark physical pass candidate",
        category: .directPeerToPeer,
        rxBufferImpact: rxBufferImpact
    )
}
