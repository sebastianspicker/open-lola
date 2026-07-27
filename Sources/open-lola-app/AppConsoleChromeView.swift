// Renders AppConsoleChromeView in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import OpenLolaCore
import SwiftUI

enum AppSignalDeskNavigationPolicy {
    static let visibleSectionIDs: [NativeAppShellSurfaceSectionID] = [
        .session,
        .devices,
        .routing,
        .streams,
        .packetMonitor,
        .validation,
        .diagnostics
    ]

    static func visibleSections(
        from sections: [NativeAppShellSurfaceSection]
    ) -> [NativeAppShellSurfaceSection] {
        visibleSectionIDs.compactMap { id in sections.first { $0.id == id } }
    }
}

struct AppConsoleSidebarView: View {
    let sections: [NativeAppShellSurfaceSection]
    @Binding var selectedSection: NativeAppShellSurfaceSectionID
    let sessionState: AppSessionState
    let captureReportAvailable: Bool

    private var sessionSections: [NativeAppShellSurfaceSection] {
        orderedSections([.session])
    }

    private var setupSections: [NativeAppShellSurfaceSection] {
        orderedSections([.devices, .routing])
    }

    private var monitorSections: [NativeAppShellSurfaceSection] {
        orderedSections([.streams, .packetMonitor])
    }

    private var evidenceSections: [NativeAppShellSurfaceSection] {
        orderedSections([.validation, .diagnostics])
    }

    var body: some View {
        VStack(spacing: 0) {
            AppBrandSignature()
                .padding(.horizontal, AppSpacing.m)
            Divider()
            List(selection: $selectedSection) {
                sidebarGroup(
                    header: "Operate",
                    sections: sessionSections,
                    stateIndicator: sessionState != .unconfigured ? sessionState.color : nil
                )
                sidebarGroup(header: "Setup", sections: setupSections)
                sidebarGroup(
                    header: "Monitor",
                    sections: monitorSections,
                    dimmedReason: packetMonitorDimmedReason
                )
                sidebarGroup(header: "Evidence", sections: evidenceSections)
            }
            .listStyle(.sidebar)
            Divider()
            AppConsoleSidebarFooter(
                sessionState: sessionState,
                captureReportAvailable: captureReportAvailable
            )
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.s)
        }
        .background(.regularMaterial)
        .navigationTitle("Open LoLa")
        .accessibilityLabel("Open LoLa signal desk")
        .navigationSplitViewColumnWidth(
            min: AppWindowSize.sidebarWidth - 40,
            ideal: AppWindowSize.sidebarWidth,
            max: AppWindowSize.sidebarWidth + 80
        )
    }

    private var packetMonitorDimmedReason: String? {
        AppPacketMonitorSidebarPolicy.dimmedReason(
            sessionState: sessionState,
            captureReportAvailable: captureReportAvailable
        )
    }

    @ViewBuilder
    private func sidebarGroup(
        header: String,
        sections: [NativeAppShellSurfaceSection],
        disabledReason: String? = nil,
        dimmedReason: String? = nil,
        stateIndicator: Color? = nil
    ) -> some View {
        if !sections.isEmpty {
            Section {
                ForEach(sections, id: \.id) { section in
                    AppConsoleSidebarRow(
                        section: section,
                        disabledReason: disabledReason,
                        dimmedReason: section.id == .packetMonitor ? dimmedReason : nil,
                        sessionState: section.id == .session ? sessionState : nil
                    )
                    .tag(section.id)
                }
            } header: {
                HStack(spacing: AppSpacing.xxs) {
                    Text(header)
                    if let stateIndicator {
                        Image(systemName: AppSidebarSessionIndicatorPolicy.systemImage(for: sessionState))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(stateIndicator)
                            .accessibilityLabel(AppSidebarSessionIndicatorPolicy.accessibilityLabel(for: sessionState))
                    }
                }
                .textCase(nil)
            }
        }
    }

    private func orderedSections(
        _ ids: [NativeAppShellSurfaceSectionID]
    ) -> [NativeAppShellSurfaceSection] {
        ids.compactMap { id in sections.first { $0.id == id } }
    }
}

private struct AppConsoleSidebarFooter: View {
    let sessionState: AppSessionState
    let captureReportAvailable: Bool

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: sessionState.systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(sessionState.color)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(sessionState.rawValue)
                    .font(.caption.weight(.semibold))
                Text(evidenceCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session \(sessionState.rawValue). \(evidenceCaption).")
    }

    private var evidenceCaption: String {
        if captureReportAvailable, sessionState == .validated {
            return "Recorded report · not live telemetry"
        }
        return captureReportAvailable ? "Packet evidence loaded" : "No packet evidence"
    }
}

enum AppSidebarSessionIndicatorPolicy {
    static func systemImage(for state: AppSessionState) -> String {
        state.systemImage
    }

    static func accessibilityLabel(for state: AppSessionState) -> String {
        "Session state: \(state.rawValue)"
    }

    /// Compact path badge for Operate → Session when the desk is past unconfigured.
    static func badgeText(for state: AppSessionState) -> String? {
        switch state {
        case .unconfigured:
            return nil
        case .armed, .ready:
            return "Ready"
        case .supervisorRunning:
            return "Live path"
        case .validated:
            return "Validated"
        default:
            return nil
        }
    }
}

private struct AppConsoleSidebarRow: View {
    let section: NativeAppShellSurfaceSection
    let disabledReason: String?
    let dimmedReason: String?
    let sessionState: AppSessionState?

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Label(AppSignalDeskSectionCopy.title(for: section.id), systemImage: section.systemImage)
            if let badgeText {
                Text(badgeText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(sessionState?.color ?? .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background((sessionState?.color ?? .secondary).opacity(0.14), in: Capsule())
                    .accessibilityHidden(true)
            } else if let sessionState {
                Image(systemName: sessionState.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(sessionState.color)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: AppSpacing.xs)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(disabledReason ?? dimmedReason ?? "Shows this workspace.")
        .help(disabledReason ?? dimmedReason ?? AppSignalDeskSectionCopy.detail(for: section.id))
        .disabled(disabledReason != nil)
    }

    private var badgeText: String? {
        sessionState.flatMap(AppSidebarSessionIndicatorPolicy.badgeText(for:))
    }

    private var accessibilityLabel: String {
        let title = AppSignalDeskSectionCopy.title(for: section.id)
        guard let sessionState else { return title }
        if let badgeText {
            return "\(title), \(badgeText), session state \(sessionState.rawValue)"
        }
        return "\(title), session state \(sessionState.rawValue)"
    }
}

enum AppPacketMonitorSidebarPolicy {
    static let missingCaptureHelp = "No capture yet. Open Packet Monitor to see how to produce packet evidence."

    static func disabledReason(sessionState: AppSessionState) -> String? {
        nil
    }

    static func dimmedReason(sessionState: AppSessionState, captureReportAvailable: Bool) -> String? {
        guard disabledReason(sessionState: sessionState) == nil, !captureReportAvailable else {
            return nil
        }
        return missingCaptureHelp
    }
}
