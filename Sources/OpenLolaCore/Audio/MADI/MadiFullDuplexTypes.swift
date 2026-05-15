import Foundation
import OpenLolaContracts

public enum MadiFullDuplexRunMode: String, Codable, Equatable, Sendable {
    case sourceLevel
    case networkRuntime
    case measuredPhysical
}

public enum MadiFullDuplexCorrectionAction: String, Codable, Equatable, Sendable {
    case none
    case insertFrame
    case dropFrame
}

public enum MadiFullDuplexError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unsupportedPayloadType(SessionPayloadType)
    case disabledAudioStream(Int)
    case noBidirectionalAudioStream
    case sampleRateMismatch(local: Int, remote: Int)
    case sampleFormatMismatch(local: UdpPcmSampleFormat, remote: UdpPcmSampleFormat)
    case framesPerPacketMismatch(local: Int, remote: Int)
    case asymmetricChannelCount(local: Int, remote: Int)
    case enabledVideoNotAllowed
    case passRequiresPhysicalRmeEvidence
    case correctionChangedInsideCallback
    case notStarted
}

public struct MadiFullDuplexAudioPair: Codable, Equatable, Sendable {
    public var localToRemote: AudioStreamDescription
    public var remoteToLocal: AudioStreamDescription
    public var allowsAsymmetricChannelCounts: Bool

    public init(
        localToRemote: AudioStreamDescription,
        remoteToLocal: AudioStreamDescription,
        allowsAsymmetricChannelCounts: Bool = false
    ) throws {
        self.localToRemote = localToRemote
        self.remoteToLocal = remoteToLocal
        self.allowsAsymmetricChannelCounts = allowsAsymmetricChannelCounts
        try validate()
    }

    public func validate() throws {
        try validateStream(localToRemote)
        try validateStream(remoteToLocal)
        guard localToRemote.sampleRateHertz == remoteToLocal.sampleRateHertz else {
            throw MadiFullDuplexError.sampleRateMismatch(
                local: localToRemote.sampleRateHertz,
                remote: remoteToLocal.sampleRateHertz
            )
        }
        guard localToRemote.sampleFormat == remoteToLocal.sampleFormat else {
            throw MadiFullDuplexError.sampleFormatMismatch(
                local: localToRemote.sampleFormat,
                remote: remoteToLocal.sampleFormat
            )
        }
        guard localToRemote.framesPerPacket == remoteToLocal.framesPerPacket else {
            throw MadiFullDuplexError.framesPerPacketMismatch(
                local: localToRemote.framesPerPacket,
                remote: remoteToLocal.framesPerPacket
            )
        }
        guard allowsAsymmetricChannelCounts
            || localToRemote.channelCount == remoteToLocal.channelCount else {
            throw MadiFullDuplexError.asymmetricChannelCount(
                local: localToRemote.channelCount,
                remote: remoteToLocal.channelCount
            )
        }
    }

    public func localSendMode(
        maxTransmissionUnitBytes: Int,
        maxFragmentsPerDeadline: Int,
        metadataRevision: Int,
        rxBufferProfile: RxBufferProfile = .direct
    ) throws -> AudioTransportMode {
        try Self.transportMode(
            for: localToRemote,
            maxTransmissionUnitBytes: maxTransmissionUnitBytes,
            maxFragmentsPerDeadline: maxFragmentsPerDeadline,
            metadataRevision: metadataRevision,
            rxBufferProfile: rxBufferProfile
        )
    }

    public func remoteReceiveMode(
        maxTransmissionUnitBytes: Int,
        maxFragmentsPerDeadline: Int,
        metadataRevision: Int,
        rxBufferProfile: RxBufferProfile = .direct
    ) throws -> AudioTransportMode {
        try Self.transportMode(
            for: remoteToLocal,
            maxTransmissionUnitBytes: maxTransmissionUnitBytes,
            maxFragmentsPerDeadline: maxFragmentsPerDeadline,
            metadataRevision: metadataRevision,
            rxBufferProfile: rxBufferProfile
        )
    }

    private func validateStream(_ stream: AudioStreamDescription) throws {
        try stream.validate()
        guard stream.payloadType == .audioPcmV2 else {
            throw MadiFullDuplexError.unsupportedPayloadType(stream.payloadType)
        }
        guard stream.direction != .disabled else {
            throw MadiFullDuplexError.disabledAudioStream(stream.id)
        }
    }

