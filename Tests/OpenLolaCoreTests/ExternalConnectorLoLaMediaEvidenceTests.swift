// Verifies that LoLa dry-run session carries audio-video media evidence.
import Testing

@testable import OpenLolaCore

@Test
func lolaDryRunSessionCarriesAudioVideoMediaEvidence() throws {
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-session-media.json"
) { input in
  input.localHost = "192.0.2.10"
  input.mediaMode = .audioVideo
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoBitsPerPixel = 8
}))

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
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .rx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-session-media-rx.json"
) { input in
  input.localHost = "192.0.2.10"
  input.mediaMode = .audioVideo
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoBitsPerPixel = 8
}))

    try report.validate()
    #expect(report.lolaMedia?.role == .rx)
    #expect(report.lolaMedia?.audioFrameCount == 1)
    #expect(report.lolaMedia?.videoFrameCount == 2)
    #expect(report.lolaMedia?.envelopeValidatedFrameCount == 3)
}

@Test
func lolaRawLinkReceiveSessionThreadsDurationIntoMediaTimeout() throws {
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .rx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-session-media-rx-timeout.json"
) { input in
  input.localHost = "192.0.2.10"
  input.dryRun = true
  input.mediaMode = .audioVideo
  input.durationSeconds = 4
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoBitsPerPixel = 8
  input.rawLinkInterface = "en0"
}))

    try report.validate()
    #expect(report.lolaMedia?.role == .rx)
    #expect(report.lolaMedia?.verdict == .fail)
}

@Test
func lolaRuntimeTimeoutWritesFailureReportWithMediaEvidence() throws {
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "127.0.0.1",
  outputPath: "/tmp/lola-session-timeout.json"
) { input in
  input.localHost = "127.0.0.1"
  input.dryRun = false
  input.mediaMode = .audioVideo
  input.durationSeconds = 1
  input.controlPort = 9
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoBitsPerPixel = 8
}))

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
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: "127.0.0.1",
  outputPath: "/tmp/lola-session-nat-preflight.json"
) { input in
  input.localHost = "203.0.113.10"
  input.dryRun = false
  input.mediaMode = .audioVideo
  input.durationSeconds = 1
  input.controlPort = 9
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoBitsPerPixel = 8
}))

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.notes.contains("advertised LoLa local host 203.0.113.10 is not assigned"))
    #expect(report.notes.contains("public IPv4 address with no NAT/firewall"))
}
