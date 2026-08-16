// Covers deterministic hosted rendering for the remaining app-shell hotspots without invoking operator actions.
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
struct AppHotspotWave18Tests {
    private static let renderSize = CGSize(width: 1_100, height: 820)

    @Test
    func wave18AppRoutingAndSettingsRenderWindowsLoLa() throws {
        try renderRoutingAndSettings(mode: .windowsLoLa, named: "windows-lola")
    }

    @Test
    func wave18AppRoutingAndSettingsRenderJackTrip() throws {
        try renderRoutingAndSettings(mode: .jackTrip, named: "jacktrip")
    }

    @Test
    func wave18AppRoutingAndSettingsRenderUltraGrid() throws {
        try renderRoutingAndSettings(mode: .ultraGrid, named: "ultragrid")
    }

    @Test
    func wave18AppRoutingAndSettingsRenderDirectPeerLocked() throws {
        try renderRoutingAndSettings(mode: .directMacPeer, inputsLocked: true, named: "direct-locked")
    }

    @Test
    func wave18AppReadOnlyOverviewRendersSyntheticReport() {
        assertRendered(
            AppShellOverviewView(report: NativeAppShellSyntheticSmoke.run()).padding(),
            size: Self.renderSize,
            named: "read-only-overview"
        )
    }

    @Test
    func wave18AppReadOnlyConfigurationRendersSyntheticSnapshot() {
        assertRendered(
            AppShellConfigurationView(configuration: syntheticConfiguration).padding(),
            size: Self.renderSize,
            named: "read-only-configuration"
        )
    }

    @Test
    func wave18AppReadOnlyMetricsRendersObserver() {
        assertRendered(
            AppShellMetricsView(
                observer: NativeMetricsObserverProfile(
                    streamName: "wave18-metrics",
                    readOnly: true,
                    blocksRealtimePaths: false,
                    publishesOnMainActor: true,
                    pollingIntervalMilliseconds: 250
                )
            )
            .padding(),
            size: Self.renderSize,
            named: "read-only-metrics"
        )
    }

    @Test
    func wave18AppReadOnlyBoundariesRendersSyntheticBoundary() {
        assertRendered(
            AppShellBoundariesView(
                boundary: NativeRealtimeBoundaryReport(
                    uiOwnsAudioLane: false,
                    uiOwnsVideoLane: false,
                    uiOwnsControlLane: false,
                    realtimeDependsOnSwiftUILifecycle: false,
                    usesImmutableConfigSnapshots: true,
                    latencyChangeRequiresExplicitUserAction: true,
                    settingsPersistedOutsideCallback: true
                )
            )
            .padding(),
            size: Self.renderSize,
            named: "read-only-boundaries"
        )
    }

    @Test
    func wave18AppReadOnlyProbeRendersDeclaredSurfaceOnly() {
        assertRendered(
            AppShellProbeView(
                report: NativeAppShellSyntheticSmoke.run(),
                plan: NativeAppShellSurfaceContract.releaseReadiness.launchProbePlan
            )
            .padding(),
            size: Self.renderSize,
            named: "read-only-probe"
        )
    }

    @Test
    func wave18AppRootDetailRendersUnselectedSurfaceWithoutNavigation() throws {
        let fixture = try makeFixture()
        let state = Wave18SurfaceState(surface: appOperatorState(remoteSelectionComplete: true))
        var requestedSection: NativeAppShellSurfaceSectionID?

        assertRendered(
            rootDetail(
                selectedSection: nil,
                state: state,
                fixture: fixture,
                navigate: { requestedSection = $0 }
            ),
            size: Self.renderSize,
            named: "root-unselected"
        )
        #expect(requestedSection == nil)
    }

    @Test
    func wave18AppRootDetailRendersUnconfiguredDirectSurfaceWithoutCapture() throws {
        let fixture = try makeFixture()
        let state = Wave18SurfaceState(surface: appOperatorState(remoteSelectionComplete: false))
        var requestedSection: NativeAppShellSurfaceSectionID?

        assertRendered(
            rootDetail(
                selectedSection: .session,
                state: state,
                fixture: fixture,
                navigate: { requestedSection = $0 }
            ),
            size: Self.renderSize,
            named: "root-unconfigured-direct"
        )
        #expect(requestedSection == nil)
    }

    @Test
    func wave18AppRootDetailRendersConfiguredDirectSurfaceWithoutCapture() throws {
        let fixture = try makeFixture()
        let state = Wave18SurfaceState(surface: appOperatorState(remoteSelectionComplete: true))
        var requestedSection: NativeAppShellSurfaceSectionID?

        assertRendered(
            rootDetail(
                selectedSection: .session,
                state: state,
                fixture: fixture,
                navigate: { requestedSection = $0 }
            ),
            size: Self.renderSize,
            named: "root-configured-direct"
        )
        #expect(requestedSection == nil)
    }

