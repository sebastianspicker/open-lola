import Foundation
import Testing

@testable import OpenLolaCore

@Test
func boundedFileReaderRejectsOversizedInputBeforeDecode() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-bounded-reader-\(UUID().uuidString).json")
    FileManager.default.createFile(atPath: url.path, contents: Data("abcd".utf8))
    defer {
        try? FileManager.default.removeItem(at: url)
    }

    #expect(throws: BoundedFileReadError.fileTooLarge(path: url.path, bytes: 4, limit: 3)) {
        _ = try BoundedFileReader.data(at: url, maxBytes: 3)
    }
}

@Test
func boundedFileReaderDecodesSmallJSONPayloads() throws {
    struct Payload: Codable, Equatable {
        let id: String
    }

    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-bounded-reader-\(UUID().uuidString).json")
    try Data(#"{"id":"ok"}"#.utf8).write(to: url)
    defer {
        try? FileManager.default.removeItem(at: url)
    }

    let payload = try BoundedFileReader.decodeJSON(Payload.self, fromPath: url.path)

    #expect(payload == Payload(id: "ok"))
}

@Test
func boundedFileReaderRejectsUndecodableTextPayloads() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-bounded-reader-\(UUID().uuidString).txt")
    try Data([0xFF, 0xFE, 0xFD]).write(to: url)
    defer {
        try? FileManager.default.removeItem(at: url)
    }

    #expect(throws: BoundedFileReadError.unreadableText(
        path: url.path,
        encoding: String(describing: String.Encoding.utf8)
    )) {
        _ = try BoundedFileReader.string(at: url, encoding: .utf8)
    }
}
