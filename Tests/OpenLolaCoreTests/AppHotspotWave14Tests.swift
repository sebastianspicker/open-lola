// Adds deterministic, no-action coverage for app-shell menu, persistence, and evidence state seams.
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@MainActor
struct AppHotspotWave14Tests {
    private static let hostSize = CGSize(width: 960, height: 680)

    @Test
    func wave14AppMenuRefreshSyntheticMetricsConstructsWithoutInvokingAction() throws {
        try hostMenuAction("refresh-synthetic-metrics")
    }

    @Test
    func wave14AppMenuRefreshInventoryConstructsWithoutInvokingAction() throws {
        try hostMenuAction("refresh-local-media-inventory")
    }

    @Test
    func wave14AppMenuArmExecutionConstructsWithoutInvokingAction() throws {
        try hostMenuAction("arm-execution")
    }

    @Test
    func wave14AppMenuWritePlanConstructsWithoutInvokingAction() throws {
        try hostMenuAction("write-two-peer-plan")
    }

    @Test
    func wave14AppMenuDryRunConstructsWithoutInvokingAction() throws {
        try hostMenuAction("dry-run-supervisor")
    }

    @Test
    func wave14AppMenuHandoffConstructsWithoutInvokingAction() throws {
        try hostMenuAction("set-handoff-intent")
    }

    @Test
    func wave14AppMenuStartConstructsWithoutInvokingAction() throws {
        try hostMenuAction("start-armed-supervisor")
    }

    @Test
    func wave14AppMenuStopConstructsWithoutInvokingAction() throws {
        try hostMenuAction("stop-supervisor-run")
    }

    @Test
    func wave14AppMenuValidateConstructsWithoutInvokingAction() throws {
        try hostMenuAction("validate-supervisor-report")
    }

    @Test
    func wave14AppMenuClearIntentConstructsWithoutInvokingAction() throws {
        try hostMenuAction("clear-command-intent")
    }

    @Test
    func wave14AppMenuPreviewConstructsWithoutInvokingAction() throws {
        try hostMenuAction("open-local-preview-window")
    }

    @Test
    func wave14AppMenuUnknownActionBuildsEmptyViewWithoutInvokingAction() {
        let action = NativeAppShellSurfaceAction(
            identity: .init(id: "wave14-unknown", title: "Unknown", keyboardShortcut: nil),
            effects: .init(
                refreshesReportOnly: false,
                startsRealtimeAudio: false,
                startsRealtimeVideo: false,
                armsControlOutput: false
            )
        )
        #expect(AppMenuActionGroup(actionID: action.id) == .unsupported)
        host(
            OpenLolaAppScene().appMenuActionButton(action),
            named: action.id,
            expectsHostedSubviews: false
        )
    }

    @Test
    func wave14AppArtifactViewConstructsLockedAndEditableStates() throws {
        let suite = try isolatedDefaults("artifacts")
        let defaults = suite.defaults
        defer { defaults.removePersistentDomain(forName: suite.name) }
        let settings = AppSettings(defaults: defaults)

        for locked in [true, false] {
            var surface = appOperatorState(remoteSelectionComplete: true)
            host(
                AppOperatorArtifactsView(
                    operatorSurface: Binding(get: { surface }, set: { surface = $0 }),
                    appSettings: settings,
                    inputsLocked: locked
                ),
                named: locked ? "locked-artifacts" : "editable-artifacts"
            )
        }
    }

    @Test
    func wave14AppArtifactPanelRetainsGeneratedArtifactsWithAndWithoutPath() {
        let pathless = NativeAppShellGeneratedArtifactState(
            kind: .twoPeerSupervisorCommand,
            generatedAt: "2026-08-05T12:00:00Z",
            path: nil,
            clipboardText: "ssh mac-a.example.test",
            validationSummary: "copyable command"
        )
        let stored = NativeAppShellGeneratedArtifactState(
            kind: .twoPeerRunPlan,
            generatedAt: "2026-08-05T12:00:01Z",
            path: "/tmp/open-lola-wave14-plan.json",
            clipboardText: "{\"id\":\"wave14\"}",
            validationSummary: "validated plan"
        )
        var state = AppOperatorArtifactPanelState()

        state.recordGeneratedArtifact(pathless, status: "Copied command.")
        #expect(state.generatedArtifact?.path == nil)
        #expect(state.fileError == nil)

        state.recordGeneratedArtifact(stored, status: "Generated plan.")
        #expect(state.generatedArtifact?.path == stored.path)
        #expect(state.status == "Generated plan.")
    }

