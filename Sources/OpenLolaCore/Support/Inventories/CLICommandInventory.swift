// Models CLI command ownership and builds summary counts so every exposed command maps to a parser, source file, and test surface.
import Foundation

/// Defines the finite classification values recorded by CLI command inventory artifacts for deterministic validation and report interpretation.
public enum CLICommandKind: String, Codable, Sendable {
    case validator
    case run
    case syntheticSmoke
    case localhostSmoke
    case inventory
    case probe
}

/// Captures inventory entry required to validate, interpret, and reproduce a CLI command inventory result.
public struct CLICommandInventoryEntry: Codable, Equatable, Sendable {
    public let command: String
    public let kind: CLICommandKind
    public let ownerSourceFile: String
    public let parser: String
    public let validationPath: String
    public let relatedTestFiles: [String]

    public init(
        command: String,
        kind: CLICommandKind,
        ownerSourceFile: String,
        parser: String,
        validationPath: String,
        relatedTestFiles: [String]
    ) {
        self.command = command
        self.kind = kind
        self.ownerSourceFile = ownerSourceFile
        self.parser = parser
        self.validationPath = validationPath
        self.relatedTestFiles = relatedTestFiles
    }
}

/// Captures summary statistics required to validate, interpret, and reproduce a CLI command inventory result.
public struct CLICommandInventorySummary: Codable, Equatable, Sendable {
    public let commandCount: Int
    public let validatorCount: Int
    public let runCount: Int
    public let syntheticSmokeCount: Int
    public let localhostSmokeCount: Int
}

/// Captures report contents required to validate, interpret, and reproduce a CLI command inventory result.
public struct CLICommandInventoryReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: CLICommandInventorySummary
    public let commands: [CLICommandInventoryEntry]
    public let notes: String

}

/// Builds the CLI command inventory from source-backed entries so ownership and operational boundaries remain reviewable.
public enum CLICommandInventory {
    public static func report() -> CLICommandInventoryReport {
        CLICommandInventoryReport(
            id: "c01-cli-command-inventory",
            title: "C01 CLI command router and argument parsing inventory",
            verdict: .partial,
            summary: summary(),
            commands: entries,
            notes: "Executable source-level command ownership inventory. Command behavior remains unchanged."
        )
    }

    public static func summary() -> CLICommandInventorySummary {
        CLICommandInventorySummary(
            commandCount: entries.count,
            validatorCount: count(.validator),
            runCount: count(.run),
            syntheticSmokeCount: count(.syntheticSmoke),
            localhostSmokeCount: count(.localhostSmoke)
        )
    }

