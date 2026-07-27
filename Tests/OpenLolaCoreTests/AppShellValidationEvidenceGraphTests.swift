// Verifies that app execution validation requires complete current report evidence.
import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

struct AppSupervisorFixture {
  let directory: URL
  let processResults: [DirectPeerTwoPeerLocalRunProcessResult]
  let preflightChecks: [DirectPeerTwoPeerPreflightCheck]
  let partialSupervisorURL: URL
  let failedSupervisorURL: URL
  let passSupervisorURL: URL
  let passReportAURL: URL
  let passReportBURL: URL
}

struct AppInvalidPassGraphFixture {
  let directory: URL
  let validProcessResults: [DirectPeerTwoPeerLocalRunProcessResult]
  let preflightChecks: [DirectPeerTwoPeerPreflightCheck]
  let partialBURL: URL
  let invalidBURL: URL
}

typealias AppSupervisorFixtureBody = (AppSupervisorFixture) throws -> Void
typealias AppInvalidPassGraphFixtureBody = (AppInvalidPassGraphFixture) throws -> Void

@MainActor
@Test
func appExecutionValidationRequiresCompleteCurrentReportEvidence() throws {
  try appAssertMissingSupervisorValidationEvidence()
  try appAssertMissingWindowsLoLaValidationEvidence()
  try appAssertMalformedExternalConnectorValidationEvidence()
  try appAssertExternalConnectorVerdictValidationEvidence()
  try appAssertFalsePassExternalConnectorValidationEvidence()
  try appAssertPartialSupervisorValidationEvidence()
  try appAssertFailedSupervisorValidationEvidence()
  try appAssertPassingSupervisorValidationEvidence()
}

@MainActor
private func withAppValidationDirectory(
  prefix: String,
  _ body: (URL) throws -> Void
) throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  try body(directory)
}

@MainActor
private func appAssertMissingSupervisorValidationEvidence() throws {

  let missingSupervisorPath = "/private/tmp/open-lola-missing-supervisor-\(UUID().uuidString).json"
  var settings = NativeAppShellExecutionSettings()
  settings.supervisorReportPath = missingSupervisorPath
  let controller = AppExecutionController(settings: settings)
  controller.lastLatencyMetrics = AppLatencyHeroMetrics.make(from: [
    appDirectPeerSessionReport(
      id: "stale-peer-report",
      packetsReceived: 1,
      packetsLost: 0,
      jitterMicroseconds: 1,
      latencyMicroseconds: 1
    )
  ])

  controller.finishValidation(exitCode: 0)

  #expect(controller.phase == .validationFailed)
  #expect(controller.status == "Validation evidence incomplete.")
  #expect(!controller.hasValidatedRuntimeEvidence)
  #expect(controller.lastLatencyMetrics == nil)
  #expect(
    controller.lastError?.contains("Validated supervisor report missing or unreadable") == true)
}

@MainActor
private func appAssertMissingWindowsLoLaValidationEvidence() throws {
  var state = appOperatorState(remoteSelectionComplete: false)
  state.sessionMode = .windowsLoLa
  state.windowsLoLaPeerFields.executablePath = try requiredFreshOpenLolaCLIURL(
    context: "app validation evidence tests"
  ).path
  state.windowsLoLaPeerFields.outputPath =
    "/private/tmp/open-lola-missing-windows-lola-\(UUID().uuidString).json"
  let windowsController = AppExecutionController()

  _ = try windowsController.prepareValidationContext(operatorSurface: state)
  windowsController.finishValidation(exitCode: 0)

  #expect(windowsController.phase == .validationFailed)
  #expect(windowsController.status == "Validation evidence incomplete.")
  #expect(!windowsController.hasValidatedRuntimeEvidence)
  #expect(windowsController.lastExternalConnectorReport == nil)
  #expect(
    windowsController.lastError?.contains(
      "Validated external connector report missing or unreadable") == true)
}

