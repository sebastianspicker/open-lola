// Consumes the versioned, implementation-neutral LoLa 2 compatibility corpus.
import Foundation
import Testing

@testable import OpenLolaCore

private struct LoLaCompatibilityCorpus: Decodable {
    struct Provenance: Decodable {
        let originalWindowsCapture: Bool

        enum CodingKeys: String, CodingKey {
            case originalWindowsCapture = "original_windows_capture"
        }
    }

    struct Vector: Decodable {
        struct Expected: Decodable {
            struct Fragment: Decodable {
                let fragmentIndex: Int?
                let originalOffset: Int?
                let fragmentLength: Int?
                let flags: Int?
                let dataHex: String?

                enum CodingKeys: String, CodingKey {
                    case fragmentIndex = "fragment_index"
                    case originalOffset = "original_offset"
                    case fragmentLength = "fragment_length"
                    case flags
                    case dataHex = "data_hex"
                }
            }

            let category: String
            let wireSize: Int?
            let sid: Int?
            let sidCanonical: String?
            let txt: String?
            let frameID: Int?
            let fragmentCount: Int?
            let fragmentIndex: Int?
            let originalOffset: Int?
            let fragmentLength: Int?
            let flags: Int?
            let serializedHex: String?
            let serializedSize: Int?
            let preludeHex: String?
            let fragments: [Fragment]?

            enum CodingKeys: String, CodingKey {
                case category
                case wireSize = "wire_size"
                case sid
                case sidCanonical = "sid_canonical"
                case txt
                case frameID = "frame_id"
                case fragmentCount = "fragment_count"
                case fragmentIndex = "fragment_index"
                case originalOffset = "original_offset"
                case fragmentLength = "fragment_length"
                case flags
                case serializedHex = "serialized_hex"
                case serializedSize = "serialized_size"
                case preludeHex = "prelude_hex"
                case fragments
            }
        }

        let id: String
        let operation: String
        let kind: String?
        let sourceIP: String?
        let destinationIP: String?
        let sid: Int?
        let text: String?
        let textRepeat: String?
        let textCount: Int?
        let expectedPrefix: String?
        let inputASCII: String?
        let inputHex: String?
        let padTo: Int?
        let padByte: String?
        let sequence: Int?
        let pcmHex: String?
        let payloadHex: String?
        let packetSize: Int?
        let expected: Expected

        enum CodingKeys: String, CodingKey {
            case id
            case operation
            case kind
            case sourceIP = "src_ip"
            case destinationIP = "dst_ip"
            case sid
            case text = "txt"
            case textRepeat = "txt_repeat"
            case textCount = "txt_count"
            case expectedPrefix = "expected_prefix"
            case inputASCII = "input_ascii"
            case inputHex = "input_hex"
            case padTo = "pad_to"
            case padByte = "pad_byte"
            case sequence
            case pcmHex = "pcm_hex"
            case payloadHex = "payload_hex"
            case packetSize = "packet_size"
            case expected
        }
    }

    let schema: String
    let version: String
    let provenance: Provenance
    let cases: [Vector]
}

private struct LoLaCompatibilityCorpusError: Error, CustomStringConvertible {
    let description: String
}

@Test
func lolaCompatibilityCorpusV1IsConsumedByOpenLolaCore() throws {
    let corpus = try lolaCompatibilityCorpus()

    #expect(corpus.schema == "open-lola.lola2.compatibility-corpus/v1")
    #expect(corpus.version.hasPrefix("1."))
    #expect(corpus.provenance.originalWindowsCapture == false)
    #expect(corpus.cases.count == 25)
    #expect(Set(corpus.cases.map(\.id)).count == corpus.cases.count)

    for vector in corpus.cases {
        try lolaConsumeCorpusVector(vector)
    }
}

private func lolaCompatibilityCorpus() throws -> LoLaCompatibilityCorpus {
    let manifestURL = try lolaCompatibilityCorpusManifestURL()
    let data = try Data(contentsOf: manifestURL)
    return try JSONDecoder().decode(LoLaCompatibilityCorpus.self, from: data)
}

private func lolaCompatibilityCorpusManifestURL(
    filePath: StaticString = #filePath
) throws -> URL {
    var directory = URL(fileURLWithPath: String(describing: filePath)).deletingLastPathComponent()
    let fileManager = FileManager.default

    while directory.path != "/" {
        let package = directory.appendingPathComponent("Package.swift")
        if fileManager.fileExists(atPath: package.path) {
            return directory.appendingPathComponent("interop/lola2/manifest.json")
        }
        directory.deleteLastPathComponent()
    }

    throw LoLaCompatibilityCorpusError(description: "Unable to locate Package.swift from \(filePath)")
}

