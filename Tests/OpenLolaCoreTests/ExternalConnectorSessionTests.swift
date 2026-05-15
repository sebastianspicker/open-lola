import Foundation
import Darwin
import Testing

@testable import OpenLolaCore

@Test
func ultraGridPlanUsesUvTransmitAndReceiveProtocolPorts() throws {
    let tx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ug-tx.json"
    ))
    let rx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "198.51.100.20",
        outputPath: "/tmp/ug-rx.json"
    ))

    #expect(tx.executable == "uv")
    #expect(tx.arguments.contains("-t"))
    #expect(tx.arguments.contains("-s"))
    #expect(tx.arguments.contains("5004:5004:5006:5006"))
    #expect(rx.arguments.contains("-d"))
    #expect(rx.arguments.contains("-r"))
    #expect(rx.videoPort == 5004)
    #expect(rx.audioPort == 5006)
    #expect(tx.mediaProfile.mode == .audioVideo)
    #expect(tx.mediaProfile.audioEnabled)
    #expect(tx.mediaProfile.videoEnabled)
    #expect(tx.sourceReferences.contains("https://github.com/CESNET/UltraGrid"))
    #expect(tx.sourceReferences.contains("https://raw.githubusercontent.com/CESNET/UltraGrid/master/README.md"))
    #expect(tx.sourceReferences.contains("https://github.com/CESNET/UltraGrid/wiki/NAT-traversal"))
}

@Test
func jackTripPlanUsesServerClientModesAndAudioPort() throws {
    let tx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-tx.json",
        audioPort: 4465,
        peerAudioPort: 4464,
        channels: 8
    ))
    let rx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .rx,
        peer: "",
        outputPath: "/tmp/jacktrip-rx.json",
        channels: 8
    ))

    #expect(tx.executable == "jacktrip")
    #expect(tx.arguments.starts(with: ["-c", "203.0.113.10"]))
    #expect(tx.arguments.contains("-R"))
    #expect(tx.arguments.contains("-n"))
    #expect(tx.arguments.contains("8"))
    #expect(commandValue(tx.arguments, "-q") == "4")
    #expect(commandValue(tx.arguments, "-r") == "1")
    #expect(commandValue(tx.arguments, "-B") == "4465")
    #expect(commandValue(tx.arguments, "-P") == "4464")
    #expect(tx.protocolFacts.contains { $0.contains("client mode targets the peer audio port") })
    #expect(rx.arguments.first == "-s")
    #expect(rx.arguments.contains("-R"))
    #expect(commandValue(rx.arguments, "-B") == "4464")
    #expect(commandValue(rx.arguments, "-P") == nil)
    #expect(rx.audioPort == 4464)
    #expect(rx.videoPort == 5004)
    #expect(tx.mediaProfile.mode == .audio)
    #expect(tx.mediaProfile.audioEnabled)
    #expect(!tx.mediaProfile.videoEnabled)
    #expect(tx.auxiliaryProcesses.isEmpty)
    #expect(tx.sourceReferences.contains("https://github.com/jacktrip/jacktrip"))
    #expect(tx.sourceReferences.contains("https://raw.githubusercontent.com/jacktrip/jacktrip/main/src/Settings.cpp"))
    #expect(tx.sourceReferences.contains("https://jacktrip.github.io/jacktrip/"))
}

@Test
func jackTripPlanUsesExplicitQueueRedundancyAndPeerAudioPort() throws {
    let tx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-tx-tuned.json",
        peerAudioPort: 4470,
        jackTrip: JackTripRunConfiguration(queueDepth: 6, redundancy: 2)
    ))

    #expect(commandValue(tx.arguments, "-q") == "6")
    #expect(commandValue(tx.arguments, "-r") == "2")
    #expect(commandValue(tx.arguments, "-P") == "4470")
}

@Test
func jackTripTransmitRequiresExplicitPeerAudioPort() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-missing-peer-port.json"
    )

    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument("--peer-audio-port")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    }
}