    @Test
    func wave14AppArtifactPanelClearsAndRecordsFailureState() {
        var state = AppOperatorArtifactPanelState()
        state.clearGeneratedArtifact(status: "Inputs changed.")
        #expect(state.generatedArtifact == nil)
        #expect(state.status == "Inputs changed.")

        state.setFailureStatus("Synthetic failure", NativeAppShellArtifactError.emptyClipboardText)
        #expect(state.generatedArtifact == nil)
        #expect(state.fileError?.contains("Synthetic failure") == true)
    }

    @Test
    func wave14AppStoredDefaultsReadExecutionSettingsFromIsolatedSuite() throws {
        let suite = try isolatedDefaults("execution")
        let defaults = suite.defaults
        defer { defaults.removePersistentDomain(forName: suite.name) }
        defaults.set("/tmp/wave14-plan.json", forKey: AppStorageKeys.planPath)
        defaults.set("/tmp/wave14-supervisor.json", forKey: AppStorageKeys.supervisorReportPath)
        defaults.set(DirectPeerTwoPeerRunExecutionMode.ssh.rawValue, forKey: AppStorageKeys.executionMode)
        defaults.set(false, forKey: AppStorageKeys.requirePreflight)
        defaults.set("mac-a.example.test", forKey: AppStorageKeys.executionMacASSH)
        defaults.set("mac-b.example.test", forKey: AppStorageKeys.executionMacBSSH)
        defaults.set("/work/a", forKey: AppStorageKeys.executionMacAWorkingDirectory)
        defaults.set("/work/b", forKey: AppStorageKeys.executionMacBWorkingDirectory)
        defaults.set("/usr/local/bin/ssh", forKey: AppStorageKeys.executionSSHExecutable)
        defaults.set("/usr/local/bin/scp", forKey: AppStorageKeys.executionSCPExecutable)

        let settings = AppShellStoredDefaults.executionSettings(defaults: defaults)
        #expect(settings.planPath == "/tmp/wave14-plan.json")
        #expect(settings.supervisorReportPath == "/tmp/wave14-supervisor.json")
        #expect(settings.executionMode == .ssh)
        #expect(!settings.requirePreflight)
        #expect(settings.macASSH == "mac-a.example.test")
        #expect(settings.macBSSH == "mac-b.example.test")
        #expect(settings.macAWorkingDirectory == "/work/a")
        #expect(settings.macBWorkingDirectory == "/work/b")
        #expect(settings.sshExecutable == "/usr/local/bin/ssh")
        #expect(settings.scpExecutable == "/usr/local/bin/scp")
    }

    @Test
    func wave14AppStoredDefaultsFallBackForInvalidEnumsAndUnsetValues() throws {
        let suite = try isolatedDefaults("enum-fallback")
        let defaults = suite.defaults
        defer { defaults.removePersistentDomain(forName: suite.name) }
        defaults.set("not-a-session", forKey: AppStorageKeys.sessionMode)
        defaults.set("not-a-control-mode", forKey: AppStorageKeys.controlMode)
        defaults.set("not-an-execution-mode", forKey: AppStorageKeys.executionMode)

        #expect(AppShellStoredDefaults.sessionMode(defaults: defaults) == .directMacPeer)
        #expect(AppShellStoredDefaults.controlMode(defaults: defaults) == .normal)
        #expect(AppShellStoredDefaults.executionSettings(defaults: defaults).executionMode == .local)
        #expect(AppShellStoredDefaults.boolDefault("wave14-missing-bool", fallback: true, defaults: defaults))
        #expect(AppShellStoredDefaults.doubleDefault("wave14-missing-double", fallback: 2.5, defaults: defaults) == 2.5)
    }

