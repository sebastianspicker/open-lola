// Collects end-to-end benchmark evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation
import OpenLolaContracts

/// Defines the finite evidence provenance values recorded by end-to-end benchmark artifacts for deterministic validation and report interpretation.
public enum E2EBenchmarkEvidenceKind: String, Codable, Equatable, Sendable {
    case synthetic
    case physicalTwoPeerRig
}

/// Defines the finite execution profile values recorded by end-to-end benchmark artifacts for deterministic validation and report interpretation.
public enum E2EBenchmarkProfile: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case audioOnlyDirect
    case audioVideoDirect
    case audioMultiVideoDirect
    case wanStable
}

/// Defines the finite execution profile values recorded by end-to-end benchmark artifacts for deterministic validation and report interpretation.
public enum E2EBenchmarkImpairmentProfile: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case loss
    case jitter
    case reorder
    case duplicate
    case late
}

/// Describes failures that prevent end-to-end benchmark inputs or evidence from satisfying the required validation invariants.
public enum E2EBenchmarkValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError,
    ValidationPercentOutOfRangeFieldError {
    case emptyField(String)
    case emptyList(String)
    case duplicateProfile(E2EBenchmarkProfile)
    case missingProfile(E2EBenchmarkProfile)
    case duplicateImpairment(E2EBenchmarkImpairmentProfile)
    case missingImpairment(E2EBenchmarkImpairmentProfile)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case percentOutOfRange(field: String, value: Double)
    case unorderedCounter(String)
    case passWithoutMeasuredRun
    case passWithoutPhysicalTwoPeerEvidence
    case passWithPlaceholderField(String)
    case passWithNonPassProfile(E2EBenchmarkProfile, MeasurementVerdict)
    case passWithoutMeasuredProfile(E2EBenchmarkProfile)
    case passWithoutPhysicalProfile(E2EBenchmarkProfile)
    case passWithoutVideoMetrics(E2EBenchmarkProfile)
    case passWithoutMultiVideoStreamCount(Int)
    case passWithAudioUnderruns(E2EBenchmarkProfile, Int)
    case passWithHiddenAudioBufferGrowth(E2EBenchmarkProfile)
    case passWithVideoAudioImpact(E2EBenchmarkProfile)
    case passExceedsDroppedFrames(profile: E2EBenchmarkProfile, value: Int, threshold: Int)
    case passExceedsPacketLoss(profile: E2EBenchmarkProfile, value: Double, threshold: Double)
    case passExceedsCpu(profile: E2EBenchmarkProfile, value: Double, threshold: Double)
    case passWithNonPassImpairment(E2EBenchmarkImpairmentProfile, MeasurementVerdict)
    case passWithoutMeasuredImpairment(E2EBenchmarkImpairmentProfile)
    case passWithoutRecoveryEvent
    case passWithoutCleanShutdown
    case passWithLeakedCallbacks(Int)
    case passWithoutMethodologyReference(String)
}

/// Captures hardware and endpoint identity required to validate, interpret, and reproduce an end-to-end benchmark result.
public struct E2EBenchmarkPeerIdentity: Codable, Equatable, Sendable {
    public var peerId: String
    public var machineModel: String
    public var chipName: String
    public var osVersion: String
    public var audioInterface: String
    public var audioDeviceUID: String
    public var videoDevice: String
    public var networkInterface: String
}

/// Captures hardware and endpoint identity required to validate, interpret, and reproduce an end-to-end benchmark result.
public struct E2EBenchmarkHardwareIdentity: Codable, Equatable, Sendable {
    public var sourcePeer: E2EBenchmarkPeerIdentity
    public var receiverPeer: E2EBenchmarkPeerIdentity
    public var rmeMadiIdentity: String
    public var blackmagicIdentity: String
    public var routeLabel: String
    public var networkTopology: String
    public var packetCapturePoint: String
    public var clockAlignmentMethod: String
}

/// Captures report contents required to validate, interpret, and reproduce an end-to-end benchmark result.
public struct E2EBenchmarkComponentReports: Codable, Equatable, Sendable {
    public var audioBenchmarkReportId: String
    public var integratedAvReportId: String
    public var videoTransportReportId: String
    public var performanceAuditReportId: String
}

/// Stores audio timing, jitter, fault, and baseline-delta metrics; provenance belongs to the enclosing run.
public struct E2EBenchmarkAudioMetrics: Codable, Equatable, Sendable {
    public var sampleRateHertz: Int
    public var channelCount: Int
    public var framesPerBuffer: Int
    public var callbackDuration: PerformanceCounterSummary
    public var oneWayLatencyMicroseconds: Double
    public var roundTripLatencyMicroseconds: Double
    public var jitter: UdpPcmPacketAgeMetrics
    public var underruns: Int
    public var overruns: Int
    public var configuredChannelCount: Int
    public var hiddenBufferGrowthDetected: Bool
    public var audioP99DeltaFromBaselineMicroseconds: Double
}

