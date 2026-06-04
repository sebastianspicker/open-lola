import OpenLolaCore
import SwiftUI

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
    @SceneStorage(AppStorageKeys.selectedSection) private var selectedSection = NativeAppShellSurfaceSectionID.overview
    @State private var derivedSurface: AppShellDerivedSurface
    @State private var searchText = ""
    @State private var showStopConfirmation = false
    @State private var elapsedTimerTask: Task<Void, Never>?
    @State private var derivedSurfaceRefreshTask: Task<Void, Never>?

    @MainActor
    init(
        report: NativeAppShellReport,
        operatorSurface: Binding<NativeAppShellOperatorPrototypeState>,
        executionController: AppExecutionController,
        previewState: AppPreviewReceiverState,
        inventoryController: AppLocalOperatorInventoryController,
        appSettings: AppSettings,
        contract: NativeAppShellSurfaceContract,
        syntheticMetricsRefreshState: AppSyntheticMetricsRefreshState,
        refreshReport: @escaping () -> Void,
        refreshInventory: @escaping () -> Void
    ) {
        self.report = report
        self._operatorSurface = operatorSurface
        self.executionController = executionController
        self.previewState = previewState
        self.inventoryController = inventoryController
        self.appSettings = appSettings
        self.contract = contract
        self.syntheticMetricsRefreshState = syntheticMetricsRefreshState
        self.refreshReport = refreshReport
        self.refreshInventory = refreshInventory
        self._derivedSurface = State(
            initialValue: AppShellDerivedSurface.make(
                report: report,
                operatorSurface: operatorSurface.wrappedValue,
                executionController: executionController,
                previewState: previewState,
                contract: contract
            )
        )
    }

    private var visibleSections: [NativeAppShellSurfaceSection] {
        NativeAppShellSectionSearch.visibleSections(contract.sections, query: searchText)
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
        NavigationSplitView {
            AppConsoleSidebarView(
                sections: visibleSections,
                selectedSection: $selectedSection,
                sessionState: derivedSurface.sessionState,
                captureReportAvailable: derivedSurface.captureReport != nil
            )
        } detail: {
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
                syntheticMetricsRefreshState: syntheticMetricsRefreshState,
                refreshReport: refreshReport,
                refreshInventory: refreshInventory,
                stopExecution: stopExecution,
                inputsLocked: executionController.isRunning,
                navigateToSection: { selectedSection = $0 },
                searchText: $searchText
            )
        }
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
        .onChange(of: searchText) { _, _ in clampSelectedSection() }
        .onChange(of: visibleSections.map(\.id)) { _, _ in clampSelectedSection() }
        .onChange(of: derivedSurface.sessionState) { _, _ in
            clampSelectedSection()
        }
        .confirmationDialog(
            AppTransportStopConfirmationPolicy.stopConfirmationTitle,
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                AppTransportStopConfirmationPolicy.stopConfirmationButtonTitle,
                role: .destructive,
                action: confirmStopExecution
            )
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AppTransportStopConfirmationPolicy.stopConfirmationMessage)
        }
    }

    private func stopExecution() {
        guard executionController.isRunning else {
            return
        }
        if AppTransportStopConfirmationPolicy.requiresConfirmation(
            isRunning: executionController.isRunning,
            lastRunWasDryRun: executionController.lastRunWasDryRun
        ) {
            showStopConfirmation = true
            return
        }
        confirmStopExecution()
    }

    private func confirmStopExecution() {
        executionController.stop()
        operatorSurface.commandIntent = .stopRequested
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

private struct AppShellRootDetailPanel: View {
    let report: NativeAppShellReport
    let selectedSection: NativeAppShellSurfaceSectionID?
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let previewState: AppPreviewReceiverState
    let inventoryController: AppLocalOperatorInventoryController
    let appSettings: AppSettings
    let contract: NativeAppShellSurfaceContract
    let derivedSurface: AppShellDerivedSurface
    let syntheticMetricsRefreshState: AppSyntheticMetricsRefreshState
    let refreshReport: () -> Void
    let refreshInventory: () -> Void
    let stopExecution: () -> Void
    let inputsLocked: Bool
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void
    @Binding var searchText: String

    var body: some View {
        VStack(spacing: 0) {
            AppConsoleTopBarView(
                snapshot: derivedSurface.statusSnapshot,
                syntheticMetricsRefreshState: syntheticMetricsRefreshState,
                refreshReport: refreshReport,
                refreshInventory: refreshInventory,
                stopExecution: stopExecution,
                canStopExecution: executionController.isRunning,
                inputsLocked: inputsLocked,
                searchText: $searchText
            )

            AppSessionStateBanner(
                state: derivedSurface.sessionState,
                localPeer: derivedSurface.operatorPlan.topologyLocalPeer,
                remotePeer: derivedSurface.operatorPlan.topologyRemotePeer,
                localHost: derivedSurface.operatorPlan.topologyLocalHost,
                remoteHost: derivedSurface.operatorPlan.topologyRemoteHost,
                elapsedSeconds: executionController.elapsedSeconds,
                onGoToSetup: { navigateToSection(.devices) },
                onGoToSession: { navigateToSection(.session) },
                onStartSession: bannerStartAction
            )

            if let selectedSection {
                ScrollView {
                    AppShellDetailView(
                        section: selectedSection,
                        report: report,
                        operatorSurface: $operatorSurface,
                        executionController: executionController,
                        previewState: previewState,
                        inventoryController: inventoryController,
                        appSettings: appSettings,
                        contract: contract,
                        captureReport: derivedSurface.captureReport,
                        operatorPlan: derivedSurface.operatorPlan,
                        surfaceProbe: derivedSurface.surfaceProbe,
                        sessionState: derivedSurface.sessionState,
                        inputsLocked: inputsLocked,
                        navigateToSection: navigateToSection
                    )
                    .padding(AppSpacing.m)
                }
            } else {
                AppUnavailableSectionView(
                    searchText: searchText,
                    sessionState: derivedSurface.sessionState,
                    captureReportAvailable: derivedSurface.captureReport != nil,
                    onGoToSetup: { navigateToSection(.devices) }
                )
            }

            AppConsoleFooterStripView(
                snapshot: derivedSurface.statusSnapshot,
                sessionState: derivedSurface.sessionState,
                armedForExecution: executionController.armedForExecution,
                isRunning: executionController.isRunning,
                stopExecution: stopExecution
            )
        }
        .background(AppDesignSystem.appBackground)
    }

    private func startSessionFromBanner() {
        guard executionController.prepareExecution(from: operatorSurface) else {
            return
        }
        if executionController.startArmed(operatorSurface: operatorSurface) {
            operatorSurface.commandIntent = .runRequested
        } else {
            operatorSurface.commandIntent = .idle
        }
    }

    private var canStartSessionFromBanner: Bool {
        AppTransportStartPolicy.canStart(
            armedForExecution: executionController.armedForExecution,
            dryRunAvailable: AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: operatorSurface.sessionMode)
                && derivedSurface.operatorPlan.isConfigured
                && !executionController.isRunning,
            lastValidationResult: executionController.lastValidationResult,
            hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence,
            requiresValidatedRuntimeEvidence: !operatorSurface.sessionMode.usesPostRunValidationStart
        )
    }

    private var bannerStartAction: (() -> Void)? {
        guard canStartSessionFromBanner else {
            return nil
        }
        return { startSessionFromBanner() }
    }
}

