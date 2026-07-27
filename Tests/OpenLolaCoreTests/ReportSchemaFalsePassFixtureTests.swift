// Registers synthetic-pass fixtures with the validators that must reject their false PASS verdicts.
import Foundation
import OpenLolaContracts

@testable import OpenLolaCore

struct RegisteredFalsePassFixture: Comparable, Sendable {
    let group: String
    let fileName: String
    let schemaName: String
    let validatorCommand: String

    var key: String {
        "\(group)/\(fileName)"
    }

    static func < (lhs: RegisteredFalsePassFixture, rhs: RegisteredFalsePassFixture) -> Bool {
        lhs.key < rhs.key
    }
}

struct FalsePassFixtureValidator {
    let group: String
    let fileName: String
    let schemaName: String
    let validatorCommand: String
    let boundaryReason: String
    let validate: (Data) throws -> ReportValidatorConsoleOutput
    let matches: (any Error) -> Bool

    var key: String {
        "\(group)/\(fileName)"
    }
}

func registeredFalsePassFixtures() -> [RegisteredFalsePassFixture] {
    let schemasByGroup = Dictionary(
        uniqueKeysWithValues: ReportSchemaInventory.entries.compactMap { entry in
            entry.fixtureGroup.map { ($0, entry) }
        }
    )
    return FixtureSmokeMatrix.fixtureGroups
        .flatMap { group in
            group.falsePassFixtures.map { fileName in
                let schema = schemasByGroup[group.group]
                return RegisteredFalsePassFixture(
                    group: group.group,
                    fileName: fileName,
                    schemaName: schema?.schemaName ?? "",
                    validatorCommand: schema?.validatorCommands.first ?? ""
                )
            }
        }
}

func falsePassFixtureValidators() -> [FalsePassFixtureValidator] {
    fieldFalsePassValidators()
        + connectorFalsePassValidators()
        + packagingEvidenceFalsePassValidators()
        + packagingRuntimeFalsePassValidators()
        + realtimeAndReleaseFalsePassValidators()
}

private func fieldFalsePassValidators() -> [FalsePassFixtureValidator] {
    [
        falsePassValidator(
            group: "FieldReadyRuntimeProofs",
            fileName: "field-runtime-proof-synthetic-pass.json",
            schemaName: "FieldReadyRuntimeProofReport",
            validatorCommand: "validate-field-runtime-proof",
            boundaryReason: "passWithoutMeasuredRun",
            as: FieldReadyRuntimeProofReport.self
        ) { error in
            if case FieldReadyRuntimeValidationError.passWithoutMeasuredRun = error {
                return true
            }
            return false
        },
        falsePassValidator(
            group: "IntegratedAvReports",
            fileName: "integrated-av-synthetic-pass.json",
            schemaName: "IntegratedAvReport",
            validatorCommand: "validate-integrated-av-report",
            boundaryReason: "passWithoutMeasuredRun",
            as: IntegratedAvReport.self
        ) { error in
            if case IntegratedAvValidationError.passWithoutMeasuredRun = error {
                return true
            }
            return false
        }
    ]
}

private func connectorFalsePassValidators() -> [FalsePassFixtureValidator] {
    [
        falsePassValidator(
            group: "ExternalConnectorSessionReports",
            fileName: "external-connector-session-missing-media-pass.json",
            schemaName: "ExternalConnectorSessionReport",
            validatorCommand: "validate-external-connector-session-report",
            boundaryReason: "runtimePassMissingEvidence",
            as: ExternalConnectorSessionReport.self
        ) { error in
            if case ExternalConnectorSessionError.runtimePassMissingEvidence("ultraGridMedia") = error {
                return true
            }
            return false
        },
        falsePassValidator(
            group: "OpenSourceReleaseReadinessReports",
            fileName: "open-source-release-readiness-missing-requirement-pass.json",
            schemaName: "OpenSourceReleaseReadinessReport",
            validatorCommand: "validate-open-source-release-readiness-report",
            boundaryReason: "missingRequirement",
            as: OpenSourceReleaseReadinessReport.self
        ) { error in
            if case OpenSourceReleaseReadinessValidationError.missingRequirement(.publicReleaseApproval) = error {
                return true
            }
            return false
        }
    ]
}

