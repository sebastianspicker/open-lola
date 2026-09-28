// Drives every checked-in LoLa 2.0 vector through Application's production codecs.
import Foundation
import OpenLolaIntegrations
import Testing

@Test func lola2ManifestConformsThroughProductionCodecs() throws {
    let manifest = try lola2Manifest()
    #expect(manifest.string("schema") == "open-lola.lola2.compatibility-corpus/v1")
    let cases = try #require(manifest.array("cases"))
    #expect(!cases.isEmpty)

    var coveredIDs = Set<String>()
    for vector in cases {
        let id = try #require(vector.string("id"))
        let operation = try #require(vector.string("operation"))
        let expected = try #require(vector.object("expected"))
        let category = try #require(expected.string("category"))

        switch operation {
        case "encode_control":
            try assertEncodedControl(vector: vector, expected: expected, id: id)
        case "parse_control":
            try assertParsedControl(vector: vector, expected: expected, category: category, id: id)
        case "reject_control_encoding":
            let message = try controlMessage(vector)
            assertControlRejection(category, id: id) { try LoLaControlDatagramEncoder.encode(message) }
        case "parse_serialized":
            do {
                _ = try LoLaCompatibilityMediaCodec.decodeSerializedBody(try hex(vector.string("input_hex") ?? ""))
                Issue.record("\(id): expected \(category)")
            } catch let error as LoLaCompatibilityMediaCodecError {
                #expect(error.normalizedCategory?.rawValue == category, "\(id): exact normalized category")
            } catch {
                Issue.record("\(id): unexpected error \(error)")
            }
        case "encode_audio":
            try assertEncodedAudio(vector: vector, expected: expected, id: id)
        case "encode_video":
            try assertEncodedVideo(vector: vector, expected: expected, id: id)
        default:
            Issue.record("\(id): unknown corpus operation \(operation)")
        }
        coveredIDs.insert(id)
    }
    #expect(coveredIDs.count == cases.count, "every manifest vector must reach a production codec")
}

private func assertEncodedControl(vector: JSONObject, expected: JSONObject, id: String) throws {
    let datagram = try LoLaControlDatagramEncoder.encode(controlMessage(vector))
    #expect(datagram.count == expected.integer("wire_size"), "\(id): exact datagram size")
    let message = String(decoding: datagram.prefix { $0 != 0 }, as: UTF8.self)
    #expect(message.hasPrefix(try #require(vector.string("expected_prefix"))), "\(id): exact wire prefix")
    #expect(datagram.drop { $0 != 0 }.allSatisfy { $0 == 0 }, "\(id): zero padding")
    let parsed = try LoLaControlDatagramDecoder.decode(datagram)
    #expect(parsed.fields["SID"] == String(try #require(expected.integer("sid"))), "\(id): SID")
    if let text = expected.string("txt") {
        #expect(parsed.fields["TXT"] == text, "\(id): TXT")
    }
}

