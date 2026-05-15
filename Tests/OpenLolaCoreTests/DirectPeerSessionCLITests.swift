import Foundation
import Testing

@Test
func directPeerSessionCLIAcceptsExplicitUIDsWithoutLegacyAudioDeviceUID() throws {
    let cliURL = try openLolaCLIURL()
    let result = try runOpenLolaCLI(
        cliURL,
        arguments: directPeerAVCLIArguments(
            inputUID: "same-full-duplex-uid",
            outputUID: "same-full-duplex-uid",
            durationSeconds: "0"
        )
    )

    #expect(result.exitCode != 0)
    #expect(result.output.contains("invalid --duration-seconds"))
    #expect(!result.output.contains("--media audio-video requires --audio-device-uid"))
}

@Test
func directPeerSessionCLIAcceptsSeparateInputOutputUIDs() throws {
    let cliURL = try openLolaCLIURL()
    let result = try runOpenLolaCLI(
        cliURL,
        arguments: directPeerAVCLIArguments(
            inputUID: "input-only-uid",
            outputUID: "output-only-uid",
            durationSeconds: "0"
        )
    )

    #expect(result.exitCode != 0)
    #expect(result.output.contains("invalid --duration-seconds"))
    #expect(!result.output.localizedCaseInsensitiveContains("not yet supported"))
}

@Test
func directPeerSessionCLIRejectsChannelMapCountMismatchBeforeRuntime() throws {
    let cliURL = try openLolaCLIURL()
    let result = try runOpenLolaCLI(
        cliURL,
        arguments: directPeerAVCLIArguments(
            inputUID: "same-full-duplex-uid",
            outputUID: "same-full-duplex-uid",
            durationSeconds: "1"
        ) + [
            "--channels", "2",
            "--input-channels", "0",
            "--output-channels", "0,1",
        ]
    )

    #expect(result.exitCode != 0)
    #expect(result.output.contains("--input-channels must contain 2 entries"))
}

@Test
func directPeerSessionCLIAcceptsStructuredEvidenceAndBaselineFlags() throws {
    let source = try readRepositoryText("Sources/open-lola/Commands/Network/DirectP2PSessionRunArgumentSupport.swift")
    let commandSource = try readRepositoryText(
        "Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift"
    )
    let dispatcherSource = try readRepositoryText("Sources/open-lola/Commands/Network/NetworkCommands.swift")

    #expect(source.contains("--packet-capture-artifact-path"))
    #expect(source.contains("--dscp-artifact-path"))
    #expect(source.contains("--clock-artifact-path"))
    #expect(source.contains("--fastest-baseline-report-id"))
    #expect(source.contains("--rx-buffer-profile"))
    #expect(source.contains("--video-compression"))
    #expect(source.contains("--ready-file"))
    #expect(commandSource.contains("RxBufferProfile(rawValue: value)"))
    #expect(commandSource.contains("invalid --rx-buffer-profile"))
    #expect(commandSource.contains("invalid --video-compression"))
    #expect(commandSource.contains("is not valid with --av-profile"))
    #expect(commandSource.contains("directP2PReadyFileWriter"))
    #expect(commandSource.contains("directP2PValidateMediaScopedArguments"))
    #expect(commandSource.contains("is only valid with --media audio-video"))
    #expect(dispatcherSource.contains("onReady: onReady"))
}

@Test
func directPeerKeyValueCommandsUseSharedParser() throws {
    let sessionSource = try readRepositoryText(
        "Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift"
    )
    let meshSource = try readRepositoryText("Sources/open-lola/Commands/Network/DirectP2PMeshArgumentSupport.swift")
    let parserSource = try readRepositoryText("Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift")

    #expect(sessionSource.contains("KeyValueArgumentParser.parseValues"))
    #expect(meshSource.contains("KeyValueArgumentParser.parseValues"))
    #expect(meshSource.contains("parseDirectP2PMeshValues"))
    #expect(parserSource.contains("allowsDashPrefixedValues"))
    #expect(!sessionSource.contains("while index < arguments.count"))
    #expect(!meshSource.contains("while index < arguments.count"))
}

