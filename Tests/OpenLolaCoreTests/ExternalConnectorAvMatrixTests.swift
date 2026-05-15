import Testing

@testable import OpenLolaCore

@Test
func externalConnectorAvMatrixBuildsTxAndRxPlansForEveryRequestedConnector() throws {
    for connector in ExternalConnectorKind.allCases {
        for role in [ExternalConnectorSessionRole.tx, .rx] {
            let configuration = ExternalConnectorSessionConfiguration(
                connector: connector,
                role: role,
                peer: role == .tx || connector != .lola ? "198.51.100.10" : "",
                localHost: "198.51.100.20",
                outputPath: "/tmp/\(connector.rawValue)-\(role.rawValue)-av.json",
                dryRun: true,
                mediaMode: .audioVideo,
                peerAudioPort: connector == .jackTrip && role.transmits ? 4464 : nil
            )

            let report = try ExternalConnectorSessionRunner.run(configuration: configuration)

            try report.validate()
            #expect(report.plan.mediaProfile.audioEnabled)
            #expect(report.plan.mediaProfile.videoEnabled)
            #expect(report.role == role)
        }
    }
}

@Test
func externalConnectorAvMatrixBuildsExplicitTxRxPlansForEveryRequestedConnector() throws {
    for connector in ExternalConnectorKind.allCases {
        let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
            connector: connector,
            role: .txRx,
            peer: "198.51.100.10",
            localHost: "198.51.100.20",
            outputPath: "/tmp/\(connector.rawValue)-tx-rx-av.json",
            dryRun: true,
            mediaMode: .audioVideo,
            peerAudioPort: connector == .jackTrip ? 4464 : nil
        ))

        try report.validate()
        #expect(report.role == .txRx)
        #expect(report.plan.role == .txRx)
        #expect(report.plan.mediaProfile.audioEnabled)
        #expect(report.plan.mediaProfile.videoEnabled)
        if connector == .lola {
            #expect(report.lolaMedia?.role == .txRx)
            #expect(report.lolaMedia?.notes.contains("bidirectional") == true)
        }
    }
}

@Test
func ultraGridPlanUsesConfiguredProductionCaptureAndPlaybackModules() throws {
    let tx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ug-tx.json",
        audioCapture: "coreaudio:input-uid",
        videoCapture: "decklink:0"
    ))
    let rx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "198.51.100.10",
        localHost: "198.51.100.20",
        outputPath: "/tmp/ug-rx.json",
        audioPlayback: "coreaudio:output-uid",
        videoDisplay: "decklink:1"
    ))

    #expect(tx.arguments.contains("decklink:0"))
    #expect(tx.arguments.contains("coreaudio:input-uid"))
    #expect(rx.arguments.contains("decklink:1"))
    #expect(rx.arguments.contains("coreaudio:output-uid"))
    #expect(rx.arguments.last == "198.51.100.10")
    #expect(tx.protocolFacts.contains { $0.contains("production devices") })
}

@Test
func ultraGridAudioVideoEndpointUsesOneFullDuplexProcessWhenPeerIsKnown() throws {
    for role in [ExternalConnectorSessionRole.tx, .rx] {
        let plan = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: role,
            peer: "198.51.100.10",
            localHost: "198.51.100.20",
            outputPath: "/tmp/ug-\(role.rawValue)-duplex.json",
            mediaMode: .audioVideo
        ))

        #expect(plan.arguments.contains("-t"))
        #expect(plan.arguments.contains("-d"))
        #expect(plan.arguments.contains("-s"))
        #expect(plan.arguments.contains("-r"))
        #expect(plan.arguments.last == "198.51.100.10")
        #expect(plan.protocolFacts.contains { $0.contains("simultaneous send and receive") })
    }
}

@Test
func ultraGridTxRxRoleUsesOneSimultaneousTransmitReceiveProcess() throws {
    let plan = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .txRx,
        peer: "198.51.100.10",
        localHost: "198.51.100.20",
        outputPath: "/tmp/ug-tx-rx.json",
        mediaMode: .audioVideo
    ))

    #expect(plan.arguments.contains("-t"))
    #expect(plan.arguments.contains("-d"))
    #expect(plan.arguments.contains("-s"))
    #expect(plan.arguments.contains("-r"))
    #expect(plan.protocolFacts.contains { $0.contains("tx-rx mode") })
}