    @Test
    func wave14AppStoredDefaultsReadPreviewBooleansDoublesAndClampedStreams() throws {
        let suite = try isolatedDefaults("preview")
        let defaults = suite.defaults
        defer { defaults.removePersistentDomain(forName: suite.name) }
        defaults.set(false, forKey: AppStorageKeys.audioPreviewEnabled)
        defaults.set(false, forKey: AppStorageKeys.videoPreviewEnabled)
        defaults.set(false, forKey: AppStorageKeys.showSafeFrame)
        defaults.set(0.3, forKey: AppStorageKeys.monitorGain)
        defaults.set(0.7, forKey: AppStorageKeys.remoteReturnBlend)
        defaults.set(1.25, forKey: AppStorageKeys.videoScale)
        defaults.set(0, forKey: AppStorageKeys.visibleStreams)
        defaults.set(-9, forKey: AppStorageKeys.selectedVideoStream)

        let preview = AppShellStoredDefaults.previewDefaults(defaults: defaults)
        #expect(!preview.audioPreviewEnabled)
        #expect(!preview.videoPreviewEnabled)
        #expect(!preview.showSafeFrame)
        #expect(preview.monitorGain == 0.3)
        #expect(preview.remoteReturnBlend == 0.7)
        #expect(preview.videoScale == 1.25)
        #expect(preview.visibleStreams == 1)
        #expect(preview.selectedVideoStream == 1)
    }

    @Test
    func wave14AppStoredDefaultsReadPrimitiveValuesAndRejectInvalidUInt16() throws {
        let suite = try isolatedDefaults("primitive")
        let defaults = suite.defaults
        defer { defaults.removePersistentDomain(forName: suite.name) }
        defaults.set(42, forKey: "wave14-int")
        defaults.set(true, forKey: "wave14-bool")
        defaults.set(4.5, forKey: "wave14-double")
        defaults.set(-1, forKey: "wave14-uint16")

        #expect(AppShellStoredDefaults.intDefault("wave14-int", fallback: 0, defaults: defaults) == 42)
        #expect(AppShellStoredDefaults.boolDefault("wave14-bool", fallback: false, defaults: defaults))
        #expect(AppShellStoredDefaults.doubleDefault("wave14-double", fallback: 0, defaults: defaults) == 4.5)
        #expect(AppShellStoredDefaults.uint16Default("wave14-uint16", fallback: 48_000, defaults: defaults) == 48_000)
        #expect(defaults.object(forKey: "wave14-uint16") == nil)
        #expect(AppShellStoredDefaults.positivePreviewStreamValue(-1) == 1)
    }

