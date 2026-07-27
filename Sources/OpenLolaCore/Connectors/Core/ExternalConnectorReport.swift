// Defines connector evidence categories and validates source-level and real-world verdict claims.
import Foundation

/// Identifies LoLa, UltraGrid/MVTP, or JackTrip as the connector under test.
public enum ExternalConnectorKind: String, CaseIterable, Codable, Equatable, Sendable {
    case lola
    case mvtpUltraGrid
    case jackTrip
}

/// Defines the supported choices for external connector handshake kind.
public enum ExternalConnectorHandshakeKind: String, Codable, Equatable, Sendable {
    case descriptorOnly
    case externalProcessDescriptor
    case controlOnlyTxRx
    case protocolAwareTxRx
}

/// Defines the supported choices for external connector evidence class.
public enum ExternalConnectorEvidenceClass: String, CaseIterable, Codable, Equatable, Sendable {
    case synthetic
    case localLoopback = "local-loopback"
    case referencePeer = "reference-peer"
    case liveDevice = "live-device"
    case fieldRoute = "field-route"
    case packetCapture = "packet-capture"
    case timing
    case teardown
    case mediaQuality = "media-quality"
}

public extension ExternalConnectorEvidenceClass {
    static let runtimePassRequiredEvidence: [ExternalConnectorEvidenceClass] = [
        .referencePeer,
        .liveDevice,
        .fieldRoute,
        .packetCapture,
        .timing,
        .teardown,
        .mediaQuality
    ]

    static func missingRuntimePassEvidence(
        observed: [ExternalConnectorEvidenceClass]
    ) -> [ExternalConnectorEvidenceClass] {
        runtimePassRequiredEvidence.filter { !observed.contains($0) }
    }
}

/// Records the evidence and outcome for external connector media provider report.
public struct ExternalConnectorMediaProviderReport: Codable, Equatable, Sendable {
    public var audioSource: String
    public var videoSource: String
    public var observedEvidenceClasses: [ExternalConnectorEvidenceClass]
    public var notes: String

    public init(
        audioSource: String,
        videoSource: String,
        observedEvidenceClasses: [ExternalConnectorEvidenceClass],
        notes: String
    ) {
        self.audioSource = audioSource
        self.videoSource = videoSource
        self.observedEvidenceClasses = observedEvidenceClasses
        self.notes = notes
    }

    public func validate(fieldPrefix: String) throws {
        try requireExternalConnectorSessionNonEmpty(audioSource, "\(fieldPrefix).audioSource")
        try requireExternalConnectorSessionNonEmpty(videoSource, "\(fieldPrefix).videoSource")
        try requireExternalConnectorSessionNonEmptyEvidenceClasses(
            observedEvidenceClasses,
            "\(fieldPrefix).observedEvidenceClasses"
        )
        try requireExternalConnectorSessionNonEmpty(notes, "\(fieldPrefix).notes")
    }
}

/// Records the evidence and outcome for external connector media sink report.
public struct ExternalConnectorMediaSinkReport: Codable, Equatable, Sendable {
    public var audioPacketCount: Int
    public var audioPayloadByteCount: Int
    public var videoFrameCount: Int
    public var videoPayloadByteCount: Int
    public var rejectedMediaCount: Int
    public var notes: String

    public init(
        audioPacketCount: Int = 0,
        audioPayloadByteCount: Int = 0,
        videoFrameCount: Int = 0,
        videoPayloadByteCount: Int = 0,
        rejectedMediaCount: Int = 0,
        notes: String
    ) {
        self.audioPacketCount = audioPacketCount
        self.audioPayloadByteCount = audioPayloadByteCount
        self.videoFrameCount = videoFrameCount
        self.videoPayloadByteCount = videoPayloadByteCount
        self.rejectedMediaCount = rejectedMediaCount
        self.notes = notes
    }

    public func validate(fieldPrefix: String) throws {
        for (field, value) in [
            ("audioPacketCount", audioPacketCount),
            ("audioPayloadByteCount", audioPayloadByteCount),
            ("videoFrameCount", videoFrameCount),
            ("videoPayloadByteCount", videoPayloadByteCount),
            ("rejectedMediaCount", rejectedMediaCount)
        ] {
            guard value >= 0 else {
                throw ExternalConnectorSessionError.invalidPositiveInteger(
                    "\(fieldPrefix).\(field)",
                    String(value)
                )
            }
        }
        try requireExternalConnectorSessionNonEmpty(notes, "\(fieldPrefix).notes")
    }
}

/// Defines the validated fields for external connector contract.
public struct ExternalConnectorContract: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var connector: ExternalConnectorKind
    public var supportedHandshake: ExternalConnectorHandshakeKind
    public var sourceContractImplemented: Bool
    public var realWorldInteroperabilityClaimed: Bool
    public var preservesDefaultAudioFirstPath: Bool
    public var defaultEnabled: Bool
    public var externalImplementationRequired: Bool
    public var publicReference: String
    public var cleanRoomBoundary: String
    public var requiredEvidenceForRealWorldPass: [String]
    public var notes: String

}

