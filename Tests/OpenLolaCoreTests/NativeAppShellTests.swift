import Foundation
import Testing

@testable import OpenLolaCore

@Test
func nativeAppShellFixtureDecodesAndValidates() throws {
    let report = try loadNativeAppShellFixture(named: "native-app-shell-partial")

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.configuration.profileName == "Synthetic Headless Profile")
    #expect(report.smokeProbe.appTargetName == "open-lola-app")
    #expect(report.realtimeBoundary.usesImmutableConfigSnapshots)
}

@Test
func nativeAppShellSyntheticSmokeEmitsPartialReport() throws {
    let report = NativeAppShellSyntheticSmoke.run()

    try report.validate()

    #expect(report.runMode == .synthetic)
    #expect(report.verdict == .partial)
    #expect(report.metricsObserver.readOnly)
    #expect(report.smokeProbe.runtimeSmokeProbed == false)
}

@Test
func nativeAppShellSurfaceContractCoversReleaseReadinessSections() throws {
    let contract = NativeAppShellSurfaceContract.releaseReadiness
    let sectionIDs = Set(contract.sections.map(\.id))

    #expect(sectionIDs == Set(NativeAppShellSurfaceSectionID.allCases))
    #expect(contract.sections.map(\.id) == [
        .overview,
        .session,
        .streams,
        .routing,
        .devices,
        .diagnostics,
        .validation,
        .packetMonitor,
        .settings,
    ])
    #expect(contract.sections.first { $0.id == .session }?.readOnly == false)
    #expect(contract.sections.first { $0.id == .streams }?.readOnly == false)
    #expect(contract.sections.first { $0.id == .devices }?.readOnly == false)
    #expect(contract.sections.first { $0.id == .packetMonitor }?.readOnly == true)
    #expect(contract.sections.first { $0.id == .validation }?.readOnly == true)
    #expect(contract.sections.allSatisfy { $0.mutatesRealtimeConfiguration == false })
    #expect(contract.actions.contains { $0.id == "refresh-synthetic-metrics" })
    #expect(contract.actions.contains { $0.id == "refresh-local-media-inventory" })
    #expect(contract.sections.contains { $0.id == .streams && $0.readOnly == false })
    #expect(contract.actions == NativeAppShellActionInventory.menuActions)
    #expect(contract.actions.contains { $0.id == "dry-run-supervisor" && $0.launchesExternalProcess })
    #expect(contract.actions.contains { $0.id == "start-armed-supervisor" && $0.launchesExternalProcess })
    #expect(contract.actions.contains { $0.id == "start-armed-supervisor" && $0.launchesExternalRealtimeProcess })
    #expect(contract.actions.contains { $0.id == "validate-supervisor-report" && $0.launchesExternalProcess })
    #expect(contract.actions.contains { $0.id == "open-local-preview-window" })
    #expect(contract.actions.contains { $0.id == "arm-execution" && $0.keyboardShortcut == "command-shift-e" })
    #expect(contract.actions.contains { $0.operatorCommandIntent == .runRequested })
    #expect(contract.actions.contains { $0.operatorCommandIntent == .stopRequested })
    #expect(contract.actions.contains { $0.id == "arm-execution" && $0.armsExecution })
    #expect(contract.actions.contains { $0.id == "arm-execution" && !$0.armsControlOutput })
    #expect(contract.actions.allSatisfy { $0.startsRealtimeAudio == false })
    #expect(contract.actions.allSatisfy { $0.startsRealtimeVideo == false })
    #expect(contract.actions.allSatisfy { $0.armsControlOutput == false })
    #expect(contract.launchProbePlan.appTargetName == "open-lola-app")
    #expect(contract.launchProbePlan.launchCommand == "./script/build_and_run.sh --verify")
    #expect(contract.launchProbePlan.recordsScreenshotOrLog)
    #expect(contract.launchProbePlan.blocksFieldReadyPass)
}

