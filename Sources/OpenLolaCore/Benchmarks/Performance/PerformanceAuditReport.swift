import Foundation

public struct PerformanceCounterSummary: Codable, Equatable, Sendable {
    public var sampleCount: Int
    public var p50Microseconds: Double
    public var p95Microseconds: Double
    public var p99Microseconds: Double
    public var maxMicroseconds: Double
    public var invalidSampleCount: Int
    private var recordedSamplesMicroseconds: [Double]

    public var rawSamplesMicroseconds: [Double] {
        recordedSamplesMicroseconds
    }

    public static let empty = PerformanceCounterSummary(
        sampleCount: 0,
        p50Microseconds: 0,
        p95Microseconds: 0,
        p99Microseconds: 0,
        maxMicroseconds: 0,
        invalidSampleCount: 0,
        recordedSamplesMicroseconds: []
    )

    public init(
        sampleCount: Int,
        p50Microseconds: Double,
        p95Microseconds: Double,
        p99Microseconds: Double,
        maxMicroseconds: Double,
        invalidSampleCount: Int = 0,
        recordedSamplesMicroseconds: [Double] = []
    ) {
        self.sampleCount = sampleCount
        self.p50Microseconds = p50Microseconds
        self.p95Microseconds = p95Microseconds
        self.p99Microseconds = p99Microseconds
        self.maxMicroseconds = maxMicroseconds
        self.invalidSampleCount = invalidSampleCount
        self.recordedSamplesMicroseconds = recordedSamplesMicroseconds
    }

    public static func fromCallback(_ callback: EndpointCallbackMetrics) -> PerformanceCounterSummary {
        PerformanceCounterSummary(
            sampleCount: 1,
            p50Microseconds: callback.p50Microseconds,
            p95Microseconds: callback.p95Microseconds,
            p99Microseconds: callback.p99Microseconds,
            maxMicroseconds: callback.maxMicroseconds
        )
    }

    public static func fromSamples(_ samples: [Double]) -> PerformanceCounterSummary {
        guard !samples.isEmpty else {
            return .empty
        }
        let invalidSampleCount = samples.filter { !$0.isFinite || $0 < 0 }.count
        let sorted = samples.filter { $0.isFinite && $0 >= 0 }.sorted()
        guard !sorted.isEmpty else {
            return PerformanceCounterSummary(
                sampleCount: 0,
                p50Microseconds: 0,
                p95Microseconds: 0,
                p99Microseconds: 0,
                maxMicroseconds: 0,
                invalidSampleCount: invalidSampleCount
            )
        }
        return PerformanceCounterSummary(
            sampleCount: sorted.count,
            p50Microseconds: performancePercentile(sorted, 0.50),
            p95Microseconds: performancePercentile(sorted, 0.95),
            p99Microseconds: performancePercentile(sorted, 0.99),
            maxMicroseconds: sorted.last ?? 0,
            invalidSampleCount: invalidSampleCount
        )
    }

    public mutating func record(_ microseconds: Double) {
        recordedSamplesMicroseconds.append(microseconds)
        finalize()
    }

    public mutating func finalize() {
        guard !recordedSamplesMicroseconds.isEmpty else {
            return
        }
        let samples = recordedSamplesMicroseconds
        self = PerformanceCounterSummary.fromSamples(samples)
        recordedSamplesMicroseconds = samples
    }

