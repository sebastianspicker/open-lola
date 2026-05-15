import Foundation

public struct LoLaCompatibilityPacketFixtureRunConfiguration: Equatable, Sendable {
    public var outputPath: String
    public var captureOutputPath: String?
    public var localHost: String
    public var peer: String
    public var mediaMode: ExternalConnectorMediaMode
    public var channels: Int
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var videoWidth: Int
    public var videoHeight: Int
    public var videoBitsPerPixel: Int
    public var packetCount: Int

    public init(
        outputPath: String,
        captureOutputPath: String? = nil,
        localHost: String = "192.0.2.10",
        peer: String = "192.0.2.20",
        mediaMode: ExternalConnectorMediaMode = .audioVideo,
        channels: Int = 2,
        sampleRateHertz: Int = 44_100,
        framesPerPacket: Int = 64,
        videoWidth: Int = 1920,
        videoHeight: Int = 1080,
        videoBitsPerPixel: Int = 24,
        packetCount: Int = 1
    ) {
        self.outputPath = outputPath
        self.captureOutputPath = captureOutputPath
        self.localHost = localHost
        self.peer = peer
        self.mediaMode = mediaMode
        self.channels = channels
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        self.videoBitsPerPixel = videoBitsPerPixel
        self.packetCount = packetCount
    }

    public static func parse(_ arguments: [String]) throws -> LoLaCompatibilityPacketFixtureRunConfiguration {
        let values = try parseLoLaPacketFixtureArguments(arguments)
        return try LoLaCompatibilityPacketFixtureRunConfiguration(
            outputPath: requiredLoLaPacketFixtureValue("--output", values),
            captureOutputPath: values["--capture-output"],
            localHost: values["--local-host"] ?? "192.0.2.10",
            peer: values["--peer"] ?? "192.0.2.20",
            mediaMode: values["--media"].map(parseExternalConnectorMediaMode) ?? .audioVideo,
            channels: optionalLoLaPacketFixturePositiveInteger("--channels", values) ?? 2,
            sampleRateHertz: optionalLoLaPacketFixturePositiveInteger("--sample-rate", values) ?? 44_100,
            framesPerPacket: optionalLoLaPacketFixturePositiveInteger("--frames", values) ?? 64,
            videoWidth: optionalLoLaPacketFixturePositiveInteger("--video-width", values) ?? 1920,
            videoHeight: optionalLoLaPacketFixturePositiveInteger("--video-height", values) ?? 1080,
            videoBitsPerPixel: optionalLoLaPacketFixturePositiveInteger("--video-bpp", values) ?? 24,
            packetCount: optionalLoLaPacketFixturePositiveInteger("--packets", values) ?? 1
        )
    }
}

public struct LoLaCompatibilityPacketFixtureReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var mediaMode: ExternalConnectorMediaMode
    public var frames: [LoLaCompatibilityMediaFrame]
    public var captureOutputPath: String?
    public var captureByteCount: Int
    public var decodedCapturePacketCount: Int
    public var decodedMediaEnvelopePacketCount: Int
    public var decodedPayloadCandidates: [LoLaCompatibilityMediaPayloadCandidate]
    public var verdict: MeasurementVerdict
    public var evidenceBoundary: String
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        mediaMode: ExternalConnectorMediaMode,
        frames: [LoLaCompatibilityMediaFrame],
        captureOutputPath: String?,
        captureByteCount: Int,
        decodedCapturePacketCount: Int,
        decodedMediaEnvelopePacketCount: Int,
        decodedPayloadCandidates: [LoLaCompatibilityMediaPayloadCandidate],
        verdict: MeasurementVerdict,
        evidenceBoundary: String,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.mediaMode = mediaMode
        self.frames = frames
        self.captureOutputPath = captureOutputPath
        self.captureByteCount = captureByteCount
        self.decodedCapturePacketCount = decodedCapturePacketCount
        self.decodedMediaEnvelopePacketCount = decodedMediaEnvelopePacketCount
        self.decodedPayloadCandidates = decodedPayloadCandidates
        self.verdict = verdict
        self.evidenceBoundary = evidenceBoundary
        self.notes = notes
    }

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorSessionNonEmpty(evidenceBoundary, "evidenceBoundary")
        try requireExternalConnectorSessionNonEmpty(notes, "notes")
        guard verdict != .pass else {
            throw ExternalConnectorSessionError.dryRunCannotPass
        }
        guard !frames.isEmpty else {
            throw ExternalConnectorSessionError.emptyList("frames")
        }
        guard captureByteCount > 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("captureByteCount", String(captureByteCount))
        }
        guard decodedCapturePacketCount == frames.count else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "decodedCapturePacketCount",
                String(decodedCapturePacketCount)
            )
        }
        guard decodedMediaEnvelopePacketCount == frames.count else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "decodedMediaEnvelopePacketCount",
                String(decodedMediaEnvelopePacketCount)
            )
        }
        guard decodedPayloadCandidates.count == frames.count else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "decodedPayloadCandidates",
                String(decodedPayloadCandidates.count)
            )
        }
    }
}

