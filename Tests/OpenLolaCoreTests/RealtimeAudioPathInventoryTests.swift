import Foundation
import Testing

@testable import OpenLolaCore

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
func realtimeAudioPathInventoryMachineReadableSurfaceMatchesRuntimeReport() throws {
    let data = try RealtimeAudioPathInventory.report().prettyJSONData()
    let decoded = try JSONDecoder().decode(RealtimeAudioPathInventoryReport.self, from: data)
    let commands = Set(CLICommandInventory.entries.map(\.command))

    #expect(decoded == RealtimeAudioPathInventory.report())
    #expect(decoded.verdict == .partial)
    #expect(decoded.summary.entryCount == decoded.entries.count)
    #expect(decoded.summary.fastestPassRelevantCount == decoded.entries.filter(\.fastestPassRelevant).count)
    #expect(commands.contains("realtime-audio-path-inventory"))
    #expect(decoded.notes.contains("does not claim real RME/MADI hardware readiness"))
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
