// Defines and validates integrated AV audio, video, synchronization, load, and verdict evidence.
import Foundation
import OpenLolaContracts

/// Defines failures reported when integrated AV validation error cannot continue.
public enum IntegratedAvValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyList(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedPacketAge(String)
    case unorderedAudioCallbackMetrics(String)
    case percentOutOfRange(field: String, value: Double)
    case passRunTooShort(seconds: Double, minimumSeconds: Double)
    case passWithoutMeasuredRun
    case passWithoutP04Proof
    case passWithoutAudioOnlyBaselineFirst
    case passWithoutRmeAudioDevice
    case passWithoutVideoCapture
    case passWithoutVideoTransportOrPreview
    case passWithoutOscPolling
    case passWithoutAtemReadOnlyPolling
    case passWithAtemCommandsArmed
    case passWithNonPassAudioBaseline(MeasurementVerdict)
    case passWithNonPassIntegratedAudio(MeasurementVerdict)
    case passChangesAudioRouteVerdict(baseline: MeasurementVerdict, integrated: MeasurementVerdict)
    case passWithNonPassAudioRouteVerdict(baseline: MeasurementVerdict, integrated: MeasurementVerdict)
    case passWithUiRealtimeOwnership
    case passWithoutPreAudioDegradation
    case passIncreasesAudioP99(baseline: Double, integrated: Double)
    case passIncreasesAudioMax(baseline: Double, integrated: Double)
    case passChangesAudioPlayoutTarget(baseline: Int, integrated: Int)
    case passWithAudioLossOrLatePackets
    case passWithUnderruns(Int)
    case passWithHiddenPlayoutGrowth
    case passWithoutRunWindow
    case passWithInsufficientAudioVideoOverlap(seconds: Double, minimumSeconds: Double)
    case passWithAudioBaselineReportMismatch(expected: String, actual: String)
    case passWithIntegratedRunReportMismatch(expected: String, actual: String)
    case passWithoutAudioRoutePacketCapturePoint
    case passWithoutVideoCaptureReportId
    case passWithoutVideoTransportReportId
// swiftlint:disable:next identifier_name
case passWithoutVideoTransportPacketCapturePoint
    case passWithoutVideoPreviewReportId
    case passWithPlaceholderProofField(String)
    // swiftlint:disable:next inclusive_language
    case audioMasterClockViolation(IntegratedAvMasterClock)
    case audioMayBlockForVideo
    case videoMayChangeAudioPlayoutTarget
    case videoWithoutPreAudioImpactDegradation
    case invalidVideoFrameIdentityRange(firstFrameId: Int, lastFrameId: Int)
    case invalidVideoFrameTimestampRange(firstFrameMonotonicNanoseconds: Int, lastFrameMonotonicNanoseconds: Int)
    case passWithNonMonotonicVideoFrameTiming(Int)
    case passWithDuplicateVideoFrameIdentities(Int)
    case passWithStaleVideoRendered(maxAgeMicroseconds: Double, limitMicroseconds: Double)
    case passWithRenderedStaleVideoFrames(Int)
    case passWithAudioHoldForVideoEvents(Int)
}

/// Records the evidence and outcome for integrated AV report.
public struct IntegratedAvReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public static let minimumPassDurationSeconds: Double = 1_800

    public var id: String
    public var title: String
    public var capturedAt: String
    public var runMode: ReportRunMode
    public var durationSeconds: Double
    public var runWindow: IntegratedAvRunWindowEvidence?
    public var sync: IntegratedAvSyncPolicy
    public var headless: HeadlessOwnershipReport
    public var audio: IntegratedAudioMetrics
    public var video: IntegratedVideoMetrics
    public var systemLoad: IntegratedSystemLoadMetrics
    public var proof: IntegratedProofEvidence?
    public var verdict: MeasurementVerdict
    public var notes: String

    public struct Metadata: Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var runMode: ReportRunMode
        public var durationSeconds: Double
        public var runWindow: IntegratedAvRunWindowEvidence?

        public init(
            id: String,
            title: String,
            capturedAt: String,
            runMode: ReportRunMode,
            durationSeconds: Double,
            runWindow: IntegratedAvRunWindowEvidence? = nil
        ) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.runMode = runMode
            self.durationSeconds = durationSeconds
            self.runWindow = runWindow
        }
    }

    public struct Evidence: Equatable, Sendable {
        public var headless: HeadlessOwnershipReport
        public var audio: IntegratedAudioMetrics
        public var video: IntegratedVideoMetrics
        public var systemLoad: IntegratedSystemLoadMetrics
        public var proof: IntegratedProofEvidence?

        public init(
            headless: HeadlessOwnershipReport,
            audio: IntegratedAudioMetrics,
            video: IntegratedVideoMetrics,
            systemLoad: IntegratedSystemLoadMetrics,
            proof: IntegratedProofEvidence? = nil
        ) {
            self.headless = headless
            self.audio = audio
            self.video = video
            self.systemLoad = systemLoad
            self.proof = proof
        }
    }

    public init(
        metadata: Metadata,
        sync: IntegratedAvSyncPolicy = .audioMaster,
        evidence: Evidence,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = metadata.id
        self.title = metadata.title
        self.capturedAt = metadata.capturedAt
        self.runMode = metadata.runMode
        self.durationSeconds = metadata.durationSeconds
        self.runWindow = metadata.runWindow
        self.sync = sync
        self.headless = evidence.headless
        self.audio = evidence.audio
        self.video = evidence.video
        self.systemLoad = evidence.systemLoad
        self.proof = evidence.proof
        self.verdict = verdict
        self.notes = notes
    }
}