    @Test
    func wave18AppRootDetailDerivationKeepsDirectPolicyAndNoCapture() throws {
        let fixture = try makeFixture()
        let direct = AppShellDerivedSurface.make(
            report: NativeAppShellSyntheticSmoke.run(),
            operatorSurface: appOperatorState(remoteSelectionComplete: true),
            executionController: fixture.controller,
            previewState: fixture.previewState,
            contract: .releaseReadiness
        )
        let incomplete = AppShellDerivedSurface.make(
            report: NativeAppShellSyntheticSmoke.run(),
            operatorSurface: appOperatorState(remoteSelectionComplete: false),
            executionController: fixture.controller,
            previewState: fixture.previewState,
            contract: .releaseReadiness
        )

        #expect(direct.operatorPlan.sessionMode == .directMacPeer)
        #expect(direct.operatorPlan.isConfigured)
        #expect(direct.captureReport == nil)
        #expect(incomplete.sessionState == .unconfigured)
        #expect(incomplete.captureReport == nil)
    }

    @Test
    func wave18AppLocalOperatorRendersDirectRouteWithoutRefresh() throws {
        try renderLocalOperator(surface: appOperatorState(remoteSelectionComplete: true), inputsLocked: false, named: "local-direct")
    }

    @Test
    func wave18AppLocalOperatorRendersLockedWindowsRouteWithoutRefresh() throws {
        var surface = appOperatorState(remoteSelectionComplete: true)
        surface.sessionMode = .windowsLoLa
        try renderLocalOperator(surface: surface, inputsLocked: true, named: "local-windows-locked")
    }

    @Test
    func wave18AppLocalOperatorRendersInventoryErrorsWithoutRefresh() throws {
        var surface = appOperatorState(remoteSelectionComplete: true)
        surface.inventory.inventoryErrors = ["Synthetic inventory fixture warning"]
        surface.remoteInventory.inventoryErrors = ["Synthetic remote inventory fixture warning"]
        try renderLocalOperator(surface: surface, inputsLocked: false, named: "local-errors")
    }

    @Test
    func wave18AppOperatorPlanRendersConfiguredDirectReadinessAndCommands() {
        renderPlan(surface: appOperatorState(remoteSelectionComplete: true), named: "plan-direct-configured")
    }

    @Test
    func wave18AppOperatorPlanRendersWindowsReadinessAndCommands() {
        var surface = appOperatorState(remoteSelectionComplete: true)
        surface.sessionMode = .windowsLoLa
        renderPlan(surface: surface, named: "plan-windows")
    }

    @Test
    func wave18AppOperatorPlanRendersExternalReadinessAndCommands() {
        var surface = appOperatorState(remoteSelectionComplete: true)
        surface.sessionMode = .jackTrip
        renderPlan(surface: surface, named: "plan-jacktrip")
    }

    @Test
    func wave18AppOperatorPlanRendersUltraGridReadinessAndCommands() {
        var surface = appOperatorState(remoteSelectionComplete: true)
        surface.sessionMode = .ultraGrid
        renderPlan(surface: surface, named: "plan-ultragrid")
    }

    @Test
    func wave18AppOperatorPlanRendersUnavailableDirectReadinessAndCommands() {
        renderPlan(surface: appOperatorState(remoteSelectionComplete: false), named: "plan-direct-unavailable")
    }

    @Test
    func wave18AppTopologyRendersDirectVideoSignalPath() {
        renderTopology(mode: .directMacPeer, videoEnabled: true, named: "topology-direct-video")
    }

    @Test
    func wave18AppTopologyRendersDirectWithoutVideoSignalPath() {
        renderTopology(mode: .directMacPeer, videoEnabled: false, named: "topology-direct-no-video")
    }

    @Test
    func wave18AppTopologyRendersExternalVideoSignalPath() {
        renderTopology(mode: .jackTrip, videoEnabled: true, named: "topology-external-video")
    }

    @Test
    func wave18AppTopologyRendersExternalWithoutVideoSignalPath() {
        renderTopology(mode: .ultraGrid, videoEnabled: false, named: "topology-external-no-video")
    }

    private var syntheticConfiguration: NativeAppConfigurationSnapshot {
        .init(
            profile: .init(name: "wave18", audioDeviceSelection: "local-rme", outputDeviceUID: "local-rme"),
            audio: .init(sampleRateHertz: 48_000, framesPerBuffer: 128, requestedPlayoutTargetFrames: 128),
            features: .init(
                videoEnabled: true,
                showControlEnabled: false,
                lightingEnabled: false,
                createdByUI: true,
                immutableHandoff: true
            )
        )
    }

