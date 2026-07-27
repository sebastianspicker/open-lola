// Verifies that native app shell run actions declare the external real-time launch boundary.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func nativeAppShellSurfaceActionStillEncodesItsFlatJSONFields() throws {
    let action = NativeAppShellSurfaceAction(
        identity: .init(id: "flat-contract", title: "Flat Contract", keyboardShortcut: nil),
        effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false),
        execution: .init(launchesExternalProcess: true)
    )
    let data = try JSONEncoder().encode(action)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(object?["launchesExternalProcess"] as? Bool == true)
    #expect(object?["armsControlOutput"] as? Bool == false)
    #expect(try JSONDecoder().decode(NativeAppShellSurfaceAction.self, from: data) == action)
}

@Test
func nativeAppShellRunActionMustDeclareExternalRealtimeLaunchBoundary() throws {
    let contract = NativeAppShellSurfaceContract.releaseReadiness
    let unsafeRunAction = NativeAppShellSurfaceAction(
        identity: .init(id: "unsafe-run", title: "Unsafe Run", keyboardShortcut: nil, operatorCommandIntent: .runRequested),
        effects: .init(refreshesReportOnly: false, startsRealtimeAudio: false, startsRealtimeVideo: false, armsControlOutput: false),
        execution: .init(launchesExternalProcess: true, launchesExternalRealtimeProcess: false)
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
