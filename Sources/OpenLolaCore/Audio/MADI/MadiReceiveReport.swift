import Dispatch
import Foundation

public struct MadiReceiveSyntheticMeasurement: Codable, Equatable, Sendable {
    public var channelCount: Int
    public var framesPerPacket: Int
    public var sampleRateHertz: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var inputPayloadByteCount: Int
    public var outputPayloadByteCount: Int
    public var packetFragmentCount: Int
    public var depacketizationMicroseconds: Double
    public var rxLatencyFrames: Int
    public var rxLatencyPackets: Int
    public var rxLatencyMicroseconds: Double
    public var allocationWarnings: Int
    public var underruns: Int
    public var overruns: Int
    public var futurePackets: Int
    public var fragmentLostPackets: Int

    public init(
        channelCount: Int,
        framesPerPacket: Int,
        sampleRateHertz: Int,
        sampleFormat: UdpPcmSampleFormat,
        inputPayloadByteCount: Int,
        outputPayloadByteCount: Int,
        packetFragmentCount: Int,
        depacketizationMicroseconds: Double,
        rxLatencyFrames: Int,
        rxLatencyPackets: Int,
        rxLatencyMicroseconds: Double,
        allocationWarnings: Int,
        underruns: Int,
        overruns: Int,
        futurePackets: Int = 0,
        fragmentLostPackets: Int
    ) {
        self.channelCount = channelCount
        self.framesPerPacket = framesPerPacket
        self.sampleRateHertz = sampleRateHertz
        self.sampleFormat = sampleFormat
        self.inputPayloadByteCount = inputPayloadByteCount
        self.outputPayloadByteCount = outputPayloadByteCount
        self.packetFragmentCount = packetFragmentCount
        self.depacketizationMicroseconds = depacketizationMicroseconds
        self.rxLatencyFrames = rxLatencyFrames
        self.rxLatencyPackets = rxLatencyPackets
        self.rxLatencyMicroseconds = rxLatencyMicroseconds
        self.allocationWarnings = allocationWarnings
        self.underruns = underruns
        self.overruns = overruns
        self.futurePackets = futurePackets
        self.fragmentLostPackets = fragmentLostPackets
    }
}

public struct MadiReceiveSyntheticReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var measurements: [MadiReceiveSyntheticMeasurement]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        measurements: [MadiReceiveSyntheticMeasurement],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.measurements = measurements
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try MadiReceiveValidator.requireNonEmpty(id, "id")
        try MadiReceiveValidator.requireNonEmpty(capturedAt, "capturedAt")
        try MadiReceiveValidator.requireNonEmpty(notes, "notes")
        let requiredChannelCounts = Set(madiSyntheticRequiredChannelCounts)
        guard Set(measurements.map(\.channelCount)).isSuperset(of: requiredChannelCounts) else {
            throw MadiReceiveError.transportModeMismatch("requiredChannelCounts")
        }
        for measurement in measurements {
            try validate(measurement)
        }
        if verdict == .pass {
            throw MadiReceiveError.passRequiresPhysicalRmeEvidence
        }
    }

    private func validate(_ measurement: MadiReceiveSyntheticMeasurement) throws {
        try MadiReceiveValidator.requirePositive(measurement.channelCount, "measurement.channelCount")
        try MadiReceiveValidator.requirePositive(measurement.framesPerPacket, "measurement.framesPerPacket")
        try MadiReceiveValidator.requirePositive(measurement.sampleRateHertz, "measurement.sampleRateHertz")
        try MadiReceiveValidator.requirePositive(
            measurement.inputPayloadByteCount,
            "measurement.inputPayloadByteCount"
        )
        try MadiReceiveValidator.requirePositive(
            measurement.outputPayloadByteCount,
            "measurement.outputPayloadByteCount"
        )
        try MadiReceiveValidator.requirePositive(
            measurement.packetFragmentCount,
            "measurement.packetFragmentCount"
        )
        try MadiReceiveValidator.requireNonNegative(
            measurement.depacketizationMicroseconds,
            "measurement.depacketizationMicroseconds"
        )
        try MadiReceiveValidator.requireNonNegative(
            measurement.rxLatencyFrames,
            "measurement.rxLatencyFrames"
        )
        try MadiReceiveValidator.requireNonNegative(
            measurement.rxLatencyPackets,
            "measurement.rxLatencyPackets"
        )
        try MadiReceiveValidator.requireNonNegative(
            measurement.rxLatencyMicroseconds,
            "measurement.rxLatencyMicroseconds"
        )
        try MadiReceiveValidator.requireNonNegative(
            measurement.allocationWarnings,
            "measurement.allocationWarnings"
        )
        try MadiReceiveValidator.requireNonNegative(measurement.underruns, "measurement.underruns")
        try MadiReceiveValidator.requireNonNegative(measurement.overruns, "measurement.overruns")
        try MadiReceiveValidator.requireNonNegative(measurement.futurePackets, "measurement.futurePackets")
        try MadiReceiveValidator.requireNonNegative(
            measurement.fragmentLostPackets,
            "measurement.fragmentLostPackets"
        )
    }
}

