// Verifies that external connector connection plan builds bidirectional AV endpoints.
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
            "--video-display", "gl"
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
// swiftlint:disable function_body_length
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
        "--jacktrip-audio-backend", "jack-graph",
        "--video-capture", "decklink:0",
        "--video-display", "decklink:1",
        "--session-id", "23"
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
    #expect(!localServer.command.contains("/usr/local/bin/jacktrip"))
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
    #expect(commandValue(remoteClient.command, "--jacktrip-audio-backend") == "jack-graph")
    #expect(commandValue(localServer.command, "--jacktrip-audio-backend") == "jack-graph")
    #expect(commandValue(remoteClient.plan.arguments, "-B") == "4491")
    #expect(commandValue(remoteClient.plan.arguments, "-P") == "4490")
    #expect(report.runDirectory == "/tmp/open-lola-nmp-run")
    #expect(
        commandValue(localServer.command, "--output")
            == "/tmp/open-lola-nmp-run/jackTrip-local-bidirectional-rx.json"
    )
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
        "--ultragrid-executable", "/usr/local/bin/uv"
    ])
    #expect(report.preflightShellCommand?.contains("--connector jacktrip") == true)
    _ = try ExternalConnectorSessionConfiguration.parse(Array(localServer.command.dropFirst()))
    _ = try ExternalConnectorSessionConfiguration.parse(Array(remoteClient.command.dropFirst()))
}
// swiftlint:enable function_body_length

@Test
func ultraGridConnectionPlanCarriesServerClientTopologyWithoutUvPreflight() throws {
    let configuration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "mvtp-ultragrid",
        "--local-host", "198.51.100.10",
        "--remote-host", "198.51.100.20",
        "--output", "/tmp/ultragrid-server-client.json",
        "--run-dir", "/tmp/open-lola-ug-server-client",
        "--media", "audio-video",
        "--ultragrid-topology", "server-client",
        "--audio-port", "5006",
        "--video-port", "5004"
    ])

    let report = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)
    let server = try #require(report.endpoints.first {
        $0.side == .local && $0.direction == .bidirectional && $0.role == .rx
    })
    let client = try #require(report.endpoints.first {
        $0.side == .remote && $0.direction == .bidirectional && $0.role == .tx
    })

    try report.validate()
    #expect(report.preflightCommand == nil)
    #expect(commandValue(server.command, "--peer") == nil)
    #expect(commandValue(server.command, "--ultragrid-topology") == "server-client")
    #expect(commandValue(server.command, "--ultragrid-topology-role") == "server")
    #expect(commandValue(server.command, "--ultragrid-audio-payload-type") == "21")
    #expect(commandValue(server.command, "--ultragrid-video-payload-type") == "20")
    #expect(commandValue(server.command, "--ultragrid-fec") == "none")
    #expect(commandValue(client.command, "--peer") == "198.51.100.10")
    #expect(commandValue(client.command, "--ultragrid-topology") == "server-client")
    #expect(commandValue(client.command, "--ultragrid-topology-role") == "client")
    #expect(server.plan.arguments.contains("--topology"))
    #expect(server.plan.arguments.contains("server-client"))
    #expect(server.plan.arguments.contains("server"))
    #expect(!server.plan.arguments.contains("uv"))
    #expect(!client.plan.arguments.contains("uv"))
    _ = try ExternalConnectorSessionConfiguration.parse(Array(server.command.dropFirst()))
    _ = try ExternalConnectorSessionConfiguration.parse(Array(client.command.dropFirst()))
}

@Test
// swiftlint:disable function_body_length
func externalConnectorConnectionPlanRejectsInvalidInputsAndArtifacts() throws {
    let videoOnlyConfiguration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "jacktrip",
        "--local-host", "203.0.113.10",
        "--remote-host", "203.0.113.20",
        "--output", "/tmp/jacktrip-connection.json",
        "--media", "video"
    ])

    #expect(throws: ExternalConnectorSessionError.connectorDoesNotSupportMediaMode(.jackTrip, .video)) {
        _ = try ExternalConnectorConnectionPlanRunner.run(configuration: videoOnlyConfiguration)
    }

    let incompleteRawLinkConfiguration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "lola",
        "--local-host", "198.51.100.10",
        "--remote-host", "198.51.100.20",
        "--output", "/tmp/lola-connection.json",
        "--media", "audio-video",
        "--local-raw-link-interface", "en10"
    ])

    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument("--remote-raw-link-interface")) {
        _ = try ExternalConnectorConnectionPlanRunner.run(configuration: incompleteRawLinkConfiguration)
    }

    let unsupportedRawLinkConfiguration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "jacktrip",
        "--local-host", "203.0.113.10",
        "--remote-host", "203.0.113.20",
        "--output", "/tmp/jacktrip-raw-link.json",
        "--media", "audio-video",
        "--local-raw-link-interface", "en10",
        "--remote-raw-link-interface", "en11",
        "--local-mac", "02:00:00:00:00:0a",
        "--remote-mac", "02:00:00:00:00:0b"
    ])

    #expect(throws: ExternalConnectorSessionError.connectorDoesNotSupportRawLink(.jackTrip)) {
        _ = try ExternalConnectorConnectionPlanRunner.run(configuration: unsupportedRawLinkConfiguration)
    }

    var report = try ExternalConnectorConnectionPlanRunner.run(configuration: try .parse([
        "--connector", "mvtp-ultragrid",
        "--local-host", "198.51.100.10",
        "--remote-host", "198.51.100.20",
        "--output", "/tmp/open-lola-nmp/ultragrid-plan.json",
        "--media", "audio-video"
    ]))
    let outputIndex = try #require(report.endpoints[0].command.firstIndex(of: "--output"))
    report.endpoints[0].command[outputIndex + 1] = "<run-dir>/endpoint.json"

    #expect(throws: ExternalConnectorSessionError.placeholderValue("endpoints.command")) {
        try report.validate()
    }

    var staleShellReport = try ExternalConnectorConnectionPlanRunner.run(configuration: try .parse([
        "--connector", "mvtp-ultragrid",
        "--local-host", "198.51.100.10",
        "--remote-host", "198.51.100.20",
        "--output", "/tmp/open-lola-nmp/ultragrid-plan.json",
        "--media", "audio-video"
    ]))
    staleShellReport.endpoints[0].shellCommand = "open-lola external-connector-session-run --connector mvtp-ultragrid"

    #expect(throws: ExternalConnectorSessionError.inconsistentShellCommand("endpoints.shellCommand")) {
        try staleShellReport.validate()
    }
}
// swiftlint:enable function_body_length

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
        "--media-packets", "3"
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
