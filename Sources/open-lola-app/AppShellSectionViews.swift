import OpenLolaCore
import SwiftUI

struct AppShellDetailView: View {
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
                    captureReport: captureReport,
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
                    inputsLocked: inputsLocked,
                    onOpenDiagnostics: { navigateToSection(.diagnostics) }
                )
            case .diagnostics:
                AppDiagnosticsSectionView(
                    report: report,
                    operatorPlan: operatorPlan,
                    executionController: executionController
                )
            case .validation:
                AppValidationSectionView(
                    operatorSurface: $operatorSurface,
                    report: report,
                    operatorPlan: operatorPlan,
                    executionController: executionController,
                    surfaceProbe: surfaceProbe,
                    launchProbePlan: contract.launchProbePlan,
                    appSettings: appSettings,
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
    let captureReport: LoLaCompatibilityCaptureReport?
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
                    : operatorPlan.sessionMode.externalConnectorKind != nil
                    ? 2
                    : operatorSurface.directPeerCommandFields.channelCount,
                sessionMode: operatorPlan.sessionMode,
                sessionState: sessionState,
                executionPhase: executionController.phase,
                packetEvidenceAvailable: AppConnectionTopologyAnimationPolicy.hasPacketEvidence(captureReport)
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
        let remoteEvidence = AppRemoteEvidenceStatusPolicy.make(
            plan: operatorPlan,
            captureReport: captureReport
        )
        LazyVGrid(columns: appShellTwoColumns, alignment: .leading, spacing: AppSpacing.m) {
            AppPreviewReceiverView(operatorSurface: $operatorSurface, previewState: previewState)
            DesignPanel(title: "Remote Evidence", systemImage: "video.badge.ellipsis") {
                MetricsGrid {
                    AppReadableMetric(label: "Runtime state", value: remoteEvidence.runtimeState)
                    AppReadableMetric(label: "Evidence", value: remoteEvidence.evidence)
                    LabeledContent("Packets", value: remoteEvidence.packetCount)
                }
            }
        }
    }
}

struct AppRemoteEvidenceStatusModel: Equatable {
    let runtimeState: String
    let evidence: String
    let packetCount: String
}

