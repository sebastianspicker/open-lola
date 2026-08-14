// Verifies that the LoLa session parser accepts MJPEG payloads and quick-connect video flags.
import Foundation
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
func lolaSessionParserDefaultsToGeneratedRawCOMP0() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "lola",
        "--role", "tx-rx",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-default-session.json",
        "--media", "video"
    ])
    #expect(configuration.lolaVideoPayload == .generated)
    #expect(configuration.videoCompression == 0)
}

@Test
func lolaSessionParserRejectsJpegXSForWindowsLoLa() {
    #expect(throws: ExternalConnectorSessionError.unsupportedRuntimeMode(
        "lola-jpeg-xs-unsupported-for-windows-lola"
    )) {
        _ = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "lola",
        "--role", "tx-rx",
        "--peer", "192.0.2.20",
        "--output", "/tmp/lola-jpeg-xs-session.json",
        "--media", "video",
        "--lola-video-payload", "avfoundation-jpeg-xs",
        "--video-compression", "1"
        ])
    }
}

@Test(arguments: [
    ("generated", "1", "lola-raw-video-payload-requires-COMP-0"),
    ("avfoundation-raw8", "1", "lola-raw-video-payload-requires-COMP-0"),
    ("avfoundation-mjpeg", "0", "lola-mjpeg-video-payload-requires-COMP-1"),
    ("generated", "2", "lola-video-compression-unsupported-2")
])
func lolaSessionParserRejectsInvalidPayloadAndCOMPCombinations(
    payload: String,
    compression: String,
    expectedMode: String
) {
    #expect(throws: ExternalConnectorSessionError.unsupportedRuntimeMode(expectedMode)) {
        _ = try ExternalConnectorSessionConfiguration.parse([
            "--connector", "lola",
            "--role", "tx-rx",
            "--peer", "192.0.2.20",
            "--output", "/tmp/lola-invalid-session.json",
            "--media", "video",
            "--lola-video-payload", payload,
            "--video-compression", compression
        ])
    }
}

@Test(arguments: [
    (LoLaVideoPayloadKind.generated, 1, "lola-raw-video-payload-requires-COMP-0"),
    (.avFoundationRaw8, 1, "lola-raw-video-payload-requires-COMP-0"),
    (.avFoundationMjpeg, 0, "lola-mjpeg-video-payload-requires-COMP-1"),
    (.generated, 2, "lola-video-compression-unsupported-2")
])
func lolaVideoPayloadContractRejectsInvalidPayloadAndCOMPCombinations(
    payload: LoLaVideoPayloadKind,
    compression: Int,
    expectedMode: String
) {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-video-contract.json"
    ) { input in
        input.mediaMode = .video
        input.lolaVideoPayload = payload
        input.videoCompression = compression
    })

    #expect(throws: ExternalConnectorSessionError.unsupportedRuntimeMode(expectedMode)) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    }
}

@Test
func lolaRawVideoPayloadRejectsUnalignedBPPAndWrongPayloadLength() throws {
    let unaligned = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-video-contract.json"
    ) { input in
        input.mediaMode = .video
        input.videoWidth = 2
        input.videoHeight = 2
        input.videoBitsPerPixel = 12
    })
    #expect(throws: ExternalConnectorSessionError.unsupportedRuntimeMode(
        "lola-raw-video-bpp-must-be-byte-aligned"
    )) {
        _ = try LoLaVideoPayloadProvider.generatedRawVideoPayload(configuration: unaligned, sequenceNumber: 0)
    }

    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-video-contract.json"
    ) { input in
        input.mediaMode = .video
        input.videoWidth = 640
        input.videoHeight = 480
        input.videoBitsPerPixel = 8
    })
    #expect(throws: LoLaVideoPayloadError.rawPayloadLengthMismatch(expected: 307_200, actual: 1)) {
        try LoLaVideoPayloadProvider.validatePayload(Data([0]), configuration: configuration)
    }
}

@Test
func lolaMjpegPayloadRequiresCompleteJpegMarkersBeforePacketization() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-video-contract.json"
    ) { input in
        input.mediaMode = .video
        input.lolaVideoPayload = .avFoundationMjpeg
        input.videoCompression = 1
    })
    #expect(throws: LoLaVideoPayloadError.incompleteMjpegPayload) {
        try LoLaVideoPayloadProvider.validatePayload(Data([0xff, 0xd8, 0x00]), configuration: configuration)
    }
    try LoLaVideoPayloadProvider.validatePayload(
        Data([0xff, 0xd8, 0xff, 0xd9]),
        configuration: configuration
    )

    #expect(throws: LoLaVideoPayloadError.incompleteMjpegPayload) {
        _ = try LoLaCompatibilityMediaSession.buildTransmitFramesForSequence(
            configuration: configuration,
            sequence: 0,
            capturedVideoPayload: Data([0xff, 0xd8, 0x00])
        )
    }
}