private func lolaConsumeCorpusVector(_ vector: LoLaCompatibilityCorpus.Vector) throws {
    switch vector.operation {
    case "encode_control":
        try lolaVerifyControlEncoding(vector)
    case "parse_control":
        try lolaVerifyControlParse(vector)
    case "reject_control_encoding":
        try lolaVerifyControlEncodingRejection(vector)
    case "parse_serialized":
        try lolaVerifySerializedMediaParse(vector)
    case "encode_audio":
        try lolaVerifyAudioEncoding(vector)
    case "encode_video":
        try lolaVerifyVideoEncoding(vector)
    default:
        throw LoLaCompatibilityCorpusError(
            description: "\(vector.id): unsupported corpus operation \(vector.operation)"
        )
    }
}

private func lolaVerifyControlEncoding(_ vector: LoLaCompatibilityCorpus.Vector) throws {
    let message = try lolaControlMessage(for: vector)
    let expected = vector.expected
    let prefix = try lolaCorpusRequired(vector.expectedPrefix, vector, "expected_prefix")
    let wireSize = try lolaCorpusRequired(expected.wireSize, vector, "expected.wire_size")

    #expect(expected.category == "accept")
    #expect(message.hasPrefix(prefix))
    let datagram = try lolaControlDatagramBytes(message)
    #expect(datagram.count == wireSize)
    #expect(Array(datagram.prefix(prefix.utf8.count)) == Array(prefix.utf8))

    let parsed = try LoLaCompatibilityControlMessage.parse(message)
    let expectedSID = try lolaExpectedCanonicalSID(expected, vector)
    #expect(parsed.fields["SID"] == expectedSID)
    if let text = expected.txt {
        #expect(parsed.fields["TXT"] == text)
    }
}

private func lolaVerifyControlParse(_ vector: LoLaCompatibilityCorpus.Vector) throws {
    let input = try lolaControlInput(vector)
    let category = vector.expected.category

    if category == "accept" {
        let parsed = try LoLaCompatibilityControlMessage.parse(input)
        let expectedSID = try lolaExpectedCanonicalSID(vector.expected, vector)
        #expect(parsed.fields["SID"] == expectedSID)
        if let text = vector.expected.txt {
            #expect(parsed.fields["TXT"] == text)
        }
        return
    }

    lolaExpectRejection(category, vector: vector) {
        _ = try LoLaCompatibilityControlMessage.parse(input)
    }
}

private func lolaExpectedCanonicalSID(
    _ expected: LoLaCompatibilityCorpus.Vector.Expected,
    _ vector: LoLaCompatibilityCorpus.Vector
) throws -> String {
    if let canonical = expected.sidCanonical {
        return canonical
    }
    return String(try lolaCorpusRequired(expected.sid, vector, "expected.sid"))
}

private func lolaVerifyControlEncodingRejection(_ vector: LoLaCompatibilityCorpus.Vector) throws {
    let message = try lolaControlMessage(for: vector)
    lolaExpectRejection(vector.expected.category, vector: vector) {
        _ = try lolaControlDatagramBytes(message)
    }
}

private func lolaVerifySerializedMediaParse(_ vector: LoLaCompatibilityCorpus.Vector) throws {
    let input = try lolaControlInput(vector)
    lolaExpectRejection(vector.expected.category, vector: vector) {
        _ = try LoLaCompatibilityMediaCodec.decodeSerializedBody(Data(input.utf8))
    }
}

