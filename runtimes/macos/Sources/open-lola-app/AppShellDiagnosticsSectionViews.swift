// Renders AppShellDiagnosticsSectionViews in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import OpenLolaCore
import SwiftUI

struct AppDiagnosticsSectionView: View {
    let report: NativeAppShellReport
    let operatorPlan: AppOperatorPrototypePlan
    let executionController: AppExecutionController

    @State private var copyFeedback: AppPasteboardCopyFeedback?

    var body: some View {
        let status = AppDiagnosticsStatusModel.make(report: report, executionController: executionController)
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 170), spacing: AppSpacing.s)],
                alignment: .leading,
                spacing: AppSpacing.s
            ) {
                AppDiagnosticsSummaryCard(
                    title: "Permissions",
                    value: status.permissionsTitle,
                    systemImage: "hand.raised"
                )
                AppDiagnosticsSummaryCard(
                    title: "Realtime Safety",
                    value: status.realtimeSafetyTitle,
                    systemImage: "lock.shield"
                )
                AppDiagnosticsSummaryCard(title: "Process/Logs", value: status.processTitle, systemImage: "terminal")
                AppDiagnosticsSummaryCard(
                    title: "Evidence",
                    value: status.evidenceTitle,
                    systemImage: "chart.line.uptrend.xyaxis"
                )
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
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .background(AppDesignSystem.elevatedBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
    }
}

struct AppValidationSectionView: View {
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
                    AppReadableMetric(
                        label: "Supervisor report",
                        value: executionController.settings.supervisorReportPath,
                        monospaced: true
                    )
                    AppReadableMetric(label: "Stdout", value: executionController.stdoutPath, monospaced: true)
                    AppReadableMetric(label: "Stderr", value: executionController.stderrPath, monospaced: true)
                }
            }
            DesignPanel(title: "Surface Probe", systemImage: "macwindow.badge.plus") {
                AppShellProbeView(report: report, plan: launchProbePlan)
                Text(
                    "PARTIAL is expected until source/synthetic checks are paired with current runtime evidence "
                        + "from a measured supervisor or external connector report."
                )
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
        case .overview: "Session"
        case .session: "Session"
        case .streams: "Media"
        case .routing: "Routing"
        case .devices: "Connection"
        case .diagnostics: "Diagnostics"
        case .validation: "Review"
        case .packetMonitor: "Packets"
        case .settings: "Settings"
        }
    }
}

var appShellTwoColumns: [GridItem] {
    [
        GridItem(.adaptive(minimum: 340), spacing: AppSpacing.m)
    ]
}
