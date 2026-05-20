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
        .onChange(of: operatorSurface) { _, _ in scheduleDerivedSurfaceRefresh() }
        .onChange(of: report) { _, _ in scheduleDerivedSurfaceRefresh() }
        .onChange(of: contract) { _, _ in scheduleDerivedSurfaceRefresh() }
        .onChange(of: executionDerivedInputs) { _, _ in scheduleDerivedSurfaceRefresh() }
        .onChange(of: previewDerivedInputs) { _, _ in scheduleDerivedSurfaceRefresh() }
        .onChange(of: searchText) { _, _ in clampSelectedSection() }
        .onChange(of: visibleSections.map(\.id)) { _, _ in clampSelectedSection() }
        .onChange(of: derivedSurface.sessionState) { oldState, newState in
            clampSelectedSection()
            if let targetSection = AppSidebarLiveNavigationPolicy.targetSection(
                currentSection: selectedSection,
                previousState: oldState,
                newState: newState
            ) {
                selectedSection = targetSection
            }
        }
        .confirmationDialog(
            "Stop active session?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop", role: .destructive, action: confirmStopExecution)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Stopping ends the current active audio/video session.")
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

enum AppSidebarLiveNavigationPolicy {
    static func targetSection(
        currentSection: NativeAppShellSurfaceSectionID,
        previousState: AppSessionState,
        newState: AppSessionState
    ) -> NativeAppShellSurfaceSectionID? {
        guard previousState != .live, newState == .live, currentSection != .session else {
            return nil
        }
        return .session
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
        guard prepareExecutionForStart() else {
            return
        }
        if executionController.startArmed(operatorSurface: operatorSurface) {
            operatorSurface.commandIntent = .runRequested
        } else {
            operatorSurface.commandIntent = .idle
        }
    }

    private func prepareExecutionForStart() -> Bool {
        switch operatorSurface.sessionMode {
        case .directMacPeer:
            return executionController.writePlanOrLogError(from: operatorSurface)
        case .windowsLoLa:
            return true
        case .jackTrip, .ultraGrid:
            return false
        }
    }

