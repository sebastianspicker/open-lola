// Verifies that LoLa control loopback exchanges a quick-connect ACK.
import Foundation
import Darwin
import Testing

@testable import OpenLolaCore

@Test
func lolaControlLoopbackExchangesQuickConnectAck() async throws {
    try await SocketHeavyTestGate.shared.run {
        let (txReport, acceptedRxReport) = try await acceptedLoLaLoopbackReports()
        try assertQuickConnectTxReport(txReport)
        try assertQuickConnectRxReport(acceptedRxReport)
    }
}
private func acceptedLoLaLoopbackReports() async throws
    -> (tx: ExternalConnectorSessionReport, rx: ExternalConnectorSessionReport) {
    var reports: (tx: ExternalConnectorSessionReport, rx: ExternalConnectorSessionReport)?
    for _ in 0..<3 {
        let (receiver, transmitter) = try lolaLoopbackConfigurations()
        let receiverReady = ExternalConnectorReadinessGate()
        let waitForRxReport = runExternalConnectorSessionInBackground(
            receiver,
            onLoLaControlReady: { Task { await receiverReady.signal() } }
        )
        #expect(await receiverReady.wait(timeout: .seconds(3)))
        let txReport = try ExternalConnectorSessionRunner.run(configuration: transmitter)
        let acceptedRxReport = try waitForRxReport()
        reports = (txReport, acceptedRxReport)
        if lolaLoopbackReportsCompleted(txReport, acceptedRxReport) {
            break
        }
    }
    return try #require(reports)
}
private func lolaLoopbackConfigurations() throws
    -> (receiver: ExternalConnectorSessionConfiguration, transmitter: ExternalConnectorSessionConfiguration) {
    let controlPort = try freeLoopbackUdpPort()
    let mediaPorts: (audio: UInt16, video: UInt16) = (
        try freeLoopbackUdpPort(),
        try freeLoopbackUdpPort()
    )
    let receiver = lolaLoopbackConfiguration(
        role: .rx, peer: "", outputPath: "/tmp/lola-rx.json", controlPort: controlPort, mediaPorts: mediaPorts
    )
    let transmitter = lolaLoopbackConfiguration(
        role: .tx, peer: "127.0.0.1", outputPath: "/tmp/lola-tx.json", controlPort: controlPort, mediaPorts: mediaPorts
    )
    return (receiver, transmitter)
}

private func lolaLoopbackConfiguration(
    role: ExternalConnectorSessionRole,
    peer: String,
    outputPath: String,
    controlPort: UInt16,
    mediaPorts: (audio: UInt16, video: UInt16)
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: role,
  peer: peer,
  outputPath: outputPath
) { input in
  input.localHost = "127.0.0.1"
  input.dryRun = false
  input.durationSeconds = 8
  input.controlPort = controlPort
  input.audioPort = mediaPorts.audio
  input.videoPort = mediaPorts.video
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoFrameRate = 60
  input.videoBitsPerPixel = 8
  input.sessionID = "42"
})
}
private func lolaLoopbackReportsCompleted(
    _ txReport: ExternalConnectorSessionReport,
    _ acceptedRxReport: ExternalConnectorSessionReport
) -> Bool {
    txReport.lolaControl?.parsedMessageName == "/MESG_QUICKCONN_ACK"
        && acceptedRxReport.lolaControl?.parsedMessageName == "/MESG_QUICKCONN"
        && txReport.lolaMedia?.realLinkTransmitted == true
        && (txReport.lolaMedia?.sentBytesTotal ?? 0) > 0
        && acceptedRxReport.lolaMedia?.realLinkTransmitted == true
        && (acceptedRxReport.lolaMedia?.envelopeValidatedFrameCount ?? 0) > 0
}
func assertQuickConnectAckControl(_ report: ExternalConnectorSessionReport) throws {
    try report.validate()
    #expect(report.lolaControl?.parsedMessageName == "/MESG_QUICKCONN_ACK")
    #expect(report.lolaControl?.sentMessages.count == 2)
    #expect(report.lolaControl?.receivedMessages.count == 2)
    #expect(report.lolaControl?.sentMessages.first?.hasPrefix("/MESG_CHECKLOLASTATUS") == true)
}

