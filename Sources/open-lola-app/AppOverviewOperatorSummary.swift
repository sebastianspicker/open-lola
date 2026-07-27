// Builds the operator overview summary, keeping status aggregation out of the root view layout.
import OpenLolaCore

struct AppOverviewOperatorSummary: Equatable {
    let statusItems: [AppOverviewStatusItem]
    let nextAction: AppOverviewNextAction
    let evidence: AppOverviewEvidenceSummary

    @MainActor
    static func make(
        report: NativeAppShellReport,
        plan: AppOperatorPrototypePlan,
        executionController: AppExecutionController,
        sessionState: AppSessionState,
        captureReport: LoLaCompatibilityCaptureReport?
    ) -> AppOverviewOperatorSummary {
        AppOverviewOperatorSummary(
            statusItems: statusItems(
                plan: plan,
                executionController: executionController,
                sessionState: sessionState,
                captureReport: captureReport
            ),
            nextAction: nextAction(
                plan: plan,
                executionController: executionController,
                sessionState: sessionState,
                captureReport: captureReport
            ),
            evidence: evidenceSummary(
                report: report,
                plan: plan,
                executionController: executionController,
                captureReport: captureReport
            )
        )
    }
}
