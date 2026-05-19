import Foundation

public enum MediaClockValidationError: Error, Equatable, Sendable {
    case invalidSampleRate(Int)
    case invalidStreamID(UInt32)
    case invalidTimestamp(UInt64)
    case insufficientDriftSamples(Int)
    case nonAudioMasterPolicy(SessionLatencyProfile)
    case nonMonotonicTimestamp(previous: UInt64, next: UInt64)
    case zeroRemoteDuration
    case audioDelayAddedForVideo(profile: SessionLatencyProfile, frames: Int)
}

public enum MediaClock {
    public static func nanoseconds(forFrameCount frameCount: UInt64, sampleRateHertz: Int) -> UInt64 {
        guard sampleRateHertz > 0 else {
            return 0
        }
        let divisor = UInt64(sampleRateHertz)
        let product = frameCount.multipliedFullWidth(by: 1_000_000_000)
        guard product.high < divisor else {
            preconditionFailure("MediaClock.nanoseconds overflow")
        }
        let division = divisor.dividingFullWidth(product)
        let roundingThreshold = (divisor + 1) / 2
        return division.quotient + (division.remainder >= roundingThreshold ? 1 : 0)
    }

    public static func validateMonotonicHostTimes(_ hostTimes: [UInt64]) throws {
        guard var previous = hostTimes.first else {
            return
        }
        for next in hostTimes.dropFirst() {
            guard next > previous else {
                throw MediaClockValidationError.nonMonotonicTimestamp(
                    previous: previous,
                    next: next
                )
            }
            previous = next
        }
    }
}

public struct MediaClockAnchor: Codable, Equatable, Sendable {
    public var senderFrameIndex: UInt64
    public var hostTimeNanoseconds: UInt64
    public var sampleRateHertz: Int

    public init(
        senderFrameIndex: UInt64,
        hostTimeNanoseconds: UInt64,
        sampleRateHertz: Int
    ) {
        self.senderFrameIndex = senderFrameIndex
        self.hostTimeNanoseconds = hostTimeNanoseconds
        self.sampleRateHertz = sampleRateHertz
    }

    public func validate() throws {
        guard sampleRateHertz > 0 else {
            throw MediaClockValidationError.invalidSampleRate(sampleRateHertz)
        }
        guard hostTimeNanoseconds > 0 else {
            throw MediaClockValidationError.invalidTimestamp(hostTimeNanoseconds)
        }
    }

    public func hostTimeNanoseconds(forFrameIndex frameIndex: UInt64) -> UInt64 {
        guard frameIndex >= senderFrameIndex else {
            return hostTimeNanoseconds
        }
        guard sampleRateHertz > 0 else {
            return hostTimeNanoseconds
        }
        let frameDelta = frameIndex - senderFrameIndex
        let roundedDelta = MediaClock.nanoseconds(
            forFrameCount: frameDelta,
            sampleRateHertz: sampleRateHertz
        )
        let (hostTime, overflow) = hostTimeNanoseconds.addingReportingOverflow(roundedDelta)
        return overflow ? UInt64.max : hostTime
    }

    public func ageMicroseconds(observedAtNanoseconds: UInt64) -> Double {
        signedDeltaMicroseconds(
            lhsNanoseconds: observedAtNanoseconds,
            rhsNanoseconds: hostTimeNanoseconds
        )
    }
}

public enum MediaTimestampOrigin: String, Codable, Equatable, Sendable {
    case audioPacketSenderHostTimeNanoseconds
    case audioPacketSenderFrameIndex
    case videoPacketTimestampNanoseconds
    case syntheticMonotonicNanoseconds
}

public struct MediaTimingPacket: Codable, Equatable, Sendable {
    public var streamID: UInt32
    public var sequenceNumber: UInt64
    public var observedPayloadType: SessionPayloadType
    public var senderFrameIndex: UInt64?
    public var remoteSenderTimeNanoseconds: UInt64
    public var localObservationTimeNanoseconds: UInt64
    public var timestampOrigin: MediaTimestampOrigin

    public var observedAgeMicroseconds: Double {
        signedDeltaMicroseconds(
            lhsNanoseconds: localObservationTimeNanoseconds,
            rhsNanoseconds: remoteSenderTimeNanoseconds
        )
    }

