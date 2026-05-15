import Foundation

public protocol ReportValidatingArtifact: PrettyJSONCodable {
    var id: String { get }
    var verdict: MeasurementVerdict { get }

    func validate() throws
}

public protocol ReportMetadataArtifact: ReportValidatingArtifact {
    var title: String { get }
    var capturedAt: String { get }
    var notes: String { get }
}

protocol ReportValidationLifecycle {
    func validateIdentity() throws
    func validateFields() throws
    func validatePassVerdict() throws
}

extension ReportValidationLifecycle {
    func validateLifecycle() throws {
        try validateIdentity()
        try validateFields()
        try validatePassVerdict()
    }
}

public struct ReportValidatorConsoleOutput: Codable, Equatable, Sendable {
    public let validLine: String
    public let extraLines: [String]
    public let verdictLine: String

    public init(validLine: String, extraLines: [String], verdictLine: String) {
        self.validLine = validLine
        self.extraLines = extraLines
        self.verdictLine = verdictLine
    }

    public var lines: [String] {
        [validLine] + extraLines + [verdictLine]
    }
}

public enum ReportValidatorSurface {
    public static func validate<Report: ReportValidatingArtifact>(
        _ data: Data,
        as _: Report.Type,
        label: String,
        extraLines: (Report) -> [String] = { _ in [] }
    ) throws -> ReportValidatorConsoleOutput {
        let report = try Report.decode(from: data)
        try report.validate()
        return ReportValidatorConsoleOutput(
            validLine: "\(label) valid: \(report.id)",
            extraLines: extraLines(report),
            verdictLine: "VERDICT: \(report.verdict.rawValue.uppercased())"
        )
    }
}