private func packagingEvidenceFalsePassValidators() -> [FalsePassFixtureValidator] {
    [
        falsePassValidator(
            group: "PackagingFieldTests",
            fileName: "packaging-field-test-synthetic-pass.json",
            schemaName: "PackagingFieldTestReport",
            validatorCommand: "validate-packaging-field-report",
            boundaryReason: "passWithoutMeasuredRun",
            as: PackagingFieldTestReport.self
        ) { error in
            if case PackagingFieldTestValidationError.passWithoutMeasuredRun = error {
                return true
            }
            return false
        },
        falsePassValidator(
            group: "PackagingFieldTests",
            fileName: "packaging-field-test-missing-signing.json",
            schemaName: "PackagingFieldTestReport",
            validatorCommand: "validate-packaging-field-report",
            boundaryReason: "passWithoutSignedPackage",
            as: PackagingFieldTestReport.self
        ) { error in
            if case PackagingFieldTestValidationError.passWithoutSignedPackage = error {
                return true
            }
            return false
        },
        falsePassValidator(
            group: "PackagingFieldTests",
            fileName: "packaging-field-test-missing-notarization.json",
            schemaName: "PackagingFieldTestReport",
            validatorCommand: "validate-packaging-field-report",
            boundaryReason: "passWithoutAcceptedNotarization",
            as: PackagingFieldTestReport.self
        ) { error in
            if case PackagingFieldTestValidationError.passWithoutAcceptedNotarization = error {
                return true
            }
            return false
        }
    ]
}

private func packagingRuntimeFalsePassValidators() -> [FalsePassFixtureValidator] {
    [
        falsePassValidator(
            group: "PackagingFieldTests",
            fileName: "packaging-field-test-missing-gatekeeper.json",
            schemaName: "PackagingFieldTestReport",
            validatorCommand: "validate-packaging-field-report",
            boundaryReason: "passWithoutGatekeeperAcceptance",
            as: PackagingFieldTestReport.self
        ) { error in
            if case PackagingFieldTestValidationError.passWithoutGatekeeperAcceptance = error {
                return true
            }
            return false
        },
        falsePassValidator(
            group: "PackagingFieldTests",
            fileName: "packaging-field-test-missing-clean-mac.json",
            schemaName: "PackagingFieldTestReport",
            validatorCommand: "validate-packaging-field-report",
            boundaryReason: "passWithoutCleanMacTest",
            as: PackagingFieldTestReport.self
        ) { error in
            if case PackagingFieldTestValidationError.passWithoutCleanMacTest = error {
                return true
            }
            return false
        }
    ]
}

private func realtimeAndReleaseFalsePassValidators() -> [FalsePassFixtureValidator] {
    [
        falsePassValidator(
            group: "RealtimeAudioEngineReports",
            fileName: "realtime-audio-engine-synthetic-pass.json",
            schemaName: "RealtimeAudioEngineReport",
            validatorCommand: "validate-realtime-audio-engine-report",
            boundaryReason: "passWithoutMeasuredRun",
            as: RealtimeAudioEngineReport.self
        ) { error in
            if case RealtimeAudioEngineValidationError.passWithoutMeasuredRun = error {
                return true
            }
            return false
        },
        falsePassValidator(
            group: "ReleaseHardeningReports",
            fileName: "release-hardening-synthetic-pass.json",
            schemaName: "ReleaseHardeningReport",
            validatorCommand: "validate-release-hardening-report",
            boundaryReason: "passWithoutMeasuredRun",
            as: ReleaseHardeningReport.self
        ) { error in
            if case ReleaseHardeningValidationError.passWithoutMeasuredRun = error {
                return true
            }
            return false
        }
    ]
}

// swiftlint:disable:next function_parameter_count
private func falsePassValidator<Report: ReportValidatingArtifact>(
    group: String,
    fileName: String,
    schemaName: String,
    validatorCommand: String,
    boundaryReason: String,
    as type: Report.Type,
    matches: @escaping (any Error) -> Bool
) -> FalsePassFixtureValidator {
    FalsePassFixtureValidator(
        group: group,
        fileName: fileName,
        schemaName: schemaName,
        validatorCommand: validatorCommand,
        boundaryReason: boundaryReason,
        validate: { data in
            try ReportValidatorSurface.validate(data, as: type, label: schemaName)
        },
        matches: matches
    )
}
