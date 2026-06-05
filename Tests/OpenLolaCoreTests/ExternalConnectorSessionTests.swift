import Foundation
import Darwin
import Testing

@testable import OpenLolaCore

@Test
func externalConnectorLaunchPlansCoverUltraGridJackTripAndAvTransportPorts() throws {
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

    #expect(tx.launchKind == .internalUltraGridMvtp)
    #expect(tx.executable == nil)
    #expect(tx.arguments.contains("--video-capture"))
    #expect(tx.arguments.contains("--audio-capture"))
    #expect(tx.arguments.contains("5004:5004:5006:5006"))
    #expect(rx.arguments.contains("--video-display"))
    #expect(rx.arguments.contains("--audio-playback"))
    #expect(rx.videoPort == 5004)
    #expect(rx.audioPort == 5006)
    #expect(tx.mediaProfile.mode == .audioVideo)
    #expect(tx.mediaProfile.audioEnabled)
    #expect(tx.mediaProfile.videoEnabled)
    #expect(tx.sourceReferences.contains("https://github.com/CESNET/UltraGrid"))
    #expect(tx.sourceReferences.contains("https://raw.githubusercontent.com/CESNET/UltraGrid/master/README.md"))
    #expect(tx.sourceReferences.contains("https://github.com/CESNET/UltraGrid/wiki/NAT-traversal"))
    #expect(tx.sourceReferences.contains("https://raw.githubusercontent.com/wiki/CESNET/UltraGrid/UltraGrid-packet-types.md"))

    let jackTripTx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-tx.json",
        audioPort: 4465,
        peerAudioPort: 4464,
        channels: 8,
        jackTrip: JackTripRunConfiguration(queueDepth: 6, redundancy: 2)
    ))
    let jackTripRx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .rx,
        peer: "",
        outputPath: "/tmp/jacktrip-rx.json",
        channels: 8
    ))

    #expect(jackTripTx.launchKind == .internalJackTripAudio)
    #expect(jackTripTx.executable == nil)
    #expect(jackTripTx.arguments.starts(with: ["-c", "203.0.113.10"]))
    #expect(jackTripTx.arguments.contains("-R"))
    #expect(jackTripTx.arguments.contains("-n"))
    #expect(jackTripTx.arguments.contains("8"))
    #expect(commandValue(jackTripTx.arguments, "-q") == "6")
    #expect(commandValue(jackTripTx.arguments, "-r") == "2")
    #expect(commandValue(jackTripTx.arguments, "-B") == "4465")
    #expect(commandValue(jackTripTx.arguments, "-P") == "4464")
    #expect(jackTripTx.protocolFacts.contains { $0.contains("direct UDP endpoint") })
    #expect(jackTripRx.arguments.first == "-s")
    #expect(jackTripRx.arguments.contains("-R"))
    #expect(commandValue(jackTripRx.arguments, "-B") == "4464")
    #expect(commandValue(jackTripRx.arguments, "-P") == nil)
    #expect(jackTripRx.audioPort == 4464)
    #expect(jackTripRx.videoPort == 5004)
    #expect(jackTripTx.mediaProfile.mode == .audio)
    #expect(jackTripTx.mediaProfile.audioEnabled)
    #expect(!jackTripTx.mediaProfile.videoEnabled)
    #expect(jackTripTx.auxiliaryProcesses.isEmpty)
    #expect(jackTripTx.sourceReferences.contains("https://github.com/jacktrip/jacktrip"))
    #expect(jackTripTx.sourceReferences.contains("https://raw.githubusercontent.com/jacktrip/jacktrip/main/src/Settings.cpp"))
    #expect(jackTripTx.sourceReferences.contains("https://raw.githubusercontent.com/jacktrip/jacktrip/main/docs/Documentation/NetworkProtocol.md"))
    #expect(jackTripTx.sourceReferences.contains("https://raw.githubusercontent.com/jacktrip/jacktrip/main/src/PacketHeader.h"))
    #expect(jackTripTx.sourceReferences.contains("https://jacktrip.github.io/jacktrip/"))

    let jackTripAvTx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-av-tx.json",
        mediaMode: .audioVideo,
        peerAudioPort: 4464
    ))
    let jackTripAvRx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .rx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-av-rx.json",
        mediaMode: .audioVideo
    ))

    #expect(jackTripAvTx.arguments.starts(with: ["-c", "203.0.113.10"]))
    #expect(jackTripAvTx.mediaProfile.mode == .audioVideo)
    #expect(jackTripAvTx.mediaProfile.audioEnabled)
    #expect(jackTripAvTx.mediaProfile.videoEnabled)
    #expect(jackTripAvTx.auxiliaryProcesses.count == 1)
    #expect(jackTripAvTx.auxiliaryProcesses[0].executable == "uv")
    #expect(jackTripAvTx.auxiliaryProcesses[0].arguments.contains("-t"))
    #expect(jackTripAvTx.auxiliaryProcesses[0].arguments.contains("5004:5004"))
    #expect(jackTripAvRx.arguments.first == "-s")
    #expect(jackTripAvRx.auxiliaryProcesses.count == 1)
    #expect(jackTripAvRx.auxiliaryProcesses[0].arguments.contains("-d"))
    #expect(jackTripAvRx.auxiliaryProcesses[0].arguments.contains("5004:5004"))
    #expect(jackTripAvRx.auxiliaryProcesses[0].arguments.last == "203.0.113.10")
    #expect(jackTripAvTx.protocolFacts.contains { $0.contains("audio-video mode pairs native JackTrip audio") })
    #expect(jackTripAvTx.sourceReferences.contains("https://github.com/CESNET/UltraGrid"))
}

