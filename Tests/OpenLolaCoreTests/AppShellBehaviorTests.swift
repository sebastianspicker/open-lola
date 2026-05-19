import AppKit
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
@Test
func appExecutionCommandPreviewRequiresVerifiedExecutable() throws {
    let missingExecutable = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-missing-preview-\(UUID().uuidString)")
    var surface = appOperatorState(remoteSelectionComplete: true)
    surface.directPeerCommandFields.executablePath = missingExecutable.path
    let controller = AppExecutionController()

    do {
        _ = try controller.executionCommand(
            executablePath: missingExecutable.path,
            operatorSurface: surface,
            dryRun: true
        ).get()
        Issue.record("Expected command preview to require a verified executable path")
    } catch {
        #expect(String(describing: error).contains("Executable path unavailable"))
    }

    controller.dryRun(executablePath: missingExecutable.path)

    #expect(controller.phase == .failedToStart)
    #expect(controller.status == "Run failed to start.")
    #expect(controller.lastCommand.isEmpty)
    #expect(controller.lastReport?.command.isEmpty == true)
    #expect(controller.lastError?.contains("Executable path unavailable") == true)
}

@Test
func appExecutablePathResolverClassifiesRunnableAndUnavailablePaths() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-executable-paths-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let missingExecutable = directory.appendingPathComponent("missing-open-lola")
    let nonExecutableFile = directory.appendingPathComponent("not-executable")
    let executableFile = directory.appendingPathComponent("open-lola")
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: nonExecutableFile)
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableFile)
    try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o755))],
        ofItemAtPath: executableFile.path
    )

    #expect(AppExecutablePathResolver.resolve(missingExecutable.path) == .unavailable(
        path: missingExecutable.path,
        reason: "file does not exist"
    ))
    #expect(AppExecutablePathResolver.resolve(nonExecutableFile.path) == .unverified(
        path: nonExecutableFile.path,
        reason: "file is not executable"
    ))
    #expect(AppExecutablePathResolver.resolve(executableFile.path) == .verified(path: executableFile.path))

    do {
        _ = try AppExecutablePathResolver.verifiedPath(nonExecutableFile.path)
        Issue.record("Expected non-executable file to fail executable verification")
    } catch {
        #expect(String(describing: error).contains("Executable path unverified"))
    }
}

@MainActor
@Test
func appStateAndRuntimeEvidenceScopeDoNotReportLiveWithoutValidatedEvidence() {
    #expect(AppDesignSystem.appBackgroundMeetsSecondaryTextContrast)
    #expect(AppDesignSystem.appBackgroundSecondaryTextContrastRatio >= AppDesignSystem.minimumNormalTextContrastRatio)

    let noEvidenceState = AppSessionState.derive(
        isRunning: false,
        isArmed: false,
        lastExitCode: 0,
        isConfigured: true,
        commandIntent: .idle,
        phase: .runFinished,
        hasValidatedRuntimeEvidence: false
    )
    let evidenceState = AppSessionState.derive(
        isRunning: false,
        isArmed: false,
        lastExitCode: 0,
        isConfigured: true,
        commandIntent: .idle,
        phase: .runFinished,
        hasValidatedRuntimeEvidence: true
    )
    let handoffState = AppSessionState.derive(
        isRunning: false,
        isArmed: false,
        lastExitCode: nil,
        isConfigured: false,
        commandIntent: .handoffRequested,
        phase: .idle,
        hasValidatedRuntimeEvidence: false
    )

    #expect(noEvidenceState == .awaitingEvidence)
    #expect(evidenceState == .live)
    #expect(handoffState == .unconfigured)

    let metrics = AppLatencyHeroMetrics.make(from: [
        appDirectPeerSessionReport(
            id: "peer-a-report",
            packetsReceived: 90,
            packetsLost: 0,
            jitterMicroseconds: 2_500,
            latencyMicroseconds: 1_200
        ),
    ])

    #expect(AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
        executionKind: .directMacPeer,
        validationExitCode: 0,
        directPeerLatencyMetrics: metrics,
        externalConnectorReport: nil
    ))
    #expect(!AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
        executionKind: .directMacPeer,
        validationExitCode: nil,
        directPeerLatencyMetrics: metrics,
        externalConnectorReport: nil
    ))
    #expect(!AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
        executionKind: .windowsLoLa,
        validationExitCode: 0,
        directPeerLatencyMetrics: metrics,
        externalConnectorReport: nil
    ))
    #expect(AppRuntimeEvidenceScope.allowsDirectPeerCaptureEvidence(executionKind: .directMacPeer))
    #expect(!AppRuntimeEvidenceScope.allowsDirectPeerCaptureEvidence(executionKind: .windowsLoLa))
}

