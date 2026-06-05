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
    #expect(AppDesignSystem.appBackgroundMeetsSecondaryTextContrast)
    #expect(AppDesignSystem.appBackgroundSecondaryTextContrastRatio >= AppDesignSystem.minimumNormalTextContrastRatio)
    #expect(AppDesignSystem.warningTextLightModeContrastRatio >= AppDesignSystem.minimumNormalTextContrastRatio)
    #expect(AppDesignSystem.stateArmedLightModeContrastRatio >= AppDesignSystem.minimumNormalTextContrastRatio)
    #expect(AppDesignSystem.stateReadyLightModeContrastRatio >= AppDesignSystem.minimumNormalTextContrastRatio)
    #expect(AppDesignSystem.stateLiveLightModeContrastRatio >= AppDesignSystem.minimumNormalTextContrastRatio)
    #expect(AppDesignSystem.stateErrorLightModeContrastRatio >= AppDesignSystem.minimumNormalTextContrastRatio)
    #expect(AppDesignSystem.stateUnconfiguredLightModeContrastRatio >= AppDesignSystem.minimumNormalTextContrastRatio)
    #expect(AppDesignSystem.statusBadgeMinimumTextContrastRatio >= AppDesignSystem.minimumNormalTextContrastRatio)
    #expect(AppDesignSystem.warningBannerMinimumTextContrastRatio >= AppDesignSystem.minimumNormalTextContrastRatio)

    let noEvidenceState = AppSessionState.derive(AppSessionStateDerivationInput(
        isRunning: false,
        isArmed: false,
        lastExitCode: 0,
        isConfigured: true,
        commandIntent: .idle,
        phase: .runFinished,
        hasValidatedRuntimeEvidence: false
    ))
    let evidenceState = AppSessionState.derive(AppSessionStateDerivationInput(
        isRunning: false,
        isArmed: false,
        lastExitCode: 0,
        isConfigured: true,
        commandIntent: .idle,
        phase: .runFinished,
        hasValidatedRuntimeEvidence: true
    ))
    let handoffState = AppSessionState.derive(AppSessionStateDerivationInput(
        isRunning: false,
        isArmed: false,
        lastExitCode: nil,
        isConfigured: false,
        commandIntent: .handoffRequested,
        phase: .idle,
        hasValidatedRuntimeEvidence: false
    ))
    let validatingState = AppSessionState.derive(AppSessionStateDerivationInput(
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

    let stoppedByOperatorState = AppSessionState.derive(AppSessionStateDerivationInput(
        isRunning: false,
        isArmed: true,
        lastExitCode: 15,
        isConfigured: true,
        commandIntent: .stopRequested,
        phase: .stopRequested,
        hasValidatedRuntimeEvidence: false
    ))
    let unexpectedSignalState = AppSessionState.derive(AppSessionStateDerivationInput(
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

    let metrics = AppLatencyHeroMetrics.make(from: [
            appMeasuredPassDirectPeerSessionReport(id: "peer-a-report", peerID: "peer-a"),
        ])

    #expect(AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
        executionKind: .directMacPeer,
        validationExitCode: 0,
        directPeerLatencyMetrics: metrics,
        externalConnectorReport: nil
    ))
    #expect(!AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
        executionKind: .directMacPeer,
        validationExitCode: nil,
        directPeerLatencyMetrics: metrics,
        externalConnectorReport: nil
    ))
    #expect(!AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
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

    let executable = directory.appendingPathComponent("open-lola")
    try Data("""
    #!/bin/sh
    trap 'exit 0' TERM
    sleep 5 &
    wait $!
    """.utf8).write(to: executable)
    try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o755))],
        ofItemAtPath: executable.path
    )

    var settings = NativeAppShellExecutionSettings()
    settings.planPath = directory.appendingPathComponent("plan.json").path
    settings.supervisorReportPath = directory.appendingPathComponent("supervisor.json").path
    settings.connectionPreflightReportPath = directory.appendingPathComponent("preflight.json").path
    settings.requirePreflight = false

    let controller = AppExecutionController(settings: settings)
    controller.armedForExecution = true
    controller.dryRun(executablePath: executable.path)
    #expect(controller.lastRunWasDryRun)
    try await waitUntil("test process starts") {
        controller.isRunning
    }
    #expect(controller.sessionToken != nil)
    #expect(FileManager.default.fileExists(
        atPath: AppRuntimeEvidenceScope.sessionTokenURL(reportPath: settings.supervisorReportPath).path
    ))

    controller.stop()

    #expect(!controller.armedForExecution)
    #expect(controller.phase == .stopRequested)
    #expect(controller.status == "Stop requested.")
    #expect(controller.lastReport == nil)

    try await waitUntil("stop report is finalized after process exit") {
        controller.lastReport != nil
    }

    #expect(!controller.isRunning)
    #expect(controller.lastReport?.stopRequested == true)
    #expect(controller.lastReport?.exitCode != nil)
    #expect(controller.lastReport?.finishedAt != nil)
    #expect(AppSessionState.derive(AppSessionStateDerivationInput(
        isRunning: controller.isRunning,
        isArmed: controller.armedForExecution,
        lastExitCode: controller.lastExitCode,
        isConfigured: true,
        commandIntent: .stopRequested,
        phase: controller.phase,
        hasValidatedRuntimeEvidence: false
    )) == .ready)
}

