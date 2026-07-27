// Compares candidate latency metrics with an explicitly sourced LoLa baseline while preserving unavailable and incomparable outcomes.
import Foundation

/// Defines the finite structured result values recorded by LoLa baseline comparison artifacts for deterministic validation and report interpretation.
public enum LolaBaselineAvailability: String, Codable, Equatable, Sendable {
    case measured
    case unavailable
}

/// Defines the finite structured result values recorded by LoLa baseline comparison artifacts for deterministic validation and report interpretation.
public enum LolaBaselineMeasurementMethod: String, Codable, Equatable, Sendable {
    case oneWayAnalogLoopback
    case roundTripAnalogLoopback
}

/// Defines the finite operation result values recorded by LoLa baseline comparison artifacts for deterministic validation and report interpretation.
public enum LolaBaselineComparisonResult: String, Codable, Equatable, Sendable {
    case openLolaFaster
    case openLolaEquivalent
    case openLolaSlower
    case unavailable
}

/// Captures measured metrics required to validate, interpret, and reproduce a LoLa baseline comparison result.
public struct LolaBaselineLatencyMetrics: Codable, Equatable, Sendable {
    public var p50Milliseconds: Double
    public var p95Milliseconds: Double
    public var p99Milliseconds: Double
    public var maxMilliseconds: Double

    public init(
        p50Milliseconds: Double,
        p95Milliseconds: Double,
        p99Milliseconds: Double,
        maxMilliseconds: Double
    ) {
        self.p50Milliseconds = p50Milliseconds
        self.p95Milliseconds = p95Milliseconds
        self.p99Milliseconds = p99Milliseconds
        self.maxMilliseconds = maxMilliseconds
    }
}

/// Describes failures that prevent LoLa baseline comparison inputs or evidence from satisfying the required validation invariants.
public enum LolaBaselineComparisonValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedLatencyMetrics
    case unavailableWithoutReason
    case measuredWithUnavailableResult
}

/// Captures structured result required to validate, interpret, and reproduce a LoLa baseline comparison result.
public struct LolaBaselineComparison: Codable, Equatable, Sendable {
    public struct Setup: Sendable {
        public let availability: LolaBaselineAvailability
        public let lolaVersion: String
        public let lolaSettings: String
        public let audioInterface: String
        public let route: RouteIdentity
        public let packetMode: UdpPcmPacketMode
        public let measurementMethod: LolaBaselineMeasurementMethod

        public init(
            availability: LolaBaselineAvailability,
            lolaVersion: String,
            lolaSettings: String,
            audioInterface: String,
            route: RouteIdentity,
            packetMode: UdpPcmPacketMode,
            measurementMethod: LolaBaselineMeasurementMethod
        ) {
            self.availability = availability
            self.lolaVersion = lolaVersion
            self.lolaSettings = lolaSettings
            self.audioInterface = audioInterface
            self.route = route
            self.packetMode = packetMode
            self.measurementMethod = measurementMethod
        }
    }

    public struct Measurements: Sendable {
        public let latency: LolaBaselineLatencyMetrics
        public let lostPackets: Int
        public let latePackets: Int
        public let underruns: Int

        public init(
            latency: LolaBaselineLatencyMetrics,
            lostPackets: Int,
            latePackets: Int,
            underruns: Int
        ) {
            self.latency = latency
            self.lostPackets = lostPackets
            self.latePackets = latePackets
            self.underruns = underruns
        }
    }

    public struct Evidence: Sendable {
        public let artifactNotes: String
        public let measuredOnSameHardwareAndRoute: Bool

        public init(artifactNotes: String, measuredOnSameHardwareAndRoute: Bool) {
            self.artifactNotes = artifactNotes
            self.measuredOnSameHardwareAndRoute = measuredOnSameHardwareAndRoute
        }
    }

    public struct Outcome: Sendable {
        public let result: LolaBaselineComparisonResult
        public let notTestedReason: String?

