import Foundation

public struct ExternalConnectorNmpPreflightConfiguration: Equatable, Sendable {
    public var planPath: String
    public var outputPath: String

    public init(planPath: String, outputPath: String) {
        self.planPath = planPath
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> ExternalConnectorNmpPreflightConfiguration {
        let allowed = ["--plan", "--output"]
        var values: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw ExternalConnectorSessionError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw ExternalConnectorSessionError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw ExternalConnectorSessionError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }
        return ExternalConnectorNmpPreflightConfiguration(
            planPath: try requiredExternalConnectorValue("--plan", values),
            outputPath: try requiredExternalConnectorValue("--output", values)
        )
    }
}

public struct ExternalConnectorNmpPreflightResult: Codable, Equatable, Sendable {
    public var connector: ExternalConnectorKind
    public var preflightCommand: [String]?
    public var report: ExternalConnectorExecutablePreflightReport?
    public var skippedReason: String?
}

public struct ExternalConnectorNmpPreflightReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var planID: String
    public var planPath: String
    public var results: [ExternalConnectorNmpPreflightResult]
    public var verdict: MeasurementVerdict
    public var notes: String

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorSessionNonEmpty(planID, "planID")
        try requireExternalConnectorSessionNonEmpty(planPath, "planPath")
        try requireExternalConnectorSessionNonEmpty(notes, "notes")
        guard !results.isEmpty, Set(results.map(\.connector)).count == results.count else {
            throw ExternalConnectorSessionError.emptyField("results")
        }
        for result in results {
            if let command = result.preflightCommand {
                try requireExternalConnectorSessionNonEmptyList(command, "results.preflightCommand")
                guard command.first == "external-connector-executable-preflight-run" else {
                    throw ExternalConnectorSessionError.emptyField("results.preflightCommand")
                }
                _ = try ExternalConnectorExecutablePreflightConfiguration.parse(Array(command.dropFirst()))
                guard let report = result.report else {
                    throw ExternalConnectorSessionError.emptyField("results.report")
                }
                try report.validate()
            } else {
                try requireExternalConnectorSessionNonEmpty(result.skippedReason ?? "", "results.skippedReason")
            }
        }
        if verdict == .pass, results.contains(where: { $0.report?.verdict == .fail }) {
            throw ExternalConnectorExecutablePreflightError.passWithFailingProbe("nmp-preflight")
        }
        if verdict == .fail, !results.contains(where: { $0.report?.verdict == .fail }) {
            throw ExternalConnectorExecutablePreflightError.failWithoutFailingProbe
        }
    }
}

public enum ExternalConnectorNmpPreflightRunner {
    public static func run(
        configuration: ExternalConnectorNmpPreflightConfiguration,
        plan: ExternalConnectorNmpPlanReport
    ) throws -> ExternalConnectorNmpPreflightReport {
        try plan.validate()
        let results = try plan.plans.map(preflightResult)
        return ExternalConnectorNmpPreflightReport(
            id: "external-connector-nmp-preflight",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            planID: plan.id,
            planPath: configuration.planPath,
            results: results,
            verdict: aggregateNmpPreflightVerdict(results),
            notes: "Runs every connector-scoped executable preflight embedded in an NMP A/V plan. This is host readiness evidence only, not endpoint interoperability proof."
        )
    }
}

private func preflightResult(
    _ plan: ExternalConnectorConnectionPlanReport
) throws -> ExternalConnectorNmpPreflightResult {
    guard let command = plan.preflightCommand else {
        return ExternalConnectorNmpPreflightResult(
            connector: plan.connector,
            preflightCommand: nil,
            report: nil,
            skippedReason: "\(plan.connector.rawValue) uses the internal open-lola connector path; no external executable preflight is required."
        )
    }
    let configuration = try ExternalConnectorExecutablePreflightConfiguration.parse(Array(command.dropFirst()))
    return ExternalConnectorNmpPreflightResult(
        connector: plan.connector,
        preflightCommand: command,
        report: ExternalConnectorExecutablePreflightRunner.run(configuration: configuration),
        skippedReason: nil
    )
}

private func aggregateNmpPreflightVerdict(
    _ results: [ExternalConnectorNmpPreflightResult]
) -> MeasurementVerdict {
    if results.contains(where: { $0.report?.verdict == .fail }) {
        return .fail
    }
    if results.contains(where: { $0.report?.verdict == .partial }) {
        return .partial
    }
    return .pass
}
