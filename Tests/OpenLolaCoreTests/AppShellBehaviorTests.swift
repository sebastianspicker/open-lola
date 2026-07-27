// Covers shared app-shell behavior contracts so navigation and state regressions are caught.
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func appSessionStateSurfaceDoesNotExposeUnbackedLiveState() {
  #expect(!AppSessionState.allCases.map(\.rawValue).contains("Live"))
}

@MainActor
@Test
func appStateAndRuntimeEvidenceScopeDoNotReportLiveWithoutValidatedEvidence() {
  appAssertDesignSystemContrast()
  appAssertSessionStateDerivationRequiresEvidence()
  appAssertRuntimeEvidenceScopeRequiresValidatedDirectPeerEvidence()
}

@MainActor
private func appAssertDesignSystemContrast() {
  #expect(AppDesignSystem.appBackgroundMeetsSecondaryTextContrast)
  #expect(
    AppDesignSystem.appBackgroundSecondaryTextContrastRatio
      >= AppDesignSystem.minimumNormalTextContrastRatio)
  #expect(
    AppDesignSystem.warningTextLightModeContrastRatio
      >= AppDesignSystem.minimumNormalTextContrastRatio)
  #expect(
    AppDesignSystem.stateArmedLightModeContrastRatio
      >= AppDesignSystem.minimumNormalTextContrastRatio)
  #expect(
    AppDesignSystem.stateReadyLightModeContrastRatio
      >= AppDesignSystem.minimumNormalTextContrastRatio)
  #expect(
    AppDesignSystem.stateLiveLightModeContrastRatio
      >= AppDesignSystem.minimumNormalTextContrastRatio)
  #expect(
    AppDesignSystem.stateErrorLightModeContrastRatio
      >= AppDesignSystem.minimumNormalTextContrastRatio)
  #expect(
    AppDesignSystem.stateUnconfiguredLightModeContrastRatio
      >= AppDesignSystem.minimumNormalTextContrastRatio)
  #expect(
    AppDesignSystem.statusBadgeMinimumTextContrastRatio
      >= AppDesignSystem.minimumNormalTextContrastRatio)
  #expect(
    AppDesignSystem.warningBannerMinimumTextContrastRatio
      >= AppDesignSystem.minimumNormalTextContrastRatio)
}

@MainActor
private func appAssertSessionStateDerivationRequiresEvidence() {
  appAssertSessionStateDerivesSetupAndEvidenceStates()
  appAssertSessionStateDerivesStopAndSignalStates()
}

@MainActor
private func appAssertSessionStateDerivesSetupAndEvidenceStates() {
  let noEvidenceState = AppSessionState.derive(
    AppSessionStateDerivationInput(
      isRunning: false,
      isArmed: false,
      lastExitCode: 0,
      isConfigured: true,
      commandIntent: .idle,
      phase: .runFinished,
      hasValidatedRuntimeEvidence: false
    ))
  let evidenceState = AppSessionState.derive(
    AppSessionStateDerivationInput(
      isRunning: false,
      isArmed: false,
      lastExitCode: 0,
      isConfigured: true,
      commandIntent: .idle,
      phase: .runFinished,
      hasValidatedRuntimeEvidence: true
    ))
  let handoffState = AppSessionState.derive(
    AppSessionStateDerivationInput(
      isRunning: false,
      isArmed: false,
      lastExitCode: nil,
      isConfigured: false,
      commandIntent: .handoffRequested,
      phase: .idle,
      hasValidatedRuntimeEvidence: false
    ))
  let validatingState = AppSessionState.derive(
    AppSessionStateDerivationInput(
      isRunning: true,
      isArmed: false,
      lastExitCode: nil,
      isConfigured: true,
      commandIntent: .idle,
      phase: .validationRunning,
      hasValidatedRuntimeEvidence: false
    ))

  #expect(noEvidenceState == .awaitingEvidence)
  #expect(evidenceState == .validated)
  #expect(handoffState == .unconfigured)
  #expect(validatingState == .validating)
}

