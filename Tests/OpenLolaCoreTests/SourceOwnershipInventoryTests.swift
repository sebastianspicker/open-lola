import Foundation
import Testing

@testable import OpenLolaCore

@Test
func sourceOwnershipInventorySummaryMatchesEntries() {
    let entries = SourceOwnershipInventory.entries
    let summary = SourceOwnershipInventory.summary()

    #expect(summary.groupCount == entries.count)
    #expect(summary.groupCount == 21)
    #expect(summary.lowRiskCount == entries.filter { $0.refactorRisk == .low }.count)
    #expect(summary.mediumRiskCount == entries.filter { $0.refactorRisk == .medium }.count)
    #expect(summary.highRiskCount == entries.filter { $0.refactorRisk == .high }.count)
    #expect(summary.firstMoveCandidateCount == 1)
    #expect(summary.movedInC02Count == 1)
}

@Test
func sourceOwnershipInventoryEntriesHaveExistingSourceTestFixtureAndDocPaths() {
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
            + entry.relatedDocs {
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }
}

@Test
func sourceOwnershipInventoryEntriesDoNotRepeatRelatedPaths() {
    for entry in SourceOwnershipInventory.entries {
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
func sourceOwnershipInventoryReportsFallbackOnlyCoverageSeparately() {
    let coverage = SourceOwnershipInventory.coverage(forSourcePaths: [
        "Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift",
        "Sources/UnknownRuntime/NewRuntimeFile.swift",
    ])

    #expect(coverage.unmatched == ["Sources/UnknownRuntime/NewRuntimeFile.swift"])
    #expect(coverage.fallbackOnly == [])
}

@Test
func sourceOwnershipInventoryDoesNotUseBroadFallbackOwners() throws {
    let source = try String(
        contentsOf: repositoryRoot
            .appendingPathComponent("Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift"),
        encoding: .utf8
    )
    let unknownPath = "Sources/OpenLolaCore/NewRuntimeLane/NewRuntimeFile.swift"
    let coverage = SourceOwnershipInventory.coverage(forSourcePaths: [unknownPath])

    #expect(!source.contains("sourceRootOwners"))
    #expect(!source.contains("fallbackRoot"))
    #expect(coverage.unmatched == [unknownPath])
    #expect(coverage.fallbackOnly == [])
}

@Test
func sourceOwnershipInventoryDistinguishesExactDirectoryAndProposedRootMatches() throws {
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
func externalConnectorOwnershipCoversLoLaProtocolSourceFiles() throws {
    let externalConnectors = try #require(SourceOwnershipInventory.entry(for: .externalConnectors))
    let owned = Set(externalConnectors.currentSourcePaths)

    for path in [
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityControlMessage.swift",
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityPacketFixture.swift",
        "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift",
    ] {
        #expect(owned.contains(path))
    }
}

@Test
func sourceOwnershipInventoryExposesC02CoreSupportMoveOnly() throws {
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
        "Sources/OpenLolaCore/Core/ValidationPrimitives.swift",
    ])

    let movedGroups = SourceOwnershipInventory.entries.filter(\.movedInC02).map(\.group)
    #expect(movedGroups == [.coreSupport])
}

@Test
func sourceOwnershipInventoryKeepsHighRiskRuntimeGroupsDeferred() {
    let deferredGroups: Set<SourceOwnershipGroup> = [
        .audioMadiRme,
        .audioRealtime,
        .networkUdp,
        .networkP2P,
        .networkNat,
        .videoCaptureTransport,
        .controlLightingAtemOsc,
        .releaseProofPackaging,
    ]

    for entry in SourceOwnershipInventory.entries where deferredGroups.contains(entry.group) {
        #expect(entry.refactorRisk == .high)
        #expect(!entry.firstMoveCandidate)
        #expect(!entry.movedInC02)
        #expect(entry.status == .active)
    }
}

@Test
func sourceOwnershipInventoryFencesVendoredThirdPartyTrees() throws {
    let vendor = try #require(SourceOwnershipInventory.entry(for: .thirdPartyVendoredCode))
    let udp = try #require(SourceOwnershipInventory.entry(for: .networkUdp))
    let video = try #require(SourceOwnershipInventory.entry(for: .videoCaptureTransport))

    #expect(vendor.currentSourcePaths == [
        "Sources/opus-1.5.2/",
        "Sources/xs_ref_sw_ed2/",
    ])
    #expect(vendor.runtimeRole == .thirdPartyVendorFence)
    #expect(vendor.status == .needsHumanReview)
    #expect(vendor.improvementRecommendation.contains("Do not treat upstream vendor internals as first-party"))
    #expect(!udp.currentSourcePaths.contains("Sources/opus-1.5.2/"))
    #expect(!video.currentSourcePaths.contains("Sources/xs_ref_sw_ed2/"))

    for path in [
        "Sources/opus-1.5.2/openlola_bridge/COpusBridge.c",
        "Sources/xs_ref_sw_ed2/libjxs/src/bitpacking.c",
    ] {
        let resolution = try #require(SourceOwnershipInventory.resolution(forSourcePath: path))
        #expect(resolution.entry.group == .thirdPartyVendoredCode)
        #expect(resolution.matchKind == .ownedDirectory)
    }
}

@Test
func sourceOwnershipInventoryCommandIsCoveredByCLIInventory() {
    let inventoryCommands = Set(CLICommandInventory.entries.map(\.command))

    #expect(inventoryCommands.contains("source-ownership-inventory"))
}

@Test
func sourceOwnershipInventoryJSONSurfaceRoundTrips() throws {
    let data = try OpenLolaCLI.sourceOwnershipInventoryData()
    let decoded = try JSONDecoder().decode(SourceOwnershipInventoryReport.self, from: data)

    #expect(decoded == SourceOwnershipInventory.report())
    #expect(decoded.verdict == .partial)
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
    for path in paths {
        if !seen.insert(path).inserted {
            duplicates.insert(path)
        }
    }
    return duplicates.sorted()
}
