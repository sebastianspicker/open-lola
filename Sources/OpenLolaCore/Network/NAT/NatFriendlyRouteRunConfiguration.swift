// Declares NAT traversal configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Foundation

/// Configures NatFriendlyRouteRunConfiguration so callers supply explicit inputs before starting NAT traversal and relay setup.
public struct NatFriendlyRouteRunConfiguration: Codable, Equatable, Sendable {
    private static let allowedArguments: Set<String> = [
        "--role",
        "--bind-host",
        "--peer-id",
        "--rendezvous-host",
        "--rendezvous-port",
        "--relay-host",
        "--relay-port",
        "--session-id",
        "--port",
        "--duration-seconds",
        "--keepalive-interval-ms",
        "--raw-rtt-microseconds",
        "--output",
        "--debug-output"
    ]

    public struct Identity: Codable, Equatable, Sendable {
        public var role: NatFriendlyRouteRole
        public var bindHost: String
        public var peerID: String
        public var sessionID: String

        public init(role: NatFriendlyRouteRole, bindHost: String, peerID: String, sessionID: String) {
            self.role = role
            self.bindHost = bindHost
            self.peerID = peerID
            self.sessionID = sessionID
        }
    }

    public struct Traversal: Codable, Equatable, Sendable {
        public var rendezvousHost: String
        public var rendezvousPort: UInt16
        public var relayHost: String?
        public var relayPort: UInt16?

        public init(
            rendezvousHost: String,
            rendezvousPort: UInt16,
            relayHost: String? = nil,
            relayPort: UInt16? = nil
        ) {
            self.rendezvousHost = rendezvousHost
            self.rendezvousPort = rendezvousPort
            self.relayHost = relayHost
            self.relayPort = relayPort
        }
    }

    public struct Runtime: Codable, Equatable, Sendable {
        public var localUdpPort: UInt16
        public var durationSeconds: Int
        public var keepaliveIntervalMilliseconds: Int
        public var rawRouteRttMicroseconds: Double?

        public init(
            localUdpPort: UInt16,
            durationSeconds: Int,
            keepaliveIntervalMilliseconds: Int = 100,
            rawRouteRttMicroseconds: Double? = nil
        ) {
            self.localUdpPort = localUdpPort
            self.durationSeconds = durationSeconds
            self.keepaliveIntervalMilliseconds = keepaliveIntervalMilliseconds
            self.rawRouteRttMicroseconds = rawRouteRttMicroseconds
        }
    }

    public struct Output: Codable, Equatable, Sendable {
        public var reportPath: String
        public var debugPath: String?

        public init(reportPath: String, debugPath: String?) {
            self.reportPath = reportPath
            self.debugPath = debugPath
        }
    }

    public struct Input: Codable, Equatable, Sendable {
        public var identity: Identity
        public var traversal: Traversal
        public var runtime: Runtime
        public var output: Output

        public init(identity: Identity, traversal: Traversal, runtime: Runtime, output: Output) {
            self.identity = identity
            self.traversal = traversal
            self.runtime = runtime
            self.output = output
        }
    }

    public let role: NatFriendlyRouteRole
    public let bindHost: String
    public let peerID: String
    public let rendezvousHost: String
    public let rendezvousPort: UInt16
    public let relayHost: String?
    public let relayPort: UInt16?
    public let sessionID: String
    public let localUdpPort: UInt16
    public let durationSeconds: Int
    public let keepaliveIntervalMilliseconds: Int
    public let rawRouteRttMicroseconds: Double?
    public let outputPath: String
    public let debugOutputPath: String?

    public init(_ input: Input) {
        self.role = input.identity.role
        self.bindHost = input.identity.bindHost
        self.peerID = input.identity.peerID
        self.rendezvousHost = input.traversal.rendezvousHost
        self.rendezvousPort = input.traversal.rendezvousPort
        self.relayHost = input.traversal.relayHost
        self.relayPort = input.traversal.relayPort
        self.sessionID = input.identity.sessionID
        self.localUdpPort = input.runtime.localUdpPort
        self.durationSeconds = input.runtime.durationSeconds
        self.keepaliveIntervalMilliseconds = input.runtime.keepaliveIntervalMilliseconds
        self.rawRouteRttMicroseconds = input.runtime.rawRouteRttMicroseconds
        self.outputPath = input.output.reportPath
        self.debugOutputPath = input.output.debugPath
    }

