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
    #expect(AppExecutionSettingsShortcutCopy.validationShortcutLabel() == nil)

    let validationActionWithShortcut = NativeAppShellSurfaceAction(
        id: "validate-supervisor-report",
        title: "Validate Supervisor Report",
        keyboardShortcut: "command-shift-v",
        refreshesReportOnly: false,
        startsRealtimeAudio: false,
        startsRealtimeVideo: false,
        armsControlOutput: false,
        launchesExternalProcess: true
    )

    #expect(AppExecutionSettingsShortcutCopy.validationShortcutLabel(
        actions: [validationActionWithShortcut]
    ) == "Shortcut: ⌘⇧V")
}

@MainActor
@Test
func appConsoleSearchCopyMatchesSectionFilterBehavior() {
    let sections = NativeAppShellSurfaceContract.releaseReadiness.sections
    let settingsOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "settings")
    let noMatches = NativeAppShellSectionSearch.visibleSections(sections, query: "not-a-section")
    let snapshot = AppConsoleStatusSnapshot.make(
        report: NativeAppShellSyntheticSmoke.run(),
        plan: AppOperatorPrototypePlan.make(operatorSurface: AppShellStoredDefaults.placeholderOperatorSurface()),
        executionController: AppExecutionController(),
        captureReport: nil
    )

    #expect(snapshot.searchPlaceholder == AppConsoleSearchCopy.placeholder)
    #expect(AppConsoleSearchCopy.placeholder == "Filter sections")
    #expect(AppConsoleSearchCopy.accessibilityHint.contains("sidebar section list"))
    #expect(AppConsoleSearchCopy.accessibilityHint.contains("does not search inside"))
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
    #expect(!AppPreviewControlAvailability.returnBlendEnabledInLocalPreview)
    #expect(!AppPreviewControlAvailability.visibleStreamsEnabledInLocalPreview)
    #expect(!AppPreviewControlAvailability.selectedStreamEnabledInLocalPreview)
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
        ) == [.execution, .externalConnectorNotice])
        #expect(AppShellSettingsTabVisibility.visibleTabs(
            sessionMode: mode,
            controlMode: .advanced
        ) == [.execution, .externalConnectorNotice])
    }

    #expect(!AppShellSettingsTabID.allCases.map(\.title).contains("Unavailable"))
}

@Test
func appSidebarSettingsSectionStaysReadOnlyAndSeparateFromNativeSettingsEditor() {
    let settingsSection = NativeAppShellSurfaceContract.releaseReadiness.sections.first { $0.id == .settings }

    #expect(settingsSection?.readOnly == true)
    #expect(AppShellSettingsSurfacePolicy.sidebarUsesReadOnlySummary)
    #expect(AppShellSettingsSurfacePolicy.nativeSettingsSceneUsesMutableEditor)
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
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set("original-peer", forKey: AppStorageKeys.localPeer)
    let settings = AppSettings(defaults: defaults)
    let draft = AppSettingsDraft(settings: settings)
    var surface = AppShellStoredDefaults.placeholderOperatorSurface()
    let controller = AppExecutionController()
    let previewState = AppPreviewReceiverState()

    draft.localPeer = "draft-peer"
    settings.localPeer = "newer-peer"

    #expect(draft.hasSourceConflict(comparedTo: settings))
    let staleResult = draft.commit(
        to: settings,
        operatorSurface: &surface,
        executionController: controller,
        previewState: previewState
    )

    #expect(staleResult == .conflict(AppSettingsDraftCommitResult.conflictMessage))
    #expect(settings.localPeer == "newer-peer")
    #expect(defaults.string(forKey: AppStorageKeys.localPeer) == "newer-peer")
    #expect(surface.directPeerCommandFields.localPeer != "draft-peer")
    #expect(draft.localPeer == "newer-peer")

    draft.localPeer = "accepted-peer"
    #expect(draft.commit(
        to: settings,
        operatorSurface: &surface,
        executionController: controller,
        previewState: previewState
    ) == .saved)
    #expect(settings.localPeer == "accepted-peer")
    #expect(surface.directPeerCommandFields.localPeer == "accepted-peer")
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
    #expect(AppChannelMeterAccessibilityPolicy.value(channelCount: 0, peak: nil) == "Overview only. No channels visible")
    #expect(AppChannelMeterAccessibilityPolicy.value(channelCount: 8, peak: 0.724) == "Overview only. 8 channels, peak 72 percent")
    #expect(AppChannelMeterAccessibilityPolicy.value(channelCount: 64, peak: 1.7) == "Overview only. 64 channels, peak 100 percent")
}

