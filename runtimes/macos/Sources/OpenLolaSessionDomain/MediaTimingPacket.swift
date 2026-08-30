/// Validation failures shared by media-clock domain values.
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

/// The source of a timestamp observed on a media packet.
public enum MediaTimestampOrigin: String, Codable, Equatable, Sendable {
    case audioPacketSenderHostTimeNanoseconds
    case audioPacketSenderFrameIndex
    case videoPacketTimestampNanoseconds
    case syntheticMonotonicNanoseconds
}

/// A transport-neutral timing observation for media synchronization.
public struct MediaTimingPacket: Codable, Equatable, Sendable {
    public var streamID: UInt32
    public var sequenceNumber: UInt64
    public var observedPayloadType: SessionPayloadType
    public var senderFrameIndex: UInt64?
    public var remoteSenderTimeNanoseconds: UInt64
    public var localObservationTimeNanoseconds: UInt64
    public var timestampOrigin: MediaTimestampOrigin

    public var observedAgeMicroseconds: Double {
        sessionTimingDeltaMicroseconds(
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

    public func validate() throws {
        guard streamID > 0 else {
            throw MediaClockValidationError.invalidStreamID(streamID)
        }
        guard localObservationTimeNanoseconds > 0 else {
            throw MediaClockValidationError.invalidTimestamp(localObservationTimeNanoseconds)
        }
    }
}

private func sessionTimingDeltaMicroseconds(
    lhsNanoseconds: UInt64,
    rhsNanoseconds: UInt64
) -> Double {
    if lhsNanoseconds >= rhsNanoseconds {
        return Double(lhsNanoseconds - rhsNanoseconds) / 1_000
    }
    return -Double(rhsNanoseconds - lhsNanoseconds) / 1_000
}
