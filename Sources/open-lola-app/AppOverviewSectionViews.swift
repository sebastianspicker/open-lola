// Renders overview workspace sections for the Signal Desk operator interface.
import OpenLolaCore
import SwiftUI

struct AppOverviewSectionView: View {
    let report: NativeAppShellReport
    let operatorPlan: AppOperatorPrototypePlan
    let executionController: AppExecutionController
    let latencyMetrics: AppLatencyHeroMetrics?
    let hasValidatedRuntimeEvidence: Bool
    let sessionState: AppSessionState
    let captureReport: LoLaCompatibilityCaptureReport?
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    private var overviewSummary: AppOverviewOperatorSummary {
        appOverviewOperatorSummary(
            report: report,
            operatorPlan: operatorPlan,
            executionController: executionController,
            sessionState: sessionState,
            captureReport: captureReport
        )
    }

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
                DesignPanel(title: "Runtime Evidence", systemImage: "chart.line.uptrend.xyaxis") {
                    AppReadableMetric(
                        label: "Latency metrics",
                        value: latencyMetrics.evidenceStatusMessage ?? "Loaded but not currently validated"
                    )
                }
            }
            AppOverviewStatusStrip(items: overviewSummary.statusItems)
            AppOverviewActionEvidenceLayout(
                action: overviewSummary.nextAction,
                evidenceSummary: overviewSummary.evidence,
                navigateToSection: navigateToSection
            )
            DesignPanel(title: "Operator Plan", systemImage: "point.3.connected.trianglepath.dotted") {
                AppOperatorReadinessView(plan: operatorPlan, executionController: executionController)
            }
        }
    }
}

struct AppOverviewStatusStrip: View {
    let items: [AppOverviewStatusItem]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: AppSpacing.s)],
            alignment: .leading,
            spacing: AppSpacing.s
        ) {
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

struct AppOverviewActionEvidenceLayout: View {
    let action: AppOverviewNextAction
    let evidenceSummary: AppOverviewEvidenceSummary
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AppSpacing.m) {
                AppOverviewNextActionPanel(action: action, navigateToSection: navigateToSection)
                AppOverviewEvidencePanel(summary: evidenceSummary)
            }
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                AppOverviewNextActionPanel(action: action, navigateToSection: navigateToSection)
                AppOverviewEvidencePanel(summary: evidenceSummary)
            }
        }
    }
}

struct AppOverviewNextActionPanel: View {
    let action: AppOverviewNextAction
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    var body: some View {
        DesignPanel(title: "Next Action", systemImage: action.systemImage, minHeight: 170) {
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

struct AppOverviewEvidencePanel: View {
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

extension AppOverviewNextAction {
    var targetSectionLabel: String {
        switch targetSection {
        case .overview, .session: "Open Session"
        case .streams: "Open Media"
        case .routing: "Open Routing"
        case .devices: "Open Connection"
        case .diagnostics: "Open Diagnostics"
        case .validation: "Review Evidence"
        case .packetMonitor: "Open Packets"
        case .settings: "Open Settings"
        }
    }
}