    public init(
        streamID: UInt32,
        sequenceNumber: UInt64,
        observedPayloadType: SessionPayloadType,
        senderFrameIndex: UInt64?,
        remoteSenderTimeNanoseconds: UInt64,
        localObservationTimeNanoseconds: UInt64,
        timestampOrigin: MediaTimestampOrigin
    ) {
        self.streamID = streamID
        self.sequenceNumber = sequenceNumber
        self.observedPayloadType = observedPayloadType
        self.senderFrameIndex = senderFrameIndex
        self.remoteSenderTimeNanoseconds = remoteSenderTimeNanoseconds
        self.localObservationTimeNanoseconds = localObservationTimeNanoseconds
        self.timestampOrigin = timestampOrigin
    }

    public init(
        audioPacket: UdpPcmPacket,
        streamID: UInt32,
        localObservationTimeNanoseconds: UInt64
    ) throws {
        self.init(
            streamID: streamID,
            sequenceNumber: audioPacket.header.sequenceNumber,
            observedPayloadType: .audioPcmV2,
            senderFrameIndex: audioPacket.header.senderFrameIndex,
            remoteSenderTimeNanoseconds: audioPacket.header.senderHostTimeNanoseconds,
            localObservationTimeNanoseconds: localObservationTimeNanoseconds,
            timestampOrigin: .audioPacketSenderHostTimeNanoseconds
        )
        try validate()
    }

    public init(
        audioV2Packet: UdpPcmV2Packet,
        localObservationTimeNanoseconds: UInt64
    ) throws {
        self.init(
            streamID: audioV2Packet.header.streamID,
            sequenceNumber: audioV2Packet.header.sequenceNumber,
            observedPayloadType: .audioPcmV2,
            senderFrameIndex: audioV2Packet.header.senderFrameIndex,
            remoteSenderTimeNanoseconds: audioV2Packet.header.senderHostTimeNanoseconds,
            localObservationTimeNanoseconds: localObservationTimeNanoseconds,
            timestampOrigin: .audioPacketSenderHostTimeNanoseconds
        )
        try validate()
    }

    public init(
        videoPacket: VideoTransportPacket,
        localObservationTimeNanoseconds: UInt64
    ) throws {
        self.init(
            streamID: videoPacket.streamID,
            sequenceNumber: videoPacket.sequenceNumber,
            observedPayloadType: .videoRawFrameFragment,
            senderFrameIndex: nil,
            remoteSenderTimeNanoseconds: videoPacket.timestampNanoseconds,
            localObservationTimeNanoseconds: localObservationTimeNanoseconds,
            timestampOrigin: .videoPacketTimestampNanoseconds
        )
        try validate()
    }

    public func validate() throws {
        guard streamID > 0 else {
            throw MediaClockValidationError.invalidStreamID(streamID)
        }
        guard localObservationTimeNanoseconds > 0 else {
            throw MediaClockValidationError.invalidTimestamp(localObservationTimeNanoseconds)
        }
    }
}

public struct MediaClockDriftEstimate: Codable, Equatable, Sendable {
    public var sampleCount: Int
    public var remoteDurationNanoseconds: UInt64
    public var localDurationNanoseconds: UInt64
    public var offsetMicroseconds: Double
    public var driftSlopePartsPerMillion: Double
    public var correctionBoundary: DriftCorrectionLocation

    public init(
        sampleCount: Int,
        remoteDurationNanoseconds: UInt64,
        localDurationNanoseconds: UInt64,
        offsetMicroseconds: Double,
        driftSlopePartsPerMillion: Double,
        correctionBoundary: DriftCorrectionLocation = .outsideCallback
    ) {
        self.sampleCount = sampleCount
        self.remoteDurationNanoseconds = remoteDurationNanoseconds
        self.localDurationNanoseconds = localDurationNanoseconds
        self.offsetMicroseconds = offsetMicroseconds
        self.driftSlopePartsPerMillion = driftSlopePartsPerMillion
        self.correctionBoundary = correctionBoundary
    }
}

public enum MediaClockDriftEstimator {
    public static func estimate(
        from packets: [MediaTimingPacket],
        correctionBoundary: DriftCorrectionLocation = .outsideCallback
    ) throws -> MediaClockDriftEstimate {
        guard packets.count >= 2 else {
            throw MediaClockValidationError.insufficientDriftSamples(packets.count)
        }
        for packet in packets {
            try packet.validate()
        }
        try MediaClock.validateMonotonicHostTimes(packets.map(\.localObservationTimeNanoseconds))
        try MediaClock.validateMonotonicHostTimes(packets.map(\.remoteSenderTimeNanoseconds))

        let first = packets[0]
        let last = packets[packets.count - 1]
        let remoteDuration = last.remoteSenderTimeNanoseconds - first.remoteSenderTimeNanoseconds
        guard remoteDuration > 0 else {
            throw MediaClockValidationError.zeroRemoteDuration
        }
        let localDuration = last.localObservationTimeNanoseconds - first.localObservationTimeNanoseconds
        let driftSlope = (
            Double(localDuration) - Double(remoteDuration)
        ) / Double(remoteDuration) * 1_000_000

        return MediaClockDriftEstimate(
            sampleCount: packets.count,
            remoteDurationNanoseconds: remoteDuration,
            localDurationNanoseconds: localDuration,
            offsetMicroseconds: last.observedAgeMicroseconds,
            driftSlopePartsPerMillion: driftSlope,
            correctionBoundary: correctionBoundary
        )
    }
}

