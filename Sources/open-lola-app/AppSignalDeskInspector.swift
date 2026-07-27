// Renders AppSignalDeskInspector in the operator UI, keeping presentation and user affordances separate from execution state.
import OpenLolaCore
import SwiftUI

struct AppSignalDeskToolbar: ToolbarContent {
    let selectedSection: NativeAppShellSurfaceSectionID?
    let sessionState: AppSessionState
    let syntheticMetricsRefreshState: AppSyntheticMetricsRefreshState
    let inputsLocked: Bool
    let refreshReport: () -> Void
    let refreshInventory: () -> Void
    @Binding var isInspectorPresented: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: sessionState.systemImage)
                    .foregroundStyle(sessionState.color)
                    .accessibilityHidden(true)
                Text(AppSignalDeskSectionCopy.title(for: selectedSection ?? .session))
                    .fontWeight(.semibold)
                Text("·")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Text(sessionState.rawValue)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(AppSignalDeskSectionCopy.title(for: selectedSection ?? .session)), "
                    + "session state \(sessionState.rawValue)"
            )
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: refreshInventory) {
                Label("Refresh Devices", systemImage: "externaldrive.badge.plus")
            }
            .labelStyle(.iconOnly)
            .disabled(inputsLocked)
            .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "Refresh local media devices")

            Button(action: refreshReport) {
                if syntheticMetricsRefreshState.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing source checks")
                } else {
                    Label("Refresh Source Checks", systemImage: "arrow.clockwise")
                }
            }
            .labelStyle(.iconOnly)
            .disabled(syntheticMetricsRefreshState.isRefreshing)
            .help(syntheticMetricsRefreshState.buttonHelp)

            Button {
                isInspectorPresented.toggle()
            } label: {
                Label(
                    isInspectorPresented ? "Hide Evidence Inspector" : "Show Evidence Inspector",
                    systemImage: "sidebar.right"
                )
            }
            .labelStyle(.iconOnly)
            .keyboardShortcut("i", modifiers: [.command, .option])
            .help(isInspectorPresented ? "Hide evidence inspector" : "Show evidence inspector")

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .labelStyle(.iconOnly)
            .help("Open application settings")
        }
    }
}

struct AppSignalDeskDocumentationToolbarView: View {
    let selectedSection: NativeAppShellSurfaceSectionID?
    let sessionState: AppSessionState

    var body: some View {
        ZStack {
            HStack {
                Spacer()

                HStack(spacing: AppSpacing.m) {
                    toolbarIcon("Refresh Devices", systemImage: "externaldrive.badge.plus")
                    toolbarIcon("Refresh Source Checks", systemImage: "arrow.clockwise")
                    toolbarIcon("Evidence Inspector", systemImage: "sidebar.right")
                    toolbarIcon("Settings", systemImage: "gearshape")
                }
            }

            HStack(spacing: AppSpacing.xs) {
                Text(AppSignalDeskSectionCopy.title(for: selectedSection ?? .session))
                Text("·").foregroundStyle(.tertiary)
                Text(sessionState.rawValue)
                Image(systemName: sessionState.systemImage)
                    .foregroundStyle(sessionState.color)
            }
            .font(.callout.weight(.semibold))
        }
        .padding(.horizontal, AppSpacing.m)
        .frame(height: 46)
        .background(.bar)
    }

    private func toolbarIcon(_ title: String, systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .medium))
        .foregroundStyle(title == "Evidence Inspector" ? AppDesignSystem.interactionAccent : .secondary)
        .frame(width: 28, height: 28)
        .accessibilityLabel(title)
        .help(title)
    }
}