@Test
func nativeAppShellSectionSearchFiltersReleaseReadinessSectionsByTitleAndIdentifier() throws {
    let sections = NativeAppShellSurfaceContract.releaseReadiness.sections

    #expect(NativeAppShellSectionSearch.visibleSections(sections, query: "").map(\.id) == sections.map(\.id))
    #expect(NativeAppShellSectionSearch.visibleSections(sections, query: "packet").map(\.id) == [.packetMonitor])
    #expect(NativeAppShellSectionSearch.visibleSections(sections, query: "VALIDATION").map(\.id) == [.validation])
    #expect(NativeAppShellSectionSearch.visibleSections(sections, query: "  session  ").map(\.id) == [.session])
}

@Test
func nativeAppPacketMonitorRowsFilterByStreamAndSearchFields() throws {
    let report = lolaCompatibilityCaptureReportForAppShell()

    let allRows = try NativeAppPacketMonitorRows.rows(report: report, limit: 10)
    let audioRows = try NativeAppPacketMonitorRows.rows(report: report, streamFilter: .audio, limit: 10)
    let videoRows = try NativeAppPacketMonitorRows.rows(report: report, streamFilter: .video, limit: 10)
    let candidateRows = try NativeAppPacketMonitorRows.rows(report: report, searchText: "mjpeg", limit: 10)
    let destinationRows = try NativeAppPacketMonitorRows.rows(report: report, searchText: "198.51.100.20", limit: 10)

    #expect(allRows.map(\.id) == [1, 2, 3])
    #expect(audioRows.map(\.id) == [1])
    #expect(videoRows.map(\.id) == [2])
    #expect(candidateRows.map(\.id) == [2])
    #expect(destinationRows.map(\.id) == [3])
}

@Test
func nativeAppPacketMonitorRowsExposeUnclippedAccessibilityLabels() throws {
    let report = lolaCompatibilityCaptureReportForAppShell()
    let rows = try NativeAppPacketMonitorRows.rows(report: report, streamFilter: .video, limit: 10)
    let label = try #require(rows.first?.accessibilityLabel)

    #expect(label.contains("Packet 2"))
    #expect(label.contains("stream video"))
    #expect(label.contains("from 192.0.2.11:7000 to 198.51.100.10:7000"))
    #expect(label.contains("payload 512 B"))
    #expect(label.contains("candidate mjpeg"))
}

@Test
func nativeAppPacketMonitorRowsRejectNegativeLimit() throws {
    let report = lolaCompatibilityCaptureReportForAppShell()

    #expect(throws: NativeAppPacketMonitorRowsError.negativeLimit(-1)) {
        _ = try NativeAppPacketMonitorRows.rows(report: report, limit: -1)
    }
}

@Test
func nativeAppShellOperatorPrototypeStateValidatesLocalSelectionAndIntentBoundary() throws {
    let state = operatorPrototypeState()

    try state.validate()

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

@Test
func nativeAppShellOperatorPrototypeBuildsLocalDirectPeerCommandFromSelection() throws {
    var state = operatorPrototypeState()
    state.directPeerCommandFields.videoCompression = .jpegXS
    let handoff = try state.localDirectPeerCommandHandoff()

    try handoff.validate()

    #expect(handoff.intent == .runRequested)
    #expect(handoff.remoteOrchestrationEnabled == false)
    #expect(handoff.startsLongRunningProcess == false)
    #expect(handoff.command.arguments.starts(with: [
        ".build/debug/open-lola",
        "direct-p2p-session-run",
        "--media",
        "audio-video",
    ]))
    #expect(handoff.command.arguments.contains("--input-uid"))
    #expect(handoff.command.arguments.contains("rme-madi-uid"))
    #expect(handoff.command.arguments.contains("--output-uid"))
    #expect(handoff.command.arguments.contains("--video-device-id"))
    #expect(handoff.command.arguments.contains("atem-uid"))
    #expect(handoff.command.arguments.contains("--video-compression"))
    #expect(handoff.command.arguments.contains("jpeg-xs"))
    #expect(handoff.command.arguments.contains("--local-host"))
    #expect(handoff.command.arguments.contains("192.0.2.10"))
    #expect(handoff.command.arguments.contains("--remote-host"))
    #expect(handoff.command.arguments.contains("192.0.2.20"))
    #expect(handoff.command.displayCommand.contains("direct-p2p-session-run --media audio-video"))
}

