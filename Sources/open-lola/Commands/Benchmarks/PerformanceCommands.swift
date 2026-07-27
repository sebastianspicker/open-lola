// Translates PerformanceCommands command syntax into core API calls, keeping CLI parsing independent from domain services.
import Foundation
import OpenLolaCore

func handlePerformanceCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.count == 2 && args[0] == "validate-performance-audit-report":
        try validateReport(at: args[1], as: PerformanceAuditReport.self, label: "performance audit report")
        return true
    case ["performance-audit-synthetic-smoke"]:
        let report = try PerformanceAuditSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
        return true
    default:
        return false
    }
}
