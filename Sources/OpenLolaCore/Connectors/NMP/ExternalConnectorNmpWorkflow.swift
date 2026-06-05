import Foundation

public struct ExternalConnectorNmpWorkflowConfiguration: Equatable, Sendable {
    public var outputPath: String
    public var planPath: String
    public var preflightPath: String
    public var endpointRunPath: String
    public var side: ExternalConnectorConnectionSide
    public var dryRunOverride: Bool?
    public var planConfiguration: ExternalConnectorNmpPlanConfiguration

    public static func parse(_ arguments: [String]) throws -> ExternalConnectorNmpWorkflowConfiguration {
        let values = try parseExternalConnectorKeyValueArguments(arguments, allowed: nmpWorkflowArguments)
        let outputPath = try requiredExternalConnectorValue("--output", values)
        let runDirectory = values["--run-dir"] ?? nmpWorkflowDefaultRunDirectory(forOutputPath: outputPath)
        let normalizedRunDirectory = nmpWorkflowNormalizedRunDirectory(runDirectory)
        let side = try nmpWorkflowSide(values)
        let planPath = "\(normalizedRunDirectory)/nmp-plan.json"
        let preflightPath = "\(normalizedRunDirectory)/nmp-preflight.json"
        let endpointRunPath = "\(normalizedRunDirectory)/nmp-\(side.rawValue)-endpoint-run.json"
        return try ExternalConnectorNmpWorkflowConfiguration(
            outputPath: outputPath,
            planPath: planPath,
            preflightPath: preflightPath,
            endpointRunPath: endpointRunPath,
            side: side,
            dryRunOverride: optionalExternalConnectorBoolean("--dry-run", values),
            planConfiguration: ExternalConnectorNmpPlanConfiguration.parse(nmpWorkflowPlanArguments(
                values,
                planPath: planPath,
                runDirectory: runDirectory
            ))
        )
    }
}

private let nmpWorkflowArguments = Set([
    "--local-host", "--remote-host", "--output", "--run-dir", "--connectors",
    "--ultragrid-executable", "--jacktrip-executable", "--jacktrip-video-executable",
    "--media", "--control-transport", "--duration-seconds", "--channels",
    "--sample-rate", "--frames", "--video-width", "--video-height", "--video-fps",
    "--video-bpp", "--audio-capture", "--audio-playback", "--video-capture",
    "--video-display", "--session-id", "--local-raw-link-interface",
    "--remote-raw-link-interface", "--local-mac", "--remote-mac",
    "--media-packets", "--side", "--dry-run"
])

private func nmpWorkflowSide(_ values: [String: String]) throws -> ExternalConnectorConnectionSide {
    let sideText = try requiredExternalConnectorValue("--side", values)
    guard let side = ExternalConnectorConnectionSide(rawValue: sideText) else {
        throw ExternalConnectorSessionError.invalidConnectionSide(sideText)
    }
    return side
}

public struct ExternalConnectorNmpWorkflowReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var planPath: String
    public var preflightPath: String
    public var endpointRunPath: String
    public var side: ExternalConnectorConnectionSide
    public var plan: ExternalConnectorNmpPlanReport
    public var preflight: ExternalConnectorNmpPreflightReport
    public var endpointRun: ExternalConnectorNmpEndpointRunReport
    public var verdict: MeasurementVerdict
    public var notes: String

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorSessionNonEmpty(planPath, "planPath")
        try requireExternalConnectorSessionNonEmpty(preflightPath, "preflightPath")
        try requireExternalConnectorSessionNonEmpty(endpointRunPath, "endpointRunPath")
        try requireExternalConnectorSessionNonEmpty(notes, "notes")
        try plan.validate()
        try preflight.validate()
        try endpointRun.validate()
        guard preflight.planID == plan.id, endpointRun.planID == plan.id else {
            throw ExternalConnectorSessionError.emptyField("planID")
        }
        guard preflight.planPath == planPath, endpointRun.planPath == planPath else {
            throw ExternalConnectorSessionError.emptyField("planPath")
        }
        guard endpointRun.side == side else {
            throw ExternalConnectorSessionError.emptyField("side")
        }
        guard verdict != .pass else {
            throw ExternalConnectorValidationError.realWorldPassNotAllowed
        }
        if verdict == .fail, preflight.verdict != .fail, endpointRun.verdict != .fail {
            throw ExternalConnectorExecutablePreflightError.failWithoutFailingProbe
        }
    }
}