@Test
func nativeAppShellOperatorPrototypeBuildsTwoPeerPlanFromLocalAndRemoteSelections() throws {
    var state = operatorPrototypeState()
    state.directPeerCommandFields.videoCompression = .jpegXS
    let configuration = try state.twoPeerRunPlanConfiguration()
    let report = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: configuration)

    try report.validate()

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

@Test
func nativeAppShellOperatorPrototypeRejectsCommandWithoutSelectedInput() throws {
    var state = operatorPrototypeState()
    state.inventory.selection.audioInputUID = nil

    #expect(throws: NativeAppShellSurfaceValidationError.missingLocalCommandSelection("audioInputUID")) {
        _ = try state.localDirectPeerCommandHandoff()
    }
}

@Test
func nativeAppShellOperatorPrototypeRejectsTwoPeerPlanWithoutSelectedRemoteInput() throws {
    var state = operatorPrototypeState()
    state.remoteInventory.selection.audioInputUID = nil

    #expect(throws: NativeAppShellSurfaceValidationError.missingRemoteCommandSelection("audioInputUID")) {
        _ = try state.twoPeerRunPlanConfiguration()
    }
}

@Test
func nativeAppShellOperatorPrototypeRejectsUnavailableRemoteSelection() throws {
    var state = operatorPrototypeState()
    state.remoteInventory.selection.audioOutputUID = "missing-remote-output"

    #expect(throws: NativeAppShellSurfaceValidationError.selectedRemoteAudioOutputUnavailable("missing-remote-output")) {
        try state.validate()
    }
}

@Test
func nativeAppShellOperatorPrototypeRejectsUnavailableSelection() throws {
    var state = operatorPrototypeState()
    state.inventory.selection.audioInputUID = "missing-input"

    #expect(throws: NativeAppShellSurfaceValidationError.selectedAudioInputUnavailable("missing-input")) {
        try state.validate()
    }
}

@Test
func nativeAppShellOperatorPrototypeRejectsRemoteOrchestration() throws {
    var state = operatorPrototypeState()
    state.remoteOrchestrationEnabled = true

    #expect(throws: NativeAppShellSurfaceValidationError.operatorEnablesRemoteOrchestration) {
        try state.validate()
    }
}

@Test
func nativeAppShellCommandSettingsRejectInvalidPositiveFields() throws {
    var state = operatorPrototypeState()
    state.directPeerCommandFields.durationSeconds = 0

    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("durationSeconds")) {
        try state.twoPeerRunPlanConfiguration()
    }
}

@Test
func nativeAppShellCommandSettingsRejectFramesOutsideUInt32Range() throws {
    var state = operatorPrototypeState()
    state.directPeerCommandFields.framesPerPacket = Int(UInt32.max) + 1

    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("framesPerPacket")) {
        try state.twoPeerRunPlanConfiguration()
    }
}

@Test
func nativeAppShellCommandSettingsRejectInvalidFormatFields() throws {
    var state = operatorPrototypeState()
    state.directPeerCommandFields.sampleFormat = "float64"

    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("sampleFormat")) {
        try state.twoPeerRunPlanConfiguration()
    }

    state = operatorPrototypeState()
    state.directPeerCommandFields.videoPixelFormat = "uyvy"

    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("videoPixelFormat")) {
        try state.twoPeerRunPlanConfiguration()
    }
}

