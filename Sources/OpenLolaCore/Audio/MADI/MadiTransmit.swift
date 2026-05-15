import Dispatch
import Foundation

public struct MadiTransmitPacketizationMeasurement: Codable, Equatable, Sendable {
    public var channelCount: Int
    public var framesPerPacket: Int
    public var sampleRateHertz: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var payloadByteCount: Int
    public var packetFragmentCount: Int
    public var maxPacketByteCount: Int
    public var packetizationMicroseconds: Double
    public var allocationWarnings: Int

    public init(
        channelCount: Int,
        framesPerPacket: Int,
        sampleRateHertz: Int,
        sampleFormat: UdpPcmSampleFormat,
        payloadByteCount: Int,
        packetFragmentCount: Int,
        maxPacketByteCount: Int,
        packetizationMicroseconds: Double,
        allocationWarnings: Int
    ) {
        self.channelCount = channelCount
        self.framesPerPacket = framesPerPacket
        self.sampleRateHertz = sampleRateHertz
        self.sampleFormat = sampleFormat
        self.payloadByteCount = payloadByteCount
        self.packetFragmentCount = packetFragmentCount
        self.maxPacketByteCount = maxPacketByteCount
        self.packetizationMicroseconds = packetizationMicroseconds
        self.allocationWarnings = allocationWarnings
    }
}

public struct MadiTransmitSyntheticReport: PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var measurements: [MadiTransmitPacketizationMeasurement]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        measurements: [MadiTransmitPacketizationMeasurement],
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
        try requireMadiTransmitNonEmpty(id, "id")
        try requireMadiTransmitNonEmpty(capturedAt, "capturedAt")
        try requireMadiTransmitNonEmpty(notes, "notes")
        let requiredChannelCounts = Set(madiSyntheticRequiredChannelCounts)
        guard Set(measurements.map(\.channelCount)).isSuperset(of: requiredChannelCounts) else {
            throw MadiTransmitValidationError.missingRequiredChannelCounts
        }
        for measurement in measurements {
            try requireMadiTransmitPositive(measurement.channelCount, "measurement.channelCount")
            try requireMadiTransmitPositive(measurement.framesPerPacket, "measurement.framesPerPacket")
            try requireMadiTransmitPositive(measurement.sampleRateHertz, "measurement.sampleRateHertz")
            try requireMadiTransmitPositive(measurement.payloadByteCount, "measurement.payloadByteCount")
            try requireMadiTransmitPositive(measurement.packetFragmentCount, "measurement.packetFragmentCount")
            try requireMadiTransmitPositive(measurement.maxPacketByteCount, "measurement.maxPacketByteCount")
            try requireMadiTransmitNonNegative(
                measurement.packetizationMicroseconds,
                "measurement.packetizationMicroseconds"
            )
            try requireMadiTransmitNonNegative(
                measurement.allocationWarnings,
                "measurement.allocationWarnings"
            )
        }
        if verdict == .pass {
            throw MadiTransmitValidationError.passRequiresPhysicalRmeEvidence
        }
    }
}

public enum MadiTransmitValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError {
    case emptyField(String)
    case nonPositiveField(String)
    case negativeField(String)
    case missingRequiredChannelCounts
    case passRequiresPhysicalRmeEvidence
}

public enum MadiTransmitSyntheticSmoke {
    public static func run() throws -> MadiTransmitSyntheticReport {
        let measurements = try madiSyntheticRequiredChannelCounts.map { channelCount in
            try measure(channelCount: channelCount)
        }
        return MadiTransmitSyntheticReport(
            id: "m03-madi-tx-synthetic-packetization",
            capturedAt: "2026-05-04T00:00:00Z",
            measurements: measurements,
            verdict: .partial,
            notes: "Synthetic packetization only; physical RME MADI TX evidence is required for PASS."
        )
    }

    private static func measure(channelCount: Int) throws -> MadiTransmitPacketizationMeasurement {
        let framesPerPacket = 32
        let sampleRateHertz = 48_000
        let sampleFormat = UdpPcmSampleFormat.float32LittleEndian
        let maxTransmissionUnitBytes = 1_200
        let mode = try audioTransportMode(
            channelCount: channelCount,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: sampleRateHertz,
            sampleFormat: sampleFormat,
            maxTransmissionUnitBytes: maxTransmissionUnitBytes
        )
        let payload = SyntheticAudioPayload.make(seed: 0, byteCount: mode.payloadByteCount)
        var handoff = RealtimeAudioPacketHandoff(
            configuration: RealtimeAudioEngineConfiguration(
                inputDeviceUID: "synthetic-rme-madi",
                outputDeviceUID: "synthetic-rme-madi",
                sampleRateHertz: sampleRateHertz,
                framesPerBuffer: framesPerPacket,
                channelCount: channelCount,
                packetFormat: sampleFormat,
                inputChannelMap: Array(0..<channelCount),
                outputChannelMap: Array(0..<channelCount),
                playoutTargetFrames: framesPerPacket,
                preallocatedBlockCount: 4
            )
        )

        _ = handoff.captureCallback(
            startFrame: 0,
            hostTimeNanoseconds: 1,
            payload: payload
        )
        let start = DispatchTime.now().uptimeNanoseconds
        let packets = try handoff.sendNextV2Packets(mode: mode) ?? []
        let end = DispatchTime.now().uptimeNanoseconds
        let reassembled = try UdpPcmV2FragmentReassembler.reassemble(packets)
        guard reassembled.payload == payload else {
            throw MadiTransmitValidationError.emptyField("reassembled.payload")
        }

        return MadiTransmitPacketizationMeasurement(
            channelCount: channelCount,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: sampleRateHertz,
            sampleFormat: sampleFormat,
            payloadByteCount: mode.payloadByteCount,
            packetFragmentCount: packets.count,
            maxPacketByteCount: packets.map(\.header.packetByteCount).max() ?? 0,
            packetizationMicroseconds: Double(end - start) / 1_000,
            allocationWarnings: handoff.metrics.allocationWarnings
        )
    }

    private static func audioTransportMode(
        channelCount: Int,
        framesPerPacket: Int,
        sampleRateHertz: Int,
        sampleFormat: UdpPcmSampleFormat,
        maxTransmissionUnitBytes: Int
    ) throws -> AudioTransportMode {
        let fragments = try UdpPcmV2FragmentPlanner.plan(
            UdpPcmV2FragmentPlanRequest(
                streamID: 1,
                totalChannelCount: channelCount,
                framesPerPacket: framesPerPacket,
                sampleRateHertz: sampleRateHertz,
                sampleFormat: sampleFormat,
                maxTransmissionUnitBytes: maxTransmissionUnitBytes,
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
            maxTransmissionUnitBytes: maxTransmissionUnitBytes,
            channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
            fragments: fragments
        )
    }
}

private func requireMadiTransmitNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, error: MadiTransmitValidationError.self)
}

private func requireMadiTransmitPositive(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, error: MadiTransmitValidationError.self)
}

private func requireMadiTransmitNonNegative(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, error: MadiTransmitValidationError.self)
}

private func requireMadiTransmitNonNegative(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(
        value,
        field: field,
        negative: MadiTransmitValidationError.negativeField,
        nonFinite: MadiTransmitValidationError.negativeField
    )
}
