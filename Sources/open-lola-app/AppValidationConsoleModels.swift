import OpenLolaCore
import SwiftUI

struct AppValidationRow: Identifiable {
    let id: String
    let title: String
    let detail: String
    let tone: Color

    @MainActor
    static func rows(
        report: NativeAppShellReport,
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController,
        surfaceProbe: NativeAppShellSurfaceProbeReport
    ) -> [AppValidationRow] {
        [
            AppValidationRow(
                id: "source-report",
                title: "Native app shell report",
                detail: report.verdict.rawValue.uppercased(),
                tone: AppConsoleStatusSnapshot.tone(for: report.verdict)
            ),
            AppValidationRow(
                id: "two-peer-plan",
                title: planValidationTitle(plan),
                detail: planValidationDetail(plan),
                tone: plan.isConfigured ? AppDesignSystem.stateConnecting : AppDesignSystem.stateWarning
            ),
            AppValidationRow(
                id: "surface-probe",
                title: "Surface probe",
                detail: surfaceProbe.verdict.rawValue.uppercased(),
                tone: AppConsoleStatusSnapshot.tone(for: surfaceProbe.verdict)
            ),
            AppValidationRow(
                id: "supervisor-report",
                title: "Supervisor report",
                detail: executionController.lastValidationExitCode.map {
                    $0 == 0 && executionController.hasValidatedRuntimeEvidence ? "validated" : "failed"
                }
                    ?? "not measured",
                tone: executionController.lastValidationExitCode.map {
                    $0 == 0 && executionController.hasValidatedRuntimeEvidence
                        ? AppDesignSystem.stateLive
                        : AppDesignSystem.stateError
                } ?? .secondary
            ),
        ]
    }

    private static func planValidationTitle(_ plan: AppOperatorPrototypePlan) -> String {
        switch plan.sessionMode {
        case .directMacPeer:
            return "Two-peer plan"
        case .windowsLoLa:
            return "Windows LoLa connector command"
        case .jackTrip, .ultraGrid:
            return "\(plan.sessionMode.displayName) app runtime"
        }
    }

    private static func planValidationDetail(_ plan: AppOperatorPrototypePlan) -> String {
        switch plan.sessionMode {
        case .directMacPeer:
            return plan.report?.verdict.rawValue.uppercased() ?? "PARTIAL: remote selection incomplete"
        case .windowsLoLa:
            return plan.windowsLoLaCommand == nil ? "PARTIAL: fields incomplete" : "PARTIAL: external endpoint required"
        case .jackTrip, .ultraGrid:
            return plan.sessionMode.unavailableAppReason ?? "PARTIAL: app runtime unavailable"
        }
    }
}

enum AppValidationPreflightVerdict: String, Equatable {
    case readyToValidate = "Ready to validate"
    case readyToStart = "Ready to start"
    case blocked = "Blocked"
    case running = "Running"
    case evidenceIncomplete = "Evidence incomplete"
}

struct AppValidationBlocker: Equatable, Identifiable {
    let id: String
    let title: String
    let remediation: String
    let targetSection: NativeAppShellSurfaceSectionID
}

struct AppAdvancedControlRecovery: Equatable {
    let fieldLabel: String
    let detail: String
    let buttonTitle: String
}

enum AppAdvancedControlRecoveryPolicy {
    static func recovery(
        for blocker: AppValidationBlocker,
        plan: AppOperatorPrototypePlan
    ) -> AppAdvancedControlRecovery? {
        guard plan.sessionMode == .directMacPeer,
              plan.controlMode == .normal,
              blocker.targetSection == .devices,
              let fieldLabel = advancedOnlyFieldLabel(in: blocker.remediation)
        else {
            return nil
        }
        return AppAdvancedControlRecovery(
            fieldLabel: fieldLabel,
            detail: "\(fieldLabel) is hidden by Normal controls. Show Advanced controls to edit it.",
            buttonTitle: "Show Advanced Controls"
        )
    }

    private static func advancedOnlyFieldLabel(in text: String) -> String? {
        let fields: [(key: String, label: String)] = [
            ("role", "Role"),
            ("localHost", "Local host"),
            ("outputPath", "Output path"),
            ("controlPort", "Control port"),
            ("remoteControlPort", "Remote control port"),
            ("audioPort", "Audio port"),
            ("videoPort", "Video port"),
            ("metricsPort", "Metrics port"),
            ("durationSeconds", "Duration"),
        ]
        return fields.first { text.contains("\"\($0.key)\"") || text.contains($0.key) }?.label
    }
}