@MainActor
private func appAssertMalformedExternalConnectorValidationEvidence() throws {
  var state = appOperatorState(remoteSelectionComplete: false)
  state.sessionMode = .windowsLoLa
  state.windowsLoLaPeerFields.executablePath = try requiredFreshOpenLolaCLIURL(
    context: "app validation evidence tests"
  ).path

  try withAppValidationDirectory(prefix: "open-lola-app-validation") { directory in
    let malformedSupervisorURL = directory.appendingPathComponent("supervisor-malformed.json")
    try Data("{".utf8).write(to: malformedSupervisorURL)
    var malformedSupervisorSettings = NativeAppShellExecutionSettings()
    malformedSupervisorSettings.supervisorReportPath = malformedSupervisorURL.path
    let malformedSupervisorController = AppExecutionController(
      settings: malformedSupervisorSettings)

    malformedSupervisorController.finishValidation(exitCode: 0)

    #expect(malformedSupervisorController.phase == .validationFailed)
    #expect(malformedSupervisorController.status == "Validation evidence incomplete.")
    #expect(!malformedSupervisorController.hasValidatedRuntimeEvidence)
    #expect(malformedSupervisorController.lastLatencyMetrics == nil)
    #expect(
      malformedSupervisorController.lastError?.contains(
        "Validated supervisor report missing or unreadable") == true
    )

    let malformedWindowsReportURL = directory.appendingPathComponent("windows-malformed.json")
    try Data("{".utf8).write(to: malformedWindowsReportURL)
    state.windowsLoLaPeerFields.outputPath = malformedWindowsReportURL.path
    let malformedWindowsController = AppExecutionController()

    _ = try malformedWindowsController.prepareValidationContext(operatorSurface: state)
    malformedWindowsController.finishValidation(exitCode: 0)

    #expect(malformedWindowsController.phase == .validationFailed)
    #expect(malformedWindowsController.status == "Validation evidence incomplete.")
    #expect(!malformedWindowsController.hasValidatedRuntimeEvidence)
    #expect(malformedWindowsController.lastExternalConnectorReport == nil)
    #expect(
      malformedWindowsController.lastError?
        .contains("Validated external connector report missing or unreadable") == true
    )
    #expect(
      malformedWindowsController.errorLog.contains {
        $0.contains("External connector report unavailable")
      })

  }
}

@MainActor
private func appAssertExternalConnectorVerdictValidationEvidence() throws {
  var state = appOperatorState(remoteSelectionComplete: false)
  state.sessionMode = .windowsLoLa
  state.windowsLoLaPeerFields.executablePath = try requiredFreshOpenLolaCLIURL(
    context: "app validation evidence tests"
  ).path

  try withAppValidationDirectory(prefix: "open-lola-app-validation") { directory in
    let partialWindowsReportURL = directory.appendingPathComponent("windows-partial.json")
    try appExternalConnectorSessionReport(
      verdict: .partial, outputPath: partialWindowsReportURL.path
    )
    .prettyJSONData()
    .write(to: partialWindowsReportURL)
    state.windowsLoLaPeerFields.outputPath = partialWindowsReportURL.path
    let partialWindowsController = AppExecutionController()

    _ = try partialWindowsController.prepareValidationContext(operatorSurface: state)
    partialWindowsController.finishValidation(exitCode: 0)

    #expect(partialWindowsController.phase == .validationFailed)
    #expect(partialWindowsController.status == "Validation evidence incomplete.")
    #expect(partialWindowsController.lastValidationResult == .failed)
    #expect(partialWindowsController.lastValidationSummary.contains("FAILED"))
    #expect(!partialWindowsController.hasValidatedRuntimeEvidence)
    #expect(partialWindowsController.lastExternalConnectorReport?.verdict == .partial)
    #expect(
      partialWindowsController.lastError
        == "External connector evidence incomplete: no runtime error recorded; verdict partial "
        + "still requires measured evidence"
    )
    let failedWindowsReportURL = directory.appendingPathComponent("windows-fail.json")
    try appExternalConnectorSessionReport(verdict: .fail, outputPath: failedWindowsReportURL.path)
      .prettyJSONData()
      .write(to: failedWindowsReportURL)
    state.windowsLoLaPeerFields.outputPath = failedWindowsReportURL.path
    let failedWindowsController = AppExecutionController()

    _ = try failedWindowsController.prepareValidationContext(operatorSurface: state)
    failedWindowsController.finishValidation(exitCode: 0)

    #expect(failedWindowsController.phase == .validationFailed)
    #expect(failedWindowsController.status == "Validation evidence incomplete.")
    #expect(!failedWindowsController.hasValidatedRuntimeEvidence)
    #expect(failedWindowsController.lastExternalConnectorReport?.verdict == .fail)
    #expect(
      failedWindowsController.lastError
        == "External connector evidence incomplete: runtime error recorded; verdict fail"
    )

  }
}

