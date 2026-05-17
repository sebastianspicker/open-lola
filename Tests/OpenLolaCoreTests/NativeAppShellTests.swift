import Foundation
import Testing

@testable import OpenLolaCore


@Test
func nativeAppShellOperatorPrototypeValidatesStateAndBuildsCommandAndTwoPeerPlan() throws {
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

    var commandState = operatorPrototypeState()
    commandState.directPeerCommandFields.videoCompression = .jpegXS
    let handoff = try commandState.localDirectPeerCommandHandoff()

    try handoff.validate()

    #expect(handoff.intent == .runRequested)
    #expect(handoff.remoteOrchestrationEnabled == false)
    #expect(handoff.startsLongRunningProcess == false)
    #expect(handoff.command.arguments.starts(with: [
        ".build/debug/open-lola",
        "mac-to-mac-connection-preflight-run",
        "--local-peer-id",
        "mac-a",
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

    var planState = operatorPrototypeState()
    planState.directPeerCommandFields.videoCompression = .jpegXS
    let configuration = try planState.twoPeerRunPlanConfiguration()
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

    #expect(throws: NativeAppShellSurfaceValidationError.selectedRemoteAudioOutputUnavailable("missing-remote-output")) {
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

    let fields = NativeAppShellWindowsLoLaPeerFields(
        videoFrameRate: Int.max,
        durationSeconds: 2
    )

    #expect(throws: NativeAppShellSurfaceValidationError.invalidCommandField("mediaPacketCount")) {
        try fields.sessionArguments(executablePath: "/tmp/open-lola", dryRun: true)
    }
}

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
    #expect(argumentValue(localArguments, "--connection-preflight-report") == localSettings.connectionPreflightReportPath)
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

private func argumentValue(_ arguments: [String], _ flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
        return nil
    }
    return arguments[index + 1]
}
