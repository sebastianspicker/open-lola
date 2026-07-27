// Decides whether to render, defer, or drop video against the current audio clock.
import Foundation

/// Names the render, defer, and drop actions available when audio and video timestamps diverge.
public enum AVSyncDecisionAction: String, Codable, Equatable, Sendable {
    case renderNow
    case deferVideo
    case dropVideo
}

/// Names the timestamp relationship that explains each audio/video synchronization action.
public enum AVSyncDecisionReason: String, Codable, Equatable, Sendable {
    case insideAlignmentWindow
    case videoBehindWithinStaleThreshold
    case staleVideo
    case videoAheadOfAudio
}

/// Groups `action`, `reason`, `avOffsetMicroseconds`, and `audioDelayFramesAddedForVideo` into the public AVSyncDecision contract used by timing control.
public struct AVSyncDecision: Codable, Equatable, Sendable {
    public var action: AVSyncDecisionAction
    public var reason: AVSyncDecisionReason
    public var avOffsetMicroseconds: Double
    public var audioDelayFramesAddedForVideo: Int

    public init(
        action: AVSyncDecisionAction,
        reason: AVSyncDecisionReason,
        avOffsetMicroseconds: Double,
        audioDelayFramesAddedForVideo: Int = 0
    ) {
        self.action = action
        self.reason = reason
        self.avOffsetMicroseconds = avOffsetMicroseconds
        self.audioDelayFramesAddedForVideo = audioDelayFramesAddedForVideo
    }
}

/// Constrains `profile`, `audioMaster`, `audioMayDelayForVideo`, and `videoAlignmentToleranceMicroseconds` so timing and drift control tradeoffs remain explicit and testable.
public struct AVSyncPolicy: Codable, Equatable, Sendable {
    public var profile: SessionLatencyProfile
    // swiftlint:disable:next inclusive_language
    public var audioMaster: Bool
    public var audioMayDelayForVideo: Bool
    public var videoAlignmentToleranceMicroseconds: Double
    public var staleVideoDropThresholdMicroseconds: Double
    public var earlyVideoDeferThresholdMicroseconds: Double

    public init(
        profile: SessionLatencyProfile,
        // swiftlint:disable:next inclusive_language
        audioMaster: Bool,
        audioMayDelayForVideo: Bool,
        videoAlignmentToleranceMicroseconds: Double,
        staleVideoDropThresholdMicroseconds: Double,
        earlyVideoDeferThresholdMicroseconds: Double
    ) {
        self.profile = profile
        self.audioMaster = audioMaster
        self.audioMayDelayForVideo = audioMayDelayForVideo
        self.videoAlignmentToleranceMicroseconds = videoAlignmentToleranceMicroseconds
        self.staleVideoDropThresholdMicroseconds = staleVideoDropThresholdMicroseconds
        self.earlyVideoDeferThresholdMicroseconds = earlyVideoDeferThresholdMicroseconds
    }

    public static func policy(for profile: SessionLatencyProfile) -> AVSyncPolicy {
        switch profile {
        case .directAudioFirst:
            AVSyncPolicy(
                profile: profile,
                audioMaster: true,
                audioMayDelayForVideo: false,
                videoAlignmentToleranceMicroseconds: 0,
                staleVideoDropThresholdMicroseconds: 0,
                earlyVideoDeferThresholdMicroseconds: 0
            )
        case .balancedAV:
            AVSyncPolicy(
                profile: profile,
                audioMaster: true,
                audioMayDelayForVideo: false,
                videoAlignmentToleranceMicroseconds: 20_000,
                staleVideoDropThresholdMicroseconds: 40_000,
                earlyVideoDeferThresholdMicroseconds: 20_000
            )
        case .multiVideoPerformance:
            AVSyncPolicy(
                profile: profile,
                audioMaster: true,
                audioMayDelayForVideo: false,
                videoAlignmentToleranceMicroseconds: 10_000,
                staleVideoDropThresholdMicroseconds: 20_000,
                earlyVideoDeferThresholdMicroseconds: 10_000
            )
        case .wanStable:
            AVSyncPolicy(
                profile: profile,
                audioMaster: true,
                audioMayDelayForVideo: false,
                videoAlignmentToleranceMicroseconds: 50_000,
                staleVideoDropThresholdMicroseconds: 120_000,
                earlyVideoDeferThresholdMicroseconds: 50_000
            )
        }
    }
}

