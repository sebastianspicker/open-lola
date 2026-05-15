import Testing

@testable import OpenLolaCore

@Test
func externalConnectorConnectionPlanBuildsBidirectionalAvEndpoints() throws {
    for connector in ExternalConnectorKind.allCases {
        let configuration = try ExternalConnectorConnectionPlanConfiguration.parse([
            "--connector", connector.rawValue,
            "--local-host", "198.51.100.10",
            "--remote-host", "198.51.100.20",
            "--output", "/tmp/\(connector.rawValue)-connection.json",
            "--media", "audio-video",
            "--executable", connector == .lola ? "ignored" : "/usr/bin/true",
            "--video-executable", "/usr/bin/true",
            "--video-capture", "testcard:1920:1080:30:RGB",
            "--video-display", "gl",
        ])

        let report = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)

        try report.validate()
        #expect(report.endpoints.count == 2)
        if connector == .jackTrip {
            #expect(Set(report.endpoints.map(\.role)) == Set([.rx, .tx]))
        } else {
            #expect(report.endpoints.allSatisfy { $0.role == .txRx })
        }
        #expect(report.endpoints.allSatisfy { $0.direction == .bidirectional })
        #expect(report.endpoints.allSatisfy { $0.plan.mediaProfile.audioEnabled })
        #expect(report.endpoints.allSatisfy { $0.plan.mediaProfile.videoEnabled })
    }
}

