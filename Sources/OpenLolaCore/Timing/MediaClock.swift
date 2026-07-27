// Converts host time and frame indices into media-clock anchors, packets, and drift estimates.
import Foundation

/// Reports `invalidSampleRate`, `invalidStreamID`, `invalidTimestamp`, and `insufficientDriftSamples` failures that stop invalid timing and drift control work before it reaches a live path.
public enum MediaClockValidationError: Error, Equatable, Sendable {
    case invalidSampleRate(Int)
    case invalidStreamID(UInt32)
    case invalidTimestamp(UInt64)
    case insufficientDriftSamples(Int)
    // swiftlint:disable:next inclusive_language
    case nonAudioMasterPolicy(SessionLatencyProfile)
    case nonMonotonicTimestamp(previous: UInt64, next: UInt64)
    case zeroRemoteDuration
    case audioDelayAddedForVideo(profile: SessionLatencyProfile, frames: Int)
}

/// Provides monotonic timestamp construction, comparison, and validation for audio/video alignment.
public enum MediaClock {
    public static func nanoseconds(forFrameCount frameCount: UInt64, sampleRateHertz: Int) -> UInt64 {
        guard sampleRateHertz > 0 else {
            return 0
        }
        let divisor = UInt64(sampleRateHertz)
        let product = frameCount.multipliedFullWidth(by: 1_000_000_000)
        guard product.high < divisor else {
            return UInt64.max
        }
        let division = divisor.dividingFullWidth(product)
        let roundingThreshold = (divisor + 1) / 2
        guard division.remainder >= roundingThreshold else {
            return division.quotient
        }
        let (rounded, overflow) = division.quotient.addingReportingOverflow(1)
        return overflow ? UInt64.max : rounded
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

/// Groups `senderFrameIndex`, `hostTimeNanoseconds`, and `sampleRateHertz` into the public MediaClockAnchor contract used by timing control.
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

/// Defines `audioPacketSenderHostTimeNanoseconds`, `audioPacketSenderFrameIndex`, `videoPacketTimestampNanoseconds`, and `syntheticMonotonicNanoseconds` states used to make media timestamp origin decisions in timing and drift control.
public enum MediaTimestampOrigin: String, Codable, Equatable, Sendable {
    case audioPacketSenderHostTimeNanoseconds
    case audioPacketSenderFrameIndex
    case videoPacketTimestampNanoseconds
    case syntheticMonotonicNanoseconds
}

/// Associates `streamID`, `sequenceNumber`, `observedPayloadType`, and `senderFrameIndex` with one packet before timing control validates or forwards it.
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

/// Summarizes `sampleCount`, `remoteDurationNanoseconds`, `localDurationNanoseconds`, and `offsetMicroseconds` calculated from timing observations in timing control.
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

/// Calculates media clock drift from successive timing observations in timing and drift control.
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
