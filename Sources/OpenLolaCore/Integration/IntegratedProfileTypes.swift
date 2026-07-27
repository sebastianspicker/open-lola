// Defines integrated-profile labels, features, lanes, options, benchmarks, degradation, and validation.
import Foundation

/// Defines the supported choices for integrated profile label.
public enum IntegratedProfileLabel: String, Codable, Equatable, Hashable, Sendable {
    case fastestAudio = "fastest-audio"
    case audioVideo = "audio-video"
    case audioLighting = "audio-lighting"
    case audioVideoLighting = "audio-video-lighting"
}

/// Identifies optional video or lighting-control capability in an integrated profile.
public enum IntegratedProfileFeature: String, Codable, Equatable, Hashable, Sendable {
    case video
    case lightingControl = "lighting-control"
}

/// Defines the supported choices for integrated profile subordinate lane.
public enum IntegratedProfileSubordinateLane: String, Codable, Equatable, Hashable, Sendable {
    case fastestAudio
    case audioRoute
    case videoCapture
    case videoTransport
    case integratedAv
    case lightingControl
}

/// Defines the supported choices for integrated profile benchmark scenario.
public enum IntegratedProfileBenchmarkScenario: String, Codable, Equatable, Hashable, Sendable {
    case audioOnly
    case audioVideo
    case audioControl
    case audioVideoControl
}

/// Defines the supported choices for integrated profile degradation step.
public enum IntegratedProfileDegradationStep: String, Codable, Equatable, Hashable, Sendable {
    case reduceVideoQuality
    case reduceVideoFrameRate
    case disableLighting
    case disableVideo
    case increaseAudioLatency
}

/// Defines the validated fields for integrated profile option.
public struct IntegratedProfileOption: Codable, Equatable, Sendable {
    public var label: IntegratedProfileLabel
    public var features: [IntegratedProfileFeature]
    public var defaultProfile: Bool
    public var latencyCostMicroseconds: Double
    public var sourceReportId: String
    public var costReportId: String
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        label: IntegratedProfileLabel,
        features: [IntegratedProfileFeature],
        defaultProfile: Bool,
        latencyCostMicroseconds: Double,
        sourceReportId: String,
        costReportId: String,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.label = label
        self.features = features
        self.defaultProfile = defaultProfile
        self.latencyCostMicroseconds = latencyCostMicroseconds
        self.sourceReportId = sourceReportId
        self.costReportId = costReportId
        self.verdict = verdict
        self.notes = notes
    }
}

/// Records the evidence and outcome for integrated profile subordinate evidence.
public struct IntegratedProfileSubordinateEvidence: Codable, Equatable, Sendable {
    public var lane: IntegratedProfileSubordinateLane
    public var reportId: String
    public var verdict: MeasurementVerdict
    public var measured: Bool
    public var physicalPassEvidence: Bool
    public var notes: String

    public init(
        lane: IntegratedProfileSubordinateLane,
        reportId: String,
        verdict: MeasurementVerdict,
        measured: Bool,
        physicalPassEvidence: Bool,
        notes: String
    ) {
        self.lane = lane
        self.reportId = reportId
        self.verdict = verdict
        self.measured = measured
        self.physicalPassEvidence = physicalPassEvidence
        self.notes = notes
    }
}

/// Records the evidence and outcome for integrated profile benchmark metrics.
public struct IntegratedProfileBenchmarkMetrics: Codable, Equatable, Sendable {
    public struct Audio: Sendable {
        public let latencyP99Microseconds: Double
        public let jitterP99Microseconds: Double
        public let lostPackets: Int
        public let latePackets: Int
        public let underruns: Int

        public init(
            latencyP99Microseconds: Double,
            jitterP99Microseconds: Double,
            lostPackets: Int,
            latePackets: Int,
            underruns: Int
        ) {
            self.latencyP99Microseconds = latencyP99Microseconds
            self.jitterP99Microseconds = jitterP99Microseconds
            self.lostPackets = lostPackets
            self.latePackets = latePackets
            self.underruns = underruns
        }
    }

    public struct VideoControl: Sendable {
        public let droppedVideoFrames: Int
        public let cueTimingP99Microseconds: Double

