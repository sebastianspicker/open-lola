// Verifies that machine-readable executable JSON surfaces round-trip.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func machineReadableExecutableJSONSurfacesRoundTrip() throws {
 let surfaceCases = machineReadableMRExecutableSurfaceCases()
    for surfaceCase in surfaceCases {
        #expect(!surfaceCase.name.isEmpty)
        let result = try runRequiredMROpenLolaCLI(arguments: surfaceCase.arguments)

        #expect(result.exitCode == 0)
        #expect(try mrExecutableVerdict(from: result.output) == surfaceCase.expectedVerdict)
        try surfaceCase.validate(try mrExecutableJSONPayload(from: result.output))
    }
}

@Test
func machineReadableExecutablePayloadParsingRequiresVerdictLine() {
    #expect(throws: MRCLIExecutableProbeError.missingVerdictLine) {
        _ = try mrExecutableJSONPayload(from: "{}\n")
    }
}

@Test
func machineReadableExecutableProbeRejectsStaleBinary() throws {
    let fixture = try mrExecutableFreshnessFixture(
        executableDate: Date(timeIntervalSince1970: 1_000),
        sourceDate: Date(timeIntervalSince1970: 2_000)
    )
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }

    do {
        try requireFreshOpenLolaCLI(fixture.executable, repositoryRoot: fixture.root)
        Issue.record("Expected stale open-lola executable to be rejected")
    } catch OpenLolaCLIExecutableProbeError.staleExecutable(let message) {
        #expect(message.contains("swift build --product open-lola --build-path \(fixture.root.path)/.build"))
    } catch {
        Issue.record("Expected staleExecutable, got \(error)")
    }
}

@Test
func machineReadableExecutableProbeAcceptsFreshBinary() throws {
    let fixture = try mrExecutableFreshnessFixture(
        executableDate: Date(timeIntervalSince1970: 2_000),
        sourceDate: Date(timeIntervalSince1970: 1_000)
    )
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }

    try requireFreshOpenLolaCLI(fixture.executable, repositoryRoot: fixture.root)
}

@Test
func machineReadableExecutableProbeIgnoresAppOnlySourceChanges() throws {
    let fixture = try mrExecutableFreshnessFixture(
        executableDate: Date(timeIntervalSince1970: 2_000),
        sourceDate: Date(timeIntervalSince1970: 1_000)
    )
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }

    for path in [
        "Sources/open-lola-app/AppOnlyChange.swift",
        "Sources/open-lola-app-main/AppMainOnlyChange.swift"
    ] {
        let url = fixture.root.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "public enum AppOnlyChange {}\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 3_000)],
            ofItemAtPath: url.path
        )
    }

    try requireFreshOpenLolaCLI(fixture.executable, repositoryRoot: fixture.root)
}

@Test
func machineReadableExecutableGoalTemplateRejectsFalsePassMutation() throws {
    let result = try runRequiredMROpenLolaCLI(arguments: ["goal-runtime-evidence-template"])
    var report = try JSONDecoder().decode(
        GoalRuntimeEvidenceTemplateReport.self,
        from: try mrExecutableJSONPayload(from: result.output)
    )
    assertGoalRuntimeEvidenceTemplateRejectsFalsePass(&report)
}

@Test
func openLolaExecutableRejectsUnknownCommand() throws {
    let result = try runRequiredMROpenLolaCLI(arguments: ["not-a-command"])

    #expect(result.exitCode != 0)
    #expect(result.output.contains("Usage: open-lola <command>"))
    #expect(result.output.contains("error: invalid argument: not-a-command"))
}
