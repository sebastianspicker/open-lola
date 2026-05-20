import AppKit
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appExecutionCommandPreviewRequiresVerifiedExecutable() throws {
    let missingExecutable = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-missing-preview-\(UUID().uuidString)")
    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = missingExecutable.path
    let controller = AppExecutionController()

    do {
        _ = try controller.executionCommand(
            executablePath: missingExecutable.path,
            operatorSurface: surface,
            dryRun: true
        ).get()
        Issue.record("Expected command preview to require a verified executable path")
    } catch {
        #expect(String(describing: error).contains("Executable path unavailable"))
    }

    controller.dryRun(executablePath: missingExecutable.path)

    #expect(controller.phase == .failedToStart)
    #expect(controller.status == "Run failed to start.")
    #expect(controller.lastCommand.isEmpty)
    #expect(controller.lastReport?.command.isEmpty == true)
    #expect(controller.lastError?.contains("Executable path unavailable") == true)
}

@MainActor
@Test
func appStartArmedReportsFailureBeforeRunIntentIsSet() throws {
    let missingExecutable = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-missing-start-\(UUID().uuidString)")
    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = missingExecutable.path
    var commandIntent = surface.commandIntent
    let controller = AppExecutionController()
    controller.armedForExecution = true

    let started = controller.startArmed(operatorSurface: surface)
    if started {
        commandIntent = .runRequested
    } else {
        commandIntent = .idle
    }

    #expect(!started)
    #expect(commandIntent == .idle)
    #expect(controller.phase == .failedToStart)
    #expect(controller.status == "Run failed to start.")
    #expect(controller.lastError?.contains("Executable path unavailable") == true)
}

@Test
func appTransportStopConfirmationCoversActiveNonDryRuns() {
    #expect(AppTransportStopConfirmationPolicy.stopConfirmationTitle == "Stop active supervisor run?")
    #expect(AppTransportStopConfirmationPolicy.stopConfirmationButtonTitle == "Stop Supervisor Run")
    #expect(AppTransportStopConfirmationPolicy.stopConfirmationMessage.contains("active supervisor run"))
    #expect(AppTransportStopConfirmationPolicy.quitConfirmationTitle == "Quit while supervisor is running?")
    #expect(AppTransportStopConfirmationPolicy.quitConfirmationButtonTitle == "Quit and Stop Supervisor")
    #expect(AppTransportStopConfirmationPolicy.quitConfirmationMessage.contains("supervisor run is active"))
    #expect(AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState: .live))
    #expect(AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState: .supervisorRunning))
    #expect(!AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState: .armed))
    #expect(!AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState: .dryRunRunning))
    #expect(!AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState: .awaitingEvidence))
    #expect(!AppTransportStopConfirmationPolicy.requiresConfirmation(sessionState: .error))
    #expect(AppTransportStopConfirmationPolicy.requiresConfirmation(isRunning: true, lastRunWasDryRun: false))
    #expect(!AppTransportStopConfirmationPolicy.requiresConfirmation(isRunning: true, lastRunWasDryRun: true))
    #expect(!AppTransportStopConfirmationPolicy.requiresConfirmation(isRunning: false, lastRunWasDryRun: false))
}

@Test
func appFooterTransportStripShowsStopOnlyForActiveRuns() {
    #expect(AppFooterTransportPolicy.showsStopButton(isRunning: true))
    #expect(!AppFooterTransportPolicy.showsStopButton(isRunning: false))
    #expect(AppFooterTransportPolicy.stateTitle(
        sessionState: .supervisorRunning,
        armedForExecution: true,
        isRunning: true
    ) == "Active: Supervisor Running")
    #expect(AppFooterTransportPolicy.stateTitle(
        sessionState: .ready,
        armedForExecution: true,
        isRunning: false
    ) == "Armed")
}

@Test
func appQuitGuardOnlyPromptsForActiveRunsBeforeConfirmedQuit() {
    #expect(AppQuitGuardPolicy.requiresConfirmation(isRunning: true, allowNextTerminate: false))
    #expect(!AppQuitGuardPolicy.requiresConfirmation(isRunning: false, allowNextTerminate: false))
    #expect(!AppQuitGuardPolicy.requiresConfirmation(isRunning: true, allowNextTerminate: true))
}

@Test
func appSessionBannerAccessibilityAnnouncementTargetsErrorAndPreviewWarningOnly() {
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(
        state: .error,
        label: "failure"
    ) == "Session state: Error. failure")
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(
        state: .receiverWarning,
        label: "preview degraded"
    ) == "Session state: Preview Warning. preview degraded")
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(state: .live, label: "live") == nil)
    #expect(AppSessionBannerAccessibilityPolicy.announcementMessage(state: .ready, label: "ready") == nil)
}

@Test
func appPreviewWindowRequestFeedbackDoesNotClaimDisplaySuccess() {
    #expect(AppPreviewWindowRequestFeedback.statusMessage.contains("request sent"))
    #expect(AppPreviewWindowRequestFeedback.statusMessage.contains("not confirmed"))
    #expect(AppPreviewWindowRequestFeedback.statusMessage.contains("reopen Local Preview"))
    #expect(!AppPreviewWindowRequestFeedback.statusMessage.localizedCaseInsensitiveContains("opened"))
    #expect(AppPreviewWindowRequestFeedback.menuHelp.contains("Request"))
    #expect(AppPreviewWindowRequestFeedback.menuHelp.contains("not confirmed"))
}

@Test
func appCommandIntentDisplayUsesHumanReadableLabels() {
    #expect(AppCommandIntentDisplay.title(.idle) == "Idle")
    #expect(AppCommandIntentDisplay.title(.handoffRequested) == "Handoff requested")
    #expect(AppCommandIntentDisplay.title(.runRequested) == "Run requested")
    #expect(AppCommandIntentDisplay.title(.stopRequested) == "Stop requested")
}

@Test
func appCommandIntentStopControlIsMetadataOnlyWhileRuntimeIsActive() {
    #expect(AppCommandIntentControlPolicy.stopIntentTitle == "Mark Stop Intent")
    #expect(AppCommandIntentControlPolicy.title(for: .handoffRequested) == "Mark Handoff Intent")
    #expect(AppCommandIntentControlPolicy.title(for: .startRequested) == "Mark Start Intent")
    #expect(AppCommandIntentControlPolicy.title(for: .runRequested) == "Mark Run Intent")
    #expect(AppCommandIntentControlPolicy.title(for: .idle) == "Clear Command Intent")
    #expect(AppCommandIntentControlPolicy.stopIntentDisabled(inputsLocked: true))
    #expect(!AppCommandIntentControlPolicy.stopIntentDisabled(inputsLocked: false))
    #expect(AppCommandIntentControlPolicy.stopIntentHelp(
        inputsLocked: true
    ).contains("transport Stop control"))
    #expect(AppCommandIntentControlPolicy.stopIntentHelp(
        inputsLocked: false
    ).contains("metadata"))
    #expect(AppCommandIntentControlPolicy.help(
        for: .startRequested,
        inputsLocked: false
    ).contains("without starting a process"))
    #expect(AppCommandIntentControlPolicy.help(
        for: .runRequested,
        inputsLocked: true
    ) == AppRuntimeInputLock.lockedHelp)
}

@Test
func appTransportStartPolicyRequiresPassingValidationAfterFailure() {
    #expect(!AppTransportStartPolicy.canStart(
        armedForExecution: true,
        dryRunAvailable: true,
        lastValidationResult: .unknown,
        hasValidatedRuntimeEvidence: false
    ))
    #expect(!AppTransportStartPolicy.canStart(
        armedForExecution: true,
        dryRunAvailable: true,
        lastValidationResult: .failed,
        hasValidatedRuntimeEvidence: false
    ))
    #expect(!AppTransportStartPolicy.canStart(
        armedForExecution: true,
        dryRunAvailable: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: false
    ))
    #expect(AppTransportStartPolicy.canStart(
        armedForExecution: true,
        dryRunAvailable: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    ))
}

