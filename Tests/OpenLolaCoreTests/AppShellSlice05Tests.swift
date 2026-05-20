import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func appMenuActionHandlingCoversEveryContractAction() {
    let contractActionIDs = Set(NativeAppShellSurfaceContract.releaseReadiness.actions.map(\.id))

    #expect(contractActionIDs == AppMenuActionHandling.handledActionIDs)
    #expect(AppMenuActionHandling.isHandled("validate-supervisor-report"))
    #expect(!AppMenuActionHandling.isHandled("future-unmapped-action"))
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

@Test
func appPacketMonitorSelectionAllowsTruthfulEmptyEvidenceState() {
    let sections = NativeAppShellSurfaceContract.releaseReadiness.sections
    let packetOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "packet")

    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: false
    ) == .packetMonitor)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: false
    ) == .packetMonitor)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .ready,
        captureReportAvailable: false
    ) == .packetMonitor)
    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .unconfigured,
        captureReportAvailable: false
    ) == nil)
    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: true
    ) == .packetMonitor)
}

@MainActor
@Test
func appSlice05UiPoliciesExposeTruthfulOperatorStates() {
    #expect(!AppPreviewControlAvailability.returnBlendEnabledInLocalPreview)
    #expect(!AppPreviewControlAvailability.visibleStreamsEnabledInLocalPreview)
    #expect(!AppPreviewControlAvailability.selectedStreamEnabledInLocalPreview)
    #expect(AppPreviewControlAvailability.unsupportedLocalPreviewHelp.contains("single-stream"))
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
}

@Test
func appWorkflowModesAndControlVisibilityAreExplicit() {
    #expect(NativeAppShellSessionMode.allCases.map(\.displayName) == ["Mac-to-Mac", "LoLa", "JackTrip", "UltraGrid"])
    #expect(NativeAppShellSessionMode.directMacPeer.supportsAppExecution)
    #expect(NativeAppShellSessionMode.windowsLoLa.externalConnectorKind == .lola)
    #expect(NativeAppShellSessionMode.jackTrip.externalConnectorKind == .jackTrip)
    #expect(NativeAppShellSessionMode.ultraGrid.externalConnectorKind == .mvtpUltraGrid)
    #expect(!NativeAppShellSessionMode.jackTrip.supportsAppExecution)
    #expect(!NativeAppShellSessionMode.ultraGrid.supportsAppExecution)
    #expect(AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: .directMacPeer))
    #expect(AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: .windowsLoLa))
    #expect(!AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: .jackTrip))
    #expect(!AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: .ultraGrid))
    #expect(NativeAppShellSessionMode.jackTrip.appStatusLabel == "External connector CLI only")
    #expect(NativeAppShellSessionMode.ultraGrid.appStatusLabel == "External connector CLI only")
    #expect(NativeAppShellSessionMode.jackTrip.unavailableAppReason?.contains("operator planning") == true)
    #expect(NativeAppShellSessionMode.ultraGrid.unavailableAppReason?.contains("operator planning") == true)
    #expect(NativeAppShellSessionMode.jackTrip.unavailableAppReason?.contains("external connector or NMP CLI contracts") == true)
    #expect(NativeAppShellSessionMode.ultraGrid.unavailableAppReason?.contains("external connector or NMP CLI contracts") == true)

    let normalDirect = Set(NativeAppShellSettingsVisibility.visibleGroups(
        sessionMode: .directMacPeer,
        controlMode: .normal
    ))
    #expect(normalDirect.contains(.workflow))
    #expect(normalDirect.contains(.connection))
    #expect(normalDirect.contains(.preview))
    #expect(normalDirect.contains(.snapshot))
    #expect(!normalDirect.contains(.ports))
    #expect(!normalDirect.contains(.audioCodec))
    #expect(!normalDirect.contains(.videoCodec))
    #expect(!normalDirect.contains(.sshFallback))

    let advancedDirect = Set(NativeAppShellSettingsVisibility.visibleGroups(
        sessionMode: .directMacPeer,
        controlMode: .advanced
    ))
    #expect(advancedDirect.contains(.ports))
    #expect(advancedDirect.contains(.audioCodec))
    #expect(advancedDirect.contains(.videoCodec))
    #expect(advancedDirect.contains(.sshFallback))

    let externalOnly = Set(NativeAppShellSettingsVisibility.visibleGroups(
        sessionMode: .jackTrip,
        controlMode: .advanced
    ))
    #expect(externalOnly.contains(.externalConnectorNotice))
    #expect(!externalOnly.contains(.execution))
    #expect(!externalOnly.contains(.ports))

    for mode in [NativeAppShellSessionMode.jackTrip, .ultraGrid] {
        #expect(
            NativeAppShellSettingsVisibility.visibleGroups(
                sessionMode: mode,
                controlMode: .normal
            ) == [.workflow, .externalConnectorNotice]
        )
        #expect(
            NativeAppShellSettingsVisibility.visibleGroups(
                sessionMode: mode,
                controlMode: .advanced
            ) == [.workflow, .externalConnectorNotice]
        )
    }
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