public enum ExternalConnectorNmpWorkflowRunner {
    public static func run(
        configuration: ExternalConnectorNmpWorkflowConfiguration
    ) throws -> ExternalConnectorNmpWorkflowReport {
        let plan = try ExternalConnectorNmpPlanRunner.run(configuration: configuration.planConfiguration)
        let preflight = try ExternalConnectorNmpPreflightRunner.run(
            configuration: ExternalConnectorNmpPreflightConfiguration(
                planPath: configuration.planPath,
                outputPath: configuration.preflightPath
            ),
            plan: plan
        )
        let endpointRun = try ExternalConnectorNmpEndpointRunRunner.run(
            configuration: ExternalConnectorNmpEndpointRunConfiguration(
                planPath: configuration.planPath,
                outputPath: configuration.endpointRunPath,
                side: configuration.side,
                dryRunOverride: configuration.dryRunOverride
            ),
            plan: plan,
            preflight: preflight
        )
        return ExternalConnectorNmpWorkflowReport(
            id: "external-connector-nmp-\(configuration.side.rawValue)-workflow",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            planPath: configuration.planPath,
            preflightPath: configuration.preflightPath,
            endpointRunPath: configuration.endpointRunPath,
            side: configuration.side,
            plan: plan,
            preflight: preflight,
            endpointRun: endpointRun,
            verdict: aggregateNmpWorkflowVerdict(preflight: preflight, endpointRun: endpointRun),
            notes: nmpWorkflowNotes()
        )
    }
}

private func nmpWorkflowPlanArguments(
    _ values: [String: String],
    planPath: String,
    runDirectory: String
) -> [String] {
    var arguments = [
        "--local-host", values["--local-host"] ?? "",
        "--remote-host", values["--remote-host"] ?? "",
        "--output", planPath,
        "--run-dir", runDirectory
    ]
    let optionalKeys = [
        "--connectors", "--ultragrid-executable", "--jacktrip-executable",
        "--jacktrip-video-executable", "--media", "--control-transport",
        "--duration-seconds", "--channels", "--sample-rate", "--frames",
        "--video-width", "--video-height", "--video-fps", "--video-bpp",
        "--audio-capture", "--audio-playback", "--video-capture",
        "--video-display", "--session-id", "--local-raw-link-interface",
        "--remote-raw-link-interface", "--local-mac", "--remote-mac",
        "--media-packets"
    ]
    for key in optionalKeys {
        if let value = values[key] {
            arguments += [key, value]
        }
    }
    return arguments
}

private func nmpWorkflowNotes() -> String {
    [
        "Single-command NMP A/V workflow: builds the LoLa, MVTP/UltraGrid, and JackTrip plan,",
        "runs host executable preflight, then runs the selected endpoint side or both sides",
        "with any preflight-discovered external executable paths.",
        "PASS remains blocked until real peers, executable identities,",
        "and measured bidirectional media evidence exist."
    ].joined(separator: " ")
}

private func aggregateNmpWorkflowVerdict(
    preflight: ExternalConnectorNmpPreflightReport,
    endpointRun: ExternalConnectorNmpEndpointRunReport
) -> MeasurementVerdict {
    if preflight.verdict == .fail || endpointRun.verdict == .fail {
        return .fail
    }
    return .partial
}

private func nmpWorkflowDefaultRunDirectory(forOutputPath outputPath: String) -> String {
    guard let slash = outputPath.lastIndex(of: "/") else {
        return "."
    }
    if slash == outputPath.startIndex {
        return "/"
    }
    return String(outputPath[..<slash])
}

private func nmpWorkflowNormalizedRunDirectory(_ runDirectory: String) -> String {
    guard runDirectory.count > 1, runDirectory.hasSuffix("/") else {
        return runDirectory
    }
    return String(runDirectory.dropLast())
}