@MainActor
@Test
func appExecutionStopDefersReportUntilProcessExit() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-stop-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let executable = directory.appendingPathComponent("open-lola")
    try Data("""
    #!/bin/sh
    trap 'exit 0' TERM
    sleep 5 &
    wait $!
    """.utf8).write(to: executable)
    try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o755))],
        ofItemAtPath: executable.path
    )

    var settings = NativeAppShellExecutionSettings()
    settings.planPath = directory.appendingPathComponent("plan.json").path
    settings.supervisorReportPath = directory.appendingPathComponent("supervisor.json").path
    settings.connectionPreflightReportPath = directory.appendingPathComponent("preflight.json").path
    settings.requirePreflight = false

    let controller = AppExecutionController(settings: settings)
    controller.dryRun(executablePath: executable.path)
    try await waitUntil("test process starts") {
        controller.isRunning
    }

    controller.stop()

    #expect(controller.phase == .stopRequested)
    #expect(controller.status == "Stop requested.")
    #expect(controller.lastReport == nil)

    try await waitUntil("stop report is finalized after process exit") {
        controller.lastReport != nil
    }

    #expect(!controller.isRunning)
    #expect(controller.lastReport?.stopRequested == true)
    #expect(controller.lastReport?.exitCode != nil)
    #expect(controller.lastReport?.finishedAt != nil)
}