@MainActor
@Test
func appExecutionValidationBlocksMissingExecutableBeforeLaunch() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-validation-launch-\(UUID().uuidString)", isDirectory: true)
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
    try AppRuntimeEvidenceScope.writeSessionToken("current-validation", reportPath: existingReport.path)
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

@MainActor
@Test
func appConsoleFooterRenderedValidationStatusRequiresRuntimeEvidence() throws {
    let sourceReport = NativeAppShellSyntheticSmoke.run()
    let unconfiguredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: false))
    let configuredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: true))

    let noReportFooter = try renderedFooterLabels(
        report: sourceReport,
        plan: unconfiguredPlan,
        controller: AppExecutionController()
    )
    #expect(noReportFooter.contains("Setup required"))
    #expect(!noReportFooter.contains("Report validated"))

    let malformedEvidenceController = AppExecutionController()
    malformedEvidenceController.lastValidationExitCode = 0
    malformedEvidenceController.lastError = "Validated supervisor report missing or unreadable: malformed.json"
    let malformedFooter = try renderedFooterLabels(
        report: sourceReport,
        plan: configuredPlan,
        controller: malformedEvidenceController
    )
    #expect(malformedFooter.contains("Validation failed"))
    #expect(!malformedFooter.contains("Report validated"))

    let partialEvidenceController = AppExecutionController()
    partialEvidenceController.lastValidationExitCode = 0
    partialEvidenceController.lastLatencyMetrics = AppLatencyHeroMetrics.make(
        from: [
            appDirectPeerSessionReport(
                id: "partial-peer-report",
                packetsReceived: 1,
                packetsLost: 0,
                jitterMicroseconds: 1,
                latencyMicroseconds: 1
            ),
        ],
        expectedPeerReportCount: 1,
        loadFailures: [],
        supervisorVerdict: .partial
    )
    let partialFooter = try renderedFooterLabels(
        report: sourceReport,
        plan: configuredPlan,
        controller: partialEvidenceController
    )
    #expect(partialFooter.contains("Validation failed"))
    #expect(!partialFooter.contains("Report validated"))

    let stalePassController = AppExecutionController()
    stalePassController.lastValidationExitCode = 0
    stalePassController.lastReport = NativeAppShellExecutionReport(
        command: ["open-lola", "validate-direct-p2p-two-peer-local-run-report"],
        startedAt: "2026-05-17T00:00:00Z",
        exitCode: 0,
        stdoutPath: "/tmp/stdout.log",
        stderrPath: "/tmp/stderr.log",
        validationExitCode: 0,
        verdict: .pass,
        notes: "stale pass report without loaded runtime metrics"
    )
    let stalePassFooter = try renderedFooterLabels(
        report: sourceReport,
        plan: configuredPlan,
        controller: stalePassController
    )
    #expect(stalePassFooter.contains("Validation failed"))
    #expect(!stalePassFooter.contains("Report validated"))

    let validEvidenceController = AppExecutionController()
    validEvidenceController.lastValidationExitCode = 0
    validEvidenceController.lastLatencyMetrics = AppLatencyHeroMetrics.make(from: [
        appMeasuredPassDirectPeerSessionReport(id: "valid-peer-report", peerID: "peer-a"),
    ])
    let validFooter = try renderedFooterLabels(
        report: sourceReport,
        plan: configuredPlan,
        controller: validEvidenceController
    )
    #expect(validFooter.contains("Report validated"))
}

