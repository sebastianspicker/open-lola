// Defines LoLa capture formats, decoded packet observations, summaries, and validation failures.
import Foundation

/// Defines the supported choices for LoLa compatibility capture format.
public enum LoLaCompatibilityCaptureFormat: String, Codable, Equatable, Sendable {
    case classicPcap
    case pcapng
}

/// Defines the supported choices for LoLa compatibility capture stream.
public enum LoLaCompatibilityCaptureStream: String, Codable, Equatable, Sendable {
    case control
    case audio
    case video
    case otherUDP
    case nonUDP
    case malformed
}

/// Defines the supported choices for LoLa compatibility media payload candidate.
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

/// Records the evidence and outcome for LoLa compatibility capture packet report.
public struct LoLaCompatibilityCapturePacketReport: Codable, Equatable, Sendable {
    public struct Network: Equatable, Sendable {
        public var sourceIP: String?
        public var destinationIP: String?
        public var sourcePort: UInt16?
        public var destinationPort: UInt16?
        public var payloadLength: Int?

        public init(
            sourceIP: String? = nil,
            destinationIP: String? = nil,
            sourcePort: UInt16? = nil,
            destinationPort: UInt16? = nil,
            payloadLength: Int? = nil
        ) {
            self.sourceIP = sourceIP
            self.destinationIP = destinationIP
            self.sourcePort = sourcePort
            self.destinationPort = destinationPort
            self.payloadLength = payloadLength
        }
    }

    public struct Media: Equatable, Sendable {
        public var envelopeValid: Bool
        public var payloadCandidate: LoLaCompatibilityMediaPayloadCandidate?
        public var packetKind: LoLaCompatibilityMediaPacketKind?
        public var frameID: UInt32?

        public init(
            envelopeValid: Bool = false,
            payloadCandidate: LoLaCompatibilityMediaPayloadCandidate? = nil,
            packetKind: LoLaCompatibilityMediaPacketKind? = nil,
            frameID: UInt32? = nil
        ) {
            self.envelopeValid = envelopeValid
            self.payloadCandidate = payloadCandidate
            self.packetKind = packetKind
            self.frameID = frameID
        }
    }

    public struct Fragment: Equatable, Sendable {
        public var index: Int?
        public var count: Int?
        public var payloadLength: Int?
        public var serializedPayloadLength: Int?
        public var final: Bool?

        public init(
            index: Int? = nil,
            count: Int? = nil,
            payloadLength: Int? = nil,
            serializedPayloadLength: Int? = nil,
            final: Bool? = nil
        ) {
            self.index = index
            self.count = count
            self.payloadLength = payloadLength
            self.serializedPayloadLength = serializedPayloadLength
            self.final = final
        }
    }

    public struct Metadata: Equatable, Sendable {
        public var controlMessageName: String?
        public var notes: [String]

        public init(controlMessageName: String? = nil, notes: [String] = []) {
            self.controlMessageName = controlMessageName
            self.notes = notes
        }
    }

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
        network: Network = .init(),
        media: Media = .init(),
        fragment: Fragment = .init(),
        metadata: Metadata = .init()
    ) {
        self.index = index
        self.capturedLength = capturedLength
        self.originalLength = originalLength
        self.stream = stream
        sourceIP = network.sourceIP
        destinationIP = network.destinationIP
        sourcePort = network.sourcePort
        destinationPort = network.destinationPort
        payloadLength = network.payloadLength
        mediaEnvelopeValid = media.envelopeValid
        mediaPayloadCandidate = media.payloadCandidate
        packetKind = media.packetKind
        frameID = media.frameID
        fragmentIndex = fragment.index
        fragmentCount = fragment.count
        fragmentPayloadLength = fragment.payloadLength
        serializedMediaPayloadLength = fragment.serializedPayloadLength
        finalFragment = fragment.final
        controlMessageName = metadata.controlMessageName
        notes = metadata.notes
    }
}

/// Records the evidence and outcome for LoLa compatibility capture summary.
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

/// Defines failures reported when LoLa compatibility capture validation error cannot continue.
public enum LoLaCompatibilityCaptureValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case negativeCount(String)
    case summaryMismatch(String)
    case passNotAllowed
}

/// Defines failures reported when LoLa compatibility capture decode error cannot continue.
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

/// Records the evidence and outcome for LoLa compatibility capture report.
public struct LoLaCompatibilityCaptureReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var id: String
        public var title: String
        public var capturedAt: String
        public var inputPath: String
        public var inputFormat: LoLaCompatibilityCaptureFormat

        public init(
            id: String,
            title: String,
            capturedAt: String,
            inputPath: String,
            inputFormat: LoLaCompatibilityCaptureFormat
        ) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.inputPath = inputPath
            self.inputFormat = inputFormat
        }
    }

    public struct Content: Equatable, Sendable {
        public var summary: LoLaCompatibilityCaptureSummary
        public var packets: [LoLaCompatibilityCapturePacketReport]

        public init(summary: LoLaCompatibilityCaptureSummary, packets: [LoLaCompatibilityCapturePacketReport]) {
            self.summary = summary
            self.packets = packets
        }
    }

    public enum OutcomeDomain {}
    public typealias Outcome = EvidenceBoundaryReportOutcome<OutcomeDomain>

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

    public init(identity: Identity, content: Content, outcome: Outcome) {
        id = identity.id
        title = identity.title
        capturedAt = identity.capturedAt
        inputPath = identity.inputPath
        inputFormat = identity.inputFormat
        summary = content.summary
        packets = content.packets
        verdict = outcome.verdict
        evidenceBoundary = outcome.evidenceBoundary
        notes = outcome.notes
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
            ("summary.unknownUdpPacketCount", summary.unknownUdpPacketCount)
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
