import Foundation
import Testing

@testable import OpenLolaCore

@Test
func externalConnectorReportRejectsIncompleteSourceAndRealWorldPassClaims() throws {
    var report = ExternalConnectorSyntheticSmoke.run()
    report.connectors[0].sourceContractImplemented = false

    #expect(throws: ExternalConnectorValidationError.sourcePassWithoutImplementedContract("connectors")) {
        try report.validate()
    }

    report = ExternalConnectorSyntheticSmoke.run()
    report.realWorldVerdict = .pass

    #expect(throws: ExternalConnectorValidationError.realWorldPassNotAllowed) {
        try report.validate()
    }

    report = ExternalConnectorSyntheticSmoke.run()
    report.connectors[0].realWorldInteroperabilityClaimed = true

    #expect(throws: ExternalConnectorValidationError.realWorldClaimWithoutEvidence("lola")) {
        try report.validate()
    }

    report = ExternalConnectorSyntheticSmoke.run()
    report.connectors.removeAll { $0.connector == .jackTrip }

    #expect(throws: ExternalConnectorValidationError.missingConnector("jackTrip")) {
        try report.validate()
    }

    report = ExternalConnectorSyntheticSmoke.run()
    report.connectors[1].preservesDefaultAudioFirstPath = false

    #expect(throws: ExternalConnectorValidationError.audioFirstPathRisk("mvtpUltraGrid")) {
        try report.validate()
    }
}

@Test
func externalConnectorReportRequiresExplicitEvidenceProvenance() throws {
    var report = ExternalConnectorSyntheticSmoke.run()

    try report.validate()
    #expect(report.observedEvidenceClasses == [.synthetic])
    #expect(report.missingEvidenceClassesForRealWorldPass == [
        .localLoopback,
        .referencePeer,
        .liveDevice,
        .fieldRoute,
        .packetCapture,
        .timing,
        .teardown,
        .mediaQuality,
    ])
    #expect(ExternalConnectorEvidenceClass.runtimePassRequiredEvidence == [
        .referencePeer,
        .liveDevice,
        .fieldRoute,
        .packetCapture,
        .timing,
        .teardown,
        .mediaQuality,
    ])
    #expect(ExternalConnectorEvidenceClass.missingRuntimePassEvidence(observed: [.referencePeer]) == [
        .liveDevice,
        .fieldRoute,
        .packetCapture,
        .timing,
        .teardown,
        .mediaQuality,
    ])

    report.observedEvidenceClasses = []
    #expect(throws: ExternalConnectorValidationError.emptyList("observedEvidenceClasses")) {
        try report.validate()
    }

    report = ExternalConnectorSyntheticSmoke.run()
    report.missingEvidenceClassesForRealWorldPass = []
    #expect(throws: ExternalConnectorValidationError.emptyList("missingEvidenceClassesForRealWorldPass")) {
        try report.validate()
    }
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