@Test
func jackTripAudioVideoPairsJackTripAudioWithUltraGridVideo() throws {
    let tx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-av-tx.json",
        mediaMode: .audioVideo,
        peerAudioPort: 4464
    ))
    let rx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .rx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-av-rx.json",
        mediaMode: .audioVideo
    ))

    #expect(tx.executable == "jacktrip")
    #expect(tx.arguments.starts(with: ["-c", "203.0.113.10"]))
    #expect(tx.arguments.contains("-R"))
    #expect(tx.mediaProfile.mode == .audioVideo)
    #expect(tx.mediaProfile.audioEnabled)
    #expect(tx.mediaProfile.videoEnabled)
    #expect(tx.auxiliaryProcesses.count == 1)
    #expect(tx.auxiliaryProcesses[0].executable == "uv")
    #expect(tx.auxiliaryProcesses[0].arguments.contains("-t"))
    #expect(tx.auxiliaryProcesses[0].arguments.contains("5004:5004"))
    #expect(rx.arguments.first == "-s")
    #expect(rx.auxiliaryProcesses.count == 1)
    #expect(rx.auxiliaryProcesses[0].arguments.contains("-d"))
    #expect(rx.auxiliaryProcesses[0].arguments.contains("5004:5004"))
    #expect(rx.auxiliaryProcesses[0].arguments.last == "203.0.113.10")
    #expect(tx.protocolFacts.contains { $0.contains("audio-video mode pairs JackTrip audio") })
    #expect(tx.sourceReferences.contains("https://github.com/CESNET/UltraGrid"))
}

@Test
func jackTripRejectsVideoOnlyMode() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .rx,
        peer: "",
        outputPath: "/tmp/jacktrip-video.json",
        mediaMode: .video
    )

    #expect(throws: ExternalConnectorSessionError.connectorDoesNotSupportMediaMode(.jackTrip, .video)) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    }
}

@Test
func ultraGridRejectsAudioOnlyModeUntilPureAudioCommandIsSourceBacked() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "",
        outputPath: "/tmp/ug-audio.json",
        mediaMode: .audio
    )

    #expect(throws: ExternalConnectorSessionError.connectorDoesNotSupportMediaMode(.mvtpUltraGrid, .audio)) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    }
}

@Test
func ultraGridRejectsZeroPortBeforePortMapConstruction() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .txRx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ug-zero-video-port.json",
        videoPort: 0
    )

    #expect(throws: ExternalConnectorSessionError.invalidPort("videoPort", "0")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    }
}

@Test
func ultraGridRejectsOptionLikeModuleArguments() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ug-option-video-capture.json",
        videoCapture: "--help"
    )

    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("videoCapture", "--help")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    }
}

@Test
func ultraGridAllowsWhitespaceDeviceNamesAsSingleArguments() throws {
    let plan = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .txRx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ug-whitespace-devices.json",
        audioCapture: "Studio Input 1",
        audioPlayback: "Studio Output 1",
        videoCapture: "decklink:device=Studio Camera 1",
        videoDisplay: "DeckLink Studio Display"
    ))

    #expect(commandValue(plan.arguments, "-s") == "Studio Input 1")
    #expect(commandValue(plan.arguments, "-r") == "Studio Output 1")
    #expect(commandValue(plan.arguments, "-t") == "decklink:device=Studio Camera 1")
    #expect(commandValue(plan.arguments, "-d") == "DeckLink Studio Display")
}

@Test
func jackTripAuxiliaryVideoRejectsOptionLikeCaptureArgument() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-av-option-video-capture.json",
        mediaMode: .audioVideo,
        peerAudioPort: 4464,
        videoCapture: "--help"
    )

    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("videoCapture", "--help")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    }
}

@Test
func jackTripAllowsWhitespaceAudioDeviceNamesAsSingleArguments() throws {
    let plan = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-whitespace-devices.json",
        peerAudioPort: 4464,
        audioCapture: "RME MADI Input 1",
        audioPlayback: "RME MADI Output 1"
    ))

    #expect(commandValue(plan.arguments, "--audioinputdevice") == "RME MADI Input 1")
    #expect(commandValue(plan.arguments, "--audiooutputdevice") == "RME MADI Output 1")
}

