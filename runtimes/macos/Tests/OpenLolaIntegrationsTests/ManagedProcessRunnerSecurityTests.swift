// Verifies managed process output and execution remain bounded on failure.
import Foundation
import XCTest
@testable import OpenLolaIntegrations

final class ManagedProcessRunnerSecurityTests: XCTestCase {
    func testTimeoutTerminatesSleepingExecutable() throws {
        let startedAt = Date()
        XCTAssertThrowsError(
            try ManagedProcessRunner.runToExit(
                executable: "/bin/sleep",
                arguments: ["5"],
                timeoutSeconds: 0.1
            )
        ) { error in
            XCTAssertEqual(error as? ManagedProcessTimeoutError, .init(executable: "/bin/sleep", timeoutSeconds: 0.1))
        }
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 2)
    }

    func testLogSymlinkIsRejectedWithoutChangingVictim() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let victim = directory.appendingPathComponent("victim")
        let log = directory.appendingPathComponent("stdout.log")
        try Data("unchanged".utf8).write(to: victim)
        try FileManager.default.createSymbolicLink(atPath: log.path, withDestinationPath: victim.path)

        XCTAssertThrowsError(
            try ManagedProcessRunner.start(
                executable: "/usr/bin/true",
                arguments: [],
                standardOutputPath: log.path
            )
        )
        XCTAssertEqual(try Data(contentsOf: victim), Data("unchanged".utf8))
    }

    func testChildOutputIsCappedAndPrivate() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = directory.appendingPathComponent("stdout.log")
        _ = try ManagedProcessRunner.runToExit(
            executable: "/bin/sh",
            arguments: ["-c", "head -c 1200000 /dev/zero"],
            standardOutputPath: log.path,
            timeoutSeconds: 5
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: log.path)
        XCTAssertLessThanOrEqual((attributes[.size] as? NSNumber)?.intValue ?? .max, 1_048_576)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-lola-managed-process-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