    private var canStartSessionFromBanner: Bool {
        AppTransportStartPolicy.canStart(
            armedForExecution: executionController.armedForExecution,
            dryRunAvailable: AppTransportWorkflowPolicy.isWorkflowAvailable(sessionMode: operatorSurface.sessionMode)
                && derivedSurface.operatorPlan.isConfigured
                && !executionController.isRunning,
            lastValidationResult: executionController.lastValidationResult,
            hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence
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
        if searchText.localizedCaseInsensitiveContains("packet"), !captureReportAvailable {
            return "Packet Monitor is unavailable until a decoded capture report is loaded."
        }
        if isSearchActive { return "No section matches \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))\"." }
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

private struct AppShellDetailView: View {
    let section: NativeAppShellSurfaceSectionID
    let report: NativeAppShellReport
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let previewState: AppPreviewReceiverState
    let inventoryController: AppLocalOperatorInventoryController
    let appSettings: AppSettings
    let contract: NativeAppShellSurfaceContract
    let captureReport: LoLaCompatibilityCaptureReport?
    let operatorPlan: AppOperatorPrototypePlan
    let surfaceProbe: NativeAppShellSurfaceProbeReport
    let sessionState: AppSessionState
    let inputsLocked: Bool
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    var body: some View {
        AppOperatorSectionLayout(title: sectionTitle) {
            Text(sectionTitle)
                .font(.title2.weight(.semibold))

            switch section {
            case .overview:
                AppOverviewSectionView(
                    report: report,
                    operatorPlan: operatorPlan,
                    executionController: executionController,
                    latencyMetrics: executionController.lastLatencyMetrics,
                    hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence,
                    sessionState: sessionState,
                    captureReport: captureReport,
                    navigateToSection: navigateToSection
                )
            case .session:
                AppSessionSectionView(
                    operatorSurface: $operatorSurface,
                    executionController: executionController,
                    operatorPlan: operatorPlan,
                    sessionState: sessionState,
                    inputsLocked: inputsLocked
                )
            case .streams:
                AppStreamsSectionView(
                    operatorSurface: $operatorSurface,
                    previewState: previewState,
                    operatorPlan: operatorPlan,
                    captureReport: captureReport
                )
            case .routing:
                AppRoutingSectionView(
                    operatorSurface: $operatorSurface,
                    operatorPlan: operatorPlan,
                    appSettings: appSettings,
                    inputsLocked: inputsLocked
                )
            case .devices:
                AppDevicesSectionView(
                    operatorSurface: $operatorSurface,
                    inventoryController: inventoryController,
                    appSettings: appSettings,
                    inputsLocked: inputsLocked
                )
            case .diagnostics:
                AppDiagnosticsSectionView(
                    report: report,
                    operatorPlan: operatorPlan,
                    executionController: executionController
                )
            case .validation:
                AppValidationSectionView(
                    report: report,
                    operatorPlan: operatorPlan,
                    executionController: executionController,
                    surfaceProbe: surfaceProbe,
                    launchProbePlan: contract.launchProbePlan,
                    navigateToSection: navigateToSection
                )
            case .packetMonitor:
                AppPacketMonitorView(
                    captureReport: captureReport,
                    emptyState: AppPacketMonitorEmptyState.make(
                        plan: operatorPlan,
                        executionSettings: executionController.settings
                    ),
                    navigateToSection: navigateToSection
                )
            case .settings:
                AppShellSettingsSummaryView(
                    operatorSurface: operatorSurface,
                    executionSettings: executionController.settings,
                    executionController: executionController,
                    appSettings: appSettings
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionTitle: String {
        contract.sections.first { $0.id == section }?.title ?? "Open LoLa"
    }
}

private struct AppOperatorSectionLayout<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            content
        }
        .frame(maxWidth: 1180, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct AppOverviewSectionView: View {
    let report: NativeAppShellReport
    let operatorPlan: AppOperatorPrototypePlan
    let executionController: AppExecutionController
    let latencyMetrics: AppLatencyHeroMetrics?
    let hasValidatedRuntimeEvidence: Bool
    let sessionState: AppSessionState
    let captureReport: LoLaCompatibilityCaptureReport?
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    var body: some View {
        let summary = AppOverviewOperatorSummary.make(
            report: report,
            plan: operatorPlan,
            executionController: executionController,
            sessionState: sessionState,
            captureReport: captureReport
        )
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            if hasValidatedRuntimeEvidence {
                AppLatencyHeroView(
                    audioLatencyMs: latencyMetrics?.audioLatencyMs,
                    packetLossPercent: latencyMetrics?.packetLossPercent,
                    jitterMs: latencyMetrics?.jitterMs,
                    evidenceStatusMessage: latencyMetrics?.evidenceStatusMessage
                )
            } else if let latencyMetrics {
                DesignPanel(title: "Runtime Evidence", systemImage: "chart.line.uptrend.xyaxis") {
                    AppReadableMetric(
                        label: "Latency metrics",
                        value: latencyMetrics.evidenceStatusMessage ?? "Loaded but not currently validated"
                    )
                }
            }
            AppOverviewStatusStrip(items: summary.statusItems)
            HStack(alignment: .top, spacing: AppSpacing.m) {
                AppOverviewNextActionPanel(action: summary.nextAction, navigateToSection: navigateToSection)
                AppOverviewEvidencePanel(summary: summary.evidence)
            }
            .fixedSize(horizontal: false, vertical: true)
            DesignPanel(title: "Operator Plan", systemImage: "point.3.connected.trianglepath.dotted") {
                AppOperatorReadinessView(plan: operatorPlan, executionController: executionController)
            }
        }
    }
}

private struct AppOverviewStatusStrip: View {
    let items: [AppOverviewStatusItem]

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.s) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Label(item.title, systemImage: item.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .textSelection(.enabled)
                }
                .padding(AppSpacing.s)
                .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
                .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
                }
            }
        }
    }
}

private struct AppOverviewNextActionPanel: View {
    let action: AppOverviewNextAction
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    var body: some View {
        DesignPanel(title: "Next Action", systemImage: action.systemImage) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(action.title)
                    .font(.title3.weight(.semibold))
                Text(action.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Button {
                    navigateToSection(action.targetSection)
                } label: {
                    Label(action.targetSectionLabel, systemImage: "arrow.right.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct AppOverviewEvidencePanel: View {
    let summary: AppOverviewEvidenceSummary

    var body: some View {
        DesignPanel(title: "Evidence Summary", systemImage: "doc.text.magnifyingglass") {
            MetricsGrid {
                LabeledContent("Source verdict", value: summary.sourceVerdict)
                LabeledContent("Runtime", value: summary.runtimeEvidence)
                AppReadableMetric(label: "Latest report", value: summary.latestReportPath, monospaced: true)
                LabeledContent("Freshness", value: summary.freshness)
            }
        }
    }
}

private extension AppOverviewNextAction {
    var targetSectionLabel: String {
        switch targetSection {
        case .overview: "Open Overview"
        case .session: "Open Session"
        case .streams: "Open Streams"
        case .routing: "Open Routing"
        case .devices: "Open Devices"
        case .diagnostics: "Open Diagnostics"
        case .validation: "Open Validation"
        case .packetMonitor: "Open Packet Monitor"
        case .settings: "Open Settings"
        }
    }
}

private struct AppSessionSectionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let operatorPlan: AppOperatorPrototypePlan
    let sessionState: AppSessionState
    let inputsLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppTransportView(
                operatorSurface: $operatorSurface,
                executionController: executionController,
                plan: operatorPlan,
                sessionState: sessionState
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))

            AppConnectionTopologyView(
                localPeer: operatorPlan.topologyLocalPeer,
                remotePeer: operatorPlan.topologyRemotePeer,
                localHost: operatorPlan.topologyLocalHost,
                remoteHost: operatorPlan.topologyRemoteHost,
                channelCount: operatorPlan.sessionMode == .windowsLoLa
                    ? operatorPlan.windowsLoLaFields.channelCount
                    : operatorSurface.directPeerCommandFields.channelCount,
                sessionMode: operatorPlan.sessionMode,
                sessionState: sessionState,
                executionPhase: executionController.phase
            )

            AppExecutionView(
                operatorSurface: $operatorSurface,
                executionController: executionController,
                plan: operatorPlan,
                inputsLocked: inputsLocked
            )
            AppOperatorCommandsView(plan: operatorPlan)
            AppLogsView(executionController: executionController)
        }
    }
}

private struct AppStreamsSectionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let previewState: AppPreviewReceiverState
    let operatorPlan: AppOperatorPrototypePlan
    let captureReport: LoLaCompatibilityCaptureReport?

