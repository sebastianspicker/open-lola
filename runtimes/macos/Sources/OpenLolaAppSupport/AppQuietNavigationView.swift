// Presents task navigation without coupling workspace selection to execution permissions.
import OpenLolaCore
import SwiftUI

enum AppQuietNavigationPolicy {
    static func automaticPhase(after execution: AppExecutionPhase) -> AppSessionPhase? {
        switch execution {
        case .supervisorRunning, .dryRunRunning: .live
        case .runFinished, .runFailed, .failedToStart: .review
        default: nil
        }
    }

    static func phase(
        section: NativeAppShellSurfaceSectionID,
        requested: AppSessionPhase?,
        current: AppSessionPhase
    ) -> AppSessionPhase {
        switch section {
        case .devices, .routing, .settings: .setup
        case .streams: .live
        case .validation, .diagnostics, .packetMonitor: .review
        case .session, .overview: requested ?? current
        }
    }
}

extension AppSessionPhase {
    var navigationTitle: String {
        switch self {
        case .setup: "Configure"
        case .ready: "Check"
        case .live: "Run"
        case .review: "Review"
        }
    }
}

struct AppQuietNavigationView: View {
    let sections: [NativeAppShellSurfaceSection]
    let selectedSection: NativeAppShellSurfaceSectionID
    let selectedPhase: AppSessionPhase
    let selectPhase: (AppSessionPhase) -> Void
    let selectSection: (NativeAppShellSurfaceSectionID) -> Void
    @Binding var isInspectorPresented: Bool
    let inputsLocked: Bool
    let refreshReport: () -> Void
    let refreshInventory: () -> Void
    @AppStorage(AppStorageKeys.appearance) private var appearance = AppAppearanceChoice.system

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.l) {
                    AppBrandSignature()
                    Divider().frame(height: 24)
                    Text("Independent open-source project")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Spacer(minLength: AppSpacing.s)
                    sourceAlpha
                    utilities
                }
                VStack(spacing: 0) {
                    HStack {
                        AppBrandSignature()
                        Spacer(minLength: AppSpacing.s)
                        utilities
                    }
                    HStack {
                        Text("Independent open-source project").font(.caption)
                        Spacer()
                        sourceAlpha
                    }
                    .foregroundStyle(.secondary)
                    .padding(.bottom, AppSpacing.s)
                }
            }
            Divider()
            HStack(spacing: AppSpacing.l) {
                ForEach(AppSessionPhase.allCases) { phase in
                    phaseButton(phase)
                        .frame(minWidth: 116, alignment: .leading)
                }
                Spacer(minLength: AppSpacing.s)
                Menu {
                    ForEach(sections, id: \.id) { section in
                        Button {
                            selectSection(section.id)
                        } label: {
                            Label(AppSignalDeskSectionCopy.title(for: section.id), systemImage: section.id == selectedSection ? "checkmark" : "rectangle")
                        }
                    }
                } label: {
                    Label("Workspaces", systemImage: "square.grid.2x2")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("All workspaces, including routing, media, packets and diagnostics")
            }
            .padding(.vertical, AppSpacing.s)
        }
        .padding(.horizontal, AppSpacing.xl)
        .background(AppDesignSystem.appBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Open LoLa navigation")
    }

    private var sourceAlpha: some View {
        Text("SOURCE ALPHA")
            .font(.system(size: 10, weight: .medium))
            .tracking(2)
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    private func phaseButton(_ phase: AppSessionPhase) -> some View {
        Button { selectPhase(phase) } label: {
            HStack(spacing: AppSpacing.xs) {
                Text(String(format: "%02d", phase.stepNumber))
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(phase.navigationTitle)
                    .font(.system(size: 15, weight: phase == selectedPhase ? .semibold : .regular))
            }
            .foregroundStyle(phase == selectedPhase ? .primary : .secondary)
            .padding(.vertical, AppSpacing.xs)
            .overlay(alignment: .bottomLeading) {
                if phase == selectedPhase {
                    Rectangle().fill(AppDesignSystem.signalAccent).frame(width: 24, height: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Step \(phase.stepNumber): \(phase.navigationTitle)")
        .accessibilityAddTraits(phase == selectedPhase ? .isSelected : [])
        .help("Open \(phase.navigationTitle). Navigation does not start or authorize a run.")
    }

    private var utilities: some View {
        HStack(spacing: AppSpacing.m) {
            Menu {
                Button("Refresh local media inventory", action: refreshInventory)
                    .disabled(inputsLocked)
                Button("Refresh source/synthetic report", action: refreshReport)
                Divider()
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearanceChoice.allCases) { choice in
                        Text(choice.rawValue.capitalized).tag(choice)
                    }
                }
                SettingsLink { Text("Settings…") }
            } label: {
                Label("Options", systemImage: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button { isInspectorPresented.toggle() } label: {
                Label("Evidence", systemImage: "sidebar.right")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("i", modifiers: [.command, .option])
            .help("Show or hide the evidence inspector")
        }
    }
}

enum AppAppearanceChoice: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct AppAppearanceModifier: ViewModifier {
    @AppStorage(AppStorageKeys.appearance) private var appearance = AppAppearanceChoice.system
    func body(content: Content) -> some View {
        content.preferredColorScheme(appearance.colorScheme)
    }
}
