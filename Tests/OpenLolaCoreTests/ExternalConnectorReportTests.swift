import Foundation
import Testing

@testable import OpenLolaCore

@Test
func externalConnectorSyntheticSmokeCoversRequestedConnectors() throws {
    let report = ExternalConnectorSyntheticSmoke.run()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.sourceLevelVerdict == .pass)
    #expect(report.realWorldVerdict == .partial)
    #expect(report.connectors.map(\.connector) == ExternalConnectorKind.allCases)
    #expect(report.connectors.first { $0.connector == .lola }?.sourceContractImplemented == true)
    #expect(report.connectors.first { $0.connector == .lola }?.supportedHandshake == .protocolAwareTxRx)
    #expect(report.connectors.first { $0.connector == .lola }?.publicReference.contains("docs/reverse-engineering/README.md") == true)
    #expect(report.connectors.first { $0.connector == .lola }?.publicReference.contains("private/") == false)
    #expect(report.connectors.first { $0.connector == .lola }?.publicReference.contains("archive/") == false)
    #expect(report.assumptions.first?.contains("video prelude packets") == true)
    #expect(report.assumptions.contains { $0.contains("early process exits") })
    #expect(report.assumptions.contains { $0.contains("connector-scoped") })
    #expect(report.connectors.first { $0.connector == .lola }?.notes.contains("post-control UDP socket media TX/RX") == true)
    #expect(report.connectors.filter { $0.connector != .lola }.allSatisfy { $0.sourceContractImplemented })
    #expect(report.connectors.allSatisfy { !$0.realWorldInteroperabilityClaimed })
    #expect(report.connectors.allSatisfy { $0.preservesDefaultAudioFirstPath })
}

@Test
func externalConnectorReportFixtureDecodesAndValidates() throws {
    let report = try loadExternalConnectorFixture(named: "external-connectors-source-pass")

    try report.validate()

    #expect(report.connectors.count == 3)
    #expect(report.connectors.contains { $0.connector == .lola })
    #expect(report.connectors.contains { $0.connector == .mvtpUltraGrid })
    #expect(report.connectors.contains { $0.connector == .jackTrip })
}

@Test
func externalConnectorReportRejectsSourcePassWithIncompleteConnectorContract() throws {
    var report = ExternalConnectorSyntheticSmoke.run()
    report.connectors[0].sourceContractImplemented = false

    #expect(throws: ExternalConnectorValidationError.sourcePassWithoutImplementedContract("connectors")) {
        try report.validate()
    }
}

@Test
func externalConnectorReportRejectsRealWorldPassWithoutMeasuredEvidence() throws {
    var report = ExternalConnectorSyntheticSmoke.run()
    report.realWorldVerdict = .pass

    #expect(throws: ExternalConnectorValidationError.realWorldPassNotAllowed) {
        try report.validate()
    }
}

@Test
func externalConnectorReportRejectsClaimedInteropWithoutEvidence() throws {
    var report = ExternalConnectorSyntheticSmoke.run()
    report.connectors[0].realWorldInteroperabilityClaimed = true

    #expect(throws: ExternalConnectorValidationError.realWorldClaimWithoutEvidence("lola")) {
        try report.validate()
    }
}

@Test
func externalConnectorReportRejectsMissingConnector() throws {
    var report = ExternalConnectorSyntheticSmoke.run()
    report.connectors.removeAll { $0.connector == .jackTrip }

    #expect(throws: ExternalConnectorValidationError.missingConnector("jackTrip")) {
        try report.validate()
    }
}

@Test
func externalConnectorReportRejectsLatencyRisk() throws {
    var report = ExternalConnectorSyntheticSmoke.run()
    report.connectors[1].preservesDefaultAudioFirstPath = false

    #expect(throws: ExternalConnectorValidationError.audioFirstPathRisk("mvtpUltraGrid")) {
        try report.validate()
    }
}

@Test
func externalConnectorJSONRoundTripPreservesReport() throws {
    let report = ExternalConnectorSyntheticSmoke.run()
    let data = try report.prettyJSONData()
    let decoded = try ExternalConnectorReport.decode(from: data)

    #expect(decoded == report)
}

private func loadExternalConnectorFixture(named name: String) throws -> ExternalConnectorReport {
    let url = try externalConnectorFixtureURL(named: name)
    return try ExternalConnectorReport.decode(from: Data(contentsOf: url))
}

private func externalConnectorFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "ExternalConnectorReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "ExternalConnectorReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}
