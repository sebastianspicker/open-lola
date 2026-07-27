// Verifies that native app shell operator prototype validates state and builds a command and two-peer plan.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func nativeAppShellReportStillRoundTripsItsPersistedFlatContract() throws {
    let report = NativeAppShellSyntheticSmoke.run()
    let data = try JSONEncoder().encode(report)
    let decoded = try NativeAppShellReport.decode(from: data)

    #expect(decoded == report)
}

@Test
func nativeAppShellOperatorPrototypeValidatesStateAndBuildsCommandAndTwoPeerPlan() throws {
    let state = operatorPrototypeState()

    try state.validate()
    assertOperatorPrototypeState(state)

    var commandState = operatorPrototypeState()
    commandState.directPeerCommandFields.videoCompression = .jpegXS
    let handoff = try commandState.localDirectPeerCommandHandoff()

    try handoff.validate()
    assertDirectPeerCommandHandoff(handoff)

    var planState = operatorPrototypeState()
    planState.directPeerCommandFields.videoCompression = .jpegXS
    let configuration = try planState.twoPeerRunPlanConfiguration()
    let report = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: configuration)

    try report.validate()
    assertTwoPeerPlan(configuration, report)
}

private func assertOperatorPrototypeState(_ state: NativeAppShellOperatorPrototypeState) {
    #expect(state.commandIntent == .runRequested)
    #expect(state.inventory.selection.audioInputUID == "rme-madi-uid")
    #expect(state.inventory.selection.audioOutputUID == "rme-madi-uid")
    #expect(state.inventory.selection.videoDeviceID == "atem-uid")
    #expect(state.remoteInventory.selection.audioInputUID == "remote-rme-input-uid")
    #expect(state.remoteInventory.selection.audioOutputUID == "remote-rme-output-uid")
    #expect(state.remoteInventory.selection.videoDeviceID == "remote-atem-uid")
    #expect(state.remoteOrchestrationEnabled == false)
    #expect(state.startsLongRunningProcess == false)
}

private func assertDirectPeerCommandHandoff(_ handoff: NativeAppShellLocalCommandHandoff) {
    #expect(handoff.intent == .runRequested)
    #expect(handoff.remoteOrchestrationEnabled == false)
    #expect(handoff.startsLongRunningProcess == false)
    #expect(handoff.command.arguments.starts(with: [
        ".build/debug/open-lola",
        "mac-to-mac-connection-preflight-run",
        "--local-peer-id",
        "mac-a"
    ]))
    #expect(argumentValue(handoff.command.arguments, "--remote-peer-id") == "mac-b")
    #expect(argumentValue(handoff.command.arguments, "--peer") == "192.0.2.20")
    #expect(argumentValue(handoff.command.arguments, "--output")?.contains("connection-preflight.json") == true)
    #expect(!handoff.command.arguments.contains("direct-p2p-session-run"))
    #expect(!handoff.command.arguments.contains("--media"))
    #expect(!handoff.command.arguments.contains("audio-video"))
    #expect(!handoff.command.arguments.contains("--input-uid"))
    #expect(!handoff.command.arguments.contains("--video-device-id"))
    #expect(handoff.command.arguments.contains("192.0.2.20"))
    #expect(handoff.command.displayCommand.contains("mac-to-mac-connection-preflight-run"))
}

private func assertTwoPeerPlan(
    _ configuration: DirectPeerTwoPeerRunPlanConfiguration,
    _ report: DirectPeerTwoPeerRunPlanReport
) {
    #expect(configuration.macA.inputUID == "rme-madi-uid")
    #expect(configuration.macA.outputUID == "rme-madi-uid")
    #expect(configuration.macA.videoDeviceID == "atem-uid")
    #expect(configuration.macB.inputUID == "remote-rme-input-uid")
    #expect(configuration.macB.outputUID == "remote-rme-output-uid")
    #expect(configuration.macB.videoDeviceID == "remote-atem-uid")
    #expect(configuration.videoCompression == .jpegXS)
    #expect(report.commands.flatMap(\.arguments).contains("jpeg-xs"))
    #expect(!report.commands.flatMap(\.arguments).contains("operator-select-mac-b-input-uid"))
    #expect(!report.commands.flatMap(\.arguments).contains("operator-select-mac-b-output-uid"))
}

