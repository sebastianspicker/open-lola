// Loads NMP plan artifacts and resolves the endpoint configuration selected for execution.
import Foundation

func validateNmpEndpointPreflight(
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

func nmpEndpointRunNotes(
    side: ExternalConnectorConnectionSide,
    preflight: ExternalConnectorNmpPreflightReport?
) -> String {
    let preflightText = preflight == nil
        ? " No preflight report was supplied, so endpoint commands use the executable paths embedded in the plan."
        : [
            " Supplied preflight evidence is used to propagate discovered UltraGrid",
            "and JackTrip executable paths into endpoint commands."
        ].joined(separator: " ")
    let sideText = side == .both
        ? "both local and remote side"
        : "the \(side.rawValue) side"
    return [
        "Runs \(sideText) endpoints embedded in an NMP A/V plan.\(preflightText)",
        "This aggregates process/session attempts; PASS remains blocked until",
        "measured bidirectional media evidence exists."
    ].joined(separator: " ")
}

func selectedNmpEndpoints(
    plan: ExternalConnectorNmpPlanReport,
    side: ExternalConnectorConnectionSide
) -> [ExternalConnectorConnectionEndpoint] {
    let endpoints = plan.plans.flatMap(\.endpoints)
    guard side != .both else {
        return endpoints
    }
    return endpoints.filter { $0.side == side }
}

func runEndpoint(
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

func runEndpointsConcurrently(
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

func orderedNmpEndpointConnectors(
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

func runConnectorEndpointsConcurrently(
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

func runConnectorEndpoint(
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

struct ExternalConnectorNmpExecutableOverrides: Sendable {
    var ultraGridExecutable: String?
    var jackTripExecutable: String?
}

func nmpEndpointCommand(
    _ command: [String],
    dryRunOverride: Bool?,
    connector: ExternalConnectorKind,
    executableOverrides: ExternalConnectorNmpExecutableOverrides?
) -> [String] {
    var updated = command
    if let dryRunOverride {
        setNmpEndpointDryRun(dryRunOverride, in: &updated)
    }
    setNmpEndpointExecutableOverrides(
        connector: connector,
        executableOverrides: executableOverrides,
        command: &updated
    )
    return updated
}

func setNmpEndpointDryRun(_ dryRunOverride: Bool, in command: inout [String]) {
    setNmpEndpointOption("--dry-run", value: dryRunOverride ? "true" : "false", in: &command)
}

func setNmpEndpointExecutableOverrides(
    connector: ExternalConnectorKind,
    executableOverrides: ExternalConnectorNmpExecutableOverrides?,
    command: inout [String]
) {
    switch connector {
    case .mvtpUltraGrid:
        setNmpEndpointUltraGridExecutable(executableOverrides?.ultraGridExecutable, in: &command)
    case .jackTrip:
        setNmpEndpointJackTripExecutableOverrides(executableOverrides, in: &command)
    case .lola:
        break
    }
}

func setNmpEndpointUltraGridExecutable(_ executable: String?, in command: inout [String]) {
    if let executable {
        setNmpEndpointOption("--executable", value: executable, in: &command)
    }
}

func setNmpEndpointJackTripExecutableOverrides(
    _ executableOverrides: ExternalConnectorNmpExecutableOverrides?,
    in command: inout [String]
) {
    if let jackTripExecutable = executableOverrides?.jackTripExecutable {
        setNmpEndpointOption("--executable", value: jackTripExecutable, in: &command)
    }
    if let ultraGridExecutable = executableOverrides?.ultraGridExecutable {
        setNmpEndpointOption("--video-executable", value: ultraGridExecutable, in: &command)
    }
}

func setNmpEndpointOption(_ option: String, value: String, in command: inout [String]) {
    if let index = command.firstIndex(of: option), index + 1 < command.count {
        command[index + 1] = value
    } else {
        command += [option, value]
    }
}

func nmpExecutableOverrides(
    for connector: ExternalConnectorKind,
    preflight: ExternalConnectorNmpPreflightReport?
) -> ExternalConnectorNmpExecutableOverrides? {
    guard let result = preflight?.results.first(where: { $0.connector == connector }),
          let report = result.report else {
        return nil
    }
    let ultraGridExecutable = nmpExecutableOverride(.ultraGrid, in: report)
    let jackTripExecutable = nmpExecutableOverride(.jackTrip, in: report)
    guard ultraGridExecutable != nil || jackTripExecutable != nil else {
        return nil
    }
    return ExternalConnectorNmpExecutableOverrides(
        ultraGridExecutable: ultraGridExecutable,
        jackTripExecutable: jackTripExecutable
    )
}

func nmpExecutableOverride(
    _ identity: ExternalConnectorExecutableIdentity,
    in report: ExternalConnectorExecutablePreflightReport
) -> String? {
    report.probes.first {
        $0.detectedIdentity == identity && $0.verdict == .pass
    }?.executable
}

func aggregateNmpEndpointRunVerdict(
    _ results: [ExternalConnectorNmpEndpointRunResult]
) -> MeasurementVerdict {
    if results.contains(where: { $0.report.verdict == .fail }) {
        return .fail
    }
    return .partial
}
