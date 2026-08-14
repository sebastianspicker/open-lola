// Verifies that accepted UltraGrid raw8 sources are normalized to receiver-valid RGB3 wire frames.
import Foundation
import Testing

@testable import OpenLolaCore

@Test(arguments: [false, true])
func ultraGridRaw8SourcesProduceReceiverValidRGB3WireFrames(liveSourceSeam: Bool) throws {
    let configuration = ultraGridRaw8WireConfiguration()
    let source = liveSourceSeam ? Data([0x10, 0x20]) : Data([0x00, 0x01])
    let provider: any UltraGridMediaProviding = liveSourceSeam
        ? UltraGridRaw8WireProvider(source: source)
        : UltraGridSyntheticMediaProvider()
    let datagrams = try UltraGridCompatibilityRunner.buildDatagrams(
        configuration: configuration,
        mediaProvider: provider
    )
    let fragments = try datagrams.map { try UltraGridVideoRawFragmentPayload.decode($0.rtp.payload) }
    let reassembled = try UltraGridCompatibility.reassembleVideoFrame(fragments)

    let rgb3 = try UltraGridFourCC("RGB3")
    #expect(fragments.allSatisfy { $0.header.fourCC == rgb3 })
    #expect(reassembled == Data([source[0], source[0], source[0], source[1], source[1], source[1]]))
    #expect(try UltraGridCompatibilityMediaSinkDecoder.consumeReceivedMedia(
        datagrams,
        encryptionConfiguration: nil
    ).videoFrameCount == 1)
    #expect(provider.providerReport.observedEvidenceClasses == [.synthetic])
}

@Test
func ultraGridRaw8WireContractRejectsWrongSourceShapeBeforePacketization() throws {
    #expect(throws: UltraGridCompatibilityError.invalidPayloadLength(expected: 2, actual: 6)) {
        _ = try UltraGridCompatibilityRunner.buildDatagrams(
            configuration: ultraGridRaw8WireConfiguration(),
            mediaProvider: UltraGridRaw8WireProvider(source: Data(repeating: 0, count: 6))
        )
    }
}

private final class UltraGridRaw8WireProvider: UltraGridMediaProviding {
    let source: Data

    init(source: Data) {
        self.source = source
    }

    var providerReport: ExternalConnectorMediaProviderReport {
        ExternalConnectorMediaProviderReport(
            audioSource: "test",
            videoSource: "avfoundation-raw8-seam",
            observedEvidenceClasses: [.synthetic],
            notes: "Test seam only; no camera or UltraGrid peer is used."
        )
    }

    func audioPCM(sequenceNumber _: Int, channels _: Int, framesPerPacket _: Int) throws -> Data { Data() }

    func videoFrame(frameID _: Int, width _: Int, height _: Int, bitsPerPixel _: Int) throws -> Data { source }

    func videoFrame(
        frameID: Int,
        width: Int,
        height: Int,
        bitsPerPixel: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        return try videoFrame(frameID: frameID, width: width, height: height, bitsPerPixel: bitsPerPixel)
    }
}

private func ultraGridRaw8WireConfiguration() -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/ug-raw8-wire.json"
    ) { input in
        input.mediaMode = .video
        input.videoWidth = 2
        input.videoHeight = 1
        input.videoFrameRate = 30
        input.videoBitsPerPixel = 8
        input.mediaPacketCount = 1
        input.durationSeconds = 1
    })
}