@Test
func externalConnectorConfigurationAndLaunchPlanRejectInvalidInputs() throws {
    let parsed = try ExternalConnectorSessionConfiguration.parse([
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
        "--ultragrid-audio-payload-type", "96",
        "--ultragrid-video-payload-type", "97",
        "--ultragrid-fec", "single-parity",
        "--ultragrid-control", "local-tcp",
        "--ultragrid-control-command", "stats on",
    ])

    #expect(parsed.connector == .mvtpUltraGrid)
    #expect(parsed.role == .rx)
    #expect(parsed.mediaMode == .audioVideo)
    #expect(parsed.videoExecutable == "uv")
    #expect(parsed.channels == 4)
    #expect(parsed.audioPort == 5006)
    #expect(parsed.videoWidth == 1280)
    #expect(parsed.videoHeight == 720)
    #expect(parsed.videoFrameRate == 60)
    #expect(parsed.ultraGridAudioPayloadType == 96)
    #expect(parsed.ultraGridVideoPayloadType == 97)
    #expect(parsed.ultraGridFECMode == .singleParity)
    #expect(parsed.ultraGridControlMode == .localTCP)
    #expect(try parsed.ultraGridControlCommands.map { try $0.encodedLine() } == ["stats on\r\n"])

    let ultraGridServer = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "",
        outputPath: "/tmp/ug-server.json",
        ultraGridTopologyMode: .serverClient,
        ultraGridTopologyRole: .server
    ))
    #expect(ultraGridServer.peer.isEmpty)
    #expect(!ultraGridServer.arguments.contains("--peer"))
    #expect(commandValue(ultraGridServer.arguments, "--topology") == "server-client")
    #expect(commandValue(ultraGridServer.arguments, "--topology-role") == "server")

    #expect(throws: ExternalConnectorSessionError.invalidConnector("mtvp-ultragrid")) {
        try ExternalConnectorSessionConfiguration.parse([
            "--connector", "mtvp-ultragrid",
            "--role", "rx",
            "--peer", "198.51.100.20",
            "--output", "/tmp/ug.json",
        ])
    }

    let missingPeerPortConfiguration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-missing-peer-port.json"
    )

    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument("--peer-audio-port")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: missingPeerPortConfiguration)
    }

    #expect(throws: ExternalConnectorSessionError.connectorDoesNotSupportMediaMode(.jackTrip, .video)) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .rx,
            peer: "",
            outputPath: "/tmp/jacktrip-video.json",
            mediaMode: .video
        ))
    }

    let audioOnlyUltraGrid = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "198.51.100.20",
        outputPath: "/tmp/ug-audio.json",
        mediaMode: .audio
    ))
    #expect(audioOnlyUltraGrid.mediaProfile.mode == .audio)
    #expect(audioOnlyUltraGrid.protocolFacts.contains { $0.contains("payload type 21") })

    #expect(throws: ExternalConnectorSessionError.invalidPort("videoPort", "0")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .txRx,
            peer: "198.51.100.10",
            outputPath: "/tmp/ug-zero-video-port.json",
            videoPort: 0
        ))
    }

    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("videoCapture", "--help")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "198.51.100.10",
            outputPath: "/tmp/ug-option-video-capture.json",
            videoCapture: "--help"
        ))
    }

    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("videoCapture", "--help")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-av-option-video-capture.json",
            mediaMode: .audioVideo,
            peerAudioPort: 4464,
            videoCapture: "--help"
        ))
    }

    #expect(throws: ExternalConnectorSessionError.connectorRequiresPeerForTx(.jackTrip)) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "",
            outputPath: "/tmp/jacktrip-tx.json"
        ))
    }

    #expect(throws: ExternalConnectorSessionError.invalidLoLaSessionID("sid-1")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .tx,
            peer: "192.0.2.20",
            outputPath: "/tmp/lola-invalid-session.json",
            sessionID: "sid-1"
        ))
    }

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
func externalConnectorPlansPreserveWhitespaceDeviceNamesAsSingleArguments() throws {
    let ultraGrid = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .txRx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ug-whitespace-devices.json",
        audioCapture: "Studio Input 1",
        audioPlayback: "Studio Output 1",
        videoCapture: "decklink:device=Studio Camera 1",
        videoDisplay: "DeckLink Studio Display"
    ))

    #expect(commandValue(ultraGrid.arguments, "--audio-capture") == "Studio Input 1")
    #expect(commandValue(ultraGrid.arguments, "--audio-playback") == "Studio Output 1")
    #expect(commandValue(ultraGrid.arguments, "--video-capture") == "decklink:device=Studio Camera 1")
    #expect(commandValue(ultraGrid.arguments, "--video-display") == "DeckLink Studio Display")

    let jackTrip = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-whitespace-devices.json",
        peerAudioPort: 4464,
        audioCapture: "RME MADI Input 1",
        audioPlayback: "RME MADI Output 1"
    ))

    #expect(commandValue(jackTrip.arguments, "--audioinputdevice") == "RME MADI Input 1")
    #expect(commandValue(jackTrip.arguments, "--audiooutputdevice") == "RME MADI Output 1")
}

