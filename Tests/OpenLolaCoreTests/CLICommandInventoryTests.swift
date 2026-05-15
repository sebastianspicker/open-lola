import Foundation
import Testing

@testable import OpenLolaCore

@Test
func commandInventoryMatchesExecutableCommandSources() throws {
    let discovered = try discoverExecutableCommands()
    let inventoried = Set(CLICommandInventory.entries.map(\.command))

    #expect(discovered == inventoried)
}

@Test
func commandInventoryHasNoDuplicateCommands() {
    let commands = CLICommandInventory.entries.map(\.command)

    #expect(commands.count == Set(commands).count)
}

@Test
func commandInventoryEntriesHaveConcreteOwnersAndValidationPaths() {
    let root = repositoryRoot

    for entry in CLICommandInventory.entries {
        #expect(!entry.command.isEmpty)
        #expect(!entry.parser.isEmpty)
        #expect(!entry.validationPath.isEmpty)
        #expect(FileManager.default.fileExists(
            atPath: root.appendingPathComponent(entry.ownerSourceFile).path
        ))
        #expect(!entry.relatedTestFiles.isEmpty)
        for path in entry.relatedTestFiles {
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }
}

@Test
func commandInventorySummaryMatchesEntries() {
    let summary = CLICommandInventory.summary()

    #expect(summary.commandCount == CLICommandInventory.entries.count)
    #expect(summary.validatorCount == CLICommandInventory.entries.filter { $0.kind == .validator }.count)
    #expect(summary.runCount == CLICommandInventory.entries.filter { $0.kind == .run }.count)
    #expect(summary.syntheticSmokeCount == CLICommandInventory.entries.filter { $0.kind == .syntheticSmoke }.count)
    #expect(summary.localhostSmokeCount == CLICommandInventory.entries.filter { $0.kind == .localhostSmoke }.count)
}

@Test
func commandInventoryExcludesDeprecatedFixtureOnlyParitySmoke() {
    let commands = Set(CLICommandInventory.entries.map(\.command))

    #expect(!commands.contains("lola-parity-deferred-synthetic-smoke"))
}

@Test
func commandInventoryJSONSurfaceRoundTrips() throws {
    let data = try OpenLolaCLI.commandInventoryData()
    let decoded = try JSONDecoder().decode(CLICommandInventoryReport.self, from: data)

    #expect(decoded == CLICommandInventory.report())
    #expect(decoded.verdict == .partial)
}

@Test
func openLolaExecutableTopLevelHelpListsInventoryCommands() throws {
    let result = try runRequiredOpenLolaCLI(arguments: ["--help"])

    #expect(result.exitCode == 0)
    #expect(result.output.contains("Usage: open-lola <command> [...]"))
    for command in CLICommandInventory.entries.map(\.command) {
        #expect(result.output.contains("  \(command)"))
    }
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

@Test
func openLolaExecutableNativeAppSurfaceProbeEmitsPartialReport() throws {
    let result = try runRequiredOpenLolaCLI(arguments: ["native-app-shell-surface-probe"])
    let report = try NativeAppShellSurfaceProbeReport.decode(from: try executableJSONPayload(from: result.output))

    #expect(result.exitCode == 0)
    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.launchProbePlan.appTargetName == "open-lola-app")
    #expect(result.output.contains("VERDICT: PARTIAL"))
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
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

private func discoverExecutableCommands() throws -> Set<String> {
    let sourceRoot = repositoryRoot.appendingPathComponent("Sources/open-lola")
    let patterns = [
        #"case\s+\["([a-z0-9-]+)"\]"#,
        #"args\[0\]\s*==\s*"([a-z0-9-]+)""#,
        #"args\.first\s*==\s*"([a-z0-9-]+)""#,
        #"RegisteredCommand\(name:\s*"([a-z0-9-]+)""#,
    ]
    let regexes = try patterns.map { try NSRegularExpression(pattern: $0) }
    var commands = Set<String>()
    guard let enumerator = FileManager.default.enumerator(
        at: sourceRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return commands
    }

    for case let url as URL in enumerator where url.pathExtension == "swift" {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else {
            continue
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        for regex in regexes {
            for match in regex.matches(in: source, range: range) {
                guard let commandRange = Range(match.range(at: 1), in: source) else {
                    continue
                }
                commands.insert(String(source[commandRange]))
            }
        }
    }
    return commands
}
