// Verifies command parsing and injected transport composition at the Application boundary.
import Foundation
import OpenLolaApplication
import Testing

@Test func transportCLIParserReportsDuplicateBeforeTheRepeatedValueIsMissing() {
    #expect(throws: KeyValueArgumentError.duplicateArgument("--peer")) {
        _ = try KeyValueArgumentParser.parseValuesCheckingDuplicatesFirst(
            ["--peer", "127.0.0.1", "--peer"],
            allowed: ["--peer"],
            unknown: KeyValueArgumentError.unknownArgument,
            duplicate: KeyValueArgumentError.duplicateArgument,
            missingValue: KeyValueArgumentError.missingValue
        )
    }
}

@Test func rawLinkConfigurationComposesWithInjectedTransmitterIntoObservedReport() throws {
    let configuration = try LoLaRawLinkTransmitRunConfiguration.parse([
        "--interface", "lo0",
        "--source-ip", "192.0.2.10",
        "--peer", "198.51.100.20",
        "--source-mac", "00:11:22:33:44:55",
        "--destination-mac", "66:77:88:99:aa:bb",
        "--output", "/tmp/open-lola-behavioral-report.json",
        "--packets", "1",
        "--media", "audio",
        "--dry-run", "true"
    ])
    let transmitter = RecordingRawLinkTransmitter()

    let report = try LoLaRawLinkTransmitRunner.run(
        configuration: configuration,
        transmitter: transmitter
    )

    #expect(transmitter.transmittedFrames == report.frames.map(\.encodedFrame))
    #expect(report.role == .tx)
    #expect(report.mediaMode == .audio)
    #expect(report.expectedDatagramCount == transmitter.transmittedFrames.count)
    #expect(report.sentBytesTotal == transmitter.transmittedFrames.reduce(0) { $0 + $1.count })
    #expect(report.realLinkTransmitted == false)
}

private final class RecordingRawLinkTransmitter: LoLaRawLinkTransmitter {
    private(set) var transmittedFrames: [Data] = []

    func transmit(_ frames: [LoLaCompatibilityMediaFrame]) throws -> [Int] {
        transmittedFrames.append(contentsOf: frames.map(\.encodedFrame))
        return frames.map(\.wireByteCount)
    }
}
