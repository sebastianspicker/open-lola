import Foundation
import Testing

@testable import OpenLolaCore

@Test
func releaseRunConfigurationsDocumentProgrammaticRunnerContracts() throws {
    let contracts = [
        (
            path: "Sources/OpenLolaCore/Release/FieldReadinessRun.swift",
            configuration: "FieldReadinessRunConfiguration",
            documentation: "CLI and programmatic input contract for the aggregate field-readiness runner"
        ),
        (
            path: "Sources/OpenLolaCore/Release/PackagingFieldTestRun.swift",
            configuration: "PackagingFieldRunConfiguration",
            documentation: "CLI and programmatic input contract for packaging field-test artifact generation"
        ),
        (
            path: "Sources/OpenLolaCore/Release/RecordingSessionRun.swift",
            configuration: "RecordingSessionRunConfiguration",
            documentation: "CLI and programmatic input contract for recording-session artifact generation"
        ),
        (
            path: "Sources/OpenLolaCore/Release/FasterThanLoLaClosure.swift",
            configuration: "FasterThanLoLaClosureRunConfiguration",
            documentation: "CLI and programmatic input contract for faster-than-LoLa closure evidence aggregation"
        ),
    ]

    for contract in contracts {
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent(contract.path),
            encoding: .utf8
        )
        #expect(source.contains("/// \(contract.documentation)."))
        #expect(source.contains("public struct \(contract.configuration): Codable, Equatable, Sendable"))
        #expect(source.contains("public static func parse(_ arguments: [String]) throws -> \(contract.configuration)"))
        #expect(source.contains("configuration: \(contract.configuration)"))
    }
}

@Test
func testingIndexDocumentsActiveReleaseValidationHarnesses() throws {
    let testingIndex = try String(
        contentsOf: repositoryRoot.appendingPathComponent("docs/testing/README.md"),
        encoding: .utf8
    )

    #expect(testingIndex.contains("## Release Validation Harnesses"))
    #expect(testingIndex.contains("OpenSourceReleaseReadiness.swift"))
    #expect(testingIndex.contains("PackagingFieldTest*.swift"))
    #expect(testingIndex.contains("RecordingSession*.swift"))
    #expect(testingIndex.contains("ReleaseHardening*.swift"))
    #expect(testingIndex.contains("No `Release/` Swift harness is archived as dead code"))
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
