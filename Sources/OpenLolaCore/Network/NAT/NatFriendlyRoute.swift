// Models NAT endpoints, traversal observations, and route verdicts so compatibility evidence cannot be mistaken for direct-path latency proof.
import Darwin
import Dispatch
import Foundation

/// Identifies which side of a NAT-friendly route binds or initiates the session.
public enum NatFriendlyRouteRole: String, Codable, Equatable, Sendable {
    case sender
    case looper
}

/// Selects the raw UDP compatibility strategy used for a NAT-friendly route.
public enum NatFriendlyCompatibilityMode: String, Codable, Equatable, Sendable {
    case rendezvousOnly
    case directTraversal
    case relayFallback
}

/// Describes NatEndpoint values used to plan and verify NAT traversal and relay setup.
public struct NatEndpoint: Codable, Equatable, Sendable {
    public var host: String
    public var port: UInt16

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }
}

/// Captures NatTraversalEvidence evidence in a stable form for validation and serialized reporting.
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
}

/// Configures NatFriendlyRouteReportInput so callers supply explicit inputs before starting NAT traversal and relay setup.
public struct NatFriendlyRouteReportInput: Sendable {
    public var id = ""
    public var capturedAt = ""
    public var sessionID = ""
    public var peerID = ""
    public var role: NatFriendlyRouteRole = .sender
    public var rendezvousEndpoint = NatEndpoint(host: "", port: 0)
    public var localEndpoint = NatEndpoint(host: "", port: 0)
    public var compatibilityMode: NatFriendlyCompatibilityMode = .rendezvousOnly
    public var rawP2PPreferred = false
    public var traversal = NatTraversalEvidence(
        observedExternalEndpoint: nil,
        peerEndpoint: nil,
        directCandidateDiscovered: false,
        directTraversalSucceeded: false,
        relayUsed: false,
        keepaliveIntervalMilliseconds: 0,
        directTraversalRttMicroseconds: nil,
        relayFallbackRttMicroseconds: nil,
        rawRouteRttMicroseconds: nil,
        addedLatencyMicroseconds: 0
    )
    public var loopback: UdpPcmLoopbackReport?
    public var verdict: MeasurementVerdict = .partial
    public var notes = ""
}

/// Enumerates failures that callers must handle when working with NAT traversal and relay setup.
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
 // swiftlint:disable:next identifier_name
 case relayFallbackWithoutFailedDirectTraversal
}

/// Captures NatFriendlyRouteReport evidence in a stable form for validation and serialized reporting.
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

    public init(_ input: NatFriendlyRouteReportInput) {
        id = input.id
        capturedAt = input.capturedAt
        sessionID = input.sessionID
        peerID = input.peerID
        role = input.role
        rendezvousEndpoint = input.rendezvousEndpoint
        localEndpoint = input.localEndpoint
        compatibilityMode = input.compatibilityMode
        rawP2PPreferred = input.rawP2PPreferred
        traversal = input.traversal
        loopback = input.loopback
        verdict = input.verdict
        notes = input.notes
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
           !traversal.relayUsed
            || !traversal.directCandidateDiscovered
            || traversal.directTraversalSucceeded {
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
