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
            return "Awaiting evidence — validate the runtime report before treating media as proven"
        case .validated:
            return "Evidence validated — completed run evidence is available"
        case .receiverWarning:
            return "Local Preview degraded — check the preview receiver before treating monitoring as healthy"
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
        case .armed, .supervisorRunning, .validated, .receiverWarning, .error:
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
            .frame(minHeight: AppCompactToolButtonSizing.minimumHitLength)
            .background(tone.opacity(0.12), in: Capsule())
            .contentShape(Rectangle())
    }
}

// MARK: - Helpers

extension AppSessionState {
    /// Derives the session state from the execution controller's observable state.
    static func derive(_ input: AppSessionStateDerivationInput) -> AppSessionState {
        if let runningState = runningState(input) {
            return runningState
        }
        if let phaseState = terminalPhaseState(input) {
            return phaseState
        }
        if let exitState = exitCodeState(input) {
            return exitState
        }
        return configuredState(input)
    }

    private static func runningState(_ input: AppSessionStateDerivationInput) -> AppSessionState? {
        guard input.isRunning else {
            return nil
        }
        switch input.phase {
        case .dryRunRunning:
            return .dryRunRunning
        case .validationRunning:
            return .validating
        default:
            return .supervisorRunning
        }
    }

    private static func terminalPhaseState(_ input: AppSessionStateDerivationInput) -> AppSessionState? {
        switch input.phase {
        case .runFailed, .validationFailed, .failedToStart:
            return .error
        case .stopRequested:
            return input.isConfigured ? .ready : .unconfigured
        case .runFinished, .validationPassed:
            return completedState(hasValidatedRuntimeEvidence: input.hasValidatedRuntimeEvidence)
        default:
            return nil
        }
    }

    private static func exitCodeState(_ input: AppSessionStateDerivationInput) -> AppSessionState? {
        guard let code = input.lastExitCode else {
            return nil
        }
        guard code == 0 else {
            return .error
        }
        return completedState(hasValidatedRuntimeEvidence: input.hasValidatedRuntimeEvidence)
    }

    private static func configuredState(_ input: AppSessionStateDerivationInput) -> AppSessionState {
        guard input.isConfigured else {
            return .unconfigured
        }
        if input.commandIntent == .handoffRequested { return .connecting }
        if input.isArmed { return .armed }
        return .ready
    }

    private static func completedState(hasValidatedRuntimeEvidence: Bool) -> AppSessionState {
        hasValidatedRuntimeEvidence ? .validated : .awaitingEvidence
    }
}

struct AppSessionStateDerivationInput {
    let isRunning: Bool
    let isArmed: Bool
    let lastExitCode: Int?
    let isConfigured: Bool
    let commandIntent: NativeAppShellOperatorCommandIntent
    let phase: AppExecutionPhase
    var hasValidatedRuntimeEvidence: Bool = false
}
