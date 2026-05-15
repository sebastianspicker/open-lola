import Foundation

public enum LoLaCompatibilityCaptureFormat: String, Codable, Equatable, Sendable {
    case classicPcap
    case pcapng
}

public enum LoLaCompatibilityCaptureStream: String, Codable, Equatable, Sendable {
    case control
    case audio
    case video
    case otherUDP
    case nonUDP
    case malformed
}

public enum LoLaCompatibilityMediaPayloadCandidate: String, Codable, Equatable, Sendable {
    case rawAudio
    case rawVideo
    case audioFragment
    case videoPrelude
    case videoFragment
    case malformedFragment
    case mjpeg
    case unknown
}

public struct LoLaCompatibilityCapturePacketReport: Codable, Equatable, Sendable {
    public var index: Int
    public var capturedLength: Int
    public var originalLength: Int
    public var stream: LoLaCompatibilityCaptureStream
    public var sourceIP: String?
    public var destinationIP: String?
    public var sourcePort: UInt16?
    public var destinationPort: UInt16?
    public var payloadLength: Int?
    public var mediaEnvelopeValid: Bool
    public var mediaPayloadCandidate: LoLaCompatibilityMediaPayloadCandidate?
    public var packetKind: LoLaCompatibilityMediaPacketKind?
    public var frameID: UInt32?
    public var fragmentIndex: Int?
    public var fragmentCount: Int?
    public var fragmentPayloadLength: Int?
    public var serializedMediaPayloadLength: Int?
    public var finalFragment: Bool?
    public var controlMessageName: String?
    public var notes: [String]

    public init(
        index: Int,
        capturedLength: Int,
        originalLength: Int,
        stream: LoLaCompatibilityCaptureStream,
        sourceIP: String? = nil,
        destinationIP: String? = nil,
        sourcePort: UInt16? = nil,
        destinationPort: UInt16? = nil,
        payloadLength: Int? = nil,
        mediaEnvelopeValid: Bool = false,
        mediaPayloadCandidate: LoLaCompatibilityMediaPayloadCandidate? = nil,
        packetKind: LoLaCompatibilityMediaPacketKind? = nil,
        frameID: UInt32? = nil,
        fragmentIndex: Int? = nil,
        fragmentCount: Int? = nil,
        fragmentPayloadLength: Int? = nil,
        serializedMediaPayloadLength: Int? = nil,
        finalFragment: Bool? = nil,
        controlMessageName: String? = nil,
        notes: [String] = []
    ) {
        self.index = index
        self.capturedLength = capturedLength
        self.originalLength = originalLength
        self.stream = stream
        self.sourceIP = sourceIP
        self.destinationIP = destinationIP
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.payloadLength = payloadLength
        self.mediaEnvelopeValid = mediaEnvelopeValid
        self.mediaPayloadCandidate = mediaPayloadCandidate
        self.packetKind = packetKind
        self.frameID = frameID
        self.fragmentIndex = fragmentIndex
        self.fragmentCount = fragmentCount
        self.fragmentPayloadLength = fragmentPayloadLength
        self.serializedMediaPayloadLength = serializedMediaPayloadLength
        self.finalFragment = finalFragment
        self.controlMessageName = controlMessageName
        self.notes = notes
    }
}

public struct LoLaCompatibilityCaptureSummary: Codable, Equatable, Sendable {
    public var packetCount: Int
    public var ipv4UdpPacketCount: Int
    public var controlPacketCount: Int
    public var audioPacketCount: Int
    public var videoPacketCount: Int
    public var lolaMediaEnvelopePacketCount: Int
    public var malformedPacketCount: Int
    public var unknownUdpPacketCount: Int

    public init(packets: [LoLaCompatibilityCapturePacketReport]) {
        packetCount = packets.count
        ipv4UdpPacketCount = packets.filter { $0.sourcePort != nil && $0.destinationPort != nil }.count
        controlPacketCount = packets.filter { $0.stream == .control }.count
        audioPacketCount = packets.filter { $0.stream == .audio }.count
        videoPacketCount = packets.filter { $0.stream == .video }.count
        lolaMediaEnvelopePacketCount = packets.filter(\.mediaEnvelopeValid).count
        malformedPacketCount = packets.filter { $0.stream == .malformed }.count
        unknownUdpPacketCount = packets.filter { $0.stream == .otherUDP }.count
    }
}

public enum LoLaCompatibilityCaptureValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case negativeCount(String)
    case summaryMismatch(String)
    case passNotAllowed
}

public enum LoLaCompatibilityCaptureDecodeError: Error, Equatable, Sendable {
    case unsupportedCaptureFormat
    case inputTooLarge(Int)
    case packetCountTooLarge(Int)
    case payloadTooLarge(Int)
    case truncatedClassicPcapHeader
    case unsupportedClassicPcapLinkType(UInt32)
    case malformedClassicPcapRecord(Int)
    case malformedPcapngSection
    case malformedPcapngBlock(Int)
}

public struct LoLaCompatibilityCaptureReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var inputPath: String
    public var inputFormat: LoLaCompatibilityCaptureFormat
    public var summary: LoLaCompatibilityCaptureSummary
    public var packets: [LoLaCompatibilityCapturePacketReport]
    public var verdict: MeasurementVerdict
    public var evidenceBoundary: String
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        inputPath: String,
        inputFormat: LoLaCompatibilityCaptureFormat,
        summary: LoLaCompatibilityCaptureSummary,
        packets: [LoLaCompatibilityCapturePacketReport],
        verdict: MeasurementVerdict,
        evidenceBoundary: String,
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.inputPath = inputPath
        self.inputFormat = inputFormat
        self.summary = summary
        self.packets = packets
        self.verdict = verdict
        self.evidenceBoundary = evidenceBoundary
        self.notes = notes
    }

    public func validate() throws {
        try requireLoLaCaptureNonEmpty(id, "id")
        try requireLoLaCaptureNonEmpty(title, "title")
        try requireLoLaCaptureNonEmpty(capturedAt, "capturedAt")
        try requireLoLaCaptureNonEmpty(inputPath, "inputPath")
        try requireLoLaCaptureNonEmpty(evidenceBoundary, "evidenceBoundary")
        try requireLoLaCaptureNonEmpty(notes, "notes")
        guard verdict != .pass else {
            throw LoLaCompatibilityCaptureValidationError.passNotAllowed
        }
        for field in [
            ("summary.packetCount", summary.packetCount),
            ("summary.ipv4UdpPacketCount", summary.ipv4UdpPacketCount),
            ("summary.controlPacketCount", summary.controlPacketCount),
            ("summary.audioPacketCount", summary.audioPacketCount),
            ("summary.videoPacketCount", summary.videoPacketCount),
            ("summary.lolaMediaEnvelopePacketCount", summary.lolaMediaEnvelopePacketCount),
            ("summary.malformedPacketCount", summary.malformedPacketCount),
            ("summary.unknownUdpPacketCount", summary.unknownUdpPacketCount),
        ] where field.1 < 0 {
            throw LoLaCompatibilityCaptureValidationError.negativeCount(field.0)
        }
        let rebuilt = LoLaCompatibilityCaptureSummary(packets: packets)
        guard rebuilt == summary else {
            throw LoLaCompatibilityCaptureValidationError.summaryMismatch("summary")
        }
    }
}

private func requireLoLaCaptureNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonBlank(
        value,
        field: field,
        empty: LoLaCompatibilityCaptureValidationError.emptyField
    )
}