public enum MadiReceiveSyntheticSmoke {
    public static func run() throws -> MadiReceiveSyntheticReport {
        let measurements = try madiSyntheticRequiredChannelCounts.map { channelCount in
            try measure(channelCount: channelCount)
        }
        return MadiReceiveSyntheticReport(
            id: "m04-madi-rx-synthetic-depacketization",
            capturedAt: "2026-05-04T00:00:00Z",
            measurements: measurements,
            verdict: .partial,
            notes: "Synthetic MADI RX only; physical RME multichannel output evidence is required for PASS."
        )
    }

    private static func measure(channelCount: Int) throws -> MadiReceiveSyntheticMeasurement {
        let mode = try audioTransportMode(channelCount: channelCount)
        let payload = SyntheticAudioPayload.make(seed: 0, byteCount: mode.payloadByteCount)
        let packets = try UdpPcmV2Packetizer.packetize(
            payload,
            sequenceNumber: 0,
            senderFrameIndex: 0,
            senderHostTimeNanoseconds: 1,
            mode: mode
        )
        var receiver = try MadiReceiveEngine(
            configuration: MadiReceiveConfiguration(mode: mode)
        )

        let start = DispatchTime.now().uptimeNanoseconds
        for packet in packets {
            _ = try receiver.receive(packet, receivedAtHostTimeNanoseconds: 2)
        }
        _ = receiver.renderCallback()
        let rendered = receiver.renderCallback()
        let end = DispatchTime.now().uptimeNanoseconds

        guard case .played(let block) = rendered, block.payload == payload else {
            throw MadiReceiveError.transportModeMismatch("renderedPayload")
        }

        return MadiReceiveSyntheticMeasurement(
            channelCount: channelCount,
            framesPerPacket: mode.framesPerPacket,
            sampleRateHertz: mode.sampleRateHertz,
            sampleFormat: mode.sampleFormat,
            inputPayloadByteCount: mode.payloadByteCount,
            outputPayloadByteCount: block.payload.count,
            packetFragmentCount: packets.count,
            depacketizationMicroseconds: Double(end - start) / 1_000,
            rxLatencyFrames: block.latency.frames,
            rxLatencyPackets: block.latency.packets,
            rxLatencyMicroseconds: block.latency.microseconds,
            allocationWarnings: receiver.metrics.allocationWarnings,
            underruns: receiver.metrics.underruns,
            overruns: receiver.metrics.overruns,
            futurePackets: receiver.metrics.futurePackets,
            fragmentLostPackets: receiver.metrics.fragmentLostPackets
        )
    }

    private static func audioTransportMode(channelCount: Int) throws -> AudioTransportMode {
        let framesPerPacket = 32
        let sampleRateHertz = 48_000
        let sampleFormat = UdpPcmSampleFormat.float32LittleEndian
        let fragments = try UdpPcmV2FragmentPlanner.plan(
            UdpPcmV2FragmentPlanRequest(
                streamID: 1,
                totalChannelCount: channelCount,
                framesPerPacket: framesPerPacket,
                sampleRateHertz: sampleRateHertz,
                sampleFormat: sampleFormat,
                maxTransmissionUnitBytes: 1_200,
                maxFragmentsPerDeadline: 16,
                metadataRevision: 3,
                packingMode: .interleavedChannelRange
            )
        )
        return AudioTransportMode(
            protocolVersion: .udpPcmV2,
            sampleRateHertz: sampleRateHertz,
            framesPerPacket: framesPerPacket,
            channelCount: channelCount,
            sampleFormat: sampleFormat,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct,
            maxTransmissionUnitBytes: 1_200,
            channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
            fragments: fragments
        )
    }
}

private enum MadiReceiveValidator: ReportValidationProtocol {
    typealias ValidationError = MadiReceiveError
}