@Test
func appMenuStartPolicyMatchesTransportStartPolicy() {
    let menuStart = AppMenuActionPolicy.startAvailable(
        sessionMode: .directMacPeer,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    )
    let transportStart = AppTransportStartPolicy.canStart(
        armedForExecution: true,
        dryRunAvailable: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    )

    #expect(menuStart == transportStart)
    #expect(!AppMenuActionPolicy.startAvailable(
        sessionMode: .directMacPeer,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .unknown,
        hasValidatedRuntimeEvidence: false
    ))
    #expect(!AppMenuActionPolicy.startAvailable(
        sessionMode: .directMacPeer,
        planIsConfigured: false,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    ))
    #expect(!AppMenuActionPolicy.startAvailable(
        sessionMode: .ultraGrid,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    ))
    #expect(!AppMenuActionPolicy.startAvailable(
        sessionMode: .directMacPeer,
        planIsConfigured: true,
        isRunning: true,
        armedForExecution: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    ))
    #expect(AppMenuActionPolicy.armDisabled(sessionMode: .directMacPeer, isRunning: true))
    #expect(AppMenuActionPolicy.armDisabled(sessionMode: .ultraGrid, isRunning: false))
    #expect(!AppMenuActionPolicy.armDisabled(sessionMode: .directMacPeer, isRunning: false))
}

@Test
func appMenuActionPolicyReportsDisabledRecoveryReasons() {
    #expect(AppMenuActionPolicy.writePlanDisabledReason(
        sessionMode: .windowsLoLa,
        isRunning: false
    )?.contains("Direct Mac Peer") == true)
    #expect(AppMenuActionPolicy.writePlanDisabledReason(
        sessionMode: .directMacPeer,
        isRunning: false
    ) == nil)
    #expect(AppMenuActionPolicy.dryRunDisabledReason(
        sessionMode: .directMacPeer,
        planIsConfigured: false,
        isRunning: false
    )?.contains("Configure") == true)
    #expect(AppMenuActionPolicy.dryRunDisabledReason(
        sessionMode: .ultraGrid,
        planIsConfigured: true,
        isRunning: false
    )?.contains("supported workflow") == true)
    #expect(AppMenuActionPolicy.handoffIntentDisabledReason(
        planIsConfigured: false,
        isRunning: false
    )?.contains("Configure") == true)
    #expect(AppMenuActionPolicy.startDisabledReason(
        sessionMode: .directMacPeer,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: false,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    ) == "Arm execution before starting.")
    #expect(AppMenuActionPolicy.startDisabledReason(
        sessionMode: .directMacPeer,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .unknown,
        hasValidatedRuntimeEvidence: false
    )?.contains("passing validation") == true)
    #expect(AppMenuActionPolicy.startDisabledReason(
        sessionMode: .directMacPeer,
        planIsConfigured: true,
        isRunning: false,
        armedForExecution: true,
        lastValidationResult: .passed,
        hasValidatedRuntimeEvidence: true
    ) == nil)
    #expect(AppMenuActionPolicy.stopDisabledReason(isRunning: false) == "No supervisor run is active.")
    #expect(AppMenuActionPolicy.stopDisabledReason(isRunning: true) == nil)
    #expect(AppMenuActionPolicy.validateDisabledReason(
        validationUnavailableMessage: "Load a report before validating."
    ) == "Load a report before validating.")
    #expect(AppMenuActionPolicy.armDisabledReason(
        sessionMode: .ultraGrid,
        isRunning: false
    )?.contains("supported workflow") == true)
}

@Test
func appOperatorArtifactPanelClearsStaleArtifactForRemoteInputAndFailures() {
    let artifact = NativeAppShellGeneratedArtifactState(
        kind: .twoPeerRunPlan,
        generatedAt: "2026-05-20T12:00:00Z",
        path: "/tmp/open-lola/plan.json",
        clipboardText: "{\"id\":\"old\"}",
        validationSummary: "old plan"
    )
    var panelState = AppOperatorArtifactPanelState()

    panelState.recordGeneratedArtifact(artifact, status: "Generated copyable plan JSON.")
    panelState.clearGeneratedArtifact(status: "Pasted remote inventory JSON. Review and import to validate IDs.")

    #expect(panelState.generatedArtifact == nil)
    #expect(panelState.status.contains("Review and import"))
    #expect(panelState.fileError == nil)

    panelState.recordGeneratedArtifact(artifact, status: "Generated copyable plan JSON.")
    panelState.setFailureStatus("Remote inventory import failed", NativeAppShellArtifactError.emptyClipboardText)

    #expect(panelState.generatedArtifact == nil)
    #expect(panelState.status.contains("Remote inventory import failed"))
    #expect(panelState.fileError == panelState.status)
}

@Test
func appArtifactImportAndWriteStatusExposeValidationAndCounts() {
    let remoteInventory = appOperatorState(remoteSelectionComplete: true).remoteInventory
    let importSummary = AppRemoteInventoryImportStatus.summary(for: remoteInventory)
    #expect(importSummary.contains("host remote-mac"))
    #expect(importSummary.contains("audio input remote-rme"))
    #expect(importSummary.contains("audio output remote-rme"))
    #expect(importSummary.contains("video remote-atem"))

    let artifact = NativeAppShellGeneratedArtifactState(
        kind: .twoPeerRunPlan,
        generatedAt: "2026-05-20T12:00:00Z",
        path: "/tmp/open-lola/plan-2026-05-20T12-00-00Z.json",
        clipboardText: "{\"id\":\"new\"}",
        validationSummary: "new plan"
    )
    let result = NativeAppShellArtifactWriteResult(
        artifact: artifact,
        requestedPath: "/tmp/open-lola/plan.json",
        writtenPath: "/tmp/open-lola/plan-2026-05-20T12-00-00Z.json",
        writtenCount: 1,
        skippedCount: 1,
        failedCount: 0
    )
    let status = AppArtifactWriteStatus.message(result: result, copied: false)

    #expect(status.contains("Wrote 1 plan artifact"))
    #expect(status.contains("Skipped overwrite of existing target /tmp/open-lola/plan.json"))
    #expect(status.contains("Counts: written 1, skipped 1, failed 0"))
    #expect(status.contains("Pasteboard copy failed"))
}

@Test
func appConnectionTopologyAnimationRequiresSupervisorRunningPhase() {
    #expect(AppConnectionTopologyAnimationPolicy.shouldAnimate(
        phase: .supervisorRunning,
        reduceMotion: false
    ))
    #expect(!AppConnectionTopologyAnimationPolicy.shouldAnimate(
        phase: .validationPassed,
        reduceMotion: false
    ))
    #expect(!AppConnectionTopologyAnimationPolicy.shouldAnimate(
        phase: .runFinished,
        reduceMotion: false
    ))
    #expect(!AppConnectionTopologyAnimationPolicy.shouldAnimate(
        phase: .supervisorRunning,
        reduceMotion: true
    ))
}

@Test
func appCommandPreviewKeepsExactCopySeparateFromReviewDisplay() {
    let command = [
        "/Applications/Open LoLa/bin/open-lola",
        "direct-p2p-session-run",
        "--plan",
        "/tmp/open lola/plan's.json",
        "--peer",
        "mac-studio-control-room-with-long-hostname.example.local",
    ]
    let shellLine = AppCommandPreview.shellLine(command)
    let multilineDisplay = AppCommandPreview.multilineDisplay(command)

    #expect(AppCommandPreview.copyText(command) == shellLine)
    #expect(
        shellLine ==
            "'/Applications/Open LoLa/bin/open-lola' direct-p2p-session-run --plan '/tmp/open lola/plan'\\''s.json' --peer mac-studio-control-room-with-long-hostname.example.local"
    )
    #expect(multilineDisplay != shellLine)
    #expect(multilineDisplay.contains(" \\\n  --plan"))
    #expect(multilineDisplay.contains("'/tmp/open lola/plan'\\''s.json'"))
}