    enum CodingKeys: String, CodingKey {
        case sampleCount
        case p50Microseconds
        case p95Microseconds
        case p99Microseconds
        case maxMicroseconds
        case invalidSampleCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sampleCount = try container.decode(Int.self, forKey: .sampleCount)
        self.p50Microseconds = try container.decode(Double.self, forKey: .p50Microseconds)
        self.p95Microseconds = try container.decode(Double.self, forKey: .p95Microseconds)
        self.p99Microseconds = try container.decode(Double.self, forKey: .p99Microseconds)
        self.maxMicroseconds = try container.decode(Double.self, forKey: .maxMicroseconds)
        self.invalidSampleCount = try container.decodeIfPresent(Int.self, forKey: .invalidSampleCount) ?? 0
        self.recordedSamplesMicroseconds = []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sampleCount, forKey: .sampleCount)
        try container.encode(p50Microseconds, forKey: .p50Microseconds)
        try container.encode(p95Microseconds, forKey: .p95Microseconds)
        try container.encode(p99Microseconds, forKey: .p99Microseconds)
        try container.encode(maxMicroseconds, forKey: .maxMicroseconds)
        try container.encode(invalidSampleCount, forKey: .invalidSampleCount)
    }

    public static func == (lhs: PerformanceCounterSummary, rhs: PerformanceCounterSummary) -> Bool {
        lhs.sampleCount == rhs.sampleCount
            && lhs.p50Microseconds == rhs.p50Microseconds
            && lhs.p95Microseconds == rhs.p95Microseconds
            && lhs.p99Microseconds == rhs.p99Microseconds
            && lhs.maxMicroseconds == rhs.maxMicroseconds
            && lhs.invalidSampleCount == rhs.invalidSampleCount
    }
}

private func performancePercentile(_ sorted: [Double], _ fraction: Double) -> Double {
    guard !sorted.isEmpty else {
        return 0
    }
    let bounded = min(1, max(0, fraction))
    let index = Int((Double(sorted.count - 1) * bounded).rounded(.up))
    return sorted[min(sorted.count - 1, max(0, index))]
}

public enum PerformanceAuditRunMode: String, Codable, Equatable, Sendable {
    case synthetic
    case measured
}

public enum PerformanceAuditEvidenceKind: String, Codable, Equatable, Sendable {
    case sourceAudit
    case synthetic
    case physicalAppleSiliconRig
}

public enum PerformanceHotPathSurface: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case audioCallback
    case audioPacketHandoff
    case audioPacketization
    case audioDepacketization
    case videoCapture
    case videoPacketization
    case videoReassembly
    case networkTransport
    case control
    case metricsReporting
    case ui
}

public enum PerformanceWorkerRole: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case audioCallback
    case audioNetworkTx
    case audioNetworkRx
    case videoCapture
    case videoEncodePacketize
    case videoReceiveRender
    case controlSession
    case observability
    case ui
}

public enum PerformanceWorkerQoS: String, Codable, Equatable, Sendable {
    case realtimeDeviceOwned
    case userInteractive
    case userInitiated
    case utility
    case main
}

public enum PerformanceCopyKind: String, Codable, Equatable, Sendable {
    case none
    case preallocatedSlabCopy
    case channelRemapCopy
    case packetBoundaryCopy
    case apiBoundaryCopy
    case pixelBufferReference
    case encodedFragmentCopy
}

public enum PerformanceAccelerationOption: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case rawLowCopyBaseline
    case metal
    case videoToolbox
}

public enum PerformanceSettingsTier: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case safe
    case ultra
    case experimental
}

public enum PerformanceAuditValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError {
    case emptyField(String)
    case emptyList(String)
    case duplicateHotPath(PerformanceHotPathSurface)
    case duplicateWorkerRole(PerformanceWorkerRole)
    case duplicateSettingsTier(PerformanceSettingsTier)
    case duplicateAccelerationOption(PerformanceAccelerationOption)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedCounter(String)
    case invalidCounterSamples(field: String, count: Int)
    case unorderedPacketAge(String)
    case passWithoutMeasuredRun
    case passWithoutPhysicalRig
    case passWithoutRequiredHotPath(PerformanceHotPathSurface)
    case passWithRealtimeViolation(surface: PerformanceHotPathSurface, field: String)
    case passWithDynamicConfiguration(PerformanceHotPathSurface)
    case passWithAudioBlockingWorker(PerformanceWorkerRole)
    case passWithWrongWorkerQoS(
        role: PerformanceWorkerRole,
        expected: PerformanceWorkerQoS,
        actual: PerformanceWorkerQoS
    )
    case passWithUndocumentedCopy(String)
    case passWithUnmeasuredCopy(String)
    case passWithAvoidableCopyRemaining(String)
    case passWithoutAccelerationOption(PerformanceAccelerationOption)
    case passWithoutRawBaseline(PerformanceAccelerationOption)
    case passWithoutSettingsTier(PerformanceSettingsTier)
    case passWithoutProfilePhysicalEvidence(PerformanceSettingsTier)
    case passWithCounterWarning(String)
    case passWithAppleSiliconPolicyViolation(String)
}

