// Renders AppShellRootView in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import OpenLolaCore
import SwiftUI

struct AppShellRootDependencies {
    var executionController: AppExecutionController
    var previewState: AppPreviewReceiverState
    var inventoryController: AppLocalOperatorInventoryController
    var appSettings: AppSettings
    var contract: NativeAppShellSurfaceContract
    var syntheticMetricsRefreshState: AppSyntheticMetricsRefreshState
    var refreshReport: () -> Void
    var refreshInventory: () -> Void
}

struct AppShellRootView: View {
    let report: NativeAppShellReport
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let previewState: AppPreviewReceiverState
    let inventoryController: AppLocalOperatorInventoryController
    let appSettings: AppSettings
    let contract: NativeAppShellSurfaceContract
    let syntheticMetricsRefreshState: AppSyntheticMetricsRefreshState
    let refreshReport: () -> Void
    let refreshInventory: () -> Void
    @SceneStorage(AppStorageKeys.selectedSection) private var selectedSection = NativeAppShellSurfaceSectionID.session
    @State private var derivedSurface: AppShellDerivedSurface
    @State private var isEvidenceInspectorPresented = false
    @State private var elapsedTimerTask: Task<Void, Never>?
    @State private var derivedSurfaceRefreshTask: Task<Void, Never>?
    @Environment(\.appDocumentationRendering) private var appDocumentationRendering

    @MainActor
    init(
        report: NativeAppShellReport,
        operatorSurface: Binding<NativeAppShellOperatorPrototypeState>,
        dependencies: AppShellRootDependencies,
        initialSelectedSection: NativeAppShellSurfaceSectionID = .session,
        initiallyPresentsEvidenceInspector: Bool = false
    ) {
        self.report = report
        self._operatorSurface = operatorSurface
        self.executionController = dependencies.executionController
        self.previewState = dependencies.previewState
        self.inventoryController = dependencies.inventoryController
        self.appSettings = dependencies.appSettings
        self.contract = dependencies.contract
        self.syntheticMetricsRefreshState = dependencies.syntheticMetricsRefreshState
        self.refreshReport = dependencies.refreshReport
        self.refreshInventory = dependencies.refreshInventory
        self._selectedSection = SceneStorage(
            wrappedValue: initialSelectedSection,
            AppStorageKeys.selectedSection
        )
        self._isEvidenceInspectorPresented = State(initialValue: initiallyPresentsEvidenceInspector)
        self._derivedSurface = State(
            initialValue: AppShellDerivedSurface.make(
                report: report,
                operatorSurface: operatorSurface.wrappedValue,
                executionController: dependencies.executionController,
                previewState: dependencies.previewState,
                contract: dependencies.contract
            )
        )
    }

    private var visibleSections: [NativeAppShellSurfaceSection] {
        AppSignalDeskNavigationPolicy.visibleSections(from: contract.sections)
    }

    private var resolvedSelectedSection: NativeAppShellSurfaceSectionID? {
        AppConsoleSectionSelection.resolvedSection(
            current: selectedSection,
            visibleSections: visibleSections,
            sessionState: derivedSurface.sessionState,
            captureReportAvailable: derivedSurface.captureReport != nil
        )
    }

    private var executionDerivedInputs: AppShellExecutionDerivedInputs {
        AppShellExecutionDerivedInputs(
            status: executionController.status,
            isRunning: executionController.isRunning,
            armedForExecution: executionController.armedForExecution,
            lastExitCode: executionController.lastExitCode,
            lastValidationExitCode: executionController.lastValidationExitCode,
            phase: executionController.phase,
            hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence,
            lastLatencyMetrics: executionController.lastLatencyMetrics,
            lastCaptureReport: executionController.lastCaptureReport,
            lastExternalConnectorReport: executionController.lastExternalConnectorReport
        )
    }

    private var previewDerivedInputs: AppShellPreviewDerivedInputs {
        AppShellPreviewDerivedInputs(
            phase: previewState.previewPhase,
            audioPreviewEnabled: previewState.audioPreviewEnabled,
            videoPreviewEnabled: previewState.videoPreviewEnabled,
            receiverStatus: previewState.receiverStatus
        )
    }