// swiftlint:disable function_body_length
@Test
func nativeAppShellOperatorPrototypeRejectsInvalidSelectionsAndUnsafeSettings() throws {
    var state = operatorPrototypeState()
    state.inventory.selection.audioInputUID = nil

    try state.localDirectPeerCommandHandoff().validate()

    #expect(throws: NativeAppShellSurfaceValidationError.missingLocalCommandSelection("audioInputUID")) {
        _ = try state.twoPeerRunPlanConfiguration()
    }

    state = operatorPrototypeState()
    state.remoteInventory.selection.audioInputUID = nil

    #expect(throws: NativeAppShellSurfaceValidationError.missingRemoteCommandSelection("audioInputUID")) {
        _ = try state.twoPeerRunPlanConfiguration()
    }

    state = operatorPrototypeState()
    state.remoteInventory.selection.audioOutputUID = "missing-remote-output"

#expect(throws: NativeAppShellSurfaceValidationError.selectedRemoteAudioOutputUnavailable(
"missing-remote-output"
)) {
        try state.validate()
    }

    state = operatorPrototypeState()
    state.inventory.selection.audioInputUID = "missing-input"

    #expect(throws: NativeAppShellSurfaceValidationError.selectedAudioInputUnavailable("missing-input")) {
        try state.validate()
    }

    state = operatorPrototypeState()
    state.remoteOrchestrationEnabled = true

    #expect(throws: NativeAppShellSurfaceValidationError.operatorEnablesRemoteOrchestration) {
        try state.validate()
    }

    state = operatorPrototypeState()
    state.directPeerCommandFields.durationSeconds = 0

    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("durationSeconds")) {
        try state.twoPeerRunPlanConfiguration()
    }

    state = operatorPrototypeState()
    state.directPeerCommandFields.framesPerPacket = Int(UInt32.max) + 1

    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("framesPerPacket")) {
        try state.twoPeerRunPlanConfiguration()
    }

    state = operatorPrototypeState()
    state.directPeerCommandFields.sampleFormat = "float64"

    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("sampleFormat")) {
        try state.twoPeerRunPlanConfiguration()
    }

    state = operatorPrototypeState()
    state.directPeerCommandFields.videoPixelFormat = "uyvy"

    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("videoPixelFormat")) {
        try state.twoPeerRunPlanConfiguration()
    }

    state = operatorPrototypeState()
    state.directPeerCommandFields.videoPort = state.directPeerCommandFields.audioPort

    #expect(throws: NativeAppShellSurfaceValidationError.duplicateCommandPort("videoPort")) {
        try state.twoPeerRunPlanConfiguration()
    }

    var fields = NativeAppShellWindowsLoLaPeerFields.appDefault
    fields.videoFrameRate = Int.max
    fields.durationSeconds = 2

    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("mediaPacketCount")) {
        try fields.sessionArguments(executablePath: "/tmp/open-lola", dryRun: true)
    }
}
// swiftlint:enable function_body_length

@Test
func nativeAppShellSurfaceProbeReportsPartialReadinessAndRejectsFalsePass() throws {
    let sourceReport = NativeAppShellSyntheticSmoke.run()
    let report = NativeAppShellSurfaceProbe.run(sourceReport: sourceReport)

    try report.validate()

    #expect(report.id == "c11-native-app-shell-surface-probe")
    #expect(report.sourceReportId == sourceReport.id)
    #expect(report.verdict == .partial)
    #expect(report.launchProbePlan.requiresHumanVisibleWindow)
    #expect(report.launchProbePlan.recordsScreenshotOrLog)
    #expect(report.launchProbePlan.blocksFieldReadyPass)

    var passCandidate = report
    passCandidate.verdict = .pass

    #expect(throws: NativeAppShellSurfaceValidationError.passWhileLaunchProbeBlocksFieldReady) {
        try passCandidate.validate()
    }
}