@MainActor
@Test
func appExecutionValidationBlocksMissingExecutableBeforeLaunch() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-app-validation-launch-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let existingReport = directory.appendingPathComponent("supervisor.json")
    try Data("{}".utf8).write(to: existingReport)
    let missingValidator = directory.appendingPathComponent("open-lola")

    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = existingReport.path
    settings.connectionPreflightReportPath = directory.appendingPathComponent("preflight.json").path
    settings.requirePreflight = false

    let controller = AppExecutionController(settings: settings)
    controller.lastValidationExitCode = 0
    controller.validateReport(executablePath: missingValidator.path)

    #expect(controller.phase == .validationFailed)
    #expect(controller.status == "Validation unavailable.")
    #expect(controller.lastValidationExitCode == nil)
    #expect(controller.lastCommand.isEmpty)
    #expect(controller.lastReport == nil)
    #expect(controller.lastError?.contains("Executable path unavailable") == true)
    #expect(!controller.hasValidatedRuntimeEvidence)
}

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
    #expect(!partialWindowsController.hasValidatedRuntimeEvidence)
    #expect(partialWindowsController.lastExternalConnectorReport?.verdict == .partial)
    #expect(partialWindowsController.lastError == "External connector evidence incomplete: verdict partial")

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
    #expect(failedWindowsController.lastError == "External connector evidence incomplete: verdict fail")

    let passingWindowsReportURL = directory.appendingPathComponent("windows-pass.json")
    try appExternalConnectorSessionReport(verdict: .pass, outputPath: passingWindowsReportURL.path)
        .prettyJSONData()
        .write(to: passingWindowsReportURL)
    state.windowsLoLaPeerFields.outputPath = passingWindowsReportURL.path
    let passingWindowsController = AppExecutionController()

    _ = try passingWindowsController.prepareValidationContext(operatorSurface: state)
    passingWindowsController.finishValidation(exitCode: 0)

    #expect(passingWindowsController.phase == .validationPassed)
    #expect(passingWindowsController.status == "Validation passed.")
    #expect(passingWindowsController.hasValidatedRuntimeEvidence)
    #expect(passingWindowsController.lastExternalConnectorReport?.verdict == .pass)

    let reportAURL = directory.appendingPathComponent("peer-a.json")
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
    let processResults = [
        appProcessResult(peerID: "peer-a", reportPath: reportAURL.path),
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
        verdict: .pass,
        notes: "unit test supervisor report"
    ).prettyJSONData().write(to: passSupervisorURL)

    var passingSettings = NativeAppShellExecutionSettings()
    passingSettings.supervisorReportPath = passSupervisorURL.path
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
func appConsoleFooterRenderedValidationStatusRequiresRuntimeEvidence() throws {
    let sourceReport = NativeAppShellSyntheticSmoke.run()
    let unconfiguredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: false))
    let configuredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: true))

    let noReportFooter = try renderedFooterLabels(
        report: sourceReport,
        plan: unconfiguredPlan,
        controller: AppExecutionController()
    )
    #expect(noReportFooter.contains("Setup required"))
    #expect(!noReportFooter.contains("Report validated"))

    let malformedEvidenceController = AppExecutionController()
    malformedEvidenceController.lastValidationExitCode = 0
    malformedEvidenceController.lastError = "Validated supervisor report missing or unreadable: malformed.json"
    let malformedFooter = try renderedFooterLabels(
        report: sourceReport,
        plan: configuredPlan,
        controller: malformedEvidenceController
    )
    #expect(malformedFooter.contains("Validation failed"))
    #expect(!malformedFooter.contains("Report validated"))

    let partialEvidenceController = AppExecutionController()
    partialEvidenceController.lastValidationExitCode = 0
    partialEvidenceController.lastLatencyMetrics = AppLatencyHeroMetrics.make(
        from: [
            appDirectPeerSessionReport(
                id: "partial-peer-report",
                packetsReceived: 1,
                packetsLost: 0,
                jitterMicroseconds: 1,
                latencyMicroseconds: 1
            ),
        ],
        expectedPeerReportCount: 1,
        loadFailures: [],
        supervisorVerdict: .partial
    )
    let partialFooter = try renderedFooterLabels(
        report: sourceReport,
        plan: configuredPlan,
        controller: partialEvidenceController
    )
    #expect(partialFooter.contains("Validation failed"))
    #expect(!partialFooter.contains("Report validated"))

    let stalePassController = AppExecutionController()
    stalePassController.lastValidationExitCode = 0
    stalePassController.lastReport = NativeAppShellExecutionReport(
        command: ["open-lola", "validate-direct-p2p-two-peer-local-run-report"],
        startedAt: "2026-05-17T00:00:00Z",
        exitCode: 0,
        stdoutPath: "/tmp/stdout.log",
        stderrPath: "/tmp/stderr.log",
        validationExitCode: 0,
        verdict: .pass,
        notes: "stale pass report without loaded runtime metrics"
    )
    let stalePassFooter = try renderedFooterLabels(
        report: sourceReport,
        plan: configuredPlan,
        controller: stalePassController
    )
    #expect(stalePassFooter.contains("Validation failed"))
    #expect(!stalePassFooter.contains("Report validated"))

    let validEvidenceController = AppExecutionController()
    validEvidenceController.lastValidationExitCode = 0
    validEvidenceController.lastLatencyMetrics = AppLatencyHeroMetrics.make(from: [
        appDirectPeerSessionReport(
            id: "valid-peer-report",
            packetsReceived: 90,
            packetsLost: 0,
            jitterMicroseconds: 2_500,
            latencyMicroseconds: 1_200
        ),
    ])
    let validFooter = try renderedFooterLabels(
        report: sourceReport,
        plan: configuredPlan,
        controller: validEvidenceController
    )
    #expect(validFooter.contains("Report validated"))
}

