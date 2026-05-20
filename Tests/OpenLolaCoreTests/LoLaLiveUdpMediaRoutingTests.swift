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

@Test
func lolaLiveTransmitBothAudioAndVideoErrorsArePreserved() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "not-an-ip-address",
        localHost: "127.0.0.1",
        outputPath: "/tmp/lola-live-aggregate-errors.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1,
        audioPort: 41_200,
        videoPort: 41_201,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8,
        lolaVideoPayload: .generated
    )

    do {
        _ = try LoLaSocketUdpMediaLiveTransmitter().transmit(configuration: configuration)
        Issue.record("Expected live transmitter to preserve both worker errors")
    } catch let error as LoLaLiveTransmitAggregateError {
        #expect(error.errors.count == 2)
        #expect(error.localizedDescription.contains("2 error(s)"))
        #expect(error.localizedDescription.contains("not-an-ip-address"))
    } catch {
        Issue.record("Expected aggregate error, got \(error)")
    }
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
