// Verifies that app menu action handling covers every contract action.
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func appMenuActionHandlingCoversEveryContractAction() {
    let contractActionIDs = Set(NativeAppShellSurfaceContract.releaseReadiness.actions.map(\.id))

    #expect(contractActionIDs == AppMenuActionHandling.handledActionIDs)
    #expect(AppMenuActionHandling.handledActionIDs.contains("validate-supervisor-report"))
    #expect(!AppMenuActionHandling.handledActionIDs.contains("future-unmapped-action"))
}

@Test
func appValidationShortcutCopyRequiresMenuContractShortcut() {
    #expect(AppExecutionSettingsShortcutCopy.validationShortcutLabel() == "Shortcut: ⌘⇧V")

    let validationActionWithShortcut = NativeAppShellSurfaceAction(
        identity: .init(id: "validate-supervisor-report", title: "Validate Supervisor Report", keyboardShortcut: "command-shift-v"),
        effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false),
        execution: .init(launchesExternalProcess: true)
    )

    #expect(AppExecutionSettingsShortcutCopy.validationShortcutLabel(
        actions: [validationActionWithShortcut]
    ) == "Shortcut: ⌘⇧V")
}

@Test
func appSectionFilterMatchesSectionTitles() {
    let sections = NativeAppShellSurfaceContract.releaseReadiness.sections
    let settingsOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "settings")
    let noMatches = NativeAppShellSectionSearch.visibleSections(sections, query: "not-a-section")

    #expect(settingsOnly.map(\.id) == [.settings])
    #expect(noMatches.isEmpty)
}

@Test
func appSyntheticMetricsRefreshCopySeparatesSourceReportFromLiveRuntime() {
    #expect(AppSyntheticMetricsRefreshState.idle.badgeTitle == "Source/synthetic")
    #expect(AppSyntheticMetricsRefreshState.refreshing.isRefreshing)
    #expect(!AppSyntheticMetricsRefreshState.refreshed.isRefreshing)
    #expect(AppSyntheticMetricsRefreshState.refreshing.buttonHelp.contains("source/synthetic report"))
    #expect(AppSyntheticMetricsRefreshState.refreshing.buttonHelp.contains("does not measure live runtime"))
    #expect(AppSyntheticMetricsRefreshState.refreshed.badgeHelp.contains("refresh completed"))
    #expect(AppSyntheticMetricsRefreshState.refreshed.badgeHelp.contains("No live runtime measurement"))
}

@MainActor
@Test
func appValidationBlocksMissingReportArtifactsBeforeLaunching() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-slice05-validation-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let controller = AppExecutionController()
    var surface = AppShellStoredDefaults.placeholderOperatorSurface()
    let missingDirectReport = directory.appendingPathComponent("missing-supervisor.json").path
    controller.settings.supervisorReportPath = missingDirectReport

    #expect(controller.validationReadiness(operatorSurface: surface) == .missingReport(missingDirectReport))
    controller.validateReport(operatorSurface: surface)
    #expect(controller.lastCommand.isEmpty)
    #expect(controller.status == "Validation unavailable.")
    #expect(controller.phase == .validationFailed)
    #expect(controller.lastError == "Cannot validate missing report artifact: \(missingDirectReport)")

    surface.sessionMode = .windowsLoLa
    let missingWindowsReport = directory.appendingPathComponent("missing-windows-lola.json").path
    surface.windowsLoLaPeerFields.outputPath = missingWindowsReport
    #expect(controller.validationReadiness(operatorSurface: surface) == .missingReport(missingWindowsReport))
}

