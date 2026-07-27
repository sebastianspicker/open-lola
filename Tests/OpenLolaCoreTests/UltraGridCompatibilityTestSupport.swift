// Shared ultra grid compatibility helpers keep related tests deterministic and focused on their contract.
import Foundation

@testable import OpenLolaCore

func ultraGridAudioDatagram(
    sequence: UInt16,
    timestamp: UInt32,
    ssrc: UInt32
) throws -> UltraGridCompatibilityDatagram {
    UltraGridCompatibilityDatagram(
        stream: .audio,
        sourceHost: "203.0.113.10",
        destinationPort: 50_006,
        rtp: try UltraGridCompatibility.audioPacket(UltraGridAudioPacketRequest(
            sequenceNumber: sequence,
            timestamp: timestamp,
            ssrc: ssrc,
            channels: 2,
            sampleRateHertz: 48_000,
            framesPerPacket: 128,
            pcmPayload: Data(repeating: 0, count: 8)
        ))
    )
}
