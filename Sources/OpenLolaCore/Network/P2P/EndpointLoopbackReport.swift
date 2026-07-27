// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Represents EndpointLoopbackDevice values used by direct peer sessions.
public struct EndpointLoopbackDevice: Codable, Equatable, Sendable {
    public var name: String
    public var uid: String
    public var transportType: String
    public var clockDomain: UInt32?

    public init(
        name: String,
        uid: String,
        transportType: String,
        clockDomain: UInt32?
    ) {
        self.name = name
        self.uid = uid
        self.transportType = transportType
        self.clockDomain = clockDomain
    }
}

/// Represents the EndpointCallbackMetrics produced by direct peer sessions without exposing its execution state.
public struct EndpointCallbackMetrics: Codable, Equatable, Sendable, LatencyPercentileValuesProviding {
    public typealias Latency = LatencyPercentileMetrics<EndpointCallbackMetrics>

    public struct Events: Equatable, Sendable {
        public var missedDeadlines: Int
        public var underruns: Int
        public var overruns: Int

        public init(missedDeadlines: Int, underruns: Int, overruns: Int) {
            self.missedDeadlines = missedDeadlines
            self.underruns = underruns
            self.overruns = overruns
        }
    }

    public struct Sampling: Equatable, Sendable {
        public var recordedIntervalSamples: Int
        public var droppedIntervalSamples: Int
        public var hostTimeConversionFailures: Int

        public init(recordedIntervalSamples: Int = 0, droppedIntervalSamples: Int = 0, hostTimeConversionFailures: Int = 0) {
            self.recordedIntervalSamples = recordedIntervalSamples
            self.droppedIntervalSamples = droppedIntervalSamples
            self.hostTimeConversionFailures = hostTimeConversionFailures
        }
    }
    public var p50Microseconds: Double
    public var p95Microseconds: Double
    public var p99Microseconds: Double
    public var maxMicroseconds: Double
    public var missedDeadlines: Int
    public var underruns: Int
    public var overruns: Int
    public var recordedIntervalSamples: Int
    public var droppedIntervalSamples: Int
    public var hostTimeConversionFailures: Int

    public init(latency: Latency, events: Events, sampling: Sampling = .init()) {
        self.p50Microseconds = latency.p50Microseconds
        self.p95Microseconds = latency.p95Microseconds
        self.p99Microseconds = latency.p99Microseconds
        self.maxMicroseconds = latency.maxMicroseconds
        self.missedDeadlines = events.missedDeadlines
        self.underruns = events.underruns
        self.overruns = events.overruns
        self.recordedIntervalSamples = sampling.recordedIntervalSamples
        self.droppedIntervalSamples = sampling.droppedIntervalSamples
        self.hostTimeConversionFailures = sampling.hostTimeConversionFailures
    }

    private enum CodingKeys: String, CodingKey, LatencyPercentileCodingKeys {
        case p50Microseconds
        case p95Microseconds
        case p99Microseconds
        case maxMicroseconds
        case missedDeadlines
        case underruns
        case overruns
        case recordedIntervalSamples
        case droppedIntervalSamples
        case hostTimeConversionFailures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let percentiles = try decodeLatencyPercentiles(from: container)
        self.p50Microseconds = percentiles.p50Microseconds
        self.p95Microseconds = percentiles.p95Microseconds
        self.p99Microseconds = percentiles.p99Microseconds
        self.maxMicroseconds = percentiles.maxMicroseconds
        self.missedDeadlines = try container.decode(Int.self, forKey: .missedDeadlines)
        self.underruns = try container.decode(Int.self, forKey: .underruns)
        self.overruns = try container.decode(Int.self, forKey: .overruns)
        self.recordedIntervalSamples = try container.decodeIfPresent(
            Int.self,
            forKey: .recordedIntervalSamples
        ) ?? 0
        self.droppedIntervalSamples = try container.decodeIfPresent(
            Int.self,
            forKey: .droppedIntervalSamples
        ) ?? 0
        self.hostTimeConversionFailures = try container.decodeIfPresent(
            Int.self,
            forKey: .hostTimeConversionFailures
        ) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try encodeLatencyPercentiles(self, to: &container)
        try container.encode(missedDeadlines, forKey: .missedDeadlines)
        try container.encode(underruns, forKey: .underruns)
        try container.encode(overruns, forKey: .overruns)
        try container.encode(recordedIntervalSamples, forKey: .recordedIntervalSamples)
        try container.encode(droppedIntervalSamples, forKey: .droppedIntervalSamples)
        try container.encode(hostTimeConversionFailures, forKey: .hostTimeConversionFailures)
    }
}

