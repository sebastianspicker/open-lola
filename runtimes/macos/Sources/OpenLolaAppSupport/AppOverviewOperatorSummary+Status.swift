// Aggregates overview status and evidence fields for the operator summary.
import OpenLolaCore

extension AppOverviewOperatorSummary {
    @MainActor
    static func statusItems(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController,
        sessionState: AppSessionState,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> [AppOverviewStatusItem] {
        [
            AppOverviewStatusItem(
                id: "readiness",
                title: "Readiness",
                value: plan.isConfigured ? "Configured" : "Setup required",
                systemImage: "flag"
            ),
            AppOverviewStatusItem(
                id: "session",
                title: "Session",
                value: sessionState.rawValue,
                systemImage: sessionState.systemImage
            ),
            AppOverviewStatusItem(
                id: "execution",
                title: "Session process",
                value: executionController.status,
                systemImage: "terminal"
            ),
            AppOverviewStatusItem(
                id: "validation",
                title: "Validation",
                value: validationStatus(executionController),
                systemImage: "checklist.checked"
            ),
            AppOverviewStatusItem(
                id: "packets",
                title: AppCopyVocabulary.packetEvidence,
                value: packetEvidenceStatus(captureReport),
                systemImage: "tablecells"
            )
        ]
    }

    @MainActor
    static func evidenceSummary(
        report: NativeAppShellReport,
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> AppOverviewEvidenceSummary {
        AppOverviewEvidenceSummary(
            sourceVerdict: "Source checks · \(report.verdict.rawValue.capitalized)",
            runtimeEvidence: runtimeEvidenceStatus(executionController),
            latestReportPath: latestReportPath(plan: plan, executionController: executionController),
            freshness: freshness(executionController: executionController, captureReport: captureReport)
        )
    }
}

private extension AppOverviewOperatorSummary {
    @MainActor
    static func validationStatus(_ executionController: AppExecutionController) -> String {
        guard let exitCode = executionController.lastValidationExitCode else {
            return "Not run"
        }
        if exitCode == 0, executionController.hasValidatedRuntimeEvidence {
            return "Validated"
        }
        return "Evidence incomplete"
    }

    static func packetEvidenceStatus(_ captureReport: LoLaCompatibilityCaptureReport?) -> String {
        guard let captureReport else {
            return "Missing"
        }
        return "\(max(0, captureReport.summary.packetCount)) decoded"
    }

    @MainActor
    static func runtimeEvidenceStatus(_ executionController: AppExecutionController) -> String {
        if executionController.hasValidatedRuntimeEvidence {
            return "Measured report · Validated"
        }
        if executionController.lastLatencyMetrics != nil || executionController.lastExternalConnectorReport != nil {
            return "Measured report · Incomplete"
        }
        return "Not measured"
    }

    @MainActor
    static func latestReportPath(
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController
    ) -> String {
        if plan.sessionMode == .windowsLoLa {
            return plan.windowsLoLaFields.outputPath
        }
        if plan.sessionMode.externalConnectorKind != nil {
            return plan.externalConnectorFields.outputPath
        }
        return executionController.settings.supervisorReportPath
    }

    @MainActor
    static func freshness(
        executionController: AppExecutionController,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> String {
        if executionController.isRunning {
            return "Run in progress · not yet validated"
        }
        if executionController.lastValidationExitCode != nil {
            return "Latest completed report"
        }
        if captureReport != nil {
            return "Loaded packet artifact"
        }
        return "Source checks only"
    }
}