@Test
func appCompactToolButtonSizingProvidesMinimumHitTarget() {
    #expect(AppCompactToolButtonSizing.minimumHitLength == 28)
}

@Test
func appChannelMetersOnlyShowWithActiveLocalPreviewEvidence() {
    #expect(AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .supervisorRunning,
        audioPreviewEnabled: true,
        audioPreviewPhase: .active
    ))
    #expect(AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .idle,
        audioPreviewEnabled: true,
        audioPreviewPhase: .active
    ))
    #expect(!AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .supervisorRunning,
        audioPreviewEnabled: true,
        audioPreviewPhase: .idle
    ))
    #expect(!AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .supervisorRunning,
        audioPreviewEnabled: true,
        audioPreviewPhase: .failed
    ))
    #expect(!AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .supervisorRunning,
        audioPreviewEnabled: false,
        audioPreviewPhase: .active
    ))
}

@Test
func appSidebarNavigatesToSessionOnlyOnLiveTransition() {
    #expect(AppSidebarLiveNavigationPolicy.targetSection(
        currentSection: .settings,
        previousState: .awaitingEvidence,
        newState: .live
    ) == .session)
    #expect(AppSidebarLiveNavigationPolicy.targetSection(
        currentSection: .settings,
        previousState: .live,
        newState: .live
    ) == nil)
    #expect(AppSidebarLiveNavigationPolicy.targetSection(
        currentSection: .session,
        previousState: .awaitingEvidence,
        newState: .live
    ) == nil)
    #expect(AppSidebarLiveNavigationPolicy.targetSection(
        currentSection: .settings,
        previousState: .armed,
        newState: .supervisorRunning
    ) == nil)
}

@Test
func appProcessExitDisplayUsesOperatorLanguage() {
    #expect(AppProcessExitDisplay.title(nil) == "none")
    #expect(AppProcessExitDisplay.title(0) == "Exited cleanly")
    #expect(AppProcessExitDisplay.title(15) == "Stopped by operator")
    #expect(AppProcessExitDisplay.title(-15) == "Stopped by operator")
    #expect(AppProcessExitDisplay.title(143) == "Stopped by operator")
    #expect(AppProcessExitDisplay.title(2) == "Unexpected exit (code 2)")
}

@Test
func appLogOpenButtonPolicyExplainsUnavailableLogFiles() {
    let missingReason = AppLogOpenButtonPolicy.disabledReason(
        label: "stdout",
        path: "/tmp/open-lola/missing-stdout.log",
        canOpen: false
    )

    #expect(missingReason == "Stdout log unavailable. No file exists at /tmp/open-lola/missing-stdout.log.")
    #expect(AppLogOpenButtonPolicy.disabledReason(
        label: "stderr",
        path: "/tmp/open-lola/stderr.log",
        canOpen: true
    ) == nil)
    #expect(AppLogOpenButtonPolicy.openHelp(label: "stderr") == "Open stderr log file")
}

@Test
func appExecutionLogSnapshotPreservesPreviousRunBeforeTruncation() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-log-snapshot-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let currentLog = directory.appendingPathComponent("execution-stdout.log")
    let previousLog = directory.appendingPathComponent("previous-execution-stdout.log")
    try Data("first run\n".utf8).write(to: currentLog)

    let copied = try AppExecutionLogSnapshot.preserveCurrentLogIfPresent(
        sourcePath: currentLog.path,
        previousPath: previousLog.path
    )

    #expect(copied)
    #expect(try String(contentsOf: previousLog, encoding: .utf8) == "first run\n")

    try Data().write(to: currentLog)
    let copiedEmptyLog = try AppExecutionLogSnapshot.preserveCurrentLogIfPresent(
        sourcePath: currentLog.path,
        previousPath: previousLog.path
    )

    #expect(!copiedEmptyLog)
    #expect(try String(contentsOf: previousLog, encoding: .utf8) == "first run\n")
}

@MainActor
@Test
func appExecutionEvidenceRingPreservesLastThreeSnapshotsBeforeClearing() {
    let controller = AppExecutionController()

    controller.archiveCurrentEvidenceForNextRun()
    #expect(controller.previousRunEvidence.isEmpty)

    for index in 1...4 {
        controller.lastCommand = ["open-lola", "run-\(index)"]
        controller.status = "Run \(index) failed."
        controller.phase = .runFailed
        controller.lastExitCode = index
        controller.lastValidationExitCode = index + 10
        controller.lastValidationResult = .failed
        controller.lastError = "failure \(index)"
        controller.errorLog = ["failure \(index)"]
        controller.archiveCurrentEvidenceForNextRun()
    }

    #expect(controller.previousRunEvidence.count == 3)
    #expect(controller.previousRunEvidence.map(\.exitCode) == [4, 3, 2])
    #expect(controller.previousRunEvidence.first?.lastError == "failure 4")
    #expect(controller.previousRunEvidence.first?.commandLine.contains("run-4") == true)
}

@MainActor
@Test
func appSettingsDraftDoesNotPersistOrMutateRuntimeUntilSave() throws {
    let suiteName = "open-lola-settings-draft-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set("original-peer", forKey: AppStorageKeys.localPeer)
    defaults.set(true, forKey: AppStorageKeys.requirePreflight)
    defaults.set(true, forKey: AppStorageKeys.audioPreviewEnabled)

    let settings = AppSettings(defaults: defaults)
    let draft = AppSettingsDraft(settings: settings)
    var surface = AppShellStoredDefaults.placeholderOperatorSurface()
    let controller = AppExecutionController()
    let previewState = AppPreviewReceiverState()

    draft.localPeer = "draft-peer"
    draft.requirePreflight = false
    draft.audioPreviewEnabled = false

    #expect(defaults.string(forKey: AppStorageKeys.localPeer) == "original-peer")
    #expect(settings.localPeer == "original-peer")
    #expect(surface.directPeerCommandFields.localPeer != "draft-peer")
    #expect(controller.settings.requirePreflight)
    #expect(previewState.audioPreviewEnabled)

    draft.commit(
        to: settings,
        operatorSurface: &surface,
        executionController: controller,
        previewState: previewState
    )

    #expect(defaults.string(forKey: AppStorageKeys.localPeer) == "draft-peer")
    #expect(settings.localPeer == "draft-peer")
    #expect(surface.directPeerCommandFields.localPeer == "draft-peer")
    #expect(!controller.settings.requirePreflight)
    #expect(!previewState.audioPreviewEnabled)

    draft.localPeer = "discarded-peer"
    draft.load(from: settings)

    #expect(draft.localPeer == "draft-peer")
    #expect(defaults.string(forKey: AppStorageKeys.localPeer) == "draft-peer")
}