    var body: some View {
        LazyVGrid(columns: appShellTwoColumns, alignment: .leading, spacing: AppSpacing.m) {
            AppPreviewReceiverView(operatorSurface: $operatorSurface, previewState: previewState)
            DesignPanel(title: "Remote Stream", systemImage: "video.badge.ellipsis") {
                MetricsGrid {
                    AppReadableMetric(label: "Status", value: remoteStreamStatus)
                    AppReadableMetric(label: "Evidence", value: remoteVideoEvidence)
                    LabeledContent("Packets", value: captureReport.map { "\($0.summary.packetCount)" } ?? "Not measured")
                }
            }
        }
    }

    private var remoteVideoEvidence: String {
        captureReport.map { _ in "Capture report loaded" } ?? "Not measured"
    }

    private var remoteStreamStatus: String {
        if operatorPlan.sessionMode == .windowsLoLa {
            return "Report only"
        }
        if operatorPlan.sessionMode.unavailableAppReason != nil {
            return "Runtime unavailable"
        }
        return operatorPlan.macB == nil ? "Remote unavailable" : "Remote plan only"
    }
}

private struct AppRoutingSectionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let operatorPlan: AppOperatorPrototypePlan
    let appSettings: AppSettings
    let inputsLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            if operatorSurface.sessionMode == .windowsLoLa {
                AppWindowsLoLaRoutingSummary(operatorSurface: $operatorSurface)
            } else if operatorSurface.sessionMode.unavailableAppReason != nil {
                AppWorkflowUnavailableView(sessionMode: operatorSurface.sessionMode)
            } else {
                AppPeerNetworkFieldsView(operatorSurface: $operatorSurface, appSettings: appSettings)
                    .disabled(inputsLocked)
                    .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "")
                AppOperatorArtifactsView(
                    operatorSurface: $operatorSurface,
                    appSettings: appSettings,
                    inputsLocked: inputsLocked
                )
            }
        }
    }
}