private struct AppUnavailableSectionView: View {
    let searchText: String
    let sessionState: AppSessionState
    let captureReportAvailable: Bool
    var onGoToSetup: (() -> Void)? = nil

    private var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: AppSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .frame(maxWidth: 340)
            }

            if sessionState == .unconfigured, !isSearchActive, let onGoToSetup {
                Button(action: onGoToSetup) {
                    Label("Go to Devices Setup", systemImage: "gearshape")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppDesignSystem.appBackground)
    }

    private var icon: String {
        if isSearchActive { return "magnifyingglass" }
        if sessionState == .unconfigured { return "gearshape.2" }
        return "slash.circle"
    }

    private var title: String {
        if isSearchActive { return "No matching section" }
        if sessionState == .unconfigured { return "Not configured" }
        return "Section unavailable"
    }

    private var detail: String {
        AppUnavailableSectionCopy.detail(
            searchText: searchText,
            sessionState: sessionState,
            captureReportAvailable: captureReportAvailable
        )
    }
}

enum AppUnavailableSectionCopy {
    static func detail(
        searchText: String,
        sessionState: AppSessionState,
        captureReportAvailable: Bool
    ) -> String {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.localizedCaseInsensitiveContains("packet"), !captureReportAvailable {
            return "No capture yet. Open Packet Monitor after configuring a session to see how to produce packet evidence."
        }
        if !trimmedSearch.isEmpty {
            return "No section matches \"\(trimmedSearch)\"."
        }
        return sessionState == .unconfigured
            ? "Configure your audio devices and peer addresses to get started."
            : "This section is unavailable in the current session state."
    }
}