@MainActor
private func waitUntil(
    _ description: String,
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    condition: () -> Bool
) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while !condition() {
        if DispatchTime.now().uptimeNanoseconds >= deadline {
            Issue.record("Timed out waiting for \(description)")
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

@MainActor
private func renderedFooterLabels(
    report: NativeAppShellReport,
    plan: AppOperatorPrototypePlan,
    controller: AppExecutionController
) throws -> [String] {
    let snapshot = AppConsoleStatusSnapshot.make(
        report: report,
        plan: plan,
        executionController: controller,
        captureReport: nil
    )
    let hostingView = NSHostingView(rootView: AppConsoleFooterStripView(snapshot: snapshot))
    hostingView.frame = NSRect(x: 0, y: 0, width: 900, height: 80)
    hostingView.layoutSubtreeIfNeeded()
    let renderedSize = hostingView.fittingSize
    #expect(renderedSize.width > 0)
    #expect(renderedSize.height > 0)
    return [
        snapshot.validationTitle,
        snapshot.packetTitle,
        snapshot.remoteStreamTitle,
    ]
}

@Test
func appPacketMonitorAndSectionSelectionKeepUnavailableViewsInactive() {
    let emptyReport = LoLaCompatibilityCaptureReport(
        id: "empty-capture",
        title: "Empty capture",
        capturedAt: "2026-05-14T00:00:00Z",
        inputPath: "fixtures/empty.pcapng",
        inputFormat: .pcapng,
        summary: LoLaCompatibilityCaptureSummary(packets: []),
        packets: [],
        verdict: .partial,
        evidenceBoundary: "unit-test packet monitor",
        notes: "empty capture"
    )

    #expect(AppPacketMonitorRowsState.make(
        report: emptyReport,
        streamFilter: .all,
        searchText: "no-match"
    ) == .rows([]))

    let failureState = AppPacketMonitorRowsState.make(
        report: emptyReport,
        streamFilter: .all,
        searchText: "",
        limit: -1
    )
    guard case .failure(let message) = failureState else {
        Issue.record("Expected row-building failure state")
        return
    }
    #expect(message.contains("negativeLimit"))

    let sections = NativeAppShellSurfaceContract.releaseReadiness.sections
    let settingsOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "settings")
    let packetOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "packet")

    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: settingsOnly,
        sessionState: .live,
        captureReportAvailable: true
    ) == .settings)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == .overview)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .ready,
        captureReportAvailable: false
    ) == .packetMonitor)
    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == nil)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .unconfigured,
        captureReportAvailable: true
    ) == nil)
}

@MainActor
@Test
func appOverviewSummaryChoosesOperatorNextActions() {
    let report = NativeAppShellSyntheticSmoke.run()
    let unconfiguredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: false))
    let configuredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: true))

    let unconfigured = AppOverviewOperatorSummary.make(
        report: report,
        plan: unconfiguredPlan,
        executionController: AppExecutionController(),
        sessionState: .unconfigured,
        captureReport: nil
    )
    #expect(unconfigured.nextAction.title == "Configure devices")
    #expect(unconfigured.nextAction.targetSection == .devices)
    #expect(unconfigured.statusItems.contains { $0.id == "readiness" && $0.value == "Setup required" })

    let ready = AppOverviewOperatorSummary.make(
        report: report,
        plan: configuredPlan,
        executionController: AppExecutionController(),
        sessionState: .ready,
        captureReport: nil
    )
    #expect(ready.nextAction.title == "Arm or dry-run")
    #expect(ready.nextAction.targetSection == .session)

    let runningController = AppExecutionController()
    runningController.phase = .supervisorRunning
    runningController.status = "Supervisor running."
    let running = AppOverviewOperatorSummary.make(
        report: report,
        plan: configuredPlan,
        executionController: runningController,
        sessionState: .supervisorRunning,
        captureReport: nil
    )
    #expect(running.nextAction.title == "Monitor the run")
    #expect(running.nextAction.targetSection == .session)

    let failedController = AppExecutionController()
    failedController.phase = .runFailed
    failedController.lastError = "unit failure"
    let failed = AppOverviewOperatorSummary.make(
        report: report,
        plan: configuredPlan,
        executionController: failedController,
        sessionState: .error,
        captureReport: nil
    )
    #expect(failed.nextAction.title == "Inspect the failure")
    #expect(failed.nextAction.targetSection == .diagnostics)

    let incompleteController = AppExecutionController()
    incompleteController.lastValidationExitCode = 0
    let incomplete = AppOverviewOperatorSummary.make(
        report: report,
        plan: configuredPlan,
        executionController: incompleteController,
        sessionState: .awaitingEvidence,
        captureReport: nil
    )
    #expect(incomplete.nextAction.title == "Resolve evidence gap")
    #expect(incomplete.nextAction.targetSection == .validation)
    #expect(incomplete.evidence.runtimeEvidence == "Missing current measurement")
}

