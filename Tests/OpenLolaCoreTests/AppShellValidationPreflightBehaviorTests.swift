// Covers app-shell validation preflight state transitions so release checks catch UI-policy regressions.
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appValidationPreflightReportsBlockersWithTargetSections() throws {
  let report = NativeAppShellSyntheticSmoke.run()
  let surfaceProbe = NativeAppShellSurfaceProbe.run(sourceReport: report)
  let unconfiguredPlan = AppOperatorPrototypePlan.make(
    operatorSurface: appOperatorState(remoteSelectionComplete: false)
  )
  let configuredPlan = AppOperatorPrototypePlan.make(
    operatorSurface: appOperatorState(remoteSelectionComplete: true)
  )
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(
      "open-lola-app-preflight-readiness-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  appAssertPreflightBlocksUnconfiguredAndRunning(
    unconfiguredPlan: unconfiguredPlan,
    configuredPlan: configuredPlan,
    surfaceProbe: surfaceProbe
  )
  appAssertPreflightBlocksMissingReport(plan: configuredPlan, surfaceProbe: surfaceProbe)
  appAssertPreflightKeepsIncompleteEvidenceBlocked(plan: configuredPlan, surfaceProbe: surfaceProbe)
  appAssertPreflightReportsValidationFailure(plan: configuredPlan, surfaceProbe: surfaceProbe)
  try appAssertPreflightMovesFromReportReadyToStartReady(
    plan: configuredPlan,
    surfaceProbe: surfaceProbe,
    directory: directory
  )
}

@MainActor
private func appAssertPreflightBlocksUnconfiguredAndRunning(
  unconfiguredPlan: AppOperatorPrototypePlan,
  configuredPlan: AppOperatorPrototypePlan,
  surfaceProbe: NativeAppShellSurfaceProbeReport
) {
  let blocked = AppValidationPreflightModel.make(
    plan: unconfiguredPlan,
    executionController: AppExecutionController(),
    surfaceProbe: surfaceProbe
  )
  #expect(blocked.verdict == .blocked)
  #expect(blocked.blockers.contains { $0.id == "plan" && $0.targetSection == .devices })

  let runningController = AppExecutionController()
  runningController.phase = .dryRunRunning
  let running = AppValidationPreflightModel.make(
    plan: configuredPlan,
    executionController: runningController,
    surfaceProbe: surfaceProbe
  )
  #expect(running.verdict == .running)
  #expect(running.blockers.first?.targetSection == .session)
}

@MainActor
private func appAssertPreflightBlocksMissingReport(
  plan: AppOperatorPrototypePlan,
  surfaceProbe: NativeAppShellSurfaceProbeReport
) {
  let missingReportController = AppExecutionController()
  missingReportController.settings.supervisorReportPath =
    "/private/tmp/open-lola-missing-preflight-\(UUID().uuidString).json"
  let missingReport = AppValidationPreflightModel.make(
    plan: plan,
    executionController: missingReportController,
    surfaceProbe: surfaceProbe
  )
  #expect(missingReport.verdict == .blocked)
  #expect(
    missingReport.blockers.contains {
      $0.id == "report-readiness" && $0.targetSection == .validation
    })
}

@MainActor
private func appAssertPreflightKeepsIncompleteEvidenceBlocked(
  plan: AppOperatorPrototypePlan,
  surfaceProbe: NativeAppShellSurfaceProbeReport
) {
  let incompleteController = AppExecutionController()
  incompleteController.lastValidationExitCode = 0
  let incomplete = AppValidationPreflightModel.make(
    plan: plan,
    executionController: incompleteController,
    surfaceProbe: surfaceProbe
  )
  #expect(incomplete.verdict == .evidenceIncomplete)
  #expect(incomplete.verdict.toneKind == .warning)
  #expect(incomplete.blockers.contains { $0.id == "evidence" && $0.targetSection == .session })

  incompleteController.lastValidationResult = .failed
  incompleteController.lastError = "Supervisor evidence incomplete"
  let incompleteAfterValidation = AppValidationPreflightModel.make(
    plan: plan,
    executionController: incompleteController,
    surfaceProbe: surfaceProbe
  )
  #expect(incompleteAfterValidation.verdict == .evidenceIncomplete)
  #expect(
    incompleteAfterValidation.blockers.contains {
      $0.id == "evidence" && $0.targetSection == .session
    })
}

@MainActor
private func appAssertPreflightReportsValidationFailure(
  plan: AppOperatorPrototypePlan,
  surfaceProbe: NativeAppShellSurfaceProbeReport
) {
  let failedValidationController = AppExecutionController()
  failedValidationController.phase = .idle
  failedValidationController.lastValidationResult = .failed
  failedValidationController.lastError = "unit validation failure"
  let failedValidation = AppValidationPreflightModel.make(
    plan: plan,
    executionController: failedValidationController,
    surfaceProbe: surfaceProbe
  )
  #expect(failedValidation.verdict == .blocked)
  #expect(failedValidation.blockers.contains { $0.id == "last-error" })

  failedValidationController.lastError = nil
  let failedValidationWithoutError = AppValidationPreflightModel.make(
    plan: plan,
    executionController: failedValidationController,
    surfaceProbe: surfaceProbe
  )
  #expect(failedValidationWithoutError.verdict == .blocked)
  #expect(
    failedValidationWithoutError.blockers.contains { blocker in
      blocker.id == "last-error"
        && blocker.remediation.contains("Run validation again")
    })

  failedValidationController.lastValidationResult = .passed
  let passedValidation = AppValidationPreflightModel.make(
    plan: plan,
    executionController: failedValidationController,
    surfaceProbe: surfaceProbe
  )
  #expect(!passedValidation.blockers.contains { $0.id == "last-error" })
}

@MainActor
private func appAssertPreflightMovesFromReportReadyToStartReady(
  plan: AppOperatorPrototypePlan,
  surfaceProbe: NativeAppShellSurfaceProbeReport,
  directory: URL
) throws {
  let reportReadyController = AppExecutionController()
  let reportURL = directory.appendingPathComponent("ready-to-validate.json")
  try Data("{}".utf8).write(to: reportURL)
  reportReadyController.settings.supervisorReportPath = reportURL.path
  reportReadyController.sessionToken = "ready-to-validate"
  try AppRuntimeEvidenceScope.writeSessionToken("ready-to-validate", reportPath: reportURL.path)
  try FileManager.default.setAttributes(
    [.modificationDate: Date().addingTimeInterval(1)],
    ofItemAtPath: reportURL.path
  )
  let readyToValidate = AppValidationPreflightModel.make(
    plan: plan,
    executionController: reportReadyController,
    surfaceProbe: surfaceProbe
  )
  #expect(readyToValidate.verdict == .readyToValidate)
  #expect(readyToValidate.detail.contains("Run Validate before Start"))

  let readyToStartController = AppExecutionController()
  seedValidatedRuntimeEvidence(readyToStartController)
  let readyToStart = AppValidationPreflightModel.make(
    plan: plan,
    executionController: readyToStartController,
    surfaceProbe: surfaceProbe
  )
  #expect(readyToStart.verdict == .readyToStart)
  #expect(readyToStart.detail.contains("Arm in Session"))
}
