// Handles AtemReadOnlyControl control exchange, keeping control-plane details distinct from media data flow.
import Foundation
#if canImport(Darwin)
import Darwin
#endif

let atemProbeMaximumTimeoutMilliseconds = 30_000

/// Classifies read-only ATEM reachability and probe health.
public enum AtemReadOnlyHealth: String, Codable, Equatable, Sendable {
    case connected
    case unavailable
    case timeout
    case error
}

/// Enumerates failures that callers must handle when working with read-only control integration.
public enum AtemReadOnlyControlValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case commandsArmed
    case passWithoutConnectedHealth(AtemReadOnlyHealth)
    case passWithoutNetworkEvidence
    case passWithPlaceholderField(String)
}

/// Keeps ATEM capture identity distinct from other control-report identities.
public enum AtemReadOnlyControlIdentityDomain {}
/// Names the report identity type used by read-only ATEM control evidence.
public typealias AtemReadOnlyControlIdentity = ReportCaptureIdentity<AtemReadOnlyControlIdentityDomain>

/// Captures the observed ATEM device details for a read-only control report.
public struct AtemReadOnlyControlDeviceEvidence: Equatable, Sendable {
    public var ipAddress: String
    public var model: String
    public var firmware: String
    public var controlPort: UInt16?
    public var protocolName: String?
    public var networkInterface: String?
    public var sameNetworkAsAudio: Bool?
    public init(ipAddress: String, model: String, firmware: String, controlPort: UInt16? = nil, protocolName: String? = nil, networkInterface: String? = nil, sameNetworkAsAudio: Bool? = nil) { self.ipAddress = ipAddress; self.model = model; self.firmware = firmware; self.controlPort = controlPort; self.protocolName = protocolName; self.networkInterface = networkInterface; self.sameNetworkAsAudio = sameNetworkAsAudio }
}

/// Captures the program, preview, tally, and audio mixer state reported by ATEM.
public struct AtemReadOnlyControlSwitchState: Equatable, Sendable {
    public var programSource: String
    public var previewSource: String
    public var tally: String
    public var audioMixerState: String
    public init(programSource: String, previewSource: String, tally: String, audioMixerState: String) { self.programSource = programSource; self.previewSource = previewSource; self.tally = tally; self.audioMixerState = audioMixerState }
}

/// Records reachability, command safety, timing, and errors from an ATEM probe.
public struct AtemReadOnlyControlProbeEvidence: Equatable, Sendable {
    public var health: AtemReadOnlyHealth
    public var armedCommandsAllowed: Bool
    public var pollIntervalMilliseconds: Int?
    public var connectionAttemptMilliseconds: Double?
    public var errorMessage: String?
    public init(health: AtemReadOnlyHealth, armedCommandsAllowed: Bool, pollIntervalMilliseconds: Int? = nil, connectionAttemptMilliseconds: Double? = nil, errorMessage: String? = nil) { self.health = health; self.armedCommandsAllowed = armedCommandsAllowed; self.pollIntervalMilliseconds = pollIntervalMilliseconds; self.connectionAttemptMilliseconds = connectionAttemptMilliseconds; self.errorMessage = errorMessage }
}

/// Serializes read-only ATEM device, switch-state, and probe evidence with a verdict.
public struct AtemReadOnlyControlReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var ipAddress: String
    public var model: String
    public var firmware: String
    public var programSource: String
    public var previewSource: String
    public var tally: String
    public var audioMixerState: String
    public var health: AtemReadOnlyHealth
    public var armedCommandsAllowed: Bool
    public var controlPort: UInt16?
    public var protocolName: String?
    public var networkInterface: String?
    public var sameNetworkAsAudio: Bool?
    public var readOnlyPollIntervalMilliseconds: Int?
    public var connectionAttemptMilliseconds: Double?
    public var errorMessage: String?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(identity: AtemReadOnlyControlIdentity, device: AtemReadOnlyControlDeviceEvidence, switchState: AtemReadOnlyControlSwitchState, probe: AtemReadOnlyControlProbeEvidence, verdict: MeasurementVerdict, notes: String) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.ipAddress = device.ipAddress
        self.model = device.model
        self.firmware = device.firmware
        self.programSource = switchState.programSource
        self.previewSource = switchState.previewSource
        self.tally = switchState.tally
        self.audioMixerState = switchState.audioMixerState
        self.health = probe.health
        self.armedCommandsAllowed = probe.armedCommandsAllowed
        self.controlPort = device.controlPort
        self.protocolName = device.protocolName
        self.networkInterface = device.networkInterface
        self.sameNetworkAsAudio = device.sameNetworkAsAudio
        self.readOnlyPollIntervalMilliseconds = probe.pollIntervalMilliseconds
        self.connectionAttemptMilliseconds = probe.connectionAttemptMilliseconds
        self.errorMessage = probe.errorMessage
        self.verdict = verdict
        self.notes = notes
    }
}

/// Configures AtemReadOnlyProbeConfiguration so callers supply explicit inputs before starting read-only control integration.
public struct AtemReadOnlyProbeConfiguration: Codable, Equatable, Sendable {
    public var host: String
    public var port: UInt16
    public var timeoutMilliseconds: Int
    public var pollIntervalMilliseconds: Int
    public var networkInterface: String?
    public var sameNetworkAsAudio: Bool?
    public var outputPath: String