@MainActor
@Test
func appValidationPreflightReportsBlockersWithTargetSections() {
    let report = NativeAppShellSyntheticSmoke.run()
    let surfaceProbe = NativeAppShellSurfaceProbe.run(sourceReport: report)
    let unconfiguredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: false))
    let configuredPlan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: true))

    let blocked = AppValidationPreflightModel.make(
        plan: unconfiguredPlan,
        executionController: AppExecutionController(),
        surfaceProbe: surfaceProbe
    )
    #expect(blocked.verdict == .blocked)
    #expect(blocked.blockers.contains { $0.id == "plan" && $0.targetSection == .devices })

    let runningController = AppExecutionController()
    runningController.phase = .dryRunRunning
    let running = AppValidationPreflightModel.make(
        plan: configuredPlan,
        executionController: runningController,
        surfaceProbe: surfaceProbe
    )
    #expect(running.verdict == .running)
    #expect(running.blockers.first?.targetSection == .session)

    let incompleteController = AppExecutionController()
    incompleteController.lastValidationExitCode = 0
    let incomplete = AppValidationPreflightModel.make(
        plan: configuredPlan,
        executionController: incompleteController,
        surfaceProbe: surfaceProbe
    )
    #expect(incomplete.verdict == .evidenceIncomplete)
    #expect(incomplete.blockers.first?.targetSection == .session)
}

@MainActor
@Test
func appPacketMonitorEmptyStateAndDiagnosticsStatusExposeEvidenceContext() {
    let report = NativeAppShellSyntheticSmoke.run()
    let plan = AppOperatorPrototypePlan.make(operatorSurface: appOperatorState(remoteSelectionComplete: true))
    var settings = NativeAppShellExecutionSettings()
    settings.supervisorReportPath = "/tmp/open-lola-supervisor.json"

    let emptyState = AppPacketMonitorEmptyState.make(plan: plan, executionSettings: settings)
    #expect(emptyState.title == "Packet evidence unavailable")
    #expect(emptyState.expectedReportPath == "/tmp/open-lola-supervisor.json")
    #expect(emptyState.targetSection == .session)

    let controller = AppExecutionController(settings: settings)
    let sourceDiagnostics = AppDiagnosticsStatusModel.make(report: report, executionController: controller)
    #expect(sourceDiagnostics.permissionsTitle == "Ready")
    #expect(sourceDiagnostics.realtimeSafetyTitle == "Callback-safe")
    #expect(sourceDiagnostics.processTitle == "Idle")
    #expect(sourceDiagnostics.evidenceTitle == "Synthetic source")

    controller.lastLatencyMetrics = AppLatencyHeroMetrics.make(
        from: [
            appDirectPeerSessionReport(
                id: "partial-peer-report",
                packetsReceived: 1,
                packetsLost: 0,
                jitterMicroseconds: 1,
                latencyMicroseconds: 1
            ),
        ],
        expectedPeerReportCount: 1,
        loadFailures: [],
        supervisorVerdict: .partial
    )
    let partialDiagnostics = AppDiagnosticsStatusModel.make(report: report, executionController: controller)
    #expect(partialDiagnostics.evidenceTitle == "Loaded partial")
}

