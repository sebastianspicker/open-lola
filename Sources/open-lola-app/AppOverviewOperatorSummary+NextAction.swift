// Chooses the next operator action for the overview summary.
import OpenLolaCore

extension AppOverviewOperatorSummary {
    @MainActor
    static func nextAction(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController,
        sessionState: AppSessionState,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> AppOverviewNextAction {
        if let action = configurationAction(plan: plan) { return action }
        if let action = activeExecutionAction(
            executionController: executionController,
            sessionState: sessionState
        ) { return action }
        if let action = failureAction(
            executionController: executionController,
            sessionState: sessionState
        ) { return action }
        if let action = validationGapAction(executionController: executionController) { return action }
        if let action = validatedEvidenceAction(
            executionController: executionController,
            captureReport: captureReport
        ) { return action }

        let readiness = appValidationReadiness(plan: plan, executionController: executionController)
        if !readiness.isReady {
            return AppOverviewNextAction(
                title: "Produce current report",
                detail: readiness.unavailableMessage ?? "Run or load a current report before validating or starting.",
                targetSection: .session,
                systemImage: "doc.badge.clock"
            )
        }
        return AppOverviewNextAction(
            title: "Validate current report",
            detail: "The report artifact is current enough to validate. Run validation before Start can enable.",
            targetSection: .validation,
            systemImage: "checkmark.seal"
        )
    }
}

private extension AppOverviewOperatorSummary {
    static func configurationAction(plan: AppOperatorPrototypePlan) -> AppOverviewNextAction? {
        guard !plan.isConfigured else { return nil }
        return AppOverviewNextAction(
            title: "Configure devices",
            detail: "Import or select local and remote media inventory before arming a run.",
            targetSection: .devices,
            systemImage: "slider.horizontal.below.rectangle"
        )
    }

    @MainActor
    static func activeExecutionAction(
        executionController: AppExecutionController,
        sessionState: AppSessionState
    ) -> AppOverviewNextAction? {
        guard executionController.isRunning
            || sessionState == .supervisorRunning
            || sessionState == .dryRunRunning else {
            return nil
        }
        return AppOverviewNextAction(
            title: "Monitor the run",
            detail: "Execution is active. Watch session state and logs before validating evidence.",
            targetSection: .session,
            systemImage: "dot.radiowaves.left.and.right"
        )
    }

    @MainActor
    static func failureAction(
        executionController: AppExecutionController,
        sessionState: AppSessionState
    ) -> AppOverviewNextAction? {
        guard sessionState == .error
            || executionController.phase == .failedToStart
            || executionController.phase == .runFailed else {
            return nil
        }
        return AppOverviewNextAction(
            title: "Inspect the failure",
            detail: executionController.lastError ?? "The last execution did not complete successfully.",
            targetSection: .diagnostics,
            systemImage: "exclamationmark.triangle"
        )
    }

    @MainActor
    static func validationGapAction(executionController: AppExecutionController) -> AppOverviewNextAction? {
        guard executionController.lastValidationExitCode == 0, !executionController.hasValidatedRuntimeEvidence else {
            return nil
        }
        return AppOverviewNextAction(
            title: "Resolve evidence gap",
            detail: "The validator exited cleanly, but current runtime evidence is incomplete.",
            targetSection: .validation,
            systemImage: "clock.badge.exclamationmark"
        )
    }

    @MainActor
    static func validatedEvidenceAction(
        executionController: AppExecutionController,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> AppOverviewNextAction? {
        guard executionController.hasValidatedRuntimeEvidence else { return nil }
        guard !executionController.armedForExecution else {
            return AppOverviewNextAction(
                title: "Start armed supervisor",
                detail: "Current runtime evidence is validated and execution is armed.",
                targetSection: .session,
                systemImage: "play.fill"
            )
        }
        return unarmedValidatedEvidenceAction(captureReport: captureReport)
    }

    static func unarmedValidatedEvidenceAction(
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> AppOverviewNextAction {
        AppOverviewNextAction(
            title: captureReport == nil ? "Arm for Start" : "Inspect packet evidence",
            detail: captureReport == nil
                ? "Runtime evidence is validated. Arm in Session before starting."
                : "Decoded packet evidence is available for stream inspection.",
            targetSection: captureReport == nil ? .session : .packetMonitor,
            systemImage: captureReport == nil ? "checkmark.shield" : "tablecells"
        )
    }
}
