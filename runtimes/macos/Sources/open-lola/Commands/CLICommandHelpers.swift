// Implements CLICommandHelpers at the operator or CLI boundary, keeping it separate from core runtime services.
import Foundation
import OpenLolaCore

func validateReport<Report: ReportValidatingArtifact>(
    at path: String,
    as _: Report.Type,
    label: String,
    extraLines: ((Report) -> [String])? = nil
) throws {
    let output = try ReportValidatorSurface.validate(
        BoundedFileReader.data(atPath: path),
        as: Report.self,
        label: label,
        extraLines: extraLines ?? { _ in [] }
    )
    if !output.lines.isEmpty {
        let outputText = output.lines.joined(separator: "\n") + "\n"
        try FileHandle.standardOutput.write(contentsOf: Data(outputText.utf8))
    }
}