private func appOperatorState(remoteSelectionComplete: Bool) -> NativeAppShellOperatorPrototypeState {
    var remoteInventory = NativeAppShellLocalMediaInventory.editableRemotePlaceholder(peerName: "remote-mac")
    if remoteSelectionComplete {
        remoteInventory = NativeAppShellLocalMediaInventory(
            capturedAt: "2026-05-14T00:00:00Z",
            hostName: "remote-mac",
            audioDevices: [
                NativeAppShellAudioDeviceOption(
                    name: "Remote RME",
                    uid: "remote-rme",
                    inputChannelCount: 64,
                    outputChannelCount: 64,
                    nominalSampleRateHertz: 48_000,
                    currentBufferFrameSize: 32
                ),
            ],
            videoDevices: [
                NativeAppShellVideoDeviceOption(
                    label: "Remote ATEM",
                    uniqueId: "remote-atem",
                    manufacturer: "Blackmagic Design",
                    transport: "USB",
                    sourcePolicy: .blackmagicFirstAvFoundationFallback,
                    formatCount: 1
                ),
            ],
            selection: NativeAppShellLocalMediaSelection(
                audioInputUID: "remote-rme",
                audioOutputUID: "remote-rme",
                videoDeviceID: "remote-atem"
            ),
            inventoryErrors: []
        )
    }
    var fields = NativeAppShellDirectPeerCommandFields.appDefault
    fields.localHost = "192.0.2.10"
    fields.remoteHost = "192.0.2.20"
    return NativeAppShellOperatorPrototypeState(
        inventory: NativeAppShellLocalMediaInventory(
            capturedAt: "2026-05-14T00:00:00Z",
            hostName: "local-mac",
            audioDevices: [
                NativeAppShellAudioDeviceOption(
                    name: "Local RME",
                    uid: "local-rme",
                    inputChannelCount: 64,
                    outputChannelCount: 64,
                    nominalSampleRateHertz: 48_000,
                    currentBufferFrameSize: 32
                ),
            ],
            videoDevices: [
                NativeAppShellVideoDeviceOption(
                    label: "Local ATEM",
                    uniqueId: "local-atem",
                    manufacturer: "Blackmagic Design",
                    transport: "USB",
                    sourcePolicy: .blackmagicFirstAvFoundationFallback,
                    formatCount: 1
                ),
            ],
            selection: NativeAppShellLocalMediaSelection(
                audioInputUID: "local-rme",
                audioOutputUID: "local-rme",
                videoDeviceID: "local-atem"
            ),
            inventoryErrors: []
        ),
        remoteInventory: remoteInventory,
        commandIntent: .idle,
        remoteOrchestrationEnabled: false,
        startsLongRunningProcess: false,
        directPeerCommandFields: fields
    )
}

private func appDirectPeerSessionReport(
    id: String,
    packetsReceived: Int,
    packetsLost: Int,
    jitterMicroseconds: Double,
    latencyMicroseconds: Double
) -> DirectPeerSessionReport {
    DirectPeerSessionReport(
        id: id,
        capturedAt: "2026-05-14T00:00:00Z",
        configuration: appSessionConfiguration(),
        metrics: DirectPeerSessionReportMetrics(
            controlMessagesSent: 1,
            packetsSent: packetsReceived + packetsLost,
            packetsReceived: packetsReceived,
            packetsLost: packetsLost,
            jitterMicroseconds: jitterMicroseconds,
            audioPacketsRouted: packetsReceived,
            videoPacketsRouted: 0,
            recoveryEvents: 0,
            audioPayloadsSentOnControlChannel: 0
        ),
        avRuntime: DirectPeerSessionAVRuntimeMetadata(
            avProfile: .fastest,
            previewMode: .off,
            mediaSourceMode: .syntheticFixture,
            audioDeviceUID: "local-rme",
            sampleRateHertz: 48_000,
            selectedBufferFrameSize: 32,
            latencyProfile: .directAudioFirst,
            rxBufferProfile: .direct,
            videoDeviceID: "local-atem",
            videoFrameRate: 30,
            videoStreamID: 100,
            fastestPassBlockedReason: "unit test partial",
            fastestAVBaselineComparison: DirectPeerSessionFastestAVBaselineComparison(
                audioOnlyBaselineReportID: "audio-only",
                audioOnlyBaselineReportPath: "reports/audio-only.json",
                comparisonArtifactPath: "reports/comparison.json",
                audioOnlyLatencyP99Microseconds: latencyMicroseconds,
                fastestAVAudioLatencyP99Microseconds: latencyMicroseconds,
                audioLatencyEqualToBaseline: true,
                rxBufferEqualToBaseline: true,
                lossJitterEqualToBaseline: true
            )
        ),
        verdict: .partial,
        notes: "unit test partial report"
    )
}

