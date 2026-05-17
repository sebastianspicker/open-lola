import Foundation

public struct NatSkippedDatagramCounts: Codable, Equatable, Sendable {
    public static let zero = NatSkippedDatagramCounts()

    public var malformed: Int
    public var wrongSession: Int
    public var wrongPeer: Int

    public init(malformed: Int = 0, wrongSession: Int = 0, wrongPeer: Int = 0) {
        self.malformed = malformed
        self.wrongSession = wrongSession
        self.wrongPeer = wrongPeer
    }

    func validate(fieldPrefix: String) throws {
        try requireNatNonNegative(malformed, "\(fieldPrefix).malformed")
        try requireNatNonNegative(wrongSession, "\(fieldPrefix).wrongSession")
        try requireNatNonNegative(wrongPeer, "\(fieldPrefix).wrongPeer")
    }
}

public struct NatRendezvousReport: PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var endpoint: NatEndpoint
    public var sessionID: String
    public var mode: NatFriendlyCompatibilityMode
    public var expectedPeerCount: Int
    public var registrations: [NatRendezvousRegistration]
    public var completedPeerResponses: Int
    public var skippedDatagrams: NatSkippedDatagramCounts
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        endpoint: NatEndpoint,
        sessionID: String,
        mode: NatFriendlyCompatibilityMode,
        expectedPeerCount: Int,
        registrations: [NatRendezvousRegistration],
        completedPeerResponses: Int,
        skippedDatagrams: NatSkippedDatagramCounts = .zero,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.endpoint = endpoint
        self.sessionID = sessionID
        self.mode = mode
        self.expectedPeerCount = expectedPeerCount
        self.registrations = registrations
        self.completedPeerResponses = completedPeerResponses
        self.skippedDatagrams = skippedDatagrams
        self.verdict = verdict
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case capturedAt
        case endpoint
        case sessionID
        case mode
        case expectedPeerCount
        case registrations
        case completedPeerResponses
        case skippedDatagrams
        case verdict
        case notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        capturedAt = try container.decode(String.self, forKey: .capturedAt)
        endpoint = try container.decode(NatEndpoint.self, forKey: .endpoint)
        sessionID = try container.decode(String.self, forKey: .sessionID)
        mode = try container.decode(NatFriendlyCompatibilityMode.self, forKey: .mode)
        expectedPeerCount = try container.decode(Int.self, forKey: .expectedPeerCount)
        registrations = try container.decode([NatRendezvousRegistration].self, forKey: .registrations)
        completedPeerResponses = try container.decode(Int.self, forKey: .completedPeerResponses)
        skippedDatagrams = try container.decodeIfPresent(
            NatSkippedDatagramCounts.self,
            forKey: .skippedDatagrams
        ) ?? .zero
        verdict = try container.decode(MeasurementVerdict.self, forKey: .verdict)
        notes = try container.decode(String.self, forKey: .notes)
    }

    public func validate() throws {
        try requireNatNonEmpty(id, "id")
        try requireNatNonEmpty(capturedAt, "capturedAt")
        try requireNatNonEmpty(endpoint.host, "endpoint.host")
        try requireNatPositive(Int(endpoint.port), "endpoint.port")
        try requireNatNonEmpty(sessionID, "sessionID")
        try requireNatPositive(expectedPeerCount, "expectedPeerCount")
        try requireNatNonNegative(completedPeerResponses, "completedPeerResponses")
        try skippedDatagrams.validate(fieldPrefix: "skippedDatagrams")
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
    public var skippedDatagrams: NatSkippedDatagramCounts
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        endpoint: NatEndpoint,
        sessionID: String,
        expectedPeerCount: Int,
        registrations: [NatRelayRegistration],
        forwardedDatagrams: Int,
        skippedDatagrams: NatSkippedDatagramCounts = .zero,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.endpoint = endpoint
        self.sessionID = sessionID
        self.expectedPeerCount = expectedPeerCount
        self.registrations = registrations
        self.forwardedDatagrams = forwardedDatagrams
        self.skippedDatagrams = skippedDatagrams
        self.verdict = verdict
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case capturedAt
        case endpoint
        case sessionID
        case expectedPeerCount
        case registrations
        case forwardedDatagrams
        case skippedDatagrams
        case verdict
        case notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        capturedAt = try container.decode(String.self, forKey: .capturedAt)
        endpoint = try container.decode(NatEndpoint.self, forKey: .endpoint)
        sessionID = try container.decode(String.self, forKey: .sessionID)
        expectedPeerCount = try container.decode(Int.self, forKey: .expectedPeerCount)
        registrations = try container.decode([NatRelayRegistration].self, forKey: .registrations)
        forwardedDatagrams = try container.decode(Int.self, forKey: .forwardedDatagrams)
        skippedDatagrams = try container.decodeIfPresent(
            NatSkippedDatagramCounts.self,
            forKey: .skippedDatagrams
        ) ?? .zero
        verdict = try container.decode(MeasurementVerdict.self, forKey: .verdict)
        notes = try container.decode(String.self, forKey: .notes)
    }

    public func validate() throws {
        try requireNatNonEmpty(id, "id")
        try requireNatNonEmpty(capturedAt, "capturedAt")
        try requireNatNonEmpty(endpoint.host, "endpoint.host")
        try requireNatPositive(Int(endpoint.port), "endpoint.port")
        try requireNatNonEmpty(sessionID, "sessionID")
        try requireNatPositive(expectedPeerCount, "expectedPeerCount")
        try requireNatNonNegative(forwardedDatagrams, "forwardedDatagrams")
        try skippedDatagrams.validate(fieldPrefix: "skippedDatagrams")
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