@Test
func appExecutablePathResolverClassifiesRunnableAndUnavailablePaths() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-executable-paths-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let missingExecutable = directory.appendingPathComponent("missing-open-lola")
    let nonExecutableFile = directory.appendingPathComponent("not-executable")
    let executableFile = directory.appendingPathComponent("open-lola")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: nonExecutableFile)
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableFile)
    try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o755))],
        ofItemAtPath: executableFile.path
    )

    #expect(AppExecutablePathResolver.resolve(missingExecutable.path) == .unavailable(
        path: missingExecutable.path,
        reason: "file does not exist"
    ))
    #expect(AppExecutablePathResolver.resolve(nonExecutableFile.path) == .unverified(
        path: nonExecutableFile.path,
        reason: "file is not executable"
    ))
    #expect(AppExecutablePathResolver.resolve(executableFile.path) == .verified(path: executableFile.path))

    do {
        _ = try AppExecutablePathResolver.verifiedPath(nonExecutableFile.path)
        Issue.record("Expected non-executable file to fail executable verification")
    } catch {
        #expect(String(describing: error).contains("Executable path unverified"))
    }
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

    let noEvidenceState = AppSessionState.derive(
        isRunning: false,
        isArmed: false,
        lastExitCode: 0,
        isConfigured: true,
        commandIntent: .idle,
        phase: .runFinished,
        hasValidatedRuntimeEvidence: false
    )
    let evidenceState = AppSessionState.derive(
        isRunning: false,
        isArmed: false,
        lastExitCode: 0,
        isConfigured: true,
        commandIntent: .idle,
        phase: .runFinished,
        hasValidatedRuntimeEvidence: true
    )
    let handoffState = AppSessionState.derive(
        isRunning: false,
        isArmed: false,
        lastExitCode: nil,
        isConfigured: false,
        commandIntent: .handoffRequested,
        phase: .idle,
        hasValidatedRuntimeEvidence: false
    )
    let validatingState = AppSessionState.derive(
        isRunning: true,
        isArmed: false,
        lastExitCode: nil,
        isConfigured: true,
        commandIntent: .idle,
        phase: .validationRunning,
        hasValidatedRuntimeEvidence: false
    )

    #expect(noEvidenceState == .awaitingEvidence)
    #expect(evidenceState == .validated)
    #expect(handoffState == .unconfigured)
    #expect(validatingState == .validating)

    let stoppedByOperatorState = AppSessionState.derive(
        isRunning: false,
        isArmed: true,
        lastExitCode: 15,
        isConfigured: true,
        commandIntent: .stopRequested,
        phase: .stopRequested,
        hasValidatedRuntimeEvidence: false
    )
    let unexpectedSignalState = AppSessionState.derive(
        isRunning: false,
        isArmed: true,
        lastExitCode: 15,
        isConfigured: true,
        commandIntent: .idle,
        phase: .runFailed,
        hasValidatedRuntimeEvidence: false
    )

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
func appSidebarSessionIndicatorUsesNonColorStateCue() {
    let states: [AppSessionState] = [
        .unconfigured,
        .ready,
        .armed,
        .connecting,
        .supervisorRunning,
        .dryRunRunning,
        .validating,
        .awaitingEvidence,
        .validated,
        .receiverWarning,
        .live,
        .error,
    ]

    for state in states {
        #expect(AppSidebarSessionIndicatorPolicy.systemImage(for: state) == state.systemImage)
        #expect(!AppSidebarSessionIndicatorPolicy.systemImage(for: state).isEmpty)
        #expect(AppSidebarSessionIndicatorPolicy.accessibilityLabel(for: state).contains(state.rawValue))
    }
    #expect(AppSidebarSessionIndicatorPolicy.systemImage(for: .ready) != AppSidebarSessionIndicatorPolicy.systemImage(for: .error))
    #expect(AppSidebarSessionIndicatorPolicy.systemImage(for: .armed) != AppSidebarSessionIndicatorPolicy.systemImage(for: .live))
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
    #expect(AppSessionState.derive(
        isRunning: controller.isRunning,
        isArmed: controller.armedForExecution,
        lastExitCode: controller.lastExitCode,
        isConfigured: true,
        commandIntent: .stopRequested,
        phase: controller.phase,
        hasValidatedRuntimeEvidence: false
    ) == .ready)
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
func appValidationReadinessRequiresCurrentSessionToken() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-session-token-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let reportURL = directory.appendingPathComponent("supervisor.json")
    try Data("{}".utf8).write(to: reportURL)

    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = reportURL.path
    let controller = AppExecutionController(settings: settings)
    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = "/private/tmp/open-lola"

    #expect(controller.validationReadiness(operatorSurface: surface) == .staleReport(reportURL.path))

    controller.sessionToken = "current-session"
    try AppRuntimeEvidenceScope.writeSessionToken("older-session", reportPath: reportURL.path)
    #expect(controller.validationReadiness(operatorSurface: surface) == .staleReport(reportURL.path))
    #expect(!AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
        executionKind: .directMacPeer,
        validationExitCode: 0,
        directPeerLatencyMetrics: AppLatencyHeroMetrics.make(from: [
            appMeasuredPassDirectPeerSessionReport(id: "stale-peer-report", peerID: "peer-a"),
        ]),
        externalConnectorReport: nil,
        reportPath: reportURL.path,
        currentSessionToken: controller.sessionToken
    ))

    try AppRuntimeEvidenceScope.writeSessionToken("current-session", reportPath: reportURL.path)
    try Data("{}".utf8).write(to: reportURL)
    #expect(controller.validationReadiness(operatorSurface: surface) == .ready)
    #expect(AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
        executionKind: .directMacPeer,
        validationExitCode: 0,
        directPeerLatencyMetrics: AppLatencyHeroMetrics.make(from: [
            appMeasuredPassDirectPeerSessionReport(id: "current-peer-report", peerID: "peer-a"),
        ]),
        externalConnectorReport: nil,
        reportPath: reportURL.path,
        currentSessionToken: controller.sessionToken
    ))
}

@MainActor
@Test
func appRuntimeConfigurationChangeInvalidatesValidatedEvidenceBeforeStart() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-runtime-invalidation-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let supervisorURL = directory.appendingPathComponent("supervisor-pass.json")
    try writeAppMeasuredPassSupervisorReport(directory: directory, supervisorURL: supervisorURL)

    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = supervisorURL.path
    let controller = AppExecutionController(settings: settings)
    controller.sessionToken = "validated-session"
    try AppRuntimeEvidenceScope.writeSessionToken("validated-session", reportPath: supervisorURL.path)
    try FileManager.default.setAttributes(
        [.modificationDate: Date().addingTimeInterval(1)],
        ofItemAtPath: supervisorURL.path
    )

    controller.finishValidation(exitCode: 0)
    controller.armedForExecution = true

    #expect(controller.lastValidationResult == .passed)
    #expect(controller.hasValidatedRuntimeEvidence)
    #expect(AppTransportStartPolicy.canStart(
        armedForExecution: controller.armedForExecution,
        dryRunAvailable: true,
        lastValidationResult: controller.lastValidationResult,
        hasValidatedRuntimeEvidence: controller.hasValidatedRuntimeEvidence
    ))

    controller.invalidateRuntimeEvidenceAfterConfigurationChange()

    #expect(controller.lastValidationResult == .unknown)
    #expect(controller.lastValidationExitCode == nil)
    #expect(controller.lastValidationFinishedAt == nil)
    #expect(controller.lastLatencyMetrics == nil)
    #expect(controller.lastExternalConnectorReport == nil)
    #expect(controller.lastCaptureReport == nil)
    #expect(controller.sessionToken == nil)
    #expect(controller.status == "Configuration changed. Revalidate before starting.")
    #expect(!controller.hasValidatedRuntimeEvidence)
    #expect(!AppTransportStartPolicy.canStart(
        armedForExecution: controller.armedForExecution,
        dryRunAvailable: true,
        lastValidationResult: controller.lastValidationResult,
        hasValidatedRuntimeEvidence: controller.hasValidatedRuntimeEvidence
    ))

    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = "/private/tmp/open-lola"
    #expect(controller.validationReadiness(operatorSurface: surface) == .staleReport(supervisorURL.path))
}