private func appProcessResult(peerID: String, reportPath: String) -> DirectPeerTwoPeerLocalRunProcessResult {
    DirectPeerTwoPeerLocalRunProcessResult(
        peerID: peerID,
        role: peerID == "peer-a" ? .initiator : .responder,
        reportPath: reportPath,
        command: ["open-lola", "direct-p2p-session-run"],
        exitCode: 0,
        collectedReportPath: reportPath
    )
}

private func appExternalConnectorSessionReport(
    verdict: MeasurementVerdict,
    outputPath: String
) throws -> ExternalConnectorSessionReport {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .txRx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: outputPath,
        dryRun: false,
        mediaMode: .audioVideo,
        controlTransport: .udp,
        durationSeconds: 1,
        controlPort: 7_000,
        audioPort: 19_788,
        videoPort: 19_798,
        channels: 2,
        sampleRateHertz: 44_100,
        framesPerPacket: 64,
        videoWidth: 640,
        videoHeight: 480,
        videoFrameRate: 25,
        videoBitsPerPixel: 8,
        mediaPacketCount: 1
    )
    return ExternalConnectorSessionReport(
        id: "external-connector-\(verdict.rawValue)",
        capturedAt: "2026-05-15T00:00:00Z",
        connector: configuration.connector,
        role: configuration.role,
        dryRun: false,
        plan: try ExternalConnectorLaunchPlan.build(configuration: configuration),
        process: nil,
        auxiliaryProcesses: [],
        lolaControl: nil,
        lolaMedia: nil,
        runtimeError: verdict == .fail ? "unit test runtime failure" : nil,
        verdict: verdict,
        notes: "unit test Windows LoLa connector report"
    )
}

private func appSessionConfiguration() -> SessionConfiguration {
    SessionConfiguration(
        sessionID: "app-test-session",
        peers: [
            PeerIdentity(
                peerID: "peer-a",
                displayName: "Peer A",
                implementationName: "open-lola",
                implementationVersion: "test"
            ),
            PeerIdentity(
                peerID: "peer-b",
                displayName: "Peer B",
                implementationName: "open-lola",
                implementationVersion: "test"
            ),
        ],
        latencyProfile: .directAudioFirst,
        rxBufferProfile: .direct,
        audioStreams: [],
        videoStreams: [],
        controlEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 19_001),
        audioEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 19_002),
        videoEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 19_003),
        metricsEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 19_004),
        peerMediaEndpoints: [
            appPeerEndpoints(peerID: "peer-a", basePort: 19_001),
            appPeerEndpoints(peerID: "peer-b", basePort: 19_011),
        ],
        mtuBytes: 1_200,
        metricIntervalMilliseconds: 1_000,
        reconnectDeadlineMilliseconds: 1_000
    )
}

private func appPeerEndpoints(peerID: String, basePort: UInt16) -> SessionPeerMediaEndpoints {
    SessionPeerMediaEndpoints(
        peerID: peerID,
        controlEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: basePort),
        audioEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: basePort + 1),
        videoEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: basePort + 2),
        metricsEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: basePort + 3)
    )
}
