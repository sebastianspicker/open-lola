// Collects source inventory evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Defines the finite structured result values recorded by fixture smoke matrix artifacts for deterministic validation and report interpretation.
public enum FixtureProvenanceClass: String, Codable, Sendable {
    case syntheticReport
    case syntheticValidationFixture
    case syntheticInventory
    case syntheticMeasurementReport
    case openLolaGeneratedPacket
    case sourceContract
}

/// Defines the finite structured result values recorded by fixture smoke matrix artifacts for deterministic validation and report interpretation.
public enum PublicReleasePosture: String, Codable, Sendable {
    case reviewPending
    case internalOnly
}

/// Captures inventory entry required to validate, interpret, and reproduce a fixture smoke matrix result.
public struct FixtureMatrixEntry: Codable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var group: String
        public var expectedFileCount: Int
        public var fileExtensions: [String]
        public var provenanceClass: FixtureProvenanceClass
        public var publicReleasePosture: PublicReleasePosture

        public init(
            group: String,
            expectedFileCount: Int,
            fileExtensions: [String] = ["json"],
            provenanceClass: FixtureProvenanceClass,
            publicReleasePosture: PublicReleasePosture = .reviewPending
        ) {
            self.group = group
            self.expectedFileCount = expectedFileCount
            self.fileExtensions = fileExtensions
            self.provenanceClass = provenanceClass
            self.publicReleasePosture = publicReleasePosture
        }
    }

    public struct Commands: Equatable, Sendable {
        public var validator: String?
        public var smoke: String?

        public init(validator: String? = nil, smoke: String? = nil) {
            self.validator = validator
            self.smoke = smoke
        }
    }

    public struct References: Equatable, Sendable {
        public var sourceFiles: [String]
        public var testFiles: [String]

        public init(sourceFiles: [String], testFiles: [String]) {
            self.sourceFiles = sourceFiles
            self.testFiles = testFiles
        }
    }

    public struct FalsePassPolicy: Equatable, Sendable {
        public var required: Bool
        public var fixtures: [String]

        public init(required: Bool = false, fixtures: [String] = []) {
            self.required = required
            self.fixtures = fixtures
        }
    }

    public let group: String
    public let expectedFileCount: Int
    public let fileExtensions: [String]
    public let provenanceClass: FixtureProvenanceClass
    public let publicReleasePosture: PublicReleasePosture
    public let validatorCommand: String?
    public let smokeCommand: String?
    public let relatedSourceFiles: [String]
    public let relatedTestFiles: [String]
    public let requiresFalsePassFixture: Bool
    public let falsePassFixtures: [String]

    public init(
        identity: Identity,
        commands: Commands = Commands(),
        references: References,
        falsePassPolicy: FalsePassPolicy = FalsePassPolicy()
    ) {
        group = identity.group
        expectedFileCount = identity.expectedFileCount
        fileExtensions = identity.fileExtensions
        provenanceClass = identity.provenanceClass
        publicReleasePosture = identity.publicReleasePosture
        validatorCommand = commands.validator
        smokeCommand = commands.smoke
        relatedSourceFiles = references.sourceFiles
        relatedTestFiles = references.testFiles
        requiresFalsePassFixture = falsePassPolicy.required
        falsePassFixtures = falsePassPolicy.fixtures
    }
}

/// Captures inventory entry required to validate, interpret, and reproduce a fixture smoke matrix result.
public struct CLISmokeMatrixEntry: Codable, Equatable, Sendable {
    public let command: String
    public let sourceFile: String
    public let expectedVerdict: MeasurementVerdict
    public let syntheticOnly: Bool
    public let relatedFixtureGroup: String?
    public let owner: String

    public init(
        command: String,
        sourceFile: String,
        expectedVerdict: MeasurementVerdict,
        syntheticOnly: Bool,
        relatedFixtureGroup: String?,
        owner: String
    ) {
        self.command = command
        self.sourceFile = sourceFile
        self.expectedVerdict = expectedVerdict
        self.syntheticOnly = syntheticOnly
        self.relatedFixtureGroup = relatedFixtureGroup
        self.owner = owner
    }
}

/// Captures summary statistics required to validate, interpret, and reproduce a fixture smoke matrix result.
public struct FixtureSmokeMatrixSummary: Codable, Equatable, Sendable {
    public let fixtureGroupCount: Int
    public let fixtureFileCount: Int
    public let jsonFixtureCount: Int
    public let hexFixtureCount: Int
    public let syntheticSmokeCount: Int
    public let highRiskFalsePassFixtureCount: Int
}

/// Captures report contents required to validate, interpret, and reproduce a fixture smoke matrix result.
public struct FixtureSmokeMatrixReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: FixtureSmokeMatrixSummary
    public let fixtureGroups: [FixtureMatrixEntry]
    public let syntheticSmokes: [CLISmokeMatrixEntry]
    public let notes: String
}

/// Builds the fixture smoke matrix from source-backed entries so ownership and operational boundaries remain reviewable.
public enum FixtureSmokeMatrix {
    public static func report() -> FixtureSmokeMatrixReport {
        FixtureSmokeMatrixReport(
            id: "c08-fixture-cli-smoke-matrix",
            title: "C08 fixture and CLI smoke matrix",
            verdict: .partial,
            summary: summary(),
            fixtureGroups: fixtureGroups,
            syntheticSmokes: syntheticSmokes,
            notes: "Executable source-level matrix. Public release posture " +
"remains reviewPending until fixture provenance is confirmed."
        )
    }

    public static func summary() -> FixtureSmokeMatrixSummary {
        let jsonCount = fixtureGroups
            .filter { $0.fileExtensions.contains("json") }
            .map(\.expectedFileCount)
            .reduce(0, +)
        let falsePassCount = fixtureGroups
            .map(\.falsePassFixtures.count)
            .reduce(0, +)
        return FixtureSmokeMatrixSummary(
            fixtureGroupCount: fixtureGroups.count,
            fixtureFileCount: fixtureGroups.map(\.expectedFileCount).reduce(0, +),
            jsonFixtureCount: jsonCount,
            hexFixtureCount: hexFixtureCount,
            syntheticSmokeCount: syntheticSmokes.count,
            highRiskFalsePassFixtureCount: falsePassCount
        )
    }

    private static var hexFixtureCount: Int {
        fixtureGroups
            .filter { $0.fileExtensions == ["hex"] }
            .map(\.expectedFileCount)
            .reduce(0, +)
    }
}
