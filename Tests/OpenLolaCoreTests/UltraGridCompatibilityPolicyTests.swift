// Verifies UltraGrid codec policy, payload registry safety, and control reporting.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func ultraGridRawVideoFourCCConstantsAvoidThrowingFileScopeInitialization() throws {
    let source = try ultraGridRepositoryFile(
        "Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridCompatibility.swift"
    )
    #expect(!source.contains("try! UltraGridFourCC"))

    let rgbPackets = try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
        frame: UltraGridVideoFragmentFrame(
            payload: Data([0x01, 0x02, 0x03]),
            id: 1,
            width: 1,
            height: 1,
            frameRate: 30,
            bitsPerPixel: 24
        ),
        transport: UltraGridVideoFragmentTransport(
            sequenceStart: 10,
            timestamp: 100,
            ssrc: 0x1234
        )
    ))
    let rgbaPackets = try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
        frame: UltraGridVideoFragmentFrame(
            payload: Data([0x01, 0x02, 0x03, 0x04]),
            id: 2,
            width: 1,
            height: 1,
            frameRate: 30,
            bitsPerPixel: 32
        ),
        transport: UltraGridVideoFragmentTransport(
            sequenceStart: 20,
            timestamp: 200,
            ssrc: 0x5678
        )
    ))
    let rgb = try UltraGridVideoRawFragmentPayload.decode(try #require(rgbPackets.first).payload)
    let rgba = try UltraGridVideoRawFragmentPayload.decode(try #require(rgbaPackets.first).payload)

    #expect(rgb.header.fourCC == (try UltraGridFourCC("RGB3")))
    #expect(rgba.header.fourCC == (try UltraGridFourCC("RGBA")))
}

@Test
func ultraGridDefaultPayloadRegistryAvoidsForcedInitialization() throws {
    let source = try ultraGridRepositoryFile(
        "Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridProtocolModel.swift"
    )
    #expect(!source.contains("try! UltraGridRTPPayloadRegistry"))
    #expect(UltraGridRTPPayloadRegistry.default.codec(for: 21) == .pcmAudio)
    #expect(UltraGridRTPPayloadRegistry.default.codec(for: 20) == .rawVideo)
}

@Test
func ultraGridCodecRejectsUnsupportedPayloadTypesAndModes() throws {
    let unsupportedRTP = RTPPacket(
        header: RTPPacketHeader(payloadType: 45, sequenceNumber: 1, timestamp: 1, ssrc: 1),
        payload: Data([0, 1, 2, 3])
    )
    #expect(throws: UltraGridCompatibilityError.unsupportedPayloadType(45)) {
        _ = try UltraGridCompatibility.decode(unsupportedRTP)
    }

    let unsupportedDynamicRTP = RTPPacket(
        header: RTPPacketHeader(payloadType: 96, sequenceNumber: 1, timestamp: 1, ssrc: 1),
        payload: Data([0, 1, 2, 3])
    )
    #expect(throws: UltraGridCompatibilityError.unsupportedMode("dynamic-rtp-unmapped-96")) {
        _ = try UltraGridCompatibility.decode(unsupportedDynamicRTP)
    }

    let unsupportedAudioTag = UltraGridAudioPayload(
        header: UltraGridAudioPayloadHeader(
            bufferNumber: 1,
            payloadOffset: 0,
            payloadByteCount: 4,
            quantizationBits: 16,
            sampleRateHertz: 48_000,
            audioTag: 2
        ),
        pcmPayload: Data([0, 1, 2, 3])
    )
    #expect(throws: UltraGridCompatibilityError.unsupportedMode("audio-tag-2")) {
        _ = try unsupportedAudioTag.encoded()
    }
}

@Test
func ultraGridReportsAdvancedModesAsUnsupportedUntilScoped() throws {
    #expect(UltraGridCompatibility.unsupportedModes.isEmpty)

    let encryptedVideo = RTPPacket(
        header: RTPPacketHeader(payloadType: 24, sequenceNumber: 1, timestamp: 1, ssrc: 1),
        payload: Data([0, 1, 2, 3])
    )
    #expect(throws: UltraGridCompatibilityError.unsupportedMode("encrypted-video-missing-key")) {
        _ = try UltraGridCompatibility.decode(encryptedVideo)
    }

    let encryptedAudio = RTPPacket(
        header: RTPPacketHeader(payloadType: 25, sequenceNumber: 1, timestamp: 1, ssrc: 1),
        payload: Data([0, 1, 2, 3])
    )
    #expect(throws: UltraGridCompatibilityError.unsupportedMode("encrypted-audio-missing-key")) {
        _ = try UltraGridCompatibility.decode(encryptedAudio)
    }
}

@Test
func ultraGridControlCommandsEncodeAndReportWithoutClaimingPeerControlPlane() throws {
    let command = try UltraGridControlCommand.parse("stats on")
    #expect(try command.encodedLine() == "stats on\r\n")
    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument(
        "ultraGrid.controlCommand",
        "stats on\nexit"
    )) {
        _ = try UltraGridControlCommand.parse("stats on\nexit")
    }

    let report = try UltraGridCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "203.0.113.20",
            outputPath: "/tmp/ug-control.json"
        ) { input in
            input.dryRun = true
            input.ultraGridControlMode = .localTCP
            input.ultraGridControlCommands = [.stats(true), .avDelayMilliseconds(15)]
        })
    )

    try report.validate()
    #expect(report.control.mode == .localTCP)
    #expect(report.control.port == 5054)
    #expect(report.control.commands == ["stats on\r\n", "av-delay 15\r\n"])
    #expect(report.verdict == .partial)
}

private func ultraGridRepositoryFile(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
