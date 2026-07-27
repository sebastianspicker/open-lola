// Collects NAT traversal evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Represents NatSkippedDatagramCounts values used by NAT traversal and relay setup.
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

private protocol NatReportCoreCodingKeys: CodingKey {
    static var id: Self { get }
    static var capturedAt: Self { get }
    static var endpoint: Self { get }
    static var sessionID: Self { get }
    static var skippedDatagrams: Self { get }
    static var verdict: Self { get }
    static var notes: Self { get }
}

private struct NatReportIdentityFields {
    var id: String
    var capturedAt: String
    var endpoint: NatEndpoint
    var sessionID: String

    var values: (
        capture: (id: String, capturedAt: String),
        route: (endpoint: NatEndpoint, sessionID: String)
    ) {
        ((id, capturedAt), (endpoint, sessionID))
    }
}

private struct NatReportOutcomeFields {
    var skippedDatagrams: NatSkippedDatagramCounts
    var verdict: MeasurementVerdict
    var notes: String

    var values: (
        skippedDatagrams: NatSkippedDatagramCounts,
        disposition: (verdict: MeasurementVerdict, notes: String)
    ) {
        (skippedDatagrams, (verdict, notes))
    }
}

private protocol NatReportCoreFields {
    var id: String { get }
    var capturedAt: String { get }
    var endpoint: NatEndpoint { get }
    var sessionID: String { get }
    var expectedPeerCount: Int { get }
    var skippedDatagrams: NatSkippedDatagramCounts { get }
    var notes: String { get }
}

private func decodeNatReportIdentity<Key: NatReportCoreCodingKeys>(
    from container: KeyedDecodingContainer<Key>
) throws -> NatReportIdentityFields {
    NatReportIdentityFields(
        id: try container.decode(String.self, forKey: .id),
        capturedAt: try container.decode(String.self, forKey: .capturedAt),
        endpoint: try container.decode(NatEndpoint.self, forKey: .endpoint),
        sessionID: try container.decode(String.self, forKey: .sessionID)
    )
}

private func decodeNatReportContainerAndIdentity<Key: NatReportCoreCodingKeys>(
    from decoder: Decoder,
    keyedBy keyType: Key.Type
) throws -> (container: KeyedDecodingContainer<Key>, identity: NatReportIdentityFields) {
    let container = try decoder.container(keyedBy: keyType)
    return (container, try decodeNatReportIdentity(from: container))
}

private func decodeNatReportOutcome<Key: NatReportCoreCodingKeys>(
    from container: KeyedDecodingContainer<Key>
) throws -> NatReportOutcomeFields {
    NatReportOutcomeFields(
        skippedDatagrams: try container.decodeIfPresent(
            NatSkippedDatagramCounts.self,
            forKey: .skippedDatagrams
        ) ?? .zero,
        verdict: try container.decode(MeasurementVerdict.self, forKey: .verdict),
        notes: try container.decode(String.self, forKey: .notes)
    )
}

private func validateNatReportIdentity(
    id: String,
    capturedAt: String,
    endpoint: NatEndpoint,
    sessionID: String,
    expectedPeerCount: Int
) throws {
    try requireNatNonEmpty(id, "id")
    try requireNatNonEmpty(capturedAt, "capturedAt")
    try requireNatNonEmpty(endpoint.host, "endpoint.host")
    try requireNatPositive(Int(endpoint.port), "endpoint.port")
    try requireNatNonEmpty(sessionID, "sessionID")
    try requireNatPositive(expectedPeerCount, "expectedPeerCount")
}

private func validateNatReportOutcome(
    skippedDatagrams: NatSkippedDatagramCounts,
    notes: String
) throws {
    try skippedDatagrams.validate(fieldPrefix: "skippedDatagrams")
    try requireNatNonEmpty(notes, "notes")
}

