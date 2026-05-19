import Foundation
import Testing

@testable import OpenLolaCore

@Test
func externalConnectorNmpPreflightRunsPlanScopedExecutableChecks() throws {
    let ultraGrid = try makeNmpProbeExecutable(
        name: "uv",
        output: "UltraGrid - A High Definition Collaboratory -t capture -d display"
    )
    let jackTrip = try makeNmpProbeExecutable(
        name: "jacktrip",
        output: "JackTrip VERSION: 2.7.0"
    )
    defer {
        try? FileManager.default.removeItem(atPath: ultraGrid)
        try? FileManager.default.removeItem(atPath: jackTrip)
    }
    let plan = try ExternalConnectorNmpPlanRunner.run(configuration: ExternalConnectorNmpPlanConfiguration(
        localHost: "198.51.100.20",
        remoteHost: "198.51.100.10",
        outputPath: "/tmp/nmp-plan.json",
        connectors: [.lola, .mvtpUltraGrid, .jackTrip],
        ultraGridExecutable: ultraGrid,
        jackTripExecutable: jackTrip
    ))

    let report = try ExternalConnectorNmpPreflightRunner.run(
        configuration: ExternalConnectorNmpPreflightConfiguration(
            planPath: "/tmp/nmp-plan.json",
            outputPath: "/tmp/nmp-preflight.json"
        ),
        plan: plan
    )

    try report.validate()
    #expect(report.verdict == .pass)
    #expect(report.results.map(\.connector) == [.lola, .mvtpUltraGrid, .jackTrip])
    #expect(report.results.first { $0.connector == .lola }?.skippedReason?.contains("internal") == true)
    #expect(report.results.first { $0.connector == .mvtpUltraGrid }?.skippedReason?.contains("internal") == true)
    #expect(report.results.first { $0.connector == .jackTrip }?.report?.verdict == .pass)
}

@Test
func externalConnectorNmpPreflightFailsWhenAnyPlanPreflightFails() throws {
    let pythonUv = try makeNmpProbeExecutable(
        name: "uv",
        output: "An extremely fast Python package manager."
    )
    defer { try? FileManager.default.removeItem(atPath: pythonUv) }
    let plan = try ExternalConnectorNmpPlanRunner.run(configuration: ExternalConnectorNmpPlanConfiguration(
        localHost: "198.51.100.20",
        remoteHost: "198.51.100.10",
        outputPath: "/tmp/nmp-plan.json",
        connectors: [.lola, .mvtpUltraGrid, .jackTrip],
        ultraGridExecutable: pythonUv,
        jackTripExecutable: "/tmp/open-lola-missing-jacktrip-\(UUID().uuidString)"
    ))

    let report = try ExternalConnectorNmpPreflightRunner.run(
        configuration: ExternalConnectorNmpPreflightConfiguration(
            planPath: "/tmp/nmp-plan.json",
            outputPath: "/tmp/nmp-preflight.json"
        ),
        plan: plan
    )

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.results.first { $0.connector == .mvtpUltraGrid }?.skippedReason?.contains("internal") == true)
    #expect(report.results.first { $0.connector == .jackTrip }?.report?.verdict == .fail)
}

@Test
func externalConnectorNmpPreflightParserRejectsUnknownArguments() {
    #expect(throws: ExternalConnectorSessionError.unknownArgument("--bad")) {
        _ = try ExternalConnectorNmpPreflightConfiguration.parse([
            "--plan", "/tmp/nmp-plan.json",
            "--output", "/tmp/nmp-preflight.json",
            "--bad", "value",
        ])
    }
}

private func makeNmpProbeExecutable(name: String, output: String) throws -> String {
    let path = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("open-lola-nmp-\(name)-probe-\(UUID().uuidString).sh")
    try "#!/bin/sh\necho '\(output)'\n".write(to: path, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
    return path.path
}