    private static func transportMode(
        for stream: AudioStreamDescription,
        maxTransmissionUnitBytes: Int,
        maxFragmentsPerDeadline: Int,
        metadataRevision: Int,
        rxBufferProfile: RxBufferProfile
    ) throws -> AudioTransportMode {
        let fragments = try UdpPcmV2FragmentPlanner.plan(
            UdpPcmV2FragmentPlanRequest(
                streamID: stream.id,
                totalChannelCount: stream.channelCount,
                framesPerPacket: stream.framesPerPacket,
                sampleRateHertz: stream.sampleRateHertz,
                sampleFormat: stream.sampleFormat,
                maxTransmissionUnitBytes: maxTransmissionUnitBytes,
                maxFragmentsPerDeadline: maxFragmentsPerDeadline,
                metadataRevision: metadataRevision,
                packingMode: .interleavedChannelRange
            )
        )
        return AudioTransportMode(
            protocolVersion: .udpPcmV2,
            sampleRateHertz: stream.sampleRateHertz,
            framesPerPacket: stream.framesPerPacket,
            channelCount: stream.channelCount,
            sampleFormat: stream.sampleFormat,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: rxBufferProfile,
            maxTransmissionUnitBytes: maxTransmissionUnitBytes,
            channelOrder: stream.channelOrder,
            fragments: fragments
        )
    }
}

public struct MadiFullDuplexCorrectionPolicy: Codable, Equatable, Sendable {
    public var driftThresholdPartsPerMillion: Double
    public var maxCorrectionFramesPerEvent: Int
    public var maxEventsPerMinute: Int

    public init(
        driftThresholdPartsPerMillion: Double = 100,
        maxCorrectionFramesPerEvent: Int = 1,
        maxEventsPerMinute: Int = 60
    ) {
        self.driftThresholdPartsPerMillion = driftThresholdPartsPerMillion
        self.maxCorrectionFramesPerEvent = maxCorrectionFramesPerEvent
        self.maxEventsPerMinute = maxEventsPerMinute
    }

    public func validate() throws {
        try requireM05PositiveFinite(
            driftThresholdPartsPerMillion,
            "driftThresholdPartsPerMillion"
        )
        try requireM05Positive(maxCorrectionFramesPerEvent, "maxCorrectionFramesPerEvent")
        try requireM05Positive(maxEventsPerMinute, "maxEventsPerMinute")
    }

    func correctionEvent(
        for estimate: MadiFullDuplexDriftEstimate,
        sequenceNumber: UInt64
    ) -> MadiFullDuplexCorrectionEvent? {
        let slope = estimate.driftSlopePartsPerMillion
        guard abs(slope) >= driftThresholdPartsPerMillion else {
            return nil
        }
        let unboundedFrames = Int((abs(slope) / driftThresholdPartsPerMillion).rounded(.up))
        return MadiFullDuplexCorrectionEvent(
            sequenceNumber: sequenceNumber,
            action: slope > 0 ? .insertFrame : .dropFrame,
            driftSlopePartsPerMillion: slope,
            correctionFrames: max(1, min(maxCorrectionFramesPerEvent, unboundedFrames)),
            changedInsideAudioCallback: false,
            reason: "bounded correction scheduled outside audio callback"
        )
    }
}

public struct MadiFullDuplexClockSample: Codable, Equatable, Sendable {
    public var senderFrameIndex: UInt64
    public var receiverPlayoutFrameIndex: UInt64
    public var localHostTimeNanoseconds: UInt64

    public init(
        senderFrameIndex: UInt64,
        receiverPlayoutFrameIndex: UInt64,
        localHostTimeNanoseconds: UInt64
    ) {
        self.senderFrameIndex = senderFrameIndex
        self.receiverPlayoutFrameIndex = receiverPlayoutFrameIndex
        self.localHostTimeNanoseconds = localHostTimeNanoseconds
    }
}

public struct MadiFullDuplexDriftEstimate: Codable, Equatable, Sendable {
    public var sampleCount: Int
    public var senderFrameDelta: UInt64
    public var receiverFrameDelta: UInt64
    public var driftSlopePartsPerMillion: Double

    public init(
        sampleCount: Int,
        senderFrameDelta: UInt64,
        receiverFrameDelta: UInt64,
        driftSlopePartsPerMillion: Double
    ) {
        self.sampleCount = sampleCount
        self.senderFrameDelta = senderFrameDelta
        self.receiverFrameDelta = receiverFrameDelta
        self.driftSlopePartsPerMillion = driftSlopePartsPerMillion
    }

    public func validate() throws {
        try requireM05Positive(sampleCount, "drift.sampleCount")
        try requireM05NonNegative(Double(senderFrameDelta), "drift.senderFrameDelta")
        try requireM05NonNegative(Double(receiverFrameDelta), "drift.receiverFrameDelta")
        try requireM05Finite(driftSlopePartsPerMillion, "drift.driftSlopePartsPerMillion")
    }
}

