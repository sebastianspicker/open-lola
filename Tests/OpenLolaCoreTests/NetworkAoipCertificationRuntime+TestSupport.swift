// Shared network aoip certification runtime helpers keep related tests deterministic and focused on their contract.
import Foundation
import Testing
@testable import OpenLolaCore

func networkAoipAcceptedMode(_ fixture: MeasuredFixtureAcceptedMode) -> EndpointModeResult {
    var result = acceptedMode(fixture)
    if !fixture.stable {
        result.notes = "accepted unstable measured row"
    }
    return result
}

func networkAoipRejectedMode(_ sampleRate: Int, _ frames: Int, reason: String) -> EndpointModeResult {
    measuredFixtureRejectedMode(sampleRate, frames, reason: reason)
}

func networkAoipRealtimeRuntime() throws -> RealtimeAudioRuntimeEvidence {
    standardRealtimeAudioRuntimeEvidence(rxBufferPolicy: try networkAoipRxBufferPolicy())
}

func networkAoipRealtimeConfiguration() throws -> RealtimeAudioEngineConfiguration {
    standardRealtimeAudioEngineConfiguration(rxBufferPolicy: try networkAoipRxBufferPolicy())
}

func networkAoipRxBufferPolicy() throws -> RxBufferPolicy {
    try RxBufferPolicy.direct(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        targetPackets: 1
    )
}

func networkAoipRmeDevice() -> CoreAudioDeviceInventory {
    measuredFixtureRmeMadiDevice(
        uid: "rme-madi-uid",
        id: 42,
        transportType: "thunderbolt",
        outsideReportedRange: [],
        diagnosticNotes: ["measured RME MADI Thunderbolt source"]
    )
}

func networkAoipLolaBaseline(route: RouteIdentity) -> LolaBaselineComparison {
    measuredFixtureLolaBaseline(route: route, packetMode: networkAoipPacketMode())
}

func networkAoipEndpointProfile(_ suffix: String) -> AoipEndpointProfile {
    AoipEndpointProfile(
        vendor: "RME",
        model: "AVB Tool \(suffix)",
        firmwareVersion: "1.2.3",
        profileName: "AVB media endpoint",
        bufferFrames: 16
    )
}

func networkAoipPacketMode() -> UdpPcmPacketMode {
    measuredFixturePacketMode()
}
