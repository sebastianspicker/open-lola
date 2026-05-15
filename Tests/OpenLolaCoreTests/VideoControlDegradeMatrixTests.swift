import Foundation
import Testing

@testable import OpenLolaCore

@Test
func videoControlDegradeMatrixSummaryMatchesEntries() {
    let entries = VideoControlDegradeMatrix.entries
    let summary = VideoControlDegradeMatrix.summary()

    #expect(summary.entryCount == entries.count)
    #expect(summary.entryCount == 9)
    #expect(summary.commandBackedCount == 9)
    #expect(summary.audioProtectedCount == 9)
    #expect(summary.degradeBeforeAudioLatencyRequiredCount == 5)
    #expect(summary.audioBaselineRequiredForPassCount == 8)
    #expect(summary.passEvidenceRequiredCount == 9)
    #expect(summary.readOnlyControlCount == 1)
    #expect(summary.armedByDefaultCount == 0)
}

@Test
func videoControlDegradeMatrixEntriesHaveExistingSourcesTestsAndDocs() {
    let root = repositoryRoot

    for entry in VideoControlDegradeMatrix.entries {
        #expect(!entry.primarySourceFile.isEmpty)
        #expect(!entry.relatedTestFiles.isEmpty)
        #expect(!entry.relatedDocs.isEmpty)
        #expect(!entry.notes.isEmpty)
        #expect(FileManager.default.fileExists(
            atPath: root.appendingPathComponent(entry.primarySourceFile).path
        ))
        for path in entry.relatedSourceFiles + entry.relatedTestFiles + entry.relatedDocs {
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }
}

@Test
func videoControlDegradeMatrixCommandsAreCoveredByCLIInventory() {
    let matrixCommands = Set(VideoControlDegradeMatrix.entries.flatMap(\.relatedCommands))
    let inventoryCommands = Set(CLICommandInventory.entries.map(\.command))

    #expect(matrixCommands.isSubset(of: inventoryCommands))
    #expect(inventoryCommands.contains("video-control-degrade-matrix"))
}

@Test
func videoControlDegradeMatrixKeepsControlSurfacesDisarmedByDefault() throws {
    #expect(VideoControlDegradeMatrix.entries.allSatisfy { $0.audioProtected })
    #expect(VideoControlDegradeMatrix.entries.allSatisfy { !$0.destructiveControlArmedByDefault })

    let atem = try #require(VideoControlDegradeMatrix.entries.first {
        $0.surface == .atemReadOnlyControl
    })
    #expect(atem.evidenceBoundary == .readOnlyControl)
    #expect(atem.notes.contains("disarmed"))
}

@Test
func videoControlDegradeMatrixHelperRequiresExplicitAudioProtection() throws {
    let source = try String(
        contentsOf: repositoryRoot
            .appendingPathComponent("Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift"),
        encoding: .utf8
    )

    #expect(source.contains("_ audioProtected: Bool"))
    #expect(source.contains("audioProtected: audioProtected"))
}

@Test
func videoControlDegradeMatrixRequiresDegradeBeforeIntegratedAudioImpact() throws {
    let degradeFirstSurfaces = Set(VideoControlDegradeMatrix.entries
        .filter(\.degradeBeforeAudioLatencyRequired)
        .map(\.surface))

    #expect(degradeFirstSurfaces == [
        .videoTransport,
        .videoRenderOutput,
        .multiVideoStreams,
        .integratedAv,
        .integratedProfile,
    ])

    let integratedAv = try #require(VideoControlDegradeMatrix.entries.first {
        $0.surface == .integratedAv
    })
    #expect(integratedAv.audioBaselineRequiredForPass)
    #expect(integratedAv.notes.contains("audio-only baseline first"))
}

@Test
func videoControlDegradeMatrixJSONSurfaceRoundTrips() throws {
    let data = try OpenLolaCLI.videoControlDegradeMatrixData()
    let decoded = try JSONDecoder().decode(VideoControlDegradeMatrixReport.self, from: data)

    #expect(decoded == VideoControlDegradeMatrix.report())
    #expect(decoded.verdict == .partial)
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