@MainActor
@Test
func appDiagnosticsLabelsPlaceholderAndSourceLevelFactsExplicitly() {
    let controller = AppExecutionController()
    let placeholder = AppDiagnosticsStatusModel.make(
        report: NativeAppShellReport.placeholder(),
        executionController: controller
    )

    #expect(placeholder.permissionsTitle == "Planned ready")
    #expect(placeholder.realtimeSafetyTitle == "Source boundary safe")
    #expect(placeholder.evidenceTitle == "Placeholder source")
}

@Test
func appRemoteEvidenceStatusSeparatesPlanPreviewFromPacketEvidence() {
    let noCapture = AppRemoteEvidenceStatusPolicy.make(
        plan: AppOperatorPrototypePlan.make(operatorSurface: appWorkflowSurface()),
        captureReport: nil
    )
    #expect(noCapture.runtimeState == "Remote plan only; no received-media proof")
    #expect(noCapture.evidence == "No remote packet or media evidence measured")
    #expect(noCapture.packetCount == "Not measured")

    let emptyCapture = LoLaCompatibilityCaptureReport(
        id: "empty-capture",
        title: "Empty capture",
        capturedAt: "2026-05-20T00:00:00Z",
        inputPath: "fixtures/empty.pcapng",
        inputFormat: .pcapng,
        summary: LoLaCompatibilityCaptureSummary(packets: []),
        packets: [],
        verdict: .partial,
        evidenceBoundary: "unit-test packet monitor",
        notes: "empty capture"
    )
    let withCapture = AppRemoteEvidenceStatusPolicy.make(
        plan: AppOperatorPrototypePlan.make(operatorSurface: appWorkflowSurface()),
        captureReport: emptyCapture
    )
    #expect(withCapture.evidence == "Packet capture report loaded")
    #expect(withCapture.packetCount == "0")
}

@Test
func appPreviewReceiverWarningPolicyOnlyWarnsDuringRuntimeEvidenceStates() {
    #expect(AppPreviewReceiverWarningPolicy.showsMainBannerWarning(
        phase: .degraded,
        audioPreviewEnabled: true,
        videoPreviewEnabled: false,
        sessionState: .live
    ))
    #expect(AppPreviewReceiverWarningPolicy.showsMainBannerWarning(
        phase: .failed,
        audioPreviewEnabled: false,
        videoPreviewEnabled: true,
        sessionState: .supervisorRunning
    ))
    #expect(!AppPreviewReceiverWarningPolicy.showsMainBannerWarning(
        phase: .failed,
        audioPreviewEnabled: false,
        videoPreviewEnabled: false,
        sessionState: .live
    ))
    #expect(!AppPreviewReceiverWarningPolicy.showsMainBannerWarning(
        phase: .failed,
        audioPreviewEnabled: true,
        videoPreviewEnabled: true,
        sessionState: .ready
    ))
    #expect(!AppPreviewReceiverWarningPolicy.showsMainBannerWarning(
        phase: .active,
        audioPreviewEnabled: true,
        videoPreviewEnabled: true,
        sessionState: .live
    ))
}

@Test
func appRuntimeInputLockBlocksMutatingInputsButKeepsStopAvailable() {
    #expect(AppRuntimeInputLock.mutatingInputsLocked(isRunning: true))
    #expect(!AppRuntimeInputLock.mutatingInputsLocked(isRunning: false))
    #expect(AppRuntimeInputLock.canStop(isRunning: true))
    #expect(!AppRuntimeInputLock.canStop(isRunning: false))
    #expect(AppRuntimeInputLock.lockedHelp.contains("locked"))
    #expect(AppRemoteInventoryEditPolicy.fieldsDisabled(inputsLocked: true))
    #expect(!AppRemoteInventoryEditPolicy.fieldsDisabled(inputsLocked: false))
    #expect(AppRemoteInventoryEditPolicy.help(inputsLocked: true) == AppRuntimeInputLock.lockedHelp)
}