        public init(droppedVideoFrames: Int, cueTimingP99Microseconds: Double) {
            self.droppedVideoFrames = droppedVideoFrames
            self.cueTimingP99Microseconds = cueTimingP99Microseconds
        }
    }

    public struct Resources: Sendable {
        public let cpuP99Percent: Double
        public let residentMemoryMegabytes: Double
        public let measurementDurationSeconds: Double?
        public let durationMismatch: Bool

        public init(
            cpuP99Percent: Double,
            residentMemoryMegabytes: Double,
            measurementDurationSeconds: Double? = nil,
            durationMismatch: Bool = false
        ) {
            self.cpuP99Percent = cpuP99Percent
            self.residentMemoryMegabytes = residentMemoryMegabytes
            self.measurementDurationSeconds = measurementDurationSeconds
            self.durationMismatch = durationMismatch
        }
    }

    public struct Warnings: Sendable {
        public let callbackDeadlines: Int
        public let allocations: Int
        public let threadScheduling: Int

        public init(callbackDeadlines: Int, allocations: Int, threadScheduling: Int) {
            self.callbackDeadlines = callbackDeadlines
            self.allocations = allocations
            self.threadScheduling = threadScheduling
        }
    }

    public var audioLatencyP99Microseconds: Double
    public var audioJitterP99Microseconds: Double
    public var lostPackets: Int
    public var latePackets: Int
    public var underruns: Int
    public var droppedVideoFrames: Int
    public var cueTimingP99Microseconds: Double
    public var cpuP99Percent: Double
    public var residentMemoryMegabytes: Double
    public var measurementDurationSeconds: Double?
    public var durationMismatch: Bool
    public var callbackDeadlineWarnings: Int
    public var allocationWarnings: Int
    public var threadSchedulingWarnings: Int

    public init(
        audio: Audio,
        videoControl: VideoControl,
        resources: Resources,
        warnings: Warnings
    ) {
        self.audioLatencyP99Microseconds = audio.latencyP99Microseconds
        self.audioJitterP99Microseconds = audio.jitterP99Microseconds
        self.lostPackets = audio.lostPackets
        self.latePackets = audio.latePackets
        self.underruns = audio.underruns
        self.droppedVideoFrames = videoControl.droppedVideoFrames
        self.cueTimingP99Microseconds = videoControl.cueTimingP99Microseconds
        self.cpuP99Percent = resources.cpuP99Percent
        self.residentMemoryMegabytes = resources.residentMemoryMegabytes
        self.measurementDurationSeconds = resources.measurementDurationSeconds
        self.durationMismatch = resources.durationMismatch
        self.callbackDeadlineWarnings = warnings.callbackDeadlines
        self.allocationWarnings = warnings.allocations
        self.threadSchedulingWarnings = warnings.threadScheduling
    }

    enum CodingKeys: String, CodingKey {
        case audioLatencyP99Microseconds
        case audioJitterP99Microseconds
        case lostPackets
        case latePackets
        case underruns
        case droppedVideoFrames
        case cueTimingP99Microseconds
        case cpuP99Percent
        case residentMemoryMegabytes
        case measurementDurationSeconds
        case durationMismatch
        case callbackDeadlineWarnings
        case allocationWarnings
        case threadSchedulingWarnings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.audioLatencyP99Microseconds = try container.decode(Double.self, forKey: .audioLatencyP99Microseconds)
        self.audioJitterP99Microseconds = try container.decode(Double.self, forKey: .audioJitterP99Microseconds)
        self.lostPackets = try container.decode(Int.self, forKey: .lostPackets)
        self.latePackets = try container.decode(Int.self, forKey: .latePackets)
        self.underruns = try container.decode(Int.self, forKey: .underruns)
        self.droppedVideoFrames = try container.decode(Int.self, forKey: .droppedVideoFrames)
        self.cueTimingP99Microseconds = try container.decode(Double.self, forKey: .cueTimingP99Microseconds)
        self.cpuP99Percent = try container.decode(Double.self, forKey: .cpuP99Percent)
        self.residentMemoryMegabytes = try container.decode(Double.self, forKey: .residentMemoryMegabytes)
        self.measurementDurationSeconds = try container.decodeIfPresent(
            Double.self,
            forKey: .measurementDurationSeconds
        )
        self.durationMismatch = try container.decodeIfPresent(Bool.self, forKey: .durationMismatch) ?? false
        self.callbackDeadlineWarnings = try container.decode(Int.self, forKey: .callbackDeadlineWarnings)
        self.allocationWarnings = try container.decode(Int.self, forKey: .allocationWarnings)
        self.threadSchedulingWarnings = try container.decode(Int.self, forKey: .threadSchedulingWarnings)
    }
}

