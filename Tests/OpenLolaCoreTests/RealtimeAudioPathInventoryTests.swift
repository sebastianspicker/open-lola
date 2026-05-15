import Foundation
import Testing

@testable import OpenLolaCore

@Test
func realtimeAudioPathInventorySummaryMatchesEntries() {
    let entries = RealtimeAudioPathInventory.entries
    let summary = RealtimeAudioPathInventory.summary()

    #expect(summary.entryCount == entries.count)
    #expect(summary.entryCount == 25)
    #expect(summary.realtimePathCount == 7)
    #expect(summary.nearRealtimePathCount == 9)
    #expect(summary.reportOnlyCount == 6)
    #expect(summary.syntheticOnlyCount == 3)
    #expect(summary.fastestPassRelevantCount == entries.filter(\.fastestPassRelevant).count)
}

@Test
func realtimeAudioPathInventoryEntriesHaveExistingSourceTestsAndDocs() {
    let root = repositoryRoot

    for entry in RealtimeAudioPathInventory.entries {
        #expect(!entry.role.isEmpty)
        #expect(!entry.notes.isEmpty)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(entry.sourceFile).path))
        for path in entry.relatedTestFiles + entry.relatedDocs {
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }
}

@Test
func realtimeAudioPathInventoryLabelsAllC06AffectedClasses() {
    let classes = Set(RealtimeAudioPathInventory.entries.map(\.pathClass))
    let sourceFiles = Set(RealtimeAudioPathInventory.entries.map(\.sourceFile))

    #expect(classes == [.realtimePath, .nearRealtimePath, .reportOnly, .syntheticOnly])
    #expect(sourceFiles.contains("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift"))
    #expect(sourceFiles.contains("Sources/OpenLolaCore/Timing/RxBuffering.swift"))
    #expect(sourceFiles.contains("Sources/OpenLolaCore/Timing/LatencyProfileContracts.swift"))
    #expect(sourceFiles.contains("Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift"))
    #expect(sourceFiles.contains("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift"))
    #expect(sourceFiles.contains("Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift"))
}

@Test
func realtimeAudioPathInventoryJSONSurfaceRoundTrips() throws {
    let data = try OpenLolaCLI.realtimeAudioPathInventoryData()
    let decoded = try JSONDecoder().decode(RealtimeAudioPathInventoryReport.self, from: data)

    #expect(decoded == RealtimeAudioPathInventory.report())
    #expect(decoded.verdict == .partial)
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