@Test
func appInventoryRefreshMergePreservesConcurrentOperatorEdits() {
    var current = appWorkflowSurface()
    current.remoteInventory.hostName = "edited-remote-label"
    current.directPeerCommandFields.remoteHost = "198.51.100.44"
    current.inventory.selection = NativeAppShellLocalMediaSelection(
        audioInputUID: "current-input",
        audioOutputUID: "current-output",
        videoDeviceID: "current-video"
    )

    var refreshResult = appWorkflowSurface()
    refreshResult.remoteInventory.hostName = "stale-remote-label"
    refreshResult.directPeerCommandFields.remoteHost = "192.0.2.99"
    refreshResult.inventory = appWorkflowInventory(
        hostName: "refreshed-local",
        inputUID: "fallback-input",
        outputUID: "fallback-output",
        videoID: "fallback-video"
    )
    refreshResult.inventory.audioDevices.append(contentsOf: [
        NativeAppShellAudioDeviceOption(
            name: "Current Input",
            uid: "current-input",
            inputChannelCount: 2,
            outputChannelCount: 0,
            nominalSampleRateHertz: 48_000,
            currentBufferFrameSize: 120
        ),
        NativeAppShellAudioDeviceOption(
            name: "Current Output",
            uid: "current-output",
            inputChannelCount: 0,
            outputChannelCount: 2,
            nominalSampleRateHertz: 48_000,
            currentBufferFrameSize: 120
        ),
    ])
    refreshResult.inventory.videoDevices.append(NativeAppShellVideoDeviceOption(
        label: "Current Video",
        uniqueId: "current-video",
        manufacturer: "Test",
        transport: "virtual",
        sourcePolicy: .blackmagicFirstAvFoundationFallback,
        formatCount: 1
    ))

    let merged = AppLocalOperatorInventoryRefreshMergePolicy.merge(
        current: current,
        refreshResult: refreshResult
    )

    #expect(merged.inventory.hostName == "refreshed-local")
    #expect(merged.inventory.selection.audioInputUID == "current-input")
    #expect(merged.inventory.selection.audioOutputUID == "current-output")
    #expect(merged.inventory.selection.videoDeviceID == "current-video")
    #expect(merged.remoteInventory.hostName == "edited-remote-label")
    #expect(merged.directPeerCommandFields.remoteHost == "198.51.100.44")
    #expect(merged.commandIntent == current.commandIntent)
}

@MainActor
@Test
func appWorkflowModesDoNotLeakRunnablePlansAcrossModes() {
    var surface = appWorkflowSurface()
    surface.directPeerCommandFields.audioTransport = .openLolaOpusCeltLowDelay
    surface.directPeerCommandFields.videoCompression = .jpegXS

    let directPlan = AppOperatorPrototypePlan.make(operatorSurface: surface)
    #expect(directPlan.isConfigured)
    #expect(directPlan.audioTransport == .openLolaOpusCeltLowDelay)
    #expect(directPlan.videoCompression == .jpegXS)

    surface.sessionMode = .windowsLoLa
    surface.windowsLoLaPeerFields.payloadMode = .avFoundationJpegXS
    let lolaPlan = AppOperatorPrototypePlan.make(operatorSurface: surface)
    #expect(lolaPlan.isConfigured)
    #expect(lolaPlan.windowsLoLaCommand?.contains("lola") == true)
    #expect(lolaPlan.windowsLoLaCommand?.contains(LoLaVideoPayloadKind.avFoundationJpegXS.rawValue) == true)
    #expect(lolaPlan.validationError == nil)
    #expect(lolaPlan.report == nil)

    surface.windowsLoLaPeerFields.outputPath = ""
    let invalidWindowsPlan = AppOperatorPrototypePlan.make(operatorSurface: surface)
    #expect(!invalidWindowsPlan.isConfigured)
    #expect(invalidWindowsPlan.windowsLoLaCommand == nil)
    #expect(invalidWindowsPlan.validationError?.contains("invalidCommandField(\"outputPath\")") == true)

    surface.windowsLoLaPeerFields.outputPath = "/tmp/open-lola-app/windows-lola-session.json"
    surface.sessionMode = .directMacPeer
    surface.directPeerCommandFields.localHost = ""
    let invalidDirectPlan = AppOperatorPrototypePlan.make(operatorSurface: surface)
    #expect(!invalidDirectPlan.isConfigured)
    #expect(invalidDirectPlan.report == nil)
    #expect(invalidDirectPlan.validationError?.contains("invalidCommandField(\"localHost\")") == true)

    let controller = AppExecutionController()
    surface.directPeerCommandFields.localHost = "192.0.2.10"
    for mode in [NativeAppShellSessionMode.jackTrip, .ultraGrid] {
        surface.sessionMode = mode
        let plan = AppOperatorPrototypePlan.make(operatorSurface: surface)
        #expect(!plan.isConfigured)
        #expect(plan.validationError?.contains("operator planning") == true)
        #expect(plan.validationError?.contains("no wired runtime launcher") == true)
        #expect(controller.validationReadiness(operatorSurface: surface).isReady == false)
        #expect(
            controller.validationReadiness(operatorSurface: surface)
                .unavailableMessage?
                .contains("no wired runtime launcher") == true
        )

        #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")) {
            try controller.executionCommand(
                executablePath: ".build/debug/open-lola",
                operatorSurface: surface,
                dryRun: true
            ).get()
        }
        #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")) {
            try controller.validatorCommand(
                executablePath: ".build/debug/open-lola",
                operatorSurface: surface
            ).get()
        }
    }
}

