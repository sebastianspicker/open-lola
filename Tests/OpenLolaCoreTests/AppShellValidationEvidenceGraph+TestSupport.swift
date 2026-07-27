// Shared App shell validation evidence graph helpers keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

struct AppSupervisorReportInput {
  let id: String
  let runDirectory: String
  let processResults: [DirectPeerTwoPeerLocalRunProcessResult]
  let aggregation: DirectPeerTwoPeerLocalRunReport.Aggregation
  let preflightChecks: [DirectPeerTwoPeerPreflightCheck]
  let verdict: MeasurementVerdict
  let notes: String
}

func appSupervisorReport(_ input: AppSupervisorReportInput) -> DirectPeerTwoPeerLocalRunReport {
  let metadata = DirectPeerTwoPeerLocalRunReport.Metadata(
    id: input.id,
    capturedAt: "2026-05-15T00:00:00Z",
    planID: "plan",
    runDirectory: input.runDirectory
  )
  let processExecution = DirectPeerTwoPeerLocalRunReport.ProcessExecution(
    executed: true,
    processResults: input.processResults
  )
  let evidence = DirectPeerTwoPeerLocalRunReport.Evidence(
    preflightChecks: input.preflightChecks,
    gates: ["unit"],
    verdict: input.verdict,
    notes: input.notes
  )
  let reportInput = DirectPeerTwoPeerLocalRunReport.Input(
    metadata: metadata,
    processExecution: processExecution,
    aggregation: input.aggregation,
    evidence: evidence
  )
  return DirectPeerTwoPeerLocalRunReport(reportInput)
}

@MainActor
func withInvalidDirectPeerPassGraphFixture(_ body: AppInvalidPassGraphFixtureBody) throws {

  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(
      "open-lola-app-invalid-pass-graph-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  let passAURL = directory.appendingPathComponent("peer-a-pass.json")
  let passBURL = directory.appendingPathComponent("peer-b-pass.json")
  let partialBURL = directory.appendingPathComponent("peer-b-partial.json")
  let invalidBURL = directory.appendingPathComponent("peer-b-invalid.json")
  try appMeasuredPassDirectPeerSessionReport(id: "peer-a-pass", peerID: "peer-a")
    .prettyJSONData()
    .write(to: passAURL)
  try appMeasuredPassDirectPeerSessionReport(id: "peer-b-pass", peerID: "peer-b")
    .prettyJSONData()
    .write(to: passBURL)
  try appDirectPeerSessionReport(
    id: "peer-b-partial",
    packetsReceived: 90,
    packetsLost: 0,
    jitterMicroseconds: 2_500,
    latencyMicroseconds: 1_200
  ).prettyJSONData().write(to: partialBURL)
  var invalidChild = appMeasuredPassDirectPeerSessionReport(id: "peer-b-invalid", peerID: "peer-b")
  invalidChild.metrics.packetsReceived = -1
  try invalidChild.prettyJSONData().write(to: invalidBURL)

  let validProcessResults = [
    appProcessResult(
      peerID: "peer-a",
      reportPath: passAURL.path,
      receiveProofPath: directory.appendingPathComponent("peer-a-rx-proof.json").path
    ),
    appProcessResult(
      peerID: "peer-b",
      reportPath: passBURL.path,
      receiveProofPath: directory.appendingPathComponent("peer-b-rx-proof.json").path
    )
  ]
  let preflightChecks = [
    DirectPeerTwoPeerPreflightCheck(id: "unit", severity: .pass, passed: true, message: "ok")
  ]

  try body(.init(
    directory: directory,
    validProcessResults: validProcessResults,
    preflightChecks: preflightChecks,
    partialBURL: partialBURL,
    invalidBURL: invalidBURL
  ))
}

@MainActor
func appAssertInvalidSupervisorPassReportGraph() throws {
  try withInvalidDirectPeerPassGraphFixture { fixture in
    let invalidSupervisorURL = fixture.directory.appendingPathComponent("supervisor-invalid-pass.json")
    let aggregation = DirectPeerTwoPeerLocalRunReport.Aggregation(
      command: ["open-lola", "direct-p2p-two-peer-local-run"]
    )
    let reportInput = AppSupervisorReportInput(
      id: "supervisor-invalid-pass",
      runDirectory: fixture.directory.path,
      processResults: fixture.validProcessResults,
      aggregation: aggregation,
      preflightChecks: fixture.preflightChecks,
      verdict: .pass,
      notes: "unit test invalid pass supervisor"
    )
    try appSupervisorReport(reportInput).prettyJSONData().write(to: invalidSupervisorURL)

    let invalidSupervisorController = AppExecutionController(
      settings: {
        var settings = NativeAppShellExecutionSettings()
        settings.supervisorReportPath = invalidSupervisorURL.path
        return settings
      }())
    invalidSupervisorController.finishValidation(exitCode: 0)

    #expect(invalidSupervisorController.phase == .validationFailed)
    #expect(!invalidSupervisorController.hasValidatedRuntimeEvidence)
    #expect(invalidSupervisorController.lastLatencyMetrics == nil)
    #expect(
      invalidSupervisorController.lastError?.contains(
        "Validated supervisor report missing or unreadable") == true
    )
  }
}