private func lolaVerifyAudioEncoding(_ vector: LoLaCompatibilityCorpus.Vector) throws {
    let payload = try lolaCorpusData(fromHex: lolaCorpusRequired(vector.pcmHex, vector, "pcm_hex"))
    let expected = vector.expected
    let wireSize = try lolaCorpusRequired(expected.wireSize, vector, "expected.wire_size")
    let frameID = UInt32(try lolaCorpusRequired(expected.frameID, vector, "expected.frame_id"))
    let fragmentCount = try lolaCorpusRequired(expected.fragmentCount, vector, "expected.fragment_count")
    let fragmentIndex = try lolaCorpusRequired(expected.fragmentIndex, vector, "expected.fragment_index")
    let originalOffset = try lolaCorpusRequired(expected.originalOffset, vector, "expected.original_offset")
    let fragmentLength = try lolaCorpusRequired(expected.fragmentLength, vector, "expected.fragment_length")
    let finalFlag = try lolaCorpusRequired(expected.flags, vector, "expected.flags") != 0
    let serialized = try lolaCorpusData(
        fromHex: lolaCorpusRequired(expected.serializedHex, vector, "expected.serialized_hex")
    )
    let fragment = try #require(LoLaCompatibilityMediaCodec.audioFragments(
        sequenceNumber: UInt32(try lolaCorpusRequired(vector.sequence, vector, "sequence")),
        channels: 2,
        payload: payload
    ).first)
    let decoded = try #require(LoLaCompatibilityMediaCodec.decode(fragment.payload).normalFragment)

    #expect(expected.category == "accept")
    #expect(fragment.payload.count == wireSize)
    #expect(decoded.header.frameID == frameID)
    #expect(decoded.header.fragmentCount == fragmentCount)
    #expect(decoded.header.fragmentIndex == fragmentIndex)
    #expect(decoded.header.originalOffset == originalOffset)
    #expect(decoded.header.fragmentPayloadLength == fragmentLength)
    #expect(decoded.header.finalFlag == finalFlag)
    #expect(decoded.fragmentBytes == serialized)
}

private func lolaVerifyVideoEncoding(_ vector: LoLaCompatibilityCorpus.Vector) throws {
    let expected = vector.expected
    let packetSize = try lolaCorpusRequired(vector.packetSize, vector, "packet_size")
    let maxFragmentBodyByteCount = packetSize - LoLaCompatibilityMediaModel.fragmentPayloadOffset
    let packets = try LoLaCompatibilityMediaCodec.videoPackets(
        sequenceNumber: UInt32(try lolaCorpusRequired(vector.sequence, vector, "sequence")),
        payload: try lolaCorpusData(fromHex: lolaCorpusRequired(vector.payloadHex, vector, "payload_hex")),
        maxFragmentBodyByteCount: maxFragmentBodyByteCount
    )
    let prelude = try #require(LoLaCompatibilityMediaCodec.decode(packets[0].payload).videoPrelude)
    let fragments = try packets.dropFirst().map {
        try #require(LoLaCompatibilityMediaCodec.decode($0.payload).normalFragment)
    }
    let expectedFragments = try lolaCorpusRequired(expected.fragments, vector, "expected.fragments")
    let frameID = UInt32(try lolaCorpusRequired(expected.frameID, vector, "expected.frame_id"))
    let serializedSize = try lolaCorpusRequired(expected.serializedSize, vector, "expected.serialized_size")
    let fragmentCount = try lolaCorpusRequired(expected.fragmentCount, vector, "expected.fragment_count")
    let preludeBytes = try lolaCorpusData(
        fromHex: lolaCorpusRequired(expected.preludeHex, vector, "expected.prelude_hex")
    )

    #expect(expected.category == "accept")
    #expect(prelude.frameID == frameID)
    #expect(prelude.serializedSize == serializedSize)
    #expect(prelude.fragmentCount == fragmentCount)
    #expect(packets[0].payload == preludeBytes)
    #expect(fragments.count == expectedFragments.count)

    for (fragment, expectedFragment) in zip(fragments, expectedFragments) {
        let fragmentIndex = try lolaCorpusRequired(expectedFragment.fragmentIndex, vector, "fragment.fragment_index")
        let originalOffset = try lolaCorpusRequired(expectedFragment.originalOffset, vector, "fragment.original_offset")
        let fragmentLength = try lolaCorpusRequired(expectedFragment.fragmentLength, vector, "fragment.fragment_length")
        let finalFlag = try lolaCorpusRequired(expectedFragment.flags, vector, "fragment.flags") != 0
        let bytes = try lolaCorpusData(
            fromHex: lolaCorpusRequired(expectedFragment.dataHex, vector, "fragment.data_hex")
        )
        #expect(fragment.header.frameID == prelude.frameID)
        #expect(fragment.header.fragmentCount == prelude.fragmentCount)
        #expect(fragment.header.fragmentIndex == fragmentIndex)
        #expect(fragment.header.originalOffset == originalOffset)
        #expect(fragment.header.fragmentPayloadLength == fragmentLength)
        #expect(fragment.header.finalFlag == finalFlag)
        #expect(fragment.fragmentBytes == bytes)
    }
}