@Test
func externalConnectorSessionRunnerReportsDryRunsAndProcessRuns() throws {
    let dryRunConfiguration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-session.json",
        peerAudioPort: 4464
    )

    let report = try ExternalConnectorSessionRunner.run(configuration: dryRunConfiguration)

    try report.validate()
    #expect(report.dryRun)
    #expect(report.verdict == .partial)
    #expect(report.process == nil)

    let avConfiguration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-av-session.json",
        mediaMode: .audioVideo,
        peerAudioPort: 4464
    )

    let avReport = try ExternalConnectorSessionRunner.run(configuration: avConfiguration)

    try avReport.validate()
    #expect(avReport.dryRun)
    #expect(avReport.plan.auxiliaryProcesses.count == 1)
    #expect(avReport.plan.auxiliaryProcesses[0].label == "jacktrip-auxiliary-ultragrid-video")
    #expect(avReport.auxiliaryProcesses.isEmpty)

    let processRunner = MockExternalConnectorProcessRunner(results: [
        ExternalConnectorProcessResult(
            launched: true,
            processIdentifier: 47_002,
            terminatedAfterDuration: true
        ),
    ])
    let processConfiguration = ExternalConnectorSessionConfiguration(
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

    let processReport = try ExternalConnectorSessionRunner.run(
        configuration: processConfiguration,
        processRunner: processRunner
    )

    try processReport.validate()
    #expect(processReport.process == nil)
    #expect(processReport.jackTripMedia?.transmittedDatagramCount == 1)
    #expect(processReport.auxiliaryProcesses.count == 1)
    #expect(processReport.auxiliaryProcesses[0].launched)
    #expect(processReport.plan.auxiliaryProcesses[0].mediaMode == .video)
    #expect(processRunner.invocations.map(\.executable) == [
        "/definitely/not/uv",
    ])
}

