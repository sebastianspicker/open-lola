import Foundation

public enum IntegratedProfileRunMode: String, Codable, Equatable, Sendable {
    case synthetic
    case measured
}

public enum IntegratedProfileLabel: String, Codable, Equatable, Hashable, Sendable {
    case fastestAudio = "fastest-audio"
    case audioVideo = "audio-video"
    case audioLighting = "audio-lighting"
    case audioVideoLighting = "audio-video-lighting"
}

public enum IntegratedProfileFeature: String, Codable, Equatable, Hashable, Sendable {
    case video
    case lightingControl = "lighting-control"
}

public enum IntegratedProfileSubordinateLane: String, Codable, Equatable, Hashable, Sendable {
    case fastestAudio
    case audioRoute
    case videoCapture
    case videoTransport
    case integratedAv
    case lightingControl
}

public enum IntegratedProfileBenchmarkScenario: String, Codable, Equatable, Hashable, Sendable {
    case audioOnly
    case audioVideo
    case audioControl
    case audioVideoControl
}

public enum IntegratedProfileDegradationStep: String, Codable, Equatable, Hashable, Sendable {
    case reduceVideoQuality
    case reduceVideoFrameRate
    case disableLighting
    case disableVideo
    case increaseAudioLatency
}

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

public struct IntegratedProfileBenchmarkMetrics: Codable, Equatable, Sendable {
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
        audioLatencyP99Microseconds: Double,
        audioJitterP99Microseconds: Double,
        lostPackets: Int,
        latePackets: Int,
        underruns: Int,
        droppedVideoFrames: Int,
        cueTimingP99Microseconds: Double,
        cpuP99Percent: Double,
        residentMemoryMegabytes: Double,
        measurementDurationSeconds: Double? = nil,
        durationMismatch: Bool = false,
        callbackDeadlineWarnings: Int,
        allocationWarnings: Int,
        threadSchedulingWarnings: Int
    ) {
        self.audioLatencyP99Microseconds = audioLatencyP99Microseconds
        self.audioJitterP99Microseconds = audioJitterP99Microseconds
        self.lostPackets = lostPackets
        self.latePackets = latePackets
        self.underruns = underruns
        self.droppedVideoFrames = droppedVideoFrames
        self.cueTimingP99Microseconds = cueTimingP99Microseconds
        self.cpuP99Percent = cpuP99Percent
        self.residentMemoryMegabytes = residentMemoryMegabytes
        self.measurementDurationSeconds = measurementDurationSeconds
        self.durationMismatch = durationMismatch
        self.callbackDeadlineWarnings = callbackDeadlineWarnings
        self.allocationWarnings = allocationWarnings
        self.threadSchedulingWarnings = threadSchedulingWarnings
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
        self.measurementDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .measurementDurationSeconds)
        self.durationMismatch = try container.decodeIfPresent(Bool.self, forKey: .durationMismatch) ?? false
        self.callbackDeadlineWarnings = try container.decode(Int.self, forKey: .callbackDeadlineWarnings)
        self.allocationWarnings = try container.decode(Int.self, forKey: .allocationWarnings)
        self.threadSchedulingWarnings = try container.decode(Int.self, forKey: .threadSchedulingWarnings)
    }
}

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
