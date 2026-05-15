import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func appMenuActionHandlingCoversEveryContractAction() {
    let contractActionIDs = Set(NativeAppShellSurfaceContract.releaseReadiness.actions.map(\.id))

    #expect(contractActionIDs == AppMenuActionHandling.handledActionIDs)
    #expect(AppMenuActionHandling.isHandled("validate-supervisor-report"))
    #expect(!AppMenuActionHandling.isHandled("future-unmapped-action"))
}

@MainActor
@Test
func appValidationReadinessRequiresExistingReportArtifactBeforeLaunching() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-slice05-validation-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let controller = AppExecutionController()
    var surface = AppShellStoredDefaults.placeholderOperatorSurface()
    let missingDirectReport = directory.appendingPathComponent("missing-supervisor.json").path
    controller.settings.supervisorReportPath = missingDirectReport

    #expect(controller.validationReadiness(operatorSurface: surface) == .missingReport(missingDirectReport))
    controller.validateReport(operatorSurface: surface)
    #expect(controller.lastCommand.isEmpty)
    #expect(controller.status == "Validation unavailable.")
    #expect(controller.phase == .validationFailed)
    #expect(controller.lastError == "Cannot validate missing report artifact: \(missingDirectReport)")

    let existingDirectReport = directory.appendingPathComponent("supervisor.json")
    try Data("{}".utf8).write(to: existingDirectReport)
    controller.settings.supervisorReportPath = existingDirectReport.path
    #expect(controller.validationReadiness(operatorSurface: surface) == .ready)

    surface.sessionMode = .windowsLoLa
    let missingWindowsReport = directory.appendingPathComponent("missing-windows-lola.json").path
    surface.windowsLoLaPeerFields.outputPath = missingWindowsReport
    #expect(controller.validationReadiness(operatorSurface: surface) == .missingReport(missingWindowsReport))

    let existingWindowsReport = directory.appendingPathComponent("windows-lola.json")
    try Data("{}".utf8).write(to: existingWindowsReport)
    surface.windowsLoLaPeerFields.outputPath = existingWindowsReport.path
    #expect(controller.validationReadiness(operatorSurface: surface) == .ready)
}

@Test
func appPacketMonitorSelectionRequiresCaptureReportEvidence() {
    let sections = NativeAppShellSurfaceContract.releaseReadiness.sections
    let packetOnly = NativeAppShellSectionSearch.visibleSections(sections, query: "packet")

    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: false
    ) == nil)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: false
    ) == .overview)
    #expect(AppConsoleSectionSelection.resolvedSection(
        current: .packetMonitor,
        visibleSections: packetOnly,
        sessionState: .ready,
        captureReportAvailable: false
    ) == nil)
    #expect(AppConsoleSectionSelection.activeSection(
        current: .packetMonitor,
        visibleSections: sections,
        sessionState: .ready,
        captureReportAvailable: true
    ) == .packetMonitor)
}

@Test
func appSlice05UiPoliciesExposeTruthfulOperatorStates() {
    #expect(!AppPreviewControlAvailability.returnBlendEnabledInLocalPreview)
    #expect(!AppPreviewControlAvailability.visibleStreamsEnabledInLocalPreview)
    #expect(AppPreviewControlAvailability.unsupportedLocalPreviewHelp.contains("single-stream"))

    #expect(AppSettingsMutationPolicy.executionSettingsLocked(isRunning: true))
    #expect(!AppSettingsMutationPolicy.executionSettingsLocked(isRunning: false))
    #expect(AppSettingsMutationPolicy.help(isRunning: true).contains("locked"))

    #expect(AppWindowSize.operatorMinWidth == 1024)
    #expect(AppWindowSize.operatorMinHeight == 720)
}

@Test
func appExecutionErrorGuidanceClassifiesCommonFailureTypes() {
    #expect(AppExecutionErrorGuidance.detail(
        for: "Cannot validate missing report artifact: /tmp/supervisor.json"
    ).contains("report path"))
    #expect(AppExecutionErrorGuidance.detail(
        for: "No such file or executable"
    ).contains("executable path"))
    #expect(AppExecutionErrorGuidance.detail(
        for: "plan validation failed"
    ).contains("plan fields"))
    #expect(AppExecutionErrorGuidance.detail(
        for: "process exited 42"
    ).contains("log paths"))
}

@Test
func appReadableMetricAccessibilityIncludesMetricContext() {
    #expect(AppReadableMetricAccessibility.valueLabel(metric: "Plan", value: "/tmp/plan.json") == "Plan: /tmp/plan.json")
    #expect(AppReadableMetricAccessibility.copyLabel(metric: "Audio input UID") == "Copy Audio input UID value")
}
