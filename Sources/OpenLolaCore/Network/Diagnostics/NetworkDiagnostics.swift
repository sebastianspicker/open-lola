// Defines ping and traceroute results, pass thresholds, and run configuration so diagnostic observations stay distinct from media-route certification.
import Dispatch
import Foundation

/// Represents the NetworkPingResult produced by network diagnostics without exposing its execution state.
public struct NetworkPingResult: Codable, Equatable, Sendable {
    public var transmitted: Int
    public var received: Int
    public var packetLossPercent: Double
    public var minRttMilliseconds: Double
    public var averageRttMilliseconds: Double
    public var maxRttMilliseconds: Double
    public var standardDeviationMilliseconds: Double

    public init(
        transmitted: Int,
        received: Int,
        packetLossPercent: Double,
        minRttMilliseconds: Double,
        averageRttMilliseconds: Double,
        maxRttMilliseconds: Double,
        standardDeviationMilliseconds: Double
    ) {
        self.transmitted = transmitted
        self.received = received
        self.packetLossPercent = packetLossPercent
        self.minRttMilliseconds = minRttMilliseconds
        self.averageRttMilliseconds = averageRttMilliseconds
        self.maxRttMilliseconds = maxRttMilliseconds
        self.standardDeviationMilliseconds = standardDeviationMilliseconds
    }
}

/// Represents NetworkTracerouteHop values used by network diagnostics.
public struct NetworkTracerouteHop: Codable, Equatable, Sendable {
    public var index: Int
    public var address: String
    public var timingsMilliseconds: [Double]

    public init(index: Int, address: String, timingsMilliseconds: [Double]) {
        self.index = index
        self.address = address
        self.timingsMilliseconds = timingsMilliseconds
    }
}

/// Represents the NetworkTracerouteResult produced by network diagnostics without exposing its execution state.
public struct NetworkTracerouteResult: Codable, Equatable, Sendable {
    public var hops: [NetworkTracerouteHop]
    public var blocked: Bool
    public var blockedReason: String?

    public init(
        hops: [NetworkTracerouteHop],
        blocked: Bool,
        blockedReason: String?
    ) {
        self.hops = hops
        self.blocked = blocked
        self.blockedReason = blockedReason
    }
}

/// Enumerates failures that callers must handle when working with network diagnostics.
public enum NetworkDiagnosticsValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case passWithoutPing
    case passWithPingLoss
    case passExceedsThreshold(field: String, actual: Double, maximum: Double)
    case passWithBlockedTraceroute
    case blockedTracerouteMissingReason
}

/// Centralizes the round-trip-time and jitter ceilings required for a passing diagnostic report.
public enum NetworkDiagnosticsPassThresholds {
    public static let maximumAverageRttMilliseconds = 2.0
    public static let maximumRttMilliseconds = 5.0
    public static let maximumStandardDeviationMilliseconds = 1.0
}

/// Captures NetworkDiagnosticsReport evidence in a stable form for validation and serialized reporting.
public struct NetworkDiagnosticsReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var id: String
        public var capturedAt: String
        public var peer: String

        public init(id: String, capturedAt: String, peer: String) {
            self.id = id
            self.capturedAt = capturedAt
            self.peer = peer
        }
    }

    public struct PingEvidence: Equatable, Sendable {
        public var result: NetworkPingResult?
        public var error: String?

        public init(result: NetworkPingResult?, error: String? = nil) {
            self.result = result
            self.error = error
        }
    }

    public struct TracerouteEvidence: Equatable, Sendable {
        public var result: NetworkTracerouteResult
        public var error: String?

        public init(result: NetworkTracerouteResult, error: String? = nil) {
            self.result = result
            self.error = error
        }
    }

    public var id: String
    public var capturedAt: String
    public var peer: String
    public var ping: NetworkPingResult?
    public var pingError: String?
    public var traceroute: NetworkTracerouteResult
    public var tracerouteError: String?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        identity: Identity,
        ping: PingEvidence,
        traceroute: TracerouteEvidence,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        id = identity.id
        capturedAt = identity.capturedAt
        peer = identity.peer
        self.ping = ping.result
        pingError = ping.error
        self.traceroute = traceroute.result
        tracerouteError = traceroute.error
        self.verdict = verdict
        self.notes = notes
    }

}