private struct AppWindowsLoLaRoutingSummary: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState

    var body: some View {
        DesignPanel(title: "Windows LoLa connector", systemImage: "display.and.arrow.down") {
            MetricsGrid {
                LabeledContent("Local host", value: operatorSurface.windowsLoLaPeerFields.localHost)
                LabeledContent("Windows host", value: operatorSurface.windowsLoLaPeerFields.windowsHost)
                LabeledContent("Role", value: operatorSurface.windowsLoLaPeerFields.role.rawValue)
                LabeledContent("Media", value: operatorSurface.windowsLoLaPeerFields.mediaMode.cliValue)
                LabeledContent("Payload", value: operatorSurface.windowsLoLaPeerFields.payloadMode.rawValue)
                LabeledContent("Report", value: operatorSurface.windowsLoLaPeerFields.outputPath)
            }
        }
    }
}

private struct AppShellSettingsSummaryView: View {
    @Environment(\.openSettings) private var openSettings

    let operatorSurface: NativeAppShellOperatorPrototypeState
    let executionSettings: NativeAppShellExecutionSettings
    let executionController: AppExecutionController
    let appSettings: AppSettings

    var body: some View {
        DesignPanel(title: "Settings", systemImage: "gearshape") {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                MetricsGrid {
                    LabeledContent("Workflow", value: operatorSurface.sessionMode.displayName)
                    LabeledContent("Controls", value: operatorSurface.controlMode.displayName)
                    LabeledContent("Running", value: yesNo(executionController.isRunning))
                    AppReadableMetric(label: "Executable", value: executablePath, monospaced: true)
                    AppReadableMetric(label: "Plan", value: executionSettings.planPath, monospaced: true)
                    AppReadableMetric(label: "Report", value: reportPath, monospaced: true)
                }

                Button {
                    openSettings()
                } label: {
                    Label("Open Settings", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
                .help("Open the macOS Settings window")
            }
        }
    }

    private var executablePath: String {
        switch operatorSurface.sessionMode {
        case .directMacPeer:
            return operatorSurface.directPeerCommandFields.executablePath
        case .windowsLoLa:
            return operatorSurface.windowsLoLaPeerFields.executablePath
        case .jackTrip, .ultraGrid:
            return appSettings.executablePath
        }
    }

    private var reportPath: String {
        switch operatorSurface.sessionMode {
        case .windowsLoLa:
            return operatorSurface.windowsLoLaPeerFields.outputPath
        case .directMacPeer, .jackTrip, .ultraGrid:
            return executionSettings.supervisorReportPath
        }
    }
}

enum AppShellSettingsSurfacePolicy {
    static let sidebarUsesReadOnlySummary = true
    static let nativeSettingsSceneUsesMutableEditor = true
}

private struct AppDevicesSectionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let inventoryController: AppLocalOperatorInventoryController
    let appSettings: AppSettings
    let inputsLocked: Bool

    var body: some View {
        AppLocalOperatorSurfaceView(
            operatorSurface: $operatorSurface,
            inventoryController: inventoryController,
            appSettings: appSettings,
            inputsLocked: inputsLocked
        )
    }
}

private struct AppDiagnosticsSectionView: View {
    let report: NativeAppShellReport
    let operatorPlan: AppOperatorPrototypePlan
    let executionController: AppExecutionController