@Test
func directPeerTwoPeerSupervisorWaitsForReadinessMarkerInsteadOfBlindDelay() throws {
    let source = try readRepositoryText(
        "Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift"
    )
    let processRunner = try readRepositoryText(
        "Sources/OpenLolaCore/Support/ManagedProcessRunner.swift"
    )

    #expect(source.contains("waitForDirectP2PReadyFile"))
    #expect(source.contains("--ready-file"))
    #expect(source.contains("responder exited before readiness marker"))
    #expect(source.contains("waitForDirectP2PProcessesToExit"))
    #expect(source.contains("terminateExpiredDirectP2PProcesses"))
    #expect(source.contains("ManagedProcessRunner.terminate"))
    #expect(processRunner.contains("SIGKILL"))
    #expect(!source.contains("usleep(useconds_t(options.readinessDelayMilliseconds * 1_000))"))
    #expect(!source.contains("initiator.process.waitUntilExit()"))
    #expect(!source.contains("responder.process.waitUntilExit()"))
}

@Test
func directPeerSessionCLIPositiveIntegerInputsAreBounded() throws {
    let source = try readRepositoryText(
        "Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift"
    )

    #expect(source.contains("directP2PPositiveIntegerBounds"))
    #expect(source.contains("\"--duration-seconds\": 86_400"))
    #expect(source.contains("\"--timeout-seconds\": 86_400"))
    #expect(source.contains("\"--video-width\": 8_192"))
    #expect(source.contains("\"--video-height\": 8_192"))
    #expect(source.contains("number <= maximum"))
    #expect(source.contains("count <= directP2PMaximumPositiveInteger(for: \"--packets\")"))
}

@Test
func directPeerTwoPeerSupervisorCollectsRXProofOnlyWhenRequested() throws {
    let source = try readRepositoryText(
        "Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift"
    )

    #expect(source.contains("directP2PArgumentValue(\"--rx-proof-output\""))
    #expect(source.contains("warning: rx-proof collection skipped"))
    #expect(!source.contains("remotePath: rxProofPath(for: command.outputReportPath)"))
}

private func openLolaCLIURL() throws -> URL {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let candidates = [
        URL(fileURLWithPath: "/private/tmp/open-lola2-swiftpm-build/debug/open-lola"),
        root.appendingPathComponent(".build/debug/open-lola"),
        root.appendingPathComponent(".build/arm64-apple-macosx/debug/open-lola"),
    ]

    return try #require(
        candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) },
        "open-lola executable must be built before CLI behavior tests"
    )
}

private func directPeerAVCLIArguments(
    inputUID: String,
    outputUID: String,
    durationSeconds: String
) -> [String] {
    [
        "direct-p2p-session-run",
        "--media", "audio-video",
        "--role", "initiator",
        "--local-peer", "peer-a",
        "--remote-peer", "peer-b",
        "--local-host", "127.0.0.1",
        "--remote-host", "127.0.0.1",
        "--control-port", "19001",
        "--remote-control-port", "19002",
        "--audio-port", "19003",
        "--video-port", "19004",
        "--metrics-port", "19005",
        "--output", "/tmp/open-lola-direct-p2p-av-parser-test.json",
        "--duration-seconds", durationSeconds,
        "--input-uid", inputUID,
        "--output-uid", outputUID,
        "--video-device-id", "synthetic-test-device",
        "--preview", "off",
    ]
}

private func runOpenLolaCLI(
    _ executableURL: URL,
    arguments: [String]
) throws -> (exitCode: Int32, output: String) {
    let process = Process()
    let outputPipe = Pipe()
    process.executableURL = executableURL
    process.arguments = arguments
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    try process.run()
    process.waitUntilExit()

    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
}

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