@Test
func externalConnectorSessionRunnerReportsJackGraphBackendPrerequisiteFailure() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-jack-graph-session.json",
        dryRun: false,
        peerAudioPort: 4464,
        jackTrip: JackTripRunConfiguration(audioBackend: .jackGraph)
    )

    let report = try ExternalConnectorSessionRunner.run(
        configuration: configuration,
        processRunner: MockExternalConnectorProcessRunner(results: [])
    )

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.jackTripMedia == nil)
    #expect(report.runtimeError?.contains("jack-graph-backend requires a measured JACK graph capture provider") == true)
    #expect(report.plan.protocolFacts.contains {
        $0.contains("jack-graph requires measured JACK graph capture evidence")
    })
}

@Test
func connectorReport_partialWithRuntimeError_hasRuntimeErrorFreeFalse() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-partial-runtime-error.json",
        peerAudioPort: 4464
    )
    let plan = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    let report = ExternalConnectorSessionReport(
        id: "external-connector-runtime-error-partial",
        capturedAt: "2026-05-19T00:00:00Z",
        connector: .jackTrip,
        role: .tx,
        dryRun: false,
        plan: plan,
        process: nil,
        lolaControl: nil,
        runtimeError: "socket failure after partial media evidence",
        verdict: .partial,
        notes: "Partial report with explicit runtime error diagnostic."
    )
    let ultraGridMedia = UltraGridCompatibilityMediaReport(UltraGridCompatibilityMediaReportInput(
        identity: UltraGridCompatibilityMediaIdentity(
            id: "ultragrid-runtime-error-partial",
            capturedAt: "2026-05-19T00:00:00Z",
            role: .tx,
            mediaMode: .audioVideo
        ),
        packets: UltraGridCompatibilityPacketSummary(
            datagrams: [],
            transmittedDatagramCount: 0,
            receivedDatagramCount: 0
        ),
        evidence: UltraGridCompatibilityEvidenceState(
            realLinkTransmitted: false,
            verdict: .partial,
            runtimeError: "socket failure after partial media evidence",
            notes: "Partial UltraGrid media report with explicit runtime error diagnostic."
        )
    ))
    let jackTripMedia = partialJackTripMediaReportWithRuntimeError()

    try report.validate()
    try ultraGridMedia.validate()
    try jackTripMedia.validate()

    #expect(report.runtimeErrorFree == false)
    #expect(ultraGridMedia.runtimeErrorFree == false)
    #expect(jackTripMedia.runtimeErrorFree == false)
}

private func partialJackTripMediaReportWithRuntimeError() -> JackTripCompatibilityMediaReport {
    jackTripCompatibilityMediaReport {
        $0.id = "jacktrip-runtime-error-partial"
        $0.capturedAt = "2026-05-19T00:00:00Z"
        $0.role = .tx
        $0.realLinkTransmitted = false
        $0.verdict = .partial
        $0.runtimeError = "socket failure after partial media evidence"
        $0.notes = "Partial JackTrip media report with explicit runtime error diagnostic."
    }
}

