// Verifies that source ownership inventory entries have existing paths and no duplicates.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func sourceOwnershipInventoryEntriesHaveExistingPathsAndNoDuplicates() {
    let root = repositoryRoot

    for entry in SourceOwnershipInventory.entries {
        #expect(!entry.currentSourcePaths.isEmpty)
        #expect(!entry.proposedSourcePath.isEmpty)
        #expect(!entry.runtimeRole.rawValue.isEmpty)
        #expect(!entry.owner.isEmpty)
        #expect(!entry.validationCommands.isEmpty)

        for path in entry.currentSourcePaths
            + entry.relatedTestFiles
            + entry.relatedFixturePaths
            + entry.relatedDocs
            + entry.validationCommands.flatMap(repositoryRelativePaths) {
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }

        #expect(duplicatePaths(in: entry.currentSourcePaths) == [])
        #expect(duplicatePaths(in: entry.relatedTestFiles) == [])
        #expect(duplicatePaths(in: entry.relatedFixturePaths) == [])
        #expect(duplicatePaths(in: entry.relatedDocs) == [])
    }
}

@Test
func sourceOwnershipInventoryCoversEveryCurrentSourceFile() throws {
    let root = repositoryRoot
    let sourceRoot = root.appendingPathComponent("Sources")
    let sourceFiles = try currentSourceFiles(under: sourceRoot, root: root)
    let coverage = SourceOwnershipInventory.coverage(forSourcePaths: sourceFiles)

    #expect(!sourceFiles.isEmpty)
    #expect(coverage.unmatched == [])
    #expect(coverage.fallbackOnly == [])
}

@Test
func sourceOwnershipInventoryResolutionRejectsUnknownsAndKeepsMatchKindsDistinct() throws {
    let coverage = SourceOwnershipInventory.coverage(forSourcePaths: [
        "Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift",
        "Sources/UnknownRuntime/NewRuntimeFile.swift"
    ])

    #expect(coverage.unmatched == ["Sources/UnknownRuntime/NewRuntimeFile.swift"])
    #expect(coverage.fallbackOnly == [])

    let unknownPath = "Sources/OpenLolaCore/NewRuntimeLane/NewRuntimeFile.swift"
    let unknownCoverage = SourceOwnershipInventory.coverage(forSourcePaths: [unknownPath])

    #expect(SourceOwnershipInventory.resolution(forSourcePath: unknownPath) == nil)
    #expect(unknownCoverage.unmatched == [unknownPath])
    #expect(unknownCoverage.fallbackOnly == [])

    let exact = try #require(SourceOwnershipInventory.resolution(
        forSourcePath: "Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"
    ))
    let directory = try #require(SourceOwnershipInventory.resolution(
        forSourcePath: "Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift"
    ))
    let proposed = try #require(SourceOwnershipInventory.resolution(
        forSourcePath: "Sources/OpenLolaCore/Core/FutureCoreSupport.swift"
    ))

    #expect(exact.matchKind == .exactPath)
    #expect(directory.matchKind == .ownedDirectory)
    #expect(proposed.matchKind == .proposedRoot)
}

@Test
func sourceOwnershipInventoryPoliciesCoverExternalConnectorsCoreMovesRuntimeDeferralsAndVendorFence() throws {
    let externalConnectors = try #require(SourceOwnershipInventory.entry(for: .externalConnectors))

    assertExternalConnectorOwnership(externalConnectors)
    try assertCoreSupportMovePolicy()
    assertRuntimeDeferralPolicies()
    try assertVendorFencePolicy()

    let inventoryCommands = Set(CLICommandInventory.entries.map(\.command))
    #expect(inventoryCommands.contains("source-ownership-inventory"))
}

private func assertExternalConnectorOwnership(_ externalConnectors: SourceOwnershipEntry) {
    let owned = Set(externalConnectors.currentSourcePaths)

    for path in [
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityControlMessage.swift",
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityPacketFixture.swift",
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift"
    ] {
        #expect(owned.contains(path))
    }

}

private func assertCoreSupportMovePolicy() throws {
    let coreSupport = try #require(SourceOwnershipInventory.entry(for: .coreSupport))

    #expect(coreSupport.firstMoveCandidate)
    #expect(coreSupport.movedInC02)
    #expect(coreSupport.refactorRisk == .low)
    #expect(coreSupport.currentSourcePaths == [
        "Sources/OpenLolaContracts/",
        "Sources/OpenLolaCore/Core/CapabilitySummary.swift",
        "Sources/OpenLolaCore/Core/OpenLolaCLI.swift",
        "Sources/OpenLolaCore/Core/PeerIdentity.swift",
        "Sources/OpenLolaCore/Core/DebugTrace.swift",
        "Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift",
        "Sources/OpenLolaCore/Core/ValidationPrimitives.swift"
    ])

    let movedGroups = SourceOwnershipInventory.entries.filter(\.movedInC02).map(\.group)
    #expect(movedGroups == [.coreSupport])

}