@MainActor
@Test
func appSlice05UiPoliciesExposeTruthfulOperatorStates() {
    #expect(AppPreviewControlAvailability.unsupportedLocalPreviewHelp.contains("single-stream"))
    #expect(AppPreviewDisabledReasonCopy.unsupportedLocalPreviewControls.contains("Return blend"))
    #expect(AppPreviewDisabledReasonCopy.unsupportedLocalPreviewControls.contains("single-stream"))
    #expect(AppPreviewDisabledReasonCopy.inactivePreviewControl(
        "Monitor gain",
        help: "Open Local Preview Window to apply this control."
    ).contains("Monitor gain: Open Local Preview Window"))
    #expect(AppExecutionModeAvailability.supportedSettingsModes == [.local])

    let settingsView = appShellSettingsView()
    #expect(!settingsView.executionSettingsLocked)
    #expect(settingsView.executionSettingsHelp.contains("next generated command"))
    #expect(AppShellSettingsView.executionSettingsHelp(isRunning: true).contains("locked"))
    #expect(AppShellSettingsView.executionSettingsHelp(
        phase: .validationRunning,
        isRunning: true
    ).contains("validation"))

    #expect(AppWindowSize.operatorMinWidth == 1024)
    #expect(AppWindowSize.operatorMinHeight == 720)
}

@Test
func appSettingsTabsExposeOnlyAvailableModes() {
    #expect(AppShellSettingsTabVisibility.visibleTabs(
        sessionMode: .directMacPeer,
        controlMode: .normal
    ).map(\.title) == ["Execution", "Preview", "Snapshot"])

    #expect(AppShellSettingsTabVisibility.visibleTabs(
        sessionMode: .directMacPeer,
        controlMode: .advanced
    ).map(\.title) == ["Execution", "Peers", "Audio", "Video", "Preview", "Snapshot"])

    #expect(AppShellSettingsTabVisibility.visibleTabs(
        sessionMode: .windowsLoLa,
        controlMode: .advanced
    ).map(\.title) == ["Execution", "Windows LoLa", "Preview", "Snapshot"])

    for mode in [NativeAppShellSessionMode.jackTrip, .ultraGrid] {
        #expect(AppShellSettingsTabVisibility.visibleTabs(
            sessionMode: mode,
            controlMode: .normal
        ) == [.execution, .externalConnector, .preview, .snapshot])
        #expect(AppShellSettingsTabVisibility.visibleTabs(
            sessionMode: mode,
            controlMode: .advanced
        ) == [.execution, .externalConnector, .preview, .snapshot])
    }

    #expect(!AppShellSettingsTabID.allCases.map(\.title).contains("Unavailable"))
}

@Test
func appSidebarSettingsSectionStaysReadOnlyAndSeparateFromNativeSettingsEditor() {
    let settingsSection = NativeAppShellSurfaceContract.releaseReadiness.sections.first { $0.id == .settings }

    #expect(settingsSection?.readOnly == true)
}

@MainActor
@Test
func appPreviewReceiverPhaseReconcilesDelayedServiceStatusChanges() {
    let previewState = AppPreviewReceiverState()

    previewState.startReceiverPreview(audioInputUID: "input", videoDeviceID: "video")
    previewState.videoPreviewController.phase = .starting
    previewState.videoPreviewController.status = "Camera is warming up"
    previewState.audioLevelMeter.phase = .starting
    previewState.audioLevelMeter.status = "Audio permission prompt is pending"
    #expect(previewState.previewPhase == .starting)

    previewState.videoPreviewController.phase = .active
    previewState.videoPreviewController.status = "Camera frames flowing"
    previewState.audioLevelMeter.phase = .active
    previewState.audioLevelMeter.status = "Meter samples flowing"
    #expect(previewState.previewPhase == .active)

    previewState.audioLevelMeter.phase = .failed
    previewState.audioLevelMeter.status = "Audio meter unavailable: test failure"
    #expect(previewState.previewPhase == .degraded)

    previewState.videoPreviewController.phase = .failed
    previewState.videoPreviewController.status = "Video preview unavailable: test failure"
    #expect(previewState.previewPhase == .failed)

    previewState.stopReceiverPreview()
    previewState.videoPreviewController.status = "Live video preview: late callback"
    #expect(previewState.previewPhase == .idle)
}

