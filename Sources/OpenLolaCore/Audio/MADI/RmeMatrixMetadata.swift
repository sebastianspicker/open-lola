import Foundation

public enum RmeMatrixMetadataProviderKind: String, Codable, Equatable, Sendable {
    case coreAudioOnly
    case documentedTotalMixOscOrMidi
    case userProvidedSnapshot
    case unavailable
}

public enum RmeMatrixMetadataConfidence: String, Codable, Equatable, Sendable {
    case highForChannelOrder
    case mediumUntilMeasured
    case operatorConfirmed
    case unavailable
}

public struct RmeMatrixRouteMetadata: Codable, Equatable, Sendable {
    public var sourceChannelIndex: Int
    public var destinationBusID: String
    public var gainDb: Double
    public var muted: Bool
    public var solo: Bool
    public var pan: Double
    public var stereoPairID: String?
    public var label: String

    public init(
        sourceChannelIndex: Int,
        destinationBusID: String,
        gainDb: Double,
        muted: Bool,
        solo: Bool,
        pan: Double,
        stereoPairID: String?,
        label: String
    ) {
        self.sourceChannelIndex = sourceChannelIndex
        self.destinationBusID = destinationBusID
        self.gainDb = gainDb
        self.muted = muted
        self.solo = solo
        self.pan = pan
        self.stereoPairID = stereoPairID
        self.label = label
    }
}

public enum RmeMatrixMetadataValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case negativeRevision(Int)
    case negativeSourceChannelIndex(Int)
    case nonFiniteGain(Double)
    case panOutOfRange(Double)
    case unavailableProviderCarriesMetadata
    case unavailableProviderWrongConfidence(RmeMatrixMetadataConfidence)
    case availableProviderWithoutMetadata(RmeMatrixMetadataProviderKind)
}

let rmeMatrixPanTolerance = 1e-10

public struct RmeMatrixMetadataSnapshot: Codable, Equatable, Sendable {
    public var snapshotID: String
    public var provider: RmeMatrixMetadataProviderKind
    public var revision: Int
    public var capturedAt: String
    public var legalBasis: String
    public var confidence: RmeMatrixMetadataConfidence
    public var channels: [AudioChannelDescriptor]
    public var routes: [RmeMatrixRouteMetadata]
    public var notes: String

    public var requiresMetadataForPlayback: Bool {
        false
    }

    public init(
        snapshotID: String,
        provider: RmeMatrixMetadataProviderKind,
        revision: Int,
        capturedAt: String,
        legalBasis: String,
        confidence: RmeMatrixMetadataConfidence,
        channels: [AudioChannelDescriptor],
        routes: [RmeMatrixRouteMetadata],
        notes: String
    ) {
        self.snapshotID = snapshotID
        self.provider = provider
        self.revision = revision
        self.capturedAt = capturedAt
        self.legalBasis = legalBasis
        self.confidence = confidence
        self.channels = channels
        self.routes = routes
        self.notes = notes
    }

    public static func unavailable(
        revision: Int,
        capturedAt: String,
        notes: String
    ) -> RmeMatrixMetadataSnapshot {
        RmeMatrixMetadataSnapshot(
            snapshotID: "unavailable",
            provider: .unavailable,
            revision: revision,
            capturedAt: capturedAt,
            legalBasis: "metadata unavailable",
            confidence: .unavailable,
            channels: [],
            routes: [],
            notes: notes
        )
    }

    public func validate() throws {
        try requireNonEmpty(snapshotID, "snapshotID")
        try requireNonEmpty(capturedAt, "capturedAt")
        try requireNonEmpty(legalBasis, "legalBasis")
        try requireNonEmpty(notes, "notes")
        guard revision >= 0 else {
            throw RmeMatrixMetadataValidationError.negativeRevision(revision)
        }

        switch provider {
        case .unavailable:
            guard confidence == .unavailable else {
                throw RmeMatrixMetadataValidationError.unavailableProviderWrongConfidence(confidence)
            }
            guard channels.isEmpty, routes.isEmpty else {
                throw RmeMatrixMetadataValidationError.unavailableProviderCarriesMetadata
            }
        case .coreAudioOnly, .documentedTotalMixOscOrMidi, .userProvidedSnapshot:
            guard !channels.isEmpty || !routes.isEmpty else {
                throw RmeMatrixMetadataValidationError.availableProviderWithoutMetadata(provider)
            }
        }

        for channel in channels {
            if channel.stableSourceIndex < 0 {
                throw RmeMatrixMetadataValidationError.negativeSourceChannelIndex(
                    channel.stableSourceIndex
                )
            }
            try requireNonEmpty(channel.label, "channels.label")
        }
        for route in routes {
            try validateRoute(route)
        }
    }

    private func validateRoute(_ route: RmeMatrixRouteMetadata) throws {
        if route.sourceChannelIndex < 0 {
            throw RmeMatrixMetadataValidationError.negativeSourceChannelIndex(
                route.sourceChannelIndex
            )
        }
        try requireNonEmpty(route.destinationBusID, "routes.destinationBusID")
        try requireNonEmpty(route.label, "routes.label")
        guard route.gainDb.isFinite else {
            throw RmeMatrixMetadataValidationError.nonFiniteGain(route.gainDb)
        }
        guard route.pan >= -1.0 - rmeMatrixPanTolerance,
              route.pan <= 1.0 + rmeMatrixPanTolerance else {
            throw RmeMatrixMetadataValidationError.panOutOfRange(route.pan)
        }
    }

    private func requireNonEmpty(_ value: String, _ field: String) throws {
        if value.isEmpty {
            throw RmeMatrixMetadataValidationError.emptyField(field)
        }
    }
}

public enum RmeMatrixMetadataControlDecision: Equatable, Sendable {
    case accepted(revision: Int)
    case rateLimited(revision: Int, nextAllowedNanoseconds: UInt64)
    case staleOrDuplicate(revision: Int)
}

public struct RmeMatrixMetadataControlState: Sendable {
    public var minUpdateIntervalNanoseconds: UInt64
    public private(set) var lastAcceptedRevision: Int?
    public private(set) var lastSentNanoseconds: UInt64?

    public init(minUpdateIntervalNanoseconds: UInt64) {
        self.minUpdateIntervalNanoseconds = minUpdateIntervalNanoseconds
    }

    public mutating func record(
        _ snapshot: RmeMatrixMetadataSnapshot,
        nowNanoseconds: UInt64
    ) -> RmeMatrixMetadataControlDecision {
        if let lastAcceptedRevision, snapshot.revision <= lastAcceptedRevision {
            return .staleOrDuplicate(revision: snapshot.revision)
        }
        if let lastSentNanoseconds {
            let nextAllowed = lastSentNanoseconds + minUpdateIntervalNanoseconds
            if nowNanoseconds < nextAllowed {
                return .rateLimited(
                    revision: snapshot.revision,
                    nextAllowedNanoseconds: nextAllowed
                )
            }
        }

        lastAcceptedRevision = snapshot.revision
        lastSentNanoseconds = nowNanoseconds
        return .accepted(revision: snapshot.revision)
    }
}