    var body: some View {
        let status = AppDiagnosticsStatusModel.make(report: report, executionController: executionController)
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack(alignment: .top, spacing: AppSpacing.m) {
                AppDiagnosticsSummaryCard(title: "Permissions", value: status.permissionsTitle, systemImage: "hand.raised")
                AppDiagnosticsSummaryCard(title: "Realtime Safety", value: status.realtimeSafetyTitle, systemImage: "lock.shield")
                AppDiagnosticsSummaryCard(title: "Process/Logs", value: status.processTitle, systemImage: "terminal")
                AppDiagnosticsSummaryCard(title: "Evidence", value: status.evidenceTitle, systemImage: "chart.line.uptrend.xyaxis")
            }
            DesignPanel(title: "Permissions", systemImage: "hand.raised") {
                AppShellPermissionsView(permissions: report.permissions)
            }
            DesignPanel(title: "Realtime Safety", systemImage: "lock.shield") {
                AppShellBoundariesView(boundary: report.realtimeBoundary)
            }
            DesignPanel(title: "Evidence Observability", systemImage: "chart.line.uptrend.xyaxis") {
                AppShellMetricsView(observer: report.metricsObserver)
                AppReadableMetric(label: "Evidence state", value: status.evidenceDetail)
            }
            DesignPanel(title: "Process/Logs", systemImage: "terminal") {
                AppReportsView(plan: operatorPlan, executionController: executionController)
                HStack(spacing: AppSpacing.s) {
                    Button {
                        AppPasteboard.copyString(executionController.stdoutPath)
                    } label: {
                        Label("Copy stdout path", systemImage: "doc.on.doc")
                    }
                    Button {
                        AppPasteboard.copyString(executionController.stderrPath)
                    } label: {
                        Label("Copy stderr path", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}

private struct AppDiagnosticsSummaryCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(2)
        }
        .padding(AppSpacing.s)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
        .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
    }
}

private struct AppValidationSectionView: View {
    let report: NativeAppShellReport
    let operatorPlan: AppOperatorPrototypePlan
    let executionController: AppExecutionController
    let surfaceProbe: NativeAppShellSurfaceProbeReport
    let launchProbePlan: NativeAppShellLaunchProbePlan
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    var body: some View {
        let preflight = AppValidationPreflightModel.make(
            plan: operatorPlan,
            executionController: executionController,
            surfaceProbe: surfaceProbe
        )
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            DesignPanel(title: "Can I Run?", systemImage: "checkmark.shield") {
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    AppStatusBadge(
                        title: preflight.verdict.rawValue,
                        systemImage: preflight.verdict.systemImage,
                        tone: preflight.verdict.tone,
                        style: .rounded
                    )
                    Text(preflight.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    ForEach(preflight.blockers) { blocker in
                        HStack(alignment: .top, spacing: AppSpacing.s) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(blocker.title)
                                    .font(.callout.weight(.semibold))
                                Text(blocker.remediation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer(minLength: AppSpacing.s)
                            Button {
                                navigateToSection(blocker.targetSection)
                            } label: {
                                Label(blocker.targetSectionLabel, systemImage: "arrow.right")
                            }
                        }
                        .padding(AppSpacing.s)
                        .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            DesignPanel(title: "Validation Details", systemImage: "checklist.checked") {
                ForEach(AppValidationRow.rows(
                    report: report,
                    plan: operatorPlan,
                    executionController: executionController,
                    surfaceProbe: surfaceProbe
                )) { row in
                    HStack {
                        AppStatusBadge(title: row.detail, systemImage: "circle.fill", tone: row.tone, style: .rounded)
                        Text(row.title)
                        Spacer(minLength: 0)
                    }
                }
                Divider()
                MetricsGrid {
                    AppReadableMetric(label: "Supervisor report", value: executionController.settings.supervisorReportPath, monospaced: true)
                    AppReadableMetric(label: "Stdout", value: executionController.stdoutPath, monospaced: true)
                    AppReadableMetric(label: "Stderr", value: executionController.stderrPath, monospaced: true)
                }
            }
            DesignPanel(title: "Surface Probe", systemImage: "macwindow.badge.plus") {
                AppShellProbeView(report: report, plan: launchProbePlan)
                Text("PARTIAL is expected until source-level checks are paired with current runtime evidence from a measured supervisor or external connector report.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}

private extension AppValidationPreflightVerdict {
    var systemImage: String {
        switch self {
        case .ready: "checkmark.circle"
        case .blocked: "exclamationmark.triangle"
        case .running: "dot.radiowaves.left.and.right"
        case .evidenceIncomplete: "clock.badge.exclamationmark"
        }
    }

    var tone: Color {
        switch self {
        case .ready: AppDesignSystem.stateLive
        case .blocked: AppDesignSystem.stateError
        case .running: AppDesignSystem.stateConnecting
        case .evidenceIncomplete: AppDesignSystem.stateReady
        }
    }
}

private extension AppValidationBlocker {
    var targetSectionLabel: String {
        switch targetSection {
        case .overview: "Overview"
        case .session: "Session"
        case .streams: "Streams"
        case .routing: "Routing"
        case .devices: "Devices"
        case .diagnostics: "Diagnostics"
        case .validation: "Validation"
        case .packetMonitor: "Packet Monitor"
        case .settings: "Settings"
        }
    }
}

private var appShellTwoColumns: [GridItem] {
    [
        GridItem(.adaptive(minimum: 340), spacing: AppSpacing.m),
    ]
}
