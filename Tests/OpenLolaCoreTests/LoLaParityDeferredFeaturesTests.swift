import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaParityDeferredFixtureFactoryEmitsPartialLedger() throws {
    let report = LoLaParityDeferredFixtures.partialLedger()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.features.count >= 10)
    #expect(report.features.allSatisfy { $0.status == .deferred })
    #expect(report.features.allSatisfy { $0.preservesDefaultAudioPlayoutLatency })
    #expect(Set(report.features.map(\.featureId)).count == report.features.count)
    #expect(report.features.contains { $0.category == .windowsCompatibility })
    #expect(report.features.contains { $0.category == .appRuntime })
}

@Test
func lolaParityDeferredLedgerRejectsInvalidPassAndFeatureEvidence() throws {
    var report = LoLaParityDeferredFixtures.partialLedger()
    report.features.append(report.features[0])

    #expect(throws: LoLaParityDeferredValidationError.duplicateFeatureId(report.features[0].featureId)) {
        try report.validate()
    }

    report = try passCandidateReport()
    report.features[0].status = .deferred
    report.features[0].ownMeasuredReportId = ""

    #expect(throws: LoLaParityDeferredValidationError.passWithoutMeasuredFeatureReport(
        report.features[0].featureId
    )) {
        try report.validate()
    }

    report = try passCandidateReport()
    let featureIndex = try #require(report.features.firstIndex { $0.category == .windowsCompatibility })
    report.features[featureIndex].changesNativeUdpPcmDefaults = true

    #expect(throws: LoLaParityDeferredValidationError.passChangesNativePacketDefaults(
        report.features[featureIndex].featureId
    )) {
        try report.validate()
    }

    report = try passCandidateReport()
    let appFeatureIndex = try #require(report.features.firstIndex { $0.category == .appRuntime })
    report.features[appFeatureIndex].uiOwnsRealtimePaths = true

    #expect(throws: LoLaParityDeferredValidationError.passWithUIRealtimeOwnership(
        report.features[appFeatureIndex].featureId
    )) {
        try report.validate()
    }

    report = try passCandidateReport()
    report.features[0].preservesDefaultAudioPlayoutLatency = false

    #expect(throws: LoLaParityDeferredValidationError.passWithDefaultAudioLatencyRisk(
        report.features[0].featureId
    )) {
        try report.validate()
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