private func lolaControlMessage(for vector: LoLaCompatibilityCorpus.Vector) throws -> String {
    let sourceIP = try lolaCorpusRequired(vector.sourceIP, vector, "src_ip")
    let destinationIP = try lolaCorpusRequired(vector.destinationIP, vector, "dst_ip")
    let sessionID = try lolaCorpusRequired(vector.sid, vector, "sid")

    switch try lolaCorpusRequired(vector.kind, vector, "kind") {
    case "MESG_QUICKCONN":
        return LoLaCompatibilityControlMessage.quickConnect(lolaDefaultCorpusMediaFields(
            sourceIP: sourceIP, destinationIP: destinationIP, sessionID: sessionID
        ))
    case "MESG_CHECKLOLASTATUS_ACK":
        return LoLaCompatibilityControlMessage.checkStatusAck(
            sourceIP: sourceIP, destinationIP: destinationIP, sessionID: sessionID
        )
    case "MESG_CHAT":
        return LoLaCompatibilityControlMessage.chat(
            sourceIP: sourceIP,
            destinationIP: destinationIP,
            sessionID: sessionID,
            text: vector.text ?? String(repeating: vector.textRepeat ?? "", count: vector.textCount ?? 0)
        )
    case "MESG_REJECT":
        return LoLaCompatibilityControlMessage.reject(
            sourceIP: sourceIP,
            destinationIP: destinationIP,
            sessionID: sessionID,
            text: try lolaCorpusRequired(vector.text, vector, "txt")
        )
    default:
        throw LoLaCompatibilityCorpusError(description: "\(vector.id): unsupported control kind")
    }
}

private func lolaDefaultCorpusMediaFields(
    sourceIP: String,
    destinationIP: String,
    sessionID: Int
) -> LoLaCompatibilityMediaFields {
    LoLaCompatibilityMediaFields(
        session: LoLaControlSessionFields(
            sourceIP: sourceIP, destinationIP: destinationIP, sessionID: sessionID
        ),
        audio: LoLaCompatibilityAudioFields(sampleRateHertz: 44_100, bitsPerSample: 16, channels: 2),
        video: LoLaCompatibilityVideoFields(
            frameRate: 25,
            bitsPerPixel: 8,
            dimensions: LoLaCompatibilityVideoDimensions(width: 640, height: 480)
        )
    )
}

private func lolaControlInput(_ vector: LoLaCompatibilityCorpus.Vector) throws -> String {
    var bytes: [UInt8]
    if let inputHex = vector.inputHex {
        bytes = Array(try lolaCorpusData(fromHex: inputHex))
    } else {
        bytes = Array(try lolaCorpusRequired(vector.inputASCII, vector, "input_ascii").utf8)
    }
    if let padTo = vector.padTo {
        let pad = vector.padByte?.utf8.first ?? 0
        bytes.append(contentsOf: repeatElement(pad, count: max(0, padTo - bytes.count)))
    }
    return String(decoding: bytes, as: UTF8.self)
}

private func lolaExpectRejection(
    _ category: String,
    vector: LoLaCompatibilityCorpus.Vector,
    action: () throws -> Void
) {
    let error: (any Error)?
    do {
        try action()
        error = nil
    } catch let caughtError {
        error = caughtError
    }
    guard let error else {
        Issue.record("\(vector.id): expected \(category) rejection")
        return
    }

    switch category {
    case "reject.invalid_sid", "reject.duplicate_field", "reject.missing_required_fields", "reject.txt_order", "reject.non_ascii", "reject.oversize":
        #expect(error is ExternalConnectorSessionError)
    case "reject.serialized_length":
        #expect(error is LoLaCompatibilityMediaCodecError)
    default:
        Issue.record("\(vector.id): unsupported rejection category \(category)")
    }
}

private func lolaCorpusRequired<T>(
    _ value: T?,
    _ vector: LoLaCompatibilityCorpus.Vector,
    _ field: String
) throws -> T {
    guard let value else {
        throw LoLaCompatibilityCorpusError(description: "\(vector.id): missing \(field)")
    }
    return value
}

private func lolaCorpusData(fromHex hex: String) throws -> Data {
    guard hex.count.isMultiple(of: 2) else {
        throw LoLaCompatibilityCorpusError(description: "invalid hex byte count")
    }
    var bytes: [UInt8] = []
    var index = hex.startIndex
    while index < hex.endIndex {
        let end = hex.index(index, offsetBy: 2)
        guard let byte = UInt8(hex[index..<end], radix: 16) else {
            throw LoLaCompatibilityCorpusError(description: "invalid hex byte")
        }
        bytes.append(byte)
        index = end
    }
    return Data(bytes)
}
