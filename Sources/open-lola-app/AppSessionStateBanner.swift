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

    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Image(systemName: state.systemImage)
                .foregroundStyle(state.color)
                .opacity(state.isAnimated ? pulseOpacity : 1.0)
                .animation(
                    state.isAnimated
                        ? .easeInOut(duration: Animation.pulseDurationSeconds).repeatForever(autoreverses: true)
                        : .default,
                    value: pulseOpacity
                )
                .id(state.rawValue)
                .onAppear(perform: restartPulse)
                .onChange(of: state) { _, _ in restartPulse() }

            Text(bannerLabel)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(state.color)
                .lineLimit(2)
                .truncationMode(.middle)
                .help(bannerLabel)
                .accessibilityHint(bannerLabel)

            Spacer(minLength: 0)

            if let elapsed = elapsedSeconds {
                Text(formatElapsed(elapsed))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if state == .unconfigured, let onGoToSetup {
                Button("Go to Setup", action: onGoToSetup)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(state.color)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(state.color.opacity(0.12), in: Capsule())
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
        case .awaitingEvidence:
            return "Awaiting evidence — validate the runtime report before treating the session as live"
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
        guard state.isAnimated else {
            return
        }
        withAnimation(.easeInOut(duration: Animation.pulseDurationSeconds).repeatForever(autoreverses: true)) {
            pulseOpacity = Animation.dimmedPulseOpacity
        }
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
                return .awaitingEvidence
            default:
                return .supervisorRunning
            }
        }
        switch phase {
        case .runFailed, .validationFailed, .failedToStart:
            return .error
        case .runFinished, .validationPassed:
            if hasValidatedRuntimeEvidence {
                return .live
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
                return .live
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