@Test
func externalConnectorConnectionPlanCommandsCarryRealRunInputs() throws {
    let configuration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "jacktrip",
        "--local-host", "203.0.113.10",
        "--remote-host", "203.0.113.20",
        "--output", "/tmp/jacktrip-connection.json",
        "--run-dir", "/tmp/open-lola-nmp-run",
        "--executable", "/usr/local/bin/jacktrip",
        "--video-executable", "/usr/local/bin/uv",
        "--media", "audio-video",
        "--duration-seconds", "12",
        "--audio-port", "4490",
        "--video-port", "5010",
        "--channels", "8",
        "--sample-rate", "48000",
        "--frames", "32",
        "--video-width", "1280",
        "--video-height", "720",
        "--video-fps", "60",
        "--video-bpp", "30",
        "--audio-capture", "coreaudio:input-uid",
        "--audio-playback", "coreaudio:output-uid",
        "--video-capture", "decklink:0",
        "--video-display", "decklink:1",
        "--session-id", "23",
    ])

    let report = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)
    let localServer = try #require(report.endpoints.first {
        $0.side == .local && $0.direction == .bidirectional && $0.role == .rx
    })
    let remoteClient = try #require(report.endpoints.first {
        $0.side == .remote && $0.direction == .bidirectional && $0.role == .tx
    })

    #expect(localServer.command.contains("--dry-run"))
    #expect(localServer.command.contains("false"))
    #expect(commandValue(localServer.command, "--connector") == "jacktrip")
    #expect(commandValue(localServer.command, "--role") == "rx")
    #expect(commandValue(localServer.command, "--media") == "audio-video")
    #expect(localServer.command.contains("/usr/local/bin/jacktrip"))
    #expect(localServer.command.contains("/usr/local/bin/uv"))
    #expect(localServer.command.contains("decklink:0"))
    #expect(localServer.command.contains("decklink:1"))
    #expect(localServer.command.contains("48000"))
    #expect(localServer.command.contains("32"))
    #expect(commandValue(localServer.command, "--audio-capture") == "coreaudio:input-uid")
    #expect(commandValue(localServer.command, "--audio-playback") == "coreaudio:output-uid")
    #expect(commandValue(localServer.plan.arguments, "--audioinputdevice") == "coreaudio:input-uid")
    #expect(commandValue(localServer.plan.arguments, "--audiooutputdevice") == "coreaudio:output-uid")
    #expect(commandValue(localServer.plan.arguments, "-B") == "4490")
    #expect(commandValue(localServer.plan.arguments, "-P") == nil)
    #expect(commandValue(localServer.command, "--audio-port") == "4490")
    #expect(commandValue(localServer.command, "--peer-audio-port") == nil)
    #expect(commandValue(localServer.command, "--video-port") == "5010")
    #expect(commandValue(localServer.command, "--video-width") == "1280")
    #expect(commandValue(localServer.command, "--video-height") == "720")
    #expect(commandValue(localServer.command, "--video-fps") == "60")
    #expect(commandValue(localServer.command, "--video-bpp") == "30")
    #expect(localServer.command.contains("23"))
    #expect(localServer.plan.arguments.contains("48000"))
    #expect(localServer.plan.arguments.contains("32"))
    #expect(localServer.plan.audioPort == 4490)
    #expect(localServer.plan.videoPort == 5010)
    #expect(localServer.plan.mediaProfile.videoWidth == 1280)
    #expect(localServer.plan.mediaProfile.videoHeight == 720)
    #expect(localServer.plan.mediaProfile.videoFrameRate == 60)
    #expect(localServer.plan.mediaProfile.videoBitsPerPixel == 30)
    #expect(localServer.plan.auxiliaryProcesses[0].arguments.contains("decklink:0"))
    #expect(localServer.plan.auxiliaryProcesses[0].arguments.contains("decklink:1"))
    #expect(commandValue(localServer.command, "--peer") == "203.0.113.20")
    #expect(commandValue(localServer.command, "--full-duplex") == "true")
    #expect(commandValue(remoteClient.command, "--role") == "tx")
    #expect(commandValue(remoteClient.command, "--audio-port") == "4491")
    #expect(commandValue(remoteClient.command, "--peer-audio-port") == "4490")
    #expect(commandValue(remoteClient.plan.arguments, "-B") == "4491")
    #expect(commandValue(remoteClient.plan.arguments, "-P") == "4490")
    #expect(report.runDirectory == "/tmp/open-lola-nmp-run")
    #expect(commandValue(localServer.command, "--output") == "/tmp/open-lola-nmp-run/jackTrip-local-bidirectional-rx.json")
    #expect(localServer.shellCommand.hasPrefix("open-lola external-connector-session-run "))
    #expect(!localServer.shellCommand.contains("<run-dir>"))
    #expect(localServer.shellCommand.contains("/tmp/open-lola-nmp-run/jackTrip-local-bidirectional-rx.json"))
    #expect(localServer.shellCommand.contains("--video-capture decklink:0"))
    #expect(localServer.shellCommand.contains("--video-display decklink:1"))
    #expect(report.preflightCommand == [
        "external-connector-executable-preflight-run", "--output",
        "/tmp/open-lola-nmp-run/jackTrip-executable-preflight.json",
        "--connector", "jacktrip",
        "--jacktrip-executable", "/usr/local/bin/jacktrip",
        "--ultragrid-executable", "/usr/local/bin/uv",
    ])
    #expect(report.preflightShellCommand?.contains("--connector jacktrip") == true)
    _ = try ExternalConnectorSessionConfiguration.parse(Array(localServer.command.dropFirst()))
    _ = try ExternalConnectorSessionConfiguration.parse(Array(remoteClient.command.dropFirst()))
}

@Test
func externalConnectorSessionParserCarriesJackTripRuntimeKnobs() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "jacktrip",
        "--role", "tx",
        "--peer", "203.0.113.20",
        "--output", "/tmp/jacktrip-cli.json",
        "--peer-audio-port", "4464",
        "--jacktrip-queue-depth", "7",
        "--jacktrip-redundancy", "3",
    ])

    #expect(configuration.jackTrip.queueDepth == 7)
    #expect(configuration.jackTrip.redundancy == 3)
}

@Test
func ultraGridConnectionPlanPreflightsOnlyUltraGridExecutable() throws {
    let report = try ExternalConnectorConnectionPlanRunner.run(configuration: try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "mvtp-ultragrid",
        "--local-host", "198.51.100.10",
        "--remote-host", "198.51.100.20",
        "--output", "/tmp/open-lola-nmp/ultragrid-plan.json",
        "--executable", "/opt/ug/bin/uv",
        "--media", "audio-video",
    ]))

    #expect(report.preflightCommand == [
        "external-connector-executable-preflight-run", "--output",
        "/tmp/open-lola-nmp/mvtpUltraGrid-executable-preflight.json",
        "--connector", "mvtp-ultragrid",
        "--ultragrid-executable", "/opt/ug/bin/uv",
    ])
    #expect(report.preflightShellCommand == "open-lola external-connector-executable-preflight-run --output /tmp/open-lola-nmp/mvtpUltraGrid-executable-preflight.json --connector mvtp-ultragrid --ultragrid-executable /opt/ug/bin/uv")
}

