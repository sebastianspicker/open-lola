import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionHelpListsCanonicalAudioTransportOnly() throws {
    let cliURL = try opusTestOpenLolaCLIURL()
    let result = try runOpusTestOpenLolaCLI(cliURL, arguments: ["direct-p2p-session-run", "--help"])

    #expect(result.exitCode == 0)
    #expect(result.output.contains("--audio-transport openlola-raw|openlola-opus-celt-ld|aes67-st2110-l24"))
    #expect(!result.output.contains("--audio-compression"))
}

@Test
func directPeerSessionCLIRejectsInvalidAudioCompressionValue() throws {
    let cliURL = try opusTestOpenLolaCLIURL()
    let result = try runOpusTestOpenLolaCLI(
        cliURL,
        arguments: opusDirectAVCLIArguments() + ["--audio-compression", "invalid"]
    )

    #expect(result.exitCode != 0)
    #expect(result.output.contains("invalid --audio-compression"))
}

@Test
func directPeerSessionCLIRejectsUnsupportedOpusShapesBeforeRuntime() throws {
    let cliURL = try opusTestOpenLolaCLIURL()
    for extraArguments in [
        ["--audio-compression", "opus-celt-ld", "--channels", "64", "--frames", "120"],
        ["--audio-compression", "opus-celt-ld", "--channels", "2", "--frames", "32"],
        ["--audio-compression", "opus-celt-ld", "--channels", "2", "--frames", "120", "--sample-rate", "96000"],
        ["--audio-compression", "opus-celt-ld", "--channels", "2", "--frames", "120", "--sample-format", "int16"],
    ] {
        let result = try runOpusTestOpenLolaCLI(
            cliURL,
            arguments: opusDirectAVCLIArguments() + extraArguments
        )
        #expect(result.exitCode != 0)
        #expect(result.output.contains("opus-celt-ld requires --sample-rate 48000"))
    }
}

@Test
func directPeerSessionCLIAcceptsAoIPDefaultFramesAndRejectsConflicts() throws {
    let cliURL = try opusTestOpenLolaCLIURL()
    let conflicting = try runOpusTestOpenLolaCLI(
        cliURL,
        arguments: opusDirectAVCLIArguments() + [
            "--audio-transport", "aes67-st2110-l24",
            "--audio-compression", "opus-celt-ld",
        ]
    )
    #expect(conflicting.exitCode != 0)
    #expect(conflicting.output.contains("conflicting --audio-transport and --audio-compression"))

    let invalidShape = try runOpusTestOpenLolaCLI(
        cliURL,
        arguments: opusDirectAVCLIArguments() + [
            "--audio-transport", "aes67-st2110-l24",
            "--channels", "2",
            "--frames", "32",
        ]
    )
    #expect(invalidShape.exitCode != 0)
    #expect(invalidShape.output.contains("aes67-st2110-l24 requires --sample-rate 48000"))
}

@Test
func directPeerSessionCLIStillAcceptsHiddenLegacyAudioCompressionForMigration() throws {
    let source = try readOpusTestRepositoryText(
        "Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift"
    )
    let allowed = try readOpusTestRepositoryText(
        "Sources/open-lola/Commands/Network/DirectP2PSessionRunArgumentSupport.swift"
    )

    #expect(allowed.contains("--audio-compression"))
    #expect(allowed.contains("directP2PSessionRunPublicArguments()"))
    #expect(source.contains("guard let value else { return .raw }"))
    #expect(allowed.contains("--audio-transport"))
    #expect(source.contains("--audio-transport \\(transport.rawValue) is only valid with --media audio-video"))
}

private func opusDirectAVCLIArguments() -> [String] {
    [
        "direct-p2p-session-run",
        "--media", "audio-video",
        "--role", "initiator",
        "--local-peer", "peer-a",
        "--remote-peer", "peer-b",
        "--local-host", "127.0.0.1",
        "--remote-host", "127.0.0.1",
        "--control-port", "19101",
        "--remote-control-port", "19102",
        "--audio-port", "19103",
        "--video-port", "19104",
        "--metrics-port", "19105",
        "--output", "/tmp/open-lola-direct-p2p-opus-parser-test.json",
        "--duration-seconds", "1",
        "--input-uid", "test-input",
        "--output-uid", "test-output",
        "--video-device-id", "synthetic-test-device",
        "--preview", "off",
    ]
}

private func opusTestOpenLolaCLIURL() throws -> URL {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let candidates = [
        URL(fileURLWithPath: "/private/tmp/open-lola2-swiftpm-build/debug/open-lola"),
        root.appendingPathComponent(".build/debug/open-lola"),
        root.appendingPathComponent(".build/arm64-apple-macosx/debug/open-lola"),
    ]
    return try #require(
        candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) },
        "open-lola executable must be built before Opus CLI behavior tests"
    )
}

private func runOpusTestOpenLolaCLI(
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

private func readOpusTestRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
