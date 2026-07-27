// Collects measurement evidence evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Represents LightingDmxPayloadProfile values used by read-only control integration.
public struct LightingDmxPayloadProfile: Codable, Equatable, Sendable {
    public var channelCount: Int
    public var changedChannels: Int
    public var minLevel: Int
    public var maxLevel: Int

    public init(channelCount: Int, changedChannels: Int, minLevel: Int, maxLevel: Int) {
        self.channelCount = channelCount
        self.changedChannels = changedChannels
        self.minLevel = minLevel
        self.maxLevel = maxLevel
    }
}

/// Captures LightingPacketCaptureReport evidence in a stable form for validation and serialized reporting.
public struct LightingPacketCaptureSummary: Codable, Equatable, Sendable {
    public var captured: Bool
    public var packetCount: Int
    public var universesObserved: [Int]
    public var broadcastPackets: Int
    public var multicastPackets: Int
    public init(captured: Bool, packetCount: Int, universesObserved: [Int], broadcastPackets: Int, multicastPackets: Int) { self.captured = captured; self.packetCount = packetCount; self.universesObserved = universesObserved; self.broadcastPackets = broadcastPackets; self.multicastPackets = multicastPackets }
}

/// Identifies how and where a lighting packet capture artifact was produced.
public struct LightingPacketCaptureProvenance: Codable, Equatable, Sendable {
    public var tool: String
    public var capturePoint: String
    public var captureArtifact: String
    public var notes: String
    public init(tool: String, capturePoint: String, captureArtifact: String, notes: String) { self.tool = tool; self.capturePoint = capturePoint; self.captureArtifact = captureArtifact; self.notes = notes }
}

/// Combines lighting packet capture measurements with their collection provenance.
public struct LightingPacketCaptureReport: Codable, Equatable, Sendable {
    public var captured: Bool
    public var tool: String
    public var capturePoint: String
    public var packetCount: Int
    public var universesObserved: [Int]
    public var broadcastPackets: Int
    public var multicastPackets: Int
    public var captureArtifact: String
    public var notes: String

    public init(summary: LightingPacketCaptureSummary, provenance: LightingPacketCaptureProvenance) {
        self.captured = summary.captured
        self.tool = provenance.tool
        self.capturePoint = provenance.capturePoint
        self.packetCount = summary.packetCount
        self.universesObserved = summary.universesObserved
        self.broadcastPackets = summary.broadcastPackets
        self.multicastPackets = summary.multicastPackets
        self.captureArtifact = provenance.captureArtifact
        self.notes = provenance.notes
    }
}

/// Captures LightingProbeReport evidence in a stable form for validation and serialized reporting.
public struct LightingProbeReport: Codable, Equatable, Sendable {
    public var interopTarget: LightingInteropTarget
    public var request: LightingOutputRequest
    public var dmx: LightingDmxPayloadProfile
    public var packetCapture: LightingPacketCaptureReport
    public var durationSeconds: Double

    public init(
        interopTarget: LightingInteropTarget,
        request: LightingOutputRequest,
        dmx: LightingDmxPayloadProfile,
        packetCapture: LightingPacketCaptureReport,
        durationSeconds: Double
    ) {
        self.interopTarget = interopTarget
        self.request = request
        self.dmx = dmx
        self.packetCapture = packetCapture
        self.durationSeconds = durationSeconds
    }
}

/// Defines LightingFixtureMetadataValidationMode acceptance rules so callers receive deterministic pass or failure evidence.
public enum LightingFixtureMetadataValidationMode: String, Codable, Equatable, Sendable {
    case setupOnly
    case notRun
}

/// Defines LightingFixtureMetadataPolicy acceptance rules so callers receive deterministic pass or failure evidence.
public struct LightingFixtureMetadataPolicy: Codable, Equatable, Sendable {
    public var source: String
    public var validationMode: LightingFixtureMetadataValidationMode
    public var realtimeLookupAllowed: Bool

    public init(
        source: String,
        validationMode: LightingFixtureMetadataValidationMode,
        realtimeLookupAllowed: Bool
    ) {
        self.source = source
        self.validationMode = validationMode
        self.realtimeLookupAllowed = realtimeLookupAllowed
    }
}

/// Compares audio callback and playout metrics before and during lighting control.
public struct LightingAudioImpactMetrics: Codable, Equatable, Sendable {
    public var baselineCallbackP99Microseconds: Double
    public var lightingCallbackP99Microseconds: Double
    public var baselineCallbackMaxMicroseconds: Double
    public var lightingCallbackMaxMicroseconds: Double
    public var baselinePlayoutTargetFrames: Int
    public var lightingPlayoutTargetFrames: Int
    public var underruns: Int
    public var hiddenAudioImpactDetected: Bool
    public var baselineReportId: String?

    public init(baseline: LightingAudioCallbackMetrics, lighting: LightingAudioCallbackMetrics, underruns: Int, hiddenAudioImpactDetected: Bool, baselineReportId: String? = nil) {
        self.baselineCallbackP99Microseconds = baseline.p99Microseconds
        self.lightingCallbackP99Microseconds = lighting.p99Microseconds
        self.baselineCallbackMaxMicroseconds = baseline.maxMicroseconds
        self.lightingCallbackMaxMicroseconds = lighting.maxMicroseconds
        self.baselinePlayoutTargetFrames = baseline.playoutTargetFrames
        self.lightingPlayoutTargetFrames = lighting.playoutTargetFrames
        self.underruns = underruns
        self.hiddenAudioImpactDetected = hiddenAudioImpactDetected
        self.baselineReportId = baselineReportId
    }
}

/// Enumerates failures that callers must handle when working with read-only control integration.
public enum LightingFixtureGateValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyList(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case valueOutOfRange(field: String, value: Int)
    case invalidDmxLevelRange(minLevel: Int, maxLevel: Int)
    case missingStandard(LightingControlProtocol)
    case unorderedAudioCallbackMetrics(String)
    case packetCaptureAccountingMismatch
    case passWithoutReviewedStandards(LightingControlProtocol)
    case passWithBlockedGate(LightingGateBlockReason)
    case passWithoutFailurePolicy
    case passWithoutPacketCapture
    case passWithoutOneUniverseCapture
    case passWithoutDmxOutputActivity
    case passAllowsRealtimeFixtureLookup
    case passIncreasesAudioP99(baseline: Double, lighting: Double)
    case passIncreasesAudioMax(baseline: Double, lighting: Double)
    case passChangesAudioPlayoutTarget(baseline: Int, lighting: Int)
    case passWithUnderruns(Int)
    case passWithHiddenAudioImpact
    case passWithoutCueWorkflow
    case passWithoutOscCueReport
    case passWithoutLocalFixtureOwner
    case passWithFixtureOwnerMismatch(expected: LightingInteropTarget, actual: LightingInteropTarget)
    // swiftlint:disable:next identifier_name
    case passWithDirectFixtureStreamingOnPerformanceLink
    case passWithPlaceholderWorkflowField(String)
}
