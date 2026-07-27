// Declares latency measurement configuration and value types with input checks so parsers, runners, and tests apply the same invariants.
import Foundation

/// Defines the finite operating mode values recorded by latency benchmark artifacts for deterministic validation and report interpretation.
public enum LatencyBenchmarkRunMode: String, Codable, Equatable, Sendable {
    case synthetic
    case builtInDevice
    case sandboxLimited
    case measured
}

/// Defines the finite evidence provenance values recorded by latency benchmark artifacts for deterministic validation and report interpretation.
public enum LatencyBenchmarkEvidenceKind: String, Codable, Equatable, Sendable {
    case synthetic
    case builtInDevice
    case sandboxLimited
    case physicalReferenceRig
}

/// Defines the finite classification values recorded by latency benchmark artifacts for deterministic validation and report interpretation.
public enum LatencyBenchmarkCategory: String, Codable, Equatable, Sendable {
    case sourceValidation
    case endpointLoopback
    case directPeerToPeer
    case integratedAudioVideo
    case fieldTest
}

/// Defines the finite structured result values recorded by latency benchmark artifacts for deterministic validation and report interpretation.
public enum LatencyMediaDomain: String, Codable, Equatable, Sendable {
    case audio
    case video
    case lighting
    case integrated
}

/// Defines the finite structured result values recorded by latency benchmark artifacts for deterministic validation and report interpretation.
public enum LatencyComponentCriticality: String, Codable, Equatable, Sendable {
    case criticalPath
    case nearCriticalPath
    case offCriticalPath
    case optional
    case debugOnly
}

/// Describes failures that prevent latency benchmark inputs or evidence from satisfying the required validation invariants.
public enum LatencyBenchmarkValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError,
    ValidationPercentOutOfRangeFieldError {
    case emptyField(String)
    case emptyList(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case percentOutOfRange(field: String, value: Double)
    case unorderedJitter
    case oneWayExceedsRoundTrip(oneWayMicroseconds: Double, roundTripMicroseconds: Double)
    case unorderedCpuMetrics
    case passWithoutMeasuredRun
    case passWithoutPhysicalReferenceRig
    case passWithoutLatencyBudgetReference(String)
    case passWithoutCriticalPathComponent
    case passWithoutMeasuredCriticalPathComponent(String)
    case passExceedsOneWayThreshold(value: Double, threshold: Double)
    case passExceedsRoundTripThreshold(value: Double, threshold: Double)
    case passExceedsJitterThreshold(value: Double, threshold: Double)
    case passExceedsLossThreshold(value: Double, threshold: Double)
    case passExceedsCpuThreshold(value: Double, threshold: Double)
    case passExceedsUnderrunThreshold(value: Int, threshold: Int)
    case passExceedsDroppedFrameThreshold(value: Int, threshold: Int)
    case passExceedsAllocationWarningThreshold(value: Int, threshold: Int)
    case passExceedsThreadWarningThreshold(value: Int, threshold: Int)
    case passWithFastestIneligibleRxBuffer(RxBufferProfile)
    case passWithHiddenRxBufferGrowth
    case passWithoutLowBufferProfileEvidence(LatencyProfile)
    case passWithFastestIneligibleSessionProfile(
        profile: SessionLatencyProfile,
        rxBufferProfile: RxBufferProfile
    )
}

/// Captures operating mode required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyVideoMode: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var nominalFrameRate: Double
    public var pixelFormat: String
    public var transport: String

    public init(
        width: Int,
        height: Int,
        nominalFrameRate: Double,
        pixelFormat: String,
        transport: String
    ) {
        self.width = width
        self.height = height
        self.nominalFrameRate = nominalFrameRate
        self.pixelFormat = pixelFormat
        self.transport = transport
    }
}

/// Captures operating mode required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyLightingMode: Codable, Equatable, Sendable {
    public var protocolName: String
    public var fixtureOrBridge: String
    public var cueRateHertz: Double

    public init(protocolName: String, fixtureOrBridge: String, cueRateHertz: Double) {
        self.protocolName = protocolName
        self.fixtureOrBridge = fixtureOrBridge
        self.cueRateHertz = cueRateHertz
    }
}

/// Captures operating mode required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyBenchmarkMediaMode: Codable, Equatable, Sendable {
    public var domain: LatencyMediaDomain
    public var audio: AudioMode?
    public var video: LatencyVideoMode?
    public var lighting: LatencyLightingMode?

    public init(
        domain: LatencyMediaDomain,
        audio: AudioMode?,
        video: LatencyVideoMode?,
        lighting: LatencyLightingMode?
    ) {
        self.domain = domain
        self.audio = audio
        self.video = video
        self.lighting = lighting
    }
}

/// Captures measured metrics required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyBenchmarkTimingMetrics: Codable, Equatable, Sendable {
    /// Estimated one-way latency in microseconds, derived from the benchmark's documented measurement path.
    /// This is not an independently clock-synchronized one-way measurement unless the report methodology says so.
    public var oneWayEstimateMicroseconds: Double
    /// Round-trip latency in microseconds from the same benchmark methodology used to derive the one-way estimate.
    /// Validation requires the estimate to stay within the round-trip value to catch inconsistent methodology.
    public var roundTripMicroseconds: Double
    public var jitter: LatencyJitterMetrics

    public init(
        oneWayEstimateMicroseconds: Double,
        roundTripMicroseconds: Double,
        jitter: LatencyJitterMetrics
    ) {
        self.oneWayEstimateMicroseconds = oneWayEstimateMicroseconds
        self.roundTripMicroseconds = roundTripMicroseconds
        self.jitter = jitter
    }
}

