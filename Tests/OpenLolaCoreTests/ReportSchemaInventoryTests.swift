import Foundation
import Testing

@testable import OpenLolaCore

@Test
func reportValidatorSurfaceFormatsStableValidatorOutput() throws {
    let data = try fixtureData("ReleaseHardeningReports/valid/release-hardening-partial.json")
    let output = try ReportValidatorSurface.validate(
        data,
        as: ReleaseHardeningReport.self,
        label: "release hardening report"
    )

    #expect(output.lines == [
        "release hardening report valid: m14-release-hardening-source-validation",
        "VERDICT: PARTIAL",
    ])
}

@Test
func reportValidatorSurfacePreservesReportSpecificExtraLines() throws {
    let data = try fixtureData("IntegratedProfileReports/valid/integrated-profile-partial.json")
    let output = try ReportValidatorSurface.validate(
        data,
        as: IntegratedProfileReport.self,
        label: "integrated profile report",
        extraLines: { ["aggregate-verdict: \($0.aggregateSubordinateVerdict.rawValue)"] }
    )

    #expect(output.lines == [
        "integrated profile report valid: m12-integrated-profile-partial-fixture",
        "aggregate-verdict: partial",
        "VERDICT: PARTIAL",
    ])
}

@Test
func reportValidatorSurfaceKeepsStrictValidationFailures() throws {
    let data = try fixtureData("ReleaseHardeningReports/invalid/release-hardening-synthetic-pass.json")

    #expect(throws: ReleaseHardeningValidationError.passWithoutMeasuredRun) {
        _ = try ReportValidatorSurface.validate(
            data,
            as: ReleaseHardeningReport.self,
            label: "release hardening report"
        )
    }
}

@Test
func reportJSONCodingSurfaceIsExplicitContractAndUtilityBacked() throws {
    let data = try fixtureData("ReleaseHardeningReports/valid/release-hardening-partial.json")
    let report = try JSONReportCoder.decode(ReleaseHardeningReport.self, from: data)
    let encoded = try JSONReportCoder.prettyJSONData(for: report)
    let decoded = try ReleaseHardeningReport.decode(from: encoded)

    #expect(decoded == report)
}

@Test
func reportValidatorArtifactSurfaceDefinesValidatorContract() throws {
    let source = try String(
        contentsOf: repositoryRoot.appendingPathComponent("Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift"),
        encoding: .utf8
    )
    #expect(source.contains("public protocol ReportValidatingArtifact: PrettyJSONCodable"))
    #expect(source.contains("var id: String { get }"))
    #expect(source.contains("var verdict: MeasurementVerdict { get }"))
    #expect(!source.contains("static func decode(from data: Data) throws -> Self"))
    #expect(source.contains("func validate() throws"))
    #expect(!source.contains(": ReportValidatingArtifact {}"))
}

@Test
func reportValidationLifecycleDefinesSharedValidationTemplate() throws {
    let surface = try String(
        contentsOf: repositoryRoot.appendingPathComponent("Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift"),
        encoding: .utf8
    )
    let integratedAv = try String(
        contentsOf: repositoryRoot.appendingPathComponent(
            "Sources/OpenLolaCore/Integration/IntegratedAvReportValidation.swift"
        ),
        encoding: .utf8
    )

    #expect(surface.contains("protocol ReportValidationLifecycle"))
    #expect(surface.contains("func validateIdentity() throws"))
    #expect(surface.contains("func validateFields() throws"))
    #expect(surface.contains("func validatePassVerdict() throws"))
    #expect(surface.contains("func validateLifecycle() throws"))
    #expect(integratedAv.contains("extension IntegratedAvReport: ReportValidationLifecycle"))
    #expect(integratedAv.contains("try validateLifecycle()"))
}

@Test
func reportMetadataArtifactSurfaceCoversSharedReleaseAndEvidenceReports() {
    assertReportMetadataArtifact(FieldReadyRuntimeProofReport.self)
    assertReportMetadataArtifact(HardwareValidationReport.self)
    assertReportMetadataArtifact(OpenSourceReleaseReadinessReport.self)
    assertReportMetadataArtifact(PackagingFieldTestReport.self)
    assertReportMetadataArtifact(ReferenceRigReport.self)
}

@Test
func reportSchemaInventoryMapsEveryCLIValidatorCommand() {
    let commandValidators = Set(CLICommandInventory.entries
        .filter { $0.kind == .validator }
        .map(\.command))
    let schemaValidators = Set(ReportSchemaInventory.entries.flatMap(\.validatorCommands))

    #expect(schemaValidators == commandValidators)
}