@Test
func ultraGridValidatesUdpPortAvailabilityBeforeLaunch() throws {
    let source = try readExternalConnectorSource(
        "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift"
    )

    #expect(source.contains("validateExternalConnectorInvocationPreflight(invocation)"))
    #expect(source.contains("invocation.connector == .mvtpUltraGrid"))
    #expect(source.contains("bind(descriptor"))
    #expect(source.contains("defer { close(descriptor) }"))
}

@Test
func lolaControlRuntimeErrorsUseExplicitEmptyGuard() throws {
    let source = try readExternalConnectorSource(
        "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRunner.swift"
    )

    #expect(source.contains("let runtimeErrors = ["))
    #expect(source.contains("let runtimeError = runtimeErrors.isEmpty ? nil : runtimeErrors.joined(separator: \"; \")"))
    #expect(source.contains("verdict: runtimeError == nil ? .partial : .fail"))
}

@Test
func externalConnectorSessionRejectsTransmitWithoutPeer() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "",
        outputPath: "/tmp/jacktrip-tx.json"
    )

    #expect(throws: ExternalConnectorSessionError.connectorRequiresPeerForTx(.jackTrip)) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    }
}

@Test
func lolaPlanRejectsNonNumericSessionIDBecauseRecoveredSidIsInteger() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .tx,
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-invalid-session.json",
        sessionID: "sid-1"
    )

    #expect(throws: ExternalConnectorSessionError.invalidLoLaSessionID("sid-1")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    }
}

@Test
func externalConnectorLaunchPlanRejectsNegativeDurationAndZeroPorts() throws {
    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger("durationSeconds", "-1")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-negative-duration.json",
            durationSeconds: -1
        ))
    }

    #expect(throws: ExternalConnectorSessionError.invalidPort("controlPort", "0")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/lola-zero-control-port.json",
            controlPort: 0
        ))
    }
}

@Test
func externalConnectorSessionDryRunReportValidatesAsPartial() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-session.json",
        peerAudioPort: 4464
    )

    let report = try ExternalConnectorSessionRunner.run(configuration: configuration)

    try report.validate()
    #expect(report.dryRun)
    #expect(report.verdict == .partial)
    #expect(report.process == nil)
}

@Test
func jackTripAudioVideoDryRunReportValidatesAuxiliaryVideoPlan() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-av-session.json",
        mediaMode: .audioVideo,
        peerAudioPort: 4464
    )

    let report = try ExternalConnectorSessionRunner.run(configuration: configuration)

    try report.validate()
    #expect(report.dryRun)
    #expect(report.plan.auxiliaryProcesses.count == 1)
    #expect(report.plan.auxiliaryProcesses[0].label == "jacktrip-auxiliary-ultragrid-video")
    #expect(report.auxiliaryProcesses.isEmpty)
}

@Test
func jackTripAudioVideoProcessRunLaunchesAudioAndAuxiliaryVideo() throws {
    let processRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 47_001,
            terminatedAfterDuration: true
        ),
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 47_002,
            terminatedAfterDuration: true
        ),
    ])
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        executable: "/definitely/not/jacktrip",
        videoExecutable: "/definitely/not/uv",
        outputPath: "/tmp/jacktrip-av-process.json",
        dryRun: false,
        mediaMode: .audioVideo,
        peerAudioPort: 4464
    )

    let report = try ExternalConnectorSessionRunner.run(configuration: configuration, processRunner: processRunner)

    try report.validate()
    #expect(report.process?.launched == true)
    #expect(report.auxiliaryProcesses.count == 1)
    #expect(report.auxiliaryProcesses[0].launched)
    #expect(report.plan.auxiliaryProcesses[0].mediaMode == .video)
    #expect(processRunner.invocations.map(\.executable) == [
        "/definitely/not/jacktrip",
        "/definitely/not/uv",
    ])
}

