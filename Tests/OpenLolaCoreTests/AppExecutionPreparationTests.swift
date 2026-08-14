// Verifies execution preparation preserves plan-bound preflight evidence until the plan changes.
import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appPreparationPreservesBoundPlanAndRejectsOldPreflightAfterSemanticChange() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-execution-preparation-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    var settings = NativeAppShellExecutionSettings()
    settings.planPath = directory.appendingPathComponent("plan.json").path
    let controller = AppExecutionController(settings: settings)
    var surface = executionPreparationSurface()

    #expect(controller.prepareExecution(from: surface))
    let firstPlan = try DirectPeerTwoPeerRunPlanReport.readValidated(fromPath: settings.planPath)
    let firstBinding = try DirectPeerTwoPeerPreflightBinding.make(for: firstPlan)
    let preflight = try preparedPreflight(for: firstBinding, capturedAt: firstPlan.capturedAt)

    try DirectPeerTwoPeerPreflightBindingValidator.validate(
        report: preflight,
        for: firstPlan
    )
    #expect(controller.prepareExecution(from: surface))

    let preservedPlan = try DirectPeerTwoPeerRunPlanReport.readValidated(fromPath: settings.planPath)
    #expect(preservedPlan.capturedAt == firstPlan.capturedAt)
    #expect(
        DirectPeerTwoPeerPreflightBinding.fingerprint(for: preservedPlan)
            == firstBinding.planFingerprint
    )
    try DirectPeerTwoPeerPreflightBindingValidator.validate(
        report: preflight,
        for: preservedPlan
    )

    surface.directPeerCommandFields.remoteHost = "192.0.2.21"
    #expect(controller.prepareExecution(from: surface))

    let changedPlan = try DirectPeerTwoPeerRunPlanReport.readValidated(fromPath: settings.planPath)
    #expect(
        DirectPeerTwoPeerPreflightBinding.fingerprint(for: changedPlan)
            != firstBinding.planFingerprint
    )
    #expect(throws: DirectPeerTwoPeerPreflightBindingError.planFingerprintMismatch) {
        try DirectPeerTwoPeerPreflightBindingValidator.validate(
            report: preflight,
            for: changedPlan
        )
    }
}

private func preparedPreflight(
    for binding: DirectPeerTwoPeerPreflightBinding,
    capturedAt: String
) throws -> MacToMacConnectionEstablishmentReport {
    var report = try MacToMacConnectionEstablishmentRunner.makeReport(
        configuration: .init(
            localPeerID: binding.localPeerID,
            remotePeerID: binding.remotePeerID,
            peer: "192.0.2.20",
            outputPath: "/tmp/open-lola-app-execution-preparation-preflight.json"
        ),
        diagnostics: NetworkDiagnosticsSyntheticSmoke.run(),
        natRoute: nil
    )
    report.capturedAt = capturedAt
    report.planFingerprint = binding.planFingerprint
    report.planCapturedAt = binding.planCapturedAt
    return report
}

private func executionPreparationSurface() -> NativeAppShellOperatorPrototypeState {
    NativeAppShellOperatorPrototypeState(
        workflow: .init(
            commandIntent: .idle,
            remoteOrchestrationEnabled: false,
            startsLongRunningProcess: false
        ),
        inventories: .init(
            local: executionPreparationInventory(
                hostName: "mac-a",
                audioUID: "mac-a-audio",
                videoID: "mac-a-video"
            ),
            remote: executionPreparationInventory(
                hostName: "mac-b",
                audioUID: "mac-b-audio",
                videoID: "mac-b-video"
            )
        ),
        peerFields: .init(directPeer: .appDefault)
    )
}

private func executionPreparationInventory(
    hostName: String,
    audioUID: String,
    videoID: String
) -> NativeAppShellLocalMediaInventory {
    NativeAppShellLocalMediaInventory(
        capturedAt: "2026-08-13T00:00:00Z",
        hostName: hostName,
        audioDevices: [
            .init(
                name: "Test Audio",
                uid: audioUID,
                inputChannelCount: 64,
                outputChannelCount: 64,
                nominalSampleRateHertz: 48_000,
                currentBufferFrameSize: 32
            )
        ],
        videoDevices: [
            .init(
                label: "Test Video",
                uniqueId: videoID,
                manufacturer: "Open LoLa Tests",
                transport: "virtual",
                sourcePolicy: .blackmagicFirstAvFoundationFallback,
                formatCount: 1
            )
        ],
        selection: .init(
            audioInputUID: audioUID,
            audioOutputUID: audioUID,
            videoDeviceID: videoID
        ),
        inventoryErrors: []
    )
}