@Test
func appRuntimeEvidenceInvalidationPolicyTracksRuntimeSurfaceChangesOnly() {
    let original = appOperatorState(remoteSelectionComplete: true)

    var commandOnly = original
    commandOnly.commandIntent = .runRequested
    #expect(!AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
        oldSurface: original,
        newSurface: commandOnly
    ))

    var controlModeOnly = original
    controlModeOnly.controlMode = .advanced
    #expect(!AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
        oldSurface: original,
        newSurface: controlModeOnly
    ))

    var portChanged = original
    portChanged.directPeerCommandFields.audioPort = 57_090
    #expect(AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
        oldSurface: original,
        newSurface: portChanged
    ))

    var localSelectionChanged = original
    localSelectionChanged.inventory.selection.audioInputUID = "other-input"
    #expect(AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
        oldSurface: original,
        newSurface: localSelectionChanged
    ))

    var windowsReportChanged = original
    windowsReportChanged.windowsLoLaPeerFields.outputPath = "/tmp/open-lola-app/changed-windows-lola.json"
    #expect(AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
        oldSurface: original,
        newSurface: windowsReportChanged
    ))
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
func appValidationReadinessRejectsFreshTokenWithStaleReportContent() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-stale-report-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let reportURL = directory.appendingPathComponent("supervisor.json")
    try Data("{}".utf8).write(to: reportURL)

    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = reportURL.path
    let controller = AppExecutionController(settings: settings)
    controller.sessionToken = "fresh-session"
    try AppRuntimeEvidenceScope.writeSessionToken("fresh-session", reportPath: reportURL.path)
    try FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSince1970: 1_000)],
        ofItemAtPath: reportURL.path
    )
    try FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSince1970: 2_000)],
        ofItemAtPath: AppRuntimeEvidenceScope.sessionTokenURL(reportPath: reportURL.path).path
    )

    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = "/private/tmp/open-lola"

    #expect(controller.validationReadiness(operatorSurface: surface) == .staleReport(reportURL.path))
    #expect(AppRuntimeEvidenceScope.sessionTokenMatchResult(
        reportPath: reportURL.path,
        currentSessionToken: "fresh-session"
    ) == .staleReport)
    #expect(AppRuntimeEvidenceScope.hasValidatedRuntimeEvidenceState(
        executionKind: .directMacPeer,
        validationExitCode: 0,
        directPeerLatencyMetrics: AppLatencyHeroMetrics.make(from: [
            appMeasuredPassDirectPeerSessionReport(id: "current-peer-report", peerID: "peer-a"),
        ]),
        externalConnectorReport: nil,
        reportPath: reportURL.path,
        currentSessionToken: "fresh-session"
    ) == .staleReport)
}

@MainActor
@Test
func appRuntimeEvidenceDistinguishesCorruptReportsAndUnreadableSessionTokens() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-evidence-errors-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let corruptReportURL = directory.appendingPathComponent("supervisor-corrupt.json")
    try Data("{".utf8).write(to: corruptReportURL)
    guard case .decodeFailure = AppLatencyHeroMetrics.loadResult(fromSupervisorReportPath: corruptReportURL.path) else {
        Issue.record("Expected corrupt supervisor JSON to report decodeFailure")
        return
    }

    let missingReportURL = directory.appendingPathComponent("supervisor-missing.json")
    #expect(AppLatencyHeroMetrics.loadResult(fromSupervisorReportPath: missingReportURL.path) == .absent)

    let reportURL = directory.appendingPathComponent("supervisor.json")
    try Data("{}".utf8).write(to: reportURL)
    let tokenURL = AppRuntimeEvidenceScope.sessionTokenURL(reportPath: reportURL.path)
    try Data([0xff, 0xfe, 0xfd]).write(to: tokenURL)

    guard case .readError = AppRuntimeEvidenceScope.sessionTokenMatchResult(
        reportPath: reportURL.path,
        currentSessionToken: "current-session"
    ) else {
        Issue.record("Expected invalid UTF-8 token to report readError")
        return
    }

    let metrics = AppLatencyHeroMetrics.make(from: [
        appMeasuredPassDirectPeerSessionReport(id: "current-peer-report", peerID: "peer-a"),
    ])
    guard case .tokenReadError = AppRuntimeEvidenceScope.hasValidatedRuntimeEvidenceState(
        executionKind: .directMacPeer,
        validationExitCode: 0,
        directPeerLatencyMetrics: metrics,
        externalConnectorReport: nil,
        reportPath: reportURL.path,
        currentSessionToken: "current-session"
    ) else {
        Issue.record("Expected runtime evidence state to preserve token read error")
        return
    }

    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = reportURL.path
    let controller = AppExecutionController(settings: settings)
    controller.sessionToken = "current-session"
    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = "/private/tmp/open-lola"

    guard case .evidenceReadError = controller.validationReadiness(operatorSurface: surface) else {
        Issue.record("Expected validation readiness to surface token read error")
        return
    }
}