public struct PerformanceProcessContext: Codable, Equatable, Sendable {
    public var machineModel: String
    public var chipName: String
    public var osVersion: String
    public var processName: String
    public var thermalState: String
    public var powerMode: String

    public init(
        machineModel: String,
        chipName: String,
        osVersion: String,
        processName: String,
        thermalState: String,
        powerMode: String
    ) {
        self.machineModel = machineModel
        self.chipName = chipName
        self.osVersion = osVersion
        self.processName = processName
        self.thermalState = thermalState
        self.powerMode = powerMode
    }
}

public struct AppleSiliconRuntimePolicy: Codable, Equatable, Sendable {
    public var nativeArm64Process: Bool
    public var rosettaTranslated: Bool
    public var usesQoSInsteadOfCorePinning: Bool
    public var keepsAudioOnDeviceCallback: Bool
    public var usesUnifiedMemoryLowCopyVideoPath: Bool
    public var avoidsCPUGPUReadbackRoundTrip: Bool
    public var promotesAccelerationOnlyAfterRawBaseline: Bool
    public var notes: String

    public init(
        nativeArm64Process: Bool,
        rosettaTranslated: Bool,
        usesQoSInsteadOfCorePinning: Bool,
        keepsAudioOnDeviceCallback: Bool,
        usesUnifiedMemoryLowCopyVideoPath: Bool,
        avoidsCPUGPUReadbackRoundTrip: Bool,
        promotesAccelerationOnlyAfterRawBaseline: Bool,
        notes: String
    ) {
        self.nativeArm64Process = nativeArm64Process
        self.rosettaTranslated = rosettaTranslated
        self.usesQoSInsteadOfCorePinning = usesQoSInsteadOfCorePinning
        self.keepsAudioOnDeviceCallback = keepsAudioOnDeviceCallback
        self.usesUnifiedMemoryLowCopyVideoPath = usesUnifiedMemoryLowCopyVideoPath
        self.avoidsCPUGPUReadbackRoundTrip = avoidsCPUGPUReadbackRoundTrip
        self.promotesAccelerationOnlyAfterRawBaseline = promotesAccelerationOnlyAfterRawBaseline
        self.notes = notes
    }
}

public struct PerformanceHotPathAudit: Codable, Equatable, Sendable {
    public var surface: PerformanceHotPathSurface
    public var allocationWarnings: Int
    public var blockingIOWarnings: Int
    public var loggingWarnings: Int
    public var lockWarnings: Int
    public var usesMonotonicClock: Bool
    public var dynamicConfigurationAfterStart: Bool
    public var notes: String

    public init(
        surface: PerformanceHotPathSurface,
        allocationWarnings: Int,
        blockingIOWarnings: Int,
        loggingWarnings: Int,
        lockWarnings: Int,
        usesMonotonicClock: Bool,
        dynamicConfigurationAfterStart: Bool,
        notes: String
    ) {
        self.surface = surface
        self.allocationWarnings = allocationWarnings
        self.blockingIOWarnings = blockingIOWarnings
        self.loggingWarnings = loggingWarnings
        self.lockWarnings = lockWarnings
        self.usesMonotonicClock = usesMonotonicClock
        self.dynamicConfigurationAfterStart = dynamicConfigurationAfterStart
        self.notes = notes
    }
}