public enum AVSyncDecisionAction: String, Codable, Equatable, Sendable {
    case renderNow
    case deferVideo
    case dropVideo
}

public enum AVSyncDecisionReason: String, Codable, Equatable, Sendable {
    case insideAlignmentWindow
    case staleVideo
    case videoAheadOfAudio
}

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

public struct AVSyncPolicy: Codable, Equatable, Sendable {
    public var profile: SessionLatencyProfile
    public var audioMaster: Bool
    public var audioMayDelayForVideo: Bool
    public var videoAlignmentToleranceMicroseconds: Double
    public var staleVideoDropThresholdMicroseconds: Double
    public var earlyVideoDeferThresholdMicroseconds: Double

    public init(
        profile: SessionLatencyProfile,
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
        return AVSyncDecision(
            action: .dropVideo,
            reason: .staleVideo,
            avOffsetMicroseconds: offsetMicroseconds
        )
    }
}

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

    public init(
        policy: AVSyncPolicy,
        audioTimestampOrigin: MediaTimestampOrigin,
        videoTimestampOrigin: MediaTimestampOrigin,
        audioRouteAge: UdpPcmPacketAgeMetrics,
        videoFrameAge: UdpPcmPacketAgeMetrics,
        avOffset: UdpPcmPacketAgeMetrics,
        jitter: UdpPcmPacketAgeMetrics,
        drift: MediaClockDriftEstimate?,
        videoFramesAligned: Int,
        videoFramesDeferred: Int,
        videoFramesDroppedForSync: Int,
        audioDelayFramesAddedForVideo: Int,
        offsetMeasurementMethod: String
    ) {
        self.policy = policy
        self.audioTimestampOrigin = audioTimestampOrigin
        self.videoTimestampOrigin = videoTimestampOrigin
        self.audioRouteAge = audioRouteAge
        self.videoFrameAge = videoFrameAge
        self.avOffset = avOffset
        self.jitter = jitter
        self.drift = drift
        self.videoFramesAligned = videoFramesAligned
        self.videoFramesDeferred = videoFramesDeferred
        self.videoFramesDroppedForSync = videoFramesDroppedForSync
        self.audioDelayFramesAddedForVideo = audioDelayFramesAddedForVideo
        self.offsetMeasurementMethod = offsetMeasurementMethod
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
        try validateMediaPacketAge(audioRouteAge, "avSync.audioRouteAge")
        try validateMediaPacketAge(videoFrameAge, "avSync.videoFrameAge")
        try validateMediaPacketAge(avOffset, "avSync.avOffset")
        try validateMediaPacketAge(jitter, "avSync.jitter")
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

private func signedDeltaMicroseconds(lhsNanoseconds: UInt64, rhsNanoseconds: UInt64) -> Double {
    if lhsNanoseconds >= rhsNanoseconds {
        return Double(lhsNanoseconds - rhsNanoseconds) / 1_000
    }
    return -Double(rhsNanoseconds - lhsNanoseconds) / 1_000
}

private func validateMediaPacketAge(_ metrics: UdpPcmPacketAgeMetrics, _ field: String) throws {
    try VideoTransportValidator.requireNonNegative(metrics.p50Microseconds, "\(field).p50Microseconds")
    try VideoTransportValidator.requireNonNegative(metrics.p95Microseconds, "\(field).p95Microseconds")
    try VideoTransportValidator.requireNonNegative(metrics.p99Microseconds, "\(field).p99Microseconds")
    try VideoTransportValidator.requireNonNegative(metrics.maxMicroseconds, "\(field).maxMicroseconds")
    guard timingPercentilesAreOrdered(
        p50: metrics.p50Microseconds,
        p95: metrics.p95Microseconds,
        p99: metrics.p99Microseconds,
        max: metrics.maxMicroseconds
    ) else {
        throw VideoTransportValidationError.unorderedFrameAge
    }
}
