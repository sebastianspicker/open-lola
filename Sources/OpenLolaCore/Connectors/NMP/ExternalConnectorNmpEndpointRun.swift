import Foundation

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

public struct ExternalConnectorNmpEndpointRunResult: Codable, Equatable, Sendable {
    public var connector: ExternalConnectorKind
    public var endpointID: String
    public var side: ExternalConnectorConnectionSide
    public var direction: ExternalConnectorConnectionDirection
    public var role: ExternalConnectorSessionRole
    public var command: [String]
    public var report: ExternalConnectorSessionReport
}

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
        try requireExternalConnectorSessionNonEmpty(id, "id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorSessionNonEmpty(planID, "planID")
        try requireExternalConnectorSessionNonEmpty(planPath, "planPath")
        try requireExternalConnectorSessionNonEmpty(notes, "notes")
        guard !results.isEmpty, Set(results.map(\.endpointID)).count == results.count else {
            throw ExternalConnectorSessionError.emptyField("results")
        }
        for result in results {
            try requireExternalConnectorSessionNonEmpty(result.endpointID, "results.endpointID")
            try requireExternalConnectorSessionNonEmptyList(result.command, "results.command")
            guard side == .both ? result.side != .both : result.side == side else {
                throw ExternalConnectorSessionError.emptyField("results.side")
            }
            guard result.command.first == "external-connector-session-run" else {
                throw ExternalConnectorSessionError.emptyField("results.command")
            }
            let parsed = try ExternalConnectorSessionConfiguration.parse(Array(result.command.dropFirst()))
            guard parsed.connector == result.connector, parsed.role == result.role else {
                throw ExternalConnectorSessionError.emptyField("results.command")
            }
            try result.report.validate()
            guard result.report.connector == result.connector, result.report.role == result.role else {
                throw ExternalConnectorSessionError.emptyField("results.report")
            }
        }
        if side == .both, Set(results.map(\.side)) != [.local, .remote] {
            throw ExternalConnectorSessionError.emptyField("results.side")
        }
        guard verdict != .pass else {
            throw ExternalConnectorValidationError.realWorldPassNotAllowed
        }
        if verdict == .fail, !results.contains(where: { $0.report.verdict == .fail }) {
            throw ExternalConnectorExecutablePreflightError.failWithoutFailingProbe
        }
    }
}

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

private func validateNmpEndpointPreflight(
    configuration: ExternalConnectorNmpEndpointRunConfiguration,
    plan: ExternalConnectorNmpPlanReport,
    preflight: ExternalConnectorNmpPreflightReport?
) throws {
    guard let preflight else {
        return
    }
    guard preflight.planID == plan.id else {
        throw ExternalConnectorSessionError.emptyField("preflight.planID")
    }
    guard preflight.planPath == configuration.planPath else {
        throw ExternalConnectorSessionError.emptyField("preflight.planPath")
    }
}

private func nmpEndpointRunNotes(
    side: ExternalConnectorConnectionSide,
    preflight: ExternalConnectorNmpPreflightReport?
) -> String {
    let preflightText = preflight == nil
        ? " No preflight report was supplied, so endpoint commands use the executable paths embedded in the plan."
        : " Supplied preflight evidence is used to propagate discovered UltraGrid and JackTrip executable paths into endpoint commands."
    let sideText = side == .both
        ? "both local and remote side"
        : "the \(side.rawValue) side"
    return "Runs \(sideText) endpoints embedded in an NMP A/V plan.\(preflightText) This aggregates process/session attempts; PASS remains blocked until measured bidirectional media evidence exists."
}

private func selectedNmpEndpoints(
    plan: ExternalConnectorNmpPlanReport,
    side: ExternalConnectorConnectionSide
) -> [ExternalConnectorConnectionEndpoint] {
    let endpoints = plan.plans.flatMap(\.endpoints)
    guard side != .both else {
        return endpoints
    }
    return endpoints.filter { $0.side == side }
}

private func runEndpoint(
    _ endpoint: ExternalConnectorConnectionEndpoint,
    dryRunOverride: Bool?,
    executableOverrides: ExternalConnectorNmpExecutableOverrides?
) throws -> ExternalConnectorNmpEndpointRunResult {
    let command = nmpEndpointCommand(
        endpoint.command,
        dryRunOverride: dryRunOverride,
        connector: endpoint.plan.connector,
        executableOverrides: executableOverrides
    )
    let session = try ExternalConnectorSessionConfiguration.parse(Array(command.dropFirst()))
    let report = try ExternalConnectorSessionRunner.run(configuration: session)
    return ExternalConnectorNmpEndpointRunResult(
        connector: endpoint.plan.connector,
        endpointID: endpoint.id,
        side: endpoint.side,
        direction: endpoint.direction,
        role: endpoint.role,
        command: command,
        report: report
    )
}

private func runEndpointsConcurrently(
    _ endpoints: [ExternalConnectorConnectionEndpoint],
    dryRunOverride: Bool?,
    preflight: ExternalConnectorNmpPreflightReport?
) throws -> [ExternalConnectorNmpEndpointRunResult] {
    var results: [ExternalConnectorNmpEndpointRunResult] = []
    for connector in orderedNmpEndpointConnectors(endpoints) {
        let connectorEndpoints = endpoints.enumerated().filter { $0.element.plan.connector == connector }
        results += try runConnectorEndpointsConcurrently(
            connectorEndpoints,
            dryRunOverride: dryRunOverride,
            preflight: preflight
        )
    }
    return results
}

