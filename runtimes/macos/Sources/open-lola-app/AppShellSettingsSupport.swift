// Supplies settings-screen helpers, keeping tab policy and UI layout focused on their own responsibilities.
import OpenLolaCore
import SwiftUI

enum AppShellSettingsTabID: String, CaseIterable, Equatable {
    case execution
    case peers
    case audio
    case video
    case preview
    case windowsLoLa
    case externalConnector
    case externalConnectorNotice
    case snapshot

    var title: String {
        switch self {
        case .execution:
            return "Execution"
        case .peers:
            return "Peers"
        case .audio:
            return "Audio"
        case .video:
            return "Video"
        case .preview:
            return "Preview"
        case .windowsLoLa:
            return "Windows LoLa"
        case .externalConnector:
            return "External Connector"
        case .externalConnectorNotice:
            return "External Connector"
        case .snapshot:
            return "Snapshot"
        }
    }
}

/// Gives configuration groups the same quiet, flat surface used by the operator console.
struct AppConsoleGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            configuration.label
                .font(.headline)
            configuration.content
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppDesignSystem.panelBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
    }
}

extension View {
    func appConsoleGroupBoxStyle() -> some View {
        groupBoxStyle(AppConsoleGroupBoxStyle())
    }
}

enum AppSettingsCommitFeedback: Equatable {
    case saved
    case discarded
    case conflict(String)

    init(_ result: AppSettingsDraftCommitResult) {
        switch result {
        case .saved:
            self = .saved
        case .conflict(let message):
            self = .conflict(message)
        }
    }

    var title: String {
        switch self {
        case .saved:
            return "Saved"
        case .discarded:
            return "Discarded"
        case .conflict(let message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .saved:
            return "checkmark.circle.fill"
        case .discarded:
            return "arrow.uturn.backward.circle"
        case .conflict:
            return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .saved:
            return AppDesignSystem.stateLive
        case .discarded:
            return AppDesignSystem.stateReady
        case .conflict:
            return AppDesignSystem.stateWarning
        }
    }
}

enum AppShellSettingsTabVisibility {
    static func visibleTabs(
        sessionMode: NativeAppShellSessionMode,
        controlMode: NativeAppShellControlMode
    ) -> [AppShellSettingsTabID] {
        guard sessionMode.supportsAppExecution else {
            return [.execution, .externalConnectorNotice]
        }
        switch (sessionMode, controlMode) {
        case (.directMacPeer, .normal):
            return [.execution, .preview, .snapshot]
        case (.directMacPeer, .advanced):
            return [.execution, .peers, .audio, .video, .preview, .snapshot]
        case (.windowsLoLa, .normal):
            return [.execution, .preview, .snapshot]
        case (.windowsLoLa, .advanced):
            return [.execution, .windowsLoLa, .preview, .snapshot]
        case (.jackTrip, _), (.ultraGrid, _):
            return [.execution, .externalConnector, .preview, .snapshot]
        }
    }
}
