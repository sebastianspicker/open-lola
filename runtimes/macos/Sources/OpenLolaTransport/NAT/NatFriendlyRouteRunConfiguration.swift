import OpenLolaEvidenceModels
import OpenLolaSessionDomain
import OpenLolaContracts
// Declares NAT traversal configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Foundation

/// Configures NatFriendlyRouteRunConfiguration so callers supply explicit inputs before starting NAT traversal and relay setup.
public struct NatFriendlyRouteRunConfiguration: Codable, Equatable, Sendable {
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

    public init(
        bindHost: String,
        port: UInt16,
        sessionID: String,
        mode: NatFriendlyCompatibilityMode,
        expectedPeerCount: Int,
        timeoutSeconds: Int,
        outputPath: String
    ) {
        self.bindHost = bindHost
        self.port = port
        self.sessionID = sessionID
        self.mode = mode
        self.expectedPeerCount = expectedPeerCount
        self.timeoutSeconds = timeoutSeconds
        self.outputPath = outputPath
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