enum AppRemoteEvidenceStatusPolicy {
    static func make(
        plan: AppOperatorPrototypePlan,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> AppRemoteEvidenceStatusModel {
        let runtimeState: String
        switch plan.sessionMode {
        case .windowsLoLa:
            runtimeState = "Windows LoLa connector report only"
        case .jackTrip, .ultraGrid:
            runtimeState = "\(plan.sessionMode.displayName) connector report only"
        case .directMacPeer:
            runtimeState = plan.macB == nil
                ? AppCopyVocabulary.remotePlanUnavailable
                : AppCopyVocabulary.remotePlanOnlyNoReceivedMedia
        }
        return AppRemoteEvidenceStatusModel(
            runtimeState: runtimeState,
            evidence: captureReport == nil
                ? AppCopyVocabulary.noRemotePacketEvidenceMeasured
                : AppCopyVocabulary.packetCaptureReportLoaded,
            packetCount: captureReport.map { "\($0.summary.packetCount)" } ?? "Not measured"
        )
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
            } else if operatorSurface.sessionMode.externalConnectorKind != nil {
                AppExternalConnectorRoutingSummary(operatorSurface: $operatorSurface)
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

private struct AppExternalConnectorRoutingSummary: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState

    var body: some View {
        let fields = externalFields
        DesignPanel(title: "\(operatorSurface.sessionMode.displayName) connector", systemImage: "antenna.radiowaves.left.and.right") {
            MetricsGrid {
                AppReadableMetric(label: "Local host", value: fields.localHost, monospaced: true)
                AppReadableMetric(label: "Peer host", value: fields.peerHost, monospaced: true)
                LabeledContent("Role", value: fields.role.rawValue)
                LabeledContent("Media", value: fields.mediaMode.cliValue)
                AppReadableMetric(label: "Report", value: fields.outputPath, monospaced: true)
            }
        }
    }

    private var externalFields: NativeAppShellExternalConnectorPeerFields {
        switch operatorSurface.sessionMode.externalConnectorKind {
        case .jackTrip:
            return operatorSurface.jackTripPeerFields
        case .mvtpUltraGrid:
            return operatorSurface.ultraGridPeerFields
        case .lola, .none:
            return .jackTripAppDefault
        }
    }
}

private struct AppWindowsLoLaRoutingSummary: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState

    var body: some View {
        DesignPanel(title: "Windows LoLa connector", systemImage: "display.and.arrow.down") {
            MetricsGrid {
                AppReadableMetric(label: "Local host", value: operatorSurface.windowsLoLaPeerFields.localHost, monospaced: true)
                AppReadableMetric(label: "Windows host", value: operatorSurface.windowsLoLaPeerFields.windowsHost, monospaced: true)
                LabeledContent("Role", value: operatorSurface.windowsLoLaPeerFields.role.rawValue)
                LabeledContent("Media", value: operatorSurface.windowsLoLaPeerFields.mediaMode.cliValue)
                LabeledContent("Payload", value: operatorSurface.windowsLoLaPeerFields.payloadMode.rawValue)
                AppReadableMetric(label: "Report", value: operatorSurface.windowsLoLaPeerFields.outputPath, monospaced: true)
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
            return operatorSurface.sessionMode == .jackTrip
                ? operatorSurface.jackTripPeerFields.executablePath
                : operatorSurface.ultraGridPeerFields.executablePath
        }
    }

    private var reportPath: String {
        switch operatorSurface.sessionMode {
        case .windowsLoLa:
            return operatorSurface.windowsLoLaPeerFields.outputPath
        case .jackTrip:
            return operatorSurface.jackTripPeerFields.outputPath
        case .ultraGrid:
            return operatorSurface.ultraGridPeerFields.outputPath
        case .directMacPeer:
            return executionSettings.supervisorReportPath
        }
    }
}

private struct AppDevicesSectionView: View {
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let inventoryController: AppLocalOperatorInventoryController
    let appSettings: AppSettings
    let inputsLocked: Bool
    let onOpenDiagnostics: () -> Void

    var body: some View {
        AppLocalOperatorSurfaceView(
            operatorSurface: $operatorSurface,
            inventoryController: inventoryController,
            appSettings: appSettings,
            inputsLocked: inputsLocked,
            onOpenDiagnostics: onOpenDiagnostics
        )
    }
}

private struct AppDiagnosticsSectionView: View {
    let report: NativeAppShellReport
    let operatorPlan: AppOperatorPrototypePlan
    let executionController: AppExecutionController

    @State private var copyFeedback: AppPasteboardCopyFeedback?

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
                        copyFeedback = AppPasteboard.copyFeedback(
                            executionController.stdoutPath,
                            target: "stdout path"
                        )
                    } label: {
                        Label("Copy stdout path", systemImage: "doc.on.doc")
                    }
                    Button {
                        copyFeedback = AppPasteboard.copyFeedback(
                            executionController.stderrPath,
                            target: "stderr path"
                        )
                    } label: {
                        Label("Copy stderr path", systemImage: "doc.on.doc")
                    }
                }
                if let copyFeedback {
                    AppCopyFeedbackText(feedback: copyFeedback)
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
    @Binding var operatorSurface: NativeAppShellOperatorPrototypeState
    let report: NativeAppShellReport
    let operatorPlan: AppOperatorPrototypePlan
    let executionController: AppExecutionController
    let surfaceProbe: NativeAppShellSurfaceProbeReport
    let launchProbePlan: NativeAppShellLaunchProbePlan
    let appSettings: AppSettings
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
                                if let recovery = AppAdvancedControlRecoveryPolicy.recovery(
                                    for: blocker,
                                    plan: operatorPlan
                                ) {
                                    Text(recovery.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                    Button {
                                        operatorSurface.controlMode = .advanced
                                        appSettings.controlMode = NativeAppShellControlMode.advanced.rawValue
                                        navigateToSection(.devices)
                                    } label: {
                                        Label(recovery.buttonTitle, systemImage: "slider.horizontal.3")
                                    }
                                }
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
                Text("PARTIAL is expected until source/synthetic checks are paired with current runtime evidence from a measured supervisor or external connector report.")
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
        case .readyToValidate: "checkmark.seal"
        case .readyToStart: "checkmark.circle"
        case .blocked: "exclamationmark.triangle"
        case .running: "dot.radiowaves.left.and.right"
        case .evidenceIncomplete: "clock.badge.exclamationmark"
        }
    }

    var tone: Color {
        toneKind.color
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