@Test
func ultraGridDefaultTestcardRejectsNonPositiveVideoDimensions() throws {
    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger("videoWidth", "0")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "198.51.100.10",
            outputPath: "/tmp/ug-invalid-width.json",
            videoWidth: 0
        ))
    }

    #expect(throws: ExternalConnectorSessionError.invalidPositiveInteger("videoFrameRate", "-1")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .tx,
            peer: "198.51.100.10",
            outputPath: "/tmp/ug-invalid-frame-rate.json",
            videoFrameRate: -1
        ))
    }
}

@Test
func jackTripAuxiliaryVideoUsesConfiguredUltraGridModules() throws {
    let tx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-tx.json",
        mediaMode: .audioVideo,
        peerAudioPort: 4464,
        videoCapture: "decklink:0"
    ))
    let rx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .rx,
        peer: "203.0.113.10",
        localHost: "203.0.113.20",
        outputPath: "/tmp/jacktrip-rx.json",
        mediaMode: .audioVideo,
        videoDisplay: "decklink:1"
    ))

    #expect(tx.auxiliaryProcesses[0].arguments.contains("decklink:0"))
    #expect(rx.auxiliaryProcesses[0].arguments.contains("decklink:1"))
    #expect(rx.auxiliaryProcesses[0].arguments.last == "203.0.113.10")
    #expect(tx.auxiliaryProcesses[0].protocolFacts.contains { $0.contains("configured UltraGrid") })
}

@Test
func jackTripRtAudioUsesConfiguredInputAndOutputDevices() throws {
    let plan = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-devices.json",
        mediaMode: .audioVideo,
        peerAudioPort: 4464,
        audioCapture: "BlackHole 64ch",
        audioPlayback: "RME Fireface USB"
    ))

    #expect(plan.arguments.contains("-R"))
    #expect(argumentValue("--audioinputdevice", in: plan.arguments) == "BlackHole 64ch")
    #expect(argumentValue("--audiooutputdevice", in: plan.arguments) == "RME Fireface USB")
    #expect(plan.protocolFacts.contains { $0.contains("device-name options") })
}

@Test
func jackTripPlanRejectsFlagLikePeerAndDeviceArguments() throws {
    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("peer", "--help")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "--help",
            outputPath: "/tmp/jacktrip-bad-peer.json",
            peerAudioPort: 4464
        ))
    }

    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("audioCapture", "--help")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-bad-device.json",
            peerAudioPort: 4464,
            audioCapture: "--help"
        ))
    }
}

@Test
func jackTripAudioVideoAuxiliaryUltraGridIsFullDuplexWhenPeerIsKnown() throws {
    for role in [ExternalConnectorSessionRole.tx, .rx] {
        let plan = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: role,
            peer: "203.0.113.10",
            localHost: "203.0.113.20",
            outputPath: "/tmp/jacktrip-\(role.rawValue)-duplex.json",
            mediaMode: .audioVideo,
            peerAudioPort: role.transmits ? 4464 : nil
        ))
        let auxiliary = try #require(plan.auxiliaryProcesses.first)

        #expect(auxiliary.arguments.contains("-t"))
        #expect(auxiliary.arguments.contains("-d"))
        #expect(auxiliary.arguments.last == "203.0.113.10")
        #expect(auxiliary.protocolFacts.contains { $0.contains("send and receive together") })
    }
}

@Test
func jackTripTxRxRoleUsesBidirectionalAudioAndAuxiliaryVideo() throws {
    let plan = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .txRx,
        peer: "203.0.113.10",
        localHost: "203.0.113.20",
        outputPath: "/tmp/jacktrip-tx-rx.json",
        mediaMode: .audioVideo,
        peerAudioPort: 4464
    ))
    let auxiliary = try #require(plan.auxiliaryProcesses.first)

    #expect(plan.arguments.starts(with: ["-c", "203.0.113.10"]))
    #expect(plan.protocolFacts.contains { $0.contains("tx-rx mode") })
    #expect(auxiliary.arguments.contains("-t"))
    #expect(auxiliary.arguments.contains("-d"))
    #expect(auxiliary.protocolFacts.contains { $0.contains("tx-rx mode") })
}

