// Covers device-free app-shell presentation and state seams without starting runtime services.
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
struct AppHotspotStateWave11Tests {
    private static let renderSize = CGSize(width: 920, height: 640)

    @Test
    func wave11AppArtifactViewsRenderLockedAndEditableStates() throws {
        let suiteName = "open-lola-wave11-artifact-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var surface = appOperatorState(remoteSelectionComplete: true)
        let settings = AppSettings(defaults: defaults)
        settings.operatorPlanArtifactPath = "/private/tmp/open-lola-wave11-plan.json"

        for inputsLocked in [true, false] {
            let view = AppOperatorArtifactsView(
                operatorSurface: Binding(get: { surface }, set: { surface = $0 }),
                appSettings: settings,
                inputsLocked: inputsLocked
            )
            assertRendered(
                view.padding(),
                size: Self.renderSize,
                named: inputsLocked ? "locked-artifacts" : "editable-artifacts",
                requiresAttachedHost: true,
                boundsMessageStyle: .rendered
            )
        }
    }

    @Test
    func wave11AppArtifactPanelStatesRetainOnlyCurrentArtifact() {
        let artifact = NativeAppShellGeneratedArtifactState(
            kind: .twoPeerSupervisorCommand,
            generatedAt: "2026-08-05T10:00:00Z",
            path: nil,
            clipboardText: "ssh operator@example.test open-lola",
            validationSummary: "synthetic command"
        )
        var state = AppOperatorArtifactPanelState()

        state.recordGeneratedArtifact(artifact, status: "Generated command.")
        #expect(state.generatedArtifact == artifact)
        #expect(state.fileError == nil)

        state.clearGeneratedArtifact(status: "Inputs changed.")
        #expect(state.generatedArtifact == nil)
        #expect(state.status == "Inputs changed.")

        state.setFailureStatus("Synthetic artifact failure", NativeAppShellArtifactError.emptyClipboardText)
        #expect(state.generatedArtifact == nil)
        #expect(state.fileError?.contains("Synthetic artifact failure") == true)
    }

    @Test
    func wave11AppInventoryMergeKeepsStillCompatibleSelections() {
        var current = appOperatorState(remoteSelectionComplete: true)
        current.inventory.selection = NativeAppShellLocalMediaSelection(
            audioInputUID: "local-rme",
            audioOutputUID: "local-rme",
            videoDeviceID: "local-atem"
        )
        var refreshed = appOperatorState(remoteSelectionComplete: true)
        refreshed.inventory.selection = NativeAppShellLocalMediaSelection(
            audioInputUID: nil,
            audioOutputUID: nil,
            videoDeviceID: nil
        )

        let merged = AppLocalOperatorInventoryRefreshMergePolicy.merge(
            current: current,
            refreshResult: refreshed
        )

        #expect(merged.inventory.selection == current.inventory.selection)
        #expect(merged.remoteInventory == current.remoteInventory)
        #expect(merged.directPeerCommandFields == current.directPeerCommandFields)
    }

    @Test
    func wave11AppInventoryMergeUsesRefreshFallbackForUnavailableSelection() {
        var current = appOperatorState(remoteSelectionComplete: true)
        current.inventory.selection = NativeAppShellLocalMediaSelection(
            audioInputUID: "unavailable-input",
            audioOutputUID: "unavailable-output",
            videoDeviceID: "unavailable-video"
        )
        let refreshed = appOperatorState(remoteSelectionComplete: true)

        let merged = AppLocalOperatorInventoryRefreshMergePolicy.merge(
            current: current,
            refreshResult: refreshed
        )

        #expect(merged.inventory.selection == refreshed.inventory.selection)
        #expect(merged.inventory.audioDevices == refreshed.inventory.audioDevices)
        #expect(merged.inventory.videoDevices == refreshed.inventory.videoDevices)
    }

    @Test
    func wave11AppChannelMetersRenderEmptyClampedAndCompactStates() throws {
        let states: [(String, AnyView)] = [
            ("empty", AnyView(AppChannelMeterView(levels: [], visibleChannels: 8))),
            ("clamped", AnyView(AppChannelMeterView(levels: [-0.4, 0.15, 0.72, 1.4], visibleChannels: 4))),
            ("compact", AnyView(AppCompactMeterStrip(
                levels: [0.03, 0.25, 0.7, 1.0, 0.4, 0.0, -0.2, 1.2, 0.6],
                status: "Synthetic local meter state."
            )))
        ]

        for (name, view) in states {
            assertRendered(
                view.padding(),
                size: Self.renderSize,
                named: "meter-\(name)",
                requiresAttachedHost: true,
                boundsMessageStyle: .rendered
            )
        }
        #expect(ChannelMeterLevelSnapshot(levels: [0.1, 0.2], visibleChannels: 8).values == [0.1, 0.2])
        #expect(AppChannelMeterAccessibilityPolicy.value(channelCount: 4, peak: 1.4).contains("100 percent"))
    }