/// Captures measured metrics required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyBenchmarkLossMetrics: Codable, Equatable, Sendable {
    public var lostPackets: Int
    public var latePackets: Int
    public var lossPercent: Double

    public init(lostPackets: Int, latePackets: Int, lossPercent: Double) {
        self.lostPackets = lostPackets
        self.latePackets = latePackets
        self.lossPercent = lossPercent
    }
}

/// Captures measured metrics required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyBenchmarkFaultMetrics: Codable, Equatable, Sendable {
    public var underruns: Int
    public var overruns: Int
    public var missedDeadlines: Int
    public var droppedFrames: Int

    public init(
        underruns: Int,
        overruns: Int,
        missedDeadlines: Int,
        droppedFrames: Int
    ) {
        self.underruns = underruns
        self.overruns = overruns
        self.missedDeadlines = missedDeadlines
        self.droppedFrames = droppedFrames
    }
}

/// Captures reported warning required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyBenchmarkWarning: Codable, Equatable, Sendable {
    public var field: String
    public var message: String

    public init(field: String, message: String) {
        self.field = field
        self.message = message
    }
}

/// Captures measured metrics required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyBenchmarkResourceMetrics: Codable, Equatable, Sendable {
    public var cpuP50Percent: Double
    public var cpuP95Percent: Double
    public var cpuP99Percent: Double
    public var cpuMaxPercent: Double
    public var residentMemoryMegabytes: Double
    public var allocationWarnings: [LatencyBenchmarkWarning]
    public var threadWarnings: [LatencyBenchmarkWarning]

    public init(
        cpuP50Percent: Double,
        cpuP95Percent: Double,
        cpuP99Percent: Double,
        cpuMaxPercent: Double,
        residentMemoryMegabytes: Double,
        allocationWarnings: [LatencyBenchmarkWarning],
        threadWarnings: [LatencyBenchmarkWarning]
    ) {
        self.cpuP50Percent = cpuP50Percent
        self.cpuP95Percent = cpuP95Percent
        self.cpuP99Percent = cpuP99Percent
        self.cpuMaxPercent = cpuMaxPercent
        self.residentMemoryMegabytes = residentMemoryMegabytes
        self.allocationWarnings = allocationWarnings
        self.threadWarnings = threadWarnings
    }
}

/// Captures acceptance thresholds required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyBenchmarkThresholds: Codable, Equatable, Sendable {
    public struct Targets: Sendable {
        public let budgetDocument: String
        public let oneWayMicroseconds: Double
        public let roundTripMicroseconds: Double
        public let jitterP99MaxMicroseconds: Double
        public let packetLossMaxPercent: Double

        public init(
            budgetDocument: String,
            oneWayMicroseconds: Double,
            roundTripMicroseconds: Double,
            jitterP99MaxMicroseconds: Double,
            packetLossMaxPercent: Double
        ) {
            self.budgetDocument = budgetDocument
            self.oneWayMicroseconds = oneWayMicroseconds
            self.roundTripMicroseconds = roundTripMicroseconds
            self.jitterP99MaxMicroseconds = jitterP99MaxMicroseconds
            self.packetLossMaxPercent = packetLossMaxPercent
        }
    }

    public struct Limits: Sendable {
        public let cpuP99MaxPercent: Double
        public let underrunMaxCount: Int
        public let droppedFrameMaxCount: Int
        public let allocationWarningMaxCount: Int
        public let threadWarningMaxCount: Int

        public init(
            cpuP99MaxPercent: Double,
            underrunMaxCount: Int,
            droppedFrameMaxCount: Int,
            allocationWarningMaxCount: Int,
            threadWarningMaxCount: Int
        ) {
            self.cpuP99MaxPercent = cpuP99MaxPercent
            self.underrunMaxCount = underrunMaxCount
            self.droppedFrameMaxCount = droppedFrameMaxCount
            self.allocationWarningMaxCount = allocationWarningMaxCount
            self.threadWarningMaxCount = threadWarningMaxCount
        }
    }

    public var budgetDocument: String
    public var oneWayTargetMicroseconds: Double
    public var roundTripTargetMicroseconds: Double
    public var jitterP99MaxMicroseconds: Double
    public var packetLossMaxPercent: Double
    public var cpuP99MaxPercent: Double
    public var underrunMaxCount: Int
    public var droppedFrameMaxCount: Int
    public var allocationWarningMaxCount: Int
    public var threadWarningMaxCount: Int

    public init(
        targets: Targets,
        limits: Limits
    ) {
        self.budgetDocument = targets.budgetDocument
        self.oneWayTargetMicroseconds = targets.oneWayMicroseconds
        self.roundTripTargetMicroseconds = targets.roundTripMicroseconds
        self.jitterP99MaxMicroseconds = targets.jitterP99MaxMicroseconds
        self.packetLossMaxPercent = targets.packetLossMaxPercent
        self.cpuP99MaxPercent = limits.cpuP99MaxPercent
        self.underrunMaxCount = limits.underrunMaxCount
        self.droppedFrameMaxCount = limits.droppedFrameMaxCount
        self.allocationWarningMaxCount = limits.allocationWarningMaxCount
        self.threadWarningMaxCount = limits.threadWarningMaxCount
    }
}

/// Captures structured result required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyBudgetComponentMeasurement: Codable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var criticality: LatencyComponentCriticality
    public var budgetTargetMicroseconds: Double?
    public var measuredMicroseconds: Double?
    public var source: String

    public init(
        id: String,
        label: String,
        criticality: LatencyComponentCriticality,
        budgetTargetMicroseconds: Double?,
        measuredMicroseconds: Double?,
        source: String
    ) {
        self.id = id
        self.label = label
        self.criticality = criticality
        self.budgetTargetMicroseconds = budgetTargetMicroseconds
        self.measuredMicroseconds = measuredMicroseconds
        self.source = source
    }
}
