import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appValidationReadinessRequiresCurrentSessionToken() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-session-token-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let reportURL = directory.appendingPathComponent("supervisor.json")
    try Data("{}".utf8).write(to: reportURL)

    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = reportURL.path
    let controller = AppExecutionController(settings: settings)
    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = "/private/tmp/open-lola"

    #expect(controller.validationReadiness(operatorSurface: surface) == .staleReport(reportURL.path))

    controller.sessionToken = "current-session"
    try AppRuntimeEvidenceScope.writeSessionToken("older-session", reportPath: reportURL.path)
    #expect(controller.validationReadiness(operatorSurface: surface) == .staleReport(reportURL.path))
    #expect(!AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
        executionKind: .directMacPeer,
        validationExitCode: 0,
        directPeerLatencyMetrics: AppLatencyHeroMetrics.make(from: [
            appMeasuredPassDirectPeerSessionReport(id: "stale-peer-report", peerID: "peer-a"),
        ]),
        externalConnectorReport: nil,
        reportPath: reportURL.path,
        currentSessionToken: controller.sessionToken
    ))

    try AppRuntimeEvidenceScope.writeSessionToken("current-session", reportPath: reportURL.path)
    try Data("{}".utf8).write(to: reportURL)
    #expect(controller.validationReadiness(operatorSurface: surface) == .ready)
    #expect(AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
        executionKind: .directMacPeer,
        validationExitCode: 0,
        directPeerLatencyMetrics: AppLatencyHeroMetrics.make(from: [
            appMeasuredPassDirectPeerSessionReport(id: "current-peer-report", peerID: "peer-a"),
        ]),
        externalConnectorReport: nil,
        reportPath: reportURL.path,
        currentSessionToken: controller.sessionToken
    ))
}

@MainActor
@Test
func appRuntimeConfigurationChangeInvalidatesValidatedEvidenceBeforeStart() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-runtime-invalidation-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let supervisorURL = directory.appendingPathComponent("supervisor-pass.json")
    try writeAppMeasuredPassSupervisorReport(directory: directory, supervisorURL: supervisorURL)

    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = supervisorURL.path
    let controller = AppExecutionController(settings: settings)
    controller.sessionToken = "validated-session"
    try AppRuntimeEvidenceScope.writeSessionToken("validated-session", reportPath: supervisorURL.path)
    try FileManager.default.setAttributes(
        [.modificationDate: Date().addingTimeInterval(1)],
        ofItemAtPath: supervisorURL.path
    )

    controller.finishValidation(exitCode: 0)
    controller.armedForExecution = true

    #expect(controller.lastValidationResult == .passed)
    #expect(controller.hasValidatedRuntimeEvidence)
    #expect(AppTransportStartPolicy.canStart(
        armedForExecution: controller.armedForExecution,
        dryRunAvailable: true,
        lastValidationResult: controller.lastValidationResult,
        hasValidatedRuntimeEvidence: controller.hasValidatedRuntimeEvidence
    ))

    controller.invalidateRuntimeEvidenceAfterConfigurationChange()

    #expect(controller.lastValidationResult == .unknown)
    #expect(controller.lastValidationExitCode == nil)
    #expect(controller.lastValidationFinishedAt == nil)
    #expect(controller.lastLatencyMetrics == nil)
    #expect(controller.lastExternalConnectorReport == nil)
    #expect(controller.lastCaptureReport == nil)
    #expect(controller.sessionToken == nil)
    #expect(controller.status == "Configuration changed. Revalidate before starting.")
    #expect(!controller.hasValidatedRuntimeEvidence)
    #expect(!AppTransportStartPolicy.canStart(
        armedForExecution: controller.armedForExecution,
        dryRunAvailable: true,
        lastValidationResult: controller.lastValidationResult,
        hasValidatedRuntimeEvidence: controller.hasValidatedRuntimeEvidence
    ))

    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = "/private/tmp/open-lola"
    #expect(controller.validationReadiness(operatorSurface: surface) == .staleReport(supervisorURL.path))
}

