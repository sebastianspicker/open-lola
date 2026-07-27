// Verifies that external connector session runner reports dry runs and process runs.
import Foundation
import Darwin
import Testing

@testable import OpenLolaCore

@Test
func externalConnectorSessionRunnerReportsDryRunsAndProcessRuns() throws {
    let dryRunConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-session.json"
) { input in
  input.peerAudioPort = 4464
})

    let report = try ExternalConnectorSessionRunner.run(configuration: dryRunConfiguration)

    try report.validate()
    #expect(report.dryRun)
    #expect(report.verdict == .partial)
    #expect(report.process == nil)

    let avConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-av-session.json"
) { input in
  input.mediaMode = .audioVideo
  input.peerAudioPort = 4464
})

    let avReport = try ExternalConnectorSessionRunner.run(configuration: avConfiguration)

    try avReport.validate()
    #expect(avReport.dryRun)
    #expect(avReport.plan.auxiliaryProcesses.count == 1)
    #expect(avReport.plan.auxiliaryProcesses[0].label == "jacktrip-auxiliary-ultragrid-video")
    #expect(avReport.auxiliaryProcesses.isEmpty)
}
@Test
func externalConnectorSessionRunnerReportsProcessRuns() throws {
    let processRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 47_002,
            terminatedAfterDuration: true
        )
    ])
    let processConfiguration = ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-av-process.json"
) { input in
  input.executable = "/definitely/not/jacktrip"
  input.videoExecutable = "/definitely/not/uv"
  input.dryRun = false
  input.mediaMode = .audioVideo
  input.peerAudioPort = 4464
})

    let processReport = try ExternalConnectorSessionRunner.run(
        configuration: processConfiguration,
        processRunner: processRunner
    )

    try processReport.validate()
    #expect(processReport.process == nil)
    #expect(processReport.jackTripMedia?.transmittedDatagramCount == 1)
    #expect(processReport.auxiliaryProcesses.count == 1)
    #expect(processReport.auxiliaryProcesses[0].launched)
    #expect(processReport.plan.auxiliaryProcesses[0].mediaMode == .video)
    #expect(processRunner.invocations.map(\.executable) == [
        "/definitely/not/uv"
    ])
}
@Test
func externalConnectorSessionRunnerReportsJackGraphBackendPrerequisiteFailure() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-jack-graph-session.json"
) { input in
  input.dryRun = false
  input.peerAudioPort = 4464
  input.jackTrip = JackTripRunConfiguration { $0.audioBackend = .jackGraph }
})

    let report = try ExternalConnectorSessionRunner.run(
        configuration: configuration,
        processRunner: MockExternalConnectorProcessRunner(results: [])
    )

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.jackTripMedia == nil)
    #expect(report.runtimeError?.contains(
        "jacktrip-native-audio-backend-jack-graph"
    ) == true)
    #expect(report.plan.protocolFacts.contains {
        $0.contains("jack-graph requires measured JACK graph capture evidence")
    })
}
@Test
func connectorReport_partialWithRuntimeError_hasRuntimeErrorFreeFalse() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-partial-runtime-error.json"
) { input in
  input.peerAudioPort = 4464
})
    let plan = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    let report = { () -> ExternalConnectorSessionReport in
  var input = ExternalConnectorSessionReportInput(
    id: "external-connector-runtime-error-partial",
    capturedAt: "2026-05-19T00:00:00Z",
    connector: .jackTrip,
    role: .tx,
    dryRun: false,
    plan: plan,
    verdict: .partial,
    notes: "Partial report with explicit runtime error diagnostic."
  )
  input.process = nil
  input.lolaControl = nil
  input.runtimeError = "socket failure after partial media evidence"
  return ExternalConnectorSessionReport(input)
}()
    let ultraGridMedia = partialUltraGridMediaReportWithRuntimeError()
    let jackTripMedia = partialJackTripMediaReportWithRuntimeError()

    try report.validate()
    try ultraGridMedia.validate()
    try jackTripMedia.validate()

    #expect(report.runtimeErrorFree == false)
    #expect(ultraGridMedia.runtimeErrorFree == false)
    #expect(jackTripMedia.runtimeErrorFree == false)
}
private func partialUltraGridMediaReportWithRuntimeError() -> UltraGridCompatibilityMediaReport {
    UltraGridCompatibilityMediaReport(UltraGridCompatibilityMediaReportInput(
        identity: UltraGridCompatibilityMediaIdentity(
            id: "ultragrid-runtime-error-partial",
            capturedAt: "2026-05-19T00:00:00Z",
            role: .tx,
            mediaMode: .audioVideo
        ),
        packets: UltraGridCompatibilityPacketSummary(
            datagrams: [],
            transmittedDatagramCount: 0,
            receivedDatagramCount: 0
        ),
        evidence: UltraGridCompatibilityEvidenceState(
            realLinkTransmitted: false,
            verdict: .partial,
            runtimeError: "socket failure after partial media evidence",
            notes: "Partial UltraGrid media report with explicit runtime error diagnostic."
        )
    ))
}
private func partialJackTripMediaReportWithRuntimeError() -> JackTripCompatibilityMediaReport {
    jackTripCompatibilityMediaReport {
        $0.id = "jacktrip-runtime-error-partial"
        $0.capturedAt = "2026-05-19T00:00:00Z"
        $0.role = .tx
        $0.realLinkTransmitted = false
        $0.verdict = .partial
        $0.runtimeError = "socket failure after partial media evidence"
        $0.notes = "Partial JackTrip media report with explicit runtime error diagnostic."
    }
}
@Test
func connectorReport_partialWithoutRuntimeError_hasRuntimeErrorFreeTrue() throws {
    let lolaConfiguration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .rx,
        peer: "",
        outputPath: "/tmp/lola-dry-run-runtime-error-free.json"
    ) { input in
        input.dryRun = true
    })
    let lolaReport = try ExternalConnectorSessionRunner.run(configuration: lolaConfiguration)
    let ultraGridConfiguration = ExternalConnectorSessionConfiguration(.init(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ultragrid-runtime-error-free.json"
    ) { input in
        input.dryRun = false
    })
    let ultraGridReport = try ExternalConnectorSessionRunner.run(
        configuration: ultraGridConfiguration
    )
    let jackTripConfiguration = ExternalConnectorSessionConfiguration(.init(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-runtime-error-free.json"
    ) { input in
        input.dryRun = false
        input.peerAudioPort = 4464
    })
    let jackTripReport = try ExternalConnectorSessionRunner.run(
        configuration: jackTripConfiguration
    )

    try lolaReport.validate()
    try ultraGridReport.validate()
    try jackTripReport.validate()

    #expect(lolaReport.verdict == .partial)
    #expect(lolaReport.runtimeError == nil)
    #expect(lolaReport.runtimeErrorFree == true)
    #expect(ultraGridReport.verdict == .partial)
    #expect(ultraGridReport.runtimeError == nil)
    #expect(ultraGridReport.runtimeErrorFree == true)
    #expect(ultraGridReport.ultraGridMedia?.runtimeErrorFree == true)
    #expect(jackTripReport.verdict == .partial)
    #expect(jackTripReport.runtimeError == nil)
    #expect(jackTripReport.runtimeErrorFree == true)
    #expect(jackTripReport.jackTripMedia?.runtimeErrorFree == true)
}
