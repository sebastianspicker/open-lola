// Parses e2e-benchmark-run arguments with the optional direct-peer session report paths and loads those reports.
import Foundation

/// The `e2e-benchmark-run` configuration plus the optional `--source-session` and `--receiver-session` paths.
/// Configuration fields are readable directly on the request.
@dynamicMemberLookup
public struct E2EBenchmarkRunRequest: Equatable, Sendable {
    public var configuration: E2EBenchmarkRunConfiguration
    public var sessionPaths: E2EBenchmarkSessionPaths

    /// Creates a request from a parsed configuration and session paths.
    public init(configuration: E2EBenchmarkRunConfiguration, sessionPaths: E2EBenchmarkSessionPaths) {
        self.configuration = configuration
        self.sessionPaths = sessionPaths
    }

    /// Reads a field of the wrapped run configuration.
    public subscript<Value>(dynamicMember keyPath: KeyPath<E2EBenchmarkRunConfiguration, Value>) -> Value {
        configuration[keyPath: keyPath]
    }

    /// Splits off the session options, then parses the remaining arguments as a run configuration.
    public static func parse(_ arguments: [String]) throws -> E2EBenchmarkRunRequest {
        let sessionPaths = try E2EBenchmarkSessionPaths.extract(from: arguments)
        return E2EBenchmarkRunRequest(
            configuration: try E2EBenchmarkRunConfiguration.parse(sessionPaths.remainingArguments),
            sessionPaths: sessionPaths
        )
    }

    /// Reads, decodes, and validates the named session reports; absent paths stay nil.
    public func loadSessions() throws -> E2EBenchmarkSessionInputs {
        E2EBenchmarkSessionInputs(
            source: try Self.sessionReport(atPath: sessionPaths.source),
            receiver: try Self.sessionReport(atPath: sessionPaths.receiver)
        )
    }

    private static func sessionReport(atPath path: String?) throws -> DirectPeerSessionReport? {
        guard let path else {
            return nil
        }
        let report = try DirectPeerSessionReport.decode(from: try BoundedFileReader.data(atPath: path))
        try report.validate()
        return report
    }
}

public extension E2EBenchmarkRunner {
    /// Runs the aggregate with the session reports named in `request`.
    static func run(
        configuration request: E2EBenchmarkRunRequest,
        audioBenchmark: LatencyBenchmarkReport,
        integratedAv: IntegratedAvReport,
        videoTransport: VideoTransportReport,
        performanceAudit: PerformanceAuditReport
    ) throws -> E2EBenchmarkReport {
        try run(
            configuration: request.configuration,
            audioBenchmark: audioBenchmark,
            integratedAv: integratedAv,
            videoTransport: videoTransport,
            performanceAudit: performanceAudit,
            sessions: try request.loadSessions()
        )
    }
}

/// Splits the optional `--source-session` and `--receiver-session` paths off the `e2e-benchmark-run` arguments,
/// leaving the rest for `E2EBenchmarkRunConfiguration.parse`.
public struct E2EBenchmarkSessionPaths: Equatable, Sendable {
    public var source: String?
    public var receiver: String?
    public var remainingArguments: [String]

    /// Removes the session options and their values from `arguments`.
    public static func extract(from arguments: [String]) throws -> E2EBenchmarkSessionPaths {
        var paths = E2EBenchmarkSessionPaths(source: nil, receiver: nil, remainingArguments: [])
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            guard argument == "--source-session" || argument == "--receiver-session" else {
                paths.remainingArguments.append(argument)
                index += 1
                continue
            }
            guard index + 1 < arguments.count, !arguments[index + 1].isEmpty,
                  !arguments[index + 1].hasPrefix("--") else {
                throw E2EBenchmarkRunConfigurationError.missingValue(argument)
            }
            try paths.store(arguments[index + 1], for: argument)
            index += 2
        }
        return paths
    }

    private mutating func store(_ path: String, for argument: String) throws {
        let existing = argument == "--source-session" ? source : receiver
        guard existing == nil else {
            throw E2EBenchmarkRunConfigurationError.duplicateArgument(argument)
        }
        if argument == "--source-session" {
            source = path
        } else {
            receiver = path
        }
    }
}