    @Test
    func wave11AppExecutionViewRendersDirectSuccessAndPreviewFailureStates() throws {
        var surface = appOperatorState(remoteSelectionComplete: true)
        surface.directPeerCommandFields.executablePath = "/usr/bin/true"
        let plan = AppOperatorPrototypePlan.make(operatorSurface: surface)
        let controller = AppExecutionController()
        controller.phase = .runFinished
        controller.lastRunWasDryRun = true
        controller.lastExitCode = 15
        controller.lastError = "Error Domain=NSCocoaErrorDomain Code=4 synthetic artifact unavailable"

        assertRendered(
            AppExecutionView(
                operatorSurface: Binding(get: { surface }, set: { surface = $0 }),
                executionController: controller,
                plan: plan,
                inputsLocked: true
            )
            .padding(),
            size: Self.renderSize,
            named: "direct-execution-success",
            requiresAttachedHost: true,
            boundsMessageStyle: .rendered
        )

        surface.directPeerCommandFields.executablePath = "/private/tmp/open-lola-wave11-missing-executable"
        let failedPlan = AppOperatorPrototypePlan.make(operatorSurface: surface)
        assertRendered(
            AppExecutionView(
                operatorSurface: Binding(get: { surface }, set: { surface = $0 }),
                executionController: controller,
                plan: failedPlan,
                inputsLocked: false
            )
            .padding(),
            size: Self.renderSize,
            named: "direct-execution-preview-failure",
            requiresAttachedHost: true,
            boundsMessageStyle: .rendered
        )
    }

    @Test
    func wave11AppExecutionViewRendersWindowsAndConnectorLayouts() throws {
        var windows = appOperatorState(remoteSelectionComplete: true)
        windows.sessionMode = .windowsLoLa
        windows.windowsLoLaPeerFields.executablePath = "/usr/bin/true"
        windows.windowsLoLaPeerFields.outputPath = "/private/tmp/open-lola-wave11-windows.json"

        var connector = appOperatorState(remoteSelectionComplete: true)
        connector.sessionMode = .jackTrip
        connector.jackTripPeerFields.executablePath = "/usr/bin/true"
        connector.jackTripPeerFields.outputPath = "/private/tmp/open-lola-wave11-connector.json"

        for (name, surface) in [("windows", windows), ("connector", connector)] {
            var renderedSurface = surface
            let plan = AppOperatorPrototypePlan.make(operatorSurface: renderedSurface)
            assertRendered(
                AppExecutionView(
                    operatorSurface: Binding(get: { renderedSurface }, set: { renderedSurface = $0 }),
                    executionController: AppExecutionController(),
                    plan: plan,
                    inputsLocked: false
                )
                .padding(),
                size: Self.renderSize,
                named: "\(name)-execution",
                requiresAttachedHost: true,
                boundsMessageStyle: .rendered
            )
        }
    }

    @Test
    func wave11AppCommandReviewRendersEscapedArguments() throws {
        let command = [
            "/usr/bin/open-lola",
            "--label",
            "Signal Desk",
            "--quote",
            "operator's choice",
            ""
        ]

        #expect(AppCommandPreview.copyText(command).contains("'operator'\\''s choice'"))
        #expect(AppCommandPreview.multilineDisplay(command).contains("\\\n"))
        assertRendered(
            AppCommandReviewBlock(
                title: "Synthetic command",
                detail: "Preview only",
                command: command
            )
            .padding(),
            size: Self.renderSize,
            named: "command-review",
            requiresAttachedHost: true,
            boundsMessageStyle: .rendered
        )
    }

    @Test
    func wave11AppExecutionControllerPureStateGuardsDoNotLaunchProcesses() {
        let controller = AppExecutionController()
        #expect(controller.lastValidationSummary == "No validation run yet")
        controller.stop()
        #expect(controller.status == "No active process.")
        #expect(controller.phase == .idle)

        controller.lastValidationExitCode = 0
        controller.lastValidationResult = .passed
        controller.lastValidationFinishedAt = "2026-08-05T10:00:00Z"
        controller.lastLatencyMetrics = AppLatencyHeroMetrics.make(from: [])
        controller.invalidateRuntimeEvidenceAfterConfigurationChange()

        #expect(controller.lastValidationExitCode == nil)
        #expect(controller.lastValidationResult == .unknown)
        #expect(controller.lastValidationFinishedAt == nil)
        #expect(controller.status == "Configuration changed. Revalidate before starting.")
        #expect(controller.lastValidationSummary == "No validation run yet")
    }

    @Test
    func wave11AppSceneNoProcessGuardsStayInert() {
        let scene = OpenLolaAppScene()
        let originalIntent = scene.operatorSurface.commandIntent

        scene.handleScenePhaseChange(.active)
        scene.handleScenePhaseChange(.background)
        scene.installQuitGuard()
        scene.requestMenuStop()

        #expect(scene.operatorSurface.commandIntent == originalIntent)
        #expect(scene.executionController.phase == .idle)
        #expect(!scene.executionController.isRunning)
    }

}
