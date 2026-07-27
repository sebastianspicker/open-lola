// Declares control-plane configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
/// Configures OscCueExternalRunConfiguration so callers supply explicit inputs before starting read-only control integration.
public struct OscCueLoopbackConfiguration: Codable, Equatable, Sendable {
    public let port: UInt16
    public let count: Int
    public init(port: UInt16, count: Int) { self.port = port; self.count = count }
}

/// Describes the first external OSC peer and its availability for a cue run.
public struct OscCueExternalPeerConfiguration: Codable, Equatable, Sendable {
    public let kind: OscCuePeerKind
    public let host: String
    public let port: UInt16
    public let available: Bool
    public let unavailableReason: String?
    public init(kind: OscCuePeerKind, host: String, port: UInt16, available: Bool, unavailableReason: String?) { self.kind = kind; self.host = host; self.port = port; self.available = available; self.unavailableReason = unavailableReason }
}

/// Combines audio baseline, loopback, external peer, and output inputs for an OSC cue run.
public struct OscCueExternalRunConfiguration: Codable, Equatable, Sendable {
    public let audioBaselineReportId: String
    public let port: UInt16
    public let count: Int
    public let firstExternalPeerKind: OscCuePeerKind
    public let externalHost: String
    public let externalPort: UInt16
    public let externalAvailable: Bool
    public let externalUnavailableReason: String?
    public let outputPath: String

    public init(audioBaselineReportId: String, loopback: OscCueLoopbackConfiguration, externalPeer: OscCueExternalPeerConfiguration, outputPath: String) {
        self.audioBaselineReportId = audioBaselineReportId
        self.port = loopback.port
        self.count = loopback.count
        self.firstExternalPeerKind = externalPeer.kind
        self.externalHost = externalPeer.host
        self.externalPort = externalPeer.port
        self.externalAvailable = externalPeer.available
        self.externalUnavailableReason = externalPeer.unavailableReason
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> OscCueExternalRunConfiguration {
        let allowed = [
            "--audio-baseline",
            "--port",
            "--count",
            "--first-external-peer",
            "--external-host",
            "--external-port",
            "--external-available",
            "--external-unavailable-reason",
            "--output"
        ]
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard allowed.contains(argument) else {
                throw OscCueExternalRunConfigurationError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw OscCueExternalRunConfigurationError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("--") else {
                throw OscCueExternalRunConfigurationError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }

        let externalAvailable = try requiredOscExternalRunBoolean("--external-available", values)
        let unavailableReason = values["--external-unavailable-reason"]
        if !externalAvailable && (unavailableReason?.isEmpty ?? true) {
            throw OscCueExternalRunConfigurationError.missingRequiredArgument("--external-unavailable-reason")
        }

        return OscCueExternalRunConfiguration(
            audioBaselineReportId: try requiredOscExternalRunString("--audio-baseline", values),
            loopback: OscCueLoopbackConfiguration(port: try requiredOscExternalRunPort("--port", values, allowZero: true), count: try requiredOscExternalRunPositiveInteger("--count", values)),
            externalPeer: OscCueExternalPeerConfiguration(kind: try requiredOscExternalRunPeerKind("--first-external-peer", values), host: try requiredOscExternalRunString("--external-host", values), port: try requiredOscExternalRunPort("--external-port", values, allowZero: false), available: externalAvailable, unavailableReason: unavailableReason),
            outputPath: try requiredOscExternalRunString("--output", values)
        )
    }
}

/// Enumerates failures that callers must handle when working with read-only control integration.
public enum OscCueExternalRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
    case invalidPort(String)
    case invalidBoolean(argument: String, value: String)
    case invalidExternalPeerKind(String)
}
