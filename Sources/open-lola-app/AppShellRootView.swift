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
        .onChange(of: searchText) { _, _ in clampSelectedSection() }
        .onChange(of: visibleSections.map(\.id)) { _, _ in clampSelectedSection() }
        .onChange(of: derivedSurface.sessionState) { _, _ in clampSelectedSection() }
    }

    private func stopExecution() {
        guard executionController.isRunning else {
            return
        }
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
    let refreshReport: () -> Void
    let refreshInventory: () -> Void
    let stopExecution: () -> Void
    @Binding var searchText: String

    var body: some View {
        VStack(spacing: 0) {
            AppConsoleTopBarView(
                snapshot: derivedSurface.statusSnapshot,
                refreshReport: refreshReport,
                refreshInventory: refreshInventory,
                stopExecution: stopExecution,
                canStopExecution: executionController.isRunning,
                searchText: $searchText
            )

            AppSessionStateBanner(
                state: derivedSurface.sessionState,
                localPeer: derivedSurface.operatorPlan.topologyLocalPeer,
                remotePeer: derivedSurface.operatorPlan.topologyRemotePeer,
                localHost: derivedSurface.operatorPlan.topologyLocalHost,
                remoteHost: derivedSurface.operatorPlan.topologyRemoteHost,
                elapsedSeconds: executionController.elapsedSeconds
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
                        sessionState: derivedSurface.sessionState
                    )
                    .padding(AppSpacing.m)
                }
            } else {
                AppUnavailableSectionView(
                    searchText: searchText,
                    sessionState: derivedSurface.sessionState,
                    captureReportAvailable: derivedSurface.captureReport != nil
                )
            }

            AppConsoleFooterStripView(snapshot: derivedSurface.statusSnapshot)
        }
        .background(AppDesignSystem.appBackground)
    }
}

private struct AppUnavailableSectionView: View {
    let searchText: String
    let sessionState: AppSessionState
    let captureReportAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "slash.circle")
                .font(.headline)
            Text(detail)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AppSpacing.m)
        .background(AppDesignSystem.appBackground)
    }

    private var title: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Section unavailable"
            : "No available matching section"
    }

    private var detail: String {
        if searchText.localizedCaseInsensitiveContains("packet"), !captureReportAvailable {
            return "Packet Monitor is unavailable until a decoded capture report is loaded."
        }
        return sessionState == .unconfigured
            ? "The matching section is unavailable until a session is configured."
            : "No section matches the current filter."
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
        contract: NativeAppShellSurfaceContract
    ) -> AppShellDerivedSurface {
        let operatorPlan = AppOperatorPrototypePlan.make(operatorSurface: operatorSurface)
        return AppShellDerivedSurface(
            operatorPlan: operatorPlan,
            statusSnapshot: AppConsoleStatusSnapshot.make(
                report: report,
                plan: operatorPlan,
                executionController: executionController,
                captureReport: executionController.lastCaptureReport
            ),
            sessionState: AppSessionState.derive(
                isRunning: executionController.isRunning,
                isArmed: executionController.armedForExecution,
                lastExitCode: executionController.lastExitCode,
                isConfigured: operatorPlan.isConfigured,
                commandIntent: operatorSurface.commandIntent,
                phase: executionController.phase,
                hasValidatedRuntimeEvidence: executionController.hasValidatedRuntimeEvidence
            ),
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    sessionState: sessionState
                )
            case .session:
                AppSessionSectionView(
                    operatorSurface: $operatorSurface,
                    executionController: executionController,
                    operatorPlan: operatorPlan,
                    sessionState: sessionState
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
                    appSettings: appSettings
                )
            case .devices:
                AppDevicesSectionView(
                    operatorSurface: $operatorSurface,
                    inventoryController: inventoryController,
                    appSettings: appSettings
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
                    launchProbePlan: contract.launchProbePlan
                )
            case .packetMonitor:
                AppPacketMonitorView(captureReport: captureReport)
            case .settings:
                AppShellSettingsView(
                    configuration: report.configuration,
                    operatorSurface: $operatorSurface,
                    executionController: executionController,
                    previewState: previewState,
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

private struct AppOverviewSectionView: View {
    let report: NativeAppShellReport
    let operatorPlan: AppOperatorPrototypePlan
    let executionController: AppExecutionController
    let latencyMetrics: AppLatencyHeroMetrics?
    let hasValidatedRuntimeEvidence: Bool
    let sessionState: AppSessionState

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            if hasValidatedRuntimeEvidence {
                AppLatencyHeroView(
                    audioLatencyMs: latencyMetrics?.audioLatencyMs,
                    packetLossPercent: latencyMetrics?.packetLossPercent,
                    jitterMs: latencyMetrics?.jitterMs,
                    evidenceStatusMessage: latencyMetrics?.evidenceStatusMessage
                )
            } else if let latencyMetrics {
                AppConsolePanel(title: "Runtime Evidence", systemImage: "chart.line.uptrend.xyaxis") {
                    AppReadableMetric(
                        label: "Latency metrics",
                        value: latencyMetrics.evidenceStatusMessage ?? "Loaded but not currently validated"
                    )
                }
            }
            LazyVGrid(columns: appShellTwoColumns, alignment: .leading, spacing: 14) {
                AppConsolePanel(title: "Readiness", systemImage: "flag") {
                    AppShellOverviewView(report: report)
                }
                AppConsolePanel(title: "Operator Plan", systemImage: "point.3.connected.trianglepath.dotted") {
                    AppOperatorReadinessView(plan: operatorPlan, executionController: executionController)
                }
            }
        }
    }
}

