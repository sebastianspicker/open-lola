import Foundation
import Testing

@testable import OpenLolaCore

@Test
func commandInventoryCommandsAreBackedByExecutableRouterSource() throws {
    let advertised = Set(CLICommandInventory.entries.map(\.command))
    let routed = try executableRouterCommandNames()

    #expect(advertised.subtracting(routed).isEmpty)
    #expect(advertised.count == CLICommandInventory.entries.count)
    #expect(routed.contains("command-inventory"))
}

@Test
func commandInventoryReportPreservesPublicSummaryContract() {
    let report = CLICommandInventory.report()
    let commands = report.commands.map(\.command)

    #expect(Set(commands).count == commands.count)
    #expect(report.summary.commandCount == report.commands.count)
    #expect(report.summary.validatorCount == report.commands.filter { $0.kind == .validator }.count)
    #expect(report.summary.runCount == report.commands.filter { $0.kind == .run }.count)
    #expect(report.summary.syntheticSmokeCount == report.commands.filter { $0.kind == .syntheticSmoke }.count)
    #expect(report.summary.localhostSmokeCount == report.commands.filter { $0.kind == .localhostSmoke }.count)
}

@Test
func openLolaExecutableCommandInventoryEmitsJSONAndVerdict() throws {
    let result = try runRequiredOpenLolaCLI(arguments: ["command-inventory"])
    let report = try JSONDecoder().decode(
        CLICommandInventoryReport.self,
        from: try executableJSONPayload(from: result.output)
    )

    #expect(result.exitCode == 0)
    #expect(report == CLICommandInventory.report())
    #expect(report.verdict == .partial)
    #expect(result.output.contains("VERDICT: PARTIAL"))
}

@Test
func openLolaExecutableDirectP2PHelpIncludesDynamicArgumentSurface() throws {
    let result = try runRequiredOpenLolaCLI(arguments: ["direct-p2p-session-run", "--help"])

    #expect(result.exitCode == 0)
    #expect(result.output.contains("Supported options:"))
    #expect(result.output.contains("--input-uid"))
    #expect(result.output.contains("--output-uid"))
    #expect(result.output.contains("--rx-buffer-profile"))
    #expect(result.output.contains("--video-compression"))
    #expect(result.output.contains("--ready-file"))
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func executableRouterCommandNames() throws -> Set<String> {
    let sourceRoot = repositoryRoot.appendingPathComponent("Sources/open-lola")
    let sourceURLs = try swiftSourceURLs(under: sourceRoot)
    let patterns = try [
        #"RegisteredCommand\(name:\s*"([^"]+)""#,
        #"args\[0\]\s*==\s*"([^"]+)""#,
        #"args\.first\s*==\s*"([^"]+)""#,
        #"case\s*\[\s*"([^"]+)""#,
    ].map { try NSRegularExpression(pattern: $0) }
    var names = Set<String>()

    for url in sourceURLs {
        let text = try String(contentsOf: url, encoding: .utf8)
        for pattern in patterns {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in pattern.matches(in: text, range: range) {
                guard let matchRange = Range(match.range(at: 1), in: text) else {
                    continue
                }
                names.insert(String(text[matchRange]))
            }
        }
    }
    return names
}

private func swiftSourceURLs(under root: URL) throws -> [URL] {
    let enumerator = try #require(FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: nil
    ))
    return enumerator
        .compactMap { $0 as? URL }
        .filter { $0.pathExtension == "swift" }
        .sorted { $0.path < $1.path }
}

private func requiredOpenLolaCLIURL() throws -> URL {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let candidates = [
        URL(fileURLWithPath: "/private/tmp/open-lola2-swiftpm-build/debug/open-lola"),
        root.appendingPathComponent(".build/debug/open-lola"),
        root.appendingPathComponent(".build/arm64-apple-macosx/debug/open-lola"),
    ]
    return try #require(
        candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) },
        "open-lola executable must be built before executable behavior tests"
    )
}

private func runRequiredOpenLolaCLI(arguments: [String]) throws -> (exitCode: Int32, output: String) {
    let process = Process()
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-cli-probe-\(UUID().uuidString).log")
    FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    let outputHandle = try FileHandle(forWritingTo: outputURL)
    defer {
        try? outputHandle.close()
        try? FileManager.default.removeItem(at: outputURL)
    }
    process.executableURL = try requiredOpenLolaCLIURL()
    process.arguments = arguments
    process.standardOutput = outputHandle
    process.standardError = outputHandle

    try process.run()
    process.waitUntilExit()
    try outputHandle.close()

    let data = try Data(contentsOf: outputURL)
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
}

private func executableJSONPayload(from output: String) throws -> Data {
    guard let verdictRange = output.range(of: "\nVERDICT: ", options: .backwards) else {
        throw CLIExecutableProbeError.missingVerdictLine
    }
    return Data(output[..<verdictRange.lowerBound].utf8)
}

private enum CLIExecutableProbeError: Error {
    case missingVerdictLine
}
