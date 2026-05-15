import Testing

@testable import OpenLolaCore

@Test
func lolaSocketBidirectionalUsesLiveSenderForAVFoundationRaw8() throws {
    let udpSource = try readLoLaMediaSessionSource(
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift"
    )
    let liveSource = try readLoLaMediaSessionSource(
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMediaLive.swift"
    )

    #expect(liveSource.contains("configuration.lolaVideoPayload == .avFoundationRaw8"))
    #expect(liveSource.contains("LoLaAVFoundationLiveRaw8Source(configuration: configuration)"))
    #expect(udpSource.contains("LoLaSocketUdpMediaLiveTransmitter().transmit("))
    #expect(udpSource.contains("if shouldUseLoLaLiveSocketTransmitter(configuration)"))
}