@Test
func externalConnectorSessionParserAcceptsDeviceModuleOptions() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "mvtp-ultragrid",
        "--role", "tx",
        "--peer", "198.51.100.10",
        "--output", "/tmp/ug-av.json",
        "--media", "audio-video",
        "--audio-capture", "coreaudio:input-uid",
        "--audio-playback", "coreaudio:output-uid",
        "--peer-audio-port", "4464",
        "--video-capture", "decklink:0",
        "--video-display", "decklink:1",
        "--full-duplex", "false",
    ])

    #expect(configuration.audioCapture == "coreaudio:input-uid")
    #expect(configuration.audioPlayback == "coreaudio:output-uid")
    #expect(configuration.peerAudioPort == 4464)
    #expect(configuration.videoCapture == "decklink:0")
    #expect(configuration.videoDisplay == "decklink:1")
    #expect(!configuration.fullDuplex)
}

@Test
func externalConnectorSessionParserAcceptsExplicitTxRxRoleAliases() throws {
    for roleText in ["tx-rx", "txRx", "bidirectional", "full-duplex"] {
        let configuration = try ExternalConnectorSessionConfiguration.parse([
            "--connector", "lola",
            "--role", roleText,
            "--peer", "198.51.100.10",
            "--output", "/tmp/lola-\(roleText)-session.json",
        ])

        #expect(configuration.role == .txRx)
    }
}

@Test
func externalConnectorUserFacingParsersRejectMtvpUltraGridTypoAliases() throws {
    #expect(throws: ExternalConnectorSessionError.invalidConnector("mtvp-ultragrid")) {
        try ExternalConnectorSessionConfiguration.parse([
            "--connector", "mtvp-ultragrid",
            "--role", "tx",
            "--peer", "198.51.100.10",
            "--output", "/tmp/mtvp-session.json",
            "--media", "audio-video",
        ])
    }
    #expect(throws: ExternalConnectorSessionError.invalidConnector("mtvpUltraGrid")) {
        try ExternalConnectorConnectionPlanConfiguration.parse([
            "--connector", "mtvpUltraGrid",
            "--local-host", "198.51.100.20",
            "--remote-host", "198.51.100.10",
            "--output", "/tmp/mtvp-connection.json",
        ])
    }

    let preflight = try ExternalConnectorExecutablePreflightConfiguration.parse([
        "--output", "/tmp/mtvp-preflight.json",
        "--connector", "ultragrid",
    ])
    let workflow = try ExternalConnectorNmpWorkflowConfiguration.parse([
        "--local-host", "198.51.100.20",
        "--remote-host", "198.51.100.10",
        "--output", "/tmp/mtvp-workflow.json",
        "--side", "both",
        "--connectors", "lola,mvtp-ultragrid,jacktrip",
    ])

    #expect(preflight.connector == .mvtpUltraGrid)
    #expect(workflow.planConfiguration.connectors == [.lola, .mvtpUltraGrid, .jackTrip])
    #expect(workflow.side == .both)
}

@Test
func externalConnectorSessionRejectsRawLinkOptionsForNonLoLaConnectors() throws {
    let configuration = ExternalConnectorSessionConfiguration(connector: .mvtpUltraGrid, role: .tx, peer: "198.51.100.20", outputPath: "/tmp/ug-raw-link.json", rawLinkInterface: "en10")

    #expect(throws: ExternalConnectorSessionError.connectorDoesNotSupportRawLink(.mvtpUltraGrid)) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    }
}

@Test
func ultraGridReceiveRequiresRemotePeerInsteadOfSelfPeering() throws {
    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument("--peer")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .rx,
            peer: "",
            localHost: "198.51.100.20",
            outputPath: "/tmp/ug-rx-missing-peer.json"
        ))
    }
}

@Test
func jackTripAudioVideoReceiveRequiresPeerForAuxiliaryUltraGridVideo() throws {
    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument("--peer")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .rx,
            peer: "",
            localHost: "203.0.113.20",
            outputPath: "/tmp/jacktrip-av-rx-missing-peer.json",
            mediaMode: .audioVideo
        ))
    }
}

private func argumentValue(_ option: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: option), index + 1 < arguments.count else {
        return nil
    }
    return arguments[index + 1]
}