    public static let entries: [CLICommandInventoryEntry] = [
        main(
            "session-capabilities",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/SessionProtocolTests.swift"]
        ),
        main(
            "fixture-smoke-matrix",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift"]
        ),
        main(
            "command-inventory",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift"]
        ),
        main(
            "report-schema-inventory",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift"]
        ),
        main(
            "goal-codewise-closure",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/GoalCodewiseClosureTests.swift"]
        ),
        main(
            "goal-codewise-closure-run",
            .run,
            tests: ["Tests/OpenLolaCoreTests/GoalCodewiseClosureTests.swift"]
        ),
        main(
            "goal-runtime-evidence-template",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift"]
        ),
        main(
            "goal-runtime-evidence-template-run",
            .run,
            tests: ["Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift"]
        ),
        main(
            "goal-runtime-preflight",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/GoalRuntimePreflightTests.swift"]
        ),
        main(
            "goal-runtime-preflight-run",
            .run,
            tests: ["Tests/OpenLolaCoreTests/GoalRuntimePreflightTests.swift"]
        ),
        main(
            "goal-completion-audit",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/GoalCompletionAuditTests.swift"]
        ),
        main(
            "goal-completion-audit-run",
            .run,
            tests: ["Tests/OpenLolaCoreTests/GoalCompletionAuditTests.swift"]
        ),
        main(
            "current-evidence-status-matrix",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/CurrentEvidenceStatusMatrixTests.swift"]
        ),
        main(
            "current-evidence-status-matrix-run",
            .run,
            tests: ["Tests/OpenLolaCoreTests/CurrentEvidenceStatusMatrixTests.swift"]
        ),
        main(
            "realtime-audio-path-inventory",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift"]
        ),
        main(
            "network-route-command-matrix",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift"]
        ),
        main(
            "video-control-degrade-matrix",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/VideoControlDegradeMatrixTests.swift"]
        ),
        main(
            "source-ownership-inventory",
            .inventory,
            tests: ["Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift"]
        ),
        main(
            "udp-pcm-send-once",
            .probe,
            tests: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"]
        ),
        main(
            "udp-pcm-receive-once",
            .probe,
            tests: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"]
        )
    ]
    + networkCommands
    + milestoneValidationCommands
    + milestoneRuntimeCommands
    + [
        command(
            "validate-madi-rx-report",
            .validator,
            "Sources/open-lola/Commands/Audio/MadiReceiveCommands.swift",
            ["Tests/OpenLolaCoreTests/MadiReceiveTests.swift"]
        ),
        command(
            "madi-rx-synthetic-smoke",
            .syntheticSmoke,
            "Sources/open-lola/Commands/Audio/MadiReceiveCommands.swift",
            ["Tests/OpenLolaCoreTests/MadiReceiveTests.swift"]
        ),
        command(
            "validate-madi-full-duplex-report",
            .validator,
            "Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift",
            ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"]
        ),
        command(
            "madi-full-duplex-synthetic-smoke",
            .syntheticSmoke,
            "Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift",
            ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"]
        ),
        command(
            "madi-full-duplex-run",
            .run,
            "Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift",
            ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"]
        ),
        command(
            "latency-profile-benchmark-synthetic-smoke",
            .syntheticSmoke,
            "Sources/open-lola/Commands/Audio/LatencyProfileCommands.swift",
            ["Tests/OpenLolaCoreTests/LatencyProfileTests.swift"]
        ),
        command(
            "rx-buffer-benchmark-run",
            .run,
            "Sources/open-lola/Commands/Audio/LatencyProfileCommands.swift",
            ["Tests/OpenLolaCoreTests/RxBufferingTests.swift"]
        ),
        command(
            "validate-performance-audit-report",
            .validator,
            "Sources/open-lola/Commands/Benchmarks/PerformanceCommands.swift",
            ["Tests/OpenLolaCoreTests/PerformanceAuditTests.swift"]
        ),
        command(
            "performance-audit-synthetic-smoke",
            .syntheticSmoke,
            "Sources/open-lola/Commands/Benchmarks/PerformanceCommands.swift",
            ["Tests/OpenLolaCoreTests/PerformanceAuditTests.swift"]
        ),
        command(
            "validate-e2e-benchmark-report",
            .validator,
            "Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift",
            ["Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift"]
        ),
        command(
            "e2e-benchmark-synthetic-smoke",
            .syntheticSmoke,
            "Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift",
            ["Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift"]
        ),
        command(
            "e2e-benchmark-run",
            .run,
            "Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift",
            ["Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift"]
        )
    ]

    private static func count(_ kind: CLICommandKind) -> Int {
        entries.filter { $0.kind == kind }.count
    }
}

private func main(
    _ commandName: String,
    _ kind: CLICommandKind,
    tests: [String]
) -> CLICommandInventoryEntry {
    command(
        commandName,
        kind,
        "Sources/open-lola/main.swift",
        tests
    )
}

func command(
    _ commandName: String,
    _ kind: CLICommandKind,
    _ owner: String,
    _ tests: [String]
) -> CLICommandInventoryEntry {
    CLICommandInventoryEntry(
        command: commandName,
        kind: kind,
        ownerSourceFile: owner,
        parser: parserDescription(for: kind),
        validationPath: validationDescription(for: kind),
        relatedTestFiles: tests
    )
}

private func parserDescription(for kind: CLICommandKind) -> String {
    switch kind {
    case .validator:
        return "fixed-arity path argument"
    case .run:
        return "typed run configuration parser or explicit requiredArgument checks"
    case .syntheticSmoke, .localhostSmoke, .inventory:
        return "fixed command or optional --output variant"
    case .probe:
        return "small explicit argument parser"
    }
}

private func validationDescription(for kind: CLICommandKind) -> String {
    switch kind {
    case .validator:
        return "decode input artifact, validate report contract, print verdict"
    case .run:
        return "parse configuration, run source-level runner, validate output report, print verdict"
    case .syntheticSmoke:
        return "generate synthetic source-level report, validate it, print PARTIAL verdict"
    case .localhostSmoke:
        return "run local deterministic probe, validate output, print verdict"
    case .inventory:
        return "build local inventory JSON and print verdict"
    case .probe:
        return "execute explicit one-shot probe and print verdict"
    }
}