    public init(
        host: String,
        port: UInt16 = 9_910,
        timeoutMilliseconds: Int = 250,
        pollIntervalMilliseconds: Int = 1_000,
        networkInterface: String? = nil,
        sameNetworkAsAudio: Bool? = nil,
        outputPath: String
    ) {
        self.host = host
        self.port = port
        self.timeoutMilliseconds = timeoutMilliseconds
        self.pollIntervalMilliseconds = pollIntervalMilliseconds
        self.networkInterface = networkInterface
        self.sameNetworkAsAudio = sameNetworkAsAudio
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> AtemReadOnlyProbeConfiguration {
        let knownArguments = Set([
            "--host",
            "--port",
            "--timeout-milliseconds",
            "--poll-interval-milliseconds",
            "--network-interface",
            "--same-network-as-audio",
            "--output"
        ])
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: knownArguments,
            unknown: AtemReadOnlyProbeConfigurationError.unknownArgument,
            duplicate: AtemReadOnlyProbeConfigurationError.duplicateArgument,
            missingValue: AtemReadOnlyProbeConfigurationError.missingValue
        )

        return AtemReadOnlyProbeConfiguration(
            host: try requiredAtemProbeIPv4Address("--host", values),
            port: try optionalAtemProbePort("--port", values, defaultValue: 9_910),
            timeoutMilliseconds: try optionalAtemProbePositiveInteger(
                "--timeout-milliseconds",
                values,
                defaultValue: 250,
                maximumValue: atemProbeMaximumTimeoutMilliseconds
            ),
            pollIntervalMilliseconds: try optionalAtemProbePositiveInteger(
                "--poll-interval-milliseconds",
                values,
                defaultValue: 1_000
            ),
            networkInterface: values["--network-interface"],
            sameNetworkAsAudio: try optionalAtemProbeBool("--same-network-as-audio", values),
            outputPath: try requiredAtemProbeString("--output", values)
        )
    }
}

/// Enumerates failures that callers must handle when working with read-only control integration.
public enum AtemReadOnlyProbeConfigurationError: Error, Equatable, Sendable {
    case unknownArgument(String)
    case duplicateArgument(String)
    case missingValue(String)
    case missingRequiredArgument(String)
    case invalidInteger(argument: String, value: String)
    case invalidBoolean(argument: String, value: String)
    case nonPositiveArgument(String)
    case argumentExceedsMaximum(argument: String, value: Int, maximum: Int)
    case invalidPort(String)
    case invalidIPv4Host(String)
}

/// Represents AtemReadOnlyNetworkObservation values used by read-only control integration.
public struct AtemReadOnlyNetworkObservation: Equatable, Sendable {
    public var health: AtemReadOnlyHealth
    public var durationMilliseconds: Double
    public var errorMessage: String?

    public init(health: AtemReadOnlyHealth, durationMilliseconds: Double, errorMessage: String?) {
        self.health = health
        self.durationMilliseconds = durationMilliseconds
        self.errorMessage = errorMessage
    }
}

func requireAtemNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(
        value,
        field: field,
        empty: AtemReadOnlyControlValidationError.emptyField
    )
}

func requireAtemPositive(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requirePositive(
        value,
        field: field,
        nonPositive: AtemReadOnlyControlValidationError.nonPositiveField
    )
}

func requireAtemNonNegative(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(
        value,
        field: field,
        negative: AtemReadOnlyControlValidationError.negativeField
    )
}

func isAtemPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: [PlaceholderDetection.manualEvidenceToken, "placeholder", "synthetic"],
        exactly: ["unknown", "none", "tbd", "not-tested", "notrun", "not-run"]
    )
}

private func requiredAtemProbeString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    try KeyValueArgumentParser.requiredString(
        argument,
        values,
        missing: AtemReadOnlyProbeConfigurationError.missingRequiredArgument
    )
}

private func requiredAtemProbeIPv4Address(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    let value = try requiredAtemProbeString(argument, values)
#if canImport(Darwin)
    var address = in_addr()
    guard value.withCString({ inet_pton(AF_INET, $0, &address) }) == 1 else {
        throw AtemReadOnlyProbeConfigurationError.invalidIPv4Host(value)
    }
#endif
    return value
}

private func optionalAtemProbePositiveInteger(
    _ argument: String,
    _ values: [String: String],
    defaultValue: Int,
    maximumValue: Int? = nil
) throws -> Int {
    let parsed = try KeyValueArgumentParser.optionalPositiveInteger(
        argument,
        values,
        invalid: AtemReadOnlyProbeConfigurationError.invalidInteger,
        nonPositive: AtemReadOnlyProbeConfigurationError.nonPositiveArgument
    ) ?? defaultValue
    if let maximumValue, parsed > maximumValue {
        throw AtemReadOnlyProbeConfigurationError.argumentExceedsMaximum(
            argument: argument,
            value: parsed,
            maximum: maximumValue
        )
    }
    return parsed
}

private func optionalAtemProbePort(
    _ argument: String,
    _ values: [String: String],
    defaultValue: UInt16
) throws -> UInt16 {
    guard let value = values[argument] else {
        return defaultValue
    }
    guard let parsed = UInt16(value), parsed > 0 else {
        throw AtemReadOnlyProbeConfigurationError.invalidPort(value)
    }
    return parsed
}

private func optionalAtemProbeBool(
    _ argument: String,
    _ values: [String: String]
) throws -> Bool? {
    guard let value = values[argument] else {
        return nil
    }
    return try KeyValueArgumentParser.boolean(
        value,
        argument: argument,
        invalid: AtemReadOnlyProbeConfigurationError.invalidBoolean
    )
}