struct AppEvidenceInspectorView: View {
    let report: NativeAppShellReport
    let plan: AppOperatorPrototypePlan
    let snapshot: AppConsoleStatusSnapshot
    let executionController: AppExecutionController
    let syntheticMetricsRefreshState: AppSyntheticMetricsRefreshState
    let refreshReport: () -> Void
    let navigateToSection: (NativeAppShellSurfaceSectionID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Evidence Inspector")
                        .font(.title2.weight(.semibold))
                    Text("What is measured, what is inferred, and what still needs proof.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AppEvidenceCardList(items: evidenceItems)

                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("Current route")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .foregroundStyle(.secondary)
                    LabeledContent("Workflow", value: plan.sessionMode.displayName)
                    LabeledContent("Profile", value: report.configuration.profileName)
                    AppReadableMetric(label: "Latest report", value: latestReportPath, monospaced: true)
                }
                .padding(AppSpacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    AppDesignSystem.elevatedBackground,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Button {
                        navigateToSection(.validation)
                    } label: {
                        Label("Review Evidence", systemImage: "checklist.checked")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppDesignSystem.interactionAccent)

                    HStack(spacing: AppSpacing.s) {
                        Button {
                            navigateToSection(.diagnostics)
                        } label: {
                            Label("Diagnostics", systemImage: "stethoscope")
                        }
                        Button(action: refreshReport) {
                            Label(
                                syntheticMetricsRefreshState.isRefreshing ? "Refreshing" : "Refresh",
                                systemImage: "arrow.clockwise"
                            )
                        }
                        .disabled(syntheticMetricsRefreshState.isRefreshing)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(AppSpacing.l)
        }
        .background(AppDesignSystem.panelBackground)
        .inspectorColumnWidth(min: 290, ideal: AppWindowSize.inspectorWidth, max: 380)
    }

    private var measuredReportDetail: String {
        if executionController.hasValidatedRuntimeEvidence {
            return "Latest completed runtime report passed validation."
        }
        if executionController.lastValidationExitCode == 0 {
            return "Validation completed, but required runtime evidence is incomplete."
        }
        if executionController.lastValidationExitCode != nil {
            return "The latest report did not pass structural validation."
        }
        return "No current runtime report has been validated."
    }

    private var latestReportPath: String {
        switch plan.sessionMode {
        case .windowsLoLa:
            plan.windowsLoLaFields.outputPath
        case .jackTrip, .ultraGrid:
            plan.externalConnectorFields.outputPath
        case .directMacPeer:
            executionController.settings.supervisorReportPath
        }
    }

    private var evidenceItems: [AppEvidenceCardItem] {
        [
            .init(
                kind: "Source checks",
                title: snapshot.verdictTitle,
                detail: "Static and synthetic checks; not a current media measurement.",
                badge: .letter("S"),
                tone: snapshot.verdictTone,
                isPrimary: false
            ),
            .init(
                kind: "Measured report",
                title: snapshot.validationTitle,
                detail: measuredReportDetail,
                badge: executionController.hasValidatedRuntimeEvidence
                    ? .symbol("checkmark")
                    : .letter("M"),
                tone: snapshot.validationTone,
                isPrimary: executionController.hasValidatedRuntimeEvidence
            ),
            .init(
                kind: "Packet capture",
                title: snapshot.packetTitle,
                detail: "Decoded packets from the latest loaded capture artifact.",
                badge: .letter("P"),
                tone: snapshot.packetTone,
                isPrimary: false
            ),
            .init(
                kind: "Remote media",
                title: snapshot.remoteStreamTitle,
                detail: "Remote receive proof remains distinct from local preview state.",
                badge: .letter("R"),
                tone: snapshot.remoteStreamTone,
                isPrimary: false
            )
        ]
    }
}

private struct AppEvidenceCardItem: Identifiable {
    enum Badge {
        case letter(Character)
        case symbol(String)
    }

    let kind: String
    let title: String
    let detail: String
    let badge: Badge
    let tone: Color
    let isPrimary: Bool

    var id: String { kind }
}

private struct AppEvidenceCardList: View {
    let items: [AppEvidenceCardItem]

    var body: some View {
        VStack(spacing: AppSpacing.s) {
            ForEach(items) { item in
                AppInspectorEvidenceCard(item: item)
            }
        }
    }
}

private struct AppInspectorEvidenceCard: View {
    let item: AppEvidenceCardItem

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.s) {
            badgeView
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.kind)
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                Text(item.title)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.s)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kind): \(item.title). \(item.detail)")
    }

    @ViewBuilder
    private var badgeView: some View {
        Group {
            switch item.badge {
            case let .letter(character):
                Text(String(character))
                    .font(.caption.weight(.bold))
            case let .symbol(name):
                Image(systemName: name)
                    .font(.caption.weight(.bold))
            }
        }
        .foregroundStyle(item.tone)
        .frame(width: 28, height: 28)
        .background(item.tone.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var cardBackground: Color {
        if item.isPrimary {
            return AppDesignSystem.stateLive.opacity(0.06)
        }
        return AppDesignSystem.elevatedBackground
    }

    private var cardBorder: Color {
        if item.isPrimary {
            return AppDesignSystem.stateLive.opacity(0.28)
        }
        return AppDesignSystem.panelBorder
    }
}