private struct AppShellExecutionDerivedInputs: Equatable {
    let status: String
    let isRunning: Bool
    let armedForExecution: Bool
    let lastExitCode: Int?
    let lastValidationExitCode: Int?
    let phase: AppExecutionPhase
    let hasValidatedRuntimeEvidence: Bool
    let lastLatencyMetrics: AppLatencyHeroMetrics?
    let lastCaptureReport: LoLaCompatibilityCaptureReport?
    let lastExternalConnectorReport: ExternalConnectorSessionReport?
}

private struct AppShellPreviewDerivedInputs: Equatable {
    let phase: AppPreviewReceiverState.Phase
    let audioPreviewEnabled: Bool
    let videoPreviewEnabled: Bool
    let receiverStatus: String
}

private struct AppShellDerivedSurface {
    let operatorPlan: AppOperatorPrototypePlan
    let statusSnapshot: AppConsoleStatusSnapshot
    let sessionState: AppSessionState
    let surfaceProbe: NativeAppShellSurfaceProbeReport
    let captureReport: LoLaCompatibilityCaptureReport?

    @MainActor
    static func make(
        report: NativeAppShellReport,
        operatorSurface: NativeAppShellOperatorPrototypeState,
        executionController: AppExecutionController,
        previewState: AppPreviewReceiverState,
        contract: NativeAppShellSurfaceContract
    ) -> AppShellDerivedSurface {
        let operatorPlan = AppOperatorPrototypePlan.make(operatorSurface: operatorSurface)
        let baseSessionState = AppSessionState.derive(
            isRunning: executionController.isRunning,
            isArmed: executionController.armedForExecution,
            lastExitCode: executionController.lastExitCode,
            isConfigured: operatorPlan.isConfigured,
            commandIntent: operatorSurface.commandIntent,
            phase: executionController.phase,
            hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence
        )
        let sessionState = AppPreviewReceiverWarningPolicy.showsMainBannerWarning(
            phase: previewState.previewPhase,
            audioPreviewEnabled: previewState.audioPreviewEnabled,
            videoPreviewEnabled: previewState.videoPreviewEnabled,
            sessionState: baseSessionState
        ) ? .receiverWarning : baseSessionState
        return AppShellDerivedSurface(
            operatorPlan: operatorPlan,
            statusSnapshot: AppConsoleStatusSnapshot.make(
                report: report,
                plan: operatorPlan,
                executionController: executionController,
                captureReport: executionController.lastCaptureReport
            ),
            sessionState: sessionState,
            surfaceProbe: NativeAppShellSurfaceProbe.run(sourceReport: report, contract: contract),
            captureReport: executionController.lastCaptureReport
        )
    }
}
