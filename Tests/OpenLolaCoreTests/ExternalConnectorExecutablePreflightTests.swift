import Foundation
import Testing

@testable import OpenLolaCore

@Test
func externalConnectorExecutablePreflightPassesRecognizedUltraGridAndJackTripBinaries() throws {
    let ultraGrid = try makeExternalConnectorProbeExecutable(
        name: "uv",
        output: "UltraGrid - A High Definition Collaboratory -t capture -d display -s audio -r playback"
    )
    let jackTrip = try makeExternalConnectorProbeExecutable(
        name: "jacktrip",
        output: "JackTrip VERSION: 2.7.0"
    )
    defer {
        try? FileManager.default.removeItem(atPath: ultraGrid)
        try? FileManager.default.removeItem(atPath: jackTrip)
    }

    let report = ExternalConnectorExecutablePreflightRunner.run(configuration: ExternalConnectorExecutablePreflightConfiguration(
        outputPath: "/tmp/external-connector-executable-preflight-pass.json",
        ultraGridExecutable: ultraGrid,
        jackTripExecutable: jackTrip
    ))

    try report.validate()
    #expect(report.verdict == .pass)
    #expect(report.probes.count == 3)
    let lolaProbe = try #require(report.probes.first { $0.connector == .lola })
    #expect(lolaProbe.launched == false)
    #expect(lolaProbe.evidenceStatus == "internal-not-required")
    #expect(lolaProbe.notes.contains("no external LoLa executable is required"))
    #expect(report.probes.first { $0.connector == .mvtpUltraGrid }?.detectedIdentity == .ultraGrid)
    #expect(report.probes.first { $0.connector == .mvtpUltraGrid }?.evidenceStatus == "launched-and-matched")
    #expect(report.probes.first { $0.connector == .jackTrip }?.detectedIdentity == .jackTrip)
    #expect(report.notes.contains("PATH collisions"))
}

@Test
func externalConnectorExecutablePreflightDetectsPythonUvAndMissingJackTrip() throws {
    let pythonUv = try makeExternalConnectorProbeExecutable(
        name: "uv",
        output: "An extremely fast Python package manager."
    )
    defer { try? FileManager.default.removeItem(atPath: pythonUv) }
    let missingJackTrip = "/tmp/open-lola-missing-jacktrip-\(UUID().uuidString)"

    let report = ExternalConnectorExecutablePreflightRunner.run(configuration: ExternalConnectorExecutablePreflightConfiguration(
        outputPath: "/tmp/external-connector-executable-preflight-fail.json",
        ultraGridExecutable: pythonUv,
        jackTripExecutable: missingJackTrip
    ))

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.probes.first { $0.connector == .mvtpUltraGrid }?.detectedIdentity == .pythonUv)
    #expect(report.probes.first { $0.connector == .jackTrip }?.detectedIdentity == .missing)
    #expect(report.probes.filter { $0.verdict == .fail }.count == 2)
}

@Test
func externalConnectorExecutablePreflightDiscoversSiblingUltraGridAliasAfterPythonUvCollision() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("open-lola-ultragrid-discovery-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let pythonUv = try makeExternalConnectorProbeExecutable(
        directory: directory,
        name: "uv",
        output: "An extremely fast Python package manager."
    )
    let ultraGridAlias = try makeExternalConnectorProbeExecutable(
        directory: directory,
        name: "uv-ug",
        output: "UltraGrid - A High Definition Collaboratory -t capture -d display -s audio -r playback"
    )
    let jackTrip = try makeExternalConnectorProbeExecutable(
        name: "jacktrip",
        output: "JackTrip VERSION: 2.7.0"
    )
    defer {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.removeItem(atPath: jackTrip)
    }

    let report = ExternalConnectorExecutablePreflightRunner.run(configuration: ExternalConnectorExecutablePreflightConfiguration(
        outputPath: "/tmp/external-connector-executable-preflight-discovery.json",
        ultraGridExecutable: pythonUv,
        jackTripExecutable: jackTrip
    ))

    try report.validate()
    let ultraGridProbe = try #require(report.probes.first { $0.connector == .mvtpUltraGrid })
    #expect(report.verdict == .pass)
    #expect(ultraGridProbe.executable == ultraGridAlias)
    #expect(ultraGridProbe.detectedIdentity == .ultraGrid)
    #expect(ultraGridProbe.notes.contains("Selected \(ultraGridAlias)"))
}

@Test
func externalConnectorExecutablePreflightCanScopeToUltraGridOnly() throws {
    let ultraGrid = try makeExternalConnectorProbeExecutable(
        name: "uv",
        output: "UltraGrid - A High Definition Collaboratory -t capture -d display"
    )
    defer { try? FileManager.default.removeItem(atPath: ultraGrid) }

    let report = ExternalConnectorExecutablePreflightRunner.run(configuration: ExternalConnectorExecutablePreflightConfiguration(
        outputPath: "/tmp/external-connector-executable-preflight-ultragrid.json",
        connector: .mvtpUltraGrid,
        ultraGridExecutable: ultraGrid,
        jackTripExecutable: "/tmp/open-lola-missing-jacktrip-\(UUID().uuidString)"
    ))

    try report.validate()
    #expect(report.verdict == .pass)
    #expect(report.probes.map(\.connector) == [.mvtpUltraGrid])
}

@Test
func externalConnectorExecutablePreflightRejectsUnknownArguments() {
    #expect(throws: ExternalConnectorExecutablePreflightError.unknownArgument("--bad")) {
        _ = try ExternalConnectorExecutablePreflightConfiguration.parse([
            "--output", "/tmp/preflight.json",
            "--bad", "value",
        ])
    }
}

@Test
func externalConnectorExecutablePreflightParserAcceptsConnectorScope() throws {
    let configuration = try ExternalConnectorExecutablePreflightConfiguration.parse([
        "--output", "/tmp/preflight.json",
        "--connector", "jacktrip",
    ])

    #expect(configuration.connector == .jackTrip)
}

@Test
func externalConnectorExecutablePreflightValidationRejectsFalsePass() throws {
    var report = ExternalConnectorExecutablePreflightRunner.run(configuration: ExternalConnectorExecutablePreflightConfiguration(
        outputPath: "/tmp/external-connector-executable-preflight-false-pass.json",
        ultraGridExecutable: "/tmp/open-lola-missing-uv-\(UUID().uuidString)",
        jackTripExecutable: "/tmp/open-lola-missing-jacktrip-\(UUID().uuidString)"
    ))
    report.verdict = .pass

    #expect(throws: ExternalConnectorExecutablePreflightError.passWithFailingProbe("external-connector-executable-ultragrid-uv")) {
        try report.validate()
    }
}

private func makeExternalConnectorProbeExecutable(name: String, output: String) throws -> String {
    let path = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("open-lola-\(name)-probe-\(UUID().uuidString).sh")
    return try makeExternalConnectorProbeExecutable(path: path, output: output)
}

private func makeExternalConnectorProbeExecutable(directory: URL, name: String, output: String) throws -> String {
    try makeExternalConnectorProbeExecutable(
        path: directory.appendingPathComponent(name),
        output: output
    )
}

private func makeExternalConnectorProbeExecutable(path: URL, output: String) throws -> String {
    try "#!/bin/sh\necho '\(output)'\n".write(to: path, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
    return path.path
}
