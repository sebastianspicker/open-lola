import AppKit
import OpenLolaCore
import SwiftUI

// MARK: - Session State Banner

/// Full-width strip that shows the current session lifecycle state.
/// Always visible between the toolbar and the scrollable detail content.
struct AppSessionStateBanner: View {
    private enum Layout {
        static let bannerMinHeight: CGFloat = 44
    }

    private enum Animation {
        static let pulseDurationSeconds: Double = 1.1
        static let dimmedPulseOpacity: Double = 0.35
    }

    let state: AppSessionState
    let localPeer: String
    let remotePeer: String
    let localHost: String
    let remoteHost: String
    let elapsedSeconds: Int?
    var onGoToSetup: (() -> Void)? = nil
    var onGoToSession: (() -> Void)? = nil
    var onStartSession: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: state.systemImage)
                .foregroundStyle(state.color)
                .opacity(state.isAnimated ? pulseOpacity : 1.0)
                .animation(
                    state.isAnimated && !reduceMotion
                        ? .easeInOut(duration: Animation.pulseDurationSeconds).repeatForever(autoreverses: true)
                        : nil,
                    value: pulseOpacity
                )
                .id(state.rawValue)
                .onAppear(perform: restartPulse)
                .onChange(of: state) { _, _ in restartPulse() }
                .onChange(of: reduceMotion) { _, _ in restartPulse() }

            Text(bannerLabel)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(state.color)
                .lineLimit(2)
                .truncationMode(.middle)
                .help(bannerLabel)
                .accessibilityHint(bannerLabel)

            if state == .validating {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            if let elapsed = elapsedSeconds {
                Text(formatElapsed(elapsed))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if state == .unconfigured, let onGoToSetup {
                Button("Go to Setup", action: onGoToSetup)
                    .modifier(SessionBannerCTAStyle(tone: state.color))
            }

            if state == .ready, let onGoToSession {
                Button("Go to Session →", action: onGoToSession)
                    .modifier(SessionBannerCTAStyle(tone: state.color))
            }

            if state == .armed, let onStartSession {
                Button("Start Session", action: onStartSession)
                    .modifier(SessionBannerCTAStyle(tone: state.color))
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.xs)
        .frame(minHeight: Layout.bannerMinHeight)
        .background(state.color.opacity(0.07))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppDesignSystem.panelBorder)
                .frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session state: \(state.rawValue). \(bannerLabel)")
        .background(AppAccessibilityAnnouncementView(message: accessibilityAnnouncementMessage))
    }

    private var accessibilityAnnouncementMessage: String? {
        AppSessionBannerAccessibilityPolicy.announcementMessage(state: state, label: bannerLabel)
    }

    private var bannerLabel: String {
        switch state {
        case .unconfigured:
            return "Configure devices and peers before starting"
        case .ready:
            return "Configuration complete — arm to proceed"
        case .armed:
            return "\(localPeer) ↔ \(remotePeer) · \(localHost) → \(remoteHost)"
        case .connecting:
            return "Connecting \(localPeer) (\(localHost)) ↔ \(remotePeer) (\(remoteHost))"
        case .supervisorRunning:
            return "Supervisor running — awaiting validated media evidence"
        case .dryRunRunning:
            return "Dry run in progress — no live media should be inferred"
        case .validating:
            return "Validating…"
        case .awaitingEvidence:
            return "Awaiting evidence — validate the runtime report before treating the session as live"
        case .validated:
            return "Evidence validated — completed run evidence is available"
        case .receiverWarning:
            return "Local Preview degraded — check the preview receiver before treating monitoring as healthy"
        case .live:
            return "\(localPeer) (\(localHost)) ↔ \(remotePeer) (\(remoteHost))"
        case .error:
            return "Error — check execution log for details"
        }
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func restartPulse() {
        pulseOpacity = 1.0
        guard state.isAnimated, !reduceMotion else {
            return
        }
        withAnimation(.easeInOut(duration: Animation.pulseDurationSeconds).repeatForever(autoreverses: true)) {
            pulseOpacity = Animation.dimmedPulseOpacity
        }
    }
}

enum AppSessionBannerAccessibilityPolicy {
    static func announcementMessage(state: AppSessionState, label: String) -> String? {
        switch state {
        case .receiverWarning, .error:
            return "Session state: \(state.rawValue). \(label)"
        default:
            return nil
        }
    }
}

struct AppAccessibilityAnnouncementView: NSViewRepresentable {
    let message: String?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let message, context.coordinator.lastMessage != message else {
            return
        }
        context.coordinator.lastMessage = message
        NSAccessibility.post(
            element: nsView,
            notification: .announcementRequested,
            userInfo: [.announcement: message]
        )
    }

    final class Coordinator {
        var lastMessage: String?
    }
}

private struct SessionBannerCTAStyle: ViewModifier {
    let tone: Color

    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(tone)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xxs)
            .background(tone.opacity(0.12), in: Capsule())
    }
}

// MARK: - Helpers

extension AppSessionState {
    /// Derives the session state from the execution controller's observable state.
    static func derive(
        isRunning: Bool,
        isArmed: Bool,
        lastExitCode: Int?,
        isConfigured: Bool,
        commandIntent: NativeAppShellOperatorCommandIntent,
        phase: AppExecutionPhase,
        hasValidatedRuntimeEvidence: Bool = false
    ) -> AppSessionState {
        if isRunning {
            switch phase {
            case .dryRunRunning:
                return .dryRunRunning
            case .validationRunning:
                return .validating
            default:
                return .supervisorRunning
            }
        }
        switch phase {
        case .runFailed, .validationFailed, .failedToStart:
            return .error
        case .stopRequested:
            return isConfigured ? .ready : .unconfigured
        case .runFinished, .validationPassed:
            if hasValidatedRuntimeEvidence {
                return .validated
            }
            return .awaitingEvidence
        default:
            break
        }
        if let code = lastExitCode, code != 0 {
            return .error
        }
        if lastExitCode == 0 {
            if hasValidatedRuntimeEvidence {
                return .validated
            }
            return .awaitingEvidence
        }
        guard isConfigured else {
            return .unconfigured
        }
        if commandIntent == .handoffRequested { return .connecting }
        if isArmed { return .armed }
        return .ready
    }
}
