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
    let candidates = [
        URL(fileURLWithPath: "/private/tmp/open-lola2-swiftpm-build/debug/open-lola"),
        root.appendingPathComponent(".build/debug/open-lola"),
        root.appendingPathComponent(".build/arm64-apple-macosx/debug/open-lola"),
    ]
    return try #require(
        candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) },
        "open-lola executable must be built before executable machine-readable surface tests"
    )
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
    case missingVerdictLine
    case invalidVerdictLine(String)
    case missingJSONPayload
}
