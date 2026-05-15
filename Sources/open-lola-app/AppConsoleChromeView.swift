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
            sidebarGroup(header: "SESSION", sections: sessionSections)
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
        disabledReason: String? = nil
    ) -> some View {
        if !sections.isEmpty {
            Section(header) {
                ForEach(sections, id: \.id) { section in
                    AppConsoleSidebarRow(
                        section: section,
                        disabledReason: disabledReason
                    )
                    .tag(section.id)
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
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(.blue)
            TextField(snapshot.searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppDesignSystem.searchFieldBackground, in: RoundedRectangle(cornerRadius: 6))

            Spacer(minLength: 12)
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
            .help("Refresh local media inventory")
            Button("Stop Supervisor Run", systemImage: "stop.fill", action: stopExecution)
                .labelStyle(.iconOnly)
            .disabled(!canStopExecution)
            .accessibilityLabel("Stop Supervisor Run")
            .help(canStopExecution ? "Stop supervisor run" : "No execution is running")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
        HStack(spacing: 10) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppDesignSystem.footerBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppDesignSystem.panelBorder)
                .frame(height: 1)
        }
    }
}

struct AppConsolePanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppDesignSystem.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
    }
}
