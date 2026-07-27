// Renders AppSessionPhaseRail in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import SwiftUI

// MARK: - Phase model

/// Operator sequence phases shown on the Session workspace rail.
enum AppSessionPhase: String, CaseIterable, Identifiable, Equatable {
    case setup = "Setup"
    case ready = "Ready"
    case live = "Live"
    case review = "Review"

    var id: String { rawValue }

    var stepNumber: Int {
        switch self {
        case .setup: 1
        case .ready: 2
        case .live: 3
        case .review: 4
        }
    }
}

/// Presentation state for a single phase step.
enum AppSessionPhaseStepState: Equatable {
    case done
    case current
    case upcoming
}

// MARK: - Policy (testable)

/// Pure phase-selection policy for the Session phase rail.
enum AppSessionPhaseRailPolicy {
    /// Maps session state and light execution evidence to the current operator phase.
    static func currentPhase(
        sessionState: AppSessionState,
        hasValidatedRuntimeEvidence: Bool = false,
        lastExitCode: Int? = nil
    ) -> AppSessionPhase {
        switch sessionState {
        case .unconfigured:
            return .setup
        case .ready, .armed:
            return .ready
        case .connecting, .supervisorRunning, .dryRunRunning, .validating:
            return .live
        case .awaitingEvidence, .validated, .receiverWarning:
            return .review
        case .error:
            // Stay inside the existing sequence; do not invent a fifth phase.
            // Prefer Review when a run left exit evidence; otherwise Live.
            if hasValidatedRuntimeEvidence || lastExitCode != nil {
                return .review
            }
            return .live
        }
    }

    static func stepState(
        for phase: AppSessionPhase,
        current: AppSessionPhase
    ) -> AppSessionPhaseStepState {
        if phase.stepNumber < current.stepNumber { return .done }
        if phase.stepNumber == current.stepNumber { return .current }
        return .upcoming
    }

    static func accessibilityLabel(
        sessionState: AppSessionState,
        hasValidatedRuntimeEvidence: Bool = false,
        lastExitCode: Int? = nil
    ) -> String {
        let current = currentPhase(
            sessionState: sessionState,
            hasValidatedRuntimeEvidence: hasValidatedRuntimeEvidence,
            lastExitCode: lastExitCode
        )
        let done = AppSessionPhase.allCases
            .filter { $0.stepNumber < current.stepNumber }
            .map(\.rawValue)
        let donePart = done.isEmpty
            ? "none complete"
            : "completed \(done.joined(separator: ", "))"
        var label = "Session phase \(current.rawValue). \(donePart)."
        if sessionState == .error {
            label += " Session reports an error."
        }
        return label
    }
}

// MARK: - View

/// Capsule phase rail: Setup → Ready → Live → Review.
struct AppSessionPhaseRail: View {
    let sessionState: AppSessionState
    var hasValidatedRuntimeEvidence: Bool = false
    var lastExitCode: Int? = nil

    private enum Layout {
        static let markerSize: CGFloat = 16
        static let stepHorizontalPadding: CGFloat = 12
        static let stepVerticalPadding: CGFloat = 6
        static let softFillOpacity = 0.14
        static let ringOpacity = 0.25
        static let doneMarkerOpacity = 0.16
        static let upcomingNumberOpacity = 0.7
    }

    private var currentPhase: AppSessionPhase {
        AppSessionPhaseRailPolicy.currentPhase(
            sessionState: sessionState,
            hasValidatedRuntimeEvidence: hasValidatedRuntimeEvidence,
            lastExitCode: lastExitCode
        )
    }

    private var isErrorTone: Bool {
        sessionState == .error
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppSessionPhase.allCases) { phase in
                phaseStep(phase)
            }
        }
        .padding(AppSpacing.xxs)
        .background(AppDesignSystem.panelBackground, in: Capsule())
        .overlay {
            Capsule()
                .stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            AppSessionPhaseRailPolicy.accessibilityLabel(
                sessionState: sessionState,
                hasValidatedRuntimeEvidence: hasValidatedRuntimeEvidence,
                lastExitCode: lastExitCode
            )
        )
    }

    @ViewBuilder
    private func phaseStep(_ phase: AppSessionPhase) -> some View {
        let state = AppSessionPhaseRailPolicy.stepState(for: phase, current: currentPhase)
        let emphasizeError = isErrorTone && state == .current
        let accent = emphasizeError ? AppDesignSystem.stateError : AppDesignSystem.interactionAccent

        HStack(spacing: 6) {
            marker(phase: phase, state: state, emphasizeError: emphasizeError)
            Text(phase.rawValue)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(labelColor(for: state, emphasizeError: emphasizeError))
                .lineLimit(1)
        }
        .padding(.horizontal, Layout.stepHorizontalPadding)
        .padding(.vertical, Layout.stepVerticalPadding)
        .background(
            state == .current ? accent.opacity(Layout.softFillOpacity) : Color.clear,
            in: Capsule()
        )
        .overlay {
            if state == .current {
                Capsule()
                    .stroke(accent.opacity(Layout.ringOpacity), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(stepAccessibilityLabel(phase: phase, state: state, emphasizeError: emphasizeError))
        .accessibilityAddTraits(state == .current ? .isSelected : [])
    }

    @ViewBuilder
    private func marker(
        phase: AppSessionPhase,
        state: AppSessionPhaseStepState,
        emphasizeError: Bool
    ) -> some View {
        ZStack {
            Circle()
                .fill(markerFill(for: state, emphasizeError: emphasizeError))
                .frame(width: Layout.markerSize, height: Layout.markerSize)

            if state == .done {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(AppDesignSystem.stateLive)
            } else {
                Text("\(phase.stepNumber)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(
                        state == .current
                            ? Color.white
                            : Color.secondary.opacity(Layout.upcomingNumberOpacity)
                    )
            }
        }
        .accessibilityHidden(true)
    }

    private func markerFill(for state: AppSessionPhaseStepState, emphasizeError: Bool) -> Color {
        switch state {
        case .done:
            return AppDesignSystem.stateLive.opacity(Layout.doneMarkerOpacity)
        case .current:
            return emphasizeError ? AppDesignSystem.stateError : AppDesignSystem.interactionAccent
        case .upcoming:
            return AppDesignSystem.elevatedBackground
        }
    }

    private func labelColor(for state: AppSessionPhaseStepState, emphasizeError: Bool) -> Color {
        switch state {
        case .done:
            return Color.secondary
        case .current:
            return emphasizeError ? AppDesignSystem.stateError : Color.primary
        case .upcoming:
            return Color.secondary.opacity(0.55)
        }
    }

    private func stepAccessibilityLabel(
        phase: AppSessionPhase,
        state: AppSessionPhaseStepState,
        emphasizeError: Bool
    ) -> String {
        let status: String
        switch state {
        case .done:
            status = "complete"
        case .current:
            status = emphasizeError ? "current, error" : "current"
        case .upcoming:
            status = "upcoming"
        }
        return "\(phase.rawValue), \(status)"
    }
}
