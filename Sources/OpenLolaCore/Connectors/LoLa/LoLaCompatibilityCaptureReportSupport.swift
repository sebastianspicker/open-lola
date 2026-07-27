// Parses captured LoLa packets into media classifications and report fields, isolating pcap decoding details from the public capture report.
struct LoLaCapturedPacket: Equatable {
    var bytes: [UInt8]
    var originalLength: Int
}

struct DecodedCapturePacket {
    var report: LoLaCompatibilityCapturePacketReport
    var unexpectedErrorCount: Int
}

struct LoLaCapturePacketDetails {
    var mediaEnvelopeValid = false
    var media = LoLaMediaPayloadClassification.unknown
    var controlMessageName: String?
    var notes: [String] = []
    var unexpectedErrorCount = 0
}

struct LoLaMediaPayloadClassification {
    var candidate: LoLaCompatibilityMediaPayloadCandidate
    var packetKind: LoLaCompatibilityMediaPacketKind?
    var frameID: UInt32?
    var fragmentIndex: Int?
    var fragmentCount: Int?
    var fragmentPayloadLength: Int?
    var serializedMediaPayloadLength: Int?
    var finalFragment: Bool?

    static let unknown = LoLaMediaPayloadClassification(candidate: .unknown)
    static let malformed = LoLaMediaPayloadClassification(
        candidate: .malformedFragment,
        packetKind: .malformedFragment
    )

    static func videoPrelude(_ prelude: LoLaCompatibilityVideoPrelude) -> LoLaMediaPayloadClassification {
        LoLaMediaPayloadClassification(
            candidate: .videoPrelude,
            packetKind: .videoPrelude,
            frameID: prelude.frameID,
            fragmentCount: prelude.fragmentCount,
            serializedMediaPayloadLength: prelude.serializedSize
        )
    }

    static func normalFragment(
        candidate: LoLaCompatibilityMediaPayloadCandidate,
        packetKind: LoLaCompatibilityMediaPacketKind,
        normal: LoLaCompatibilityNormalFragment
    ) -> LoLaMediaPayloadClassification {
        LoLaMediaPayloadClassification(
            candidate: candidate,
            packetKind: packetKind,
            frameID: normal.header.frameID,
            fragmentIndex: normal.header.fragmentIndex,
            fragmentCount: normal.header.fragmentCount,
            fragmentPayloadLength: normal.header.fragmentPayloadLength,
            serializedMediaPayloadLength: normal.body.map { 8 + $0.payloadLength },
            finalFragment: normal.header.finalFlag
        )
    }
}

struct LoLaPacketCaptureParseResult {
    var format: LoLaCompatibilityCaptureFormat
    var packets: [LoLaCapturedPacket]
}

struct LoLaPcapngBlock {
    var type: UInt32
    var offset: Int
    var length: Int
}
