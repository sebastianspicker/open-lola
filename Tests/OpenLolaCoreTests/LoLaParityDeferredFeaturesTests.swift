import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaParityDeferredLedgerFixtureDecodesAndValidates() throws {
    let report = try loadLoLaParityDeferredLedgerFixture(named: "lola-parity-deferred-ledger-partial")

    try report.validate()

    #expect(report.runMode == .synthetic)
    #expect(report.verdict == .partial)
    #expect(report.fastestPathBlockedByParity == false)
    #expect(report.nativePacketContractDefaultsProtected)
    #expect(report.features.contains { $0.featureId == "windows-wire-compatibility" })
}

@Test
func lolaParityDeferredFixtureFactoryEmitsPartialLedger() throws {
    let report = LoLaParityDeferredFixtures.partialLedger()
    let source = try readLoLaParityDeferredSource()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.features.count >= 10)
    #expect(report.features.allSatisfy { $0.status == .deferred })
    #expect(report.features.allSatisfy { $0.preservesDefaultAudioPlayoutLatency })
    #expect(source.contains("public enum LoLaParityDeferredFixtures"))
    #expect(source.contains("@available(*, deprecated"))
    #expect(source.contains("fixture/documentation scaffolding only"))
    #expect(source.contains("LoLaParityDeferredFixtures.partialLedger()"))
}

@Test
func lolaParityDeferredLedgerRejectsDuplicateFeatureIds() throws {
    var report = LoLaParityDeferredFixtures.partialLedger()
    report.features.append(report.features[0])

    #expect(throws: LoLaParityDeferredValidationError.duplicateFeatureId(report.features[0].featureId)) {
        try report.validate()
    }
}

@Test
func lolaParityDeferredLedgerRejectsPassWithDeferredFeature() throws {
    var report = try passCandidateReport()
    report.features[0].status = .deferred
    report.features[0].ownMeasuredReportId = ""

    #expect(throws: LoLaParityDeferredValidationError.passWithoutMeasuredFeatureReport(
        report.features[0].featureId
    )) {
        try report.validate()
    }
}

@Test
func lolaParityDeferredLedgerRejectsPassWhenCompatibilityChangesNativeDefaults() throws {
    var report = try passCandidateReport()
    let featureIndex = try #require(report.features.firstIndex { $0.category == .windowsCompatibility })
    report.features[featureIndex].changesNativeUdpPcmDefaults = true

    #expect(throws: LoLaParityDeferredValidationError.passChangesNativePacketDefaults(
        report.features[featureIndex].featureId
    )) {
        try report.validate()
    }
}

@Test
func lolaParityDeferredLedgerRejectsPassWhenUIOwnsRealtimePaths() throws {
    var report = try passCandidateReport()
    let featureIndex = try #require(report.features.firstIndex { $0.category == .appRuntime })
    report.features[featureIndex].uiOwnsRealtimePaths = true

    #expect(throws: LoLaParityDeferredValidationError.passWithUIRealtimeOwnership(
        report.features[featureIndex].featureId
    )) {
        try report.validate()
    }
}

@Test
func lolaParityDeferredLedgerRejectsPassWithAudioLatencyRisk() throws {
    var report = try passCandidateReport()
    report.features[0].preservesDefaultAudioPlayoutLatency = false

    #expect(throws: LoLaParityDeferredValidationError.passWithDefaultAudioLatencyRisk(
        report.features[0].featureId
    )) {
        try report.validate()
    }
}

@Test
func lolaParityDeferredLedgerJSONRoundTripPreservesReport() throws {
    let report = try loadLoLaParityDeferredLedgerFixture(named: "lola-parity-deferred-ledger-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try LoLaParityDeferredLedgerReport.decode(from: jsonData)

    #expect(decoded == report)
}

@Test
func deferredFeatureTodoMarkersStayCrossReferencedToLedgerFeatureIds() throws {
    let featureIds = Set(LoLaParityDeferredFixtures.partialLedger().features.map(\.featureId))
    let todoReferences = try sourceTodoDeferredFeatureReferences()

    for reference in todoReferences {
        #expect(featureIds.contains(reference.featureId))
        #expect(reference.line.contains("LoLaParityDeferredFeatures") || reference.line.contains(reference.featureId))
    }
}

private func passCandidateReport() throws -> LoLaParityDeferredLedgerReport {
    var report = LoLaParityDeferredFixtures.partialLedger()
    report.verdict = .pass
    report.runMode = .measured
    report.features = report.features.map { feature in
        var measuredFeature = feature
        measuredFeature.status = .measured
        measuredFeature.ownMeasuredReportId = "measured-\(feature.featureId)-report"
        return measuredFeature
    }
    return report
}

private func loadLoLaParityDeferredLedgerFixture(named name: String) throws -> LoLaParityDeferredLedgerReport {
    let url = try lolaParityDeferredLedgerFixtureURL(named: name)
    return try LoLaParityDeferredLedgerReport.decode(from: Data(contentsOf: url))
}

private func lolaParityDeferredLedgerFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "LoLaParityDeferredLedgers/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "LoLaParityDeferredLedgers/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}

private struct DeferredFeatureTodoReference {
    let featureId: String
    let line: String
}

private func sourceTodoDeferredFeatureReferences() throws -> [DeferredFeatureTodoReference] {
    let root = repositoryRoot()
    let sourceRoot = root.appendingPathComponent("Sources")
    let featureIds = LoLaParityDeferredFixtures.partialLedger().features.map(\.featureId)
    guard let enumerator = FileManager.default.enumerator(
        at: sourceRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    var references: [DeferredFeatureTodoReference] = []
    for case let url as URL in enumerator where url.pathExtension == "swift" {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else {
            continue
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        for line in source.components(separatedBy: .newlines) where line.contains("TODO") {
            for featureId in featureIds where line.contains(featureId) {
                references.append(DeferredFeatureTodoReference(featureId: featureId, line: line))
            }
        }
    }
    return references
}

private func readLoLaParityDeferredSource() throws -> String {
    try String(
        contentsOf: repositoryRoot().appendingPathComponent(
            "Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift"
        ),
        encoding: .utf8
    )
}

private func repositoryRoot() -> URL {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return root
}