private struct AppSessionSectionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let executionController: AppExecutionController
    let operatorPlan: AppOperatorPrototypePlan
    let sessionState: AppSessionState

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            AppTransportView(
                operatorSurface: $operatorSurface,
                executionController: executionController,
                plan: operatorPlan
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
                sessionState: sessionState
            )

            AppExecutionView(
                operatorSurface: $operatorSurface,
                executionController: executionController,
                plan: operatorPlan
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
        LazyVGrid(columns: appShellTwoColumns, alignment: .leading, spacing: 14) {
            AppPreviewReceiverView(operatorSurface: $operatorSurface, previewState: previewState)
            AppConsolePanel(title: "Remote Stream", systemImage: "video.badge.ellipsis") {
                MetricsGrid {
                    AppReadableMetric(label: "Status", value: remoteStreamStatus)
                    AppReadableMetric(label: "Evidence", value: "No remote video frames decoded")
                    LabeledContent("Packets", value: captureReport.map { "\($0.summary.packetCount)" } ?? "Not measured")
                }
            }
        }
    }

    private var remoteStreamStatus: String {
        if operatorPlan.sessionMode == .windowsLoLa {
            return "Report only"
        }
        return operatorPlan.macB == nil ? "Unavailable" : "Plan only"
    }
}

private struct AppRoutingSectionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let operatorPlan: AppOperatorPrototypePlan
    let appSettings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if operatorSurface.sessionMode == .windowsLoLa {
                AppWindowsLoLaRoutingSummary(operatorSurface: $operatorSurface)
            } else {
                AppPeerNetworkFieldsView(operatorSurface: $operatorSurface, appSettings: appSettings)
                AppOperatorArtifactsView(
                    operatorSurface: $operatorSurface,
                    appSettings: appSettings
                )
            }
            AppOperatorCommandsView(plan: operatorPlan)
        }
    }
}

private struct AppWindowsLoLaRoutingSummary: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState

    var body: some View {
        GroupBox("Windows LoLa Connector") {
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

private struct AppDevicesSectionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let inventoryController: AppLocalOperatorInventoryController
    let appSettings: AppSettings

    var body: some View {
        AppLocalOperatorSurfaceView(
            operatorSurface: $operatorSurface,
            inventoryController: inventoryController,
            appSettings: appSettings
        )
    }
}

private struct AppDiagnosticsSectionView: View {
    let report: NativeAppShellReport
    let operatorPlan: AppOperatorPrototypePlan
    let executionController: AppExecutionController

    var body: some View {
        LazyVGrid(columns: appShellTwoColumns, alignment: .leading, spacing: 14) {
            AppConsolePanel(title: "Permissions", systemImage: "hand.raised") {
                AppShellPermissionsView(permissions: report.permissions)
            }
            AppConsolePanel(title: "Realtime Boundary", systemImage: "lock.shield") {
                AppShellBoundariesView(boundary: report.realtimeBoundary)
            }
            AppConsolePanel(title: "Metrics Observer", systemImage: "chart.line.uptrend.xyaxis") {
                AppShellMetricsView(observer: report.metricsObserver)
            }
            AppConsolePanel(title: "Process State", systemImage: "terminal") {
                AppReportsView(plan: operatorPlan, executionController: executionController)
            }
        }
    }
}

private struct AppValidationSectionView: View {
    let report: NativeAppShellReport
    let operatorPlan: AppOperatorPrototypePlan
    let executionController: AppExecutionController
    let surfaceProbe: NativeAppShellSurfaceProbeReport
    let launchProbePlan: NativeAppShellLaunchProbePlan

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppConsolePanel(title: "Validation Rows", systemImage: "checklist.checked") {
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
            }
            AppConsolePanel(title: "Surface Probe", systemImage: "macwindow.badge.plus") {
                AppShellProbeView(report: report, plan: launchProbePlan)
            }
        }
    }
}

private var appShellTwoColumns: [GridItem] {
    [
        GridItem(.adaptive(minimum: 340), spacing: 14),
    ]
}
