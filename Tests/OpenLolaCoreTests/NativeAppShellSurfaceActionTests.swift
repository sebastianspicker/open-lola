import Testing

@testable import OpenLolaCore

@Test
func nativeAppShellRunActionMustDeclareExternalRealtimeLaunchBoundary() throws {
    let contract = NativeAppShellSurfaceContract.releaseReadiness
    let unsafeRunAction = NativeAppShellSurfaceAction(
        id: "unsafe-run",
        title: "Unsafe Run",
        keyboardShortcut: nil,
        operatorCommandIntent: .runRequested,
        refreshesReportOnly: false,
        startsRealtimeAudio: false,
        startsRealtimeVideo: false,
        armsControlOutput: false,
        launchesExternalProcess: true,
        launchesExternalRealtimeProcess: false
    )
    let report = NativeAppShellSurfaceProbeReport(
        id: "unit-surface",
        title: "Unit surface",
        capturedAt: "2026-05-15T00:00:00Z",
        sourceReportId: "unit-source",
        appTargetName: contract.launchProbePlan.appTargetName,
        sections: contract.sections,
        actions: contract.actions.filter { $0.operatorCommandIntent != .runRequested } + [unsafeRunAction],
        launchProbePlan: contract.launchProbePlan,
        verdict: .partial,
        notes: "unit"
    )

    #expect(throws: NativeAppShellSurfaceValidationError.actionRunIntentWithoutExternalRealtimeMarker("unsafe-run")) {
        try report.validate()
    }
}
