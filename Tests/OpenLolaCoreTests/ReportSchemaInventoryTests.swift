// Verifies that report validator surface formats output, extra lines, strict failures, and JSON encoding.
import Foundation
import OpenLolaContracts
import Testing

@testable import OpenLolaCore

@Test
func reportValidatorSurfaceFormatsOutputExtraLinesStrictFailuresAndJSONCoding() throws {
    let releaseData = try fixtureData("ReleaseHardeningReports/valid/release-hardening-partial.json")
    let releaseOutput = try ReportValidatorSurface.validate(
        releaseData,
        as: ReleaseHardeningReport.self,
        label: "release hardening report"
    )

    #expect(releaseOutput.lines == [
        "release hardening report valid: m14-release-hardening-source-validation",
        "VERDICT: PARTIAL"
    ])

    let profileData = try fixtureData("IntegratedProfileReports/valid/integrated-profile-partial.json")
    let profileOutput = try ReportValidatorSurface.validate(
        profileData,
        as: IntegratedProfileReport.self,
        label: "integrated profile report",
        extraLines: { ["aggregate-verdict: \($0.aggregateSubordinateVerdict.rawValue)"] }
    )

    #expect(profileOutput.lines == [
        "integrated profile report valid: m12-integrated-profile-partial-fixture",
        "aggregate-verdict: partial",
        "VERDICT: PARTIAL"
    ])

    let invalidData = try fixtureData("ReleaseHardeningReports/invalid/release-hardening-synthetic-pass.json")

    #expect(throws: ReleaseHardeningValidationError.passWithoutMeasuredRun) {
        _ = try ReportValidatorSurface.validate(
            invalidData,
            as: ReleaseHardeningReport.self,
            label: "release hardening report"
        )
    }

    let report = try ReleaseHardeningReport.decode(from: releaseData)
    let encoded = try report.prettyJSONData()
    let decoded = try ReleaseHardeningReport.decode(from: encoded)

    #expect(decoded == report)
}