@MainActor
func appAssertPartialChildPassReportGraph() throws {
  try withInvalidDirectPeerPassGraphFixture { fixture in
    let partialChildSupervisorURL = fixture.directory.appendingPathComponent(
      "supervisor-partial-child.json")
    let processResults = [
      fixture.validProcessResults[0],
      appProcessResult(
        peerID: "peer-b",
        reportPath: fixture.partialBURL.path,
        receiveProofPath: fixture.directory.appendingPathComponent("peer-b-partial-rx-proof.json").path
      )
    ]
    let aggregation = DirectPeerTwoPeerLocalRunReport.Aggregation(
      command: ["open-lola", "direct-p2p-two-peer-local-run"],
      reportPath: fixture.directory.appendingPathComponent("aggregate-partial-child.json").path,
      executed: true
    )
    let reportInput = AppSupervisorReportInput(
      id: "supervisor-partial-child",
      runDirectory: fixture.directory.path,
      processResults: processResults,
      aggregation: aggregation,
      preflightChecks: fixture.preflightChecks,
      verdict: .pass,
      notes: "unit test partial child supervisor"
    )
    try appSupervisorReport(reportInput).prettyJSONData().write(to: partialChildSupervisorURL)

    var partialChildSettings = NativeAppShellExecutionSettings()
    partialChildSettings.supervisorReportPath = partialChildSupervisorURL.path
    let partialChildController = AppExecutionController(settings: partialChildSettings)
    partialChildController.finishValidation(exitCode: 0)

    #expect(partialChildController.phase == .validationFailed)
    #expect(!partialChildController.hasValidatedRuntimeEvidence)
    #expect(
      partialChildController.lastLatencyMetrics?.peerReportFailures.contains {
        $0.contains("peer-b-partial") && $0.contains("partial")
      } == true)
    #expect(partialChildController.lastError?.contains("peer report verdict partial") == true)
  }
}

@MainActor
func appAssertInvalidChildPassReportGraph() throws {
  try withInvalidDirectPeerPassGraphFixture { fixture in
    let invalidChildSupervisorURL = fixture.directory.appendingPathComponent(
      "supervisor-invalid-child.json")
    let processResults = [
      fixture.validProcessResults[0],
      appProcessResult(
        peerID: "peer-b",
        reportPath: fixture.invalidBURL.path,
        receiveProofPath: fixture.directory.appendingPathComponent("peer-b-invalid-rx-proof.json").path
      )
    ]
    let aggregation = DirectPeerTwoPeerLocalRunReport.Aggregation(
      command: ["open-lola", "direct-p2p-two-peer-local-run"],
      reportPath: fixture.directory.appendingPathComponent("aggregate-invalid-child.json").path,
      executed: true
    )
    let reportInput = AppSupervisorReportInput(
      id: "supervisor-invalid-child",
      runDirectory: fixture.directory.path,
      processResults: processResults,
      aggregation: aggregation,
      preflightChecks: fixture.preflightChecks,
      verdict: .pass,
      notes: "unit test invalid child supervisor"
    )
    try appSupervisorReport(reportInput).prettyJSONData().write(to: invalidChildSupervisorURL)

    var invalidChildSettings = NativeAppShellExecutionSettings()
    invalidChildSettings.supervisorReportPath = invalidChildSupervisorURL.path
    let invalidChildController = AppExecutionController(settings: invalidChildSettings)
    invalidChildController.finishValidation(exitCode: 0)

    #expect(invalidChildController.phase == .validationFailed)
    #expect(!invalidChildController.hasValidatedRuntimeEvidence)
    #expect(
      invalidChildController.lastLatencyMetrics?.loadFailures.contains {
        $0.contains("peer-b") && $0.contains("negativeMetric")
      } == true)
    #expect(invalidChildController.lastError?.contains("peer-b") == true)
  }
}

@MainActor
@Test
func appExecutionValidationRejectsInvalidDirectPeerPassReportGraph() throws {
try appAssertPartialChildPassReportGraph()
try appAssertInvalidChildPassReportGraph()
}
