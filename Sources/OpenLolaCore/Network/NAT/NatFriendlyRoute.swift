import Darwin
import Dispatch
import Foundation

public enum NatFriendlyRouteRole: String, Codable, Equatable, Sendable {
    case sender
    case looper
}

public enum NatFriendlyCompatibilityMode: String, Codable, Equatable, Sendable {
    case rendezvousOnly
    case directTraversal
    case relayFallback
}

public struct NatEndpoint: Codable, Equatable, Sendable {
    public var host: String
    public var port: UInt16

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }
}

public struct NatTraversalEvidence: Codable, Equatable, Sendable {
    public var observedExternalEndpoint: NatEndpoint?
    public var peerEndpoint: NatEndpoint?
    public var directCandidateDiscovered: Bool
    public var directTraversalSucceeded: Bool
    public var relayUsed: Bool
    public var keepaliveIntervalMilliseconds: Int
    public var directTraversalRttMicroseconds: Double?
    public var relayFallbackRttMicroseconds: Double?
    public var rawRouteRttMicroseconds: Double?
    public var addedLatencyMicroseconds: Double

    public init(
        observedExternalEndpoint: NatEndpoint?,
        peerEndpoint: NatEndpoint?,
        directCandidateDiscovered: Bool,
        directTraversalSucceeded: Bool,
        relayUsed: Bool,
        keepaliveIntervalMilliseconds: Int,
        directTraversalRttMicroseconds: Double? = nil,
        relayFallbackRttMicroseconds: Double? = nil,
        rawRouteRttMicroseconds: Double? = nil,
        addedLatencyMicroseconds: Double
    ) {
        self.observedExternalEndpoint = observedExternalEndpoint
        self.peerEndpoint = peerEndpoint
        self.directCandidateDiscovered = directCandidateDiscovered
        self.directTraversalSucceeded = directTraversalSucceeded
        self.relayUsed = relayUsed
        self.keepaliveIntervalMilliseconds = keepaliveIntervalMilliseconds
        self.directTraversalRttMicroseconds = directTraversalRttMicroseconds
        self.relayFallbackRttMicroseconds = relayFallbackRttMicroseconds
        self.rawRouteRttMicroseconds = rawRouteRttMicroseconds
        self.addedLatencyMicroseconds = addedLatencyMicroseconds
    }
}

public enum NatFriendlyRouteValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case passWithoutRawP2PPreference
    case passWithRelayAsFastestPath
    case passWithRendezvousOnlyMode
    case passWithoutDirectTraversal
    case passWithoutPassingLoopback
    case passWithoutRawRouteBaseline
    case directTraversalWithoutLoopback
    case directTraversalWithFailedLoopback
    case relayFallbackWithoutFailedDirectTraversal
}