public enum LoLaCompatibilityPacketFixtureRunner {
    public static func run(
        configuration: LoLaCompatibilityPacketFixtureRunConfiguration
    ) throws -> LoLaCompatibilityPacketFixtureReport {
        let session = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .tx,
            peer: configuration.peer,
            localHost: configuration.localHost,
            outputPath: configuration.outputPath,
            mediaMode: configuration.mediaMode,
            channels: configuration.channels,
            sampleRateHertz: configuration.sampleRateHertz,
            framesPerPacket: configuration.framesPerPacket,
            videoWidth: configuration.videoWidth,
            videoHeight: configuration.videoHeight,
            videoBitsPerPixel: configuration.videoBitsPerPixel
        )
        let frames = try LoLaCompatibilityMediaSession.buildTransmitFrames(
            configuration: session,
            frameCountPerStream: configuration.packetCount
        )
        let capture = classicLoLaSyntheticPcap(frames.map(\.encodedFrame))
        if let captureOutputPath = configuration.captureOutputPath {
            try capture.write(to: URL(fileURLWithPath: captureOutputPath), options: .atomic)
        }
        let decoded = try LoLaCompatibilityCaptureDecoder.decode(
            data: capture,
            inputPath: configuration.captureOutputPath ?? "synthetic-lola-fixture.pcap",
            capturedAt: ISO8601DateFormatter().string(from: Date())
        )
        try decoded.validate()
        return LoLaCompatibilityPacketFixtureReport(
            id: "lola-packet-fixture-source-level",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            mediaMode: configuration.mediaMode,
            frames: frames,
            captureOutputPath: configuration.captureOutputPath,
            captureByteCount: capture.count,
            decodedCapturePacketCount: decoded.summary.packetCount,
            decodedMediaEnvelopePacketCount: decoded.summary.lolaMediaEnvelopePacketCount,
            decodedPayloadCandidates: decoded.packets.compactMap(\.mediaPayloadCandidate),
            verdict: .partial,
            evidenceBoundary: LoLaCompatibilityMediaModel.evidenceBoundary,
            notes: "Synthetic LoLa packet fixture corpus generated from local source-level evidence. This is not a Windows LoLa capture and cannot prove AV interoperability."
        )
    }
}

private func classicLoLaSyntheticPcap(_ packets: [Data]) -> Data {
    var data = Data([0xd4, 0xc3, 0xb2, 0xa1])
    appendLoLaPacketFixtureLE16(2, to: &data)
    appendLoLaPacketFixtureLE16(4, to: &data)
    appendLoLaPacketFixtureLE32(0, to: &data)
    appendLoLaPacketFixtureLE32(0, to: &data)
    appendLoLaPacketFixtureLE32(65_535, to: &data)
    appendLoLaPacketFixtureLE32(1, to: &data)
    for packet in packets {
        appendLoLaPacketFixtureLE32(0, to: &data)
        appendLoLaPacketFixtureLE32(0, to: &data)
        appendLoLaPacketFixtureLE32(UInt32(packet.count), to: &data)
        appendLoLaPacketFixtureLE32(UInt32(packet.count), to: &data)
        data.append(packet)
    }
    return data
}

private func parseLoLaPacketFixtureArguments(_ arguments: [String]) throws -> [String: String] {
    try parseExternalConnectorKeyValueArguments(
        arguments,
        allowed: [
            "--output", "--capture-output", "--local-host", "--peer", "--media",
            "--channels", "--sample-rate", "--frames", "--video-width", "--video-height", "--video-bpp", "--packets",
        ]
    )
}

private func requiredLoLaPacketFixtureValue(_ key: String, _ values: [String: String]) throws -> String {
    try requiredExternalConnectorValue(key, values)
}

private func optionalLoLaPacketFixturePositiveInteger(
    _ key: String,
    _ values: [String: String]
) throws -> Int? {
    try optionalExternalConnectorPositiveInteger(key, values)
}

private func appendLoLaPacketFixtureLE16(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8(value >> 8))
}

private func appendLoLaPacketFixtureLE32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(value & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 24) & 0xff))
}