@Test
func nativeAppShellCommandSettingsRejectDuplicatePorts() throws {
    var state = operatorPrototypeState()
    state.directPeerCommandFields.videoPort = state.directPeerCommandFields.audioPort

    #expect(throws: NativeAppShellSurfaceValidationError.duplicateCommandPort("videoPort")) {
        try state.twoPeerRunPlanConfiguration()
    }
}

@Test
func nativeAppShellWindowsLoLaSettingsRejectMediaPacketCountOverflow() throws {
    let fields = NativeAppShellWindowsLoLaPeerFields(
        videoFrameRate: Int.max,
        durationSeconds: 2
    )

    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("mediaPacketCount")) {
        try fields.sessionArguments(executablePath: "/tmp/open-lola", dryRun: true)
    }
}

@Test
func nativeAppShellOperatorStateDocumentsSendableSnapshotMutationBoundary() throws {
    let source = try readNativeAppShellRepositoryText(
        "Sources/OpenLolaCore/Platform/NativeAppShellOperatorState.swift"
    )

    #expect(source.contains("Value-semantic operator-surface snapshot."))
    #expect(source.contains("`Sendable` is for transferring complete snapshots"))
    #expect(source.contains("Shared mutable access is not supported"))
    #expect(source.contains("MainActor-owned `@State`/`Binding`"))
    #expect(source.contains("background work must receive"))
}

@Test
func nativeAppShellSurfaceProbeEmitsPartialLaunchReadinessReport() throws {
    let sourceReport = NativeAppShellSyntheticSmoke.run()
    let report = NativeAppShellSurfaceProbe.run(sourceReport: sourceReport)

    try report.validate()

    #expect(report.id == "c11-native-app-shell-surface-probe")
    #expect(report.sourceReportId == sourceReport.id)
    #expect(report.verdict == .partial)
    #expect(report.launchProbePlan.requiresHumanVisibleWindow)
    #expect(report.launchProbePlan.recordsScreenshotOrLog)
    #expect(report.launchProbePlan.blocksFieldReadyPass)
}

@Test
func nativeAppShellSurfaceProbeRejectsPassWhileLaunchProbeBlocksFieldReadiness() throws {
    var report = NativeAppShellSurfaceProbe.run(sourceReport: NativeAppShellSyntheticSmoke.run())
    report.verdict = .pass

    #expect(throws: NativeAppShellSurfaceValidationError.passWhileLaunchProbeBlocksFieldReady) {
        try report.validate()
    }
}

@Test
func nativeAppShellExecutionSettingsBuildLocalSupervisorArgumentsWithPackagedCLI() throws {
    var settings = NativeAppShellExecutionSettings()
    settings.execute = true
    settings.executionMode = .local

    let arguments = try settings.supervisorArguments(executablePath: "/tmp/OpenLoLa.app/Contents/MacOS/open-lola")

    #expect(arguments.starts(with: [
        "/tmp/OpenLoLa.app/Contents/MacOS/open-lola",
        "direct-p2p-two-peer-local-run",
        "--plan",
        settings.planPath,
    ]))
    #expect(arguments.contains("--executable"))
    #expect(arguments.contains("/tmp/OpenLoLa.app/Contents/MacOS/open-lola"))
    #expect(arguments.contains("--execute"))
    #expect(arguments.contains("true"))
    #expect(arguments.contains("--execution-mode"))
    #expect(arguments.contains("local"))
}

@Test
func nativeAppShellExecutionDefaultsUseApplicationSupportPaths() {
    let settings = NativeAppShellExecutionSettings()

    #expect(settings.planPath.contains("Application Support/OpenLoLa/MacToMac/plan.json"))
    #expect(settings.supervisorReportPath.contains("Application Support/OpenLoLa/MacToMac/supervisor.json"))
    #expect(!settings.planPath.hasPrefix("/tmp/"))
    #expect(!settings.supervisorReportPath.hasPrefix("/tmp/"))
}