private func assertQuickConnectTxReport(_ txReport: ExternalConnectorSessionReport) throws {
    try assertQuickConnectAckControl(txReport)
    #expect(txReport.lolaControl?.receivedMessages.first?.hasPrefix("/MESG_CHECKLOLASTATUS_ACK") == true)
    #expect(txReport.lolaControl?.fields["SID"] == "42")
    #expect(txReport.lolaControl?.fields["FPS"] == "60")
    #expect(txReport.lolaControl?.fields["X"] == "16")
    let txMedia = try #require(txReport.lolaMedia)
    #expect(txMedia.realLinkTransmitted == true)
    #expect(txMedia.runtimeError == nil)
    #expect((txMedia.sentBytesTotal ?? 0) > 0)
}
private func assertQuickConnectRxReport(_ acceptedRxReport: ExternalConnectorSessionReport) throws {
    try acceptedRxReport.validate()
    #expect(acceptedRxReport.lolaControl?.parsedMessageName == "/MESG_QUICKCONN")
    #expect(acceptedRxReport.lolaControl?.receivedMessages.count == 2)
    #expect(acceptedRxReport.lolaControl?.sentMessages.count == 2)
    #expect(acceptedRxReport.lolaControl?.receivedMessages.first?.hasPrefix("/MESG_CHECKLOLASTATUS") == true)
    #expect(acceptedRxReport.lolaControl?.sentMessages.first?.hasPrefix("/MESG_CHECKLOLASTATUS_ACK") == true)
    #expect(acceptedRxReport.lolaControl?.sentMessage?.hasPrefix("/MESG_QUICKCONN_ACK") == true)
    #expect(acceptedRxReport.lolaControl?.fields["Y"] == "16")
    let rxMedia = try #require(acceptedRxReport.lolaMedia)
    #expect(rxMedia.realLinkTransmitted == true)
    #expect(rxMedia.runtimeError == nil)
    #expect(rxMedia.envelopeValidatedFrameCount > 0)
}
@Test
func externalConnectorSessionRejectsInvalidReportContracts() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .tx,
  peer: "198.51.100.10",
  outputPath: "/tmp/ug-session.json"
))
    var report = try ExternalConnectorSessionRunner.run(configuration: configuration)
    report.verdict = .pass
    #expect(throws: ExternalConnectorSessionError.dryRunCannotPass) {
        try report.validate()
    }

    let jackTripConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-session.json"
) { input in
  input.peerAudioPort = 4464
})
    var jackTripReport = try ExternalConnectorSessionRunner.run(configuration: jackTripConfiguration)
    jackTripReport.plan.sourceReferences = []

    #expect(throws: ExternalConnectorSessionError.emptyList("plan.sourceReferences")) {
        try jackTripReport.validate()
    }

    let ultraGridConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .tx,
  peer: "198.51.100.10",
  outputPath: "/tmp/ug-session.json"
))
    var ultraGridReport = try ExternalConnectorSessionRunner.run(configuration: ultraGridConfiguration)
    ultraGridReport.plan.sourceReferences = ["https://example.invalid/ultragrid-not-authoritative"]

    #expect(throws: ExternalConnectorSessionError.missingSourceReference(.mvtpUltraGrid)) {
        try ultraGridReport.validate()
    }
}
@Test
// swiftlint:disable:next function_body_length
func externalConnectorSessionPassRequiresNestedMediaRuntimeProof() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .tx,
  peer: "198.51.100.10",
  outputPath: "/tmp/ug-pass-proof.json"
) { input in
  input.dryRun = false
})
    let plan = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    var report = { () -> ExternalConnectorSessionReport in
  var input = ExternalConnectorSessionReportInput(
    id: "external-connector-missing-media-pass",
    capturedAt: "2026-05-20T00:00:00Z",
    connector: .mvtpUltraGrid,
    role: .tx,
    dryRun: false,
    plan: plan,
    verdict: .pass,
    notes: "False PASS fixture shape: outer report claims PASS without nested media proof."
  )
  input.process = nil
  input.lolaControl = nil
  return ExternalConnectorSessionReport(input)
}()

    #expect(throws: ExternalConnectorSessionError.runtimePassMissingEvidence("ultraGridMedia")) {
        try report.validate()
    }

    report.ultraGridMedia = UltraGridCompatibilityMediaReport(UltraGridCompatibilityMediaReportInput(
        identity: UltraGridCompatibilityMediaIdentity(
            id: "ultragrid-runtime-error-partial",
            capturedAt: "2026-05-20T00:00:00Z",
            role: .tx,
            mediaMode: .audio
        ),
        packets: UltraGridCompatibilityPacketSummary(
            datagrams: [],
            transmittedDatagramCount: 1,
            receivedDatagramCount: 0
        ),
        evidence: UltraGridCompatibilityEvidenceState(
            observedEvidenceClasses: ExternalConnectorEvidenceClass.runtimePassRequiredEvidence,
            missingEvidenceClassesForPass: [.teardown],
            realLinkTransmitted: true,
            verdict: .partial,
            runtimeError: "nested media socket failure",
            notes: "Nested report carries runtime error despite outer PASS."
        )
    ))

    #expect(throws: ExternalConnectorSessionError.runtimePassWithRuntimeError("ultraGridMedia.runtimeError")) {
        try report.validate()
    }
}
