import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Converts host time and frame indices into media-clock anchors, packets, and drift estimates.
import Foundation

/// Reports `invalidSampleRate`, `invalidStreamID`, `invalidTimestamp`, and `insufficientDriftSamples` failures that stop invalid timing and drift control work before it reaches a live path.
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
