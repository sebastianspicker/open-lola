import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appExecutionValidationRequiresCompleteCurrentReportEvidence() throws {
    let missingSupervisorPath = "/private/tmp/open-lola-missing-supervisor-\(UUID().uuidString).json"
    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = missingSupervisorPath
    let controller = AppExecutionController(settings: settings)
    controller.lastLatencyMetrics = AppLatencyHeroMetrics.make(from: [
        appDirectPeerSessionReport(
            id: "stale-peer-report",
            packetsReceived: 1,
            packetsLost: 0,
            jitterMicroseconds: 1,
            latencyMicroseconds: 1
        ),
    ])

    controller.finishValidation(exitCode: 0)

    #expect(controller.phase == .validationFailed)
    #expect(controller.status == "Validation evidence incomplete.")
    #expect(!controller.hasValidatedRuntimeEvidence)
    #expect(controller.lastLatencyMetrics == nil)
    #expect(controller.lastError?.contains("Validated supervisor report missing or unreadable") == true)

    var state = appOperatorState(remoteSelectionComplete: false)
    state.sessionMode = .windowsLoLa
    state.windowsLoLaPeerFields.outputPath = "/private/tmp/open-lola-missing-windows-lola-\(UUID().uuidString).json"
    let windowsController = AppExecutionController()

    _ = try windowsController.prepareValidationContext(operatorSurface: state)
    windowsController.finishValidation(exitCode: 0)

    #expect(windowsController.phase == .validationFailed)
    #expect(windowsController.status == "Validation evidence incomplete.")
    #expect(!windowsController.hasValidatedRuntimeEvidence)
    #expect(windowsController.lastExternalConnectorReport == nil)
    #expect(windowsController.lastError?.contains("Validated external connector report missing or unreadable") == true)

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-validation-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let malformedSupervisorURL = directory.appendingPathComponent("supervisor-malformed.json")
    try Data("{".utf8).write(to: malformedSupervisorURL)
    var malformedSupervisorSettings = NativeAppShellExecutionSettings()
    malformedSupervisorSettings.supervisorReportPath = malformedSupervisorURL.path
    let malformedSupervisorController = AppExecutionController(settings: malformedSupervisorSettings)

    malformedSupervisorController.finishValidation(exitCode: 0)

    #expect(malformedSupervisorController.phase == .validationFailed)
    #expect(malformedSupervisorController.status == "Validation evidence incomplete.")
    #expect(!malformedSupervisorController.hasValidatedRuntimeEvidence)
    #expect(malformedSupervisorController.lastLatencyMetrics == nil)
    #expect(malformedSupervisorController.lastError?.contains("Validated supervisor report missing or unreadable") == true)

    let malformedWindowsReportURL = directory.appendingPathComponent("windows-malformed.json")
    try Data("{".utf8).write(to: malformedWindowsReportURL)
    state.windowsLoLaPeerFields.outputPath = malformedWindowsReportURL.path
    let malformedWindowsController = AppExecutionController()

    _ = try malformedWindowsController.prepareValidationContext(operatorSurface: state)
    malformedWindowsController.finishValidation(exitCode: 0)

    #expect(malformedWindowsController.phase == .validationFailed)
    #expect(malformedWindowsController.status == "Validation evidence incomplete.")
    #expect(!malformedWindowsController.hasValidatedRuntimeEvidence)
    #expect(malformedWindowsController.lastExternalConnectorReport == nil)
    #expect(malformedWindowsController.lastError?.contains("Validated external connector report missing or unreadable") == true)
    #expect(malformedWindowsController.errorLog.contains { $0.contains("External connector report unavailable") })

    let partialWindowsReportURL = directory.appendingPathComponent("windows-partial.json")
    try appExternalConnectorSessionReport(verdict: .partial, outputPath: partialWindowsReportURL.path)
        .prettyJSONData()
        .write(to: partialWindowsReportURL)
    state.windowsLoLaPeerFields.outputPath = partialWindowsReportURL.path
    let partialWindowsController = AppExecutionController()

    _ = try partialWindowsController.prepareValidationContext(operatorSurface: state)
    partialWindowsController.finishValidation(exitCode: 0)

    #expect(partialWindowsController.phase == .validationFailed)
    #expect(partialWindowsController.status == "Validation evidence incomplete.")
    #expect(partialWindowsController.lastValidationResult == .failed)
    #expect(partialWindowsController.lastValidationSummary.contains("FAILED"))
    #expect(!partialWindowsController.hasValidatedRuntimeEvidence)
    #expect(partialWindowsController.lastExternalConnectorReport?.verdict == .partial)
    #expect(partialWindowsController.lastError == "External connector evidence incomplete: no runtime error recorded; verdict partial still requires measured evidence")
    let failedWindowsReportURL = directory.appendingPathComponent("windows-fail.json")
    try appExternalConnectorSessionReport(verdict: .fail, outputPath: failedWindowsReportURL.path)
        .prettyJSONData()
        .write(to: failedWindowsReportURL)
    state.windowsLoLaPeerFields.outputPath = failedWindowsReportURL.path
    let failedWindowsController = AppExecutionController()

    _ = try failedWindowsController.prepareValidationContext(operatorSurface: state)
    failedWindowsController.finishValidation(exitCode: 0)

    #expect(failedWindowsController.phase == .validationFailed)
    #expect(failedWindowsController.status == "Validation evidence incomplete.")
    #expect(!failedWindowsController.hasValidatedRuntimeEvidence)
    #expect(failedWindowsController.lastExternalConnectorReport?.verdict == .fail)
    #expect(failedWindowsController.lastError == "External connector evidence incomplete: runtime error recorded; verdict fail")

    let falsePassWindowsReportURL = directory.appendingPathComponent("windows-pass.json")
    try appExternalConnectorSessionReport(verdict: .pass, outputPath: falsePassWindowsReportURL.path)
        .prettyJSONData()
        .write(to: falsePassWindowsReportURL)
    state.windowsLoLaPeerFields.outputPath = falsePassWindowsReportURL.path
    let falsePassWindowsController = AppExecutionController()

    _ = try falsePassWindowsController.prepareValidationContext(operatorSurface: state)
    falsePassWindowsController.finishValidation(exitCode: 0)

    #expect(falsePassWindowsController.phase == .validationFailed)
    #expect(falsePassWindowsController.status == "Validation evidence incomplete.")
    #expect(falsePassWindowsController.lastValidationResult == .failed)
    #expect(falsePassWindowsController.lastValidationSummary.contains("FAILED"))
    #expect(!falsePassWindowsController.hasValidatedRuntimeEvidence)
    #expect(falsePassWindowsController.lastExternalConnectorReport == nil)
    #expect(falsePassWindowsController.lastError?.contains(
        "Validated external connector report missing or unreadable"
    ) == true)

    let reportAURL = directory.appendingPathComponent("peer-a.json")
    let reportBURL = directory.appendingPathComponent("peer-b.json")
    let passReportAURL = directory.appendingPathComponent("peer-a-pass.json")
    let passReportBURL = directory.appendingPathComponent("peer-b-pass.json")
    let partialSupervisorURL = directory.appendingPathComponent("supervisor-partial.json")
    let failedSupervisorURL = directory.appendingPathComponent("supervisor-fail.json")
    let passSupervisorURL = directory.appendingPathComponent("supervisor-pass.json")
    try appDirectPeerSessionReport(
        id: "peer-a-report",
        packetsReceived: 90,
        packetsLost: 0,
        jitterMicroseconds: 2_500,
        latencyMicroseconds: 1_200
    ).prettyJSONData().write(to: reportAURL)
    try appDirectPeerSessionReport(
        id: "peer-b-report",
        packetsReceived: 90,
        packetsLost: 0,
        jitterMicroseconds: 2_500,
        latencyMicroseconds: 1_200
    ).prettyJSONData().write(to: reportBURL)
    let processResults = [
        appProcessResult(peerID: "peer-a", reportPath: reportAURL.path),
        appProcessResult(peerID: "peer-b", reportPath: reportBURL.path),
    ]
    let preflightChecks = [
        DirectPeerTwoPeerPreflightCheck(id: "unit", severity: .pass, passed: true, message: "ok"),
    ]
    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: processResults,
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .partial,
        notes: "unit test supervisor report"
    ).prettyJSONData().write(to: partialSupervisorURL)

    var partialSettings = NativeAppShellExecutionSettings()
    partialSettings.supervisorReportPath = partialSupervisorURL.path
    let partialController = AppExecutionController(settings: partialSettings)

    partialController.finishValidation(exitCode: 0)

    #expect(partialController.phase == .validationFailed)
    #expect(partialController.status == "Validation evidence incomplete.")
    #expect(!partialController.hasValidatedRuntimeEvidence)
    #expect(partialController.lastLatencyMetrics?.isPartial == true)
    #expect(partialController.lastLatencyMetrics?.supervisorVerdict == .partial)
    #expect(partialController.lastReport?.verdict == .partial)
    #expect(partialController.lastError?.contains("supervisor verdict partial") == true)

    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: processResults,
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .fail,
        notes: "unit test supervisor report"
    ).prettyJSONData().write(to: failedSupervisorURL)

    var failedSupervisorSettings = NativeAppShellExecutionSettings()
    failedSupervisorSettings.supervisorReportPath = failedSupervisorURL.path
    let failedSupervisorController = AppExecutionController(settings: failedSupervisorSettings)

    failedSupervisorController.finishValidation(exitCode: 0)

    #expect(failedSupervisorController.phase == .validationFailed)
    #expect(failedSupervisorController.status == "Validation evidence incomplete.")
    #expect(!failedSupervisorController.hasValidatedRuntimeEvidence)
    #expect(failedSupervisorController.lastLatencyMetrics?.isPartial == true)
    #expect(failedSupervisorController.lastLatencyMetrics?.supervisorVerdict == .fail)
    #expect(failedSupervisorController.lastReport?.verdict == .fail)
    #expect(failedSupervisorController.lastError?.contains("supervisor verdict fail") == true)

    try appMeasuredPassDirectPeerSessionReport(id: "peer-a-pass-report", peerID: "peer-a")
        .prettyJSONData()
        .write(to: passReportAURL)
    try appMeasuredPassDirectPeerSessionReport(id: "peer-b-pass-report", peerID: "peer-b")
        .prettyJSONData()
        .write(to: passReportBURL)
    let passProcessResults = [
        appProcessResult(
            peerID: "peer-a",
            reportPath: passReportAURL.path,
            receiveProofPath: directory.appendingPathComponent("peer-a-rx-proof.json").path
        ),
        appProcessResult(
            peerID: "peer-b",
            reportPath: passReportBURL.path,
            receiveProofPath: directory.appendingPathComponent("peer-b-rx-proof.json").path
        ),
    ]

    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: passProcessResults,
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        aggregateReportPath: directory.appendingPathComponent("aggregate.json").path,
        aggregateExecuted: true,
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .pass,
        notes: "unit test supervisor report"
    ).prettyJSONData().write(to: passSupervisorURL)

    var passingSettings = NativeAppShellExecutionSettings()
    passingSettings.supervisorReportPath = passSupervisorURL.path
    let nonzeroValidationController = AppExecutionController(settings: passingSettings)

    nonzeroValidationController.finishValidation(exitCode: 1)

    #expect(nonzeroValidationController.phase == .validationFailed)
    #expect(nonzeroValidationController.status == "Validation failed.")
    #expect(!nonzeroValidationController.hasValidatedRuntimeEvidence)
    #expect(nonzeroValidationController.lastLatencyMetrics == nil)
    #expect(nonzeroValidationController.lastReport?.verdict == .partial)

    let passingController = AppExecutionController(settings: passingSettings)

    passingController.finishValidation(exitCode: 0)

    #expect(passingController.phase == .validationPassed)
    #expect(passingController.status == "Validation passed.")
    #expect(passingController.hasValidatedRuntimeEvidence)
    #expect(passingController.lastLatencyMetrics?.isPartial == false)
    #expect(passingController.lastReport?.verdict == .pass)
    #expect(passingController.lastReport?.notes.contains("Real-world PASS remains gated") == true)
}