@MainActor
@Test
func appExecutionValidationRequiresCompleteCurrentReportEvidence() throws {
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
        ),
    ])

    controller.finishValidation(exitCode: 0)

    #expect(controller.phase == .validationFailed)
    #expect(controller.status == "Validation evidence incomplete.")
    #expect(!controller.hasValidatedRuntimeEvidence)
    #expect(controller.lastLatencyMetrics == nil)
    #expect(controller.lastError?.contains("Validated supervisor report missing or unreadable") == true)

    var state = appOperatorState(remoteSelectionComplete: false)
    state.sessionMode = .windowsLoLa
    state.windowsLoLaPeerFields.outputPath = "/private/tmp/open-lola-missing-windows-lola-\(UUID().uuidString).json"
    let windowsController = AppExecutionController()

    _ = try windowsController.prepareValidationContext(operatorSurface: state)
    windowsController.finishValidation(exitCode: 0)

    #expect(windowsController.phase == .validationFailed)
    #expect(windowsController.status == "Validation evidence incomplete.")
    #expect(!windowsController.hasValidatedRuntimeEvidence)
    #expect(windowsController.lastExternalConnectorReport == nil)
    #expect(windowsController.lastError?.contains("Validated external connector report missing or unreadable") == true)

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-validation-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let malformedSupervisorURL = directory.appendingPathComponent("supervisor-malformed.json")
    try Data("{".utf8).write(to: malformedSupervisorURL)
    var malformedSupervisorSettings = NativeAppShellExecutionSettings()
    malformedSupervisorSettings.supervisorReportPath = malformedSupervisorURL.path
    let malformedSupervisorController = AppExecutionController(settings: malformedSupervisorSettings)

    malformedSupervisorController.finishValidation(exitCode: 0)

    #expect(malformedSupervisorController.phase == .validationFailed)
    #expect(malformedSupervisorController.status == "Validation evidence incomplete.")
    #expect(!malformedSupervisorController.hasValidatedRuntimeEvidence)
    #expect(malformedSupervisorController.lastLatencyMetrics == nil)
    #expect(malformedSupervisorController.lastError?.contains("Validated supervisor report missing or unreadable") == true)

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
    #expect(malformedWindowsController.lastError?.contains("Validated external connector report missing or unreadable") == true)
    #expect(malformedWindowsController.errorLog.contains { $0.contains("External connector report unavailable") })

    let partialWindowsReportURL = directory.appendingPathComponent("windows-partial.json")
    try appExternalConnectorSessionReport(verdict: .partial, outputPath: partialWindowsReportURL.path)
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
    #expect(partialWindowsController.lastError == "External connector evidence incomplete: verdict partial")

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
    #expect(failedWindowsController.lastError == "External connector evidence incomplete: verdict fail")

    let falsePassWindowsReportURL = directory.appendingPathComponent("windows-pass.json")
    try appExternalConnectorSessionReport(verdict: .pass, outputPath: falsePassWindowsReportURL.path)
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
    #expect(falsePassWindowsController.lastError?.contains(
        "Validated external connector report missing or unreadable"
    ) == true)

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
        appProcessResult(peerID: "peer-b", reportPath: reportBURL.path),
    ]
    let preflightChecks = [
        DirectPeerTwoPeerPreflightCheck(id: "unit", severity: .pass, passed: true, message: "ok"),
    ]
    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: processResults,
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .partial,
        notes: "unit test supervisor report"
    ).prettyJSONData().write(to: partialSupervisorURL)

    var partialSettings = NativeAppShellExecutionSettings()
    partialSettings.supervisorReportPath = partialSupervisorURL.path
    let partialController = AppExecutionController(settings: partialSettings)

    partialController.finishValidation(exitCode: 0)

    #expect(partialController.phase == .validationFailed)
    #expect(partialController.status == "Validation evidence incomplete.")
    #expect(!partialController.hasValidatedRuntimeEvidence)
    #expect(partialController.lastLatencyMetrics?.isPartial == true)
    #expect(partialController.lastLatencyMetrics?.supervisorVerdict == .partial)
    #expect(partialController.lastReport?.verdict == .partial)
    #expect(partialController.lastError?.contains("supervisor verdict partial") == true)

    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: processResults,
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .fail,
        notes: "unit test supervisor report"
    ).prettyJSONData().write(to: failedSupervisorURL)

    var failedSupervisorSettings = NativeAppShellExecutionSettings()
    failedSupervisorSettings.supervisorReportPath = failedSupervisorURL.path
    let failedSupervisorController = AppExecutionController(settings: failedSupervisorSettings)

    failedSupervisorController.finishValidation(exitCode: 0)

    #expect(failedSupervisorController.phase == .validationFailed)
    #expect(failedSupervisorController.status == "Validation evidence incomplete.")
    #expect(!failedSupervisorController.hasValidatedRuntimeEvidence)
    #expect(failedSupervisorController.lastLatencyMetrics?.isPartial == true)
    #expect(failedSupervisorController.lastLatencyMetrics?.supervisorVerdict == .fail)
    #expect(failedSupervisorController.lastReport?.verdict == .fail)
    #expect(failedSupervisorController.lastError?.contains("supervisor verdict fail") == true)

    try appMeasuredPassDirectPeerSessionReport(id: "peer-a-pass-report", peerID: "peer-a")
        .prettyJSONData()
        .write(to: passReportAURL)
    try appMeasuredPassDirectPeerSessionReport(id: "peer-b-pass-report", peerID: "peer-b")
        .prettyJSONData()
        .write(to: passReportBURL)
    let passProcessResults = [
        appProcessResult(
            peerID: "peer-a",
            reportPath: passReportAURL.path,
            receiveProofPath: directory.appendingPathComponent("peer-a-rx-proof.json").path
        ),
        appProcessResult(
            peerID: "peer-b",
            reportPath: passReportBURL.path,
            receiveProofPath: directory.appendingPathComponent("peer-b-rx-proof.json").path
        ),
    ]

    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: passProcessResults,
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        aggregateReportPath: directory.appendingPathComponent("aggregate.json").path,
        aggregateExecuted: true,
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .pass,
        notes: "unit test supervisor report"
    ).prettyJSONData().write(to: passSupervisorURL)

    var passingSettings = NativeAppShellExecutionSettings()
    passingSettings.supervisorReportPath = passSupervisorURL.path
    let nonzeroValidationController = AppExecutionController(settings: passingSettings)

    nonzeroValidationController.finishValidation(exitCode: 1)

    #expect(nonzeroValidationController.phase == .validationFailed)
    #expect(nonzeroValidationController.status == "Validation failed.")
    #expect(!nonzeroValidationController.hasValidatedRuntimeEvidence)
    #expect(nonzeroValidationController.lastLatencyMetrics == nil)
    #expect(nonzeroValidationController.lastReport?.verdict == .partial)

    let passingController = AppExecutionController(settings: passingSettings)

    passingController.finishValidation(exitCode: 0)

    #expect(passingController.phase == .validationPassed)
    #expect(passingController.status == "Validation passed.")
    #expect(passingController.hasValidatedRuntimeEvidence)
    #expect(passingController.lastLatencyMetrics?.isPartial == false)
    #expect(passingController.lastReport?.verdict == .pass)
    #expect(passingController.lastReport?.notes.contains("Real-world PASS remains gated") == true)
}

@MainActor
@Test
func appExecutionValidationRejectsInvalidDirectPeerPassReportGraph() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-invalid-pass-graph-\(UUID().uuidString)", isDirectory: true)
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
        ),
    ]
    let preflightChecks = [
        DirectPeerTwoPeerPreflightCheck(id: "unit", severity: .pass, passed: true, message: "ok"),
    ]

    let invalidSupervisorURL = directory.appendingPathComponent("supervisor-invalid-pass.json")
    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor-invalid-pass",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: validProcessResults,
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .pass,
        notes: "unit test invalid pass supervisor"
    ).prettyJSONData().write(to: invalidSupervisorURL)

    let invalidSupervisorController = AppExecutionController(settings: {
        var settings = NativeAppShellExecutionSettings()
        settings.supervisorReportPath = invalidSupervisorURL.path
        return settings
    }())
    invalidSupervisorController.finishValidation(exitCode: 0)

    #expect(invalidSupervisorController.phase == .validationFailed)
    #expect(!invalidSupervisorController.hasValidatedRuntimeEvidence)
    #expect(invalidSupervisorController.lastLatencyMetrics == nil)
    #expect(invalidSupervisorController.lastError?.contains("Validated supervisor report missing or unreadable") == true)

    let partialChildSupervisorURL = directory.appendingPathComponent("supervisor-partial-child.json")
    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor-partial-child",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: [
            validProcessResults[0],
            appProcessResult(
                peerID: "peer-b",
                reportPath: partialBURL.path,
                receiveProofPath: directory.appendingPathComponent("peer-b-partial-rx-proof.json").path
            ),
        ],
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        aggregateReportPath: directory.appendingPathComponent("aggregate-partial-child.json").path,
        aggregateExecuted: true,
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .pass,
        notes: "unit test partial child supervisor"
    ).prettyJSONData().write(to: partialChildSupervisorURL)

    var partialChildSettings = NativeAppShellExecutionSettings()
    partialChildSettings.supervisorReportPath = partialChildSupervisorURL.path
    let partialChildController = AppExecutionController(settings: partialChildSettings)
    partialChildController.finishValidation(exitCode: 0)

    #expect(partialChildController.phase == .validationFailed)
    #expect(!partialChildController.hasValidatedRuntimeEvidence)
    #expect(partialChildController.lastLatencyMetrics?.peerReportFailures.contains {
        $0.contains("peer-b-partial") && $0.contains("partial")
    } == true)
    #expect(partialChildController.lastError?.contains("peer report verdict partial") == true)

    let invalidChildSupervisorURL = directory.appendingPathComponent("supervisor-invalid-child.json")
    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor-invalid-child",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: [
            validProcessResults[0],
            appProcessResult(
                peerID: "peer-b",
                reportPath: invalidBURL.path,
                receiveProofPath: directory.appendingPathComponent("peer-b-invalid-rx-proof.json").path
            ),
        ],
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        aggregateReportPath: directory.appendingPathComponent("aggregate-invalid-child.json").path,
        aggregateExecuted: true,
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .pass,
        notes: "unit test invalid child supervisor"
    ).prettyJSONData().write(to: invalidChildSupervisorURL)

    var invalidChildSettings = NativeAppShellExecutionSettings()
    invalidChildSettings.supervisorReportPath = invalidChildSupervisorURL.path
    let invalidChildController = AppExecutionController(settings: invalidChildSettings)
    invalidChildController.finishValidation(exitCode: 0)

    #expect(invalidChildController.phase == .validationFailed)
    #expect(!invalidChildController.hasValidatedRuntimeEvidence)
    #expect(invalidChildController.lastLatencyMetrics?.loadFailures.contains {
        $0.contains("peer-b") && $0.contains("negativeMetric")
    } == true)
    #expect(invalidChildController.lastError?.contains("peer-b") == true)
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

