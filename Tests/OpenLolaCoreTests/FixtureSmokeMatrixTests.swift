// Verifies that fixture smoke matrix matches fixture tree.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func fixtureSmokeMatrixMatchesFixtureTree() throws {
    let actualCounts = try fixtureFileCounts()
    let actualExtensionCounts = try fixtureExtensionCounts()
    let expectedCounts = Dictionary(
        uniqueKeysWithValues: FixtureSmokeMatrix.fixtureGroups.map {
            ($0.group, $0.expectedFileCount)
        }
    )
    let summary = FixtureSmokeMatrix.summary()

    #expect(actualCounts == expectedCounts)
    #expect(summary.fixtureFileCount == actualCounts.values.reduce(0, +))
    #expect(summary.jsonFixtureCount == actualExtensionCounts["json"])
    #expect(summary.hexFixtureCount == actualExtensionCounts["hex"])
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
    let discoveredCommands = Set(CLICommandInventory.entries
        .map(\.command)
        .filter { $0.hasSuffix("-synthetic-smoke") })
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
    let schemaFalsePassGroups = Set(ReportSchemaInventory.entries.compactMap { entry in
        entry.falsePassFixtureCount > 0 ? entry.fixtureGroup : nil
    })
    let falsePassFixtureCount = FixtureSmokeMatrix.fixtureGroups
        .map(\.falsePassFixtures.count)
        .reduce(0, +)

    #expect(highRiskGroups == schemaFalsePassGroups)
    #expect(falsePassFixtureCount == ReportSchemaInventory.summary().falsePassFixtureCount)
    #expect(FixtureSmokeMatrix.summary().highRiskFalsePassFixtureCount == falsePassFixtureCount)

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
    try forEachFixtureFile { url in
        let relativePath = String(url.path.dropFirst(fixtureRoot.path.count + 1))
        guard let group = relativePath.split(separator: "/").first else {
            return
        }
        counts[String(group), default: 0] += 1
    }
    return counts
}

private func fixtureExtensionCounts() throws -> [String: Int] {
    var counts: [String: Int] = [:]
    try forEachFixtureFile { url in
        counts[url.pathExtension, default: 0] += 1
    }
    return counts
}

private func forEachFixtureFile(_ body: (URL) throws -> Void) throws {
    guard let enumerator = FileManager.default.enumerator(
        at: fixtureRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return
    }

    for case let url as URL in enumerator {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else {
            continue
        }
        try body(url)
    }
}