    private func renderRoutingAndSettings(
        mode: NativeAppShellSessionMode,
        inputsLocked: Bool = false,
        named: String
    ) throws {
        let fixture = try makeFixture()
        var surface = appOperatorState(remoteSelectionComplete: true)
        surface.sessionMode = mode
        let plan = AppOperatorPrototypePlan.make(operatorSurface: surface)

        assertRendered(
            VStack(alignment: .leading, spacing: 16) {
                AppRoutingSectionView(
                    operatorSurface: Binding(get: { surface }, set: { surface = $0 }),
                    operatorPlan: plan,
                    appSettings: fixture.settings,
                    inputsLocked: inputsLocked
                )
                AppShellSettingsSummaryView(
                    operatorSurface: surface,
                    executionSettings: fixture.controller.settings,
                    executionController: fixture.controller,
                    appSettings: fixture.settings
                )
            }
            .padding(),
            size: Self.renderSize,
            named: "routing-settings-\(named)"
        )
    }

    private func renderLocalOperator(
        surface initialSurface: NativeAppShellOperatorPrototypeState,
        inputsLocked: Bool,
        named: String
    ) throws {
        let fixture = try makeFixture()
        var surface = initialSurface
        var openedDiagnostics = false

        assertRendered(
            AppLocalOperatorSurfaceView(
                operatorSurface: Binding(get: { surface }, set: { surface = $0 }),
                inventoryController: AppLocalOperatorInventoryController(),
                appSettings: fixture.settings,
                inputsLocked: inputsLocked,
                onOpenDiagnostics: { openedDiagnostics = true }
            )
            .padding(),
            size: Self.renderSize,
            named: named
        )
        #expect(!openedDiagnostics)
    }

    private func renderPlan(surface: NativeAppShellOperatorPrototypeState, named: String) {
        let plan = AppOperatorPrototypePlan.make(operatorSurface: surface)
        assertRendered(
            VStack(alignment: .leading, spacing: 16) {
                AppOperatorReadinessView(plan: plan, executionController: AppExecutionController())
                AppOperatorCommandsView(plan: plan)
            }
            .padding(),
            size: Self.renderSize,
            named: named
        )
    }

    private func renderTopology(mode: NativeAppShellSessionMode, videoEnabled: Bool, named: String) {
        assertRendered(
            AppConnectionTopologyView(
                localPeer: "local-wave18",
                remotePeer: "remote-wave18",
                localHost: "192.0.2.18",
                remoteHost: "192.0.2.28",
                channelCount: 8,
                sessionMode: mode,
                sessionState: .ready,
                executionPhase: .idle,
                packetEvidenceAvailable: false,
                localDeviceLabel: "Local RME",
                remoteDeviceLabel: "Remote RME",
                profileCaption: "Synthetic stable rendering fixture",
                videoEnabled: videoEnabled
            )
            .padding(),
            size: Self.renderSize,
            named: named
        )
    }

    private func rootDetail(
        selectedSection: NativeAppShellSurfaceSectionID?,
        state: Wave18SurfaceState,
        fixture: Wave18Fixture,
        navigate: @escaping (NativeAppShellSurfaceSectionID) -> Void
    ) -> AppShellRootDetailPanel {
        let report = NativeAppShellSyntheticSmoke.run()
        let derived = AppShellDerivedSurface.make(
            report: report,
            operatorSurface: state.surface,
            executionController: fixture.controller,
            previewState: fixture.previewState,
            contract: .releaseReadiness
        )
        return AppShellRootDetailPanel(
            report: report,
            selectedSection: selectedSection,
            operatorSurface: Binding(get: { state.surface }, set: { state.surface = $0 }),
            executionController: fixture.controller,
            previewState: fixture.previewState,
            inventoryController: AppLocalOperatorInventoryController(),
            appSettings: fixture.settings,
            contract: .releaseReadiness,
            derivedSurface: derived,
            inputsLocked: false,
            navigateToSection: navigate
        )
    }

    private func makeFixture() throws -> Wave18Fixture {
        let suiteName = "open-lola-wave18-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return Wave18Fixture(
            suiteName: suiteName,
            settings: AppSettings(defaults: defaults),
            controller: AppExecutionController(),
            previewState: AppPreviewReceiverState(audioPreviewEnabled: false, videoPreviewEnabled: false)
        )
    }

}

@MainActor
private final class Wave18SurfaceState {
    var surface: NativeAppShellOperatorPrototypeState

    init(surface: NativeAppShellOperatorPrototypeState) {
        self.surface = surface
    }
}

@MainActor
private final class Wave18Fixture {
    let suiteName: String
    let settings: AppSettings
    let controller: AppExecutionController
    let previewState: AppPreviewReceiverState

    init(
        suiteName: String,
        settings: AppSettings,
        controller: AppExecutionController,
        previewState: AppPreviewReceiverState
    ) {
        self.suiteName = suiteName
        self.settings = settings
        self.controller = controller
        self.previewState = previewState
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}