private func orderedNmpEndpointConnectors(
    _ endpoints: [ExternalConnectorConnectionEndpoint]
) -> [ExternalConnectorKind] {
    var seen: Set<ExternalConnectorKind> = []
    return endpoints.compactMap { endpoint in
        let connector = endpoint.plan.connector
        guard !seen.contains(connector) else {
            return nil
        }
        seen.insert(connector)
        return connector
    }
}

private func runConnectorEndpointsConcurrently(
    _ endpoints: [(offset: Int, element: ExternalConnectorConnectionEndpoint)],
    dryRunOverride: Bool?,
    preflight: ExternalConnectorNmpPreflightReport?
) throws -> [ExternalConnectorNmpEndpointRunResult] {
    if endpoints.count <= 1 || dryRunOverride == true {
        return try endpoints.map { endpoint in
            try runConnectorEndpoint(
                endpoint,
                dryRunOverride: dryRunOverride,
                preflight: preflight
            )
        }
    }

    let group = DispatchGroup()
    let queue = DispatchQueue(label: "open-lola.nmp.endpoint-run", attributes: .concurrent)
    let store = NmpEndpointRunResultStore()
    for endpoint in endpoints {
        group.enter()
        let originalIndex = endpoint.offset
        let connectionEndpoint = endpoint.element
        let executableOverrides = nmpExecutableOverrides(for: connectionEndpoint.plan.connector, preflight: preflight)
        queue.async {
            defer { group.leave() }
            do {
                store.record(.success(try runEndpoint(
                    connectionEndpoint,
                    dryRunOverride: dryRunOverride,
                    executableOverrides: executableOverrides
                )), at: originalIndex)
            } catch {
                store.record(.failure(error), at: originalIndex)
            }
        }
    }
    group.wait()
    return try store.orderedResults(indexes: endpoints.map(\.offset))
}

private func runConnectorEndpoint(
    _ endpoint: (offset: Int, element: ExternalConnectorConnectionEndpoint),
    dryRunOverride: Bool?,
    preflight: ExternalConnectorNmpPreflightReport?
) throws -> ExternalConnectorNmpEndpointRunResult {
    try runEndpoint(
        endpoint.element,
        dryRunOverride: dryRunOverride,
        executableOverrides: nmpExecutableOverrides(for: endpoint.element.plan.connector, preflight: preflight)
    )
}

private final class NmpEndpointRunResultStore: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Int: Result<ExternalConnectorNmpEndpointRunResult, Error>] = [:]

    func record(_ result: Result<ExternalConnectorNmpEndpointRunResult, Error>, at index: Int) {
        lock.lock()
        defer { lock.unlock() }
        results[index] = result
    }

    func orderedResults(indexes: [Int]) throws -> [ExternalConnectorNmpEndpointRunResult] {
        try indexes.map { index in
            lock.lock()
            defer { lock.unlock() }
            let result = results[index]
            switch result {
            case let .success(value):
                return value
            case let .failure(error):
                throw error
            case nil:
                throw ExternalConnectorSessionError.emptyField("results")
            }
        }
    }
}

private struct ExternalConnectorNmpExecutableOverrides: Sendable {
    var ultraGridExecutable: String?
    var jackTripExecutable: String?
}

private func nmpEndpointCommand(
    _ command: [String],
    dryRunOverride: Bool?,
    connector: ExternalConnectorKind,
    executableOverrides: ExternalConnectorNmpExecutableOverrides?
) -> [String] {
    var updated = command
    if let dryRunOverride {
        setNmpEndpointOption(
            "--dry-run",
            value: dryRunOverride ? "true" : "false",
            in: &updated
        )
    }
    switch connector {
    case .mvtpUltraGrid:
        if let ultraGridExecutable = executableOverrides?.ultraGridExecutable {
            setNmpEndpointOption("--executable", value: ultraGridExecutable, in: &updated)
        }
    case .jackTrip:
        if let jackTripExecutable = executableOverrides?.jackTripExecutable {
            setNmpEndpointOption("--executable", value: jackTripExecutable, in: &updated)
        }
        if let ultraGridExecutable = executableOverrides?.ultraGridExecutable {
            setNmpEndpointOption("--video-executable", value: ultraGridExecutable, in: &updated)
        }
    case .lola:
        break
    }
    return updated
}

private func setNmpEndpointOption(_ option: String, value: String, in command: inout [String]) {
    if let index = command.firstIndex(of: option), index + 1 < command.count {
        command[index + 1] = value
    } else {
        command += [option, value]
    }
}

private func nmpExecutableOverrides(
    for connector: ExternalConnectorKind,
    preflight: ExternalConnectorNmpPreflightReport?
) -> ExternalConnectorNmpExecutableOverrides? {
    guard let result = preflight?.results.first(where: { $0.connector == connector }),
          let report = result.report else {
        return nil
    }
    let ultraGridExecutable = report.probes.first {
        $0.detectedIdentity == .ultraGrid && $0.verdict == .pass
    }?.executable
    let jackTripExecutable = report.probes.first {
        $0.detectedIdentity == .jackTrip && $0.verdict == .pass
    }?.executable
    guard ultraGridExecutable != nil || jackTripExecutable != nil else {
        return nil
    }
    return ExternalConnectorNmpExecutableOverrides(
        ultraGridExecutable: ultraGridExecutable,
        jackTripExecutable: jackTripExecutable
    )
}

private func aggregateNmpEndpointRunVerdict(
    _ results: [ExternalConnectorNmpEndpointRunResult]
) -> MeasurementVerdict {
    if results.contains(where: { $0.report.verdict == .fail }) {
        return .fail
    }
    return .partial
}