/// Defines the validated fields for integrated profile benchmark row.
public struct IntegratedProfileBenchmarkRow: Codable, Equatable, Sendable {
    public var scenario: IntegratedProfileBenchmarkScenario
    public var reportId: String
    public var verdict: MeasurementVerdict
    public var measured: Bool
    public var physicalEvidence: Bool
    public var metrics: IntegratedProfileBenchmarkMetrics
    public var notes: String

    public init(
        scenario: IntegratedProfileBenchmarkScenario,
        reportId: String,
        verdict: MeasurementVerdict,
        measured: Bool,
        physicalEvidence: Bool,
        metrics: IntegratedProfileBenchmarkMetrics,
        notes: String
    ) {
        self.scenario = scenario
        self.reportId = reportId
        self.verdict = verdict
        self.measured = measured
        self.physicalEvidence = physicalEvidence
        self.metrics = metrics
        self.notes = notes
    }
}

/// Defines failures reported when integrated profile validation error cannot continue.
public enum IntegratedProfileValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyList(String)
    case duplicateProfileOption(IntegratedProfileLabel)
    case missingProfileOption(IntegratedProfileLabel)
    case duplicateSubordinateLane(IntegratedProfileSubordinateLane)
    case duplicateBenchmarkScenario(IntegratedProfileBenchmarkScenario)
    case missingBenchmarkScenario(IntegratedProfileBenchmarkScenario)
    case missingOptionalFeature(IntegratedProfileFeature)
    case negativeField(String)
    case nonFiniteField(String)
    case percentOutOfRange(field: String, value: Double)
    case defaultProfileMustBeFastestAudio(IntegratedProfileLabel)
    case fastestAudioProfileMustBeDefault
    case optionalProfilePromotedToDefault(IntegratedProfileLabel)
    case defaultProfileHasFeatures
    case defaultProfileHasLatencyCost(Double)
    case optionalProfileMissingFeatures(IntegratedProfileLabel)
    case audioLatencyDegradationMustBeLast
    case duplicateDegradationStep(IntegratedProfileDegradationStep)
    case videoDegradationMustLead
    case videoDisableMustPrecedeAudioLatency
// swiftlint:disable:next identifier_name
case lightingDegradationMustPrecedeAudioLatency
    case aggregateVerdictMismatch(report: MeasurementVerdict, aggregate: MeasurementVerdict)
    case passWithoutMeasuredRun
    case passWithoutPassProfileOption(IntegratedProfileLabel, MeasurementVerdict)
    case passWithoutPassSubordinateEvidence(IntegratedProfileSubordinateLane, MeasurementVerdict)
    case passWithoutMeasuredSubordinateEvidence(IntegratedProfileSubordinateLane)
    case passWithoutPhysicalSubordinateEvidence(IntegratedProfileSubordinateLane)
    case passWithoutBenchmarkScenario(IntegratedProfileBenchmarkScenario)
    case passWithoutPassBenchmarkScenario(IntegratedProfileBenchmarkScenario, MeasurementVerdict)
    case passWithoutMeasuredBenchmarkScenario(IntegratedProfileBenchmarkScenario)
    case passWithoutPhysicalBenchmarkScenario(IntegratedProfileBenchmarkScenario)
    case benchmarkDurationMismatch(IntegratedProfileBenchmarkScenario)
    case passWithPlaceholderEvidenceField(String)
    case passUnderreportsProfileLatencyCost(
        profile: IntegratedProfileLabel,
        reportedMicroseconds: Double,
        observedMicroseconds: Double
    )
    case passProfileLatencyBelowAudioOnly(
        profile: IntegratedProfileLabel,
        observedMicroseconds: Double
    )
}