private func validateNatReportIdentity<Report: NatReportCoreFields>(_ report: Report) throws {
    try validateNatReportIdentity(
        id: report.id,
        capturedAt: report.capturedAt,
        endpoint: report.endpoint,
        sessionID: report.sessionID,
        expectedPeerCount: report.expectedPeerCount
    )
}

private func validateNatReportOutcome<Report: NatReportCoreFields>(_ report: Report) throws {
    try validateNatReportOutcome(
        skippedDatagrams: report.skippedDatagrams,
        notes: report.notes
    )
}

private func validateNatRegistrationPeerID(_ peerID: String) throws {
    try requireNatNonEmpty(peerID, "registrations.peerID")
    guard natPeerIDIsSafe(peerID) else {
        throw NatFriendlyRouteValidationError.emptyField("registrations.peerID")
    }
}

/// Captures NatRendezvousReport evidence in a stable form for validation and serialized reporting.
public struct NatRendezvousReport: PrettyJSONCodable, Equatable, Sendable {
public var id: String
public var capturedAt: String
    public var endpoint: NatEndpoint
    public var sessionID: String
    public var mode: NatFriendlyCompatibilityMode
    public var expectedPeerCount: Int
    public var registrations: [NatRendezvousRegistration]
    public var completedPeerResponses: Int
    public var skippedDatagrams: NatSkippedDatagramCounts = .zero
public var verdict: MeasurementVerdict
public var notes: String

public init(_ input: NatRendezvousReportInput) {
id = input.id
capturedAt = input.capturedAt
endpoint = input.endpoint
sessionID = input.sessionID
mode = input.mode
expectedPeerCount = input.expectedPeerCount
registrations = input.registrations
completedPeerResponses = input.completedPeerResponses
skippedDatagrams = input.skippedDatagrams
verdict = input.verdict
notes = input.notes
}

private enum CodingKeys: String, CodingKey, NatReportCoreCodingKeys {
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
        let (container, identity) = try decodeNatReportContainerAndIdentity(
            from: decoder,
            keyedBy: CodingKeys.self
        )
        ((id, capturedAt), (endpoint, sessionID)) = identity.values
        mode = try container.decode(NatFriendlyCompatibilityMode.self, forKey: .mode)
        expectedPeerCount = try container.decode(Int.self, forKey: .expectedPeerCount)
        registrations = try container.decode([NatRendezvousRegistration].self, forKey: .registrations)
        completedPeerResponses = try container.decode(Int.self, forKey: .completedPeerResponses)
        let outcome = try decodeNatReportOutcome(from: container)
        (skippedDatagrams, (verdict, notes)) = outcome.values
    }

