import Foundation
import Testing

@testable import OpenLolaCore


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
func directPeerSessionCLIRejectsDuplicateAndMissingKeyValueArguments() throws {
    let cliURL = try openLolaCLIURL()
    let duplicate = try runOpenLolaCLI(
        cliURL,
        arguments: ["direct-p2p-session-run", "--output", "/tmp/a.json", "--output", "/tmp/b.json"]
    )
    #expect(duplicate.exitCode != 0)
    #expect(duplicate.output.contains("duplicate --output"))

    let missing = try runOpenLolaCLI(
        cliURL,
        arguments: ["direct-p2p-session-run", "--output"]
    )
    #expect(missing.exitCode != 0)
    #expect(missing.output.contains("missing value for --output"))

    let dashPrefixedValue = try runOpenLolaCLI(
        cliURL,
        arguments: ["direct-p2p-session-run", "--output", "--not-a-path"]
    )
    #expect(dashPrefixedValue.exitCode != 0)
    #expect(dashPrefixedValue.output.contains("missing value for --output"))
}

@Test
func directPeerSessionCLIPositiveIntegerInputsAreBounded() throws {
    let cliURL = try openLolaCLIURL()
    let invalidPackets = try runOpenLolaCLI(
        cliURL,
        arguments: ["direct-p2p-session-run", "--output", "/tmp/open-lola-packets-bound-test.json",
                    "--packets", "1000001"]
    )
    #expect(invalidPackets.exitCode != 0)
    #expect(invalidPackets.output.contains("invalid --packets"))

    for (flag, value) in [
        ("--duration-seconds", "86401"),
        ("--video-width", "8193"),
        ("--video-height", "8193"),
    ] {
        var arguments = directPeerAVCLIArguments(
            inputUID: "same-full-duplex-uid",
            outputUID: "same-full-duplex-uid",
            durationSeconds: "1"
        )
        if let index = arguments.firstIndex(of: flag), index + 1 < arguments.count {
            arguments[index + 1] = value
        } else {
            arguments += [flag, value]
        }
        let result = try runOpenLolaCLI(cliURL, arguments: arguments)
        #expect(result.exitCode != 0)
        #expect(result.output.contains("invalid \(flag)"))
    }
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

private func directPeerTwoPeerPlanArguments(output: String, runDirectory: String) -> [String] {
    [
        "direct-p2p-two-peer-plan-run",
        "--output", output,
        "--run-dir", runDirectory,
        "--duration-seconds", "1",
        "--channels", "2",
        "--mac-a-peer", "mac-a",
        "--mac-a-host", "127.0.0.1",
        "--mac-a-port-base", "19100",
        "--mac-a-input-uid", "mac-a-input",
        "--mac-a-output-uid", "mac-a-output",
        "--mac-a-video-device-id", "mac-a-video",
        "--mac-b-peer", "mac-b",
        "--mac-b-host", "127.0.0.1",
        "--mac-b-port-base", "19200",
        "--mac-b-input-uid", "mac-b-input",
        "--mac-b-output-uid", "mac-b-output",
        "--mac-b-video-device-id", "mac-b-video",
    ]
}

private func temporaryDirectory(prefix: String) throws -> URL {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
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

private func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
}