@Test
func appPacketMonitorAndSectionSelectionKeepUnavailableViewsInactive() {
    let emptyReport = LoLaCompatibilityCaptureReport(
        id: "empty-capture",
        title: "Empty capture",
        capturedAt: "2026-05-14T00:00:00Z",
        inputPath: "fixtures/empty.pcapng",
        inputFormat: .pcapng,
        summary: LoLaCompatibilityCaptureSummary(packets: []),
        packets: [],
        verdict: .partial,
        evidenceBoundary: "unit-test packet monitor",
        notes: "empty capture"
    )

    #expect(AppPacketMonitorRowsState.make(
        report: emptyReport,
        streamFilter: .all,
        searchText: "no-match"
    ) == .rows([]))

    let failureState = AppPacketMonitorRowsState.make(
        report: emptyReport,
        streamFilter: .all,
        searchText: "",
        limit: -1
    )
    guard case .failure(let message) = failureState else {
        Issue.record("Expected row-building failure state")
        return
    }
    #expect(message.contains("negativeLimit"))

    let sections = NativeAppShellSurfaceContract.releaseReadiness.sections
    let settingsOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "settings")
    let packetOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "packet")

    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: settingsOnly,
        sessionState: .live,
        captureReportAvailable: true
    ) == .settings)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == .overview)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .ready,
        captureReportAvailable: false
    ) == .packetMonitor)
    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == nil)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == nil)
    #expect(AppPacketMonitorSidebarPolicy.disabledReason(sessionState: .unconfigured) != nil)
    #expect(AppPacketMonitorSidebarPolicy.dimmedReason(
        sessionState: .ready,
        captureReportAvailable: false
    ) == AppPacketMonitorSidebarPolicy.missingCaptureHelp)
    #expect(AppPacketMonitorSidebarPolicy.missingCaptureHelp.contains("No capture yet"))
    #expect(AppPacketMonitorSidebarPolicy.disabledReason(sessionState: .ready) == nil)
    #expect(AppPacketMonitorSidebarPolicy.dimmedReason(
        sessionState: .ready,
        captureReportAvailable: true
    ) == nil)
    #expect(AppUnavailableSectionCopy.detail(
        searchText: "packet",
        sessionState: .ready,
        captureReportAvailable: false
    ).contains("No capture yet"))
    #expect(!AppUnavailableSectionCopy.detail(
        searchText: "packet",
        sessionState: .ready,
        captureReportAvailable: false
    ).contains("unavailable"))
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
    #expect(incomplete.blockers.contains { $0.id == "evidence" && $0.targetSection == .session })

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

private func appOperatorState(remoteSelectionComplete: Bool) -> NativeAppShellOperatorPrototypeState {
    var remoteInventory = NativeAppShellLocalMediaInventory.editableRemotePlaceholder(peerName: "remote-mac")
    if remoteSelectionComplete {
        remoteInventory = NativeAppShellLocalMediaInventory(
            capturedAt: "2026-05-14T00:00:00Z",
            hostName: "remote-mac",
            audioDevices: [
                NativeAppShellAudioDeviceOption(
                    name: "Remote RME",
                    uid: "remote-rme",
                    inputChannelCount: 64,
                    outputChannelCount: 64,
                    nominalSampleRateHertz: 48_000,
                    currentBufferFrameSize: 32
                ),
            ],
            videoDevices: [
                NativeAppShellVideoDeviceOption(
                    label: "Remote ATEM",
                    uniqueId: "remote-atem",
                    manufacturer: "Blackmagic Design",
                    transport: "USB",
                    sourcePolicy: .blackmagicFirstAvFoundationFallback,
                    formatCount: 1
                ),
            ],
            selection: NativeAppShellLocalMediaSelection(
                audioInputUID: "remote-rme",
                audioOutputUID: "remote-rme",
                videoDeviceID: "remote-atem"
            ),
            inventoryErrors: []
        )
    }
    var fields = NativeAppShellDirectPeerCommandFields.appDefault
    fields.localHost = "192.0.2.10"
    fields.remoteHost = "192.0.2.20"
    return NativeAppShellOperatorPrototypeState(
        inventory: NativeAppShellLocalMediaInventory(
            capturedAt: "2026-05-14T00:00:00Z",
            hostName: "local-mac",
            audioDevices: [
                NativeAppShellAudioDeviceOption(
                    name: "Local RME",
                    uid: "local-rme",
                    inputChannelCount: 64,
                    outputChannelCount: 64,
                    nominalSampleRateHertz: 48_000,
                    currentBufferFrameSize: 32
                ),
            ],
            videoDevices: [
                NativeAppShellVideoDeviceOption(
                    label: "Local ATEM",
                    uniqueId: "local-atem",
                    manufacturer: "Blackmagic Design",
                    transport: "USB",
                    sourcePolicy: .blackmagicFirstAvFoundationFallback,
                    formatCount: 1
                ),
            ],
            selection: NativeAppShellLocalMediaSelection(
                audioInputUID: "local-rme",
                audioOutputUID: "local-rme",
                videoDeviceID: "local-atem"
            ),
            inventoryErrors: []
        ),
        remoteInventory: remoteInventory,
        commandIntent: .idle,
        remoteOrchestrationEnabled: false,
        startsLongRunningProcess: false,
        directPeerCommandFields: fields
    )
}

@MainActor
private func seedValidatedRuntimeEvidence(_ controller: AppExecutionController) {
    controller.lastValidationExitCode = 0
    controller.lastValidationResult = .passed
    controller.lastValidationFinishedAt = "2026-05-20T00:00:00Z"
    controller.lastLatencyMetrics = AppLatencyHeroMetrics.make(from: [
        appMeasuredPassDirectPeerSessionReport(id: "validated-peer-report", peerID: "peer-a"),
    ])
    controller.status = "Validation passed."
    controller.phase = .validationPassed
}

private func writeAppMeasuredPassSupervisorReport(directory: URL, supervisorURL: URL) throws {
    let reportAURL = directory.appendingPathComponent("peer-a-pass.json")
    let reportBURL = directory.appendingPathComponent("peer-b-pass.json")
    try appMeasuredPassDirectPeerSessionReport(id: "peer-a-pass-report", peerID: "peer-a")
        .prettyJSONData()
        .write(to: reportAURL)
    try appMeasuredPassDirectPeerSessionReport(id: "peer-b-pass-report", peerID: "peer-b")
        .prettyJSONData()
        .write(to: reportBURL)
    let processResults = [
        appProcessResult(
            peerID: "peer-a",
            reportPath: reportAURL.path,
            receiveProofPath: directory.appendingPathComponent("peer-a-rx-proof.json").path
        ),
        appProcessResult(
            peerID: "peer-b",
            reportPath: reportBURL.path,
            receiveProofPath: directory.appendingPathComponent("peer-b-rx-proof.json").path
        ),
    ]
    let preflightChecks = [
        DirectPeerTwoPeerPreflightCheck(id: "unit", severity: .pass, passed: true, message: "ok"),
    ]
    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor",
        capturedAt: "2026-05-20T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: processResults,
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        aggregateReportPath: directory.appendingPathComponent("aggregate.json").path,
        aggregateExecuted: true,
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .pass,
        notes: "unit test measured supervisor report"
    ).prettyJSONData().write(to: supervisorURL)
}

