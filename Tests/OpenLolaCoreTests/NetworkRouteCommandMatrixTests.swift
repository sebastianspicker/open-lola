import Foundation
import Testing

@testable import OpenLolaCore

@Test
func networkRouteCommandMatrixSummaryMatchesEntries() {
    let entries = NetworkRouteCommandMatrix.entries
    let summary = NetworkRouteCommandMatrix.summary()

    #expect(summary.entryCount == entries.count)
    #expect(summary.entryCount == 31)
    #expect(summary.validatorCount == entries.filter { $0.kind == .validator }.count)
    #expect(summary.runCount == entries.filter { $0.kind == .run }.count)
    #expect(summary.localhostSmokeCount == entries.filter { $0.kind == .localhostSmoke }.count)
    #expect(summary.probeCount == entries.filter { $0.kind == .probe }.count)
    #expect(summary.fastestDirectEvidenceCount == 3)
    #expect(summary.natCompatibilityOnlyCount == 9)
    #expect(summary.diagnosticOnlyCount == 2)
    #expect(summary.loopbackMeasurementCount == 4)
    #expect(summary.packetContractOnlyCount == 4)
}

@Test
func networkRouteCommandMatrixEntriesHaveExistingOwnersSourcesAndTests() {
    let root = repositoryRoot

    for entry in NetworkRouteCommandMatrix.entries {
        #expect(!entry.command.isEmpty)
        #expect(!entry.parser.isEmpty)
        #expect(!entry.outputReport.isEmpty)
        #expect(!entry.representativeCommand.isEmpty)
        #expect(!entry.notes.isEmpty)
        #expect(FileManager.default.fileExists(
            atPath: root.appendingPathComponent(entry.ownerSourceFile).path
        ))
        for path in entry.relatedSourceFiles + entry.relatedTestFiles {
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }
}

@Test
func networkRouteCommandMatrixCommandsAreCoveredByCLIInventory() {
    let matrixCommands = Set(NetworkRouteCommandMatrix.entries.map(\.command))
    let inventoryCommands = Set(CLICommandInventory.entries.map(\.command))

    #expect(matrixCommands.isSubset(of: inventoryCommands))
    #expect(inventoryCommands.contains("network-route-command-matrix"))
}

@Test
func networkRouteCommandMatrixKeepsNatDiagnosticsAndLocalSmokesOutOfFastestEvidence() {
    let fastestCommands = Set(NetworkRouteCommandMatrix.entries
        .filter(\.canContributeToFastestDirectEvidence)
        .map(\.command))

    #expect(fastestCommands == [
        "udp-pcm-route-run",
        "validate-route-report",
        "validate-route-certification-report",
    ])

    for entry in NetworkRouteCommandMatrix.entries {
        if entry.evidenceBoundary == .natCompatibilityOnly
            || entry.evidenceBoundary == .diagnosticOnly
            || entry.evidenceBoundary == .loopbackMeasurement
            || entry.evidenceBoundary == .packetContractOnly
            || entry.evidenceBoundary == .directPeerSessionPartialOnly {
            #expect(!entry.canContributeToFastestDirectEvidence)
        }
    }
}

@Test
func networkRouteCommandMatrixJSONSurfaceRoundTrips() throws {
    let data = try OpenLolaCLI.networkRouteCommandMatrixData()
    let decoded = try JSONDecoder().decode(NetworkRouteCommandMatrixReport.self, from: data)

    #expect(decoded == NetworkRouteCommandMatrix.report())
    #expect(decoded.verdict == .partial)
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