public struct NatFriendlyRouteReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var sessionID: String
    public var peerID: String
    public var role: NatFriendlyRouteRole
    public var rendezvousEndpoint: NatEndpoint
    public var localEndpoint: NatEndpoint
    public var compatibilityMode: NatFriendlyCompatibilityMode
    public var rawP2PPreferred: Bool
    public var traversal: NatTraversalEvidence
    public var loopback: UdpPcmLoopbackReport?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        sessionID: String,
        peerID: String,
        role: NatFriendlyRouteRole,
        rendezvousEndpoint: NatEndpoint,
        localEndpoint: NatEndpoint,
        compatibilityMode: NatFriendlyCompatibilityMode,
        rawP2PPreferred: Bool,
        traversal: NatTraversalEvidence,
        loopback: UdpPcmLoopbackReport?,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.sessionID = sessionID
        self.peerID = peerID
        self.role = role
        self.rendezvousEndpoint = rendezvousEndpoint
        self.localEndpoint = localEndpoint
        self.compatibilityMode = compatibilityMode
        self.rawP2PPreferred = rawP2PPreferred
        self.traversal = traversal
        self.loopback = loopback
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> NatFriendlyRouteReport {
        try JSONDecoder().decode(NatFriendlyRouteReport.self, from: data)
    }

    public func validate() throws {
        try validateIdentityFields()
        try validateEndpoints()
        try validateTraversalMetrics()
        try validateNotes()
        try validateLoopbackEvidence()
        try validateTraversalLoopbackConsistency()
        try validateVerdict()
    }

    private func validateIdentityFields() throws {
        try requireNatNonEmpty(id, "id")
        try requireNatNonEmpty(capturedAt, "capturedAt")
        try requireNatNonEmpty(sessionID, "sessionID")
        try requireNatNonEmpty(peerID, "peerID")
    }

    private func validateEndpoints() throws {
        try requireNatNonEmpty(rendezvousEndpoint.host, "rendezvousEndpoint.host")
        try requireNatPositive(Int(rendezvousEndpoint.port), "rendezvousEndpoint.port")
        try requireNatNonEmpty(localEndpoint.host, "localEndpoint.host")
        try requireNatPositive(Int(localEndpoint.port), "localEndpoint.port")
    }

    private func validateTraversalMetrics() throws {
        try requireNatPositive(
            traversal.keepaliveIntervalMilliseconds,
            "traversal.keepaliveIntervalMilliseconds"
        )
        try requireNatNonNegative(
            traversal.addedLatencyMicroseconds,
            "traversal.addedLatencyMicroseconds"
        )
        if let directTraversalRttMicroseconds = traversal.directTraversalRttMicroseconds {
            try requireNatNonNegative(
                directTraversalRttMicroseconds,
                "traversal.directTraversalRttMicroseconds"
            )
        }
        if let relayFallbackRttMicroseconds = traversal.relayFallbackRttMicroseconds {
            try requireNatNonNegative(
                relayFallbackRttMicroseconds,
                "traversal.relayFallbackRttMicroseconds"
            )
        }
        if let rawRouteRttMicroseconds = traversal.rawRouteRttMicroseconds {
            try requireNatNonNegative(
                rawRouteRttMicroseconds,
                "traversal.rawRouteRttMicroseconds"
            )
        }
    }

    private func validateNotes() throws {
        try requireNatNonEmpty(notes, "notes")
    }

    private func validateLoopbackEvidence() throws {
        if let loopback {
            try loopback.validate()
        }
    }

    private func validateTraversalLoopbackConsistency() throws {
        if traversal.directTraversalSucceeded && loopback == nil {
            throw NatFriendlyRouteValidationError.directTraversalWithoutLoopback
        }
        if traversal.directTraversalSucceeded,
           let loopback,
           !loopback.metrics.byteExactEcho || loopback.metrics.packetsEchoed == 0 {
            throw NatFriendlyRouteValidationError.directTraversalWithFailedLoopback
        }
    }

    private func validateVerdict() throws {
        guard verdict == .pass else {
            try validateNonPassRelayFallback()
            return
        }
        try validatePassVerdict()
    }

    private func validateNonPassRelayFallback() throws {
        if compatibilityMode == .relayFallback,
           (!traversal.relayUsed
            || !traversal.directCandidateDiscovered
            || traversal.directTraversalSucceeded) {
            throw NatFriendlyRouteValidationError.relayFallbackWithoutFailedDirectTraversal
        }
    }

    private func validatePassVerdict() throws {
        if compatibilityMode == .relayFallback || traversal.relayUsed {
            throw NatFriendlyRouteValidationError.passWithRelayAsFastestPath
        }
        if compatibilityMode == .rendezvousOnly {
            throw NatFriendlyRouteValidationError.passWithRendezvousOnlyMode
        }
        if !rawP2PPreferred {
            throw NatFriendlyRouteValidationError.passWithoutRawP2PPreference
        }
        if !traversal.directTraversalSucceeded {
            throw NatFriendlyRouteValidationError.passWithoutDirectTraversal
        }
        if loopback?.verdict != .pass {
            throw NatFriendlyRouteValidationError.passWithoutPassingLoopback
        }
        if traversal.rawRouteRttMicroseconds == nil {
            throw NatFriendlyRouteValidationError.passWithoutRawRouteBaseline
        }
    }
}