@MainActor
private func appAssertSessionStateDerivesStopAndSignalStates() {
  let stoppedByOperatorState = AppSessionState.derive(
    AppSessionStateDerivationInput(
      isRunning: false,
      isArmed: true,
      lastExitCode: 15,
      isConfigured: true,
      commandIntent: .stopRequested,
      phase: .stopRequested,
      hasValidatedRuntimeEvidence: false
    ))
  let unexpectedSignalState = AppSessionState.derive(
    AppSessionStateDerivationInput(
      isRunning: false,
      isArmed: true,
      lastExitCode: 15,
      isConfigured: true,
      commandIntent: .idle,
      phase: .runFailed,
      hasValidatedRuntimeEvidence: false
    ))

  #expect(stoppedByOperatorState == .ready)
  #expect(unexpectedSignalState == .error)
}

@MainActor
private func appAssertRuntimeEvidenceScopeRequiresValidatedDirectPeerEvidence() {
  let metrics = AppLatencyHeroMetrics.make(from: [
    appMeasuredPassDirectPeerSessionReport(id: "peer-a-report", peerID: "peer-a")
  ])

  #expect(
    AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
      executionKind: .directMacPeer,
      validationExitCode: 0,
      directPeerLatencyMetrics: metrics,
      externalConnectorReport: nil
    ))
  #expect(
    !AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
      executionKind: .directMacPeer,
      validationExitCode: nil,
      directPeerLatencyMetrics: metrics,
      externalConnectorReport: nil
    ))
  #expect(
    !AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
      executionKind: .windowsLoLa,
      validationExitCode: 0,
      directPeerLatencyMetrics: metrics,
      externalConnectorReport: nil
    ))
  #expect(AppRuntimeEvidenceScope.allowsDirectPeerCaptureEvidence(executionKind: .directMacPeer))
  #expect(!AppRuntimeEvidenceScope.allowsDirectPeerCaptureEvidence(executionKind: .windowsLoLa))
}

@MainActor
@Test
func appExecutionStopDefersReportUntilProcessExit() async throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("open-lola-app-stop-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  let executable = try appStopTestExecutable(in: directory)
  let settings = appStopTestSettings(in: directory)

  let controller = AppExecutionController(settings: settings)
  controller.stdoutPath = directory.appendingPathComponent("execution-stdout.log").path
  controller.stderrPath = directory.appendingPathComponent("execution-stderr.log").path
  controller.previousStdoutPath = directory.appendingPathComponent("previous-execution-stdout.log").path
  controller.previousStderrPath = directory.appendingPathComponent("previous-execution-stderr.log").path
  controller.armedForExecution = true
  controller.dryRun(executablePath: executable.path)
  #expect(controller.lastRunWasDryRun)
  try await appShellWaitUntil("test process starts") {
    controller.isRunning
  }
  #expect(controller.sessionToken != nil)
  #expect(
    FileManager.default.fileExists(
      atPath: AppRuntimeEvidenceScope.sessionTokenURL(reportPath: settings.supervisorReportPath)
        .path
    ))

  controller.stop()

  #expect(!controller.armedForExecution)
  #expect(controller.phase == .stopRequested)
  #expect(controller.status == "Stop requested.")
  #expect(controller.lastReport == nil)

  try await appShellWaitUntil("stop report is finalized after process exit") {
    controller.lastReport != nil
  }

  #expect(!controller.isRunning)
  #expect(controller.lastReport?.stopRequested == true)
  #expect(controller.lastReport?.exitCode != nil)
  #expect(controller.lastReport?.finishedAt != nil)
  #expect(
    AppSessionState.derive(
      AppSessionStateDerivationInput(
        isRunning: controller.isRunning,
        isArmed: controller.armedForExecution,
        lastExitCode: controller.lastExitCode,
        isConfigured: true,
        commandIntent: .stopRequested,
        phase: controller.phase,
        hasValidatedRuntimeEvidence: false
      )) == .ready)
}

