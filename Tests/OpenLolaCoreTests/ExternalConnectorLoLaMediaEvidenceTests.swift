import Testing

@testable import OpenLolaCore

@Test
func lolaDryRunSessionCarriesAudioVideoMediaEvidence() throws {
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-session-media.json",
        mediaMode: .audioVideo,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    ))

    try report.validate()
    #expect(report.dryRun)
    #expect(report.lolaControl == nil)
    #expect(report.lolaMedia?.role == .tx)
    #expect(report.lolaMedia?.audioFrameCount == 1)
    #expect(report.lolaMedia?.videoFrameCount == 2)
    #expect(report.lolaMedia?.envelopeValidatedFrameCount == 3)
    #expect(report.lolaMedia?.verdict == .partial)
}

@Test
func lolaReceiveDryRunSessionCarriesDecodedMediaEvidence() throws {
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-session-media-rx.json",
        mediaMode: .audioVideo,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    ))

    try report.validate()
    #expect(report.lolaMedia?.role == .rx)
    #expect(report.lolaMedia?.audioFrameCount == 1)
    #expect(report.lolaMedia?.videoFrameCount == 2)
    #expect(report.lolaMedia?.envelopeValidatedFrameCount == 3)
}

@Test
func lolaRawLinkReceiveSessionThreadsDurationIntoMediaTimeout() throws {
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-session-media-rx-timeout.json",
        dryRun: true,
        mediaMode: .audioVideo,
        durationSeconds: 4,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8,
        rawLinkInterface: "en0"
    ))

    try report.validate()
    #expect(report.lolaMedia?.role == .rx)
    #expect(report.lolaMedia?.verdict == .fail)
}

@Test
func lolaRuntimeTimeoutWritesFailureReportWithMediaEvidence() throws {
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "127.0.0.1",
        localHost: "127.0.0.1",
        outputPath: "/tmp/lola-session-timeout.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1,
        controlPort: 9,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    ))

    try report.validate()
    #expect(!report.dryRun)
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "receiveTimedOut")
    #expect(report.lolaControl?.sentMessages.count == 2)
    #expect(report.lolaControl?.sentMessages.first?.hasPrefix("/MESG_CHECKLOLASTATUS") == true)
    #expect(report.lolaControl?.sentMessages.last?.hasPrefix("/MESG_QUICKCONN") == true)
    #expect(report.lolaControl?.receivedMessages.isEmpty == true)
    #expect(report.lolaMedia?.audioFrameCount == 1)
    #expect(report.lolaMedia?.videoFrameCount == 2)
}

@Test
func lolaRuntimeFailureNotesAdvertisedHostThatIsNotLocalInterface() throws {
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "127.0.0.1",
        localHost: "203.0.113.10",
        outputPath: "/tmp/lola-session-nat-preflight.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 1,
        controlPort: 9,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8
    ))

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.notes.contains("advertised LoLa local host 203.0.113.10 is not assigned"))
    #expect(report.notes.contains("public IPv4 address with no NAT/firewall"))
}