@Test
func appExecutionErrorGuidanceClassifiesCommonFailureTypes() {
    #expect(AppExecutionErrorGuidance.detail(
        for: "Cannot validate missing report artifact: /tmp/supervisor.json"
    ).contains("report path"))
    #expect(AppExecutionErrorGuidance.detail(
        for: "No such file or executable"
    ).contains("executable path"))
    #expect(AppExecutionErrorGuidance.detail(
        for: "plan validation failed"
    ).contains("plan fields"))
    #expect(AppExecutionErrorGuidance.detail(
        for: "process exited 42"
    ).contains("log paths"))
}

@Test
func appReadableMetricAccessibilityIncludesMetricContext() {
    #expect(AppReadableMetricAccessibility.valueLabel(metric: "Plan", value: "/tmp/plan.json") == "Plan: /tmp/plan.json")
    #expect(AppReadableMetricAccessibility.copyLabel(metric: "Audio input UID") == "Copy Audio input UID value")
}

@MainActor
@Test
func appPasteboardCopyReportsWriteResultBeforeSuccessStatus() {
    let originalWriter = AppPasteboard.writeString
    defer {
        AppPasteboard.writeString = originalWriter
    }
    var copiedValues: [String] = []
    AppPasteboard.writeString = { value in
        copiedValues.append(value)
        return true
    }

    #expect(AppPasteboard.copyString("open-lola --dry-run"))
    #expect(copiedValues == ["open-lola --dry-run"])

    AppPasteboard.writeString = { _ in false }
    #expect(!AppPasteboard.copyString("open-lola --dry-run"))

    let copiedStatuses = [
        (
            success: "Copied local inventory JSON.",
            failure: "Copy failed for local inventory JSON."
        ),
        (
            success: "Generated copyable plan JSON.",
            failure: "Generated plan JSON, but pasteboard copy failed."
        ),
        (
            success: "Wrote plan artifact to /tmp/plan.json.",
            failure: "Wrote plan artifact, but pasteboard copy failed."
        ),
        (
            success: "Reloaded plan artifact from /tmp/plan.json.",
            failure: "Reloaded plan artifact, but pasteboard copy failed."
        ),
        (
            success: "Copied SSH supervisor command.",
            failure: "Copy failed for SSH supervisor command."
        ),
    ]

    for status in copiedStatuses {
        #expect(AppPasteboardCopyStatus.message(
            copied: true,
            success: status.success,
            failure: status.failure
        ) == status.success)
        let failedMessage = AppPasteboardCopyStatus.message(
            copied: false,
            success: status.success,
            failure: status.failure
        )
        #expect(failedMessage == status.failure)
        #expect(!failedMessage.hasPrefix("Copied"))
        #expect(!failedMessage.hasPrefix("Generated copyable"))
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
