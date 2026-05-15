import Foundation

public enum LatencyBenchmarkRunMode: String, Codable, Equatable, Sendable {
    case synthetic
    case builtInDevice
    case sandboxLimited
    case measured
}

public enum LatencyBenchmarkEvidenceKind: String, Codable, Equatable, Sendable {
    case synthetic
    case builtInDevice
    case sandboxLimited
    case physicalReferenceRig
}

public enum LatencyBenchmarkCategory: String, Codable, Equatable, Sendable {
    case sourceValidation
    case endpointLoopback
    case directPeerToPeer
    case integratedAudioVideo
    case fieldTest
}

public enum LatencyMediaDomain: String, Codable, Equatable, Sendable {
    case audio
    case video
    case lighting
    case integrated
}

public enum LatencyComponentCriticality: String, Codable, Equatable, Sendable {
    case criticalPath
    case nearCriticalPath
    case offCriticalPath
    case optional
    case debugOnly
}

public enum LatencyBenchmarkValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError {
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

public struct LatencyJitterMetrics: Codable, Equatable, Sendable {
    public var p50Microseconds: Double
    public var p95Microseconds: Double
    public var p99Microseconds: Double
    public var maxMicroseconds: Double

    public init(
        p50Microseconds: Double,
        p95Microseconds: Double,
        p99Microseconds: Double,
        maxMicroseconds: Double
    ) {
        self.p50Microseconds = p50Microseconds
        self.p95Microseconds = p95Microseconds
        self.p99Microseconds = p99Microseconds
        self.maxMicroseconds = maxMicroseconds
    }
}

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

public struct LatencyBenchmarkWarning: Codable, Equatable, Sendable {
    public var field: String
    public var message: String

    public init(field: String, message: String) {
        self.field = field
        self.message = message
    }
}

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

public struct LatencyBenchmarkThresholds: Codable, Equatable, Sendable {
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
        budgetDocument: String,
        oneWayTargetMicroseconds: Double,
        roundTripTargetMicroseconds: Double,
        jitterP99MaxMicroseconds: Double,
        packetLossMaxPercent: Double,
        cpuP99MaxPercent: Double,
        underrunMaxCount: Int,
        droppedFrameMaxCount: Int,
        allocationWarningMaxCount: Int,
        threadWarningMaxCount: Int
    ) {
        self.budgetDocument = budgetDocument
        self.oneWayTargetMicroseconds = oneWayTargetMicroseconds
        self.roundTripTargetMicroseconds = roundTripTargetMicroseconds
        self.jitterP99MaxMicroseconds = jitterP99MaxMicroseconds
        self.packetLossMaxPercent = packetLossMaxPercent
        self.cpuP99MaxPercent = cpuP99MaxPercent
        self.underrunMaxCount = underrunMaxCount
        self.droppedFrameMaxCount = droppedFrameMaxCount
        self.allocationWarningMaxCount = allocationWarningMaxCount
        self.threadWarningMaxCount = threadWarningMaxCount
    }
}

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
