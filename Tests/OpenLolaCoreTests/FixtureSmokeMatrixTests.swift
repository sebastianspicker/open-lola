import Foundation
import Testing

@testable import OpenLolaCore

@Test
func fixtureSmokeMatrixMatchesFixtureTree() throws {
    let actualCounts = try fixtureFileCounts()
    let expectedCounts = Dictionary(
        uniqueKeysWithValues: FixtureSmokeMatrix.fixtureGroups.map {
            ($0.group, $0.expectedFileCount)
        }
    )

    #expect(actualCounts == expectedCounts)
    #expect(FixtureSmokeMatrix.summary().fixtureFileCount == 56)
    #expect(FixtureSmokeMatrix.summary().jsonFixtureCount == 53)
    #expect(FixtureSmokeMatrix.summary().hexFixtureCount == 3)
}

@Test
func fixtureSmokeMatrixHasOwnersForEveryFixtureGroup() {
    for entry in FixtureSmokeMatrix.fixtureGroups {
        #expect(!entry.group.isEmpty)
        #expect(entry.expectedFileCount > 0)
        #expect(!entry.fileExtensions.isEmpty)
        #expect(!entry.relatedSourceFiles.isEmpty)
        #expect(!entry.relatedTestFiles.isEmpty)
        #expect(entry.publicReleasePosture == .reviewPending)
        for path in entry.relatedSourceFiles + entry.relatedTestFiles {
            #expect(FileManager.default.fileExists(atPath: repositoryRoot.appendingPathComponent(path).path))
        }
    }
}

@Test
func fixtureSmokeMatrixLabelsEverySyntheticSmokeCommand() throws {
    let discoveredCommands = try discoverSyntheticSmokeCommands()
    let matrixCommands = Set(FixtureSmokeMatrix.syntheticSmokes.map(\.command))

    #expect(discoveredCommands == matrixCommands)
    for smoke in FixtureSmokeMatrix.syntheticSmokes {
        #expect(smoke.syntheticOnly)
        #expect(smoke.expectedVerdict == .partial)
        #expect(FileManager.default.fileExists(
            atPath: repositoryRoot.appendingPathComponent(smoke.sourceFile).path
        ))
        if let group = smoke.relatedFixtureGroup {
            #expect(FixtureSmokeMatrix.fixtureGroups.contains { $0.group == group })
        }
    }
}

@Test
func fixtureSmokeMatrixTracksHighRiskFalsePassFixtures() {
    let highRiskGroups = Set(FixtureSmokeMatrix.fixtureGroups.compactMap { entry in
        entry.requiresFalsePassFixture ? entry.group : nil
    })

    #expect(highRiskGroups == [
        "FieldReadyRuntimeProofs",
        "IntegratedAvReports",
        "PackagingFieldTests",
        "RealtimeAudioEngineReports",
        "ReleaseHardeningReports",
    ])
    #expect(FixtureSmokeMatrix.summary().highRiskFalsePassFixtureCount == 9)

    for entry in FixtureSmokeMatrix.fixtureGroups where entry.requiresFalsePassFixture {
        #expect(!entry.falsePassFixtures.isEmpty)
        for fixture in entry.falsePassFixtures {
            let path = fixtureRoot
                .appendingPathComponent(entry.group)
                .appendingPathComponent("invalid")
                .appendingPathComponent(fixture)
            #expect(FileManager.default.fileExists(atPath: path.path))
        }
    }
}

@Test
func fixtureSmokeMatrixDataUsesNamedFixtureShapeGroups() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift")

    #expect(source.contains("syntheticReportFixtureGroups"))
    #expect(source.contains("syntheticValidationFixtureGroups"))
    #expect(source.contains("supportFixtureGroups"))
    #expect(source.contains("syntheticReportFixtureGroups\n        + syntheticValidationFixtureGroups"))
}

@Test
func fixtureSmokeMatrixJSONSurfaceRoundTrips() throws {
    let data = try OpenLolaCLI.fixtureSmokeMatrixData()
    let decoded = try JSONDecoder().decode(FixtureSmokeMatrixReport.self, from: data)

    #expect(decoded == FixtureSmokeMatrix.report())
    #expect(decoded.verdict == .partial)
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private var fixtureRoot: URL {
    repositoryRoot.appendingPathComponent("Tests/OpenLolaCoreTests/Fixtures")
}

private func fixtureFileCounts() throws -> [String: Int] {
    var counts: [String: Int] = [:]
    guard let enumerator = FileManager.default.enumerator(
        at: fixtureRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return counts
    }

    for case let url as URL in enumerator {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else {
            continue
        }
        let relativePath = String(url.path.dropFirst(fixtureRoot.path.count + 1))
        guard let group = relativePath.split(separator: "/").first else {
            continue
        }
        counts[String(group), default: 0] += 1
    }
    return counts
}

private func discoverSyntheticSmokeCommands() throws -> Set<String> {
    let sourceRoot = repositoryRoot.appendingPathComponent("Sources/open-lola")
    let regex = try NSRegularExpression(pattern: #""([a-z0-9-]+-synthetic-smoke)""#)
    var commands = Set<String>()
    guard let enumerator = FileManager.default.enumerator(
        at: sourceRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return commands
    }

    for case let url as URL in enumerator where url.pathExtension == "swift" {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else {
            continue
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        for match in regex.matches(in: source, range: range) {
            guard let commandRange = Range(match.range(at: 1), in: source) else {
                continue
            }
            commands.insert(String(source[commandRange]))
        }
    }
    return commands
}

private func readRepositoryText(_ relativePath: String) throws -> String {
    try String(contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)
}