@Test
func lolaControlLoopbackExchangesQuickConnectAck() async throws {
    try await SocketHeavyTestGate.shared.run {
        var reports: (tx: ExternalConnectorSessionReport, rx: ExternalConnectorSessionReport)?
        for _ in 0..<3 {
            let controlPort = try freeLoopbackUdpPort()
            let mediaPorts: (audio: UInt16, video: UInt16) = (
                try freeLoopbackUdpPort(),
                try freeLoopbackUdpPort()
            )
            let receiver = ExternalConnectorSessionConfiguration(
                connector: .lola,
                role: .rx,
                peer: "",
                localHost: "127.0.0.1",
                outputPath: "/tmp/lola-rx.json",
                dryRun: false,
                durationSeconds: 8,
                controlPort: controlPort,
                audioPort: mediaPorts.audio,
                videoPort: mediaPorts.video,
                videoWidth: 16,
                videoHeight: 16,
                videoFrameRate: 60,
                videoBitsPerPixel: 8,
                sessionID: "42"
            )
            let transmitter = ExternalConnectorSessionConfiguration(
                connector: .lola,
                role: .tx,
                peer: "127.0.0.1",
                localHost: "127.0.0.1",
                outputPath: "/tmp/lola-tx.json",
                dryRun: false,
                durationSeconds: 8,
                controlPort: controlPort,
                audioPort: mediaPorts.audio,
                videoPort: mediaPorts.video,
                videoWidth: 16,
                videoHeight: 16,
                videoFrameRate: 60,
                videoBitsPerPixel: 8,
                sessionID: "42"
            )
            let receiverReady = ExternalConnectorReadinessGate()
            let waitForRxReport = runExternalConnectorSessionInBackground(
                receiver,
                onLoLaControlReady: { Task { await receiverReady.signal() } }
            )
            #expect(await receiverReady.wait(timeout: .seconds(3)))
            let txReport = try ExternalConnectorSessionRunner.run(configuration: transmitter)
            let acceptedRxReport = try waitForRxReport()
            reports = (txReport, acceptedRxReport)
            if txReport.lolaControl?.parsedMessageName == "/MESG_QUICKCONN_ACK",
               acceptedRxReport.lolaControl?.parsedMessageName == "/MESG_QUICKCONN" {
                break
            }
        }
        let (txReport, acceptedRxReport) = try #require(reports)
        try txReport.validate()
        try acceptedRxReport.validate()
        #expect(txReport.lolaControl?.parsedMessageName == "/MESG_QUICKCONN_ACK")
        #expect(txReport.lolaControl?.sentMessages.count == 2)
        #expect(txReport.lolaControl?.receivedMessages.count == 2)
        #expect(txReport.lolaControl?.sentMessages.first?.hasPrefix("/MESG_CHECKLOLASTATUS") == true)
        #expect(txReport.lolaControl?.receivedMessages.first?.hasPrefix("/MESG_CHECKLOLASTATUS_ACK") == true)
        #expect(txReport.lolaControl?.fields["SID"] == "42")
        #expect(txReport.lolaControl?.fields["FPS"] == "60")
        #expect(txReport.lolaControl?.fields["X"] == "16")
        #expect(acceptedRxReport.lolaControl?.parsedMessageName == "/MESG_QUICKCONN")
        #expect(acceptedRxReport.lolaControl?.receivedMessages.count == 2)
        #expect(acceptedRxReport.lolaControl?.sentMessages.count == 2)
        #expect(acceptedRxReport.lolaControl?.receivedMessages.first?.hasPrefix("/MESG_CHECKLOLASTATUS") == true)
        #expect(acceptedRxReport.lolaControl?.sentMessages.first?.hasPrefix("/MESG_CHECKLOLASTATUS_ACK") == true)
        #expect(acceptedRxReport.lolaControl?.sentMessage?.hasPrefix("/MESG_QUICKCONN_ACK") == true)
        #expect(acceptedRxReport.lolaControl?.fields["Y"] == "16")
        #expect(txReport.lolaMedia?.realLinkTransmitted == true)
        #expect(txReport.lolaMedia?.notes.contains("UDP sockets") == true)
        #expect(acceptedRxReport.lolaMedia?.realLinkTransmitted == true)
        #expect(acceptedRxReport.lolaMedia?.notes.contains("UDP sockets") == true)
    }
}