public struct PerformanceCopyAuditEntry: Codable, Equatable, Sendable {
    public var id: String
    public var surface: PerformanceHotPathSurface
    public var kind: PerformanceCopyKind
    public var byteCountPerUnit: Int
    public var copiesPerUnit: Int
    public var avoidable: Bool
    public var removed: Bool
    public var measuredCostMicroseconds: Double?
    public var documentation: String

    public init(
        id: String,
        surface: PerformanceHotPathSurface,
        kind: PerformanceCopyKind,
        byteCountPerUnit: Int,
        copiesPerUnit: Int,
        avoidable: Bool,
        removed: Bool,
        measuredCostMicroseconds: Double?,
        documentation: String
    ) {
        self.id = id
        self.surface = surface
        self.kind = kind
        self.byteCountPerUnit = byteCountPerUnit
        self.copiesPerUnit = copiesPerUnit
        self.avoidable = avoidable
        self.removed = removed
        self.measuredCostMicroseconds = measuredCostMicroseconds
        self.documentation = documentation
    }
}

public struct PerformanceWorkerAssignment: Codable, Equatable, Sendable {
    public var role: PerformanceWorkerRole
    public var queueLabel: String
    public var qos: PerformanceWorkerQoS
    public var isolatedFromAudioCallback: Bool
    public var canBlockAudioCriticalQueue: Bool
    public var notes: String

    public init(
        role: PerformanceWorkerRole,
        queueLabel: String,
        qos: PerformanceWorkerQoS,
        isolatedFromAudioCallback: Bool,
        canBlockAudioCriticalQueue: Bool,
        notes: String
    ) {
        self.role = role
        self.queueLabel = queueLabel
        self.qos = qos
        self.isolatedFromAudioCallback = isolatedFromAudioCallback
        self.canBlockAudioCriticalQueue = canBlockAudioCriticalQueue
        self.notes = notes
    }
}

public struct PerformanceAuditCounters: Codable, Equatable, Sendable {
    public var callbackDuration: PerformanceCounterSummary
    public var packetizationDuration: PerformanceCounterSummary
    public var depacketizationDuration: PerformanceCounterSummary
    public var videoFrameAge: UdpPcmPacketAgeMetrics
    public var ringOccupancyBlocks: Int
    public var ringDropCount: Int
    public var queueDepthPackets: Int
    public var videoQueueDepthFrames: Int
    public var audioDropCount: Int
    public var allocationWarningCount: Int
    public var memoryBandwidthMegabytesPerSecond: Double

    public init(
        callbackDuration: PerformanceCounterSummary,
        packetizationDuration: PerformanceCounterSummary,
        depacketizationDuration: PerformanceCounterSummary,
        videoFrameAge: UdpPcmPacketAgeMetrics,
        ringOccupancyBlocks: Int,
        ringDropCount: Int,
        queueDepthPackets: Int,
        videoQueueDepthFrames: Int,
        audioDropCount: Int,
        allocationWarningCount: Int,
        memoryBandwidthMegabytesPerSecond: Double
    ) {
        self.callbackDuration = callbackDuration
        self.packetizationDuration = packetizationDuration
        self.depacketizationDuration = depacketizationDuration
        self.videoFrameAge = videoFrameAge
        self.ringOccupancyBlocks = ringOccupancyBlocks
        self.ringDropCount = ringDropCount
        self.queueDepthPackets = queueDepthPackets
        self.videoQueueDepthFrames = videoQueueDepthFrames
        self.audioDropCount = audioDropCount
        self.allocationWarningCount = allocationWarningCount
        self.memoryBandwidthMegabytesPerSecond = memoryBandwidthMegabytesPerSecond
    }
}

