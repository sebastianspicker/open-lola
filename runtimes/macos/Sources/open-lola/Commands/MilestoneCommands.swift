// Translates MilestoneCommands command syntax into core API calls, keeping CLI parsing independent from domain services.
import Foundation
import OpenLolaCore

func handleMilestoneCommand(_ arguments: [String]) throws -> Bool {
    if try handleMilestoneValidationCommand(arguments) {
        return true
    }
    if try handleMilestoneTransportTimingCommand(arguments) { return true }
    if try handleMilestoneVideoIntegratedCommand(arguments) { return true }
    if try handleMilestoneControlAppCommand(arguments) { return true }
    if try handleMilestoneFieldReleaseCommand(arguments) { return true }
    if try handleMilestoneExternalConnectorCommand(arguments) { return true }
    if try handleMilestoneLoLaCompatibilityCommand(arguments) { return true }
    return false
}

func writeValidatedReport<Report: ReportValidatingArtifact>(
    _ report: Report,
    to outputPath: String
) throws {
    try report.validate()
    try writeJSONData(try report.prettyJSONData(), to: outputPath)
}

func printValidatedJSONReport<Report: ReportValidatingArtifact>(
    _ report: Report
) throws {
    try printValidatedJSONReport(report, verdict: report.verdict) {
        try report.validate()
    }
}

func printValidatedJSONReport<Report: PrettyJSONCodable>(
    _ report: Report,
    verdict: MeasurementVerdict,
    validate: () throws -> Void
) throws {
    try validate()
    print(try report.prettyJSONString())
    printVerdict(verdict)
}