/// Stores video capture, encode, render, and drop metrics; provenance belongs to the enclosing run.
public struct E2EBenchmarkVideoMetrics: Codable, Equatable, Sendable {
    public var streamCount: Int
    public var width: Int
    public var height: Int
    public var frameRate: Double
    public var captureLatency: UdpPcmPacketAgeMetrics
    public var encodePacketizationLatency: PerformanceCounterSummary
    public var receiveRenderLatency: UdpPcmPacketAgeMetrics
    public var droppedFrames: Int
    public var blackmagicCaptureReportId: String
    public var renderOutputReportId: String
}

/// Stores transport throughput, loss, ordering, and jitter metrics; provenance belongs to the enclosing run.
public struct E2EBenchmarkNetworkMetrics: Codable, Equatable, Sendable {
    public var throughputMegabitsPerSecond: Double
    public var lostPackets: Int
    public var latePackets: Int
    public var reorderedPackets: Int
    public var duplicatePackets: Int
    public var packetLossPercent: Double
    public var jitter: UdpPcmPacketAgeMetrics
    public var dscpClassification: UdpPcmDscpClassification
}

/// Stores resource-use counters for one benchmark profile; provenance belongs to the enclosing run.
public struct E2EBenchmarkResourceMetrics: Codable, Equatable, Sendable {
    public var cpuP99Percent: Double
    public var gpuP99Percent: Double
    public var residentMemoryMegabytes: Double
    public var hotPathAllocationWarnings: Int
}

/// Records one profile's evidence provenance, media metrics, resources, verdict, and notes.
public struct E2EBenchmarkProfileRun: Codable, Equatable, Sendable {
    public var profile: E2EBenchmarkProfile
    public var reportId: String
    public var measured: Bool
    public var physicalEvidence: Bool
    public var audio: E2EBenchmarkAudioMetrics
    public var video: E2EBenchmarkVideoMetrics?
    public var network: E2EBenchmarkNetworkMetrics
    public var resources: E2EBenchmarkResourceMetrics
    public var verdict: MeasurementVerdict
    public var notes: String
}

/// Records one injected-impairment run and whether recovery preserved audio and video delivery.
public struct E2EBenchmarkImpairmentRun: Codable, Equatable, Sendable {
    public var profile: E2EBenchmarkImpairmentProfile
    public var reportId: String
    public var measured: Bool
    public var injectedPackets: Int
    public var observedPackets: Int
    public var recoveredPackets: Int
    public var audioUnderruns: Int
    public var videoDroppedFrames: Int
    public var verdict: MeasurementVerdict
    public var notes: String
}

/// Stores reconnect and shutdown outcomes; provenance belongs to the enclosing run.
public struct E2EBenchmarkRecoveryMetrics: Codable, Equatable, Sendable {
    public var reconnectEvents: Int
    public var reconnectP99Microseconds: Double
    public var cleanShutdownObserved: Bool
    public var leakedRealtimeCallbacksAfterShutdown: Int
    public var recoveryReportId: String
    public var shutdownReportId: String
}

/// Captures acceptance thresholds required to validate, interpret, and reproduce an end-to-end benchmark result.
public struct E2EBenchmarkThresholds: Codable, Equatable, Sendable {
    public var methodologyDocument: String
    public var packetLossMaxPercent: Double
    public var cpuP99MaxPercent: Double
    // swiftlint:disable:next identifier_name
    public var audioP99DeltaFromBaselineToleranceMicroseconds: Double
    public var audioUnderrunMaxCount: Int
    public var droppedFrameMaxCount: Int
}

/// Captures report contents required to validate, interpret, and reproduce an end-to-end benchmark result.
public struct E2EBenchmarkReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public static let minimumPassDurationSeconds: Double = 1_800

    public var id: String
    public var title: String
    public var capturedAt: String
    public var durationSeconds: Double
    public var runMode: ReportRunMode
    public var evidenceKind: E2EBenchmarkEvidenceKind
    public var hardware: E2EBenchmarkHardwareIdentity
    public var componentReports: E2EBenchmarkComponentReports
    public var profiles: [E2EBenchmarkProfileRun]
    public var impairments: [E2EBenchmarkImpairmentRun]
    public var recovery: E2EBenchmarkRecoveryMetrics
    public var thresholds: E2EBenchmarkThresholds
    public var verdict: MeasurementVerdict
    public var notes: String
}