public struct PerformanceAccelerationDecision: Codable, Equatable, Sendable {
    public var option: PerformanceAccelerationOption
    public var benchmarked: Bool
    public var rawBaselineReportId: String?
    public var measuredCostMicroseconds: Double?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        option: PerformanceAccelerationOption,
        benchmarked: Bool,
        rawBaselineReportId: String?,
        measuredCostMicroseconds: Double?,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.option = option
        self.benchmarked = benchmarked
        self.rawBaselineReportId = rawBaselineReportId
        self.measuredCostMicroseconds = measuredCostMicroseconds
        self.verdict = verdict
        self.notes = notes
    }
}

public struct PerformanceProfileReportReference: Codable, Equatable, Sendable {
    public var settingsTier: PerformanceSettingsTier
    public var sessionProfile: SessionLatencyProfile
    public var latencyProfile: LatencyProfile
    public var reportId: String
    public var counters: PerformanceAuditCounters
    public var measured: Bool
    public var physicalEvidence: Bool
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        settingsTier: PerformanceSettingsTier,
        sessionProfile: SessionLatencyProfile,
        latencyProfile: LatencyProfile,
        reportId: String,
        counters: PerformanceAuditCounters,
        measured: Bool,
        physicalEvidence: Bool,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.settingsTier = settingsTier
        self.sessionProfile = sessionProfile
        self.latencyProfile = latencyProfile
        self.reportId = reportId
        self.counters = counters
        self.measured = measured
        self.physicalEvidence = physicalEvidence
        self.verdict = verdict
        self.notes = notes
    }
}

public struct VideoTransportPerformanceCounters: Codable, Equatable, Sendable {
    public var packetizationDuration: PerformanceCounterSummary
    public var reassemblyDuration: PerformanceCounterSummary
    public var frameAge: UdpPcmPacketAgeMetrics
    public var queueDepthFrames: Int

    public init(
        packetizationDuration: PerformanceCounterSummary,
        reassemblyDuration: PerformanceCounterSummary,
        frameAge: UdpPcmPacketAgeMetrics,
        queueDepthFrames: Int
    ) {
        self.packetizationDuration = packetizationDuration
        self.reassemblyDuration = reassemblyDuration
        self.frameAge = frameAge
        self.queueDepthFrames = queueDepthFrames
    }
}

public struct PerformanceAuditReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: PerformanceAuditRunMode
    public var evidenceKind: PerformanceAuditEvidenceKind
    public var hardware: HardwareIdentity
    public var processContext: PerformanceProcessContext
    public var appleSiliconPolicy: AppleSiliconRuntimePolicy
    public var sourceReportIds: [String]
    public var hotPaths: [PerformanceHotPathAudit]
    public var copyAudit: [PerformanceCopyAuditEntry]
    public var workerAssignments: [PerformanceWorkerAssignment]
    public var counters: PerformanceAuditCounters
    public var accelerationDecisions: [PerformanceAccelerationDecision]
    public var profileReports: [PerformanceProfileReportReference]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        runMode: PerformanceAuditRunMode,
        evidenceKind: PerformanceAuditEvidenceKind,
        hardware: HardwareIdentity,
        processContext: PerformanceProcessContext,
        appleSiliconPolicy: AppleSiliconRuntimePolicy,
        sourceReportIds: [String],
        hotPaths: [PerformanceHotPathAudit],
        copyAudit: [PerformanceCopyAuditEntry],
        workerAssignments: [PerformanceWorkerAssignment],
        counters: PerformanceAuditCounters,
        accelerationDecisions: [PerformanceAccelerationDecision],
        profileReports: [PerformanceProfileReportReference],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.runMode = runMode
        self.evidenceKind = evidenceKind
        self.hardware = hardware
        self.processContext = processContext
        self.appleSiliconPolicy = appleSiliconPolicy
        self.sourceReportIds = sourceReportIds
        self.hotPaths = hotPaths
        self.copyAudit = copyAudit
        self.workerAssignments = workerAssignments
        self.counters = counters
        self.accelerationDecisions = accelerationDecisions
        self.profileReports = profileReports
        self.verdict = verdict
        self.notes = notes
    }

}