private func assertParsedControl(
    vector: JSONObject,
    expected: JSONObject,
    category: String,
    id: String
) throws {
    if let ascii = vector.string("input_ascii") {
        let input = paddedControlDatagram(ascii, vector: vector)
        if category == "accept" {
            let parsed = try LoLaControlDatagramDecoder.decode(input)
            if let canonicalSID = expected.string("sid_canonical") {
                #expect(parsed.fields["SID"] == canonicalSID, "\(id): canonical SID")
            } else if let sid = expected.integer("sid") {
                #expect(parsed.fields["SID"] == String(sid), "\(id): SID")
            }
            if let text = expected.string("txt") {
                #expect(parsed.fields["TXT"] == text, "\(id): TXT")
            }
        } else {
            assertControlRejection(category, id: id) { try LoLaControlDatagramDecoder.decode(input) }
        }
        return
    }

    let input = try hex(try #require(vector.string("input_hex")))
    assertControlRejection(category, id: id) { try LoLaControlDatagramDecoder.decode(input) }
}

private func assertEncodedAudio(vector: JSONObject, expected: JSONObject, id: String) throws {
    let packets = try LoLaCompatibilityMediaCodec.audioFragments(
        sequenceNumber: UInt32(try #require(vector.integer("sequence"))),
        channels: 2,
        payload: try hex(try #require(vector.string("pcm_hex")))
    )
    #expect(packets.count == expected.integer("fragment_count"), "\(id): fragment count")
    let packet = try #require(packets.first)
    #expect(packet.payload.count == expected.integer("wire_size"), "\(id): exact padded wire size")
    let decoded = try LoLaCompatibilityMediaCodec.decode(packet.payload)
    let fragment = try #require(decoded.normalFragment)
    let frameID = try #require(expected.integer("frame_id"))
    let serialized = try hex(try #require(expected.string("serialized_hex")))
    #expect(fragment.header.frameID == UInt32(frameID), "\(id): frame ID")
    #expect(fragment.header.fragmentCount == expected.integer("fragment_count"), "\(id): fragment count in header")
    #expect(fragment.header.fragmentIndex == expected.integer("fragment_index"), "\(id): fragment index")
    #expect(fragment.header.originalOffset == expected.integer("original_offset"), "\(id): offset")
    #expect(fragment.header.fragmentPayloadLength == expected.integer("fragment_length"), "\(id): fragment length")
    #expect(fragment.header.finalFlag == (expected.integer("flags") == 1), "\(id): final flag")
    #expect(fragment.fragmentBytes == serialized, "\(id): serialized bytes")
}

private func assertEncodedVideo(vector: JSONObject, expected: JSONObject, id: String) throws {
    let packets = try LoLaCompatibilityMediaCodec.videoPackets(
        sequenceNumber: UInt32(try #require(vector.integer("sequence"))),
        payload: try hex(try #require(vector.string("payload_hex"))),
        maxFragmentBodyByteCount: try #require(vector.integer("packet_size")) - LoLaCompatibilityMediaModel.fragmentPayloadOffset
    )
    let prelude = try #require(packets.first)
    let preludeBytes = try hex(try #require(expected.string("prelude_hex")))
    let frameID = try #require(expected.integer("frame_id"))
    #expect(prelude.payload == preludeBytes, "\(id): prelude bytes")
    let decodedPrelude = try LoLaCompatibilityMediaCodec.decode(prelude.payload)
    #expect(decodedPrelude.videoPrelude?.frameID == UInt32(frameID), "\(id): prelude frame ID")
    #expect(decodedPrelude.videoPrelude?.serializedSize == expected.integer("serialized_size"), "\(id): serialized size")
    #expect(decodedPrelude.videoPrelude?.fragmentCount == expected.integer("fragment_count"), "\(id): fragment count")

    let expectedFragments = try #require(expected.array("fragments"))
    #expect(packets.count == expectedFragments.count + 1, "\(id): total datagrams")
    for (packet, fragmentExpected) in zip(packets.dropFirst(), expectedFragments) {
        let decoded = try LoLaCompatibilityMediaCodec.decode(packet.payload)
        let fragment = try #require(decoded.normalFragment)
        let fragmentBytes = try hex(try #require(fragmentExpected.string("data_hex")))
        #expect(fragment.header.fragmentIndex == fragmentExpected.integer("fragment_index"), "\(id): fragment index")
        #expect(fragment.header.frameID == UInt32(frameID), "\(id): frame ID")
        #expect(fragment.header.fragmentCount == expected.integer("fragment_count"), "\(id): fragment count in header")
        #expect(fragment.header.originalOffset == fragmentExpected.integer("original_offset"), "\(id): offset")
        #expect(fragment.header.fragmentPayloadLength == fragmentExpected.integer("fragment_length"), "\(id): fragment length")
        #expect(fragment.header.finalFlag == (fragmentExpected.integer("flags") == 1), "\(id): final flag")
        #expect(fragment.fragmentBytes == fragmentBytes, "\(id): fragment bytes")
    }
}

private func controlMessage(_ vector: JSONObject) throws -> String {
    let source = try #require(vector.string("src_ip"))
    let destination = try #require(vector.string("dst_ip"))
    let sessionID = try #require(vector.integer("sid"))
    switch try #require(vector.string("kind")) {
    case "MESG_QUICKCONN": return LoLaCompatibilityControlMessage.quickConnect(defaultMedia(source, destination, sessionID))
    case "MESG_CHECKLOLASTATUS_ACK": return LoLaCompatibilityControlMessage.checkStatusAck(sourceIP: source, destinationIP: destination, sessionID: sessionID)
    case "MESG_CHAT": return LoLaCompatibilityControlMessage.chat(sourceIP: source, destinationIP: destination, sessionID: sessionID, text: vector.string("txt") ?? String(repeating: vector.string("txt_repeat") ?? "", count: vector.integer("txt_count") ?? 0))
    case "MESG_REJECT": return LoLaCompatibilityControlMessage.reject(sourceIP: source, destinationIP: destination, sessionID: sessionID, text: vector.string("txt") ?? "")
    default: throw CorpusError.unsupportedControlKind
    }
}

private func defaultMedia(_ source: String, _ destination: String, _ sessionID: Int) -> LoLaCompatibilityMediaFields {
    LoLaCompatibilityMediaFields(
        session: .init(sourceIP: source, destinationIP: destination, sessionID: sessionID),
        audio: .init(sampleRateHertz: 44_100, bitsPerSample: 16, channels: 2),
        video: .init(frameRate: 25, bitsPerPixel: 8, dimensions: .init(width: 640, height: 480))
    )
}

private func lola2Manifest() throws -> JSONObject {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("interop/lola2/manifest.json")
    return try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? JSONObject)
}

private func paddedControlDatagram(_ input: String, vector: JSONObject) -> [UInt8] {
    var datagram = Array(input.utf8)
    guard let size = vector.integer("pad_to"), size > datagram.count else { return datagram }
    let byte = vector.string("pad_byte")?.utf8.first ?? 0
    datagram.append(contentsOf: repeatElement(byte, count: size - datagram.count))
    return datagram
}

private func assertControlRejection(
    _ expectedCategory: String,
    id: String,
    operation: () throws -> Any
) {
    do {
        _ = try operation()
        Issue.record("\(id): expected \(expectedCategory)")
    } catch let error as LoLaControlDatagramDecodingError {
        #expect(error.category.rawValue == expectedCategory, "\(id): exact normalized category")
    } catch {
        Issue.record("\(id): unexpected error \(error)")
    }
}

private func hex(_ value: String) throws -> Data {
    guard value.count.isMultiple(of: 2) else { throw CorpusError.invalidHex }
    return try Data(stride(from: 0, to: value.count, by: 2).map { offset in
        let start = value.index(value.startIndex, offsetBy: offset)
        let end = value.index(start, offsetBy: 2)
        guard let byte = UInt8(value[start..<end], radix: 16) else { throw CorpusError.invalidHex }
        return byte
    })
}

private typealias JSONObject = [String: Any]

private extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? { self[key] as? String }
    func integer(_ key: String) -> Int? { self[key] as? Int }
    func object(_ key: String) -> JSONObject? { self[key] as? JSONObject }
    func array(_ key: String) -> [JSONObject]? { self[key] as? [JSONObject] }
}

private enum CorpusError: Error { case invalidHex, unsupportedControlKind }