@Test
func reportSchemaInventoryLinksFixturesAndSyntheticSmokes() {
    let fixtureGroups = Set(FixtureSmokeMatrix.fixtureGroups.map(\.group))
    let smokeCommands = Set(FixtureSmokeMatrix.syntheticSmokes.map(\.command))

    for entry in ReportSchemaInventory.entries {
        if let fixtureGroup = entry.fixtureGroup {
            #expect(fixtureGroups.contains(fixtureGroup))
        }
        if let smokeCommand = entry.syntheticSmokeCommand {
            #expect(smokeCommands.contains(smokeCommand))
        }
    }
}

@Test
func reportSchemaInventoryEntriesHaveExistingOwnersAndTests() {
    let root = repositoryRoot

    for entry in ReportSchemaInventory.entries {
        #expect(!entry.schemaName.isEmpty)
        #expect(!entry.schemaFamily.isEmpty)
        #expect(entry.schemaVersion >= 1)
        #expect(entry.schemaChangePolicy.contains("Increment schemaVersion"))
        #expect(entry.schemaChangePolicy.contains("validators"))
        #expect(entry.schemaChangePolicy.contains("fixtures"))
        #expect(entry.schemaChangePolicy.contains("tests"))
        #expect(!entry.notes.isEmpty)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(entry.sourceFile).path))
        for path in entry.validationFiles + entry.relatedTestFiles {
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }
}

@Test
func reportSchemaInventoryDocumentsSchemaChangePolicyInSource() throws {
    let source = try String(
        contentsOf: repositoryRoot.appendingPathComponent(
            "Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift"
        ),
        encoding: .utf8
    )

    #expect(source.contains("public let schemaVersion: Int"))
    #expect(source.contains("public let schemaChangePolicy: String"))
    #expect(source.contains("Increment schemaVersion when the JSON contract changes"))
    #expect(source.contains("update validators, fixtures, and related tests"))
}

@Test
func reportSchemaInventoryTracksLoLaUdpMediaEvidenceSurface() throws {
    let session = try #require(ReportSchemaInventory.entries.first {
        $0.schemaName == "ExternalConnectorSessionReport"
    })
    let media = try #require(ReportSchemaInventory.entries.first {
        $0.schemaName == "LoLaCompatibilityMediaSessionReport"
    })

    #expect(session.notes.contains("post-control LoLa UDP socket media TX/RX"))
    #expect(media.validationFiles.contains("Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift"))
    #expect(media.notes.contains("post-control UDP socket"))
}

@Test
func reportSchemaInventoryKeepsParityLedgerValidationOnly() throws {
    let parity = try #require(ReportSchemaInventory.entries.first {
        $0.schemaName == "LoLaParityDeferredLedgerReport"
    })

    #expect(parity.validatorCommands == ["validate-lola-parity-deferred-ledger"])
    #expect(parity.syntheticSmokeCommand == nil)
}

@Test
func reportSchemaInventorySummaryMatchesEntries() {
    let entries = ReportSchemaInventory.entries
    let summary = ReportSchemaInventory.summary()

    #expect(summary.schemaCount == entries.count)
    #expect(summary.schemaCount == 63)
    #expect(summary.validatorCommandCount == CLICommandInventory.entries.filter { $0.kind == .validator }.count)
    #expect(summary.fixtureBackedSchemaCount == entries.filter { $0.fixtureGroup != nil }.count)
    #expect(summary.measuredEvidenceRequiredCount == entries.filter(\.passRequiresMeasuredEvidence).count)
    #expect(summary.cleanMacGateCount == 3)
    #expect(summary.falsePassFixtureCount == 9)
}

@Test
func reportSchemaInventoryJSONSurfaceRoundTrips() throws {
    let data = try OpenLolaCLI.reportSchemaInventoryData()
    let decoded = try JSONDecoder().decode(ReportSchemaInventoryReport.self, from: data)

    #expect(decoded == ReportSchemaInventory.report())
    #expect(decoded.verdict == .partial)
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private var fixtureRoot: URL {
    repositoryRoot.appendingPathComponent("Tests/OpenLolaCoreTests/Fixtures")
}

private func assertReportMetadataArtifact<Report: ReportMetadataArtifact>(_: Report.Type) {}

private func fixtureData(_ relativePath: String) throws -> Data {
    try Data(contentsOf: fixtureRoot.appendingPathComponent(relativePath))
}