@Test
func externalConnectorConnectionPlanDefaultsRunDirectoryFromPlanOutputParent() throws {
    let configuration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "mvtp-ultragrid",
        "--local-host", "198.51.100.10",
        "--remote-host", "198.51.100.20",
        "--output", "/tmp/open-lola-nmp/ultragrid-plan.json",
        "--media", "audio-video",
    ])

    let report = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)
    let endpoint = try #require(report.endpoints.first {
        $0.side == .local && $0.direction == .bidirectional && $0.role == .txRx
    })

    #expect(report.runDirectory == "/tmp/open-lola-nmp")
    #expect(commandValue(endpoint.command, "--output") == "/tmp/open-lola-nmp/mvtpUltraGrid-local-bidirectional-tx-rx.json")
    #expect(!endpoint.command.contains("<run-dir>"))
    #expect(!endpoint.shellCommand.contains("<run-dir>"))
    _ = try ExternalConnectorSessionConfiguration.parse(Array(endpoint.command.dropFirst()))
}

@Test
func externalConnectorConnectionPlanValidationRejectsPlaceholderEndpointCommands() throws {
    var report = try ExternalConnectorConnectionPlanRunner.run(configuration: try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "mvtp-ultragrid",
        "--local-host", "198.51.100.10",
        "--remote-host", "198.51.100.20",
        "--output", "/tmp/open-lola-nmp/ultragrid-plan.json",
        "--media", "audio-video",
    ]))
    let outputIndex = try #require(report.endpoints[0].command.firstIndex(of: "--output"))
    report.endpoints[0].command[outputIndex + 1] = "<run-dir>/endpoint.json"

    #expect(throws: ExternalConnectorSessionError.placeholderValue("endpoints.command")) {
        try report.validate()
    }
}

@Test
func externalConnectorConnectionPlanValidationRejectsStaleShellCommand() throws {
    var report = try ExternalConnectorConnectionPlanRunner.run(configuration: try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "mvtp-ultragrid",
        "--local-host", "198.51.100.10",
        "--remote-host", "198.51.100.20",
        "--output", "/tmp/open-lola-nmp/ultragrid-plan.json",
        "--media", "audio-video",
    ]))
    report.endpoints[0].shellCommand = "open-lola external-connector-session-run --connector mvtp-ultragrid"

    #expect(throws: ExternalConnectorSessionError.inconsistentShellCommand("endpoints.shellCommand")) {
        try report.validate()
    }
}

@Test
func externalConnectorConnectionPlanUsesSideScopedPortsForBidirectionalEndpoints() throws {
    let configuration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "jacktrip",
        "--local-host", "203.0.113.10",
        "--remote-host", "203.0.113.20",
        "--output", "/tmp/jacktrip-ports.json",
        "--media", "audio-video",
        "--control-port", "7000",
        "--audio-port", "4464",
        "--video-port", "5004",
    ])

    let report = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)
    let local = try #require(report.endpoints.first { $0.side == .local })
    let remote = try #require(report.endpoints.first { $0.side == .remote })

    #expect(local.plan.controlPort == 7000)
    #expect(local.plan.audioPort == 4464)
    #expect(local.plan.videoPort == 5004)
    #expect(remote.plan.controlPort == 7001)
    #expect(remote.plan.audioPort == 4465)
    #expect(remote.plan.videoPort == 5005)
    #expect(commandValue(local.plan.arguments, "-B") == "4464")
    #expect(commandValue(local.plan.arguments, "-P") == nil)
    #expect(commandValue(remote.plan.arguments, "-B") == "4465")
    #expect(commandValue(remote.plan.arguments, "-P") == "4464")
}

@Test
func externalConnectorConnectionPlanOmitsControlPortWhenConnectorHasNoControlLane() throws {
    for connector in [ExternalConnectorKind.mvtpUltraGrid, .jackTrip] {
        let report = try ExternalConnectorConnectionPlanRunner.run(
            configuration: try ExternalConnectorConnectionPlanConfiguration.parse([
                "--connector", connector.rawValue,
                "--local-host", "198.51.100.10",
                "--remote-host", "198.51.100.20",
                "--output", "/tmp/\(connector.rawValue)-no-control-port.json",
                "--run-dir", "/tmp/open-lola-nmp",
            ])
        )

        #expect(report.endpoints.allSatisfy { commandValue($0.command, "--control-port") == nil })
        #expect(report.endpoints.allSatisfy { $0.plan.controlPort == 0 })
    }
}

