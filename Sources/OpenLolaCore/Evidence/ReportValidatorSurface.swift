// Validates ReportValidatorSurface acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

/// Captures report contents required to validate, interpret, and reproduce a report-validator surface result.
public protocol ReportValidatingArtifact: PrettyJSONCodable {
    var id: String { get }
    var verdict: MeasurementVerdict { get }

    func validate() throws
}

/// Captures report contents required to validate, interpret, and reproduce a report-validator surface result.
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

/// Decodes, validates, and formats console output for any report-validating artifact.
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