struct AppValidationPreflightModel: Equatable {
    let verdict: AppValidationPreflightVerdict
    let detail: String
    let blockers: [AppValidationBlocker]

    @MainActor
    static func make(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController,
        surfaceProbe: NativeAppShellSurfaceProbeReport
    ) -> AppValidationPreflightModel {
        if executionController.isRunning || executionController.phase == .supervisorRunning || executionController.phase == .dryRunRunning {
            return AppValidationPreflightModel(
                verdict: .running,
                detail: "A run is active; validation waits for the report artifact.",
                blockers: [
                    AppValidationBlocker(
                        id: "running",
                        title: "Execution is still running",
                        remediation: "Stop or let the Session run complete before validating its report.",
                        targetSection: .session
                    ),
                ]
            )
        }

        var blockers: [AppValidationBlocker] = []
        if !plan.isConfigured {
            blockers.append(AppValidationBlocker(
                id: "plan",
                title: "\(plan.sessionMode.displayName) setup is incomplete",
                remediation: plan.validationError ?? "Complete device inventory and routing fields.",
                targetSection: plan.sessionMode == .directMacPeer ? .devices : .routing
            ))
        }
        if surfaceProbe.verdict == .fail {
            blockers.append(AppValidationBlocker(
                id: "surface",
                title: "Surface probe failed",
                remediation: "Re-run the app launch verifier and inspect launch logs.",
                targetSection: .diagnostics
            ))
        }
        if !blockers.isEmpty {
            return AppValidationPreflightModel(
                verdict: .blocked,
                detail: "Resolve the listed setup or validation blockers before validating or starting.",
                blockers: blockers
            )
        }
        if executionController.lastValidationExitCode == 0 {
            guard !executionController.hasValidatedRuntimeEvidence else {
                return AppValidationPreflightModel(
                    verdict: .readyToStart,
                    detail: "Current runtime evidence is validated. Arm in Session, then Start.",
                    blockers: []
                )
            }
            return AppValidationPreflightModel(
                verdict: .evidenceIncomplete,
                detail: "Validation ran, but current evidence is missing, stale, or only PARTIAL.",
                blockers: [
                    AppValidationBlocker(
                        id: "evidence",
                        title: "Runtime evidence is incomplete",
                        remediation: "Produce or load a current PASS supervisor or external connector report, then validate again.",
                        targetSection: .session
                    ),
                ]
            )
        }
        if executionController.lastValidationResult == .failed {
            blockers.append(AppValidationBlocker(
                id: "last-error",
                title: "Last validation failed",
                remediation: executionController.lastError ?? "Run validation again and resolve any reported diagnostics before starting.",
                targetSection: .diagnostics
            ))
        }
        if !blockers.isEmpty {
            return AppValidationPreflightModel(
                verdict: .blocked,
                detail: "Resolve the listed setup or validation blockers before validating or starting.",
                blockers: blockers
            )
        }
        if let blocker = validationReadinessBlocker(appValidationReadiness(plan: plan, executionController: executionController)) {
            return AppValidationPreflightModel(
                verdict: .blocked,
                detail: "Resolve the listed report blocker before validating or starting.",
                blockers: [blocker]
            )
        }
        return AppValidationPreflightModel(
            verdict: .readyToValidate,
            detail: "Current report artifact is ready for validation. Run Validate before Start can enable.",
            blockers: []
        )
    }

    private static func validationReadinessBlocker(_ readiness: AppValidationReadiness) -> AppValidationBlocker? {
        guard !readiness.isReady else {
            return nil
        }
        return AppValidationBlocker(
            id: "report-readiness",
            title: "Current report is not ready for validation",
            remediation: readiness.unavailableMessage ?? "Run or load a current report before validating.",
            targetSection: .validation
        )
    }
}

@MainActor
func appValidationReadiness(
    plan: AppOperatorPrototypePlan,
    executionController: AppExecutionController
) -> AppValidationReadiness {
    switch plan.sessionMode.appExecutionRoute {
    case .directMacPeer:
        return executionController.validationReadiness(.directMacPeer, reportPath: executionController.settings.supervisorReportPath)
    case .windowsLoLa:
        return executionController.validationReadiness(.windowsLoLa, reportPath: plan.windowsLoLaFields.outputPath)
    case .unsupportedExternalConnector(let reason):
        return .unsupported(reason)
    }
}