@MainActor
@Test
func appExecutionValidationRejectsInvalidDirectPeerPassReportGraph() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-invalid-pass-graph-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let passAURL = directory.appendingPathComponent("peer-a-pass.json")
    let passBURL = directory.appendingPathComponent("peer-b-pass.json")
    let partialBURL = directory.appendingPathComponent("peer-b-partial.json")
    let invalidBURL = directory.appendingPathComponent("peer-b-invalid.json")
    try appMeasuredPassDirectPeerSessionReport(id: "peer-a-pass", peerID: "peer-a")
        .prettyJSONData()
        .write(to: passAURL)
    try appMeasuredPassDirectPeerSessionReport(id: "peer-b-pass", peerID: "peer-b")
        .prettyJSONData()
        .write(to: passBURL)
    try appDirectPeerSessionReport(
        id: "peer-b-partial",
        packetsReceived: 90,
        packetsLost: 0,
        jitterMicroseconds: 2_500,
        latencyMicroseconds: 1_200
    ).prettyJSONData().write(to: partialBURL)
    var invalidChild = appMeasuredPassDirectPeerSessionReport(id: "peer-b-invalid", peerID: "peer-b")
    invalidChild.metrics.packetsReceived = -1
    try invalidChild.prettyJSONData().write(to: invalidBURL)

    let validProcessResults = [
        appProcessResult(
            peerID: "peer-a",
            reportPath: passAURL.path,
            receiveProofPath: directory.appendingPathComponent("peer-a-rx-proof.json").path
        ),
        appProcessResult(
            peerID: "peer-b",
            reportPath: passBURL.path,
            receiveProofPath: directory.appendingPathComponent("peer-b-rx-proof.json").path
        ),
    ]
    let preflightChecks = [
        DirectPeerTwoPeerPreflightCheck(id: "unit", severity: .pass, passed: true, message: "ok"),
    ]

    let invalidSupervisorURL = directory.appendingPathComponent("supervisor-invalid-pass.json")
    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor-invalid-pass",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: validProcessResults,
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .pass,
        notes: "unit test invalid pass supervisor"
    ).prettyJSONData().write(to: invalidSupervisorURL)

    let invalidSupervisorController = AppExecutionController(settings: {
        var settings = NativeAppShellExecutionSettings()
        settings.supervisorReportPath = invalidSupervisorURL.path
        return settings
    }())
    invalidSupervisorController.finishValidation(exitCode: 0)

    #expect(invalidSupervisorController.phase == .validationFailed)
    #expect(!invalidSupervisorController.hasValidatedRuntimeEvidence)
    #expect(invalidSupervisorController.lastLatencyMetrics == nil)
    #expect(invalidSupervisorController.lastError?.contains("Validated supervisor report missing or unreadable") == true)

    let partialChildSupervisorURL = directory.appendingPathComponent("supervisor-partial-child.json")
    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor-partial-child",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: [
            validProcessResults[0],
            appProcessResult(
                peerID: "peer-b",
                reportPath: partialBURL.path,
                receiveProofPath: directory.appendingPathComponent("peer-b-partial-rx-proof.json").path
            ),
        ],
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        aggregateReportPath: directory.appendingPathComponent("aggregate-partial-child.json").path,
        aggregateExecuted: true,
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .pass,
        notes: "unit test partial child supervisor"
    ).prettyJSONData().write(to: partialChildSupervisorURL)

    var partialChildSettings = NativeAppShellExecutionSettings()
    partialChildSettings.supervisorReportPath = partialChildSupervisorURL.path
    let partialChildController = AppExecutionController(settings: partialChildSettings)
    partialChildController.finishValidation(exitCode: 0)

    #expect(partialChildController.phase == .validationFailed)
    #expect(!partialChildController.hasValidatedRuntimeEvidence)
    #expect(partialChildController.lastLatencyMetrics?.peerReportFailures.contains {
        $0.contains("peer-b-partial") && $0.contains("partial")
    } == true)
    #expect(partialChildController.lastError?.contains("peer report verdict partial") == true)

    let invalidChildSupervisorURL = directory.appendingPathComponent("supervisor-invalid-child.json")
    try DirectPeerTwoPeerLocalRunReport(
        id: "supervisor-invalid-child",
        capturedAt: "2026-05-15T00:00:00Z",
        planID: "plan",
        runDirectory: directory.path,
        executed: true,
        processResults: [
            validProcessResults[0],
            appProcessResult(
                peerID: "peer-b",
                reportPath: invalidBURL.path,
                receiveProofPath: directory.appendingPathComponent("peer-b-invalid-rx-proof.json").path
            ),
        ],
        aggregateCommand: ["open-lola", "direct-p2p-two-peer-local-run"],
        aggregateReportPath: directory.appendingPathComponent("aggregate-invalid-child.json").path,
        aggregateExecuted: true,
        preflightChecks: preflightChecks,
        evidenceGates: ["unit"],
        verdict: .pass,
        notes: "unit test invalid child supervisor"
    ).prettyJSONData().write(to: invalidChildSupervisorURL)

    var invalidChildSettings = NativeAppShellExecutionSettings()
    invalidChildSettings.supervisorReportPath = invalidChildSupervisorURL.path
    let invalidChildController = AppExecutionController(settings: invalidChildSettings)
    invalidChildController.finishValidation(exitCode: 0)

    #expect(invalidChildController.phase == .validationFailed)
    #expect(!invalidChildController.hasValidatedRuntimeEvidence)
    #expect(invalidChildController.lastLatencyMetrics?.loadFailures.contains {
        $0.contains("peer-b") && $0.contains("negativeMetric")
    } == true)
    #expect(invalidChildController.lastError?.contains("peer-b") == true)
}