public struct MadiFullDuplexCorrectionEvent: Codable, Equatable, Sendable {
    public var sequenceNumber: UInt64
    public var action: MadiFullDuplexCorrectionAction
    public var driftSlopePartsPerMillion: Double
    public var correctionFrames: Int
    public var changedInsideAudioCallback: Bool
    public var reason: String

    public init(
        sequenceNumber: UInt64,
        action: MadiFullDuplexCorrectionAction,
        driftSlopePartsPerMillion: Double,
        correctionFrames: Int,
        changedInsideAudioCallback: Bool,
        reason: String
    ) {
        self.sequenceNumber = sequenceNumber
        self.action = action
        self.driftSlopePartsPerMillion = driftSlopePartsPerMillion
        self.correctionFrames = correctionFrames
        self.changedInsideAudioCallback = changedInsideAudioCallback
        self.reason = reason
    }

    public func validate() throws {
        try requireM05Finite(driftSlopePartsPerMillion, "correction.driftSlopePartsPerMillion")
        try requireM05Positive(correctionFrames, "correction.correctionFrames")
        try requireM05NonEmpty(reason, "correction.reason")
        guard !changedInsideAudioCallback else {
            throw MadiFullDuplexError.correctionChangedInsideCallback
        }
    }
}

public struct MadiFullDuplexDriftSimulationResult: Codable, Equatable, Sendable {
    public var samples: [MadiFullDuplexClockSample]
    public var estimate: MadiFullDuplexDriftEstimate
    public var correctionEvents: [MadiFullDuplexCorrectionEvent]

    public init(
        samples: [MadiFullDuplexClockSample],
        estimate: MadiFullDuplexDriftEstimate,
        correctionEvents: [MadiFullDuplexCorrectionEvent]
    ) {
        self.samples = samples
        self.estimate = estimate
        self.correctionEvents = correctionEvents
    }

    public func validate() throws {
        guard !samples.isEmpty else {
            throw MadiFullDuplexError.emptyField("samples")
        }
        try estimate.validate()
        for event in correctionEvents {
            try event.validate()
        }
    }
}

public enum MadiFullDuplexClockDriftSimulator {
    public static func run(
        sampleCount: Int,
        senderFrameStep: Int,
        receiverFrameStep: Int,
        correctionPolicy: MadiFullDuplexCorrectionPolicy
    ) throws -> MadiFullDuplexDriftSimulationResult {
        try requireM05Positive(sampleCount, "sampleCount")
        try requireM05Positive(senderFrameStep, "senderFrameStep")
        try requireM05Positive(receiverFrameStep, "receiverFrameStep")
        try correctionPolicy.validate()

        var samples: [MadiFullDuplexClockSample] = []
        samples.reserveCapacity(sampleCount)
        for index in 0..<sampleCount {
            samples.append(MadiFullDuplexClockSample(
                senderFrameIndex: UInt64(index * senderFrameStep),
                receiverPlayoutFrameIndex: UInt64(index * receiverFrameStep),
                localHostTimeNanoseconds: UInt64(index + 1)
            ))
        }
        let estimate = try estimate(from: samples)
        return MadiFullDuplexDriftSimulationResult(
            samples: samples,
            estimate: estimate,
            correctionEvents: correctionPolicy
                .correctionEvent(for: estimate, sequenceNumber: UInt64(sampleCount - 1))
                .map { [$0] } ?? []
        )
    }

    static func estimate(
        from samples: [MadiFullDuplexClockSample]
    ) throws -> MadiFullDuplexDriftEstimate {
        guard let first = samples.first, let last = samples.last else {
            throw MadiFullDuplexError.emptyField("samples")
        }
        guard last.senderFrameIndex >= first.senderFrameIndex else {
            throw MadiFullDuplexError.negativeField("senderFrameDelta")
        }
        guard last.receiverPlayoutFrameIndex >= first.receiverPlayoutFrameIndex else {
            throw MadiFullDuplexError.negativeField("receiverFrameDelta")
        }
        let senderDelta = last.senderFrameIndex - first.senderFrameIndex
        let receiverDelta = last.receiverPlayoutFrameIndex - first.receiverPlayoutFrameIndex
        guard senderDelta > 0 else {
            throw MadiFullDuplexError.nonPositiveField("senderFrameDelta")
        }
        let slope = (
            (Double(receiverDelta) - Double(senderDelta)) / Double(senderDelta)
        ) * 1_000_000
        return MadiFullDuplexDriftEstimate(
            sampleCount: samples.count,
            senderFrameDelta: senderDelta,
            receiverFrameDelta: receiverDelta,
            driftSlopePartsPerMillion: slope
        )
    }
}
