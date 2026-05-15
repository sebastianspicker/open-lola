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
func cliAndAppReportReadersUseBoundedFileReader() throws {
    for path in [
        "Sources/open-lola/Commands/CLICommandHelpers.swift",
        "Sources/open-lola/main.swift",
        "Sources/open-lola/Commands/MilestoneCommands.swift",
        "Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift",
        "Sources/open-lola/Commands/Network/NetworkCommands.swift",
        "Sources/open-lola/Commands/Network/DirectP2PSessionRunCommandSupport.swift",
        "Sources/open-lola/Commands/Network/DirectP2PTwoPeerLocalRunCommandSupport.swift",
        "Sources/open-lola-app/AppExecutionController.swift",
        "Sources/open-lola-app/AppLatencyHeroMetrics.swift",
        "Sources/OpenLolaCore/Platform/NativeAppShellArtifacts.swift",
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReport.swift",
        "Sources/OpenLolaCore/Release/RecordingSessionRun.swift",
        "Sources/OpenLolaCore/Release/PackagingFieldTestRun.swift",
    ] {
        let source = try readRepositoryText(path)
        #expect(!source.contains("Data(contentsOf:"))
        #expect(!source.contains("String(contentsOf:"))
        #expect(source.contains("BoundedFileReader") || source.contains("readValidated"))
    }
}

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