/// Represents the EndpointLoopbackMetrics produced by direct peer sessions without exposing its execution state.
public struct EndpointLoopbackMetrics: Codable, Equatable, Sendable {
    public var reportedInputLatencyFrames: Int
    public var reportedOutputLatencyFrames: Int
    public var inputSafetyOffsetFrames: Int
    public var outputSafetyOffsetFrames: Int
    public var measuredAnalogRoundTripMilliseconds: Double
    public var correctedOneWayMilliseconds: Double
    public var hiddenBufferGrowthDetected: Bool

    public init(
        reportedInputLatencyFrames: Int,
        reportedOutputLatencyFrames: Int,
        inputSafetyOffsetFrames: Int,
        outputSafetyOffsetFrames: Int,
        measuredAnalogRoundTripMilliseconds: Double,
        correctedOneWayMilliseconds: Double,
        hiddenBufferGrowthDetected: Bool
    ) {
        self.reportedInputLatencyFrames = reportedInputLatencyFrames
        self.reportedOutputLatencyFrames = reportedOutputLatencyFrames
        self.inputSafetyOffsetFrames = inputSafetyOffsetFrames
        self.outputSafetyOffsetFrames = outputSafetyOffsetFrames
        self.measuredAnalogRoundTripMilliseconds = measuredAnalogRoundTripMilliseconds
        self.correctedOneWayMilliseconds = correctedOneWayMilliseconds
        self.hiddenBufferGrowthDetected = hiddenBufferGrowthDetected
    }
}

/// Represents the EndpointModeResult produced by direct peer sessions without exposing its execution state.
public struct EndpointModeResult: Codable, Equatable, Sendable {
    public var mode: AudioMode
    public var accepted: Bool
    public var stable: Bool
    public var rejectionReason: String?
    public var callback: EndpointCallbackMetrics?
    public var loopback: EndpointLoopbackMetrics?
    public var notes: String

    public init(
        mode: AudioMode,
        accepted: Bool,
        stable: Bool,
        rejectionReason: String?,
        callback: EndpointCallbackMetrics?,
        loopback: EndpointLoopbackMetrics?,
        notes: String
    ) {
        self.mode = mode
        self.accepted = accepted
        self.stable = stable
        self.rejectionReason = rejectionReason
        self.callback = callback
        self.loopback = loopback
        self.notes = notes
    }
}

/// Represents the SampleRateLoopbackResult produced by direct peer sessions without exposing its execution state.
public struct SampleRateLoopbackResult: Codable, Equatable, Sendable {
    public var sampleRateHertz: Int
    public var supported: Bool
    public var unsupportedReason: String?
    public var modeResults: [EndpointModeResult]

    public init(
        sampleRateHertz: Int,
        supported: Bool,
        unsupportedReason: String?,
        modeResults: [EndpointModeResult]
    ) {
        self.sampleRateHertz = sampleRateHertz
        self.supported = supported
        self.unsupportedReason = unsupportedReason
        self.modeResults = modeResults
    }
}

/// Runs EndpointStabilityRun while keeping its stateful execution separate from report validation.
public struct EndpointStabilityRun: Codable, Equatable, Sendable {
    public var mode: AudioMode
    public var durationSeconds: Int
    public var callback: EndpointCallbackMetrics
    public var dropoutEvents: Int
    public var hiddenBufferGrowthDetected: Bool
    public var notes: String