/// Configures NetworkDiagnosticsRunConfiguration so callers supply explicit inputs before starting network diagnostics.
public struct NetworkDiagnosticsRunConfiguration: Codable, Equatable, Sendable {
    public let peer: String
    public let pingCount: Int
    public let maxHops: Int
    public let outputPath: String

    public init(peer: String, pingCount: Int, maxHops: Int, outputPath: String) {
        self.peer = peer
        self.pingCount = pingCount
        self.maxHops = maxHops
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> NetworkDiagnosticsRunConfiguration {
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: ["--peer", "--ping-count", "--max-hops", "--output"],
            allowsDashPrefixedValues: false,
            unknown: NetworkDiagnosticsRunConfigurationError.unknownArgument,
            duplicate: NetworkDiagnosticsRunConfigurationError.duplicateArgument,
            missingValue: NetworkDiagnosticsRunConfigurationError.missingValue
        )
        return NetworkDiagnosticsRunConfiguration(
            peer: try KeyValueArgumentParser.requiredString(
                "--peer",
                values,
                missing: NetworkDiagnosticsRunConfigurationError.missingRequiredArgument
            ),
            pingCount: try KeyValueArgumentParser.requiredPositiveInteger(
                "--ping-count",
                values,
                missing: NetworkDiagnosticsRunConfigurationError.missingRequiredArgument,
                invalid: NetworkDiagnosticsRunConfigurationError.invalidInteger,
                nonPositive: NetworkDiagnosticsRunConfigurationError.nonPositiveArgument
            ),
            maxHops: try KeyValueArgumentParser.requiredPositiveInteger(
                "--max-hops",
                values,
                missing: NetworkDiagnosticsRunConfigurationError.missingRequiredArgument,
                invalid: NetworkDiagnosticsRunConfigurationError.invalidInteger,
                nonPositive: NetworkDiagnosticsRunConfigurationError.nonPositiveArgument
            ),
            outputPath: try KeyValueArgumentParser.requiredString(
                "--output",
                values,
                missing: NetworkDiagnosticsRunConfigurationError.missingRequiredArgument
            )
        )
    }
}

/// Enumerates failures that callers must handle when working with network diagnostics.
public enum NetworkDiagnosticsRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
}

/// Provides deterministic NetworkDiagnosticsSyntheticSmoke coverage without requiring external network diagnostics infrastructure.
public enum NetworkDiagnosticsSyntheticSmoke {
    public static func run() -> NetworkDiagnosticsReport {
        NetworkDiagnosticsReport(
            identity: NetworkDiagnosticsReport.Identity(
                id: "network-diagnostics-synthetic",
                capturedAt: "2026-05-03T00:00:00Z",
                peer: "127.0.0.1"
            ),
            ping: NetworkDiagnosticsReport.PingEvidence(result: NetworkPingResult(
                transmitted: 2,
                received: 2,
                packetLossPercent: 0,
                minRttMilliseconds: 0.05,
                averageRttMilliseconds: 0.08,
                maxRttMilliseconds: 0.10,
                standardDeviationMilliseconds: 0.01
            )),
            traceroute: NetworkDiagnosticsReport.TracerouteEvidence(result: NetworkTracerouteResult(
                hops: [
                    NetworkTracerouteHop(
                        index: 1,
                        address: "127.0.0.1",
                        timingsMilliseconds: [0.1, 0.1, 0.1]
                    )
                ],
                blocked: false,
                blockedReason: nil
            )),
            verdict: .partial,
            notes: "Synthetic diagnostics fixture."
        )
    }
}
