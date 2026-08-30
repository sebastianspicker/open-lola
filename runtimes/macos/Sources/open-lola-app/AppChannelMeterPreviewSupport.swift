// Supplies channel-meter preview data, keeping synthetic display values out of live audio metering.
import OpenLolaCore
import SwiftUI

struct AppChannelMeterEmptyStateView: View {
    let content: AppChannelMeterEmptyStateContent

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(content.title)
                .font(.caption.weight(.semibold))
            Text(content.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.accessibilityLabel)
    }
}

struct AppChannelMeterEmptyStateContent: Equatable {
    let title: String
    let detail: String
    let accessibilityLabel: String
}

enum AppChannelMeterEmptyStatePolicy {
    static func content(
        audioPreviewEnabled: Bool,
        audioPreviewPhase: AppPreviewReceiverState.Phase,
        status: String
    ) -> AppChannelMeterEmptyStateContent {
        if !audioPreviewEnabled {
            return disabledBySettingContent()
        }
        switch audioPreviewPhase {
        case .active:
            return activeContent()
        case .starting:
            return startingContent(status: status)
        case .failed:
            return failedContent(status: status)
        case .disabled:
            return disabledPhaseContent()
        case .idle, .degraded:
            return inactiveContent()
        }
    }

    private static func disabledBySettingContent() -> AppChannelMeterEmptyStateContent {
        AppChannelMeterEmptyStateContent(
            title: "Local audio preview off",
            detail: "Enable Audio Preview to use local input meters.",
            accessibilityLabel: "Local audio preview off. Enable Audio Preview to use local input meters."
        )
    }

    private static func activeContent() -> AppChannelMeterEmptyStateContent {
        AppChannelMeterEmptyStateContent(
            title: "Local audio meter active",
            detail: "Meters are waiting for local input levels.",
            accessibilityLabel: "Local audio meter active. Meters are waiting for local input levels."
        )
    }

    private static func startingContent(status: String) -> AppChannelMeterEmptyStateContent {
        AppChannelMeterEmptyStateContent(
            title: "Local audio meter starting",
            detail: status.isEmpty ? "Waiting for local metering to start." : status,
            accessibilityLabel: "Local audio meter starting. \(status)"
        )
    }

    private static func failedContent(status: String) -> AppChannelMeterEmptyStateContent {
        AppChannelMeterEmptyStateContent(
            title: "Local audio meter unavailable",
            detail: status.isEmpty
                ? "Resolve the local audio input or microphone permission before using meters."
                : status,
            accessibilityLabel: "Local audio meter unavailable. \(status)"
        )
    }

    private static func disabledPhaseContent() -> AppChannelMeterEmptyStateContent {
        AppChannelMeterEmptyStateContent(
            title: "Local audio preview disabled",
            detail: "Enable Audio Preview to use local input meters.",
            accessibilityLabel: "Local audio preview disabled. Enable Audio Preview to use local input meters."
        )
    }

    private static func inactiveContent() -> AppChannelMeterEmptyStateContent {
        AppChannelMeterEmptyStateContent(
            title: "No local audio meter active",
            detail: "Meters require active local metering evidence; remote packet evidence is shown separately.",
            accessibilityLabel: "No local audio meter active. Meters require active local metering evidence."
        )
    }
}

enum AppChannelMeterVisibilityPolicy {
    static func showsMeters(
        phase: AppExecutionPhase,
        audioPreviewEnabled: Bool,
        audioPreviewPhase: AppPreviewReceiverState.Phase = .idle
    ) -> Bool {
        audioPreviewEnabled && audioPreviewPhase == .active
    }
}