private func assertRuntimeDeferralPolicies() {
    let deferredGroups: Set<SourceOwnershipGroup> = [
        .audioMadiRme,
        .audioRealtime,
        .networkUdp,
        .networkP2P,
        .networkNat,
        .videoCaptureTransport,
        .controlLightingAtemOsc,
        .releaseProofPackaging
    ]

    for entry in SourceOwnershipInventory.entries where deferredGroups.contains(entry.group) {
        #expect(entry.refactorRisk == .high)
        #expect(!entry.firstMoveCandidate)
        #expect(!entry.movedInC02)
        #expect(entry.status == .active)
    }

}

private func assertVendorFencePolicy() throws {
    let vendor = try #require(SourceOwnershipInventory.entry(for: .thirdPartyVendoredCode))
    let udp = try #require(SourceOwnershipInventory.entry(for: .networkUdp))
    let video = try #require(SourceOwnershipInventory.entry(for: .videoCaptureTransport))

    #expect(vendor.currentSourcePaths == [
        "Sources/opus-1.5.2/",
        "Sources/xs_ref_sw_ed2/"
    ])
    #expect(vendor.runtimeRole == .thirdPartyVendorFence)
    #expect(vendor.status == .needsHumanReview)
    #expect(vendor.improvementRecommendation.contains("Do not treat upstream vendor internals as first-party"))
    #expect(!udp.currentSourcePaths.contains("Sources/opus-1.5.2/"))
    #expect(!video.currentSourcePaths.contains("Sources/xs_ref_sw_ed2/"))

    for path in [
        "Sources/opus-1.5.2/openlola_bridge/COpusBridge.c",
        "Sources/xs_ref_sw_ed2/libjxs/src/bitpacking.c"
    ] {
        let resolution = try #require(SourceOwnershipInventory.resolution(forSourcePath: path))
        #expect(resolution.entry.group == .thirdPartyVendoredCode)
        #expect(resolution.matchKind == .ownedDirectory)
    }

}

@Test
func sourceOwnershipInventoryKeepsConnectorAndP2PReportStructureExplicitUntilDesignedMigration() throws {
    let externalConnectors = try #require(SourceOwnershipInventory.entry(for: .externalConnectors))
    let p2p = try #require(SourceOwnershipInventory.entry(for: .networkP2P))

    #expect(externalConnectors.currentSourcePaths.contains("Sources/OpenLolaCore/Connectors/"))
    #expect(externalConnectors.proposedSourcePath == "Sources/OpenLolaCore/Connectors/")
    #expect(externalConnectors.relatedTestFiles.contains("Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift"))
    #expect(externalConnectors.validationCommands.contains("swift test --filter ExternalConnectorSessionTests"))

    let reportPath = "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift"
    let reportResolution = try #require(SourceOwnershipInventory.resolution(forSourcePath: reportPath))

    #expect(reportResolution.entry.group == .networkP2P)
    #expect(reportResolution.matchKind == .ownedDirectory)
    #expect(p2p.proposedSourcePath == "Sources/OpenLolaCore/Network/P2P/")
    #expect(!externalConnectors.currentSourcePaths.contains(reportPath))
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func currentSourceFiles(under sourceRoot: URL, root: URL) throws -> [String] {
    let extensions = Set(["swift", "c", "h"])
    guard let enumerator = FileManager.default.enumerator(
        at: sourceRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    var paths: [String] = []
    for case let url as URL in enumerator {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true, extensions.contains(url.pathExtension) else {
            continue
        }
        paths.append(url.path.replacingOccurrences(of: root.path + "/", with: ""))
    }
    return paths.sorted()
}

private func duplicatePaths(in paths: [String]) -> [String] {
    var seen: Set<String> = []
    var duplicates: Set<String> = []
    for path in paths where !seen.insert(path).inserted {
        duplicates.insert(path)
    }
    return duplicates.sorted()
}

private func repositoryRelativePaths(in command: String) -> [String] {
    repositoryRelativePaths(in: command, trackedPrefixes: [
        "Package.swift", "README.md", "THIRD_PARTY_NOTICES.md", "Sources/", "Tests/",
        "docs/", "linux_connector/", "scripts/"
    ])
}
