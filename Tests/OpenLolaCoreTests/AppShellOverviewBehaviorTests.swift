// Covers app-shell overview state and actions so operator-facing regressions remain visible.
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appOverviewSummaryChoosesOperatorNextActions() throws {
  let report = NativeAppShellSyntheticSmoke.run()
  let unconfiguredPlan = AppOperatorPrototypePlan.make(
    operatorSurface: appOperatorState(remoteSelectionComplete: false)
  )
  let configuredPlan = AppOperatorPrototypePlan.make(
    operatorSurface: appOperatorState(remoteSelectionComplete: true)
  )
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(
      "open-lola-app-overview-readiness-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  appAssertOverviewBlocksUnconfiguredPlan(report: report, plan: unconfiguredPlan)
  appAssertOverviewRequestsCurrentReport(report: report, plan: configuredPlan, directory: directory)
  try appAssertOverviewRequestsValidation(
    report: report, plan: configuredPlan, directory: directory)
  appAssertOverviewShowsRunningAndFailedActions(report: report, plan: configuredPlan)
  appAssertOverviewBlocksIncompleteEvidence(report: report, plan: configuredPlan)
  appAssertOverviewStartsOnlyAfterValidation(report: report, plan: configuredPlan)
}

@MainActor
private func appAssertOverviewBlocksUnconfiguredPlan(
  report: NativeAppShellReport,
  plan: AppOperatorPrototypePlan
) {
  let unconfigured = AppOverviewOperatorSummary.make(
    report: report,
    plan: plan,
    executionController: AppExecutionController(),
    sessionState: .unconfigured,
    captureReport: nil
  )
  #expect(unconfigured.nextAction.title == "Configure devices")
  #expect(unconfigured.nextAction.targetSection == .devices)
  #expect(
    unconfigured.statusItems.contains { $0.id == "readiness" && $0.value == "Setup required" })
}

@MainActor
private func appAssertOverviewRequestsCurrentReport(
  report: NativeAppShellReport,
  plan: AppOperatorPrototypePlan,
  directory: URL
) {
  let missingReportController = AppExecutionController()
  missingReportController.settings.supervisorReportPath =
    directory
    .appendingPathComponent("missing-supervisor.json").path
  let configuredNoReport = AppOverviewOperatorSummary.make(
    report: report,
    plan: plan,
    executionController: missingReportController,
    sessionState: .ready,
    captureReport: nil
  )
  #expect(configuredNoReport.nextAction.title == "Produce current report")
  #expect(configuredNoReport.nextAction.targetSection == .session)
}

@MainActor
private func appAssertOverviewRequestsValidation(
  report: NativeAppShellReport,
  plan: AppOperatorPrototypePlan,
  directory: URL
) throws {
  let currentReportURL = directory.appendingPathComponent("current-supervisor.json")
  try Data("{}".utf8).write(to: currentReportURL)
  let reportReadyController = AppExecutionController()
  reportReadyController.settings.supervisorReportPath = currentReportURL.path
  reportReadyController.sessionToken = "current-report"
  try AppRuntimeEvidenceScope.writeSessionToken("current-report", reportPath: currentReportURL.path)
  try FileManager.default.setAttributes(
    [.modificationDate: Date().addingTimeInterval(1)],
    ofItemAtPath: currentReportURL.path
  )
  let reportReady = AppOverviewOperatorSummary.make(
    report: report,
    plan: plan,
    executionController: reportReadyController,
    sessionState: .ready,
    captureReport: nil
  )
  #expect(reportReady.nextAction.title == "Validate current report")
  #expect(reportReady.nextAction.targetSection == .validation)
}

@MainActor
private func appAssertOverviewShowsRunningAndFailedActions(
  report: NativeAppShellReport,
  plan: AppOperatorPrototypePlan
) {
  let runningController = AppExecutionController()
  runningController.phase = .supervisorRunning
  runningController.status = "Supervisor running."
  let running = AppOverviewOperatorSummary.make(
    report: report,
    plan: plan,
    executionController: runningController,
    sessionState: .supervisorRunning,
    captureReport: nil
  )
  #expect(running.nextAction.title == "Monitor the run")
  #expect(running.nextAction.targetSection == .session)

  let failedController = AppExecutionController()
  failedController.phase = .runFailed
  failedController.lastError = "unit failure"
  let failed = AppOverviewOperatorSummary.make(
    report: report,
    plan: plan,
    executionController: failedController,
    sessionState: .error,
    captureReport: nil
  )
  #expect(failed.nextAction.title == "Inspect the failure")
  #expect(failed.nextAction.targetSection == .diagnostics)
}

@MainActor
private func appAssertOverviewBlocksIncompleteEvidence(
  report: NativeAppShellReport,
  plan: AppOperatorPrototypePlan
) {
  let incompleteController = AppExecutionController()
  incompleteController.lastValidationExitCode = 0
  let incomplete = AppOverviewOperatorSummary.make(
    report: report,
    plan: plan,
    executionController: incompleteController,
    sessionState: .awaitingEvidence,
    captureReport: nil
  )
  #expect(incomplete.nextAction.title == "Resolve evidence gap")
  #expect(incomplete.nextAction.targetSection == .validation)
  #expect(incomplete.evidence.runtimeEvidence == "Not measured")
}

@MainActor
private func appAssertOverviewStartsOnlyAfterValidation(
  report: NativeAppShellReport,
  plan: AppOperatorPrototypePlan
) {
  let validatedController = AppExecutionController()
  seedValidatedRuntimeEvidence(validatedController)
  let validated = AppOverviewOperatorSummary.make(
    report: report,
    plan: plan,
    executionController: validatedController,
    sessionState: .validated,
    captureReport: nil
  )
  #expect(validated.nextAction.title == "Arm for Start")
  #expect(validated.nextAction.targetSection == .session)

  validatedController.armedForExecution = true
  let armedValidated = AppOverviewOperatorSummary.make(
    report: report,
    plan: plan,
    executionController: validatedController,
    sessionState: .armed,
    captureReport: nil
  )
  #expect(armedValidated.nextAction.title == "Start armed supervisor")
  #expect(armedValidated.nextAction.targetSection == .session)
}