public struct NatFriendlyRouteRunConfiguration: Codable, Equatable, Sendable {
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

    public init(
        role: NatFriendlyRouteRole,
        bindHost: String,
        peerID: String,
        rendezvousHost: String,
        rendezvousPort: UInt16,
        relayHost: String? = nil,
        relayPort: UInt16? = nil,
        sessionID: String,
        localUdpPort: UInt16,
        durationSeconds: Int,
        keepaliveIntervalMilliseconds: Int = 100,
        rawRouteRttMicroseconds: Double? = nil,
        outputPath: String,
        debugOutputPath: String?
    ) {
        self.role = role
        self.bindHost = bindHost
        self.peerID = peerID
        self.rendezvousHost = rendezvousHost
        self.rendezvousPort = rendezvousPort
        self.relayHost = relayHost
        self.relayPort = relayPort
        self.sessionID = sessionID
        self.localUdpPort = localUdpPort
        self.durationSeconds = durationSeconds
        self.keepaliveIntervalMilliseconds = keepaliveIntervalMilliseconds
        self.rawRouteRttMicroseconds = rawRouteRttMicroseconds
        self.outputPath = outputPath
        self.debugOutputPath = debugOutputPath
    }

    public static func parse(_ arguments: [String]) throws -> NatFriendlyRouteRunConfiguration {
        let values = try parseNatArguments(
            arguments,
            allowed: [
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
        )
        let roleText = try requiredNatString("--role", values)
        guard let role = NatFriendlyRouteRole(rawValue: roleText) else {
            throw NatFriendlyRouteRunConfigurationError.invalidRole(roleText)
        }
        return NatFriendlyRouteRunConfiguration(
            role: role,
            bindHost: try requiredNatString("--bind-host", values),
            peerID: try requiredNatString("--peer-id", values),
            rendezvousHost: try requiredNatString("--rendezvous-host", values),
            rendezvousPort: try requiredNatPort("--rendezvous-port", values),
            relayHost: try optionalNatRelayHost(values),
            relayPort: try optionalNatRelayPort(values),
            sessionID: try requiredNatString("--session-id", values),
            localUdpPort: try requiredNatLocalUdpPort("--port", values),
            durationSeconds: try requiredNatPositiveInteger("--duration-seconds", values),
            keepaliveIntervalMilliseconds: try optionalNatPositiveInteger(
                "--keepalive-interval-ms",
                values
            ) ?? 100,
            rawRouteRttMicroseconds: try optionalNatNonNegativeDouble("--raw-rtt-microseconds", values),
            outputPath: try requiredNatString("--output", values),
            debugOutputPath: values["--debug-output"]
        )
    }
}

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
        return NatRelayRunConfiguration(
            bindHost: try requiredNatString("--bind-host", values),
            port: try requiredNatPort("--port", values),
            sessionID: try requiredNatString("--session-id", values),
            expectedPeerCount: try optionalNatPositiveInteger("--expected-peers", values) ?? 2,
            timeoutSeconds: try optionalNatPositiveInteger("--timeout-seconds", values) ?? 30,
            outputPath: try requiredNatString("--output", values)
        )
    }
}

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
        return NatRendezvousForwarderLauncherConfiguration(
            bindHost: try requiredNatString("--bind-host", values),
            rendezvousPort: rendezvousPort,
            forwarderPort: forwarderPort,
            sessionID: try requiredNatString("--session-id", values),
            expectedPeerCount: try optionalNatPositiveInteger("--expected-peers", values) ?? 2,
            timeoutSeconds: try optionalNatPositiveInteger("--timeout-seconds", values) ?? 30,
            outputPath: try requiredNatString("--output", values)
        )
    }
}

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