    public static func parse(_ arguments: [String]) throws -> NatFriendlyRouteRunConfiguration {
        let values = try parseNatArguments(
            arguments,
            allowed: allowedArguments
        )
        let roleText = try requiredNatString("--role", values)
        guard let role = NatFriendlyRouteRole(rawValue: roleText) else {
            throw NatFriendlyRouteRunConfigurationError.invalidRole(roleText)
        }
        let identity = Identity(
            role: role,
            bindHost: try requiredNatString("--bind-host", values),
            peerID: try requiredNatString("--peer-id", values),
            sessionID: try requiredNatString("--session-id", values)
        )
        let traversal = Traversal(
            rendezvousHost: try requiredNatString("--rendezvous-host", values),
            rendezvousPort: try requiredNatPort("--rendezvous-port", values),
            relayHost: try optionalNatRelayHost(values),
            relayPort: try optionalNatRelayPort(values)
        )
        let runtime = Runtime(
            localUdpPort: try requiredNatLocalUdpPort("--port", values),
            durationSeconds: try requiredNatPositiveInteger("--duration-seconds", values),
            keepaliveIntervalMilliseconds: try optionalNatPositiveInteger(
                "--keepalive-interval-ms",
                values
            ) ?? 100,
            rawRouteRttMicroseconds: try optionalNatNonNegativeDouble("--raw-rtt-microseconds", values)
        )
        return NatFriendlyRouteRunConfiguration(
            Input(
                identity: identity,
                traversal: traversal,
                runtime: runtime,
                output: Output(
                    reportPath: try requiredNatString("--output", values),
                    debugPath: values["--debug-output"]
                )
            )
        )
    }
}

/// Configures NatRendezvousRunConfiguration so callers supply explicit inputs before starting NAT traversal and relay setup.
public struct NatRendezvousRunConfiguration: Codable, Equatable, Sendable {
    public let bindHost: String
    public let port: UInt16
    public let sessionID: String
    public let mode: NatFriendlyCompatibilityMode
    public let expectedPeerCount: Int
    public let timeoutSeconds: Int
    public let outputPath: String

    public static func parse(_ arguments: [String]) throws -> NatRendezvousRunConfiguration {
        let values = try parseNatArguments(
            arguments,
            allowed: [
                "--bind-host",
                "--port",
                "--session-id",
                "--mode",
                "--expected-peers",
                "--timeout-seconds",
                "--output"
            ]
        )
        let modeText = try requiredNatString("--mode", values)
        guard let mode = NatFriendlyCompatibilityMode(rawValue: modeText) else {
            throw NatFriendlyRouteRunConfigurationError.invalidMode(modeText)
        }
        return NatRendezvousRunConfiguration(
            bindHost: try requiredNatString("--bind-host", values),
            port: try requiredNatPort("--port", values),
            sessionID: try requiredNatString("--session-id", values),
            mode: mode,
            expectedPeerCount: try optionalNatPositiveInteger("--expected-peers", values) ?? 2,
            timeoutSeconds: try optionalNatPositiveInteger("--timeout-seconds", values) ?? 30,
            outputPath: try requiredNatString("--output", values)
        )
    }
}

/// Configures NatRelayRunConfiguration so callers supply explicit inputs before starting NAT traversal and relay setup.
public struct NatRelayRunConfiguration: Codable, Equatable, Sendable {
    public let bindHost: String
    public let port: UInt16
    public let sessionID: String
    public let expectedPeerCount: Int
    public let timeoutSeconds: Int
    public let outputPath: String

