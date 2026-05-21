import Testing

@testable import OpenLolaCore

@Test
func externalConnectorSessionParserPreservesRepeatedUltraGridControlCommands() throws {
    let configuration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "mvtp-ultragrid",
        "--role", "tx",
        "--peer", "198.51.100.20",
        "--output", "/tmp/ug-control.json",
        "--ultragrid-control", "local-tcp",
        "--ultragrid-control-command", "stats on",
        "--ultragrid-control-command", "av-delay 15",
    ])

    #expect(try configuration.ultraGridControlCommands.map { try $0.encodedLine() } == [
        "stats on\r\n",
        "av-delay 15\r\n",
    ])

    let plan = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    #expect(commandValues(plan.arguments, "--control-command") == ["stats on", "av-delay 15"])
}

@Test
func externalConnectorSessionParserStillRejectsDuplicateScalarArguments() {
    #expect(throws: ExternalConnectorSessionError.duplicateArgument("--peer")) {
        _ = try ExternalConnectorSessionConfiguration.parse([
            "--connector", "mvtp-ultragrid",
            "--role", "tx",
            "--peer", "198.51.100.20",
            "--peer", "198.51.100.21",
            "--output", "/tmp/ug-control.json",
        ])
    }
}

@Test
func externalConnectorSessionParserRejectsMismatchedConnectorSpecificArguments() {
    #expect(throws: ExternalConnectorSessionError.unknownArgument("--jacktrip-queue-depth")) {
        _ = try ExternalConnectorSessionConfiguration.parse([
            "--connector", "mvtp-ultragrid",
            "--role", "tx",
            "--peer", "198.51.100.20",
            "--output", "/tmp/ug-jacktrip-flag.json",
            "--jacktrip-queue-depth", "6",
        ])
    }

    #expect(throws: ExternalConnectorSessionError.unknownArgument("--ultragrid-control-command")) {
        _ = try ExternalConnectorSessionConfiguration.parse([
            "--connector", "jacktrip",
            "--role", "tx",
            "--peer", "203.0.113.10",
            "--output", "/tmp/jacktrip-ug-flag.json",
            "--peer-audio-port", "4464",
            "--ultragrid-control-command", "stats on",
        ])
    }

    #expect(throws: ExternalConnectorSessionError.unknownArgument("--ultragrid-fec")) {
        _ = try ExternalConnectorSessionConfiguration.parse([
            "--connector", "lola",
            "--role", "tx",
            "--peer", "198.51.100.20",
            "--output", "/tmp/lola-ug-flag.json",
            "--ultragrid-fec", "single-parity",
        ])
    }
}

@Test
func externalConnectorSessionParserRejectsRawLinkArgumentsForNonLoLaConnectors() {
    #expect(throws: ExternalConnectorSessionError.unknownArgument("--raw-link-interface")) {
        _ = try ExternalConnectorSessionConfiguration.parse([
            "--connector", "mvtp-ultragrid",
            "--role", "tx",
            "--peer", "198.51.100.20",
            "--output", "/tmp/ug-raw-link.json",
            "--raw-link-interface", "en0",
        ])
    }

    #expect(throws: ExternalConnectorSessionError.unknownArgument("--source-mac")) {
        _ = try ExternalConnectorSessionConfiguration.parse([
            "--connector", "jacktrip",
            "--role", "tx",
            "--peer", "203.0.113.10",
            "--output", "/tmp/jacktrip-raw-link.json",
            "--peer-audio-port", "4464",
            "--source-mac", "02:4c:6f:4c:61:00",
        ])
    }
}

@Test
func externalConnectorSessionParserRejectsIgnoredLoLaVideoControlArguments() throws {
    #expect(throws: ExternalConnectorSessionError.unknownArgument("--video-compression")) {
        _ = try ExternalConnectorSessionConfiguration.parse([
            "--connector", "mvtp-ultragrid",
            "--role", "tx",
            "--peer", "198.51.100.20",
            "--output", "/tmp/ug-video-compression.json",
            "--video-compression", "1",
        ])
    }

    #expect(throws: ExternalConnectorSessionError.unknownArgument("--video-bayer")) {
        _ = try ExternalConnectorSessionConfiguration.parse([
            "--connector", "jacktrip",
            "--role", "tx",
            "--peer", "203.0.113.10",
            "--output", "/tmp/jacktrip-video-bayer.json",
            "--peer-audio-port", "4464",
            "--video-bayer", "1",
        ])
    }

    #expect(throws: ExternalConnectorSessionError.unknownArgument("--lola-video-payload")) {
        _ = try ExternalConnectorSessionConfiguration.parse([
            "--connector", "jacktrip",
            "--role", "tx",
            "--peer", "203.0.113.10",
            "--output", "/tmp/jacktrip-lola-video-payload.json",
            "--peer-audio-port", "4464",
            "--lola-video-payload", "avfoundation-raw8",
        ])
    }

    let ultraGridConfiguration = try ExternalConnectorSessionConfiguration.parse([
        "--connector", "mvtp-ultragrid",
        "--role", "tx",
        "--peer", "198.51.100.20",
        "--output", "/tmp/ug-lola-video-payload.json",
        "--lola-video-payload", "avfoundation-raw8",
    ])
    #expect(ultraGridConfiguration.lolaVideoPayload == .avFoundationRaw8)
}

private func commandValues(_ command: [String], _ flag: String) -> [String] {
    command.indices.compactMap { index in
        guard command[index] == flag, command.indices.contains(index + 1) else {
            return nil
        }
        return command[index + 1]
    }
}