    @Test
    func wave14AppStoredDefaultsValidateDirectWindowsAndConnectorFields() {
        var invalidDirect = NativeAppShellDirectPeerCommandFields.appDefault
        invalidDirect.localHost = ""
        #expect(AppShellStoredDefaults.validatedOrDefault(invalidDirect) == .appDefault)

        var invalidWindows = NativeAppShellWindowsLoLaPeerFields.appDefault
        invalidWindows.localHost = ""
        #expect(AppShellStoredDefaults.validatedOrDefault(invalidWindows) == .appDefault)

        var invalidConnector = NativeAppShellExternalConnectorPeerFields.jackTripAppDefault
        invalidConnector.localHost = ""
        let fallback = NativeAppShellExternalConnectorPeerFields.jackTripAppDefault
        #expect(
            AppShellStoredDefaults.validatedOrDefault(
                invalidConnector,
                connector: .jackTrip,
                fallback: fallback
            ) == fallback
        )
    }

    @Test
    func wave14AppExecutionStartArmedRejectsUnarmedExecutableWithoutProcess() {
        let controller = AppExecutionController()
        #expect(!controller.startArmed(executablePath: "/usr/bin/true"))
        #expect(controller.phase == .failedToStart)
        #expect(controller.status == "Execution blocked.")
        #expect(controller.lastError == "Execution is not armed.")
        #expect(!controller.isRunning)
    }

    @Test
    func wave14AppExecutionStartArmedRejectsUnarmedSurfaceWithoutProcess() {
        let controller = AppExecutionController()
        #expect(!controller.startArmed(operatorSurface: appOperatorState(remoteSelectionComplete: true)))
        #expect(controller.phase == .failedToStart)
        #expect(controller.lastCommand.isEmpty)
        #expect(!controller.isRunning)
    }

    @Test
    func wave14AppExecutionValidationReadinessUsesCurrentTemporaryFixture() throws {
        let directory = try temporaryDirectory("readiness-current")
        defer { try? FileManager.default.removeItem(at: directory) }
        let report = directory.appendingPathComponent("report.json")
        let controller = AppExecutionController()
        controller.sessionToken = "wave14-current"
        try AppRuntimeEvidenceScope.writeSessionToken("wave14-current", reportPath: report.path)
        try Data("{}".utf8).write(to: report)

        #expect(controller.validationReadiness(.directMacPeer, reportPath: report.path) == .ready)
    }

    @Test
    func wave14AppExecutionValidationReadinessRejectsMissingAndStaleFixtures() throws {
        let directory = try temporaryDirectory("readiness-stale")
        defer { try? FileManager.default.removeItem(at: directory) }
        let report = directory.appendingPathComponent("report.json")
        let controller = AppExecutionController()
        controller.sessionToken = "wave14-current"

        #expect(controller.validationReadiness(.directMacPeer, reportPath: "  ") == .missingReport("unset"))
        #expect(controller.validationReadiness(.directMacPeer, reportPath: report.path) == .missingReport(report.path))

        try Data("{}".utf8).write(to: report)
        try AppRuntimeEvidenceScope.writeSessionToken("wave14-current", reportPath: report.path)
        #expect(controller.validationReadiness(.directMacPeer, reportPath: report.path) == .staleReport(report.path))
    }

    @Test
    func wave14AppExecutionInvalidationResetsEvidenceButPreservesPureIdleState() {
        let controller = AppExecutionController()
        controller.status = "Idle stays idle."
        controller.invalidateRuntimeEvidenceAfterConfigurationChange()
        #expect(controller.status == "Idle stays idle.")

        controller.lastValidationExitCode = 0
        controller.lastValidationResult = .passed
        controller.lastValidationFinishedAt = "2026-08-05T12:00:00Z"
        controller.lastLatencyMetrics = AppLatencyHeroMetrics.make(from: [])
        controller.invalidateRuntimeEvidenceAfterConfigurationChange()
        #expect(controller.lastValidationExitCode == nil)
        #expect(controller.lastValidationResult == .unknown)
        #expect(controller.lastValidationFinishedAt == nil)
        #expect(controller.lastLatencyMetrics == nil)
        #expect(controller.status == "Configuration changed. Revalidate before starting.")
        #expect(controller.phase == .idle)
    }

    @Test
    func wave14AppExecutionInvalidationLeavesValidationInFlightUntouched() {
        let controller = AppExecutionController()
        controller.phase = .validationRunning
        controller.lastValidationExitCode = 0
        controller.invalidateRuntimeEvidenceAfterConfigurationChange()
        #expect(controller.phase == .validationRunning)
        #expect(controller.lastValidationExitCode == 0)
    }

    @Test
    func wave14AppExecutionEvidenceArchiveKeepsOnlyPureSnapshots() {
        let controller = AppExecutionController()
        controller.archiveCurrentEvidenceForNextRun()
        #expect(controller.previousRunEvidence.isEmpty)

        controller.lastCommand = ["open-lola", "wave14"]
        controller.status = "Synthetic failure."
        controller.phase = .runFailed
        controller.lastExitCode = 1
        controller.lastError = "wave14"
        controller.archiveCurrentEvidenceForNextRun()
        #expect(controller.previousRunEvidence.count == 1)
        #expect(controller.previousRunEvidence.first?.commandLine.contains("wave14") == true)
    }

    private func hostMenuAction(_ id: String) throws {
        let action = try #require(NativeAppShellSurfaceContract.releaseReadiness.actions.first { $0.id == id })
        #expect(AppMenuActionGroup(actionID: id) != .unsupported)
        host(OpenLolaAppScene().appMenuActionButton(action), named: id)
    }

    private func host<Content: View>(
        _ content: Content,
        named name: String,
        expectsHostedSubviews: Bool = true
    ) {
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = CGRect(origin: .zero, size: Self.hostSize)
        hostingView.appearance = NSAppearance(named: .aqua)
        hostingView.layoutSubtreeIfNeeded()
        #expect(hostingView.bounds.size == Self.hostSize, "\(name) should receive a deterministic host frame.")
        if expectsHostedSubviews {
            #expect(hostingView.subviews.count > 0, "\(name) should construct a SwiftUI hosting hierarchy.")
        } else {
            #expect(hostingView.subviews.isEmpty, "\(name) should remain an EmptyView host.")
        }
    }

    private func isolatedDefaults(_ label: String) throws -> (name: String, defaults: UserDefaults) {
        let name = "open-lola-wave14-\(label)-\(UUID().uuidString)"
        return (name, try #require(UserDefaults(suiteName: name)))
    }

    private func temporaryDirectory(_ label: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-lola-wave14-\(label)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
