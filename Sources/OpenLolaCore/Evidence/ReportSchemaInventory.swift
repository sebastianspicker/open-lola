// Collects measurement evidence evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Defines the finite evidence provenance values recorded by report-schema inventory artifacts for deterministic validation and report interpretation.
public enum ReportEvidenceClass: String, Codable, Sendable {
    case synthetic
    case sourceLevel
    case measured
    case cleanMac
    case externalWitnessed
}

/// Captures report contents required to validate, interpret, and reproduce a report-schema inventory result.
public struct ReportSchemaInventoryEntry: Codable, Equatable, Sendable {
    public struct Identity: Sendable {
        public let name: String
        public let family: String
        public let version: Int
        public let changePolicy: String

        public init(
            name: String,
            family: String,
            version: Int = 1,
            changePolicy: String =
                "Increment schemaVersion when the JSON contract changes; update validators, fixtures, and" +
                    " related tests in the same change."
        ) {
            self.name = name
            self.family = family
            self.version = version
            self.changePolicy = changePolicy
        }
    }

    public struct Provenance: Sendable {
        public let evidenceClass: ReportEvidenceClass
        public let sourceFile: String

        public init(evidenceClass: ReportEvidenceClass, sourceFile: String) {
            self.evidenceClass = evidenceClass
            self.sourceFile = sourceFile
        }
    }

    public struct Validation: Sendable {
        public let files: [String]
        public let commands: [String]
        public let fixtureGroup: String?
        public let syntheticSmokeCommand: String?
        public let relatedTestFiles: [String]

        public init(
            files: [String] = [],
            commands: [String] = [],
            fixtureGroup: String? = nil,
            syntheticSmokeCommand: String? = nil,
            relatedTestFiles: [String]
        ) {
            self.files = files
            self.commands = commands
            self.fixtureGroup = fixtureGroup
            self.syntheticSmokeCommand = syntheticSmokeCommand
            self.relatedTestFiles = relatedTestFiles
        }
    }

    public struct Policy: Sendable {
        public let passRequiresMeasuredEvidence: Bool
        public let falsePassFixtureCount: Int
        public let notes: String

        public init(
            passRequiresMeasuredEvidence: Bool,
            falsePassFixtureCount: Int = 0,
            notes: String
        ) {
            self.passRequiresMeasuredEvidence = passRequiresMeasuredEvidence
            self.falsePassFixtureCount = falsePassFixtureCount
            self.notes = notes
        }
    }

    public let schemaName: String
    public let schemaFamily: String
    public let schemaVersion: Int
    public let schemaChangePolicy: String
    public let evidenceClass: ReportEvidenceClass
    public let sourceFile: String
    public let validationFiles: [String]
    public let validatorCommands: [String]
    public let fixtureGroup: String?
    public let syntheticSmokeCommand: String?
    public let relatedTestFiles: [String]
    public let passRequiresMeasuredEvidence: Bool
    public let falsePassFixtureCount: Int
    public let notes: String

    public init(
        identity: Identity,
        provenance: Provenance,
        validation: Validation,
        policy: Policy
    ) {
        self.schemaName = identity.name
        self.schemaFamily = identity.family
        self.schemaVersion = identity.version
        self.schemaChangePolicy = identity.changePolicy
        self.evidenceClass = provenance.evidenceClass
        self.sourceFile = provenance.sourceFile
        self.validationFiles = validation.files
        self.validatorCommands = validation.commands
        self.fixtureGroup = validation.fixtureGroup
        self.syntheticSmokeCommand = validation.syntheticSmokeCommand
        self.relatedTestFiles = validation.relatedTestFiles
        self.passRequiresMeasuredEvidence = policy.passRequiresMeasuredEvidence
        self.falsePassFixtureCount = policy.falsePassFixtureCount
        self.notes = policy.notes
    }
}

/// Captures report contents required to validate, interpret, and reproduce a report-schema inventory result.
public struct ReportSchemaInventorySummary: Codable, Equatable, Sendable {
    public let schemaCount: Int
    public let validatorCommandCount: Int
    public let fixtureBackedSchemaCount: Int
    public let measuredEvidenceRequiredCount: Int
    public let cleanMacGateCount: Int
    public let falsePassFixtureCount: Int
}

/// Captures report contents required to validate, interpret, and reproduce a report-schema inventory result.
public struct ReportSchemaInventoryReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: ReportSchemaInventorySummary
    public let schemas: [ReportSchemaInventoryEntry]
    public let notes: String
}

/// Builds the executable report-schema inventory and its aggregate summary.
public enum ReportSchemaInventory {
    public static func report() -> ReportSchemaInventoryReport {
        ReportSchemaInventoryReport(
            id: "c03-report-schema-inventory",
            title: "C03 report validator and evidence schema inventory",
            verdict: .partial,
            summary: summary(),
            schemas: entries,
            notes:
                "Executable report schema index. It documents validation ownership and evidence class; it" +
                    " does not claim real release readiness."
        )
    }

    public static func summary() -> ReportSchemaInventorySummary {
        ReportSchemaInventorySummary(
            schemaCount: entries.count,
            validatorCommandCount: entries.flatMap(\.validatorCommands).count,
            fixtureBackedSchemaCount: entries.filter { $0.fixtureGroup != nil }.count,
            measuredEvidenceRequiredCount: entries.filter(\.passRequiresMeasuredEvidence).count,
            cleanMacGateCount: entries.filter { $0.evidenceClass == .cleanMac }.count,
            falsePassFixtureCount: entries.map(\.falsePassFixtureCount).reduce(0, +)
        )
    }

}

struct ReportSchemaInventoryEntryDraft {
    var name: String
    var family: String
    var evidenceClass: ReportEvidenceClass
    var sourceFile: String
    var validationFiles: [String] = []
    var validatorCommands: [String] = []
    var fixtureGroup: String?
    var syntheticSmokeCommand: String?
    var relatedTestFiles: [String]
    var passRequiresMeasuredEvidence: Bool
    var notes: String
}

func schema(_ draft: ReportSchemaInventoryEntryDraft) -> ReportSchemaInventoryEntry {
    ReportSchemaInventoryEntry(
        identity: ReportSchemaInventoryEntry.Identity(name: draft.name, family: draft.family),
        provenance: ReportSchemaInventoryEntry.Provenance(
            evidenceClass: draft.evidenceClass,
            sourceFile: draft.sourceFile
        ),
        validation: ReportSchemaInventoryEntry.Validation(
            files: draft.validationFiles,
            commands: draft.validatorCommands,
            fixtureGroup: draft.fixtureGroup,
            syntheticSmokeCommand: draft.syntheticSmokeCommand,
            relatedTestFiles: draft.relatedTestFiles
        ),
        policy: ReportSchemaInventoryEntry.Policy(
            passRequiresMeasuredEvidence: draft.passRequiresMeasuredEvidence,
            falsePassFixtureCount: falsePassFixtureCount(for: draft.fixtureGroup),
            notes: draft.notes
        )
    )
}

private func falsePassFixtureCount(for fixtureGroup: String?) -> Int {
    guard let fixtureGroup,
          let entry = FixtureSmokeMatrix.fixtureGroups.first(where: { $0.group == fixtureGroup }) else {
        return 0
    }
    return entry.falsePassFixtures.count
}