@Test
func nativeAppShellExecutionSettingsKeepSSHChildExecutableRemoteConfigured() throws {
    var settings = NativeAppShellExecutionSettings()
    settings.execute = true
    settings.executionMode = .ssh

    let arguments = try settings.supervisorArguments(executablePath: "/tmp/OpenLoLa.app/Contents/MacOS/open-lola")

    #expect(arguments.starts(with: [
        "/tmp/OpenLoLa.app/Contents/MacOS/open-lola",
        "direct-p2p-two-peer-local-run",
        "--plan",
        settings.planPath,
    ]))
    #expect(arguments.contains("--execute"))
    #expect(arguments.contains("true"))
    #expect(arguments.contains("--execution-mode"))
    #expect(arguments.contains("ssh"))
    #expect(arguments.contains("--mac-a-ssh"))
    #expect(arguments.contains("mac-a.local"))
    #expect(arguments.contains("--require-preflight"))
    #expect(!arguments.contains("--executable"))
    #expect(!arguments.dropFirst().contains("/tmp/OpenLoLa.app/Contents/MacOS/open-lola"))
}

@Test
func nativeAppShellExecutionSettingsIncludeConfiguredSSHFields() throws {
    var settings = NativeAppShellExecutionSettings()
    settings.execute = true
    settings.executionMode = .ssh
    settings.macASSH = "operator@mac-a.local"
    settings.macBSSH = "operator@mac-b.local"
    settings.macAWorkingDirectory = "/opt/open-lola/a"
    settings.macBWorkingDirectory = "/opt/open-lola/b"
    settings.sshExecutable = "/opt/homebrew/bin/ssh"
    settings.scpExecutable = "/opt/homebrew/bin/scp"

    let arguments = try settings.supervisorArguments(executablePath: "/tmp/OpenLoLa.app/Contents/MacOS/open-lola")

    #expect(argumentValue(arguments, "--mac-a-ssh") == "operator@mac-a.local")
    #expect(argumentValue(arguments, "--mac-b-ssh") == "operator@mac-b.local")
    #expect(argumentValue(arguments, "--mac-a-workdir") == "/opt/open-lola/a")
    #expect(argumentValue(arguments, "--mac-b-workdir") == "/opt/open-lola/b")
    #expect(argumentValue(arguments, "--ssh-executable") == "/opt/homebrew/bin/ssh")
    #expect(argumentValue(arguments, "--scp-executable") == "/opt/homebrew/bin/scp")
}

@Test
func nativeAppShellExecutionReportRejectsFalsePass() throws {
    var report = NativeAppShellExecutionReport(
        command: [".build/debug/open-lola", "direct-p2p-two-peer-local-run"],
        startedAt: "2026-05-09T00:00:00Z",
        exitCode: 1,
        stdoutPath: "/tmp/stdout.log",
        stderrPath: "/tmp/stderr.log",
        validationExitCode: nil,
        verdict: .pass,
        notes: "candidate"
    )

    #expect(throws: NativeAppShellExecutionValidationError.passWithoutSuccessfulExit) {
        try report.validate()
    }

    report.exitCode = 0
    #expect(throws: NativeAppShellExecutionValidationError.passWithoutValidatedReport) {
        try report.validate()
    }
}

@Test
func nativeAppRuntimeSmokeConfigurationParsesRequiredArguments() throws {
    let configuration = try NativeAppRuntimeSmokeConfiguration.parse([
        "--headless-report", "reports/m10-integrated-av.json",
        "--output", "reports/m13-native-app-runtime-smoke.json",
    ])

    #expect(configuration.headlessReportPath == "reports/m10-integrated-av.json")
    #expect(configuration.outputPath == "reports/m13-native-app-runtime-smoke.json")
}

@Test
func nativeAppRuntimeSmokeConfigurationRejectsMissingOutput() {
    #expect(throws: NativeAppRuntimeSmokeConfigurationError.missingRequiredArgument("--output")) {
        _ = try NativeAppRuntimeSmokeConfiguration.parse([
            "--headless-report", "reports/m10-integrated-av.json",
        ])
    }
}