@MainActor
private func waitUntil(
    _ description: String,
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    condition: () -> Bool
) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while !condition() {
        if DispatchTime.now().uptimeNanoseconds >= deadline {
            Issue.record("Timed out waiting for \(description)")
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

@MainActor
private func renderedFooterLabels(
    report: NativeAppShellReport,
    plan: AppOperatorPrototypePlan,
    controller: AppExecutionController
) throws -> [String] {
    let snapshot = AppConsoleStatusSnapshot.make(
        report: report,
        plan: plan,
        executionController: controller,
        captureReport: nil
    )
    let hostingView = NSHostingView(rootView: AppConsoleFooterStripView(
        snapshot: snapshot,
        sessionState: .ready,
        armedForExecution: false,
        isRunning: false,
        stopExecution: {}
    ))
    hostingView.frame = NSRect(x: 0, y: 0, width: 900, height: 80)
    hostingView.layoutSubtreeIfNeeded()
    let renderedSize = hostingView.fittingSize
    #expect(renderedSize.width > 0)
    #expect(renderedSize.height > 0)
    return [
        AppFooterTransportPolicy.stateTitle(sessionState: .ready, armedForExecution: false, isRunning: false),
        snapshot.validationTitle,
        snapshot.packetTitle,
        snapshot.remoteStreamTitle,
    ]
}

@MainActor
@Test
func appOverviewSummaryChoosesOperatorNextActions() throws {
    let report = NativeAppShellSyntheticSmoke.run()
    let unconfiguredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: false))
    let configuredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: true))
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-overview-readiness-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let unconfigured = AppOverviewOperatorSummary.make(
        report: report,
        plan: unconfiguredPlan,
        executionController: AppExecutionController(),
        sessionState: .unconfigured,
        captureReport: nil
    )
    #expect(unconfigured.nextAction.title == "Configure devices")
    #expect(unconfigured.nextAction.targetSection == .devices)
    #expect(unconfigured.statusItems.contains { $0.id == "readiness" && $0.value == "Setup required" })

    let missingReportController = AppExecutionController()
    missingReportController.settings.supervisorReportPath = directory.appendingPathComponent("missing-supervisor.json").path
    let configuredNoReport = AppOverviewOperatorSummary.make(
        report: report,
        plan: configuredPlan,
        executionController: missingReportController,
        sessionState: .ready,
        captureReport: nil
    )
    #expect(configuredNoReport.nextAction.title == "Produce current report")
    #expect(configuredNoReport.nextAction.targetSection == .session)

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
        plan: configuredPlan,
        executionController: reportReadyController,
        sessionState: .ready,
        captureReport: nil
    )
    #expect(reportReady.nextAction.title == "Validate current report")
    #expect(reportReady.nextAction.targetSection == .validation)

    let runningController = AppExecutionController()
    runningController.phase = .supervisorRunning
    runningController.status = "Supervisor running."
    let running = AppOverviewOperatorSummary.make(
        report: report,
        plan: configuredPlan,
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
        plan: configuredPlan,
        executionController: failedController,
        sessionState: .error,
        captureReport: nil
    )
    #expect(failed.nextAction.title == "Inspect the failure")
    #expect(failed.nextAction.targetSection == .diagnostics)

    let incompleteController = AppExecutionController()
    incompleteController.lastValidationExitCode = 0
    let incomplete = AppOverviewOperatorSummary.make(
        report: report,
        plan: configuredPlan,
        executionController: incompleteController,
        sessionState: .awaitingEvidence,
        captureReport: nil
    )
    #expect(incomplete.nextAction.title == "Resolve evidence gap")
    #expect(incomplete.nextAction.targetSection == .validation)
    #expect(incomplete.evidence.runtimeEvidence == "Missing current measurement")

    let validatedController = AppExecutionController()
    seedValidatedRuntimeEvidence(validatedController)
    let validated = AppOverviewOperatorSummary.make(
        report: report,
        plan: configuredPlan,
        executionController: validatedController,
        sessionState: .validated,
        captureReport: nil
    )
    #expect(validated.nextAction.title == "Arm for Start")
    #expect(validated.nextAction.targetSection == .session)

    validatedController.armedForExecution = true
    let armedValidated = AppOverviewOperatorSummary.make(
        report: report,
        plan: configuredPlan,
        executionController: validatedController,
        sessionState: .armed,
        captureReport: nil
    )
    #expect(armedValidated.nextAction.title == "Start armed supervisor")
    #expect(armedValidated.nextAction.targetSection == .session)
}