private func appStopTestExecutable(in directory: URL) throws -> URL {
  let executable = directory.appendingPathComponent("open-lola")
  try Data(
    """
    #!/bin/sh
    trap 'exit 0' TERM
    sleep 5 &
    wait $!
    """.utf8
  ).write(to: executable)
  try FileManager.default.setAttributes(
    [.posixPermissions: NSNumber(value: Int16(0o755))],
    ofItemAtPath: executable.path
  )
  return executable
}

private func appStopTestSettings(in directory: URL) -> NativeAppShellExecutionSettings {
  var settings = NativeAppShellExecutionSettings()
  settings.planPath = directory.appendingPathComponent("plan.json").path
  settings.supervisorReportPath = directory.appendingPathComponent("supervisor.json").path
  settings.connectionPreflightReportPath = directory.appendingPathComponent("preflight.json").path
  settings.requirePreflight = false
  return settings
}

@MainActor
@Test
func appExecutionValidationBlocksMissingExecutableBeforeLaunch() throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(
      "open-lola-app-validation-launch-\(UUID().uuidString)", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  let existingReport = directory.appendingPathComponent("supervisor.json")
  let missingValidator = directory.appendingPathComponent("open-lola")

  var settings = NativeAppShellExecutionSettings()
  settings.supervisorReportPath = existingReport.path
  settings.connectionPreflightReportPath = directory.appendingPathComponent("preflight.json").path
  settings.requirePreflight = false

  let controller = AppExecutionController(settings: settings)
  controller.sessionToken = "current-validation"
  try AppRuntimeEvidenceScope.writeSessionToken(
    "current-validation", reportPath: existingReport.path)
  try Data("{}".utf8).write(to: existingReport)
  controller.lastValidationExitCode = 0
  controller.validateReport(executablePath: missingValidator.path)

  #expect(controller.phase == .validationFailed)
  #expect(controller.status == "Validation unavailable.")
  #expect(controller.lastValidationExitCode == nil)
  #expect(controller.lastCommand.isEmpty)
  #expect(controller.lastReport == nil)
  #expect(controller.lastError?.contains("Executable path unavailable") == true)
  #expect(!controller.hasValidatedRuntimeEvidence)
}

@MainActor
@Test
func appSettingsDraftInvalidatesRuntimeEvidenceOnlyForRuntimeSettings() throws {
  let suiteName = "open-lola-settings-invalidation-\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defer { defaults.removePersistentDomain(forName: suiteName) }

  let settings = AppSettings(defaults: defaults)
  var surface = AppShellStoredDefaults.placeholderOperatorSurface()
  let previewState = AppPreviewReceiverState()
  let runtimeController = AppExecutionController()
  seedValidatedRuntimeEvidence(runtimeController)

  let runtimeDraft = AppSettingsDraft(settings: settings)
  runtimeDraft.localPeer = "changed-local-peer"
  runtimeDraft.commit(
    to: settings,
    operatorSurface: &surface,
    executionController: runtimeController,
    previewState: previewState
  )

  #expect(runtimeController.lastValidationResult == .unknown)
  #expect(runtimeController.lastValidationExitCode == nil)
  #expect(runtimeController.lastLatencyMetrics == nil)
  #expect(!runtimeController.hasValidatedRuntimeEvidence)

  let previewController = AppExecutionController()
  seedValidatedRuntimeEvidence(previewController)

  let previewDraft = AppSettingsDraft(settings: settings)
  previewDraft.audioPreviewEnabled.toggle()
  previewDraft.commit(
    to: settings,
    operatorSurface: &surface,
    executionController: previewController,
    previewState: previewState
  )

  #expect(previewController.lastValidationResult == .passed)
  #expect(previewController.lastValidationExitCode == 0)
  #expect(previewController.lastLatencyMetrics != nil)
  #expect(previewController.hasValidatedRuntimeEvidence)
}
