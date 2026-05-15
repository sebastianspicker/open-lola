import Foundation
import Testing

@testable import OpenLolaCore

@Test
func externalConnectorNmpWorkflowRunsPlanPreflightAndEndpointSide() throws {
    let ultraGrid = try makeNmpWorkflowProbeExecutable(
        name: "uv",
        output: "UltraGrid - A High Definition Collaboratory -t capture -d display"
    )
    let jackTrip = try makeNmpWorkflowProbeExecutable(
        name: "jacktrip",
        output: "JackTrip VERSION: 2.7.0"
    )
    defer {
        try? FileManager.default.removeItem(atPath: ultraGrid)
        try? FileManager.default.removeItem(atPath: jackTrip)
    }
    let configuration = try ExternalConnectorNmpWorkflowConfiguration.parse([
        "--local-host", "198.51.100.20",
        "--remote-host", "198.51.100.10",
        "--output", "/tmp/open-lola-nmp-workflow/workflow.json",
        "--side", "local",
        "--dry-run", "true",
        "--connectors", "lola,mvtp-ultragrid,jacktrip",
        "--ultragrid-executable", ultraGrid,
        "--jacktrip-executable", jackTrip,
        "--local-raw-link-interface", "en10",
        "--remote-raw-link-interface", "en11",
        "--local-mac", "02:00:00:00:00:0a",
        "--remote-mac", "02:00:00:00:00:0b",
    ])

    let report = try ExternalConnectorNmpWorkflowRunner.run(configuration: configuration)
    let lolaLocalTxRx = try #require(report.endpointRun.results.first {
        $0.connector == .lola && $0.side == .local && $0.direction == .bidirectional && $0.role == .txRx
    })

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.planPath == "/tmp/open-lola-nmp-workflow/nmp-plan.json")
    #expect(report.preflight.verdict == .pass)
    #expect(report.endpointRun.verdict == .partial)
    #expect(report.endpointRun.results.count == 3)
    #expect(report.endpointRun.results.allSatisfy { $0.report.dryRun })
    #expect(optionValue("--raw-link-interface", in: lolaLocalTxRx.command) == "en10")
    #expect(optionValue("--source-mac", in: lolaLocalTxRx.command) == "02:00:00:00:00:0a")
    #expect(optionValue("--destination-mac", in: lolaLocalTxRx.command) == "02:00:00:00:00:0b")
}

@Test
func externalConnectorNmpWorkflowUsesPreflightDiscoveredExecutablesForEndpoints() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("open-lola-nmp-workflow-discovery-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let pythonUv = try makeNmpWorkflowProbeExecutable(
        directory: directory,
        name: "uv",
        output: "An extremely fast Python package manager."
    )
    let ultraGridAlias = try makeNmpWorkflowProbeExecutable(
        directory: directory,
        name: "uv-ug",
        output: "UltraGrid - A High Definition Collaboratory -t capture -d display -s audio -r playback"
    )
    let jackTrip = try makeNmpWorkflowProbeExecutable(
        name: "jacktrip",
        output: "JackTrip VERSION: 2.7.0"
    )
    defer {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.removeItem(atPath: jackTrip)
    }
    let configuration = try ExternalConnectorNmpWorkflowConfiguration.parse([
        "--local-host", "198.51.100.20",
        "--remote-host", "198.51.100.10",
        "--output", "/tmp/open-lola-nmp-workflow-discovery/workflow.json",
        "--side", "local",
        "--dry-run", "true",
        "--connectors", "lola,mvtp-ultragrid,jacktrip",
        "--ultragrid-executable", pythonUv,
        "--jacktrip-executable", jackTrip,
    ])

    let report = try ExternalConnectorNmpWorkflowRunner.run(configuration: configuration)

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.preflight.verdict == .pass)
    let ultraGridCommands = report.endpointRun.results
        .filter { $0.connector == .mvtpUltraGrid }
        .map(\.command)
    let jackTripCommands = report.endpointRun.results
        .filter { $0.connector == .jackTrip }
        .map(\.command)
    #expect(ultraGridCommands.allSatisfy { optionValue("--executable", in: $0) == ultraGridAlias })
    #expect(jackTripCommands.allSatisfy { optionValue("--executable", in: $0) == jackTrip })
    #expect(jackTripCommands.allSatisfy { optionValue("--video-executable", in: $0) == ultraGridAlias })
}

