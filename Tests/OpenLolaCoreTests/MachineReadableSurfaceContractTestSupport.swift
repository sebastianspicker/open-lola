// Shared Machine readable surface contract helpers keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaCore

func machineReadableMRExecutableSurfaceCases() -> [MRExecutableSurfaceCase] {
 machineReadableCoreSurfaceCases() + machineReadableGoalSurfaceCases() + machineReadableMediaSurfaceCases()
}

func machineReadableCoreSurfaceCases() -> [MRExecutableSurfaceCase] {
 [
        MRExecutableSurfaceCase(
            name: "session capabilities",
            arguments: ["session-capabilities"],
            expectedVerdict: .pass
        ) { data in
            let decoded = try CapabilitySet.decode(from: data)
            try decoded.validate()
            #expect(decoded == OpenLolaCLI.localCapabilitySet())
        },
        MRExecutableSurfaceCase(
            name: "fixture smoke matrix",
            arguments: ["fixture-smoke-matrix"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(FixtureSmokeMatrixReport.self, from: data)
            #expect(decoded == FixtureSmokeMatrix.report())
            #expect(decoded.verdict == .partial)
        },
        MRExecutableSurfaceCase(
            name: "command inventory",
            arguments: ["command-inventory"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(CLICommandInventoryReport.self, from: data)
            #expect(decoded == CLICommandInventory.report())
            #expect(decoded.verdict == .partial)
        },
        MRExecutableSurfaceCase(
            name: "report schema inventory",
            arguments: ["report-schema-inventory"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(ReportSchemaInventoryReport.self, from: data)
            #expect(decoded == ReportSchemaInventory.report())
            #expect(decoded.verdict == .partial)
        }
 ]
}
func machineReadableGoalSurfaceCases() -> [MRExecutableSurfaceCase] {
 [
        MRExecutableSurfaceCase(
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
        MRExecutableSurfaceCase(
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
        MRExecutableSurfaceCase(
            name: "goal runtime preflight",
            arguments: ["goal-runtime-preflight"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(GoalRuntimePreflightReport.self, from: data)
            try decoded.validate()
            #expect(decoded.verdict == .partial)
            #expect(decoded.realWorldVerdict == .partial)
        },
        MRExecutableSurfaceCase(
            name: "goal completion audit",
            arguments: ["goal-completion-audit"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(GoalCompletionAuditReport.self, from: data)
            try decoded.validate()
            #expect(decoded.verdict == .partial)
            #expect(decoded.realWorldVerdict == .partial)
            #expect(!decoded.blockers.isEmpty)
        }
 ]
}
func machineReadableMediaSurfaceCases() -> [MRExecutableSurfaceCase] {
    machineReadableRouteSurfaceCases() + machineReadableVideoSurfaceCases()
}
func machineReadableRouteSurfaceCases() -> [MRExecutableSurfaceCase] {
    [
        MRExecutableSurfaceCase(
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
        MRExecutableSurfaceCase(
            name: "realtime audio path inventory",
            arguments: ["realtime-audio-path-inventory"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(RealtimeAudioPathInventoryReport.self, from: data)
            #expect(decoded == RealtimeAudioPathInventory.report())
            #expect(decoded.verdict == .partial)
        },
        MRExecutableSurfaceCase(
            name: "network route command matrix",
            arguments: ["network-route-command-matrix"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(NetworkRouteCommandMatrixReport.self, from: data)
            #expect(decoded == NetworkRouteCommandMatrix.report())
            #expect(decoded.verdict == .partial)
        }
    ]
}
func machineReadableVideoSurfaceCases() -> [MRExecutableSurfaceCase] {
    [
        MRExecutableSurfaceCase(
            name: "video control degrade matrix",
            arguments: ["video-control-degrade-matrix"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(VideoControlDegradeMatrixReport.self, from: data)
            #expect(decoded == VideoControlDegradeMatrix.report())
            #expect(decoded.verdict == .partial)
        },
        MRExecutableSurfaceCase(
            name: "source ownership inventory",
            arguments: ["source-ownership-inventory"],
            expectedVerdict: .partial
        ) { data in
            let decoded = try JSONDecoder().decode(SourceOwnershipInventoryReport.self, from: data)
            #expect(decoded == SourceOwnershipInventory.report())
            #expect(decoded.verdict == .partial)
        }
    ]
}

struct MRExecutableSurfaceCase {
    var name: String
    var arguments: [String]
    var expectedVerdict: MeasurementVerdict
    var validate: (Data) throws -> Void
}

func requiredMROpenLolaCLIURL() throws -> URL {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try requiredFreshOpenLolaCLIURL(
        repositoryRoot: root,
        context: "machine-readable executable behavior tests"
    )
}

func mrExecutableFreshnessFixture(
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

func runRequiredMROpenLolaCLI(arguments: [String]) throws -> (exitCode: Int32, output: String) {
    try runFreshOpenLolaCLI(
        arguments: arguments,
        context: "machine-readable executable behavior tests",
        logPrefix: "open-lola-machine-readable-probe"
    )
}

func mrExecutableVerdict(from output: String) throws -> MeasurementVerdict {
    guard let line = output.split(separator: "\n").last(where: { $0.hasPrefix("VERDICT: ") }) else {
        throw MRCLIExecutableProbeError.missingVerdictLine
    }
    let value = line.dropFirst("VERDICT: ".count).lowercased()
    guard let verdict = MeasurementVerdict(rawValue: value) else {
        throw MRCLIExecutableProbeError.invalidVerdictLine(String(line))
    }
    return verdict
}

func mrExecutableJSONPayload(from output: String) throws -> Data {
    guard output.contains("\nVERDICT: ") else {
        throw MRCLIExecutableProbeError.missingVerdictLine
    }
    guard let startIndex = output.firstIndex(of: "{") else {
        throw MRCLIExecutableProbeError.missingJSONPayload
    }

    var state = MRJSONPayloadScanState()
    var index = startIndex
    while index < output.endIndex {
        let character = output[index]
        if let endIndex = mrExecutableJSONPayloadEndIndex(
            afterReading: character,
            at: index,
            in: output,
            state: &state
        ) {
            return Data(output[startIndex..<endIndex].utf8)
        }
        index = output.index(after: index)
    }

    throw MRCLIExecutableProbeError.missingJSONPayload
}

struct MRJSONPayloadScanState {
    var depth = 0
    var inString = false
    var escaped = false
}

func mrExecutableJSONPayloadEndIndex(
    afterReading character: Character,
    at index: String.Index,
    in output: String,
    state: inout MRJSONPayloadScanState
) -> String.Index? {
    if state.inString {
        updateMRExecutableJSONPayloadStringState(afterReading: character, state: &state)
        return nil
    }

    switch character {
    case "\"":
        state.inString = true
    case "{":
        state.depth += 1
    case "}":
        state.depth -= 1
        if state.depth == 0 {
            return output.index(after: index)
        }
    default:
        break
    }
    return nil
}

func updateMRExecutableJSONPayloadStringState(
    afterReading character: Character,
    state: inout MRJSONPayloadScanState
) {
    if state.escaped {
        state.escaped = false
    } else if character == "\\" {
        state.escaped = true
    } else if character == "\"" {
        state.inString = false
    }
}

enum MRCLIExecutableProbeError: Error, Equatable {
    case missingVerdictLine
    case invalidVerdictLine(String)
    case missingJSONPayload
}
