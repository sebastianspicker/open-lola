// Verifies that network route command matrix commands are backed by executable router source.
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
        for path in entry.relatedSourceFiles
            + entry.relatedTestFiles
            + repositoryRelativePaths(in: entry.representativeCommand) {
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
        "validate-route-certification-report"
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

    if let commandArguments = commandSpecificInvalidArguments(
        for: entry.command,
        missingPath: missingPath
    ) {
        return commandArguments
    }

    return kindSpecificInvalidArguments(for: entry, missingPath: missingPath)
}

private func kindSpecificInvalidArguments(
    for entry: NetworkRouteCommandMatrixEntry,
    missingPath: String
) -> [String] {
    switch entry.kind {
    case .validator:
        return [entry.command, missingPath]
    case .run, .syntheticSmoke:
        return [entry.command]
    case .localhostSmoke:
        if entry.parser == "fixed command" {
            return [entry.command, "--unexpected"]
        }
        return [entry.command]
    case .inventory, .probe:
        return [entry.command, "--unexpected"]
    }
}

private func commandSpecificInvalidArguments(
    for command: String,
    missingPath: String
) -> [String]? {
    switch command {
    case "udp-pcm-send-once":
        return [command, "127.0.0.1", "not-a-port"]
    case "udp-pcm-receive-once":
        return [command, "not-a-port"]
    case "validate-udp-pcm-loopback-session":
        return [command, missingPath, missingPath]
    default:
        return nil
    }
}

private func executableRouterCommandNames() throws -> Set<String> {
    try openLolaExecutableRouterCommandNames(repositoryRoot: repositoryRoot)
}

private func repositoryRelativePaths(in command: String) -> [String] {
    repositoryRelativePaths(in: command, trackedPrefixes: [
        "Package.swift", "README.md", "Sources/", "Tests/", "docs/", "linux_connector/", "scripts/"
    ])
}

private func runRequiredOpenLolaCLI(arguments: [String]) throws -> (exitCode: Int32, output: String) {
    try runFreshOpenLolaCLI(
        arguments: arguments,
        context: "executable route matrix tests",
        logPrefix: "open-lola-network-route-matrix"
    )
}