@Test
func nativeAppShellExecutionSettingsRequireConnectionPreflightAndExplicitSSHFallback() throws {
    var localSettings = NativeAppShellExecutionSettings()
    localSettings.execute = true
    localSettings.executionMode = .local

    let localArguments = try localSettings.supervisorArguments(
        executablePath: "/tmp/OpenLoLa.app/Contents/MacOS/open-lola"
    )

    #expect(localArguments.contains("--connection-preflight-report"))
#expect(
argumentValue(localArguments, "--connection-preflight-report") == localSettings.connectionPreflightReportPath
)
    #expect(localArguments.contains("--executable"))
    #expect(argumentValue(localArguments, "--execution-mode") == "local")

    var missingPreflight = NativeAppShellExecutionSettings()
    missingPreflight.connectionPreflightReportPath = " "

    #expect(throws: NativeAppShellExecutionValidationError.preflightReportMissing("connectionPreflightReportPath")) {
        try missingPreflight.validate()
    }

    var sshSettings = NativeAppShellExecutionSettings()
    sshSettings.executionMode = .ssh

    #expect(throws: NativeAppShellExecutionValidationError.sshFallbackRequiresExplicitSelection) {
        _ = try sshSettings.supervisorArguments(executablePath: "/tmp/OpenLoLa.app/Contents/MacOS/open-lola")
    }

    sshSettings.sshFallbackExplicitlySelected = true

    #expect(throws: NativeAppShellExecutionValidationError.sshFallbackMissingReason) {
        _ = try sshSettings.supervisorArguments(executablePath: "/tmp/OpenLoLa.app/Contents/MacOS/open-lola")
    }

    sshSettings.sshFallbackReason = "operator selected lab SSH fallback after route policy review"
    sshSettings.macASSH = "operator@mac-a.local"
    sshSettings.macBSSH = "operator@mac-b.local"
    sshSettings.macAWorkingDirectory = "/opt/open-lola/a"
    sshSettings.macBWorkingDirectory = "/opt/open-lola/b"
    sshSettings.sshExecutable = "/opt/homebrew/bin/ssh"
    sshSettings.scpExecutable = "/opt/homebrew/bin/scp"

    let sshArguments = try sshSettings.supervisorArguments(
        executablePath: "/tmp/OpenLoLa.app/Contents/MacOS/open-lola"
    )

    #expect(argumentValue(sshArguments, "--execution-mode") == "ssh")
    #expect(argumentValue(sshArguments, "--ssh-fallback-explicit") == "true")
    #expect(argumentValue(sshArguments, "--ssh-fallback-reason") == sshSettings.sshFallbackReason)
    #expect(argumentValue(sshArguments, "--mac-a-ssh") == "operator@mac-a.local")
    #expect(argumentValue(sshArguments, "--mac-b-ssh") == "operator@mac-b.local")
    #expect(argumentValue(sshArguments, "--mac-a-workdir") == "/opt/open-lola/a")
    #expect(argumentValue(sshArguments, "--mac-b-workdir") == "/opt/open-lola/b")
    #expect(argumentValue(sshArguments, "--ssh-executable") == "/opt/homebrew/bin/ssh")
    #expect(argumentValue(sshArguments, "--scp-executable") == "/opt/homebrew/bin/scp")
    #expect(!sshArguments.contains("--executable"))
}

@Test
func nativeAppShellExecutionReportRejectsFalsePass() throws {
    var report = NativeAppShellExecutionReport(
        lifecycle: .init(
            command: [".build/debug/open-lola", "direct-p2p-two-peer-local-run"],
            startedAt: "2026-05-09T00:00:00Z",
            exitCode: 1
        ),
        artifacts: .init(stdoutPath: "/tmp/stdout.log", stderrPath: "/tmp/stderr.log"),
        validation: .init(exitCode: nil),
        outcome: .init(verdict: .pass, notes: "candidate")
    )

    #expect(throws: NativeAppShellExecutionValidationError.passWithoutSuccessfulExit) {
        try report.validate()
    }

    report.exitCode = 0
    #expect(throws: NativeAppShellExecutionValidationError.passWithoutValidatedReport) {
        try report.validate()
    }
}