@Test
func lolaControlLoopbackUsesReceiverReadinessSignalInsteadOfFixedSleep() throws {
    let source = try readExternalConnectorSessionTestSource()
    let fixedStartupSleep = "Task.sleep(for: .seconds(" + "1))"
    let pollingSleep = "try? await Task.sleep(for: " + ".milliseconds(1))"

    #expect(source.contains("onLoLaControlReady"))
    #expect(source.contains("await receiverReady.wait(timeout: .seconds(3))"))
    #expect(source.contains("withCheckedContinuation"))
    #expect(!source.contains(pollingSleep))
    #expect(!source.contains(fixedStartupSleep))
}

@Test
func externalConnectorSessionRejectsDryRunPass() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ug-session.json"
    )
    var report = try ExternalConnectorSessionRunner.run(configuration: configuration)
    report.verdict = .pass
    #expect(throws: ExternalConnectorSessionError.dryRunCannotPass) {
        try report.validate()
    }
}

@Test
func externalConnectorSessionRejectsMissingSourceReferences() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-session.json",
        peerAudioPort: 4464
    )
    var report = try ExternalConnectorSessionRunner.run(configuration: configuration)
    report.plan.sourceReferences = []

    #expect(throws: ExternalConnectorSessionError.emptyList("plan.sourceReferences")) {
        try report.validate()
    }
}

@Test
func externalConnectorSessionRejectsMissingConnectorSourceReference() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ug-session.json"
    )
    var report = try ExternalConnectorSessionRunner.run(configuration: configuration)
    report.plan.sourceReferences = ["https://example.invalid/ultragrid-not-authoritative"]

    #expect(throws: ExternalConnectorSessionError.missingSourceReference(.mvtpUltraGrid)) {
        try report.validate()
    }
}

@Test
func externalConnectorSessionParserAcceptsHyphenatedConnectorNames() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "mvtp-ultragrid",
        "--role", "rx",
        "--peer", "198.51.100.20",
        "--output", "/tmp/ug.json",
        "--dry-run", "true",
        "--video-executable", "uv",
        "--media", "audio-video",
        "--channels", "4",
        "--video-width", "1280",
        "--video-height", "720",
        "--video-fps", "60",
    ])

    #expect(configuration.connector == .mvtpUltraGrid)
    #expect(configuration.role == .rx)
    #expect(configuration.mediaMode == .audioVideo)
    #expect(configuration.videoExecutable == "uv")
    #expect(configuration.channels == 4)
    #expect(configuration.audioPort == 5006)
    #expect(configuration.videoWidth == 1280)
    #expect(configuration.videoHeight == 720)
    #expect(configuration.videoFrameRate == 60)
}

@Test
func externalConnectorSessionParserRejectsCommonMtvpTypoAlias() {
    #expect(throws: ExternalConnectorSessionError.invalidConnector("mtvp-ultragrid")) {
        try ExternalConnectorSessionConfiguration.parse([
            "--connector", "mtvp-ultragrid",
            "--role", "rx",
            "--peer", "198.51.100.20",
            "--output", "/tmp/ug.json",
        ])
    }
}

private func commandValue(_ command: [String], _ flag: String) -> String? {
    guard let index = command.firstIndex(of: flag), command.indices.contains(index + 1) else {
        return nil
    }
    return command[index + 1]
}

private func readExternalConnectorSessionTestSource() throws -> String {
    try readExternalConnectorSource("Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift")
}

private func readExternalConnectorSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: root.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

private actor ExternalConnectorReadinessGate {
    private var isReady = false
    private var waiters: [UUID: CheckedContinuation<Bool, Never>] = [:]

    func signal() {
        isReady = true
        let continuations = waiters.values
        waiters.removeAll()
        for continuation in continuations {
            continuation.resume(returning: true)
        }
    }

    func wait(timeout: Duration) async -> Bool {
        if isReady {
            return true
        }
        let id = UUID()
        return await withCheckedContinuation { continuation in
            waiters[id] = continuation
            Task.detached {
                try? await ContinuousClock().sleep(for: timeout)
                await self.timeout(id)
            }
        }
    }

    private func timeout(_ id: UUID) {
        guard let continuation = waiters.removeValue(forKey: id) else {
            return
        }
        continuation.resume(returning: isReady)
    }
}
