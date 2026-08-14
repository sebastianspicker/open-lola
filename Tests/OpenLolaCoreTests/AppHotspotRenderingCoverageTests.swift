// Exercises app-shell hotspots through local synthetic AppKit rendering without hardware or network services.
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
struct AppHotspotRenderingCoverageTests {
    private static let rootRenderSize = CGSize(width: 1_200, height: 820)
    private static let detailRenderSize = CGSize(width: 1_000, height: 760)
    private static let extendedRenderSize = CGSize(width: 1_200, height: 1_100)

    @Test
    func appShellWorkspacesRenderSyntheticOperatorStructure() throws {
        let suiteName = "open-lola-hotspot-rendering-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let dependencies = makeDependencies(defaults: defaults)
        for section in [
            NativeAppShellSurfaceSectionID.session,
            .devices,
            .routing,
            .streams,
            .packetMonitor,
            .validation,
            .diagnostics
        ] {
            let root = AppShellRootView(
                report: NativeAppShellSyntheticSmoke.run(),
                operatorSurface: .constant(appOperatorState(remoteSelectionComplete: true)),
                dependencies: dependencies,
                initialSelectedSection: section
            )
            let render = try render(root, size: Self.rootRenderSize)

            assertMeaningfulStructure(render, named: section.rawValue)
        }
    }