@Test
func ultraGridConnectionPlanCommandsCarryDirectionalDeviceModules() throws {
    let configuration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "mvtp-ultragrid",
        "--local-host", "198.51.100.10",
        "--remote-host", "198.51.100.20",
        "--output", "/tmp/ug-connection.json",
        "--media", "audio-video",
        "--audio-capture", "coreaudio:input-uid",
        "--audio-playback", "coreaudio:output-uid",
        "--video-capture", "decklink:0",
        "--video-display", "decklink:1",
    ])

    let report = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)

    for endpoint in report.endpoints {
        #expect(endpoint.role == .txRx)
        #expect(commandValue(endpoint.command, "--peer") != nil)
        #expect(endpoint.command.contains("coreaudio:input-uid"))
        #expect(endpoint.command.contains("coreaudio:output-uid"))
        #expect(endpoint.command.contains("decklink:0"))
        #expect(endpoint.command.contains("decklink:1"))
        #expect(endpoint.plan.arguments.contains("coreaudio:input-uid"))
        #expect(endpoint.plan.arguments.contains("coreaudio:output-uid"))
        #expect(endpoint.plan.arguments.contains("decklink:0"))
        #expect(endpoint.plan.arguments.contains("decklink:1"))
        #expect(endpoint.plan.arguments.last == commandValue(endpoint.command, "--peer"))
    }
}

@Test
func externalConnectorConnectionPlanRejectsVideoOnlyJackTrip() throws {
    let configuration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "jacktrip",
        "--local-host", "203.0.113.10",
        "--remote-host", "203.0.113.20",
        "--output", "/tmp/jacktrip-connection.json",
        "--media", "video",
    ])

    #expect(throws: ExternalConnectorSessionError.connectorDoesNotSupportMediaMode(.jackTrip, .video)) {
        _ = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)
    }
}

@Test
func externalConnectorConnectionPlanCommandsUseDefaultPathExecutables() throws {
    let ultraGrid = try ExternalConnectorConnectionPlanRunner.run(
        configuration: try ExternalConnectorConnectionPlanConfiguration.parse([
            "--connector", "mvtp-ultragrid",
            "--local-host", "203.0.113.10",
            "--remote-host", "203.0.113.20",
            "--output", "/tmp/ultragrid-connection.json",
            "--media", "audio-video",
        ])
    )
    let jackTrip = try ExternalConnectorConnectionPlanRunner.run(
        configuration: try ExternalConnectorConnectionPlanConfiguration.parse([
            "--connector", "jacktrip",
            "--local-host", "203.0.113.10",
            "--remote-host", "203.0.113.20",
            "--output", "/tmp/jacktrip-connection.json",
            "--media", "audio-video",
        ])
    )
    let ultraGridTxRx = try #require(ultraGrid.endpoints.first { $0.role == .txRx })
    let jackTripServer = try #require(jackTrip.endpoints.first { $0.role == .rx })
    let jackTripClient = try #require(jackTrip.endpoints.first { $0.role == .tx })

    #expect(commandValue(ultraGridTxRx.command, "--executable") == "uv")
    #expect(commandValue(jackTripServer.command, "--executable") == "jacktrip")
    #expect(commandValue(jackTripClient.command, "--executable") == "jacktrip")
    #expect(commandValue(jackTripServer.command, "--video-executable") == "uv")
    #expect(commandValue(jackTripClient.command, "--video-executable") == "uv")
    _ = try ExternalConnectorSessionConfiguration.parse(Array(ultraGridTxRx.command.dropFirst()))
    _ = try ExternalConnectorSessionConfiguration.parse(Array(jackTripServer.command.dropFirst()))
    _ = try ExternalConnectorSessionConfiguration.parse(Array(jackTripClient.command.dropFirst()))
}

