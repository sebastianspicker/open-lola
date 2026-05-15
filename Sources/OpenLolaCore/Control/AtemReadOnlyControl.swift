import Foundation
#if canImport(Darwin)
import Darwin
#endif

private let atemProbeMaximumTimeoutMilliseconds = 30_000

public enum AtemReadOnlyHealth: String, Codable, Equatable, Sendable {
    case connected
    case unavailable
    case timeout
    case error
}

public enum AtemReadOnlyControlValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case commandsArmed
    case passWithoutConnectedHealth(AtemReadOnlyHealth)
    case passWithoutNetworkEvidence
    case passWithPlaceholderField(String)
}

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

    public init(
        id: String,
        title: String,
        capturedAt: String,
        ipAddress: String,
        model: String,
        firmware: String,
        programSource: String,
        previewSource: String,
        tally: String,
        audioMixerState: String,
        health: AtemReadOnlyHealth,
        armedCommandsAllowed: Bool,
        controlPort: UInt16? = nil,
        protocolName: String? = nil,
        networkInterface: String? = nil,
        sameNetworkAsAudio: Bool? = nil,
        readOnlyPollIntervalMilliseconds: Int? = nil,
        connectionAttemptMilliseconds: Double? = nil,
        errorMessage: String? = nil,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.ipAddress = ipAddress
        self.model = model
        self.firmware = firmware
        self.programSource = programSource
        self.previewSource = previewSource
        self.tally = tally
        self.audioMixerState = audioMixerState
        self.health = health
        self.armedCommandsAllowed = armedCommandsAllowed
        self.controlPort = controlPort
        self.protocolName = protocolName
        self.networkInterface = networkInterface
        self.sameNetworkAsAudio = sameNetworkAsAudio
        self.readOnlyPollIntervalMilliseconds = readOnlyPollIntervalMilliseconds
        self.connectionAttemptMilliseconds = connectionAttemptMilliseconds
        self.errorMessage = errorMessage
        self.verdict = verdict
        self.notes = notes
    }
}

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
            "--output",
        ])
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            guard knownArguments.contains(argument) else {
                throw AtemReadOnlyProbeConfigurationError.unknownArgument(argument)
            }
            guard values[argument] == nil else {
                throw AtemReadOnlyProbeConfigurationError.duplicateArgument(argument)
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count else {
                throw AtemReadOnlyProbeConfigurationError.missingValue(argument)
            }
            values[argument] = arguments[valueIndex]
            index += 2
        }

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

public enum AtemReadOnlyControlProbe {
    public static func run(configuration: AtemReadOnlyProbeConfiguration) -> AtemReadOnlyControlReport {
        makeReport(
            configuration: configuration,
            observation: tcpReachabilityObservation(configuration: configuration),
            capturedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    public static func makeUnavailableReport(host: String, capturedAt: String? = nil) -> AtemReadOnlyControlReport {
        let configuration = AtemReadOnlyProbeConfiguration(
            host: host,
            outputPath: ""
        )
        return makeReport(
            configuration: configuration,
            observation: AtemReadOnlyNetworkObservation(
                health: .unavailable,
                durationMilliseconds: 0,
                errorMessage: "No live ATEM network probe was run."
            ),
            capturedAt: capturedAt ?? ISO8601DateFormatter().string(from: Date())
        )
    }

    public static func makeReport(
        configuration: AtemReadOnlyProbeConfiguration,
        observation: AtemReadOnlyNetworkObservation,
        capturedAt: String
    ) -> AtemReadOnlyControlReport {
        AtemReadOnlyControlReport(
            id: "m11-atem-readonly-probe",
            title: "M11 ATEM read-only control probe",
            capturedAt: capturedAt,
            ipAddress: configuration.host,
            model: "unknown",
            firmware: "unknown",
            programSource: "unknown",
            previewSource: "unknown",
            tally: "unknown",
            audioMixerState: "unknown",
            health: observation.health,
            armedCommandsAllowed: false,
            controlPort: configuration.port,
            protocolName: "tcp-reachability",
            networkInterface: configuration.networkInterface,
            sameNetworkAsAudio: configuration.sameNetworkAsAudio,
            readOnlyPollIntervalMilliseconds: configuration.pollIntervalMilliseconds,
            connectionAttemptMilliseconds: observation.durationMilliseconds,
            errorMessage: observation.errorMessage,
            verdict: .partial,
            notes: "Read-only ATEM reachability probe; .connected means TCP handshake completed, not ATEM protocol verified. No switching commands are implemented or armed, and model/firmware require a real read-only ATEM adapter or captured hardware evidence."
        )
    }

    private static func tcpReachabilityObservation(
        configuration: AtemReadOnlyProbeConfiguration
    ) -> AtemReadOnlyNetworkObservation {
        #if canImport(Darwin)
        let start = Date()
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            let socketErrno = errno
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "socket creation failed: \(socketErrno)"
            )
        }
        defer {
            close(socketDescriptor)
        }

        let flags = fcntl(socketDescriptor, F_GETFL, 0)
        guard flags >= 0, fcntl(socketDescriptor, F_SETFL, flags | O_NONBLOCK) >= 0 else {
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "failed to configure nonblocking socket: \(errno)"
            )
        }

