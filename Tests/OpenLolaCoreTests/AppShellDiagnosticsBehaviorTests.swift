// Covers app-shell diagnostics presentation so status and recovery regressions remain visible.
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appValidationBlockersExposeAdvancedControlRecoveryOnlyWhenNeeded() {
  let report = NativeAppShellSyntheticSmoke.run()
  let surfaceProbe = NativeAppShellSurfaceProbe.run(sourceReport: report)
  var surface = appOperatorState(remoteSelectionComplete: true)
  surface.controlMode = .normal
  surface.directPeerCommandFields.localHost = ""
  let hiddenFieldPlan = AppOperatorPrototypePlan.make(operatorSurface: surface)
  let hiddenFieldPreflight = AppValidationPreflightModel.make(
    plan: hiddenFieldPlan,
    executionController: AppExecutionController(),
    surfaceProbe: surfaceProbe
  )
  let hiddenFieldBlocker = hiddenFieldPreflight.blockers.first { $0.id == "plan" }
  let recovery = hiddenFieldBlocker.flatMap {
    AppAdvancedControlRecoveryPolicy.recovery(for: $0, plan: hiddenFieldPlan)
  }

  #expect(recovery?.fieldLabel == "Local host")
  #expect(recovery?.buttonTitle == "Show Advanced Controls")
  #expect(recovery?.detail.contains("hidden by Normal controls") == true)

  surface.controlMode = .advanced
  let advancedPlan = AppOperatorPrototypePlan.make(operatorSurface: surface)
  #expect(
    hiddenFieldBlocker.flatMap {
      AppAdvancedControlRecoveryPolicy.recovery(for: $0, plan: advancedPlan)
    } == nil)

  surface.controlMode = .normal
  surface.directPeerCommandFields.localHost = "192.0.2.10"
  surface.directPeerCommandFields.remoteHost = ""
  let visibleFieldPlan = AppOperatorPrototypePlan.make(operatorSurface: surface)
  let visibleFieldPreflight = AppValidationPreflightModel.make(
    plan: visibleFieldPlan,
    executionController: AppExecutionController(),
    surfaceProbe: surfaceProbe
  )
  let visibleFieldBlocker = visibleFieldPreflight.blockers.first { $0.id == "plan" }
  #expect(
    visibleFieldBlocker.flatMap {
      AppAdvancedControlRecoveryPolicy.recovery(for: $0, plan: visibleFieldPlan)
    } == nil)
}

@MainActor
@Test
func appPacketMonitorEmptyStateAndDiagnosticsStatusExposeEvidenceContext() {
  let report = NativeAppShellSyntheticSmoke.run()
  let plan = AppOperatorPrototypePlan.make(
    operatorSurface: appOperatorState(remoteSelectionComplete: true))
  var settings = NativeAppShellExecutionSettings()
  settings.supervisorReportPath = "/tmp/open-lola-supervisor.json"

  let emptyState = AppPacketMonitorEmptyState.make(plan: plan, executionSettings: settings)
  #expect(emptyState.title == "No capture data yet")
  #expect(emptyState.reason.contains("after a session completes"))
  #expect(emptyState.expectedReportPath == "/tmp/open-lola-supervisor.json")
  #expect(emptyState.targetSection == .session)

  let controller = AppExecutionController(settings: settings)
  let sourceDiagnostics = AppDiagnosticsStatusModel.make(
    report: report, executionController: controller)
  #expect(sourceDiagnostics.permissionsTitle == "Planned ready")
  #expect(sourceDiagnostics.realtimeSafetyTitle == "Source boundary safe")
  #expect(sourceDiagnostics.processTitle == "Idle")
  #expect(sourceDiagnostics.evidenceTitle == "Source checks · Partial")

  controller.lastLatencyMetrics = AppLatencyHeroMetrics.make(
    from: [
      appDirectPeerSessionReport(
        id: "partial-peer-report",
        packetsReceived: 1,
        packetsLost: 0,
        jitterMicroseconds: 1,
        latencyMicroseconds: 1
      )
    ],
    expectedPeerReportCount: 1,
    loadFailures: [],
    supervisorVerdict: .partial
  )
  let partialDiagnostics = AppDiagnosticsStatusModel.make(
    report: report, executionController: controller)
  #expect(partialDiagnostics.evidenceTitle == "Measured report · Incomplete")

  controller.lastValidationExitCode = 0
  let incompleteValidation = AppDiagnosticsStatusModel.make(
    report: report, executionController: controller)
  #expect(incompleteValidation.evidenceTitle == "Measured report · Incomplete")
  #expect(incompleteValidation.evidenceDetail ==
    "Validator exited 0, but current runtime evidence is incomplete.")

  seedValidatedRuntimeEvidence(controller)
  let validatedDiagnostics = AppDiagnosticsStatusModel.make(
    report: report, executionController: controller)
  #expect(validatedDiagnostics.evidenceTitle == "Measured report · Validated")
  #expect(!validatedDiagnostics.evidenceTitle.contains("Live measured"))
}
