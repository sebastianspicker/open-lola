import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

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