/// Aligns audio and video timestamps while retaining the decision behind each correction.
public enum AVTimestampAligner {
    public static func decision(
        videoTimestampNanoseconds: UInt64,
        audioPlayoutTimestampNanoseconds: UInt64,
        policy: AVSyncPolicy
    ) -> AVSyncDecision {
        let offsetMicroseconds = signedDeltaMicroseconds(
            lhsNanoseconds: videoTimestampNanoseconds,
            rhsNanoseconds: audioPlayoutTimestampNanoseconds
        )
        let absoluteOffset = abs(offsetMicroseconds)
        if absoluteOffset <= policy.videoAlignmentToleranceMicroseconds {
            return AVSyncDecision(
                action: .renderNow,
                reason: .insideAlignmentWindow,
                avOffsetMicroseconds: offsetMicroseconds
            )
        }
        if offsetMicroseconds > policy.earlyVideoDeferThresholdMicroseconds {
            return AVSyncDecision(
                action: .deferVideo,
                reason: .videoAheadOfAudio,
                avOffsetMicroseconds: offsetMicroseconds
            )
        }
        if offsetMicroseconds < -policy.staleVideoDropThresholdMicroseconds {
            return AVSyncDecision(
                action: .dropVideo,
                reason: .staleVideo,
                avOffsetMicroseconds: offsetMicroseconds
            )
        }
        return AVSyncDecision(
            action: .renderNow,
            reason: .videoBehindWithinStaleThreshold,
            avOffsetMicroseconds: offsetMicroseconds
        )
    }
}

/// Tracks `policy`, `audioTimestampOrigin`, `videoTimestampOrigin`, and `audioRouteAge` to expose latency, pressure, and delivery outcomes in timing and drift control.
public struct AVSyncTimingMetrics: Codable, Equatable, Sendable {
    public var policy: AVSyncPolicy
    public var audioTimestampOrigin: MediaTimestampOrigin
    public var videoTimestampOrigin: MediaTimestampOrigin
    public var audioRouteAge: UdpPcmPacketAgeMetrics
    public var videoFrameAge: UdpPcmPacketAgeMetrics
    public var avOffset: UdpPcmPacketAgeMetrics
    public var jitter: UdpPcmPacketAgeMetrics
    public var drift: MediaClockDriftEstimate?
    public var videoFramesAligned: Int
    public var videoFramesDeferred: Int
    public var videoFramesDroppedForSync: Int
    public var audioDelayFramesAddedForVideo: Int
    public var offsetMeasurementMethod: String

    public struct ClockOrigins: Equatable, Sendable {
        public var policy: AVSyncPolicy
        public var audioTimestampOrigin: MediaTimestampOrigin
        public var videoTimestampOrigin: MediaTimestampOrigin

        public init(
            policy: AVSyncPolicy,
            audioTimestampOrigin: MediaTimestampOrigin,
            videoTimestampOrigin: MediaTimestampOrigin
        ) {
            self.policy = policy
            self.audioTimestampOrigin = audioTimestampOrigin
            self.videoTimestampOrigin = videoTimestampOrigin
        }
    }

    public struct Measurements: Equatable, Sendable {
        public var audioRouteAge: UdpPcmPacketAgeMetrics
        public var videoFrameAge: UdpPcmPacketAgeMetrics
        public var avOffset: UdpPcmPacketAgeMetrics
        public var jitter: UdpPcmPacketAgeMetrics
        public var drift: MediaClockDriftEstimate?

        public init(
            audioRouteAge: UdpPcmPacketAgeMetrics,
            videoFrameAge: UdpPcmPacketAgeMetrics,
            avOffset: UdpPcmPacketAgeMetrics,
            jitter: UdpPcmPacketAgeMetrics,
            drift: MediaClockDriftEstimate?
        ) {
            self.audioRouteAge = audioRouteAge
            self.videoFrameAge = videoFrameAge
            self.avOffset = avOffset
            self.jitter = jitter
            self.drift = drift
        }
    }

    public struct Alignment: Equatable, Sendable {
        public var videoFramesAligned: Int
        public var videoFramesDeferred: Int
        public var videoFramesDroppedForSync: Int
        public var audioDelayFramesAddedForVideo: Int
        public var offsetMeasurementMethod: String