    public func validate() throws {
        try validateNatReportIdentity(self)
        try requireNatNonNegative(completedPeerResponses, "completedPeerResponses")
        try validateNatReportOutcome(self)
        for registration in registrations {
            try validateNatRegistrationPeerID(registration.peerID)
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

/// Configures NatRendezvousReportInput so callers supply explicit inputs before starting NAT traversal and relay setup.
public struct NatRendezvousReportInput: Sendable {
public var id = ""
public var capturedAt = ""
public var endpoint = NatEndpoint(host: "", port: 0)
public var sessionID = ""
public var mode = NatFriendlyCompatibilityMode.rendezvousOnly
public var expectedPeerCount = 0
public var registrations: [NatRendezvousRegistration] = []
public var completedPeerResponses = 0
public var skippedDatagrams = NatSkippedDatagramCounts.zero
public var verdict = MeasurementVerdict.partial
public var notes = ""
}

/// Represents NatRendezvousRegistration values used by NAT traversal and relay setup.
public struct NatRendezvousRegistration: Codable, Equatable, Sendable {
    public var peerID: String
    public var localEndpoint: NatEndpoint
    public var observedExternalEndpoint: NatEndpoint
    public var registeredAt: String
}

/// Configures NatRendezvousRegistrationRequest so callers supply explicit inputs before starting NAT traversal and relay setup.
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

/// Represents NatRendezvousRegistrationResponse values used by NAT traversal and relay setup.
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

/// Captures NatRelayReport evidence in a stable form for validation and serialized reporting.
public struct NatRelayReport: PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var endpoint: NatEndpoint
    public var sessionID: String
    public var expectedPeerCount: Int
    public var registrations: [NatRelayRegistration]
    public var forwardedDatagrams: Int
public var forwardingBackpressureDrops: Int
public var skippedDatagrams: NatSkippedDatagramCounts = .zero
public var verdict: MeasurementVerdict
public var notes: String

public init(_ input: NatRelayReportInput) {
id = input.id
capturedAt = input.capturedAt
endpoint = input.endpoint
sessionID = input.sessionID
expectedPeerCount = input.expectedPeerCount
registrations = input.registrations
forwardedDatagrams = input.forwardedDatagrams
forwardingBackpressureDrops = input.forwardingBackpressureDrops
skippedDatagrams = input.skippedDatagrams
verdict = input.verdict
notes = input.notes
}

private enum CodingKeys: String, CodingKey, NatReportCoreCodingKeys {
        case id
        case capturedAt
        case endpoint
        case sessionID
        case expectedPeerCount
        case registrations
        case forwardedDatagrams
        case forwardingBackpressureDrops
        case skippedDatagrams
        case verdict
        case notes
    }

    private static let legacyForwardingBackpressureDrops = 0

    public init(from decoder: Decoder) throws {
        let (container, identity) = try decodeNatReportContainerAndIdentity(
            from: decoder,
            keyedBy: CodingKeys.self
        )
        ((id, capturedAt), (endpoint, sessionID)) = identity.values
        expectedPeerCount = try container.decode(Int.self, forKey: .expectedPeerCount)
        registrations = try container.decode([NatRelayRegistration].self, forKey: .registrations)
        forwardedDatagrams = try container.decode(Int.self, forKey: .forwardedDatagrams)
        forwardingBackpressureDrops = try container.decodeIfPresent(
            Int.self,
            forKey: .forwardingBackpressureDrops
        ) ?? Self.legacyForwardingBackpressureDrops
        let outcome = try decodeNatReportOutcome(from: container)
        (skippedDatagrams, (verdict, notes)) = outcome.values
    }

    public func validate() throws {
        try validateNatReportIdentity(self)
        try requireNatNonNegative(forwardedDatagrams, "forwardedDatagrams")
        try requireNatNonNegative(forwardingBackpressureDrops, "forwardingBackpressureDrops")
        try validateNatReportOutcome(self)
        for registration in registrations {
            try validateNatRegistrationPeerID(registration.peerID)
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

extension NatRendezvousReport: NatReportCoreFields {}
extension NatRelayReport: NatReportCoreFields {}

/// Configures NatRelayReportInput so callers supply explicit inputs before starting NAT traversal and relay setup.
public struct NatRelayReportInput: Sendable {
public var id = ""
public var capturedAt = ""
public var endpoint = NatEndpoint(host: "", port: 0)
public var sessionID = ""
public var expectedPeerCount = 0
public var registrations: [NatRelayRegistration] = []
public var forwardedDatagrams = 0
public var forwardingBackpressureDrops = 0
public var skippedDatagrams = NatSkippedDatagramCounts.zero
public var verdict = MeasurementVerdict.partial
public var notes = ""
}

/// Represents NatRelayRegistration values used by NAT traversal and relay setup.
public struct NatRelayRegistration: Codable, Equatable, Sendable {
    public var peerID: String
    public var observedRelayEndpoint: NatEndpoint
    public var registeredAt: String
}

/// Configures NatRelayRegistrationRequest so callers supply explicit inputs before starting NAT traversal and relay setup.
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

/// Captures NatRendezvousForwarderLauncherReport evidence in a stable form for validation and serialized reporting.
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

/// Configures NatRendezvousClientConfiguration so callers supply explicit inputs before starting NAT traversal and relay setup.
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

/// Represents the NatRendezvousClientResult produced by NAT traversal and relay setup without exposing its execution state.
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