@MainActor
private func appAssertFalsePassExternalConnectorValidationEvidence() throws {
  var state = appOperatorState(remoteSelectionComplete: false)
  state.sessionMode = .windowsLoLa
  state.windowsLoLaPeerFields.executablePath = try requiredFreshOpenLolaCLIURL(
    context: "app validation evidence tests"
  ).path

  try withAppValidationDirectory(prefix: "open-lola-app-validation") { directory in
    let falsePassWindowsReportURL = directory.appendingPathComponent("windows-pass.json")
    try appExternalConnectorSessionReport(
      verdict: .pass, outputPath: falsePassWindowsReportURL.path
    )
    .prettyJSONData()
    .write(to: falsePassWindowsReportURL)
    state.windowsLoLaPeerFields.outputPath = falsePassWindowsReportURL.path
    let falsePassWindowsController = AppExecutionController()

    _ = try falsePassWindowsController.prepareValidationContext(operatorSurface: state)
    falsePassWindowsController.finishValidation(exitCode: 0)

    #expect(falsePassWindowsController.phase == .validationFailed)
    #expect(falsePassWindowsController.status == "Validation evidence incomplete.")
    #expect(falsePassWindowsController.lastValidationResult == .failed)
    #expect(falsePassWindowsController.lastValidationSummary.contains("FAILED"))
    #expect(!falsePassWindowsController.hasValidatedRuntimeEvidence)
    #expect(falsePassWindowsController.lastExternalConnectorReport == nil)
    #expect(
      falsePassWindowsController.lastError?.contains(
        "Validated external connector report missing or unreadable"
      ) == true)
  }
}

@MainActor
private func withDirectPeerSupervisorValidationFixture(_ body: AppSupervisorFixtureBody) throws {
  try withAppValidationDirectory(prefix: "open-lola-app-validation-supervisor") { directory in
    let reportAURL = directory.appendingPathComponent("peer-a.json")
    let reportBURL = directory.appendingPathComponent("peer-b.json")
    let passReportAURL = directory.appendingPathComponent("peer-a-pass.json")
    let passReportBURL = directory.appendingPathComponent("peer-b-pass.json")
    let partialSupervisorURL = directory.appendingPathComponent("supervisor-partial.json")
    let failedSupervisorURL = directory.appendingPathComponent("supervisor-fail.json")
    let passSupervisorURL = directory.appendingPathComponent("supervisor-pass.json")
    try appDirectPeerSessionReport(
      id: "peer-a-report",
      packetsReceived: 90,
      packetsLost: 0,
      jitterMicroseconds: 2_500,
      latencyMicroseconds: 1_200
    ).prettyJSONData().write(to: reportAURL)
    try appDirectPeerSessionReport(
      id: "peer-b-report",
      packetsReceived: 90,
      packetsLost: 0,
      jitterMicroseconds: 2_500,
      latencyMicroseconds: 1_200
    ).prettyJSONData().write(to: reportBURL)
    let processResults = [
      appProcessResult(peerID: "peer-a", reportPath: reportAURL.path),
      appProcessResult(peerID: "peer-b", reportPath: reportBURL.path)
    ]
    let preflightChecks = [
      DirectPeerTwoPeerPreflightCheck(id: "unit", severity: .pass, passed: true, message: "ok")
    ]

    try body(.init(
      directory: directory,
      processResults: processResults,
      preflightChecks: preflightChecks,
      partialSupervisorURL: partialSupervisorURL,
      failedSupervisorURL: failedSupervisorURL,
      passSupervisorURL: passSupervisorURL,
      passReportAURL: passReportAURL,
      passReportBURL: passReportBURL
    ))
  }
}

@MainActor
private func appAssertPartialSupervisorValidationEvidence() throws {
  try withDirectPeerSupervisorValidationFixture { fixture in
    let reportInput = appSupervisorValidationInput(fixture: fixture, verdict: .partial)
    try appSupervisorReport(reportInput).prettyJSONData().write(to: fixture.partialSupervisorURL)

    var partialSettings = NativeAppShellExecutionSettings()
    partialSettings.supervisorReportPath = fixture.partialSupervisorURL.path
    let partialController = AppExecutionController(settings: partialSettings)

    partialController.finishValidation(exitCode: 0)

    #expect(partialController.phase == .validationFailed)
    #expect(partialController.status == "Validation evidence incomplete.")
    #expect(!partialController.hasValidatedRuntimeEvidence)
    #expect(partialController.lastLatencyMetrics?.isPartial == true)
    #expect(partialController.lastLatencyMetrics?.supervisorVerdict == .partial)
    #expect(partialController.lastReport?.verdict == .partial)
    #expect(partialController.lastError?.contains("supervisor verdict partial") == true)
  }
}

