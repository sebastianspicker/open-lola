// Executes one endpoint from an NMP plan and records its connector command and result.
import Foundation

// swiftlint:disable:next type_name
/// Defines the validated fields for external connector NMP endpoint run configuration.
public struct ExternalConnectorNmpEndpointRunConfiguration: Equatable, Sendable {
    public var planPath: String
    public var outputPath: String
    public var side: ExternalConnectorConnectionSide
    public var dryRunOverride: Bool?
    public var preflightPath: String?

    public init(
        planPath: String,
        outputPath: String,
        side: ExternalConnectorConnectionSide,
        dryRunOverride: Bool? = nil,
        preflightPath: String? = nil
    ) {
        self.planPath = planPath
        self.outputPath = outputPath
        self.side = side
        self.dryRunOverride = dryRunOverride
        self.preflightPath = preflightPath
    }

    public static func parse(_ arguments: [String]) throws -> ExternalConnectorNmpEndpointRunConfiguration {
        let values = try parseExternalConnectorKeyValueArguments(
            arguments,
            allowed: ["--plan", "--output", "--side", "--dry-run", "--preflight"]
        )
        let sideText = try requiredExternalConnectorValue("--side", values)
        guard let side = ExternalConnectorConnectionSide(rawValue: sideText) else {
            throw ExternalConnectorSessionError.invalidConnectionSide(sideText)
        }
        return ExternalConnectorNmpEndpointRunConfiguration(
            planPath: try requiredExternalConnectorValue("--plan", values),
            outputPath: try requiredExternalConnectorValue("--output", values),
            side: side,
            dryRunOverride: try optionalExternalConnectorBoolean("--dry-run", values),
            preflightPath: values["--preflight"]
        )
    }
}

/// Defines the validated fields for external connector NMP endpoint run result.
public struct ExternalConnectorNmpEndpointRunResult: Codable, Equatable, Sendable {
    public var connector: ExternalConnectorKind
    public var endpointID: String
    public var side: ExternalConnectorConnectionSide
    public var direction: ExternalConnectorConnectionDirection
    public var role: ExternalConnectorSessionRole
    public var command: [String]
    public var report: ExternalConnectorSessionReport
}

/// Records the evidence and outcome for external connector NMP endpoint run report.
public struct ExternalConnectorNmpEndpointRunReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var planID: String
    public var planPath: String
    public var side: ExternalConnectorConnectionSide
    public var results: [ExternalConnectorNmpEndpointRunResult]
    public var verdict: MeasurementVerdict
    public var notes: String

    public func validate() throws {
        try validateNmpEndpointRunReportHeader(self)
        try validateNmpEndpointRunResults(self)
        try validateNmpEndpointRunVerdict(self)
    }
}

private func validateNmpEndpointRunReportHeader(_ report: ExternalConnectorNmpEndpointRunReport) throws {
    try requireExternalConnectorSessionNonEmpty(report.id, "id")
    try requireExternalConnectorSessionNonEmpty(report.capturedAt, "capturedAt")
    try requireExternalConnectorSessionNonEmpty(report.planID, "planID")
    try requireExternalConnectorSessionNonEmpty(report.planPath, "planPath")
    try requireExternalConnectorSessionNonEmpty(report.notes, "notes")
}

private func validateNmpEndpointRunResults(_ report: ExternalConnectorNmpEndpointRunReport) throws {
    try validateNmpEndpointRunResultSet(report)
    for result in report.results {
        try validateNmpEndpointRunResult(result, reportSide: report.side)
    }
    if report.side == .both, Set(report.results.map(\.side)) != [.local, .remote] {
        throw ExternalConnectorSessionError.emptyField("results.side")
    }
}

private func validateNmpEndpointRunResultSet(_ report: ExternalConnectorNmpEndpointRunReport) throws {
    guard !report.results.isEmpty,
          Set(report.results.map(\.endpointID)).count == report.results.count else {
        throw ExternalConnectorSessionError.emptyField("results")
    }
}