@Test
func connectorReport_partialWithoutRuntimeError_hasRuntimeErrorFreeTrue() throws {
    let lolaReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "",
        outputPath: "/tmp/lola-dry-run-runtime-error-free.json",
        dryRun: true
    ))
    let ultraGridReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ultragrid-runtime-error-free.json",
        dryRun: false
    ))
    let jackTripReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-runtime-error-free.json",
        dryRun: false,
        peerAudioPort: 4464
    ))

    try lolaReport.validate()
    try ultraGridReport.validate()
    try jackTripReport.validate()

    #expect(lolaReport.verdict == .partial)
    #expect(lolaReport.runtimeError == nil)
    #expect(lolaReport.runtimeErrorFree == true)
    #expect(ultraGridReport.verdict == .partial)
    #expect(ultraGridReport.runtimeError == nil)
    #expect(ultraGridReport.runtimeErrorFree == true)
    #expect(ultraGridReport.ultraGridMedia?.runtimeErrorFree == true)
    #expect(jackTripReport.verdict == .partial)
    #expect(jackTripReport.runtimeError == nil)
    #expect(jackTripReport.runtimeErrorFree == true)
    #expect(jackTripReport.jackTripMedia?.runtimeErrorFree == true)
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
               acceptedRxReport.lolaControl?.parsedMessageName == "/MESG_QUICKCONN",
               txReport.lolaMedia?.realLinkTransmitted == true,
               (txReport.lolaMedia?.sentBytesTotal ?? 0) > 0,
               acceptedRxReport.lolaMedia?.realLinkTransmitted == true,
               (acceptedRxReport.lolaMedia?.envelopeValidatedFrameCount ?? 0) > 0 {
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
        let txMedia = try #require(txReport.lolaMedia)
        #expect(txMedia.realLinkTransmitted == true)
        #expect(txMedia.runtimeError == nil)
        #expect((txMedia.sentBytesTotal ?? 0) > 0)
        let rxMedia = try #require(acceptedRxReport.lolaMedia)
        #expect(rxMedia.realLinkTransmitted == true)
        #expect(rxMedia.runtimeError == nil)
        #expect(rxMedia.envelopeValidatedFrameCount > 0)
    }
}

@Test
func externalConnectorSessionRejectsInvalidReportContracts() throws {
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

    let jackTripConfiguration = ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-session.json",
        peerAudioPort: 4464
    )
    var jackTripReport = try ExternalConnectorSessionRunner.run(configuration: jackTripConfiguration)
    jackTripReport.plan.sourceReferences = []

    #expect(throws: ExternalConnectorSessionError.emptyList("plan.sourceReferences")) {
        try jackTripReport.validate()
    }

    let ultraGridConfiguration = ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ug-session.json"
    )
    var ultraGridReport = try ExternalConnectorSessionRunner.run(configuration: ultraGridConfiguration)
    ultraGridReport.plan.sourceReferences = ["https://example.invalid/ultragrid-not-authoritative"]

    #expect(throws: ExternalConnectorSessionError.missingSourceReference(.mvtpUltraGrid)) {
        try ultraGridReport.validate()
    }
}

@Test
func externalConnectorSessionPassRequiresNestedMediaRuntimeProof() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ug-pass-proof.json",
        dryRun: false
    )
    let plan = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    var report = ExternalConnectorSessionReport(
        id: "external-connector-missing-media-pass",
        capturedAt: "2026-05-20T00:00:00Z",
        connector: .mvtpUltraGrid,
        role: .tx,
        dryRun: false,
        plan: plan,
        process: nil,
        lolaControl: nil,
        verdict: .pass,
        notes: "False PASS fixture shape: outer report claims PASS without nested media proof."
    )

    #expect(throws: ExternalConnectorSessionError.runtimePassMissingEvidence("ultraGridMedia")) {
        try report.validate()
    }

    report.ultraGridMedia = UltraGridCompatibilityMediaReport(UltraGridCompatibilityMediaReportInput(
        identity: UltraGridCompatibilityMediaIdentity(
            id: "ultragrid-runtime-error-partial",
            capturedAt: "2026-05-20T00:00:00Z",
            role: .tx,
            mediaMode: .audio
        ),
        packets: UltraGridCompatibilityPacketSummary(
            datagrams: [],
            transmittedDatagramCount: 1,
            receivedDatagramCount: 0
        ),
        evidence: UltraGridCompatibilityEvidenceState(
            observedEvidenceClasses: ExternalConnectorEvidenceClass.runtimePassRequiredEvidence,
            missingEvidenceClassesForPass: [.teardown],
            realLinkTransmitted: true,
            verdict: .partial,
            runtimeError: "nested media socket failure",
            notes: "Nested report carries runtime error despite outer PASS."
        )
    ))

    #expect(throws: ExternalConnectorSessionError.runtimePassWithRuntimeError("ultraGridMedia.runtimeError")) {
        try report.validate()
    }
}

private func commandValue(_ command: [String], _ flag: String) -> String? {
    guard let index = command.firstIndex(of: flag), command.indices.contains(index + 1) else {
        return nil
    }
    return command[index + 1]
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
