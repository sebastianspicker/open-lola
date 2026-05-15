import Foundation
import OpenLolaCore

func handleMadiReceiveCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.count == 2 && args[0] == "validate-madi-rx-report":
        try validateReport(at: args[1], as: MadiReceiveSyntheticReport.self, label: "MADI RX report")
    case ["madi-rx-synthetic-smoke"]:
        let report = try MadiReceiveSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    default:
        return false
    }
    return true
}
