import Foundation
import Testing

@testable import OpenLolaCore

@Test
func networkRouteCommandMatrixCommandsAreBackedByExecutableRouterSource() throws {
    let matrixCommands = Set(NetworkRouteCommandMatrix.entries.map(\.command))
    let routedCommands = try executableRouterCommandNames()

    #expect(matrixCommands.subtracting(routedCommands).isEmpty)
}

@Test
func networkRouteCommandMatrixExecutableSurfaceEmitsCurrentJSONAndVerdict() throws {
    let result = try runRequiredOpenLolaCLI(arguments: ["network-route-command-matrix"])
    let report = try JSONDecoder().decode(
        NetworkRouteCommandMatrixReport.self,
        from: try executableJSONPayload(from: result.output)
    )

    #expect(result.exitCode == 0)
    #expect(report == NetworkRouteCommandMatrix.report())
    #expect(report.verdict == .partial)
    #expect(result.output.contains("VERDICT: PARTIAL"))
}

@Test
func networkRouteCommandMatrixRowsRejectInvalidExecutableArgumentsWithoutPassVerdict() throws {
    for entry in NetworkRouteCommandMatrix.entries {
        let result = try runRequiredOpenLolaCLI(arguments: invalidArguments(for: entry))

        #expect(result.exitCode != 0, "\(entry.command) unexpectedly accepted invalid arguments")
        #expect(!result.output.contains("VERDICT: PASS"), "\(entry.command) reported PASS for invalid arguments")
    }
}

@Test
func networkRouteCommandMatrixEntriesHaveExistingOwnersSourcesAndTests() {
    let root = repositoryRoot

    for entry in NetworkRouteCommandMatrix.entries {
        #expect(!entry.command.isEmpty)
        #expect(!entry.parser.isEmpty)
        #expect(!entry.outputReport.isEmpty)
        #expect(!entry.representativeCommand.isEmpty)
        #expect(!entry.notes.isEmpty)
        #expect(FileManager.default.fileExists(
            atPath: root.appendingPathComponent(entry.ownerSourceFile).path
        ))
        for path in entry.relatedSourceFiles + entry.relatedTestFiles {
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }
}

@Test
func networkRouteCommandMatrixCommandsAreCoveredByCLIInventory() {
    let matrixCommands = Set(NetworkRouteCommandMatrix.entries.map(\.command))
    let inventoryCommands = Set(CLICommandInventory.entries.map(\.command))

    #expect(matrixCommands.isSubset(of: inventoryCommands))
    #expect(inventoryCommands.contains("network-route-command-matrix"))
}

@Test
func networkRouteCommandMatrixKeepsNatDiagnosticsAndLocalSmokesOutOfFastestEvidence() {
    let fastestCommands = Set(NetworkRouteCommandMatrix.entries
        .filter(\.canContributeToFastestDirectEvidence)
        .map(\.command))

    #expect(fastestCommands == [
        "udp-pcm-route-run",
        "validate-route-report",
        "validate-route-certification-report",
    ])

    for entry in NetworkRouteCommandMatrix.entries {
        if entry.evidenceBoundary == .natCompatibilityOnly
            || entry.evidenceBoundary == .diagnosticOnly
            || entry.evidenceBoundary == .connectionPreflight
            || entry.evidenceBoundary == .loopbackMeasurement
            || entry.evidenceBoundary == .packetContractOnly
            || entry.evidenceBoundary == .directPeerSessionPartialOnly {
            #expect(!entry.canContributeToFastestDirectEvidence)
        }
    }
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func invalidArguments(for entry: NetworkRouteCommandMatrixEntry) -> [String] {
    let missingPath = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-missing-\(UUID().uuidString).json")
        .path

    switch entry.command {
    case "udp-pcm-send-once":
        return [entry.command, "127.0.0.1", "not-a-port"]
    case "udp-pcm-receive-once":
        return [entry.command, "not-a-port"]
    case "validate-udp-pcm-loopback-session":
        return [entry.command, missingPath, missingPath]
    default:
        break
    }

    switch entry.kind {
    case .validator:
        return [entry.command, missingPath]
    case .run, .syntheticSmoke:
        return [entry.command]
    case .localhostSmoke:
        return entry.parser == "fixed command" ? [entry.command, "--unexpected"] : [entry.command]
    case .inventory, .probe:
        return [entry.command, "--unexpected"]
    }
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
        "open-lola executable must be built before executable route matrix tests"
    )
}

private func runRequiredOpenLolaCLI(arguments: [String]) throws -> (exitCode: Int32, output: String) {
    let process = Process()
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-network-route-matrix-\(UUID().uuidString).log")
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