@Test
func externalConnectorNmpWorkflowRunsBothEndpointSides() throws {
    let ultraGrid = try makeNmpWorkflowProbeExecutable(
        name: "uv",
        output: "UltraGrid - A High Definition Collaboratory -t capture -d display"
    )
    let jackTrip = try makeNmpWorkflowProbeExecutable(
        name: "jacktrip",
        output: "JackTrip VERSION: 2.7.0"
    )
    defer {
        try? FileManager.default.removeItem(atPath: ultraGrid)
        try? FileManager.default.removeItem(atPath: jackTrip)
    }
    let configuration = try ExternalConnectorNmpWorkflowConfiguration.parse([
        "--local-host", "198.51.100.20",
        "--remote-host", "198.51.100.10",
        "--output", "/tmp/open-lola-nmp-workflow-both/workflow.json",
        "--side", "both",
        "--dry-run", "true",
        "--connectors", "lola,mvtp-ultragrid,jacktrip",
        "--ultragrid-executable", ultraGrid,
        "--jacktrip-executable", jackTrip,
    ])

    let report = try ExternalConnectorNmpWorkflowRunner.run(configuration: configuration)

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.side == .both)
    #expect(report.endpointRunPath == "/tmp/open-lola-nmp-workflow-both/nmp-both-endpoint-run.json")
    #expect(report.endpointRun.side == .both)
    #expect(report.endpointRun.results.count == 6)
    #expect(Set(report.endpointRun.results.map(\.side)) == [.local, .remote])
    #expect(Set(report.endpointRun.results.map(\.connector)) == [.lola, .mvtpUltraGrid, .jackTrip])
    #expect(Set(report.endpointRun.results.map(\.role)) == [.txRx, .rx, .tx])
    #expect(report.endpointRun.results.allSatisfy { $0.report.dryRun })
    #expect(report.notes.contains("both sides"))
}

@Test
func externalConnectorNmpWorkflowFailsWhenExecutablePreflightFails() throws {
    let pythonUv = try makeNmpWorkflowProbeExecutable(
        name: "uv",
        output: "An extremely fast Python package manager."
    )
    defer { try? FileManager.default.removeItem(atPath: pythonUv) }
    let configuration = try ExternalConnectorNmpWorkflowConfiguration.parse([
        "--local-host", "198.51.100.20",
        "--remote-host", "198.51.100.10",
        "--output", "/tmp/open-lola-nmp-workflow/workflow.json",
        "--side", "local",
        "--dry-run", "true",
        "--connectors", "lola,mvtp-ultragrid,jacktrip",
        "--ultragrid-executable", pythonUv,
        "--jacktrip-executable", "/tmp/open-lola-missing-jacktrip-\(UUID().uuidString)",
    ])

    let report = try ExternalConnectorNmpWorkflowRunner.run(configuration: configuration)

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.preflight.verdict == .fail)
    #expect(report.endpointRun.verdict == .partial)
}

@Test
func externalConnectorNmpWorkflowParserRejectsUnknownArguments() {
    #expect(throws: ExternalConnectorSessionError.unknownArgument("--bad")) {
        _ = try ExternalConnectorNmpWorkflowConfiguration.parse([
            "--local-host", "198.51.100.20",
            "--remote-host", "198.51.100.10",
            "--output", "/tmp/workflow.json",
            "--side", "local",
            "--bad", "value",
        ])
    }
}

@Test
func externalConnectorNmpWorkflowParserRejectsInvalidSideAsInvalidSide() {
    #expect(throws: ExternalConnectorSessionError.invalidConnectionSide("sideways")) {
        _ = try ExternalConnectorNmpWorkflowConfiguration.parse([
            "--local-host", "198.51.100.20",
            "--remote-host", "198.51.100.10",
            "--output", "/tmp/workflow.json",
            "--side", "sideways",
        ])
    }
}

@Test
func externalConnectorNmpWorkflowRejectsRawLinkInputsWithoutLoLaConnector() throws {
    let configuration = try ExternalConnectorNmpWorkflowConfiguration.parse([
        "--local-host", "198.51.100.20",
        "--remote-host", "198.51.100.10",
        "--output", "/tmp/workflow.json",
        "--side", "local",
        "--connectors", "mvtp-ultragrid,jacktrip",
        "--local-raw-link-interface", "en10",
        "--remote-raw-link-interface", "en11",
        "--local-mac", "02:00:00:00:00:0a",
        "--remote-mac", "02:00:00:00:00:0b",
    ])

    #expect(throws: ExternalConnectorSessionError.rawLinkRequiresLoLaConnector) {
        _ = try ExternalConnectorNmpWorkflowRunner.run(configuration: configuration)
    }
}

private func makeNmpWorkflowProbeExecutable(name: String, output: String) throws -> String {
    let path = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("open-lola-nmp-workflow-\(name)-probe-\(UUID().uuidString).sh")
    return try makeNmpWorkflowProbeExecutable(path: path, output: output)
}

private func makeNmpWorkflowProbeExecutable(directory: URL, name: String, output: String) throws -> String {
    try makeNmpWorkflowProbeExecutable(
        path: directory.appendingPathComponent(name),
        output: output
    )
}

private func makeNmpWorkflowProbeExecutable(path: URL, output: String) throws -> String {
    try "#!/bin/sh\necho '\(output)'\n".write(to: path, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
    return path.path
}

private func optionValue(_ option: String, in command: [String]) -> String? {
    guard let index = command.firstIndex(of: option), index + 1 < command.count else {
        return nil
    }
    return command[index + 1]
}
