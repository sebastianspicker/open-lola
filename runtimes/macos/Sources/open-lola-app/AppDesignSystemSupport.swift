// Supplies design-system helpers, keeping shared styling rules out of individual operator views.
import SwiftUI

enum AppConstants {
    static let packetMonitorCapacity = 100
}

// MARK: - Spacing scale

enum AppSpacing {
static let xxs: CGFloat = 4
// swiftlint:disable:next identifier_name
static let xs: CGFloat = 8
// swiftlint:disable:next identifier_name
static let s: CGFloat = 12
// swiftlint:disable:next identifier_name
static let m: CGFloat = 16
// swiftlint:disable:next identifier_name
static let l: CGFloat = 24
// swiftlint:disable:next identifier_name
static let xl: CGFloat = 32
}

// MARK: - Typography helpers

extension Font {
    /// Large, monospaced hero display for the latency instrument readout.
    static var latencyHero: Font {
        .system(size: 56, weight: .bold, design: .monospaced)
    }

    /// Medium, semibold monospaced metrics value.
    static var metricsValue: Font {
        .system(size: 13, weight: .semibold, design: .monospaced)
    }
}

// MARK: - Window minimum sizes

enum AppWindowSize {
    static let operatorMinWidth: CGFloat = 1024
    static let operatorMinHeight: CGFloat = 720
    static let sessionMonitorMinWidth: CGFloat = 1080
    static let sessionMonitorMinHeight: CGFloat = 720
    static let settingsMinWidth: CGFloat = 540
    static let settingsMaxWidth: CGFloat = 800
    static let settingsWidth: CGFloat = 680
    static let sidebarWidth: CGFloat = 248
    static let inspectorWidth: CGFloat = 320
}

// MARK: - Session state machine

/// Ordered states for the P2P session lifecycle.
enum AppSessionState: String, CaseIterable {
    case unconfigured = "Unconfigured"
    case ready = "Configured"
    case armed = "Armed"
    case connecting = "Connecting"
    case supervisorRunning = "Supervisor Running"
    case dryRunRunning = "Dry Run Running"
    case validating = "Validating"
    case awaitingEvidence = "Awaiting Evidence"
    case validated = "Evidence Validated"
    case receiverWarning = "Preview Warning"
    case error = "Error"

    var color: Color {
        switch self {
        case .unconfigured: AppDesignSystem.stateUnconfigured
        case .ready: AppDesignSystem.stateReady
        case .armed: AppDesignSystem.stateArmed
        case .connecting: AppDesignSystem.stateConnecting
        case .supervisorRunning: AppDesignSystem.stateConnecting
        case .dryRunRunning: AppDesignSystem.stateArmed
        case .validating: AppDesignSystem.stateConnecting
        case .awaitingEvidence: AppDesignSystem.stateReady
        case .validated: AppDesignSystem.stateLive
        case .receiverWarning: AppDesignSystem.stateWarning
        case .error: AppDesignSystem.stateError
        }
    }

    var systemImage: String {
        switch self {
        case .unconfigured: "exclamationmark.circle"
        case .ready: "flag"
        case .armed: "checkmark.shield.fill"
        case .connecting: "dot.radiowaves.left.and.right"
        case .supervisorRunning: "terminal"
        case .dryRunRunning: "doc.text.magnifyingglass"
        case .validating: "checkmark.seal"
        case .awaitingEvidence: "clock.badge.exclamationmark"
        case .validated: "checkmark.seal.fill"
        case .receiverWarning: "exclamationmark.triangle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    var isAnimated: Bool {
        switch self {
        case .connecting, .validating:
            true
        default: false
        }
    }
}

// MARK: - Design-system-aware panel

/// A panel card that supports both the standard surface and a nested elevated surface.
struct DesignPanel<Content: View>: View {
    let title: String
    let systemImage: String
    var elevated: Bool = false
    var minHeight: CGFloat? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(
            elevated ? AppDesignSystem.elevatedBackground : AppDesignSystem.panelBackground,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
    }
}

// MARK: - Monospaced-digit label helpers

extension LabeledContent where Label == Text, Content == Text {
    /// Numeric value rendered with `.monospacedDigit()` for stable layout.
    static func metric(_ label: String, value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .monospacedDigit()
        }
    }
}