        public init(result: LolaBaselineComparisonResult, notTestedReason: String?) {
            self.result = result
            self.notTestedReason = notTestedReason
        }
    }

    public var availability: LolaBaselineAvailability
    public var lolaVersion: String
    public var lolaSettings: String
    public var audioInterface: String
    public var route: RouteIdentity
    public var packetMode: UdpPcmPacketMode
    public var measurementMethod: LolaBaselineMeasurementMethod
    public var latency: LolaBaselineLatencyMetrics
    public var lostPackets: Int
    public var latePackets: Int
    public var underruns: Int
    public var artifactNotes: String
    public var measuredOnSameHardwareAndRoute: Bool
    public var result: LolaBaselineComparisonResult
    public var notTestedReason: String?

    public init(
        setup: Setup,
        measurements: Measurements,
        evidence: Evidence,
        outcome: Outcome
    ) {
        self.availability = setup.availability
        self.lolaVersion = setup.lolaVersion
        self.lolaSettings = setup.lolaSettings
        self.audioInterface = setup.audioInterface
        self.route = setup.route
        self.packetMode = setup.packetMode
        self.measurementMethod = setup.measurementMethod
        self.latency = measurements.latency
        self.lostPackets = measurements.lostPackets
        self.latePackets = measurements.latePackets
        self.underruns = measurements.underruns
        self.artifactNotes = evidence.artifactNotes
        self.measuredOnSameHardwareAndRoute = evidence.measuredOnSameHardwareAndRoute
        self.result = outcome.result
        self.notTestedReason = outcome.notTestedReason
    }

    public func validate() throws {
        try LolaBaselineComparisonValidator.requireNonEmpty(lolaVersion, "lolaVersion")
        try LolaBaselineComparisonValidator.requireNonEmpty(lolaSettings, "lolaSettings")
        try LolaBaselineComparisonValidator.requireNonEmpty(audioInterface, "audioInterface")
        try LolaBaselineComparisonValidator.requireNonEmpty(route.label, "route.label")
        try LolaBaselineComparisonValidator.requireNonEmpty(route.topology, "route.topology")
        try LolaBaselineComparisonValidator.requirePositive(packetMode.sampleRateHertz, "packetMode.sampleRateHertz")
        try LolaBaselineComparisonValidator.requirePositive(packetMode.framesPerPacket, "packetMode.framesPerPacket")
        try LolaBaselineComparisonValidator.requirePositive(packetMode.channelCount, "packetMode.channelCount")
        try LolaBaselineComparisonValidator.requirePositive(latency.p50Milliseconds, "latency.p50Milliseconds")
        try LolaBaselineComparisonValidator.requirePositive(latency.p95Milliseconds, "latency.p95Milliseconds")
        try LolaBaselineComparisonValidator.requirePositive(latency.p99Milliseconds, "latency.p99Milliseconds")
        try LolaBaselineComparisonValidator.requirePositive(latency.maxMilliseconds, "latency.maxMilliseconds")
        try LolaBaselineComparisonValidator.requireNonNegative(lostPackets, "lostPackets")
        try LolaBaselineComparisonValidator.requireNonNegative(latePackets, "latePackets")
        try LolaBaselineComparisonValidator.requireNonNegative(underruns, "underruns")
        try LolaBaselineComparisonValidator.requireNonEmpty(artifactNotes, "artifactNotes")

        guard timingPercentilesAreOrdered(
            p50: latency.p50Milliseconds,
            p95: latency.p95Milliseconds,
            p99: latency.p99Milliseconds,
            max: latency.maxMilliseconds
        ) else {
            throw LolaBaselineComparisonValidationError.unorderedLatencyMetrics
        }

        if availability == .unavailable {
            guard notTestedReason?.isEmpty == false else {
                throw LolaBaselineComparisonValidationError.unavailableWithoutReason
            }
            return
        }

        guard result != .unavailable else {
            throw LolaBaselineComparisonValidationError.measuredWithUnavailableResult
        }
    }
}
