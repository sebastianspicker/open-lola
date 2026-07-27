// Renders AppSessionEvidenceChain in the operator interface, keeping SwiftUI presentation distinct from execution and persistence state.
import SwiftUI

// MARK: - Model

/// Visual tone for an evidence-chain stage (Proven Color Rule: green only when validated).
enum AppSessionEvidenceChainTone: Equatable {
    case source, planned, observed, validated, neutral

    var color: Color {
        switch self {
        case .source, .neutral: Color.secondary
        case .planned: AppDesignSystem.interactionAccent
        case .observed: AppDesignSystem.stateWarning
        case .validated: AppDesignSystem.stateLive
        }
    }
}

/// One stage in the horizontal Source → Planned → Observed → Validated chain.
struct AppSessionEvidenceChainStage: Identifiable, Equatable {
    var id: String
    var title: String
    var state: String
    var note: String
    var tone: AppSessionEvidenceChainTone
    /// When true and tone is `.validated`, card uses a green border (earned validation only).
    var isPassed: Bool = false
}

// MARK: - Policy (testable)

/// Builds evidence-chain stages from simple execution-like inputs (no heavy imports).
enum AppSessionEvidenceChainPolicy {
    // swiftlint:disable:next function_parameter_count
    static func stages(
        readinessConfigured: Bool,
        sessionState: AppSessionState,
        hasValidatedRuntimeEvidence: Bool,
        lastExitCode: Int?,
        lastValidationExitCode: Int?,
        isRunning: Bool,
        packetEvidenceAvailable: Bool,
        sourceState: String = "Capability",
        sourceNote: String = "Inventory & capability checks. Not a media measurement.",
        plannedRouteNote: String = "Route and profile selected for the next run."
    ) -> [AppSessionEvidenceChainStage] {
        [
            make("source", "Source", sourceState, sourceNote, .source),
            planned(configured: readinessConfigured, routeNote: plannedRouteNote),
            observed(
                sessionState: sessionState,
                isRunning: isRunning,
                lastExitCode: lastExitCode,
                hasValidated: hasValidatedRuntimeEvidence
            ),
            validated(
                hasValidated: hasValidatedRuntimeEvidence,
                lastValidationExitCode: lastValidationExitCode,
                sessionState: sessionState,
                packetEvidenceAvailable: packetEvidenceAvailable
            )
        ]
    }

    private static func make(
        _ id: String,
        _ title: String,
        _ state: String,
        _ note: String,
        _ tone: AppSessionEvidenceChainTone,
        isPassed: Bool = false
    ) -> AppSessionEvidenceChainStage {
        .init(id: id, title: title, state: state, note: note, tone: tone, isPassed: isPassed)
    }

    private static func planned(configured: Bool, routeNote: String) -> AppSessionEvidenceChainStage {
        configured
            ? make("planned", "Planned", "Configured", routeNote, .planned)
            : make("planned", "Planned", "Setup required", "Select peers, devices, and profile before arming.", .neutral)
    }

    private static func observed(
        sessionState: AppSessionState,
        isRunning: Bool,
        lastExitCode: Int?,
        hasValidated: Bool
    ) -> AppSessionEvidenceChainStage {
        let active: Set<AppSessionState> = [.connecting, .supervisorRunning, .dryRunRunning, .validating]
        if isRunning || active.contains(sessionState) {
            return make("observed", "Observed", "Running", "Session process active. Local meters remain preview-only.", .observed)
        }
        if sessionState == .error {
            return make("observed", "Observed", "Failed", "Last run did not complete successfully.", .observed)
        }
        let recorded: Set<AppSessionState> = [.awaitingEvidence, .validated, .receiverWarning]
        if lastExitCode != nil || recorded.contains(sessionState) || hasValidated {
            return make("observed", "Observed", "Recorded run", "Supervisor report loaded. Not live telemetry.", .observed)
        }
        return make("observed", "Observed", "Not measured", "No completed runtime report is loaded yet.", .neutral)
    }

    private static func validated(
        hasValidated: Bool,
        lastValidationExitCode: Int?,
        sessionState: AppSessionState,
        packetEvidenceAvailable: Bool
    ) -> AppSessionEvidenceChainStage {
        if hasValidated {
            let note = packetEvidenceAvailable
                ? "Schema + useful-media policy. Packet evidence available."
                : "Schema + useful-media policy passed."
            return make("validated", "Validated", "Passed", note, .validated, isPassed: true)
        }
        if let exit = lastValidationExitCode {
            return exit == 0
                ? make("validated", "Validated", "Incomplete", "Validator exited cleanly, but runtime evidence is incomplete.", .observed)
                : make("validated", "Validated", "Failed", "Latest report did not pass structural validation.", .neutral)
        }
        if sessionState == .awaitingEvidence {
            return make("validated", "Validated", "Awaiting", "Run finished; validate the measured report to earn green.", .observed)
        }
        return make("validated", "Validated", "Not validated", "Green is earned only by current validated evidence.", .neutral)
    }
}

// MARK: - View

/// Horizontal evidence chain: Source → Planned → Observed → Validated.
struct AppSessionEvidenceChain: View {
    let stages: [AppSessionEvidenceChainStage]

    private enum Layout {
        static let corner: CGFloat = 8
        static let cardMinHeight: CGFloat = 54
        static let cardPadX: CGFloat = 10
        static let dot: CGFloat = 10
        static let softRing: CGFloat = 16
        static let connectorH: CGFloat = 2
        static let softRingOpacity = 0.2
        static let passedBorderOpacity = 0.22
        static let passedFillOpacity = 0.06
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Label("Evidence chain", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                    stageColumn(stage, drawsConnector: index < stages.count - 1)
                }
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppDesignSystem.panelBackground, in: RoundedRectangle(cornerRadius: Layout.corner))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.corner).stroke(AppDesignSystem.panelBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Evidence chain")
    }

    private func stageColumn(_ stage: AppSessionEvidenceChainStage, drawsConnector: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            stageHeader(stage, drawsConnector: drawsConnector)
            stageCard(stage)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stage.title): \(stage.state). \(stage.note)")
    }

    private func stageHeader(_ stage: AppSessionEvidenceChainStage, drawsConnector: Bool) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(stage.tone.color.opacity(Layout.softRingOpacity))
                    .frame(width: Layout.softRing, height: Layout.softRing)
                Circle()
                    .fill(stage.tone.color)
                    .frame(width: Layout.dot, height: Layout.dot)
            }
            .accessibilityHidden(true)
            Text(stage.title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.3)
                .lineLimit(1)
            if drawsConnector {
                Rectangle()
                    .fill(AppDesignSystem.panelBorder)
                    .frame(height: Layout.connectorH)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private func stageCard(_ stage: AppSessionEvidenceChainStage) -> some View {
        let passed = stage.isPassed && stage.tone == .validated
        return VStack(alignment: .leading, spacing: 2) {
            Text(stage.state)
                .font(.caption.weight(.semibold))
                .foregroundStyle(passed ? AppDesignSystem.stateLive : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(stage.note)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Layout.cardPadX)
        .padding(.vertical, AppSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: Layout.cardMinHeight, alignment: .topLeading)
        .background(
            passed
                ? AppDesignSystem.stateLive.opacity(Layout.passedFillOpacity)
                : AppDesignSystem.elevatedBackground,
            in: RoundedRectangle(cornerRadius: Layout.corner)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Layout.corner)
                .stroke(
                    passed
                        ? AppDesignSystem.stateLive.opacity(Layout.passedBorderOpacity)
                        : AppDesignSystem.panelBorder,
                    lineWidth: 1
                )
        }
    }
}