@Test
func reportSchemaInventoryKeepsPublicManifestBackedByValidatorFixtures() throws {
    let commandValidators = Set(CLICommandInventory.entries
        .filter { $0.kind == .validator }
        .map(\.command))
    let schemaValidators = Set(ReportSchemaInventory.entries.flatMap(\.validatorCommands))

    #expect(schemaValidators == commandValidators)

    let fixtureGroups = Dictionary(
        uniqueKeysWithValues: FixtureSmokeMatrix.fixtureGroups.map { ($0.group, $0) }
    )
    let validationCases = Dictionary(
        uniqueKeysWithValues: reportFixtureValidationCases().map { ($0.group, $0) }
    )
    let smokeCommands = Set(FixtureSmokeMatrix.syntheticSmokes.map(\.command))

    for entry in ReportSchemaInventory.entries {
        if let fixtureGroup = entry.fixtureGroup {
            let fixtureEntry = try #require(fixtureGroups[fixtureGroup])
            let validationCase = try #require(validationCases[fixtureGroup])

            #expect(validationCase.schemaName == entry.schemaName)
            #expect(fixtureEntry.falsePassFixtures.count == entry.falsePassFixtureCount)
            #expect(fixtureEntry.requiresFalsePassFixture == (entry.falsePassFixtureCount > 0))
            for fixture in validationCase.acceptedValidFixtures {
                let path = fixtureRoot
                    .appendingPathComponent(fixtureGroup)
                    .appendingPathComponent("valid")
                    .appendingPathComponent(fixture)
                #expect(FileManager.default.fileExists(atPath: path.path))
            }
        }
        if let smokeCommand = entry.syntheticSmokeCommand {
            #expect(smokeCommands.contains(smokeCommand))
        }
    }

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
func metadataReportsDecodeValidateAndExposeMeaningfulMetadata() throws {
    for snapshot in try metadataReportSnapshots() {
        #expect(!snapshot.name.isEmpty)
        #expect(!snapshot.id.isEmpty)
        #expect(!snapshot.title.isEmpty)
        #expect(ISO8601DateFormatter().date(from: snapshot.capturedAt) != nil)
        #expect(!snapshot.notes.isEmpty)
        #expect(snapshot.verdict != .fail)
    }
}

private func metadataReportSnapshots() throws -> [ReportMetadataSnapshot] {
    try coreMetadataReportSnapshots()
        + packagingMetadataReportSnapshots()
}

private func coreMetadataReportSnapshots() throws -> [ReportMetadataSnapshot] {
    let fieldReady = try FieldReadyRuntimeProofReport.decode(
        from: fixtureData("FieldReadyRuntimeProofs/valid/field-runtime-proof-partial.json")
    )
    let hardware = try HardwareValidationReport.decode(
        from: fixtureData("HardwareValidationReports/valid/hardware-validation-partial.json")
    )
    let openSource = OpenSourceReleaseReadinessRunner.run(
        configuration: OpenSourceReleaseReadinessRunConfiguration(outputPath: "metadata-check.json"),
        repositoryRoot: repositoryRoot
    )
    try fieldReady.validate()
    try hardware.validate()
    try openSource.validate()

    return [
        metadataSnapshot(
            name: "FieldReadyRuntimeProofReport",
            id: fieldReady.id,
            title: fieldReady.title,
            capturedAt: fieldReady.capturedAt,
            notes: fieldReady.notes,
            verdict: fieldReady.verdict
        ),
        metadataSnapshot(
            name: "HardwareValidationReport",
            id: hardware.id,
            title: hardware.title,
            capturedAt: hardware.capturedAt,
            notes: hardware.notes,
            verdict: hardware.verdict
        ),
        metadataSnapshot(
            name: "OpenSourceReleaseReadinessReport",
            id: openSource.id,
            title: openSource.title,
            capturedAt: openSource.capturedAt,
            notes: openSource.notes,
            verdict: openSource.verdict
        )
    ]
}

private func packagingMetadataReportSnapshots() throws -> [ReportMetadataSnapshot] {
    let packaging = try PackagingFieldTestReport.decode(
        from: fixtureData("PackagingFieldTests/valid/packaging-field-test-partial.json")
    )
    let referenceRig = try ReferenceRigReport.decode(
        from: fixtureData("ReferenceRigReports/valid/reference-rig-partial.json")
    )
    let currentEvidence = CurrentEvidenceStatusMatrixReport.current()

    try packaging.validate()
    try referenceRig.validate()
    try currentEvidence.validate()

    return [
        metadataSnapshot(
            name: "PackagingFieldTestReport",
            id: packaging.id,
            title: packaging.title,
            capturedAt: packaging.capturedAt,
            notes: packaging.notes,
            verdict: packaging.verdict
        ),
        metadataSnapshot(
            name: "ReferenceRigReport",
            id: referenceRig.id,
            title: referenceRig.title,
            capturedAt: referenceRig.capturedAt,
            notes: referenceRig.notes,
            verdict: referenceRig.verdict
        ),
        metadataSnapshot(
            name: "CurrentEvidenceStatusMatrixReport",
            id: currentEvidence.id,
            title: currentEvidence.title,
            capturedAt: currentEvidence.capturedAt,
            notes: currentEvidence.notes,
            verdict: currentEvidence.verdict
        )
    ]
}

@Test
func metadataValidationRejectsEmptyMalformedAndMissingFieldsThroughValidatorSurface() throws {
    #expect(throws: CurrentEvidenceStatusMatrixValidationError.emptyField("title")) {
        _ = try ReportValidatorSurface.validate(
            currentEvidenceStatusMatrixData { $0["title"] = "" },
            as: CurrentEvidenceStatusMatrixReport.self,
            label: "current evidence status matrix"
        )
    }

    #expect(throws: CurrentEvidenceStatusMatrixValidationError.malformedField("capturedAt")) {
        _ = try ReportValidatorSurface.validate(
            currentEvidenceStatusMatrixData { $0["capturedAt"] = "not-a-date" },
            as: CurrentEvidenceStatusMatrixReport.self,
            label: "current evidence status matrix"
        )
    }

    do {
        _ = try ReportValidatorSurface.validate(
            currentEvidenceStatusMatrixData { $0.removeValue(forKey: "notes") },
            as: CurrentEvidenceStatusMatrixReport.self,
            label: "current evidence status matrix"
        )
        Issue.record("missing notes metadata unexpectedly validated")
    } catch {
        #expect(String(describing: error).contains("notes"))
    }

    let output = try ReportValidatorSurface.validate(
        CurrentEvidenceStatusMatrixReport.current().prettyJSONData(),
        as: CurrentEvidenceStatusMatrixReport.self,
        label: "current evidence status matrix",
        extraLines: { ["metadata: \($0.title) captured-at=\($0.capturedAt)"] }
    )
    #expect(output.lines.contains(
        "metadata: Current evidence status matrix captured-at=2026-07-24T00:00:00Z"
    ))
}