@MainActor
@Test
func appValidationPreflightReportsBlockersWithTargetSections() throws {
    let report = NativeAppShellSyntheticSmoke.run()
    let surfaceProbe = NativeAppShellSurfaceProbe.run(sourceReport: report)
    let unconfiguredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: false))
    let configuredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: true))
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-preflight-readiness-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

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

    let missingReportController = AppExecutionController()
    missingReportController.settings.supervisorReportPath = "/private/tmp/open-lola-missing-preflight-\(UUID().uuidString).json"
    let missingReport = AppValidationPreflightModel.make(
        plan: configuredPlan,
        executionController: missingReportController,
        surfaceProbe: surfaceProbe
    )
    #expect(missingReport.verdict == .blocked)
    #expect(missingReport.blockers.contains { $0.id == "report-readiness" && $0.targetSection == .validation })

    let incompleteController = AppExecutionController()
    incompleteController.lastValidationExitCode = 0
    let incomplete = AppValidationPreflightModel.make(
        plan: configuredPlan,
        executionController: incompleteController,
        surfaceProbe: surfaceProbe
    )
    #expect(incomplete.verdict == .evidenceIncomplete)
    #expect(incomplete.verdict.toneKind == .warning)
    #expect(incomplete.blockers.contains { $0.id == "evidence" && $0.targetSection == .session })

    incompleteController.lastValidationResult = .failed
    incompleteController.lastError = "Supervisor evidence incomplete"
    let incompleteAfterValidation = AppValidationPreflightModel.make(
        plan: configuredPlan,
        executionController: incompleteController,
        surfaceProbe: surfaceProbe
    )
    #expect(incompleteAfterValidation.verdict == .evidenceIncomplete)
    #expect(incompleteAfterValidation.blockers.contains { $0.id == "evidence" && $0.targetSection == .session })

    let failedValidationController = AppExecutionController()
    failedValidationController.phase = .idle
    failedValidationController.lastValidationResult = .failed
    failedValidationController.lastError = "unit validation failure"
    let failedValidation = AppValidationPreflightModel.make(
        plan: configuredPlan,
        executionController: failedValidationController,
        surfaceProbe: surfaceProbe
    )
    #expect(failedValidation.verdict == .blocked)
    #expect(failedValidation.blockers.contains { $0.id == "last-error" })

    failedValidationController.lastError = nil
    let failedValidationWithoutError = AppValidationPreflightModel.make(
        plan: configuredPlan,
        executionController: failedValidationController,
        surfaceProbe: surfaceProbe
    )
    #expect(failedValidationWithoutError.verdict == .blocked)
    #expect(failedValidationWithoutError.blockers.contains { blocker in
        blocker.id == "last-error"
            && blocker.remediation.contains("Run validation again")
    })

    failedValidationController.lastValidationResult = .passed
    let passedValidation = AppValidationPreflightModel.make(
        plan: configuredPlan,
        executionController: failedValidationController,
        surfaceProbe: surfaceProbe
    )
    #expect(!passedValidation.blockers.contains { $0.id == "last-error" })

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
        plan: configuredPlan,
        executionController: reportReadyController,
        surfaceProbe: surfaceProbe
    )
    #expect(readyToValidate.verdict == .readyToValidate)
    #expect(readyToValidate.detail.contains("Run Validate before Start"))

    let readyToStartController = AppExecutionController()
    seedValidatedRuntimeEvidence(readyToStartController)
    let readyToStart = AppValidationPreflightModel.make(
        plan: configuredPlan,
        executionController: readyToStartController,
        surfaceProbe: surfaceProbe
    )
    #expect(readyToStart.verdict == .readyToStart)
    #expect(readyToStart.detail.contains("Arm in Session"))
}

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
    #expect(hiddenFieldBlocker.flatMap {
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
    #expect(visibleFieldBlocker.flatMap {
        AppAdvancedControlRecoveryPolicy.recovery(for: $0, plan: visibleFieldPlan)
    } == nil)
}

@MainActor
@Test
func appPacketMonitorEmptyStateAndDiagnosticsStatusExposeEvidenceContext() {
    let report = NativeAppShellSyntheticSmoke.run()
    let plan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: true))
    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = "/tmp/open-lola-supervisor.json"

    let emptyState = AppPacketMonitorEmptyState.make(plan: plan, executionSettings: settings)
    #expect(emptyState.title == "No capture data yet")
    #expect(emptyState.reason.contains("after a session completes"))
    #expect(emptyState.expectedReportPath == "/tmp/open-lola-supervisor.json")
    #expect(emptyState.targetSection == .session)

    let controller = AppExecutionController(settings: settings)
    let sourceDiagnostics = AppDiagnosticsStatusModel.make(report: report, executionController: controller)
    #expect(sourceDiagnostics.permissionsTitle == "Planned ready")
    #expect(sourceDiagnostics.realtimeSafetyTitle == "Source boundary safe")
    #expect(sourceDiagnostics.processTitle == "Idle")
    #expect(sourceDiagnostics.evidenceTitle == "Synthetic source")

    controller.lastLatencyMetrics = AppLatencyHeroMetrics.make(
        from: [
            appDirectPeerSessionReport(
                id: "partial-peer-report",
                packetsReceived: 1,
                packetsLost: 0,
                jitterMicroseconds: 1,
                latencyMicroseconds: 1
            ),
        ],
        expectedPeerReportCount: 1,
        loadFailures: [],
        supervisorVerdict: .partial
    )
    let partialDiagnostics = AppDiagnosticsStatusModel.make(report: report, executionController: controller)
    #expect(partialDiagnostics.evidenceTitle == "Loaded partial")
}
