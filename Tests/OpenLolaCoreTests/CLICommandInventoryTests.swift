// Verifies that command inventory commands are backed by executable router source.
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

@Test
func openLolaExecutableTwoPeerReportHelpKeepsCanonicalAndCompatibilityCommands() throws {
    let canonical = try runRequiredOpenLolaCLI(arguments: ["direct-p2p-two-peer-report", "--help"])
    let compatibility = try runRequiredOpenLolaCLI(arguments: ["direct-p2p-two-peer-prototype-report", "--help"])

    #expect(canonical.exitCode == 0)
    #expect(canonical.output.contains("Usage: open-lola direct-p2p-two-peer-report"))
    #expect(canonical.output.contains("--peer-a-report"))
    #expect(canonical.output.contains("--peer-b-rx-proof"))
    #expect(compatibility.exitCode == 0)
    #expect(compatibility.output.contains("Usage: open-lola direct-p2p-two-peer-prototype-report"))
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func executableRouterCommandNames() throws -> Set<String> {
    try openLolaExecutableRouterCommandNames(repositoryRoot: repositoryRoot)
}

private func runRequiredOpenLolaCLI(arguments: [String]) throws -> (exitCode: Int32, output: String) {
    try runFreshOpenLolaCLI(
        arguments: arguments,
        context: "executable behavior tests",
        logPrefix: "open-lola-cli-probe"
    )
}
