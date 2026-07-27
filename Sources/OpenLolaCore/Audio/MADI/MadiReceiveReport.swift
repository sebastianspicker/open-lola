// Builds and validates synthetic MADI receive measurements so recovery, latency, and overrun policy can be checked without device I/O.
import Dispatch
import Foundation

/// Records `channelCount`, `framesPerPacket`, `sampleRateHertz`, and `sampleFormat` observed while measuring packetization or receive behavior.
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
    public var futurePackets: Int = 0
    public var fragmentLostPackets: Int
}

/// Records `id`, `capturedAt`, `measurements`, and `verdict` so MADI full-duplex transport measurements and verdicts can be checked after a run.
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

/// Exercises a deterministic MADI full-duplex transport path so regressions remain reproducible without hardware.
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
                .init(
                    streamID: 1,
                    audio: .init(
                        totalChannelCount: channelCount,
                        framesPerPacket: framesPerPacket,
                        sampleRateHertz: sampleRateHertz,
                        sampleFormat: sampleFormat
                    ),
                    fragmentationLimits: .init(
                        maxTransmissionUnitBytes: 1_200,
                        maxFragmentsPerDeadline: 16
                    ),
                    metadata: .init(
                        metadataRevision: 3,
                        packingMode: .interleavedChannelRange
                    )
                )
            )
        )
        return AudioTransportMode(
            transport: .init(
                protocolVersion: .udpPcmV2,
                latencyProfile: .safeLowLatency,
                rxBufferProfile: .direct,
                maxTransmissionUnitBytes: 1_200
            ),
            format: .init(
                sampleRateHertz: sampleRateHertz,
                framesPerPacket: framesPerPacket,
                channelCount: channelCount,
                sampleFormat: sampleFormat
            ),
            layout: .init(
                channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
                fragments: fragments
            )
        )
    }
}