        guard let address = sockaddrIn(host: configuration.host, port: configuration.port) else {
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "invalid IPv4 host"
            )
        }

        var targetAddress = address
        let connectResult = withAtemSockaddrPointer(to: &targetAddress) { socketAddress, socketAddressLength in
            connect(socketDescriptor, socketAddress, socketAddressLength)
        }

        if connectResult == 0 {
            return AtemReadOnlyNetworkObservation(
                health: .connected,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: nil
            )
        }

        guard errno == EINPROGRESS else {
            return AtemReadOnlyNetworkObservation(
                health: .unavailable,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "connect failed: \(errno)"
            )
        }

        var writeSet = fd_set()
        openLolaFDZero(&writeSet)
        guard atemSocketDescriptorFitsFDSet(socketDescriptor) else {
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "socket descriptor exceeds fd_set capacity"
            )
        }
        guard (try? openLolaFDSet(socketDescriptor, set: &writeSet)) != nil else {
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "socket descriptor exceeds fd_set capacity"
            )
        }
        let boundedTimeoutMilliseconds = min(
            max(1, configuration.timeoutMilliseconds),
            atemProbeMaximumTimeoutMilliseconds
        )
        var timeout = timeval(
            tv_sec: boundedTimeoutMilliseconds / 1_000,
            tv_usec: Int32((boundedTimeoutMilliseconds % 1_000) * 1_000)
        )
        let ready = select(socketDescriptor + 1, nil, &writeSet, nil, &timeout)
        if ready == 0 {
            return AtemReadOnlyNetworkObservation(
                health: .timeout,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "connect timed out"
            )
        }
        guard ready > 0 else {
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "select failed: \(errno)"
            )
        }

        var socketError: Int32 = 0
        var socketErrorLength = socklen_t(MemoryLayout<Int32>.size)
        let optionResult = getsockopt(
            socketDescriptor,
            SOL_SOCKET,
            SO_ERROR,
            &socketError,
            &socketErrorLength
        )
        guard optionResult == 0 else {
            return AtemReadOnlyNetworkObservation(
                health: .error,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "getsockopt failed: \(errno)"
            )
        }
        guard socketError == 0 else {
            return AtemReadOnlyNetworkObservation(
                health: .unavailable,
                durationMilliseconds: elapsedMilliseconds(since: start),
                errorMessage: "connect failed: \(socketError)"
            )
        }

        return AtemReadOnlyNetworkObservation(
            health: .connected,
            durationMilliseconds: elapsedMilliseconds(since: start),
            errorMessage: nil
        )
        #else
        return AtemReadOnlyNetworkObservation(
            health: .unavailable,
            durationMilliseconds: 0,
            errorMessage: "TCP reachability probe is unavailable on this platform."
        )
        #endif
    }
}

func requireAtemNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, empty: AtemReadOnlyControlValidationError.emptyField)
}

func requireAtemPositive(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, nonPositive: AtemReadOnlyControlValidationError.nonPositiveField)
}

func requireAtemNonNegative(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, negative: AtemReadOnlyControlValidationError.negativeField)
}

func isAtemPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: ["todo(human)", "placeholder", "synthetic"],
        exactly: ["unknown", "none", "tbd", "not-tested", "notrun", "not-run"]
    )
}

private func requiredAtemProbeString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw AtemReadOnlyProbeConfigurationError.missingRequiredArgument(argument)
    }
    return value
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
    guard let value = values[argument] else {
        return defaultValue
    }
    guard let parsed = Int(value) else {
        throw AtemReadOnlyProbeConfigurationError.invalidInteger(argument: argument, value: value)
    }
    if parsed <= 0 {
        throw AtemReadOnlyProbeConfigurationError.nonPositiveArgument(argument)
    }
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
    switch value.lowercased() {
    case "true":
        return true
    case "false":
        return false
    default:
        throw AtemReadOnlyProbeConfigurationError.invalidBoolean(argument: argument, value: value)
    }
}

#if canImport(Darwin)
// ATEM TCP reachability is a local macOS operator probe. These helpers stay
// Darwin-only because they depend on Darwin socket layout and fd_set storage.
private func sockaddrIn(host: String, port: UInt16) -> sockaddr_in? {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian

    guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
        return nil
    }
    return address
}

private func elapsedMilliseconds(since start: Date) -> Double {
    Date().timeIntervalSince(start) * 1_000
}

private func atemSocketDescriptorFitsFDSet(_ descriptor: Int32) -> Bool {
    openLolaFileDescriptorFitsFDSet(descriptor)
}

private func withAtemSockaddrPointer<Result>(
    to address: inout sockaddr_in,
    _ body: (UnsafePointer<sockaddr>, socklen_t) -> Result
) -> Result {
    precondition(MemoryLayout<sockaddr_in>.size >= MemoryLayout<sockaddr>.size)
    precondition(MemoryLayout<sockaddr_in>.alignment >= MemoryLayout<sockaddr>.alignment)
    return withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            body($0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
}
#endif