private func appDirectPeerSessionReport(
    id: String,
    packetsReceived: Int,
    packetsLost: Int,
    jitterMicroseconds: Double,
    latencyMicroseconds: Double
) -> DirectPeerSessionReport {
    DirectPeerSessionReport(
        id: id,
        capturedAt: "2026-05-14T00:00:00Z",
        configuration: appSessionConfiguration(),
        metrics: DirectPeerSessionReportMetrics(
            controlMessagesSent: 1,
            packetsSent: packetsReceived + packetsLost,
            packetsReceived: packetsReceived,
            packetsLost: packetsLost,
            jitterMicroseconds: jitterMicroseconds,
            audioPacketsRouted: packetsReceived,
            videoPacketsRouted: 0,
            recoveryEvents: 0,
            audioPayloadsSentOnControlChannel: 0
        ),
        avRuntime: DirectPeerSessionAVRuntimeMetadata(
            avProfile: .fastest,
            previewMode: .off,
            mediaSourceMode: .syntheticFixture,
            audioDeviceUID: "local-rme",
            sampleRateHertz: 48_000,
            selectedBufferFrameSize: 32,
            latencyProfile: .directAudioFirst,
            rxBufferProfile: .direct,
            videoDeviceID: "local-atem",
            videoFrameRate: 30,
            videoStreamID: 100,
            fastestPassBlockedReason: "unit test partial",
            fastestAVBaselineComparison: DirectPeerSessionFastestAVBaselineComparison(
                audioOnlyBaselineReportID: "audio-only",
                audioOnlyBaselineReportPath: "reports/audio-only.json",
                comparisonArtifactPath: "reports/comparison.json",
                audioOnlyLatencyP99Microseconds: latencyMicroseconds,
                fastestAVAudioLatencyP99Microseconds: latencyMicroseconds,
                audioLatencyEqualToBaseline: true,
                rxBufferEqualToBaseline: true,
                lossJitterEqualToBaseline: true
            )
        ),
        verdict: .partial,
        notes: "unit test partial report"
    )
}

private func appMeasuredPassDirectPeerSessionReport(id: String, peerID _: String) -> DirectPeerSessionReport {
    DirectPeerSessionReport(
        id: id,
        capturedAt: "2026-05-14T00:00:00Z",
        configuration: appSessionConfiguration(),
        metrics: DirectPeerSessionReportMetrics(
            controlMessagesSent: 1,
            packetsSent: 90,
            packetsReceived: 90,
            packetsLost: 0,
            jitterMicroseconds: 2_500,
            audioPacketsRouted: 90,
            videoPacketsRouted: 1,
            recoveryEvents: 0,
            audioPayloadsSentOnControlChannel: 0
        ),
        avRuntime: DirectPeerSessionAVRuntimeMetadata(
            avProfile: .balanced,
            previewMode: .on,
            mediaSourceMode: .production,
            audioDeviceUID: "local-rme",
            inputDeviceUID: "local-rme",
            outputDeviceUID: "local-rme",
            sampleRateHertz: 48_000,
            selectedBufferFrameSize: 32,
            latencyProfile: .balancedAV,
            rxBufferProfile: .small,
            videoDeviceID: "local-atem",
            videoFrameRate: 30,
            videoStreamID: 100,
            fastestPassBlockedReason: "balanced profile selected for measured app-shell pass candidate",
            runtimeMetrics: DirectPeerSessionAVRuntimeMetrics(
                audioPayloadsCaptured: 1,
                audioPayloadsSent: 1,
                audioPayloadsQueuedForPlayout: 1,
                videoFramesCaptured: 1,
                videoFramesSent: 1,
                videoFragmentsSent: 2,
                videoFragmentsReceived: 2,
                videoFramesReassembled: 1,
                previewFramesSubmitted: 1,
                audioReceiveDrainIterations: 1,
                videoReceiveDrainIterations: 1
            ),
            videoFormat: measuredPassVideoFormat(),
            receiveProof: measuredPassReceiveProof()
        ),
        measuredEvidence: DirectPeerSessionMeasuredEvidence(
            kind: .physicalTwoPeerMacs,
            sourcePeerLabel: "mac-a-m4-lab",
            receiverPeerLabel: "mac-b-m4-lab",
            routeLabel: "direct-en6-cable-run",
            packetCapturePath: "reports/captures/direct-p2p-av-mac-b.pcapng",
            packetCapture: directPeerSessionPacketCaptureArtifact(),
            dscpObservation: "EF preserved at receiver ingress",
            dscp: directPeerSessionDSCPEvidence(),
            clockSyncSummary: "PTP offset below one millisecond",
            clock: directPeerSessionClockEvidence(),
            rawVideoReceiveEvidence: "m06-direct-p2p-av-mac-b videoFramesReassembled greater than zero",
            durationSeconds: 30
        ),
        verdict: .pass,
        notes: "unit test measured report"
    )
}

private func appProcessResult(
    peerID: String,
    reportPath: String,
    receiveProofPath: String? = nil
) -> DirectPeerTwoPeerLocalRunProcessResult {
    DirectPeerTwoPeerLocalRunProcessResult(
        peerID: peerID,
        role: peerID == "peer-a" ? .initiator : .responder,
        reportPath: reportPath,
        command: ["open-lola", "direct-p2p-session-run"],
        exitCode: 0,
        collectedReportPath: reportPath,
        collectedReceiveProofPath: receiveProofPath
    )
}

private func appExternalConnectorSessionReport(
    verdict: MeasurementVerdict,
    outputPath: String
) throws -> ExternalConnectorSessionReport {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .txRx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: outputPath,
        dryRun: false,
        mediaMode: .audioVideo,
        controlTransport: .udp,
        durationSeconds: 1,
        controlPort: 7_000,
        audioPort: 19_788,
        videoPort: 19_798,
        channels: 2,
        sampleRateHertz: 44_100,
        framesPerPacket: 64,
        videoWidth: 640,
        videoHeight: 480,
        videoFrameRate: 25,
        videoBitsPerPixel: 8,
        mediaPacketCount: 1
    )
    return ExternalConnectorSessionReport(
        id: "external-connector-\(verdict.rawValue)",
        capturedAt: "2026-05-15T00:00:00Z",
        connector: configuration.connector,
        role: configuration.role,
        dryRun: false,
        plan: try ExternalConnectorLaunchPlan.build(configuration: configuration),
        process: nil,
        auxiliaryProcesses: [],
        lolaControl: nil,
        lolaMedia: nil,
        runtimeError: verdict == .fail ? "unit test runtime failure" : nil,
        verdict: verdict,
        notes: "unit test Windows LoLa connector report"
    )
}

private func appSessionConfiguration() -> SessionConfiguration {
    SessionConfiguration(
        sessionID: "app-test-session",
        peers: [
            PeerIdentity(
                peerID: "peer-a",
                displayName: "Peer A",
                implementationName: "open-lola",
                implementationVersion: "test"
            ),
            PeerIdentity(
                peerID: "peer-b",
                displayName: "Peer B",
                implementationName: "open-lola",
                implementationVersion: "test"
            ),
        ],
        latencyProfile: .directAudioFirst,
        rxBufferProfile: .direct,
        audioStreams: [],
        videoStreams: [],
        controlEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 19_001),
        audioEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 19_002),
        videoEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 19_003),
        metricsEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 19_004),
        peerMediaEndpoints: [
            appPeerEndpoints(peerID: "peer-a", basePort: 19_001, host: "192.0.2.10"),
            appPeerEndpoints(peerID: "peer-b", basePort: 19_011, host: "192.0.2.20"),
        ],
        mtuBytes: 1_200,
        metricIntervalMilliseconds: 1_000,
        reconnectDeadlineMilliseconds: 1_000
    )
}

private func appPeerEndpoints(peerID: String, basePort: UInt16, host: String) -> SessionPeerMediaEndpoints {
    SessionPeerMediaEndpoints(
        peerID: peerID,
        controlEndpoint: SessionNetworkEndpoint(host: host, port: basePort),
        audioEndpoint: SessionNetworkEndpoint(host: host, port: basePort + 1),
        videoEndpoint: SessionNetworkEndpoint(host: host, port: basePort + 2),
        metricsEndpoint: SessionNetworkEndpoint(host: host, port: basePort + 3)
    )
}