@MainActor
private func appAssertFailedSupervisorValidationEvidence() throws {
  try withDirectPeerSupervisorValidationFixture { fixture in
    let reportInput = appSupervisorValidationInput(fixture: fixture, verdict: .fail)
    try appSupervisorReport(reportInput).prettyJSONData().write(to: fixture.failedSupervisorURL)

    var failedSupervisorSettings = NativeAppShellExecutionSettings()
    failedSupervisorSettings.supervisorReportPath = fixture.failedSupervisorURL.path
    let failedSupervisorController = AppExecutionController(settings: failedSupervisorSettings)

    failedSupervisorController.finishValidation(exitCode: 0)

    #expect(failedSupervisorController.phase == .validationFailed)
    #expect(failedSupervisorController.status == "Validation evidence incomplete.")
    #expect(!failedSupervisorController.hasValidatedRuntimeEvidence)
    #expect(failedSupervisorController.lastLatencyMetrics?.isPartial == true)
    #expect(failedSupervisorController.lastLatencyMetrics?.supervisorVerdict == .fail)
    #expect(failedSupervisorController.lastReport?.verdict == .fail)
    #expect(failedSupervisorController.lastError?.contains("supervisor verdict fail") == true)
  }
}

@MainActor
private func appSupervisorValidationInput(
  fixture: AppSupervisorFixture,
  verdict: MeasurementVerdict
) -> AppSupervisorReportInput {
  AppSupervisorReportInput(
    id: "supervisor",
    runDirectory: fixture.directory.path,
    processResults: fixture.processResults,
    aggregation: .init(command: ["open-lola", "direct-p2p-two-peer-local-run"]),
    preflightChecks: fixture.preflightChecks,
    verdict: verdict,
    notes: "unit test supervisor report"
  )
}

@MainActor
private func appAssertPassingSupervisorValidationEvidence() throws {
  try withDirectPeerSupervisorValidationFixture { fixture in
    let executablePath = try requiredFreshOpenLolaCLIURL(
      context: "app validation evidence tests"
    ).path
    try appMeasuredPassDirectPeerSessionReport(id: "peer-a-pass-report", peerID: "peer-a")
      .prettyJSONData().write(to: fixture.passReportAURL)
    try appMeasuredPassDirectPeerSessionReport(id: "peer-b-pass-report", peerID: "peer-b")
      .prettyJSONData().write(to: fixture.passReportBURL)
    let passProcessResults = [
      appProcessResult(
        peerID: "peer-a", reportPath: fixture.passReportAURL.path,
        receiveProofPath: fixture.directory.appendingPathComponent("peer-a-rx-proof.json").path),
      appProcessResult(
        peerID: "peer-b", reportPath: fixture.passReportBURL.path,
        receiveProofPath: fixture.directory.appendingPathComponent("peer-b-rx-proof.json").path)
    ]

    let aggregation = DirectPeerTwoPeerLocalRunReport.Aggregation(
      command: [executablePath, "direct-p2p-two-peer-local-run"],
      reportPath: fixture.directory.appendingPathComponent("aggregate.json").path,
      executed: true
    )
    let reportInput = AppSupervisorReportInput(
      id: "supervisor",
      runDirectory: fixture.directory.path,
      processResults: passProcessResults,
      aggregation: aggregation,
      preflightChecks: fixture.preflightChecks,
      verdict: .pass,
      notes: "unit test supervisor report"
    )
    try appSupervisorReport(reportInput).prettyJSONData().write(to: fixture.passSupervisorURL)

    var passingSettings = NativeAppShellExecutionSettings()
    passingSettings.supervisorReportPath = fixture.passSupervisorURL.path
    let nonzeroValidationController = AppExecutionController(settings: passingSettings)

    nonzeroValidationController.finishValidation(exitCode: 1)
    appAssertNonzeroValidationFailure(nonzeroValidationController)

    let passingController = AppExecutionController(settings: passingSettings)

    passingController.finishValidation(exitCode: 0)
    appAssertPassingValidationEvidence(passingController)
  }
}

@MainActor
private func appAssertNonzeroValidationFailure(_ controller: AppExecutionController) {
  #expect(controller.phase == .validationFailed)
  #expect(controller.status == "Validation failed.")
  #expect(!controller.hasValidatedRuntimeEvidence)
  #expect(controller.lastLatencyMetrics == nil)
  #expect(controller.lastReport?.verdict == .partial)
}

@MainActor
private func appAssertPassingValidationEvidence(_ controller: AppExecutionController) {
  #expect(controller.phase == .validationPassed)
  #expect(controller.status == "Validation passed.")
  #expect(controller.hasValidatedRuntimeEvidence)
  #expect(controller.lastLatencyMetrics?.isPartial == false)
  #expect(controller.lastReport?.verdict == .pass)
  #expect(controller.lastReport?.notes.contains("Real-world PASS remains gated") == true)
}
