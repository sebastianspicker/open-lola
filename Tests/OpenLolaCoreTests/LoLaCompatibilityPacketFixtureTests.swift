import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaPacketFixtureRunnerWritesDecodableSyntheticPcapWithoutPromotingPass() throws {
    let artifactDirectory = try makeLoLaPacketFixtureArtifactDirectory()
    defer { try? FileManager.default.removeItem(at: artifactDirectory) }
    let reportPath = artifactDirectory.appendingPathComponent("report.json").path
    let capturePath = artifactDirectory.appendingPathComponent("fixture.pcap").path
    let report = try LoLaCompatibilityPacketFixtureRunner.run(
        configuration: LoLaCompatibilityPacketFixtureRunConfiguration(
            outputPath: reportPath,
            captureOutputPath: capturePath,
            videoWidth: 16,
            videoHeight: 16,
            videoBitsPerPixel: 8,
            packetCount: 2
        )
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.frames.count == 6)
    #expect(report.decodedCapturePacketCount == 6)
    #expect(report.decodedMediaEnvelopePacketCount == 6)
    #expect(report.decodedPayloadCandidates == [
        .audioFragment, .videoPrelude, .videoFragment,
        .audioFragment, .videoPrelude, .videoFragment,
    ])
    #expect(report.notes.contains("not a Windows LoLa capture"))
    #expect(FileManager.default.fileExists(atPath: capturePath))

    let decoded = try LoLaCompatibilityCaptureDecoder.decode(
        inputPath: capturePath
    )
    try decoded.validate()
    #expect(decoded.summary.packetCount == 6)
    #expect(decoded.summary.audioPacketCount == 2)
    #expect(decoded.summary.videoPacketCount == 4)
}

@Test
func lolaPacketFixtureConfigurationRejectsUnknownArguments() {
    #expect(throws: ExternalConnectorSessionError.unknownArgument("--bad")) {
        _ = try LoLaCompatibilityPacketFixtureRunConfiguration.parse([
            "--output", "/tmp/lola-packet-fixture.json",
            "--bad", "value",
        ])
    }
}

@Test
func lolaPacketFixtureTestArtifactsUseUniqueTemporaryDirectory() throws {
    let first = try makeLoLaPacketFixtureArtifactDirectory()
    let second = try makeLoLaPacketFixtureArtifactDirectory()
    defer {
        try? FileManager.default.removeItem(at: first)
        try? FileManager.default.removeItem(at: second)
    }

    #expect(first != second)
    #expect(first.path.hasPrefix(FileManager.default.temporaryDirectory.path))
    #expect(second.path.hasPrefix(FileManager.default.temporaryDirectory.path))
    #expect(FileManager.default.fileExists(atPath: first.path))
    #expect(FileManager.default.fileExists(atPath: second.path))
}

private func makeLoLaPacketFixtureArtifactDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-lola-packet-fixture-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