    var body: some View {
        Group {
            if appDocumentationRendering {
                documentationShell
            } else {
                runtimeShell
            }
        }
        .tint(AppDesignSystem.interactionAccent)
        .foregroundStyle(.primary)
        .frame(minWidth: AppWindowSize.operatorMinWidth, minHeight: AppWindowSize.operatorMinHeight)
        .onAppear {
            startElapsedTimer()
            clampSelectedSection()
        }
        .onDisappear {
            cancelElapsedTimer()
            cancelDerivedSurfaceRefresh()
        }
        .onChange(of: operatorSurface) { oldSurface, newSurface in
            if AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
                oldSurface: oldSurface,
                newSurface: newSurface
            ) {
                executionController.invalidateRuntimeEvidenceAfterConfigurationChange()
            }
            scheduleDerivedSurfaceRefresh()
        }
        .onChange(of: report) { _, _ in scheduleDerivedSurfaceRefresh() }
        .onChange(of: contract) { _, _ in scheduleDerivedSurfaceRefresh() }
        .onChange(of: executionDerivedInputs) { _, _ in scheduleDerivedSurfaceRefresh() }
        .onChange(of: previewDerivedInputs) { _, _ in scheduleDerivedSurfaceRefresh() }
        .onChange(of: visibleSections.map(\.id)) { _, _ in clampSelectedSection() }
        .onChange(of: derivedSurface.sessionState) { _, _ in
            clampSelectedSection()
        }
    }

    private var runtimeShell: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                AppConsoleSidebarView(
                    sections: visibleSections,
                    selectedSection: $selectedSection,
                    sessionState: derivedSurface.sessionState,
                    captureReportAvailable: derivedSurface.captureReport != nil
                )
            } detail: {
                detailPanel
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                AppSignalDeskToolbar(
                    selectedSection: resolvedSelectedSection,
                    sessionState: derivedSurface.sessionState,
                    syntheticMetricsRefreshState: syntheticMetricsRefreshState,
                    inputsLocked: executionController.isRunning,
                    refreshReport: refreshReport,
                    refreshInventory: refreshInventory,
                    isInspectorPresented: $isEvidenceInspectorPresented
                )
            }
            .inspector(isPresented: $isEvidenceInspectorPresented) {
                evidenceInspector
            }

            persistentTransport
        }
    }

    private var documentationShell: some View {
        VStack(spacing: 0) {
            AppSignalDeskDocumentationToolbarView(
                selectedSection: resolvedSelectedSection,
                sessionState: derivedSurface.sessionState
            )
            Divider()

            HStack(spacing: 0) {
                AppConsoleSidebarView(
                    sections: visibleSections,
                    selectedSection: $selectedSection,
                    sessionState: derivedSurface.sessionState,
                    captureReportAvailable: derivedSurface.captureReport != nil
                )
                .frame(width: AppWindowSize.sidebarWidth)

                Divider()

                detailPanel

                Divider()

                evidenceInspector
                .frame(width: AppWindowSize.inspectorWidth)
            }

            persistentTransport
        }
    }

    private var detailPanel: some View {
        AppShellRootDetailPanel(
            report: report,
            selectedSection: resolvedSelectedSection,
            operatorSurface: $operatorSurface,
            executionController: executionController,
            previewState: previewState,
            inventoryController: inventoryController,
            appSettings: appSettings,
            contract: contract,
            derivedSurface: derivedSurface,
            inputsLocked: executionController.isRunning,
            navigateToSection: { selectedSection = $0 }
        )
    }

    private var evidenceInspector: some View {
        AppEvidenceInspectorView(
            report: report,
            plan: derivedSurface.operatorPlan,
            snapshot: derivedSurface.statusSnapshot,
            executionController: executionController,
            syntheticMetricsRefreshState: syntheticMetricsRefreshState,
            refreshReport: refreshReport,
            navigateToSection: { selectedSection = $0 }
        )
    }

    private var persistentTransport: some View {
        AppTransportView(
            operatorSurface: $operatorSurface,
            executionController: executionController,
            plan: derivedSurface.operatorPlan,
            sessionState: derivedSurface.sessionState
        )
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.xs)
        .background(.bar)
    }

    private func startElapsedTimer() {
        elapsedTimerTask?.cancel()
        elapsedTimerTask = Task { await executionController.runElapsedTimer() }
    }

    private func cancelElapsedTimer() {
        elapsedTimerTask?.cancel()
        elapsedTimerTask = nil
    }

    @MainActor
    private func scheduleDerivedSurfaceRefresh() {
        derivedSurfaceRefreshTask?.cancel()
        derivedSurfaceRefreshTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else {
                return
            }
            refreshDerivedSurface()
            derivedSurfaceRefreshTask = nil
        }
    }

    @MainActor
    private func clampSelectedSection() {
        guard let resolved = resolvedSelectedSection,
              resolved != selectedSection else {
            return
        }
        selectedSection = resolved
    }

    private func cancelDerivedSurfaceRefresh() {
        derivedSurfaceRefreshTask?.cancel()
        derivedSurfaceRefreshTask = nil
    }

    @MainActor
    private func refreshDerivedSurface() {
        derivedSurface = AppShellDerivedSurface.make(
            report: report,
            operatorSurface: operatorSurface,
            executionController: executionController,
            previewState: previewState,
            contract: contract
        )
    }

}