private func appWorkflowSurface() -> NativeAppShellOperatorPrototypeState {
    var directFields = NativeAppShellDirectPeerCommandFields.appDefault
    directFields.localPeer = "mac-a"
    directFields.remotePeer = "mac-b"
    directFields.localHost = "192.0.2.10"
    directFields.remoteHost = "192.0.2.20"
    directFields.channelCount = 2
    directFields.sampleRateHertz = 48_000
    directFields.framesPerPacket = 120
    directFields.sampleFormat = "float32"
    directFields.videoWidth = 1_280
    directFields.videoHeight = 720
    directFields.videoPixelFormat = "bgra8"
    directFields.videoFrameRate = 30
    directFields.avProfile = .balanced
    directFields.rxBufferProfile = .small

    return NativeAppShellOperatorPrototypeState(
        inventory: appWorkflowInventory(
            hostName: "local-mac",
            inputUID: "local-input",
            outputUID: "local-output",
            videoID: "local-video"
        ),
        remoteInventory: appWorkflowInventory(
            hostName: "remote-mac",
            inputUID: "remote-input",
            outputUID: "remote-output",
            videoID: "remote-video"
        ),
        commandIntent: .runRequested,
        remoteOrchestrationEnabled: false,
        startsLongRunningProcess: false,
        directPeerCommandFields: directFields,
        windowsLoLaPeerFields: NativeAppShellWindowsLoLaPeerFields(
            executablePath: ".build/debug/open-lola",
            localHost: "0.0.0.0",
            windowsHost: "192.0.2.30",
            payloadMode: .avFoundationJpegXS
        )
    )
}

@MainActor
private func appShellSettingsView() -> AppShellSettingsView {
    var surface = AppShellStoredDefaults.placeholderOperatorSurface()
    return AppShellSettingsView(
        configuration: NativeAppConfigurationSnapshot(
            profileName: "test",
            audioDeviceSelection: "test-input",
            outputDeviceUID: nil,
            sampleRateHertz: 48_000,
            framesPerBuffer: 128,
            requestedPlayoutTargetFrames: 128,
            videoEnabled: true,
            showControlEnabled: false,
            lightingEnabled: false,
            createdByUI: true,
            immutableHandoff: true
        ),
        operatorSurface: Binding(
            get: { surface },
            set: { surface = $0 }
        ),
        executionController: AppExecutionController(),
        previewState: AppPreviewReceiverState(),
        appSettings: AppSettings()
    )
}

private func appWorkflowInventory(
    hostName: String,
    inputUID: String,
    outputUID: String,
    videoID: String
) -> NativeAppShellLocalMediaInventory {
    NativeAppShellLocalMediaInventory(
        capturedAt: "2026-05-16T00:00:00Z",
        hostName: hostName,
        audioDevices: [
            NativeAppShellAudioDeviceOption(
                name: "Input",
                uid: inputUID,
                inputChannelCount: 2,
                outputChannelCount: 0,
                nominalSampleRateHertz: 48_000,
                currentBufferFrameSize: 120
            ),
            NativeAppShellAudioDeviceOption(
                name: "Output",
                uid: outputUID,
                inputChannelCount: 0,
                outputChannelCount: 2,
                nominalSampleRateHertz: 48_000,
                currentBufferFrameSize: 120
            ),
        ],
        videoDevices: [
            NativeAppShellVideoDeviceOption(
                label: "Video",
                uniqueId: videoID,
                manufacturer: "Test",
                transport: "virtual",
                sourcePolicy: .blackmagicFirstAvFoundationFallback,
                formatCount: 1
            ),
        ],
        selection: NativeAppShellLocalMediaSelection(
            audioInputUID: inputUID,
            audioOutputUID: outputUID,
            videoDeviceID: videoID
        ),
        inventoryErrors: []
    )
}