/// Defines failures reported when external connector validation error cannot continue.
public enum ExternalConnectorValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyList(String)
    case duplicateConnector(String)
    case missingConnector(String)
    case sourcePassWithoutImplementedContract(String)
    case realWorldPassNotAllowed
    case realWorldClaimWithoutEvidence(String)
    case audioFirstPathRisk(String)
    case defaultEnabled(String)
}

/// Records the evidence and outcome for external connector report.
public struct ExternalConnectorReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var connectors: [ExternalConnectorContract]
    public var sourceLevelVerdict: MeasurementVerdict
    public var realWorldVerdict: MeasurementVerdict
    public var verdict: MeasurementVerdict
    public var observedEvidenceClasses: [ExternalConnectorEvidenceClass]
    public var missingEvidenceClassesForRealWorldPass: [ExternalConnectorEvidenceClass]
    public var assumptions: [String]
    public var notes: String

    public func validate() throws {
        try requireExternalConnectorNonEmpty(id, "id")
        try requireExternalConnectorNonEmpty(title, "title")
        try requireExternalConnectorNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorNonEmpty(notes, "notes")
        try requireExternalConnectorNonEmptyList(assumptions, "assumptions")
        try requireExternalConnectorNonEmptyEvidenceClasses(observedEvidenceClasses, "observedEvidenceClasses")
        try validateConnectors()

        if realWorldVerdict == .pass {
            throw ExternalConnectorValidationError.realWorldPassNotAllowed
        }
        if realWorldVerdict != .pass {
            try requireExternalConnectorNonEmptyEvidenceClasses(
                missingEvidenceClassesForRealWorldPass,
                "missingEvidenceClassesForRealWorldPass"
            )
        }
        if sourceLevelVerdict == .pass {
            guard connectors.allSatisfy(\.sourceContractImplemented) else {
                throw ExternalConnectorValidationError.sourcePassWithoutImplementedContract("connectors")
            }
        }
        if verdict == .pass {
            guard sourceLevelVerdict == .pass else {
                throw ExternalConnectorValidationError.sourcePassWithoutImplementedContract("report")
            }
            guard realWorldVerdict == .pass else {
                throw ExternalConnectorValidationError.realWorldPassNotAllowed
            }
        }
    }

    private func validateConnectors() throws {
        guard !connectors.isEmpty else {
            throw ExternalConnectorValidationError.emptyList("connectors")
        }

        var seen = Set<ExternalConnectorKind>()
        for connector in connectors {
            try validate(connector)
            guard seen.insert(connector.connector).inserted else {
                throw ExternalConnectorValidationError.duplicateConnector(connector.connector.rawValue)
            }
        }
        for requiredConnector in ExternalConnectorKind.allCases where !seen.contains(requiredConnector) {
            throw ExternalConnectorValidationError.missingConnector(requiredConnector.rawValue)
        }
    }

    private func validate(_ connector: ExternalConnectorContract) throws {
        try requireExternalConnectorNonEmpty(connector.id, "connectors.id")
        try requireExternalConnectorNonEmpty(connector.title, "connectors.title")
        try requireExternalConnectorNonEmpty(connector.publicReference, "connectors.publicReference")
        try requireExternalConnectorNonEmpty(connector.cleanRoomBoundary, "connectors.cleanRoomBoundary")
        try requireExternalConnectorNonEmpty(connector.notes, "connectors.notes")
        try requireExternalConnectorNonEmptyList(
            connector.requiredEvidenceForRealWorldPass,
            "connectors.requiredEvidenceForRealWorldPass"
        )
        guard connector.preservesDefaultAudioFirstPath else {
            throw ExternalConnectorValidationError.audioFirstPathRisk(connector.connector.rawValue)
        }
        guard !connector.defaultEnabled else {
            throw ExternalConnectorValidationError.defaultEnabled(connector.connector.rawValue)
        }
        guard !connector.realWorldInteroperabilityClaimed else {
            throw ExternalConnectorValidationError.realWorldClaimWithoutEvidence(connector.connector.rawValue)
        }
    }
}

private func requireExternalConnectorNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, empty: ExternalConnectorValidationError.emptyField)
}

private func requireExternalConnectorNonEmptyList(_ values: [String], _ field: String) throws {
    try ValidationPrimitives.requireNonEmptyStrings(
        values,
        field: field,
        emptyField: ExternalConnectorValidationError.emptyField,
        emptyList: ExternalConnectorValidationError.emptyList
    )
}

private func requireExternalConnectorNonEmptyEvidenceClasses(
    _ values: [ExternalConnectorEvidenceClass],
    _ field: String
) throws {
    guard !values.isEmpty else {
        throw ExternalConnectorValidationError.emptyList(field)
    }
}