@Test
func appDeviceSetupRecoveryPolicyNamesRefreshDiagnosticsAndPrivacy() {
    let emptyInventory = NativeAppShellLocalMediaInventory(
        capturedAt: "2026-05-20T00:00:00Z",
        hostName: "local-mac",
        audioDevices: [],
        videoDevices: [],
        selection: NativeAppShellLocalMediaSelection(
            audioInputUID: nil,
            audioOutputUID: nil,
            videoDeviceID: nil
        ),
        inventoryErrors: ["Core Audio inventory unavailable: permission denied"]
    )
    let recovery = AppDeviceSetupRecoveryPolicy.summary(for: emptyInventory)

    #expect(recovery?.title == "Setup recovery")
    #expect(recovery?.messages.contains { $0.contains("No audio input devices found") } == true)
    #expect(recovery?.messages.contains { $0.contains("No audio output devices found") } == true)
    #expect(recovery?.messages.contains { $0.contains("No video devices found") } == true)
    #expect(recovery?.messages.contains { $0.contains("Open Diagnostics") } == true)
    #expect(recovery?.messages.contains { $0.contains("System Settings > Privacy & Security") } == true)

    #expect(AppDeviceSetupRecoveryPolicy.summary(for: appWorkflowSurface().inventory) == nil)
}

@MainActor
@Test
func appPreviewSetupRecoveryCopyNamesDevicesAndExternalPermissions() {
    let videoPreview = AppVideoPreviewController()
    videoPreview.start(deviceID: nil, enabled: true)
    #expect(videoPreview.status == AppPreviewSetupRecoveryCopy.noVideoDeviceSelected)
    #expect(videoPreview.status.contains("Open Devices"))

    let audioMeter = AppAudioLevelMeter()
    audioMeter.start(inputUID: nil, enabled: true, gain: 0.5)
    #expect(audioMeter.status == AppPreviewSetupRecoveryCopy.noAudioInputSelected)
    #expect(audioMeter.status.contains("refresh inventory"))

    #expect(AppPreviewSetupRecoveryCopy.cameraDenied.contains("System Settings > Privacy & Security"))
    #expect(AppPreviewSetupRecoveryCopy.cameraDenied.contains("restart preview"))
    #expect(AppPreviewSetupRecoveryCopy.microphoneDenied.contains("System Settings > Privacy & Security"))
    #expect(AppPreviewSetupRecoveryCopy.microphoneDenied.contains("restart preview"))
}

@MainActor
@Test
func appSettingsNormalizeUnsupportedSSHExecutionModeBeforeRuntimeCommandGeneration() throws {
    let suiteName = "open-lola-settings-ssh-normalization-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(DirectPeerTwoPeerRunExecutionMode.ssh.rawValue, forKey: AppStorageKeys.executionMode)
    let settings = AppSettings(defaults: defaults)
    var surface = appWorkflowSurface()
    let controller = AppExecutionController()
    let previewState = AppPreviewReceiverState()
    let draft = AppSettingsDraft(settings: settings)

    #expect(settings.executionMode == DirectPeerTwoPeerRunExecutionMode.local.rawValue)

    draft.executionMode = DirectPeerTwoPeerRunExecutionMode.ssh.rawValue
    draft.commit(
        to: settings,
        operatorSurface: &surface,
        executionController: controller,
        previewState: previewState
    )

    try assertUnsupportedSSHExecutionModeIsNormalized(settings: settings, controller: controller)
}

@MainActor
private func assertUnsupportedSSHExecutionModeIsNormalized(
    settings: AppSettings,
    controller: AppExecutionController
) throws {
    #expect(settings.executionMode == DirectPeerTwoPeerRunExecutionMode.local.rawValue)
    #expect(controller.settings.executionMode == .local)
    let arguments = try controller.settings.supervisorArguments(executablePath: "/tmp/open-lola")
    #expect(arguments.contains("--execution-mode"))
    #expect(arguments.contains(DirectPeerTwoPeerRunExecutionMode.local.rawValue))
    #expect(!arguments.contains("--ssh-fallback-explicit"))
}

