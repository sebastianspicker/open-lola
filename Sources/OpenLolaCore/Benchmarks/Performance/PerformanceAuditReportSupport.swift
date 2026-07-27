// Declares performance-audit classifications, Apple-silicon policy, and validation failures so reports evaluate hot-path evidence consistently.
import Foundation
import OpenLolaContracts

/// Defines the finite evidence provenance values recorded by performance audit artifacts for deterministic validation and report interpretation.
public enum PerformanceAuditEvidenceKind: String, Codable, Equatable, Sendable {
    case sourceAudit
    case synthetic
    case physicalAppleSiliconRig
}

/// Defines the finite structured result values recorded by performance audit artifacts for deterministic validation and report interpretation.
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
    // swiftlint:disable:next identifier_name
    case ui
}

/// Defines the finite structured result values recorded by performance audit artifacts for deterministic validation and report interpretation.
public enum PerformanceWorkerRole: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case audioCallback
    case audioNetworkTx
    case audioNetworkRx
    case videoCapture
    case videoEncodePacketize
    case videoReceiveRender
    case controlSession
    case observability
    // swiftlint:disable:next identifier_name
    case ui
}

/// Defines the finite structured result values recorded by performance audit artifacts for deterministic validation and report interpretation.
public enum PerformanceWorkerQoS: String, Codable, Equatable, Sendable {
    case realtimeDeviceOwned
    case userInteractive
    case userInitiated
    case utility
    case main
}

/// Defines the finite classification values recorded by performance audit artifacts for deterministic validation and report interpretation.
public enum PerformanceCopyKind: String, Codable, Equatable, Sendable {
    case none
    case preallocatedSlabCopy
    case channelRemapCopy
    case packetBoundaryCopy
    case apiBoundaryCopy
    case pixelBufferReference
    case encodedFragmentCopy
}

/// Defines the finite structured result values recorded by performance audit artifacts for deterministic validation and report interpretation.
public enum PerformanceAccelerationOption: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case rawLowCopyBaseline
    case metal
    case videoToolbox
}

/// Defines the finite structured result values recorded by performance audit artifacts for deterministic validation and report interpretation.
public enum PerformanceSettingsTier: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case safe
    case ultra
    case experimental
}

/// Describes failures that prevent performance audit inputs or evidence from satisfying the required validation invariants.
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

/// Captures structured result required to validate, interpret, and reproduce a performance audit result.
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

/// Captures acceptance policy required to validate, interpret, and reproduce a performance audit result.
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

/// Captures audit findings required to validate, interpret, and reproduce a performance audit result.
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

/// Captures audit findings required to validate, interpret, and reproduce a performance audit result.
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

}

/// Captures structured result required to validate, interpret, and reproduce a performance audit result.
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

/// Captures audit findings required to validate, interpret, and reproduce a performance audit result.
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

}

/// Captures structured result required to validate, interpret, and reproduce a performance audit result.
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

/// Captures report contents required to validate, interpret, and reproduce a performance audit result.
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

}

/// Captures runtime counters required to validate, interpret, and reproduce a performance audit result.
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