@Test
func appRuntimeEvidenceInvalidationPolicyTracksRuntimeSurfaceChangesOnly() {
    let original = appOperatorState(remoteSelectionComplete: true)

    var commandOnly = original
    commandOnly.commandIntent = .runRequested
    #expect(!AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
        oldSurface: original,
        newSurface: commandOnly
    ))

    var controlModeOnly = original
    controlModeOnly.controlMode = .advanced
    #expect(!AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
        oldSurface: original,
        newSurface: controlModeOnly
    ))

    var portChanged = original
    portChanged.directPeerCommandFields.audioPort = 57_090
    #expect(AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
        oldSurface: original,
        newSurface: portChanged
    ))

    var localSelectionChanged = original
    localSelectionChanged.inventory.selection.audioInputUID = "other-input"
    #expect(AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
        oldSurface: original,
        newSurface: localSelectionChanged
    ))

    var windowsReportChanged = original
    windowsReportChanged.windowsLoLaPeerFields.outputPath = "/tmp/open-lola-app/changed-windows-lola.json"
    #expect(AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
        oldSurface: original,
        newSurface: windowsReportChanged
    ))

    var jackTripReportChanged = original
    jackTripReportChanged.jackTripPeerFields.outputPath = "/tmp/open-lola-app/changed-jacktrip.json"
    #expect(AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
        oldSurface: original,
        newSurface: jackTripReportChanged
    ))

    var ultraGridReportChanged = original
    ultraGridReportChanged.ultraGridPeerFields.outputPath = "/tmp/open-lola-app/changed-ultragrid.json"
    #expect(AppRuntimeEvidenceInvalidationPolicy.shouldInvalidateRuntimeEvidence(
        oldSurface: original,
        newSurface: ultraGridReportChanged
    ))
}

@MainActor
@Test
func appValidationReadinessRejectsFreshTokenWithStaleReportContent() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-stale-report-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let reportURL = directory.appendingPathComponent("supervisor.json")
    try Data("{}".utf8).write(to: reportURL)

    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = reportURL.path
    let controller = AppExecutionController(settings: settings)
    controller.sessionToken = "fresh-session"
    try AppRuntimeEvidenceScope.writeSessionToken("fresh-session", reportPath: reportURL.path)
    try FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSince1970: 1_000)],
        ofItemAtPath: reportURL.path
    )
    try FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSince1970: 2_000)],
        ofItemAtPath: AppRuntimeEvidenceScope.sessionTokenURL(reportPath: reportURL.path).path
    )

    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = "/private/tmp/open-lola"

    #expect(controller.validationReadiness(operatorSurface: surface) == .staleReport(reportURL.path))
    #expect(AppRuntimeEvidenceScope.sessionTokenMatchResult(
        reportPath: reportURL.path,
        currentSessionToken: "fresh-session"
    ) == .staleReport)
    #expect(AppRuntimeEvidenceScope.hasValidatedRuntimeEvidenceState(
        executionKind: .directMacPeer,
        validationExitCode: 0,
        directPeerLatencyMetrics: AppLatencyHeroMetrics.make(from: [
            appMeasuredPassDirectPeerSessionReport(id: "current-peer-report", peerID: "peer-a"),
        ]),
        externalConnectorReport: nil,
        reportPath: reportURL.path,
        currentSessionToken: "fresh-session"
    ) == .staleReport)
}

@MainActor
@Test
func appRuntimeEvidenceDistinguishesCorruptReportsAndUnreadableSessionTokens() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-evidence-errors-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let corruptReportURL = directory.appendingPathComponent("supervisor-corrupt.json")
    try Data("{".utf8).write(to: corruptReportURL)
    guard case .decodeFailure = AppLatencyHeroMetrics.loadResult(fromSupervisorReportPath: corruptReportURL.path) else {
        Issue.record("Expected corrupt supervisor JSON to report decodeFailure")
        return
    }

    let missingReportURL = directory.appendingPathComponent("supervisor-missing.json")
    #expect(AppLatencyHeroMetrics.loadResult(fromSupervisorReportPath: missingReportURL.path) == .absent)

    let reportURL = directory.appendingPathComponent("supervisor.json")
    try Data("{}".utf8).write(to: reportURL)
    let tokenURL = AppRuntimeEvidenceScope.sessionTokenURL(reportPath: reportURL.path)
    try Data([0xff, 0xfe, 0xfd]).write(to: tokenURL)

    guard case .readError = AppRuntimeEvidenceScope.sessionTokenMatchResult(
        reportPath: reportURL.path,
        currentSessionToken: "current-session"
    ) else {
        Issue.record("Expected invalid UTF-8 token to report readError")
        return
    }

    let metrics = AppLatencyHeroMetrics.make(from: [
        appMeasuredPassDirectPeerSessionReport(id: "current-peer-report", peerID: "peer-a"),
    ])
    guard case .tokenReadError = AppRuntimeEvidenceScope.hasValidatedRuntimeEvidenceState(
        executionKind: .directMacPeer,
        validationExitCode: 0,
        directPeerLatencyMetrics: metrics,
        externalConnectorReport: nil,
        reportPath: reportURL.path,
        currentSessionToken: "current-session"
    ) else {
        Issue.record("Expected runtime evidence state to preserve token read error")
        return
    }

    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = reportURL.path
    let controller = AppExecutionController(settings: settings)
    controller.sessionToken = "current-session"
    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = "/private/tmp/open-lola"

    guard case .evidenceReadError = controller.validationReadiness(operatorSurface: surface) else {
        Issue.record("Expected validation readiness to surface token read error")
        return
    }
}