@Test
func reportSchemaInventoryTracksLoLaUdpMediaEvidenceAndParityValidationOnly() throws {
    let session = try #require(ReportSchemaInventory.entries.first {
        $0.schemaName == "ExternalConnectorSessionReport"
    })
    let media = try #require(ReportSchemaInventory.entries.first {
        $0.schemaName == "LoLaCompatibilityMediaSessionReport"
    })

    #expect(session.notes.contains("post-control LoLa UDP socket media TX/RX"))
    #expect(media.validationFiles.contains("Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift"))
    #expect(media.notes.contains("post-control UDP socket"))

    let parity = try #require(ReportSchemaInventory.entries.first {
        $0.schemaName == "LoLaParityDeferredLedgerReport"
    })

    #expect(parity.validatorCommands == ["validate-lola-parity-deferred-ledger"])
    #expect(parity.syntheticSmokeCommand == nil)
}

@Test
func reportSchemaFalsePassFixturesFailThroughPublicValidators() throws {
    let expected = Dictionary(
        uniqueKeysWithValues: falsePassFixtureValidators().map {
            ($0.key, $0)
        }
    )
    let registered = registeredFalsePassFixtures()
    let registeredKeys = Set(registered.map(\.key))

    #expect(Set(expected.keys) == registeredKeys)

    for fixture in registered.sorted() {
        let validator = try #require(expected[fixture.key])
        #expect(validator.schemaName == fixture.schemaName)
        #expect(validator.validatorCommand == fixture.validatorCommand)
        let data = try fixtureData("\(fixture.group)/invalid/\(fixture.fileName)")
        do {
            let output = try validator.validate(data)
            Issue.record(
                """
                false-pass fixture validated unexpectedly: \
                schema=\(fixture.schemaName) validator=\(fixture.validatorCommand) \
                fixture=\(fixture.group)/invalid/\(fixture.fileName) output=\(output.lines)
                """
            )
        } catch {
            #expect(validator.matches(error))
            #expect(String(describing: error).contains(validator.boundaryReason))
        }
    }
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

private func fixtureData(_ relativePath: String) throws -> Data {
    try Data(contentsOf: fixtureRoot.appendingPathComponent(relativePath))
}

private struct ReportMetadataSnapshot {
    var name: String
    var id: String
    var title: String
    var capturedAt: String
    var notes: String
    var verdict: MeasurementVerdict
}

// swiftlint:disable:next function_parameter_count
private func metadataSnapshot(
    name: String,
    id: String,
    title: String,
    capturedAt: String,
    notes: String,
    verdict: MeasurementVerdict
) -> ReportMetadataSnapshot {
    ReportMetadataSnapshot(
        name: name,
        id: id,
        title: title,
        capturedAt: capturedAt,
        notes: notes,
        verdict: verdict
    )
}

private func currentEvidenceStatusMatrixData(
    mutate: (inout [String: Any]) throws -> Void
) throws -> Data {
    let data = try CurrentEvidenceStatusMatrixReport.current().prettyJSONData()
    var object = try #require(
        try JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    try mutate(&object)
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}
