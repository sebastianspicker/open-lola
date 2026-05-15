import Foundation

public enum FixtureProvenanceClass: String, Codable, Sendable {
    case syntheticReport
    case syntheticValidationFixture
    case syntheticInventory
    case syntheticMeasurementReport
    case openLolaGeneratedPacket
    case sourceContract
}

public enum PublicReleasePosture: String, Codable, Sendable {
    case reviewPending
    case internalOnly
}

public struct FixtureMatrixEntry: Codable, Equatable, Sendable {
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
        group: String,
        expectedFileCount: Int,
        fileExtensions: [String] = ["json"],
        provenanceClass: FixtureProvenanceClass,
        publicReleasePosture: PublicReleasePosture = .reviewPending,
        validatorCommand: String? = nil,
        smokeCommand: String? = nil,
        relatedSourceFiles: [String],
        relatedTestFiles: [String],
        requiresFalsePassFixture: Bool = false,
        falsePassFixtures: [String] = []
    ) {
        self.group = group
        self.expectedFileCount = expectedFileCount
        self.fileExtensions = fileExtensions
        self.provenanceClass = provenanceClass
        self.publicReleasePosture = publicReleasePosture
        self.validatorCommand = validatorCommand
        self.smokeCommand = smokeCommand
        self.relatedSourceFiles = relatedSourceFiles
        self.relatedTestFiles = relatedTestFiles
        self.requiresFalsePassFixture = requiresFalsePassFixture
        self.falsePassFixtures = falsePassFixtures
    }
}

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

public struct FixtureSmokeMatrixSummary: Codable, Equatable, Sendable {
    public let fixtureGroupCount: Int
    public let fixtureFileCount: Int
    public let jsonFixtureCount: Int
    public let hexFixtureCount: Int
    public let syntheticSmokeCount: Int
    public let highRiskFalsePassFixtureCount: Int
}

public struct FixtureSmokeMatrixReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: FixtureSmokeMatrixSummary
    public let fixtureGroups: [FixtureMatrixEntry]
    public let syntheticSmokes: [CLISmokeMatrixEntry]
    public let notes: String
}

public enum FixtureSmokeMatrix {
    public static func report() -> FixtureSmokeMatrixReport {
        FixtureSmokeMatrixReport(
            id: "c08-fixture-cli-smoke-matrix",
            title: "C08 fixture and CLI smoke matrix",
            verdict: .partial,
            summary: summary(),
            fixtureGroups: fixtureGroups,
            syntheticSmokes: syntheticSmokes,
            notes: "Executable source-level matrix. Public release posture remains reviewPending until fixture provenance is confirmed."
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