@Test
func nativeAppRuntimeSmokeBuildsPartialReportFromHeadlessMetrics() throws {
    let headlessReport = IntegratedHeadlessAvSyntheticSmoke.run()
    let configuration = NativeAppRuntimeSmokeConfiguration(
        headlessReportPath: "reports/m10-integrated-av.json",
        outputPath: "reports/m13-native-app-runtime-smoke.json"
    )

    let report = NativeAppRuntimeSmoke.run(
        configuration: configuration,
        headlessReport: headlessReport
    )

    try report.validate()

    #expect(report.id == "m13-native-app-runtime-smoke")
    #expect(report.runMode == .measured)
    #expect(report.verdict == .partial)
    #expect(report.configuration.immutableHandoff)
    #expect(report.configuration.requestedPlayoutTargetFrames == headlessReport.audio.integratedPlayoutTargetFrames)
    #expect(report.metricsObserver.readOnly)
    #expect(report.metricsObserver.blocksRealtimePaths == false)
    #expect(report.realtimeBoundary.uiOwnsAudioLane == false)
    #expect(report.smokeProbe.runtimeSmokeProbed)
    #expect(report.smokeProbe.comparedWithCLIMetrics)
    #expect(report.smokeProbe.cliMetricsReportId == headlessReport.id)
}

private func operatorPrototypeState() -> NativeAppShellOperatorPrototypeState {
    NativeAppShellOperatorPrototypeState(
        inventory: NativeAppShellLocalMediaInventory(
            capturedAt: "2026-05-09T00:00:00Z",
            hostName: "test-host",
            audioDevices: [
                NativeAppShellAudioDeviceOption(
                    name: "RME MADI",
                    uid: "rme-madi-uid",
                    inputChannelCount: 64,
                    outputChannelCount: 64,
                    nominalSampleRateHertz: 48_000,
                    currentBufferFrameSize: 32
                ),
                NativeAppShellAudioDeviceOption(
                    name: "Output Only",
                    uid: "output-only-uid",
                    inputChannelCount: 0,
                    outputChannelCount: 2,
                    nominalSampleRateHertz: 48_000,
                    currentBufferFrameSize: 64
                ),
            ],
            videoDevices: [
                NativeAppShellVideoDeviceOption(
                    label: "ATEM Mini Pro ISO",
                    uniqueId: "atem-uid",
                    manufacturer: "Blackmagic Design",
                    transport: "USB",
                    sourcePolicy: .blackmagicFirstAvFoundationFallback,
                    formatCount: 2
                ),
            ],
            selection: NativeAppShellLocalMediaSelection(
                audioInputUID: "rme-madi-uid",
                audioOutputUID: "rme-madi-uid",
                videoDeviceID: "atem-uid"
            ),
            inventoryErrors: []
        ),
        remoteInventory: NativeAppShellLocalMediaInventory(
            capturedAt: "2026-05-09T00:00:00Z",
            hostName: "remote-test-host",
            audioDevices: [
                NativeAppShellAudioDeviceOption(
                    name: "Remote RME Input",
                    uid: "remote-rme-input-uid",
                    inputChannelCount: 64,
                    outputChannelCount: 0,
                    nominalSampleRateHertz: 48_000,
                    currentBufferFrameSize: 32
                ),
                NativeAppShellAudioDeviceOption(
                    name: "Remote RME Output",
                    uid: "remote-rme-output-uid",
                    inputChannelCount: 0,
                    outputChannelCount: 64,
                    nominalSampleRateHertz: 48_000,
                    currentBufferFrameSize: 32
                ),
            ],
            videoDevices: [
                NativeAppShellVideoDeviceOption(
                    label: "Remote ATEM",
                    uniqueId: "remote-atem-uid",
                    manufacturer: "Blackmagic Design",
                    transport: "USB",
                    sourcePolicy: .blackmagicFirstAvFoundationFallback,
                    formatCount: 2
                ),
            ],
            selection: NativeAppShellLocalMediaSelection(
                audioInputUID: "remote-rme-input-uid",
                audioOutputUID: "remote-rme-output-uid",
                videoDeviceID: "remote-atem-uid"
            ),
            inventoryErrors: []
        ),
        commandIntent: .runRequested,
        remoteOrchestrationEnabled: false,
        startsLongRunningProcess: false,
        directPeerCommandFields: NativeAppShellDirectPeerCommandFields(
            role: .initiator,
            localPeer: "mac-a",
            remotePeer: "mac-b",
            localHost: "192.0.2.10",
            remoteHost: "192.0.2.20",
            controlPort: 57_000,
            remoteControlPort: 57_010,
            audioPort: 57_001,
            videoPort: 57_002,
            metricsPort: 57_003,
            outputPath: "/tmp/open-lola-app/direct-p2p-session-local.json",
            durationSeconds: 30,
            channelCount: 64,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            sampleFormat: "float32",
            videoWidth: 1_280,
            videoHeight: 720,
            videoPixelFormat: "bgra8",
            videoFrameRate: 30,
            videoStreamID: 101,
            avProfile: .fastest,
            preview: .on,
            timeoutSeconds: 30
        )
    )
}