@MainActor
@Test
func appSettingsDraftRejectsStaleSaveAndReloadsCurrentSettings() throws {
    let suiteName = "open-lola-settings-stale-draft-\(UUID().uuidString)"
    var context = try makeAppSettingsDraftTestContext(suiteName: suiteName)
    defer { context.defaults.removePersistentDomain(forName: suiteName) }
    let defaults = context.defaults
    let settings = context.settings
    let draft = context.draft
    let controller = context.controller
    let previewState = context.previewState

    draft.localPeer = "draft-peer"
    settings.localPeer = "newer-peer"

    #expect(draft.hasSourceConflict(comparedTo: settings))
    let staleResult = draft.commit(
        to: settings,
        operatorSurface: &context.surface,
        executionController: controller,
        previewState: previewState
    )

    #expect(staleResult == .conflict(AppSettingsDraftCommitResult.conflictMessage))
    #expect(settings.localPeer == "newer-peer")
    #expect(defaults.string(forKey: AppStorageKeys.localPeer) == "newer-peer")
    #expect(context.surface.directPeerCommandFields.localPeer != "draft-peer")
    #expect(draft.localPeer == "newer-peer")

    draft.localPeer = "accepted-peer"
    #expect(draft.commit(
        to: settings,
        operatorSurface: &context.surface,
        executionController: controller,
        previewState: previewState
    ) == .saved)
    #expect(settings.localPeer == "accepted-peer")
    #expect(context.surface.directPeerCommandFields.localPeer == "accepted-peer")
}

@MainActor
@Test
func appValidationPreflightIncludesCurrentReportReadiness() {
    let report = NativeAppShellSyntheticSmoke.run()
    let surfaceProbe = NativeAppShellSurfaceProbe.run(sourceReport: report)
    let plan = AppOperatorPrototypePlan.make(operatorSurface: appWorkflowSurface())
    let controller = AppExecutionController()
    controller.settings.supervisorReportPath = "/tmp/open-lola-missing-current-report.json"

    let preflight = AppValidationPreflightModel.make(
        plan: plan,
        executionController: controller,
        surfaceProbe: surfaceProbe
    )

    #expect(preflight.verdict == .blocked)
    #expect(preflight.blockers.contains { blocker in
        blocker.id == "report-readiness"
            && blocker.remediation.contains("missing report artifact")
            && blocker.targetSection == .validation
    })
}

@MainActor
@Test
func appPreviewAudioMetersCanUseActiveLocalPreviewEvidence() {
    #expect(AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .idle,
        audioPreviewEnabled: true,
        audioPreviewPhase: .active
    ))
    #expect(!AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .idle,
        audioPreviewEnabled: false,
        audioPreviewPhase: .active
    ))
    #expect(!AppChannelMeterVisibilityPolicy.showsMeters(
        phase: .supervisorRunning,
        audioPreviewEnabled: true,
        audioPreviewPhase: .failed
    ))

    let failedContent = AppChannelMeterEmptyStatePolicy.content(
        audioPreviewEnabled: true,
        audioPreviewPhase: .failed,
        status: "Microphone permission denied or restricted."
    )
    #expect(failedContent.title == "Local audio meter unavailable")
    #expect(failedContent.detail.contains("Microphone permission denied"))
    #expect(failedContent.accessibilityLabel.contains("Local audio meter unavailable"))

    let idleContent = AppChannelMeterEmptyStatePolicy.content(
        audioPreviewEnabled: true,
        audioPreviewPhase: .idle,
        status: "Audio meter idle."
    )
    #expect(idleContent.detail.contains("local metering evidence"))
    #expect(idleContent.detail.contains("remote packet evidence"))
}

@Test
func appChannelMeterAccessibilityDeclaresOverviewScope() {
    #expect(AppChannelMeterAccessibilityPolicy.scopeHint.contains("Compact overview only"))
    #expect(AppChannelMeterAccessibilityPolicy.scopeHint.contains("does not expose per-channel"))
    #expect(
        AppChannelMeterAccessibilityPolicy.value(channelCount: 0, peak: nil) == "Overview only. No channels visible"
    )
    #expect(
        AppChannelMeterAccessibilityPolicy.value(channelCount: 8, peak: 0.724)
            == "Overview only. 8 channels, peak 72 percent"
    )
    #expect(
        AppChannelMeterAccessibilityPolicy.value(channelCount: 64, peak: 1.7)
            == "Overview only. 64 channels, peak 100 percent"
    )
}
