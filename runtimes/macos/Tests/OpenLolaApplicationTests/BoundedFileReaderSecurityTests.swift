// Verifies bounded, single-handle reads reject unsafe files and oversized evidence.
import Foundation
import XCTest
@testable import OpenLolaApplication

final class BoundedFileReaderSecurityTests: XCTestCase {
    func testExactLimitAndOversizeRead() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("report")
        try Data(repeating: 65, count: 1024).write(to: file)
        XCTAssertEqual(try BoundedFileReader.data(at: file, maxBytes: 1024).count, 1024)
        XCTAssertThrowsError(try BoundedFileReader.data(at: file, maxBytes: 1023))
        XCTAssertThrowsError(try BoundedFileReader.data(at: file, maxBytes: -1))
        XCTAssertThrowsError(try BoundedFileReader.data(at: directory))
    }
}