private func lolaCompatibilityCaptureReportForAppShell() -> LoLaCompatibilityCaptureReport {
    let packets = [
        LoLaCompatibilityCapturePacketReport(
            index: 1,
            capturedLength: 80,
            originalLength: 80,
            stream: .audio,
            sourceIP: "192.0.2.10",
            destinationIP: "198.51.100.10",
            sourcePort: 7000,
            destinationPort: 7000,
            payloadLength: 48,
            mediaEnvelopeValid: true,
            mediaPayloadCandidate: .rawAudio
        ),
        LoLaCompatibilityCapturePacketReport(
            index: 2,
            capturedLength: 544,
            originalLength: 544,
            stream: .video,
            sourceIP: "192.0.2.11",
            destinationIP: "198.51.100.10",
            sourcePort: 7000,
            destinationPort: 7000,
            payloadLength: 512,
            mediaEnvelopeValid: true,
            mediaPayloadCandidate: .mjpeg
        ),
        LoLaCompatibilityCapturePacketReport(
            index: 3,
            capturedLength: 64,
            originalLength: 64,
            stream: .control,
            sourceIP: "192.0.2.12",
            destinationIP: "198.51.100.20",
            sourcePort: 7000,
            destinationPort: 7000,
            payloadLength: 32,
            controlMessageName: "MESG_QUICKCONN"
        ),
    ]
    return LoLaCompatibilityCaptureReport(
        id: "app-shell-capture",
        title: "App shell packet monitor capture",
        capturedAt: "2026-05-10T00:00:00Z",
        inputPath: "fixtures/app-shell.pcapng",
        inputFormat: .pcapng,
        summary: LoLaCompatibilityCaptureSummary(packets: packets),
        packets: packets,
        verdict: .partial,
        evidenceBoundary: "synthetic app packet monitor behavior",
        notes: "Synthetic app shell packet monitor fixture."
    )
}

private func passCandidateReport() throws -> NativeAppShellReport {
    var report = try loadNativeAppShellFixture(named: "native-app-shell-partial")
    report.verdict = .pass
    report.smokeProbe.appTargetBuilds = true
    report.smokeProbe.runtimeSmokeProbed = true
    report.smokeProbe.comparedWithCLIMetrics = true
    return report
}

private func loadNativeAppShellFixture(named name: String) throws -> NativeAppShellReport {
    let url = try nativeAppShellFixtureURL(named: name)
    return try NativeAppShellReport.decode(from: Data(contentsOf: url))
}

private func nativeAppShellFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "NativeAppShellReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "NativeAppShellReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}

private func readNativeAppShellRepositoryText(_ relativePath: String) throws -> String {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)
}

private func argumentValue(_ arguments: [String], _ flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
        return nil
    }
    return arguments[index + 1]
}