@Test
func lolaConnectionPlanCarriesUdpMediaPacketCountWithoutRawLink() throws {
    let configuration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "lola",
        "--local-host", "198.51.100.10",
        "--remote-host", "198.51.100.20",
        "--output", "/tmp/lola-connection.json",
        "--media", "audio-video",
        "--media-packets", "4",
    ])

    let report = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)

    for endpoint in report.endpoints {
        #expect(commandValue(endpoint.command, "--media-packets") == "4")
        _ = try ExternalConnectorSessionConfiguration.parse(Array(endpoint.command.dropFirst()))
    }
    let remoteTxRx = try #require(report.endpoints.first {
        $0.side == .remote && $0.direction == .bidirectional && $0.role == .txRx
    })
    let localTxRx = try #require(report.endpoints.first {
        $0.side == .local && $0.direction == .bidirectional && $0.role == .txRx
    })
    #expect(commandValue(remoteTxRx.command, "--peer") == "198.51.100.10")
    #expect(commandValue(localTxRx.command, "--peer") == "198.51.100.20")
    #expect(remoteTxRx.plan.peer == "198.51.100.10")
    #expect(localTxRx.plan.peer == "198.51.100.20")
}

@Test
func lolaConnectionPlanCarriesBidirectionalRawLinkInputs() throws {
    let configuration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "lola",
        "--local-host", "198.51.100.10",
        "--remote-host", "198.51.100.20",
        "--output", "/tmp/lola-connection.json",
        "--media", "audio-video",
        "--local-raw-link-interface", "en10",
        "--remote-raw-link-interface", "en11",
        "--local-mac", "02:00:00:00:00:0a",
        "--remote-mac", "02:00:00:00:00:0b",
        "--media-packets", "3",
    ])

    let report = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)
    let localTxRx = try #require(report.endpoints.first {
        $0.side == .local && $0.direction == .bidirectional && $0.role == .txRx
    })
    let remoteTxRx = try #require(report.endpoints.first {
        $0.side == .remote && $0.direction == .bidirectional && $0.role == .txRx
    })

    #expect(commandValue(localTxRx.command, "--raw-link-interface") == "en10")
    #expect(commandValue(localTxRx.command, "--source-mac") == "02:00:00:00:00:0a")
    #expect(commandValue(localTxRx.command, "--destination-mac") == "02:00:00:00:00:0b")
    #expect(commandValue(localTxRx.command, "--media-packets") == "3")
    #expect(commandValue(localTxRx.command, "--peer") == "198.51.100.20")
    #expect(commandValue(remoteTxRx.command, "--raw-link-interface") == "en11")
    #expect(commandValue(remoteTxRx.command, "--source-mac") == "02:00:00:00:00:0b")
    #expect(commandValue(remoteTxRx.command, "--destination-mac") == "02:00:00:00:00:0a")
    _ = try ExternalConnectorSessionConfiguration.parse(Array(localTxRx.command.dropFirst()))
    _ = try ExternalConnectorSessionConfiguration.parse(Array(remoteTxRx.command.dropFirst()))
}

@Test
func lolaConnectionPlanRejectsIncompleteRawLinkTuple() throws {
    let configuration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "lola",
        "--local-host", "198.51.100.10",
        "--remote-host", "198.51.100.20",
        "--output", "/tmp/lola-connection.json",
        "--media", "audio-video",
        "--local-raw-link-interface", "en10",
    ])

    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument("--remote-raw-link-interface")) {
        _ = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)
    }
}

@Test
func externalConnectorConnectionPlanRejectsRawLinkInputsForNonLoLaConnectors() throws {
    let configuration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "jacktrip",
        "--local-host", "203.0.113.10",
        "--remote-host", "203.0.113.20",
        "--output", "/tmp/jacktrip-raw-link.json",
        "--media", "audio-video",
        "--local-raw-link-interface", "en10",
        "--remote-raw-link-interface", "en11",
        "--local-mac", "02:00:00:00:00:0a",
        "--remote-mac", "02:00:00:00:00:0b",
    ])

    #expect(throws: ExternalConnectorSessionError.connectorDoesNotSupportRawLink(.jackTrip)) {
        _ = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)
    }
}

private func commandValue(_ command: [String], _ flag: String) -> String? {
    guard let index = command.firstIndex(of: flag), command.indices.contains(index + 1) else {
        return nil
    }
    return command[index + 1]
}