    public init(
        bindHost: String,
        port: UInt16,
        sessionID: String,
        expectedPeerCount: Int,
        timeoutSeconds: Int,
        outputPath: String
    ) {
        self.bindHost = bindHost
        self.port = port
        self.sessionID = sessionID
        self.expectedPeerCount = expectedPeerCount
        self.timeoutSeconds = timeoutSeconds
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> NatRelayRunConfiguration {
        let values = try parseNatArguments(
            arguments,
            allowed: [
                "--bind-host",
                "--port",
                "--session-id",
                "--expected-peers",
                "--timeout-seconds",
                "--output"
            ]
        )
        let common = try parseNatServerRunArguments(values)
        return NatRelayRunConfiguration(
            bindHost: common.bindHost,
            port: try requiredNatPort("--port", values),
            sessionID: common.sessionID,
            expectedPeerCount: common.expectedPeerCount,
            timeoutSeconds: common.timeoutSeconds,
            outputPath: common.outputPath
        )
    }
}

// swiftlint:disable:next type_name
/// Configures NatRendezvousForwarderLauncherConfiguration so callers supply explicit inputs before starting NAT traversal and relay setup.
public struct NatRendezvousForwarderLauncherConfiguration: Codable, Equatable, Sendable {
    public let bindHost: String
    public let rendezvousPort: UInt16
    public let forwarderPort: UInt16
    public let sessionID: String
    public let expectedPeerCount: Int
    public let timeoutSeconds: Int
    public let outputPath: String

    public init(
        bindHost: String,
        rendezvousPort: UInt16,
        forwarderPort: UInt16,
        sessionID: String,
        expectedPeerCount: Int,
        timeoutSeconds: Int,
        outputPath: String
    ) {
        self.bindHost = bindHost
        self.rendezvousPort = rendezvousPort
        self.forwarderPort = forwarderPort
        self.sessionID = sessionID
        self.expectedPeerCount = expectedPeerCount
        self.timeoutSeconds = timeoutSeconds
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> NatRendezvousForwarderLauncherConfiguration {
        let values = try parseNatArguments(
            arguments,
            allowed: [
                "--bind-host",
                "--rendezvous-port",
                "--forwarder-port",
                "--session-id",
                "--expected-peers",
                "--timeout-seconds",
                "--output"
            ]
        )
        let rendezvousPort = try requiredNatPort("--rendezvous-port", values)
        let forwarderPort = try requiredNatPort("--forwarder-port", values)
        guard rendezvousPort != forwarderPort else {
            throw NatFriendlyRouteRunConfigurationError.conflictingPorts(
                "--rendezvous-port and --forwarder-port must differ"
            )
        }
        let common = try parseNatServerRunArguments(values)
        return NatRendezvousForwarderLauncherConfiguration(
            bindHost: common.bindHost,
            rendezvousPort: rendezvousPort,
            forwarderPort: forwarderPort,
            sessionID: common.sessionID,
            expectedPeerCount: common.expectedPeerCount,
            timeoutSeconds: common.timeoutSeconds,
            outputPath: common.outputPath
        )
    }
}

private struct NatServerRunArguments {
    var bindHost: String
    var sessionID: String
    var expectedPeerCount: Int
    var timeoutSeconds: Int
    var outputPath: String
}

private func parseNatServerRunArguments(
    _ values: [String: String]
) throws -> NatServerRunArguments {
    NatServerRunArguments(
        bindHost: try requiredNatString("--bind-host", values),
        sessionID: try requiredNatString("--session-id", values),
        expectedPeerCount: try optionalNatPositiveInteger("--expected-peers", values) ?? 2,
        timeoutSeconds: try optionalNatPositiveInteger("--timeout-seconds", values) ?? 30,
        outputPath: try requiredNatString("--output", values)
    )
}

/// Enumerates failures that callers must handle when working with NAT traversal and relay setup.
public enum NatFriendlyRouteRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidInteger(argument: String, value: String)
    case nonPositiveArgument(String)
    case invalidPort(Int)
    case invalidRole(String)
    case invalidMode(String)
    case conflictingPorts(String)
}
