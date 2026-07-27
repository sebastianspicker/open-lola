// Verifies that app console status separates source checks from runtime evidence.
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appConsoleStatusSeparatesSourceChecksFromRuntimeEvidence() {
    let sourceReport = NativeAppShellSyntheticSmoke.run()
    let configuredPlan = AppOperatorPrototypePlan.make(
        operatorSurface: appOperatorState(remoteSelectionComplete: true)
    )

    let sourceSnapshot = AppConsoleStatusSnapshot.make(
        report: sourceReport,
        plan: configuredPlan,
        executionController: AppExecutionController(),
        captureReport: nil
    )
    #expect(sourceSnapshot.verdictTitle == "Source checks · Partial")
    #expect(sourceSnapshot.validationTitle == "Source checks · Partial")

    let incompleteController = AppExecutionController()
    incompleteController.lastValidationExitCode = 0
    incompleteController.lastError = "Validated supervisor report missing or unreadable: malformed.json"
    let incompleteSnapshot = AppConsoleStatusSnapshot.make(
        report: sourceReport,
        plan: configuredPlan,
        executionController: incompleteController,
        captureReport: nil
    )
    #expect(incompleteSnapshot.validationTitle == "Measured report · Incomplete")

    let validatedController = AppExecutionController()
    validatedController.lastValidationExitCode = 0
    validatedController.lastLatencyMetrics = AppLatencyHeroMetrics.make(from: [
        appMeasuredPassDirectPeerSessionReport(id: "valid-peer-report", peerID: "peer-a")
    ])
    let validatedSnapshot = AppConsoleStatusSnapshot.make(
        report: sourceReport,
        plan: configuredPlan,
        executionController: validatedController,
        captureReport: nil
    )
    #expect(validatedSnapshot.validationTitle == "Measured report · Validated")

    let failedController = AppExecutionController()
    failedController.lastValidationExitCode = 2
    let failedSnapshot = AppConsoleStatusSnapshot.make(
        report: sourceReport,
        plan: configuredPlan,
        executionController: failedController,
        captureReport: nil
    )
    #expect(failedSnapshot.validationTitle == "Validation failed")
}
