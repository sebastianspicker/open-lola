// Verifies that the LoLa session parser accepts MJPEG payloads and quick-connect video flags.
import Testing

@testable import OpenLolaCore

@Test
func lolaSessionParserAcceptsMjpegPayloadAndQuickConnectVideoFlags() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "lola",
        "--role", "tx-rx",
        "--peer", "192.0.2.20",
        "--local-host", "192.0.2.10",
        "--output", "/tmp/lola-mjpeg-session.json",
        "--media", "video",
        "--lola-video-payload", "avfoundation-mjpeg",
        "--video-capture", "auto",
        "--video-compression", "1",
        "--video-bayer", "0"
    ])

    #expect(configuration.lolaVideoPayload == .avFoundationMjpeg)
    #expect(configuration.videoCapture == "auto")
    #expect(configuration.videoCompression == 1)
    #expect(configuration.videoBayer == 0)
}

@Test
func lolaSessionParserAcceptsRaw8PayloadForBayerProbe() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "lola",
        "--role", "tx-rx",
        "--peer", "192.0.2.20",
        "--local-host", "192.0.2.10",
        "--output", "/tmp/lola-raw8-session.json",
        "--media", "video",
        "--video-width", "640",
        "--video-height", "480",
        "--video-bpp", "8",
        "--lola-video-payload", "avfoundation-raw8",
        "--video-capture", "auto",
        "--video-compression", "0",
        "--video-bayer", "1"
    ])

    #expect(configuration.lolaVideoPayload == .avFoundationRaw8)
    #expect(configuration.videoWidth == 640)
    #expect(configuration.videoHeight == 480)
    #expect(configuration.videoBitsPerPixel == 8)
    #expect(configuration.videoCompression == 0)
    #expect(configuration.videoBayer == 1)
}

@Test
func lolaSessionParserAcceptsJpegXSPayloadWithoutChangingCompressionField() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "lola",
        "--role", "tx-rx",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-jpeg-xs-session.json",
        "--media", "video",
        "--lola-video-payload", "avfoundation-jpeg-xs",
        "--video-compression", "1"
    ])

    #expect(configuration.lolaVideoPayload == .avFoundationJpegXS)
    #expect(configuration.videoCompression == 1)
}