    public init(
        mode: AudioMode,
        durationSeconds: Int,
        callback: EndpointCallbackMetrics,
        dropoutEvents: Int,
        hiddenBufferGrowthDetected: Bool,
        notes: String
    ) {
        self.mode = mode
        self.durationSeconds = durationSeconds
        self.callback = callback
        self.dropoutEvents = dropoutEvents
        self.hiddenBufferGrowthDetected = hiddenBufferGrowthDetected
        self.notes = notes
    }
}

/// Enumerates failures that callers must handle when working with direct peer sessions.
public enum EndpointLoopbackValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case unorderedCallbackMetrics
    case missingRequiredSampleRate(Int)
    case duplicateSampleRate(Int)
    case unsupportedSampleRateMissingReason(Int)
    case supportedSampleRateMissingModes(Int)
    case modeSampleRateMismatch(expected: Int, actual: Int)
    case duplicateFrameSize(sampleRateHertz: Int, framesPerBuffer: Int)
    case missingRequiredFrameSize(sampleRateHertz: Int, framesPerBuffer: Int)
    case acceptedModeMissingCallbackMetrics(sampleRateHertz: Int, framesPerBuffer: Int)
    case acceptedModeMissingLoopbackMetrics(sampleRateHertz: Int, framesPerBuffer: Int)
    case rejectedModeMissingReason(sampleRateHertz: Int, framesPerBuffer: Int)
    case rejectedModeMarkedStable(sampleRateHertz: Int, framesPerBuffer: Int)
    case selectedModeNotAccepted
    case selectedModeNotStable
    case stabilityModeMismatch
    case stabilityRunTooShort(seconds: Int)
    case eightFrameStabilityRunTooShort(seconds: Int, minimumSeconds: Int)
    case dropoutEventsDetected(Int)
    case hiddenBufferGrowthDetected
}

/// Captures EndpointLoopbackReport evidence in a stable form for validation and serialized reporting.
public struct EndpointLoopbackReport: ReportValidatingArtifact, Codable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable { public var id: String; public var title: String; public var capturedAt: String; public init(id: String, title: String, capturedAt: String) { self.id = id; self.title = title; self.capturedAt = capturedAt } }
    public struct Context: Equatable, Sendable { public var hardware: HardwareIdentity; public var route: RouteIdentity; public var device: EndpointLoopbackDevice; public var selectedMode: AudioMode; public var sampleRates: [SampleRateLoopbackResult]; public var stabilityRun: EndpointStabilityRun; public init(hardware: HardwareIdentity, route: RouteIdentity, device: EndpointLoopbackDevice, selectedMode: AudioMode, sampleRates: [SampleRateLoopbackResult], stabilityRun: EndpointStabilityRun) { self.hardware = hardware; self.route = route; self.device = device; self.selectedMode = selectedMode; self.sampleRates = sampleRates; self.stabilityRun = stabilityRun } }
    public struct Outcome: Equatable, Sendable { public var verdict: MeasurementVerdict; public var notes: String; public init(verdict: MeasurementVerdict, notes: String) { self.verdict = verdict; self.notes = notes } }
    public static let requiredSampleRates = [48_000, 96_000, 192_000]
    public static let requiredFrameSizes = [8, 16, 32, 64, 128]
    public static let minimumStabilityDurationSeconds = 1_800
    public static let minimumExtremeLowLatencyDurationSeconds = 7_200

    public var id: String
    public var title: String
    public var capturedAt: String
    public var hardware: HardwareIdentity
    public var route: RouteIdentity
    public var device: EndpointLoopbackDevice
    public var selectedMode: AudioMode
    public var sampleRates: [SampleRateLoopbackResult]
    public var stabilityRun: EndpointStabilityRun
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(identity: Identity, context: Context, outcome: Outcome) {
        self.id = identity.id; self.title = identity.title; self.capturedAt = identity.capturedAt
        self.hardware = context.hardware; self.route = context.route; self.device = context.device; self.selectedMode = context.selectedMode; self.sampleRates = context.sampleRates; self.stabilityRun = context.stabilityRun
        self.verdict = outcome.verdict; self.notes = outcome.notes
    }

}
