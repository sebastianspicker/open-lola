// Supplies deterministic LoLa packet samples for codec and capture tests, keeping synthetic byte sequences out of live media handling.
import Foundation

/// Defines the validated fields for LoLa compatibility packet fixture run configuration.
public struct LoLaPacketFixtureRunConfiguration: Equatable, Sendable {
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
        endpoint: LoLaUdpMediaEndpoint,
        captureOutputPath: String? = nil,
        media: LoLaMediaFormat = .init(),
        packetCount: Int = 1
    ) {
        outputPath = endpoint.outputPath
        self.captureOutputPath = captureOutputPath
        localHost = endpoint.localHost
        peer = endpoint.peer
        mediaMode = media.mode
        let audio = media.audio
        channels = audio.channels
        sampleRateHertz = audio.sampleRateHertz
        framesPerPacket = audio.framesPerPacket
        let video = media.video
        videoWidth = video.width
        videoHeight = video.height
        videoBitsPerPixel = video.bitsPerPixel
        self.packetCount = packetCount
    }

    public static func parse(_ arguments: [String]) throws -> LoLaPacketFixtureRunConfiguration {
        let values = try parseLoLaPacketFixtureArguments(arguments)
        return try LoLaPacketFixtureRunConfiguration(
            endpoint: loLaPacketFixtureEndpoint(values),
            captureOutputPath: values["--capture-output"],
            media: try loLaPacketFixtureMedia(values),
            packetCount: optionalLoLaPacketFixturePositiveInteger("--packets", values) ?? 1
        )
    }
}

private func loLaPacketFixtureEndpoint(_ values: [String: String]) throws -> LoLaUdpMediaEndpoint {
    try LoLaUdpMediaEndpoint(
        localHost: values["--local-host"] ?? "192.0.2.10",
        peer: values["--peer"] ?? "192.0.2.20",
        outputPath: requiredLoLaPacketFixtureValue("--output", values)
    )
}

private func loLaPacketFixtureMedia(_ values: [String: String]) throws -> LoLaMediaFormat {
    try LoLaMediaFormat(
        mode: values["--media"].map(parseExternalConnectorMediaMode) ?? .audioVideo,
        audio: .init(
            channels: optionalLoLaPacketFixturePositiveInteger("--channels", values) ?? 2,
            sampleRateHertz: optionalLoLaPacketFixturePositiveInteger("--sample-rate", values) ?? 44_100,
            framesPerPacket: optionalLoLaPacketFixturePositiveInteger("--frames", values) ?? 64
        ),
        video: .init(
            width: optionalLoLaPacketFixturePositiveInteger("--video-width", values) ?? 1920,
            height: optionalLoLaPacketFixturePositiveInteger("--video-height", values) ?? 1080,
            bitsPerPixel: optionalLoLaPacketFixturePositiveInteger("--video-bpp", values) ?? 24
        )
    )
}

/// Records the evidence and outcome for LoLa compatibility packet fixture report.
public struct LoLaCompatibilityPacketFixtureReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Content: Equatable, Sendable {
        public var frames: [LoLaCompatibilityMediaFrame]
        public var captureOutputPath: String?
        public var captureByteCount: Int
        public var decodedCapturePacketCount: Int
        public var decodedMediaEnvelopePacketCount: Int
        public var decodedPayloadCandidates: [LoLaCompatibilityMediaPayloadCandidate]

        public init(
            frames: [LoLaCompatibilityMediaFrame],
            captureOutputPath: String?,
            captureByteCount: Int,
            decodedCapturePacketCount: Int,
            decodedMediaEnvelopePacketCount: Int,
            decodedPayloadCandidates: [LoLaCompatibilityMediaPayloadCandidate]
        ) {
            self.frames = frames
            self.captureOutputPath = captureOutputPath
            self.captureByteCount = captureByteCount
            self.decodedCapturePacketCount = decodedCapturePacketCount
            self.decodedMediaEnvelopePacketCount = decodedMediaEnvelopePacketCount
            self.decodedPayloadCandidates = decodedPayloadCandidates
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = EvidenceBoundaryReportOutcome<OutcomeDomain>

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
        content: Content,
        outcome: Outcome
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.mediaMode = mediaMode
        frames = content.frames
        captureOutputPath = content.captureOutputPath
        captureByteCount = content.captureByteCount
        decodedCapturePacketCount = content.decodedCapturePacketCount
        decodedMediaEnvelopePacketCount = content.decodedMediaEnvelopePacketCount
        decodedPayloadCandidates = content.decodedPayloadCandidates
        verdict = outcome.verdict
        evidenceBoundary = outcome.evidenceBoundary
        notes = outcome.notes
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

/// Generates deterministic LoLa control and media packets and writes their fixture report.
public enum LoLaCompatibilityPacketFixtureRunner {
    public static func run(
        configuration: LoLaPacketFixtureRunConfiguration
    ) throws -> LoLaCompatibilityPacketFixtureReport {
        let session = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .tx,
  peer: configuration.peer,
  outputPath: configuration.outputPath
) { input in
  input.localHost = configuration.localHost
  applyLoLaMediaFields(to: &input, from: configuration)
})
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
            content: .init(
                frames: frames,
                captureOutputPath: configuration.captureOutputPath,
                captureByteCount: capture.count,
                decodedCapturePacketCount: decoded.summary.packetCount,
                decodedMediaEnvelopePacketCount: decoded.summary.lolaMediaEnvelopePacketCount,
                decodedPayloadCandidates: decoded.packets.compactMap(\.mediaPayloadCandidate)
            ),
            outcome: .init(
                verdict: .partial,
                evidenceBoundary: LoLaCompatibilityMediaModel.evidenceBoundary,
                notes: """
                Synthetic LoLa packet fixture corpus generated from local source-level evidence. \
                This is not a Windows LoLa capture and cannot prove AV interoperability.
                """
            )
        )
    }
}

extension LoLaPacketFixtureRunConfiguration: LoLaMediaFieldSource {}

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
            "--channels", "--sample-rate", "--frames", "--video-width", "--video-height", "--video-bpp", "--packets"
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
    appendUdpPcmUInt16LE(value, to: &data)
}

private func appendLoLaPacketFixtureLE32(_ value: UInt32, to data: inout Data) {
    appendUdpPcmUInt32LE(value, to: &data)
}
