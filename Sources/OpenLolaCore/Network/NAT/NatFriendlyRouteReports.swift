import Foundation

public struct NatRendezvousReport: PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var endpoint: NatEndpoint
    public var sessionID: String
    public var mode: NatFriendlyCompatibilityMode
    public var expectedPeerCount: Int
    public var registrations: [NatRendezvousRegistration]
    public var completedPeerResponses: Int
    public var verdict: MeasurementVerdict
    public var notes: String

    public func validate() throws {
        try requireNatNonEmpty(id, "id")
        try requireNatNonEmpty(capturedAt, "capturedAt")
        try requireNatNonEmpty(endpoint.host, "endpoint.host")
        try requireNatPositive(Int(endpoint.port), "endpoint.port")
        try requireNatNonEmpty(sessionID, "sessionID")
        try requireNatPositive(expectedPeerCount, "expectedPeerCount")
        try requireNatNonNegative(completedPeerResponses, "completedPeerResponses")
        try requireNatNonEmpty(notes, "notes")
        for registration in registrations {
            try requireNatNonEmpty(registration.peerID, "registrations.peerID")
            guard natPeerIDIsSafe(registration.peerID) else {
                throw NatFriendlyRouteValidationError.emptyField("registrations.peerID")
            }
            try requireNatNonEmpty(registration.localEndpoint.host, "registrations.localEndpoint.host")
            try requireNatNonEmpty(
                registration.observedExternalEndpoint.host,
                "registrations.observedExternalEndpoint.host"
            )
            try requireNatPositive(
                Int(registration.observedExternalEndpoint.port),
                "registrations.observedExternalEndpoint.port"
            )
        }
    }
}

public struct NatRendezvousRegistration: Codable, Equatable, Sendable {
    public var peerID: String
    public var localEndpoint: NatEndpoint
    public var observedExternalEndpoint: NatEndpoint
    public var registeredAt: String
}

public struct NatRendezvousRegistrationRequest: Codable, Equatable, Sendable {
    public var sessionID: String
    public var peerID: String
    public var localEndpoint: NatEndpoint

    public init(sessionID: String, peerID: String, localEndpoint: NatEndpoint) {
        self.sessionID = sessionID
        self.peerID = peerID
        self.localEndpoint = localEndpoint
    }
}

public struct NatRendezvousRegistrationResponse: Codable, Equatable, Sendable {
    public var sessionID: String
    public var peerID: String
    public var observedExternalEndpoint: NatEndpoint
    public var peerEndpoint: NatEndpoint?
    public var peerEndpoints: [NatEndpoint]?
    public var registeredPeerCount: Int
    public var sessionComplete: Bool

    public init(
        sessionID: String,
        peerID: String,
        observedExternalEndpoint: NatEndpoint,
        peerEndpoint: NatEndpoint?,
        peerEndpoints: [NatEndpoint]? = nil,
        registeredPeerCount: Int,
        sessionComplete: Bool
    ) {
        self.sessionID = sessionID
        self.peerID = peerID
        self.observedExternalEndpoint = observedExternalEndpoint
        self.peerEndpoint = peerEndpoint
        self.peerEndpoints = peerEndpoints
        self.registeredPeerCount = registeredPeerCount
        self.sessionComplete = sessionComplete
    }
}

public struct NatRelayReport: PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var endpoint: NatEndpoint
    public var sessionID: String
    public var expectedPeerCount: Int
    public var registrations: [NatRelayRegistration]
    public var forwardedDatagrams: Int
    public var verdict: MeasurementVerdict
    public var notes: String

    public func validate() throws {
        try requireNatNonEmpty(id, "id")
        try requireNatNonEmpty(capturedAt, "capturedAt")
        try requireNatNonEmpty(endpoint.host, "endpoint.host")
        try requireNatPositive(Int(endpoint.port), "endpoint.port")
        try requireNatNonEmpty(sessionID, "sessionID")
        try requireNatPositive(expectedPeerCount, "expectedPeerCount")
        try requireNatNonNegative(forwardedDatagrams, "forwardedDatagrams")
        try requireNatNonEmpty(notes, "notes")
        for registration in registrations {
            try requireNatNonEmpty(registration.peerID, "registrations.peerID")
            guard natPeerIDIsSafe(registration.peerID) else {
                throw NatFriendlyRouteValidationError.emptyField("registrations.peerID")
            }
            try requireNatNonEmpty(
                registration.observedRelayEndpoint.host,
                "registrations.observedRelayEndpoint.host"
            )
            try requireNatPositive(
                Int(registration.observedRelayEndpoint.port),
                "registrations.observedRelayEndpoint.port"
            )
        }
    }
}

public struct NatRelayRegistration: Codable, Equatable, Sendable {
    public var peerID: String
    public var observedRelayEndpoint: NatEndpoint
    public var registeredAt: String
}

public struct NatRelayRegistrationRequest: Codable, Equatable, Sendable {
    public var magic: String
    public var sessionID: String
    public var peerID: String

    public init(sessionID: String, peerID: String) {
        self.magic = NatProtocolMagic.relayRegistration
        self.sessionID = sessionID
        self.peerID = peerID
    }
}

public struct NatRendezvousForwarderLauncherReport: PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var sessionID: String
    public var bindHost: String
    public var expectedPeerCount: Int
    public var rendezvousReport: NatRendezvousReport
    public var forwarderReport: NatRelayReport
    public var performanceWarning: String
    public var verdict: MeasurementVerdict
    public var notes: String

    public func validate() throws {
        try requireNatNonEmpty(id, "id")
        try requireNatNonEmpty(capturedAt, "capturedAt")
        try requireNatNonEmpty(sessionID, "sessionID")
        try requireNatNonEmpty(bindHost, "bindHost")
        try requireNatPositive(expectedPeerCount, "expectedPeerCount")
        try rendezvousReport.validate()
        try forwarderReport.validate()
        try requireNatNonEmpty(performanceWarning, "performanceWarning")
        try requireNatNonEmpty(notes, "notes")
    }
}

public struct NatRendezvousClientConfiguration: Codable, Equatable, Sendable {
    public var sessionID: String
    public var peerID: String
    public var localEndpoint: NatEndpoint
    public var rendezvousEndpoint: NatEndpoint
    public var timeoutSeconds: Int

    public init(
        sessionID: String,
        peerID: String,
        localEndpoint: NatEndpoint,
        rendezvousEndpoint: NatEndpoint,
        timeoutSeconds: Int
    ) {
        self.sessionID = sessionID
        self.peerID = peerID
        self.localEndpoint = localEndpoint
        self.rendezvousEndpoint = rendezvousEndpoint
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct NatRendezvousClientResult: Equatable, Sendable {
    public var localEndpoint: NatEndpoint
    public var response: NatRendezvousRegistrationResponse?
    public var attempts: Int
}

struct NatRegisteredSocket {
    let socket: Int32
    let localEndpoint: NatEndpoint
    let response: NatRendezvousRegistrationResponse?
    let attempts: Int
}
