import OpenLolaCore
import SwiftUI

struct AppConsoleSidebarView: View {
    let sections: [NativeAppShellSurfaceSection]
    @Binding var selectedSection: NativeAppShellSurfaceSectionID
    let sessionState: AppSessionState
    let captureReportAvailable: Bool

    private var setupSections: [NativeAppShellSurfaceSection] {
        sections.filter { [.devices, .routing].contains($0.id) }
    }

    private var sessionSections: [NativeAppShellSurfaceSection] {
        sections.filter { [.overview, .session, .streams].contains($0.id) }
    }

    private var monitorSections: [NativeAppShellSurfaceSection] {
        sections.filter { [.packetMonitor].contains($0.id) }
    }

    private var toolSections: [NativeAppShellSurfaceSection] {
        sections.filter { [.diagnostics, .validation, .settings].contains($0.id) }
    }

    var body: some View {
        List(selection: $selectedSection) {
            sidebarGroup(header: "SETUP", sections: setupSections)
            sidebarGroup(
                header: "SESSION",
                sections: sessionSections,
                stateIndicator: sessionState != .unconfigured ? sessionState.color : nil
            )
            sidebarGroup(
                header: "MONITOR",
                sections: monitorSections,
                disabledReason: packetMonitorDisabledReason
            )
            sidebarGroup(header: "TOOLS", sections: toolSections)
        }
        .listStyle(.sidebar)
        .navigationTitle("Open LoLa")
        .accessibilityLabel("Open LoLa operator console sections")
        .navigationSplitViewColumnWidth(
            min: AppWindowSize.sidebarWidth - 40,
            ideal: AppWindowSize.sidebarWidth,
            max: AppWindowSize.sidebarWidth + 80
        )
    }

    private var packetMonitorDisabledReason: String? {
        if sessionState == .unconfigured {
            return "Unavailable until the session is configured."
        }
        if !captureReportAvailable {
            return "No decoded capture report loaded."
        }
        return nil
    }

    @ViewBuilder
    private func sidebarGroup(
        header: String,
        sections: [NativeAppShellSurfaceSection],
        disabledReason: String? = nil,
        stateIndicator: Color? = nil
    ) -> some View {
        if !sections.isEmpty {
            Section {
                ForEach(sections, id: \.id) { section in
                    AppConsoleSidebarRow(
                        section: section,
                        disabledReason: disabledReason
                    )
                    .tag(section.id)
                }
            } header: {
                HStack(spacing: AppSpacing.xxs) {
                    Text(header)
                    if let stateIndicator {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(stateIndicator)
                            .accessibilityLabel("Session state: \(sessionState.rawValue)")
                    }
                }
            }
        }
    }
}

private struct AppConsoleSidebarRow: View {
    let section: NativeAppShellSurfaceSection
    let disabledReason: String?

    var body: some View {
        Label(section.title, systemImage: section.systemImage)
            .accessibilityLabel(section.title)
            .accessibilityHint(disabledReason ?? "Shows the \(section.title) section.")
            .help(disabledReason ?? "Shows the \(section.title) section.")
            .disabled(disabledReason != nil)
    }
}

struct AppConsoleTopBarView: View {
    let snapshot: AppConsoleStatusSnapshot
    let refreshReport: () -> Void
    let refreshInventory: () -> Void
    let stopExecution: () -> Void
    let canStopExecution: Bool
    let inputsLocked: Bool
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(snapshot.searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xs - 1)
                .background(AppDesignSystem.searchFieldBackground, in: RoundedRectangle(cornerRadius: 6))

            Spacer(minLength: AppSpacing.s)
            AppStatusBadge(title: snapshot.verdictTitle, systemImage: "flag", tone: snapshot.verdictTone, style: .rounded)
                .help("Source-level verdict: \(snapshot.verdictTitle)")
            AppStatusBadge(title: snapshot.executionTitle, systemImage: "terminal", tone: snapshot.executionTone, style: .rounded)
                .help("Execution status: \(snapshot.executionTitle)")
            Button("Refresh Synthetic Metrics", systemImage: "arrow.clockwise", action: refreshReport)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Refresh Synthetic Metrics")
            .help("Refresh synthetic metrics")
            Button("Refresh Local Media Inventory", systemImage: "externaldrive.badge.plus", action: refreshInventory)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Refresh Local Media Inventory")
            .disabled(inputsLocked)
            .help(inputsLocked ? AppRuntimeInputLock.lockedHelp : "Refresh local media inventory")
            Button("Stop Supervisor Run", systemImage: "stop.fill", action: stopExecution)
                .labelStyle(.iconOnly)
            .disabled(!canStopExecution)
            .accessibilityLabel("Stop Supervisor Run")
            .help(canStopExecution ? "Stop supervisor run" : "No execution is running")
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.xs)
        .background(AppDesignSystem.panelBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppDesignSystem.panelBorder)
                .frame(height: 1)
        }
    }
}

struct AppConsoleFooterStripView: View {
    let snapshot: AppConsoleStatusSnapshot

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            AppStatusBadge(
                title: snapshot.validationTitle,
                systemImage: "checklist.checked",
                tone: snapshot.validationTone,
                style: .rounded
            )
                .help(snapshot.validationTitle)
            AppStatusBadge(title: snapshot.packetTitle, systemImage: "tablecells", tone: snapshot.packetTone, style: .rounded)
                .help(snapshot.packetTitle)
            AppStatusBadge(
                title: snapshot.remoteStreamTitle,
                systemImage: "video.badge.ellipsis",
                tone: snapshot.remoteStreamTone,
                style: .rounded
            )
                .help(snapshot.remoteStreamTitle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.xs)
        .background(AppDesignSystem.footerBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppDesignSystem.panelBorder)
                .frame(height: 1)
        }
    }
}