private func validateNmpEndpointRunResult(
    _ result: ExternalConnectorNmpEndpointRunResult,
    reportSide: ExternalConnectorConnectionSide
) throws {
    try requireExternalConnectorSessionNonEmpty(result.endpointID, "results.endpointID")
    try requireExternalConnectorSessionNonEmptyList(result.command, "results.command")
    try validateNmpEndpointRunResultSide(result.side, reportSide: reportSide)
    try validateNmpEndpointRunResultCommand(result)
    try validateNmpEndpointRunResultReport(result)
}

private func validateNmpEndpointRunResultSide(
    _ side: ExternalConnectorConnectionSide,
    reportSide: ExternalConnectorConnectionSide
) throws {
    guard reportSide == .both ? side != .both : side == reportSide else {
        throw ExternalConnectorSessionError.emptyField("results.side")
    }
}

private func validateNmpEndpointRunResultCommand(_ result: ExternalConnectorNmpEndpointRunResult) throws {
    guard result.command.first == "external-connector-session-run" else {
        throw ExternalConnectorSessionError.emptyField("results.command")
    }
    let parsed = try ExternalConnectorSessionConfiguration.parse(Array(result.command.dropFirst()))
    guard parsed.connector == result.connector, parsed.role == result.role else {
        throw ExternalConnectorSessionError.emptyField("results.command")
    }
}

private func validateNmpEndpointRunResultReport(_ result: ExternalConnectorNmpEndpointRunResult) throws {
    try result.report.validate()
    guard result.report.connector == result.connector, result.report.role == result.role else {
        throw ExternalConnectorSessionError.emptyField("results.report")
    }
}

private func validateNmpEndpointRunVerdict(_ report: ExternalConnectorNmpEndpointRunReport) throws {
    guard report.verdict != .pass else {
        throw ExternalConnectorValidationError.realWorldPassNotAllowed
    }
    if report.verdict == .fail, !report.results.contains(where: { $0.report.verdict == .fail }) {
        throw ExternalConnectorExecutablePreflightError.failWithoutFailingProbe
    }
}

/// Executes one endpoint from an NMP plan and records its connector-specific result.
public enum ExternalConnectorNmpEndpointRunRunner {
    public static func run(
        configuration: ExternalConnectorNmpEndpointRunConfiguration,
        plan: ExternalConnectorNmpPlanReport
    ) throws -> ExternalConnectorNmpEndpointRunReport {
        guard configuration.preflightPath == nil else {
            throw ExternalConnectorSessionError.emptyField("--preflight")
        }
        return try run(configuration: configuration, plan: plan, preflight: nil)
    }

    public static func run(
        configuration: ExternalConnectorNmpEndpointRunConfiguration,
        plan: ExternalConnectorNmpPlanReport,
        preflight: ExternalConnectorNmpPreflightReport?
    ) throws -> ExternalConnectorNmpEndpointRunReport {
        try plan.validate()
        try preflight?.validate()
        try validateNmpEndpointPreflight(configuration: configuration, plan: plan, preflight: preflight)
        let endpoints = selectedNmpEndpoints(plan: plan, side: configuration.side)
        guard !endpoints.isEmpty else {
            throw ExternalConnectorSessionError.emptyField("endpoints")
        }
        let results = try runEndpointsConcurrently(
            endpoints,
            dryRunOverride: configuration.dryRunOverride,
            preflight: preflight
        )
        return ExternalConnectorNmpEndpointRunReport(
            id: "external-connector-nmp-\(configuration.side.rawValue)-endpoint-run",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            planID: plan.id,
            planPath: configuration.planPath,
            side: configuration.side,
            results: results,
            verdict: aggregateNmpEndpointRunVerdict(results),
            notes: nmpEndpointRunNotes(side: configuration.side, preflight: preflight)
        )
    }
}