    @Test
    func appSettingsArtifactAndMeterBodiesRenderOperatorAccessibilityPolicies() throws {
        let suiteName = "open-lola-hotspot-detail-rendering-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var surface = appOperatorState(remoteSelectionComplete: true)
        let settings = AppSettings(defaults: defaults)
        let settingsView = AppShellSettingsView(
            configuration: NativeAppConfigurationSnapshot(
                profile: .init(name: "rendering", audioDeviceSelection: "synthetic-input", outputDeviceUID: nil),
                audio: .init(sampleRateHertz: 48_000, framesPerBuffer: 128, requestedPlayoutTargetFrames: 128),
                features: .init(
                    videoEnabled: true,
                    showControlEnabled: false,
                    lightingEnabled: false,
                    createdByUI: true,
                    immutableHandoff: true
                )
            ),
            operatorSurface: Binding(get: { surface }, set: { surface = $0 }),
            executionController: AppExecutionController(),
            previewState: AppPreviewReceiverState(),
            appSettings: settings
        )
        let artifactView = AppOperatorArtifactsView(
            operatorSurface: Binding(get: { surface }, set: { surface = $0 }),
            appSettings: settings,
            inputsLocked: true
        )
        let detail = VStack(alignment: .leading, spacing: 16) {
            settingsView
                .frame(height: 340)
            AppChannelMeterView(levels: [0.05, 0.3, 0.72, 1.0], visibleChannels: 4)
                .frame(height: 150)
            artifactView
        }
        .padding()

        let render = try render(detail, size: Self.detailRenderSize)
        assertMeaningfulStructure(render, named: "settings-artifacts-meter")

        #expect(
            AppChannelMeterAccessibilityPolicy.value(channelCount: 4, peak: 1.0)
                == "Overview only. 4 channels, peak 100 percent"
        )
        #expect(AppChannelMeterAccessibilityPolicy.scopeHint.contains("does not expose per-channel"))
        #expect(
            AppReadableMetricAccessibility.valueLabel(metric: "Supervisor report", value: "/tmp/synthetic.json")
                == "Supervisor report: /tmp/synthetic.json"
        )
        #expect(
            AppReadableMetricAccessibility.valueHint(metric: "Supervisor report")
                == "Full Supervisor report value is selectable and can be copied."
        )
        #expect(
            AppRemoteInventoryImportStatus.summary(for: surface.remoteInventory)
                .contains("Imported remote inventory JSON; host remote-mac")
        )
        #expect(AppExecutionSettingsShortcutCopy.validationShortcutLabel() == "Shortcut: ⌘⇧V")
    }


    @Test
    func appArtifactPanelsRenderGeneratedAndMissingArtifactStates() throws {
        let suiteName = "open-lola-hotspot-artifacts-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var populatedSurface = appOperatorState(remoteSelectionComplete: true)
        let populatedSettings = AppSettings(defaults: defaults)
        populatedSettings.operatorPlanArtifactPath = "/tmp/open-lola-hotspot-\(UUID().uuidString).json"
        let populatedView = AppOperatorArtifactsView(
            operatorSurface: Binding(get: { populatedSurface }, set: { populatedSurface = $0 }),
            appSettings: populatedSettings,
            inputsLocked: false
        )
        let populatedRender = try render(populatedView.padding(), size: Self.extendedRenderSize)
        assertMeaningfulStructure(populatedRender, named: "generated-plan-artifact")
        let artifact = try populatedSurface.twoPeerRunPlanArtifactState(
            outputPath: populatedSettings.operatorPlanArtifactPath
        )
        var populatedPanel = AppOperatorArtifactPanelState()
        populatedPanel.recordGeneratedArtifact(artifact, status: "Generated synthetic plan artifact.")
        #expect(populatedPanel.generatedArtifact?.path == populatedSettings.operatorPlanArtifactPath)

        var missingSurface = appOperatorState(remoteSelectionComplete: true)
        let missingSettings = AppSettings(defaults: defaults)
        missingSettings.operatorPlanArtifactPath = "/tmp/open-lola-missing-\(UUID().uuidString).json"
        let missingView = AppOperatorArtifactsView(
            operatorSurface: Binding(get: { missingSurface }, set: { missingSurface = $0 }),
            appSettings: missingSettings,
            inputsLocked: false
        )
        let missingRender = try render(missingView.padding(), size: Self.extendedRenderSize)
        assertMeaningfulStructure(missingRender, named: "missing-plan-artifact")
        #expect(!FileManager.default.fileExists(atPath: missingSettings.operatorPlanArtifactPath))
        populatedPanel.setFailureStatus("Synthetic missing plan artifact", NativeAppShellArtifactError.emptyClipboardText)
        #expect(populatedPanel.generatedArtifact == nil)
        #expect(populatedPanel.fileError?.contains("Synthetic missing plan artifact") == true)
    }

    @Test
    func appSceneMenuActionsAndLifecycleGuardsStayLocal() async throws {
        let scene = OpenLolaAppScene()
        let releaseActions = NativeAppShellSurfaceContract.releaseReadiness.actions
        for action in releaseActions {
            assertRenderFrame(
                try render(scene.appMenuActionButton(action).padding(), size: Self.detailRenderSize),
                named: "menu-action-\(action.id)"
            )
        }
        let unsupportedAction = NativeAppShellSurfaceAction(
            identity: .init(id: "synthetic-unsupported", title: "Unsupported", keyboardShortcut: nil),
            effects: .init(
                refreshesReportOnly: false,
                startsRealtimeAudio: false,
                startsRealtimeVideo: false,
                armsControlOutput: false
            )
        )
        assertRenderFrame(
            try render(
                VStack { scene.appMenuActionButton(unsupportedAction); Text("Unsupported action") }
                    .padding(),
                size: Self.detailRenderSize
            ),
            named: "unsupported-menu-action"
        )

        #expect(!scene.operatorPlanIsConfigured)
        scene.operatorSurface = appOperatorState(remoteSelectionComplete: true)
        scene.handleScenePhaseChange(.background)
        scene.installQuitGuard()
        scene.confirmQuitWhileRunning()
        scene.requestMenuStop()
        scene.confirmMenuStop()

        scene.syntheticMetricsRefreshState = .refreshing
        await scene.refreshSyntheticMetricsAsync()
        scene.syntheticMetricsRefreshState = .idle
        await scene.refreshSyntheticMetricsAsync()
        #expect(AppSyntheticMetricsRefreshState.refreshing.isRefreshing)
        #expect(AppSyntheticMetricsRefreshState.refreshed.badgeTitle == "Source/synthetic refreshed")
    }

    @Test
    func appReceiverPreviewStateRendersDisabledNilAndStopBranches() throws {
        var surface = appOperatorState(remoteSelectionComplete: true)
        let disabledState = AppPreviewReceiverState(
            audioPreviewEnabled: false,
            videoPreviewEnabled: false,
            showSafeFrame: false
        )
        disabledState.startReceiverPreview(audioInputUID: nil, videoDeviceID: nil)
        #expect(disabledState.previewPhase == .disabled)
        #expect(disabledState.verifiedReceiverStatus == "Local device preview disabled.")
        disabledState.requestPreviewWindow()
        disabledState.markPreviewWindowVisible()
        #expect(disabledState.previewWindowPhase == .visible)
        disabledState.markPreviewWindowHidden()
        #expect(disabledState.previewWindowPhase == .hidden)
        assertHostedStructure(
            try render(
                AppPreviewReceiverView(
                    operatorSurface: Binding(get: { surface }, set: { surface = $0 }),
                    previewState: disabledState
                )
                .padding(),
                size: Self.detailRenderSize
            ),
            named: "disabled-receiver-preview"
        )

        let missingDeviceState = AppPreviewReceiverState()
        missingDeviceState.startReceiverPreview(audioInputUID: nil, videoDeviceID: nil)
        #expect(missingDeviceState.previewPhase == .failed)
        #expect(missingDeviceState.verifiedReceiverStatus.contains("No video device selected"))
        missingDeviceState.stopReceiverPreview()
        missingDeviceState.stopReceiverPreview()
        #expect(missingDeviceState.previewPhase == .idle)
        #expect(missingDeviceState.receiverStatus == "Local device preview stopped.")
        #expect(missingDeviceState.videoPreviewController.phase == .idle)
        #expect(missingDeviceState.audioLevelMeter.phase == .idle)
        assertHostedStructure(
            try render(
                AppPreviewReceiverView(
                    operatorSurface: Binding(get: { surface }, set: { surface = $0 }),
                    previewState: missingDeviceState
                )
                .padding(),
                size: Self.detailRenderSize
            ),
            named: "stopped-receiver-preview"
        )
    }

    @Test
    func appReceiverPreviewServicesExerciseDeviceFreeLifecycleAndLayerAttachment() throws {
        let videoController = AppVideoPreviewController()
        var videoStatusChanges = 0
        videoController.onStatusChange = { videoStatusChanges += 1 }

        videoController.start(deviceID: nil, enabled: false)
        #expect(videoController.phase == .disabled)
        videoController.start(deviceID: nil, enabled: true)
        #expect(videoController.phase == .failed)
        #expect(videoController.status == AppPreviewSetupRecoveryCopy.noVideoDeviceSelected)

        let previewView = AppVideoPreviewNSView(frame: .zero)
        videoController.attach(previewView.previewLayer)
        #expect(videoController.previewLayer === previewView.previewLayer)
        #expect(previewView.previewLayer.videoGravity == .resizeAspect)
        assertHostedStructure(
            try render(
                AppVideoPreviewLayerView(controller: videoController)
                    .frame(width: 320, height: 180),
                size: CGSize(width: 360, height: 220)
            ),
            named: "device-free-video-preview-layer"
        )
        videoController.stop()
        #expect(videoController.phase == .idle)
        #expect(videoStatusChanges > 0)

        let audioMeter = AppAudioLevelMeter()
        var audioStatusChanges = 0
        audioMeter.onStatusChange = { audioStatusChanges += 1 }
        audioMeter.start(inputUID: nil, enabled: false, gain: 0.5)
        #expect(audioMeter.phase == .disabled)
        audioMeter.start(inputUID: nil, enabled: true, gain: 0.5)
        #expect(audioMeter.phase == .failed)
        #expect(audioMeter.status == AppPreviewSetupRecoveryCopy.noAudioInputSelected)
        audioMeter.setGain(0.25)
        #expect(audioMeter.levels.allSatisfy { $0 == 0 })
        audioMeter.stop()
        #expect(audioMeter.phase == .idle)
        #expect(audioStatusChanges > 0)
    }

    @Test
    func appPlanAndExecutionBodiesRenderConfiguredAndBlockedBranches() throws {
        var configuredSurface = appOperatorState(remoteSelectionComplete: true)
        let configuredPlan = AppOperatorPrototypePlan.make(operatorSurface: configuredSurface)
        let executionController = AppExecutionController()
        executionController.status = "Synthetic dry-run completed."
        executionController.phase = .runFinished
        executionController.lastRunWasDryRun = true
        executionController.lastExitCode = 15
        executionController.lastError = "Error Domain=NSCocoaErrorDomain Code=4 synthetic missing artifact"

        let configuredDetail = VStack(alignment: .leading, spacing: 16) {
            AppOperatorReadinessView(plan: configuredPlan, executionController: executionController)
            AppOperatorCommandsView(plan: configuredPlan)
            AppExecutionView(
                operatorSurface: Binding(get: { configuredSurface }, set: { configuredSurface = $0 }),
                executionController: executionController,
                plan: configuredPlan,
                inputsLocked: true
            )
        }
        .padding()
        let configuredRender = try render(configuredDetail, size: Self.extendedRenderSize)
        assertMeaningfulStructure(configuredRender, named: "configured-plan-and-dry-run")

        let incompletePlan = AppOperatorPrototypePlan.make(
            operatorSurface: appOperatorState(remoteSelectionComplete: false)
        )
        let blockedRender = try render(
            AppOperatorReadinessView(plan: incompletePlan, executionController: AppExecutionController()).padding(),
            size: Self.detailRenderSize
        )
        assertMeaningfulStructure(blockedRender, named: "blocked-plan-readiness")
        #expect(incompletePlan.validationError != nil)
        #expect(AppProcessExitDisplay.title(15) == "Stopped by operator")
        #expect(executionController.lastError?.contains("synthetic missing artifact") == true)
    }

    @Test
    func appPacketMonitorPreviewAndSupportBodiesRenderLocalStates() throws {
        let plan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: true))
        let executionController = AppExecutionController()
        let emptyState = AppPacketMonitorEmptyState.make(plan: plan, executionSettings: executionController.settings)
        var requestedSection: NativeAppShellSurfaceSectionID?
        let emptyMonitor = AppPacketMonitorView(
            captureReport: nil,
            emptyState: emptyState,
            navigateToSection: { requestedSection = $0 }
        )
        let populatedMonitor = AppPacketMonitorView(
            captureReport: lolaCompatibilityCaptureReportForAppShell(),
            emptyState: emptyState,
            navigateToSection: { requestedSection = $0 }
        )

        assertMeaningfulStructure(
            try render(emptyMonitor.padding(), size: Self.detailRenderSize),
            named: "empty-packet-monitor"
        )
        assertMeaningfulStructure(
            try render(populatedMonitor.padding(), size: Self.detailRenderSize),
            named: "populated-packet-monitor"
        )

        let videoController = AppVideoPreviewController()
        videoController.start(deviceID: nil, enabled: true)
        let audioMeter = AppAudioLevelMeter()
        audioMeter.start(inputUID: nil, enabled: true, gain: 0.5)
        let localServiceDetail = VStack(alignment: .leading, spacing: 12) {
            AppVideoPreviewLayerView(controller: videoController)
                .frame(height: 120)
            Text(videoController.status)
            Text(audioMeter.status)
            AppWarningBanner(
                title: "Synthetic warning",
                messages: ["No local preview device was selected."],
                detail: "Local rendering only.",
                dismissAction: {}
            )
            AppStatusBadge(
                title: "Synthetic status",
                systemImage: "checkmark.circle.fill",
                tone: .green
            )
            AppReadableValue(label: "Expected report", value: emptyState.expectedReportPath)
        }
        .padding()
        assertMeaningfulStructure(
            try render(localServiceDetail, size: Self.detailRenderSize),
            named: "preview-service-and-support"
        )
        #expect(videoController.phase == .failed)
        #expect(videoController.status == AppPreviewSetupRecoveryCopy.noVideoDeviceSelected)
        #expect(audioMeter.phase == .failed)
        #expect(audioMeter.status == AppPreviewSetupRecoveryCopy.noAudioInputSelected)
        videoController.start(deviceID: nil, enabled: false)
        #expect(videoController.phase == .disabled)
        videoController.stop()
        #expect(videoController.phase == .idle)
        #expect(videoController.status == "Video preview idle.")
        audioMeter.start(inputUID: nil, enabled: false, gain: 0.5)
        #expect(audioMeter.phase == .disabled)
        audioMeter.setGain(0.25)
        audioMeter.stop()
        #expect(audioMeter.phase == .idle)
        #expect(audioMeter.status == "Audio meter idle.")
        #expect(audioMeter.levels == Array(repeating: 0.0, count: 8))
        #expect(requestedSection == nil)
        #expect(emptyState.targetSection == .session)
        #expect(AppReadableMetricAccessibility.valueLabel(metric: "Expected report", value: emptyState.expectedReportPath).contains("Expected report"))
    }

    @Test
    func appStoredDefaultsInventoryMergeAndExecutionGuardsStayLocal() {
        let placeholder = AppShellStoredDefaults.placeholderOperatorSurface(commandIntent: .runRequested)
        #expect(placeholder.commandIntent == .runRequested)
        #expect(placeholder.inventory.capturedAt == "launch-inventory-pending")
        #expect(placeholder.inventory.selection.audioInputUID == nil)
        #expect(placeholder.inventory.inventoryErrors == ["Local media inventory refresh pending."])

        var staleSelection = appOperatorState(remoteSelectionComplete: true)
        staleSelection.inventory.selection = NativeAppShellLocalMediaSelection(
            audioInputUID: "missing-input",
            audioOutputUID: "missing-output",
            videoDeviceID: "missing-video"
        )
        let refreshed = appOperatorState(remoteSelectionComplete: true)
        let merged = AppLocalOperatorInventoryRefreshMergePolicy.merge(
            current: staleSelection,
            refreshResult: refreshed
        )
        #expect(merged.inventory.selection == refreshed.inventory.selection)
        let inventoryController = AppLocalOperatorInventoryController()
        #expect(!inventoryController.isRefreshingInventory)
        #expect(inventoryController.lastRefreshWarning == nil)

        let executionController = AppExecutionController()
        #expect(!executionController.startArmed(executablePath: "/bin/echo"))
        #expect(executionController.phase == .failedToStart)
        #expect(executionController.lastError == "Execution is not armed.")
        #expect(
            executionController.validationReadiness(.directMacPeer, reportPath: " \n")
                == .missingReport("unset")
        )
    }

    private func makeDependencies(defaults: UserDefaults) -> AppShellRootDependencies {
        let controller = AppExecutionController()
        controller.status = "Synthetic local rendering state. Not live runtime evidence."
        let previewState = AppPreviewReceiverState(
            audioPreviewEnabled: true,
            videoPreviewEnabled: true,
            showSafeFrame: true,
            monitorGain: 0.65,
            videoScale: 1
        )
        previewState.previewPhase = .active
        previewState.receiverStatus = "Synthetic local preview state."
        return AppShellRootDependencies(
            executionController: controller,
            previewState: previewState,
            inventoryController: AppLocalOperatorInventoryController(),
            appSettings: AppSettings(defaults: defaults),
            contract: .releaseReadiness,
            syntheticMetricsRefreshState: .idle,
            refreshReport: {},
            refreshInventory: {}
        )
    }

    private func assertMeaningfulStructure(_ render: AppHotspotRender, named name: String) {
        #expect(render.frame.width > 0, "\(name) must have a nonzero rendered width.")
        #expect(render.frame.height > 0, "\(name) must have a nonzero rendered height.")
        #expect(render.hostedSubviewCount > 0, "\(name) must build an AppKit hosting hierarchy.")
        #expect(render.sampledColorCount > 16, "\(name) must render visual structure, not a blank canvas.")
        #expect(render.visibleSampleCount > 100, "\(name) must render visible operator content.")
    }

    private func assertRenderFrame(_ render: AppHotspotRender, named name: String) {
        #expect(render.frame.width > 0, "\(name) must have a nonzero rendered width.")
        #expect(render.frame.height > 0, "\(name) must have a nonzero rendered height.")
    }
}
