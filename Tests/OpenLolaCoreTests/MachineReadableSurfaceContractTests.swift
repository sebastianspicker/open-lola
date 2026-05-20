import Foundation
import Testing

@testable import OpenLolaCore

@Test
func machineReadableExecutableJSONSurfacesRoundTrip() throws {
    let surfaceCases: [ExecutableSurfaceCase] = [
        ExecutableSurfaceCase(
            name: "session capabilities",
            arguments: ["session-capabilities"],
            expectedVerdict: .pass
        ) { data in
            let decoded = try CapabilitySet.decode(from: data)

            try decoded.validate()
            #expect(decoded == OpenLolaCLI.localCapabilitySet())
        },
        ExecutableSurfaceCase(
            name: "fixture smoke matrix",
            arguments: ["fixture-smoke-matrix"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(FixtureSmokeMatrixReport.self, from: data)

            #expect(decoded == FixtureSmokeMatrix.report())
            #expect(decoded.verdict == .partial)
        },
        ExecutableSurfaceCase(
            name: "command inventory",
            arguments: ["command-inventory"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(CLICommandInventoryReport.self, from: data)

            #expect(decoded == CLICommandInventory.report())
            #expect(decoded.verdict == .partial)
        },
        ExecutableSurfaceCase(
            name: "report schema inventory",
            arguments: ["report-schema-inventory"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(ReportSchemaInventoryReport.self, from: data)

            #expect(decoded == ReportSchemaInventory.report())
            #expect(decoded.verdict == .partial)
        },
        ExecutableSurfaceCase(
            name: "goal codewise closure",
            arguments: ["goal-codewise-closure"],
            expectedVerdict: .pass
        ) { data in
            let decoded = try JSONDecoder().decode(GoalCodewiseClosureReport.self, from: data)

            try decoded.validate()
            #expect(decoded == GoalCodewiseClosureReport.codewiseClosure())
            #expect(decoded.verdict == .pass)
            #expect(decoded.realWorldVerdict == .partial)
        },
        ExecutableSurfaceCase(
            name: "goal runtime evidence template",
            arguments: ["goal-runtime-evidence-template"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(GoalRuntimeEvidenceTemplateReport.self, from: data)

            try decoded.validate()
            #expect(decoded == GoalRuntimeEvidenceTemplateReport.template())
            #expect(decoded.verdict == .partial)
            #expect(decoded.realWorldVerdict == .partial)
        },
        ExecutableSurfaceCase(
            name: "goal runtime preflight",
            arguments: ["goal-runtime-preflight"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(GoalRuntimePreflightReport.self, from: data)

            try decoded.validate()
            #expect(decoded.verdict == .partial)
            #expect(decoded.realWorldVerdict == .partial)
        },
        ExecutableSurfaceCase(
            name: "goal completion audit",
            arguments: ["goal-completion-audit"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(GoalCompletionAuditReport.self, from: data)

            try decoded.validate()
            #expect(decoded.verdict == .partial)
            #expect(decoded.realWorldVerdict == .partial)
            #expect(!decoded.blockers.isEmpty)
        },
        ExecutableSurfaceCase(
            name: "current evidence status matrix",
            arguments: ["current-evidence-status-matrix"],
            expectedVerdict: .partial
        ) { data in
            let report = CurrentEvidenceStatusMatrixReport.current()
            let decoded = try JSONDecoder().decode(CurrentEvidenceStatusMatrixReport.self, from: data)

            try decoded.validate()
            #expect(decoded == report)
            #expect(decoded.verdict == .partial)
        },
        ExecutableSurfaceCase(
            name: "realtime audio path inventory",
            arguments: ["realtime-audio-path-inventory"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(RealtimeAudioPathInventoryReport.self, from: data)

            #expect(decoded == RealtimeAudioPathInventory.report())
            #expect(decoded.verdict == .partial)
        },
        ExecutableSurfaceCase(
            name: "network route command matrix",
            arguments: ["network-route-command-matrix"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(NetworkRouteCommandMatrixReport.self, from: data)

            #expect(decoded == NetworkRouteCommandMatrix.report())
            #expect(decoded.verdict == .partial)
        },
        ExecutableSurfaceCase(
            name: "video control degrade matrix",
            arguments: ["video-control-degrade-matrix"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(VideoControlDegradeMatrixReport.self, from: data)

            #expect(decoded == VideoControlDegradeMatrix.report())
            #expect(decoded.verdict == .partial)
        },
        ExecutableSurfaceCase(
            name: "source ownership inventory",
            arguments: ["source-ownership-inventory"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(SourceOwnershipInventoryReport.self, from: data)

            #expect(decoded == SourceOwnershipInventory.report())
            #expect(decoded.verdict == .partial)
        },
    ]

    for surfaceCase in surfaceCases {
        #expect(!surfaceCase.name.isEmpty)
        let result = try runRequiredOpenLolaCLI(arguments: surfaceCase.arguments)

        #expect(result.exitCode == 0)
        #expect(try executableVerdict(from: result.output) == surfaceCase.expectedVerdict)
        try surfaceCase.validate(try executableJSONPayload(from: result.output))
    }
}

@Test
func machineReadableExecutablePayloadParsingRequiresVerdictLine() {
    #expect(throws: CLIExecutableProbeError.missingVerdictLine) {
        _ = try executableJSONPayload(from: "{}\n")
    }
}

@Test
func machineReadableExecutableProbeRejectsStaleBinary() throws {
    let fixture = try executableFreshnessFixture(
        executableDate: Date(timeIntervalSince1970: 1_000),
        sourceDate: Date(timeIntervalSince1970: 2_000)
    )
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }

    do {
        try requireFreshOpenLolaCLI(fixture.executable, repositoryRoot: fixture.root)
        Issue.record("Expected stale open-lola executable to be rejected")
    } catch CLIExecutableProbeError.staleExecutable(let message) {
        #expect(message.contains("swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build"))
    } catch {
        Issue.record("Expected staleExecutable, got \(error)")
    }
}

@Test
func machineReadableExecutableProbeAcceptsFreshBinary() throws {
    let fixture = try executableFreshnessFixture(
        executableDate: Date(timeIntervalSince1970: 2_000),
        sourceDate: Date(timeIntervalSince1970: 1_000)
    )
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }

    try requireFreshOpenLolaCLI(fixture.executable, repositoryRoot: fixture.root)
}

@Test
func machineReadableExecutableGoalTemplateRejectsFalsePassMutation() throws {
    let result = try runRequiredOpenLolaCLI(arguments: ["goal-runtime-evidence-template"])
    var report = try JSONDecoder().decode(
        GoalRuntimeEvidenceTemplateReport.self,
        from: try executableJSONPayload(from: result.output)
    )
    report.deliverables[0].currentVerdict = .pass
    report.summary = GoalRuntimeEvidenceTemplateSummary(deliverables: report.deliverables)

    #expect(throws: GoalRuntimeEvidenceTemplateValidationError.deliverablePassWithoutPhysicalEvidence(
        GoalRuntimeEvidenceDeliverableID.twoMacRmeMadiBidirectional.rawValue
    )) {
        try report.validate()
    }
}

@Test
func openLolaExecutableRejectsUnknownCommand() throws {
    let result = try runRequiredOpenLolaCLI(arguments: ["not-a-command"])

    #expect(result.exitCode != 0)
    #expect(result.output.contains("Usage: open-lola <command>"))
    #expect(result.output.contains("error: invalid argument: not-a-command"))
}

private struct ExecutableSurfaceCase {
    var name: String
    var arguments: [String]
    var expectedVerdict: MeasurementVerdict
    var validate: (Data) throws -> Void
}

private func requiredOpenLolaCLIURL() throws -> URL {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let configuredPath = ProcessInfo.processInfo.environment["OPEN_LOLA_TEST_OPEN_LOLA_CLI"]?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let cliURL = configuredPath?.isEmpty == false
        ? URL(fileURLWithPath: configuredPath!)
        : URL(fileURLWithPath: "/private/tmp/open-lola2-swiftpm-build/debug/open-lola")
    guard FileManager.default.isExecutableFile(atPath: cliURL.path) else {
        throw CLIExecutableProbeError.missingExecutable(cliURL.path)
    }
    try requireFreshOpenLolaCLI(cliURL, repositoryRoot: root)
    return cliURL
}

private func requireFreshOpenLolaCLI(_ cliURL: URL, repositoryRoot: URL) throws {
    let executableDate = try modificationDate(cliURL)
    let sourceDate = try newestProductSourceModificationDate(repositoryRoot: repositoryRoot)
    guard executableDate.addingTimeInterval(1) >= sourceDate else {
        throw CLIExecutableProbeError.staleExecutable(
            "\(cliURL.path) is older than product sources; run swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build"
        )
    }
}

private func newestProductSourceModificationDate(repositoryRoot: URL) throws -> Date {
    var newest = try modificationDate(repositoryRoot.appendingPathComponent("Package.swift"))
    let sourceRoot = repositoryRoot.appendingPathComponent("Sources")
    guard let enumerator = FileManager.default.enumerator(
        at: sourceRoot,
        includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return newest
    }
    for case let url as URL in enumerator where isProductSource(url) {
        newest = max(newest, try modificationDate(url))
    }
    return newest
}

private func isProductSource(_ url: URL) -> Bool {
    switch url.lastPathComponent {
    case "Package.swift":
        return true
    default:
        return [
            "c",
            "cc",
            "cpp",
            "cxx",
            "h",
            "hpp",
            "m",
            "mm",
            "modulemap",
            "swift",
        ].contains(url.pathExtension)
    }
}

private func modificationDate(_ url: URL) throws -> Date {
    let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
    guard let date = values.contentModificationDate else {
        throw CLIExecutableProbeError.missingModificationDate(url.path)
    }
    return date
}

private func executableFreshnessFixture(
    executableDate: Date,
    sourceDate: Date
) throws -> (root: URL, executable: URL) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-cli-freshness-\(UUID().uuidString)")
    let sources = root.appendingPathComponent("Sources/OpenLolaCore")
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let package = root.appendingPathComponent("Package.swift")
    let source = sources.appendingPathComponent("CurrentSource.swift")
    let executable = root.appendingPathComponent("open-lola")
    try "let package = Package(name: \"OpenLoLa\")\n".write(to: package, atomically: true, encoding: .utf8)
    try "public enum CurrentSource {}\n".write(to: source, atomically: true, encoding: .utf8)
    FileManager.default.createFile(
        atPath: executable.path,
        contents: Data("#!/bin/sh\nexit 0\n".utf8)
    )
    for url in [package, source] {
        try FileManager.default.setAttributes(
            [.modificationDate: sourceDate],
            ofItemAtPath: url.path
        )
    }
    try FileManager.default.setAttributes(
        [.modificationDate: executableDate, .posixPermissions: 0o755],
        ofItemAtPath: executable.path
    )
    return (root, executable)
}

private func runRequiredOpenLolaCLI(arguments: [String]) throws -> (exitCode: Int32, output: String) {
    let process = Process()
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-machine-readable-probe-\(UUID().uuidString).log")
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

private func executableVerdict(from output: String) throws -> MeasurementVerdict {
    guard let line = output.split(separator: "\n").last(where: { $0.hasPrefix("VERDICT: ") }) else {
        throw CLIExecutableProbeError.missingVerdictLine
    }
    let value = line.dropFirst("VERDICT: ".count).lowercased()
    guard let verdict = MeasurementVerdict(rawValue: value) else {
        throw CLIExecutableProbeError.invalidVerdictLine(String(line))
    }
    return verdict
}

private func executableJSONPayload(from output: String) throws -> Data {
    guard output.contains("\nVERDICT: ") else {
        throw CLIExecutableProbeError.missingVerdictLine
    }
    guard let startIndex = output.firstIndex(of: "{") else {
        throw CLIExecutableProbeError.missingJSONPayload
    }

    var depth = 0
    var inString = false
    var escaped = false
    var index = startIndex
    while index < output.endIndex {
        let character = output[index]
        if inString {
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                inString = false
            }
        } else {
            if character == "\"" {
                inString = true
            } else if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    let endIndex = output.index(after: index)
                    return Data(output[startIndex..<endIndex].utf8)
                }
            }
        }
        index = output.index(after: index)
    }

    throw CLIExecutableProbeError.missingJSONPayload
}

private enum CLIExecutableProbeError: Error, Equatable {
    case missingExecutable(String)
    case staleExecutable(String)
    case missingModificationDate(String)
    case missingVerdictLine
    case invalidVerdictLine(String)
    case missingJSONPayload
}