        public init(
            videoFramesAligned: Int,
            videoFramesDeferred: Int,
            videoFramesDroppedForSync: Int,
            audioDelayFramesAddedForVideo: Int,
            offsetMeasurementMethod: String
        ) {
            self.videoFramesAligned = videoFramesAligned
            self.videoFramesDeferred = videoFramesDeferred
            self.videoFramesDroppedForSync = videoFramesDroppedForSync
            self.audioDelayFramesAddedForVideo = audioDelayFramesAddedForVideo
            self.offsetMeasurementMethod = offsetMeasurementMethod
        }
    }

    public init(
        clockOrigins: ClockOrigins,
        measurements: Measurements,
        alignment: Alignment
    ) {
        self.policy = clockOrigins.policy
        self.audioTimestampOrigin = clockOrigins.audioTimestampOrigin
        self.videoTimestampOrigin = clockOrigins.videoTimestampOrigin
        self.audioRouteAge = measurements.audioRouteAge
        self.videoFrameAge = measurements.videoFrameAge
        self.avOffset = measurements.avOffset
        self.jitter = measurements.jitter
        self.drift = measurements.drift
        self.videoFramesAligned = alignment.videoFramesAligned
        self.videoFramesDeferred = alignment.videoFramesDeferred
        self.videoFramesDroppedForSync = alignment.videoFramesDroppedForSync
        self.audioDelayFramesAddedForVideo = alignment.audioDelayFramesAddedForVideo
        self.offsetMeasurementMethod = alignment.offsetMeasurementMethod
    }

    public func validate() throws {
        guard policy.audioMaster else {
            throw MediaClockValidationError.nonAudioMasterPolicy(policy.profile)
        }
        try VideoTransportValidator.requireNonNegative(
            policy.videoAlignmentToleranceMicroseconds,
            "avSync.policy.videoAlignmentToleranceMicroseconds"
        )
        try VideoTransportValidator.requireNonNegative(
            policy.staleVideoDropThresholdMicroseconds,
            "avSync.policy.staleVideoDropThresholdMicroseconds"
        )
        try VideoTransportValidator.requireNonNegative(
            policy.earlyVideoDeferThresholdMicroseconds,
            "avSync.policy.earlyVideoDeferThresholdMicroseconds"
        )
        try validateVideoPacketAge(audioRouteAge, field: "avSync.audioRouteAge")
        try validateVideoPacketAge(videoFrameAge, field: "avSync.videoFrameAge")
        try validateVideoPacketAge(avOffset, field: "avSync.avOffset")
        try validateVideoPacketAge(jitter, field: "avSync.jitter")
        try validateDriftEstimate(drift)
        try VideoTransportValidator.requireNonNegative(videoFramesAligned, "avSync.videoFramesAligned")
        try VideoTransportValidator.requireNonNegative(videoFramesDeferred, "avSync.videoFramesDeferred")
        try VideoTransportValidator.requireNonNegative(
            videoFramesDroppedForSync,
            "avSync.videoFramesDroppedForSync"
        )
        try VideoTransportValidator.requireNonNegative(
            audioDelayFramesAddedForVideo,
            "avSync.audioDelayFramesAddedForVideo"
        )
        try VideoTransportValidator.requireNonEmpty(offsetMeasurementMethod, "avSync.offsetMeasurementMethod")
        if !policy.audioMayDelayForVideo && audioDelayFramesAddedForVideo > 0 {
            throw MediaClockValidationError.audioDelayAddedForVideo(
                profile: policy.profile,
                frames: audioDelayFramesAddedForVideo
            )
        }
    }
}

private func validateDriftEstimate(_ drift: MediaClockDriftEstimate?) throws {
    guard let drift else {
        return
    }
    try VideoTransportValidator.requirePositive(drift.sampleCount, "avSync.drift.sampleCount")
    try VideoTransportValidator.requireFinite(drift.offsetMicroseconds, "avSync.drift.offsetMicroseconds")
    try VideoTransportValidator.requireFinite(
        drift.driftSlopePartsPerMillion,
        "avSync.drift.driftSlopePartsPerMillion"
    )
}

func signedDeltaMicroseconds(lhsNanoseconds: UInt64, rhsNanoseconds: UInt64) -> Double {
    if lhsNanoseconds >= rhsNanoseconds {
        return Double(lhsNanoseconds - rhsNanoseconds) / 1_000
    }
    return -Double(rhsNanoseconds - lhsNanoseconds) / 1_000
}
