import Testing

@testable import OpenLolaCore

@Test
func lolaSocketBidirectionalUsesLiveSenderForAVFoundationRaw8() throws {
    let liveRaw8Configuration = lolaLiveRoutingConfiguration(
        mediaMode: .audioVideo,
        videoPayload: .avFoundationRaw8
    )
    let generatedVideoConfiguration = lolaLiveRoutingConfiguration(
        mediaMode: .audioVideo,
        videoPayload: .generated
    )
    let unsupportedLiveCaptureConfiguration = lolaLiveRoutingConfiguration(
        mediaMode: .audioVideo,
        videoPayload: .avFoundationMjpeg
    )
    let audioOnlyGeneratedConfiguration = lolaLiveRoutingConfiguration(
        mediaMode: .audio,
        videoPayload: .generated
    )
    let audioOnlyRaw8Configuration = lolaLiveRoutingConfiguration(
        mediaMode: .audio,
        videoPayload: .avFoundationRaw8
    )

    #expect(shouldUseLoLaLiveSocketTransmitter(liveRaw8Configuration))
    #expect(shouldUseLoLaLiveSocketTransmitter(generatedVideoConfiguration))
    #expect(!shouldUseLoLaLiveSocketTransmitter(unsupportedLiveCaptureConfiguration))
    #expect(shouldUseLoLaLiveSocketTransmitter(audioOnlyGeneratedConfiguration))
    #expect(!shouldUseLoLaLiveSocketTransmitter(audioOnlyRaw8Configuration))
}

private func lolaLiveRoutingConfiguration(
    mediaMode: ExternalConnectorMediaMode,
    videoPayload: LoLaVideoPayloadKind
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "127.0.0.1",
        localHost: "127.0.0.1",
        outputPath: "/tmp/lola-live-routing.json",
        dryRun: false,
        mediaMode: mediaMode,
        durationSeconds: 1,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8,
        lolaVideoPayload: videoPayload
    )
}
