// Maps LatencyProfileCommands CLI input into core calls, keeping argument normalization outside domain services.
import Foundation
import OpenLolaCore

func handleLatencyProfileCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["latency-profile-benchmark-synthetic-smoke"]:
        let report = try latencyProfileBenchmarkSyntheticSmokeReport()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.count == 3
        && args[0] == "latency-profile-benchmark-synthetic-smoke"
        && args[1] == "--output":
        let report = try latencyProfileBenchmarkSyntheticSmokeReport()
        try writeJSONData(try report.prettyJSONData(), to: args[2])
        print("latency profile benchmark report written: \(args[2])")
        print("session-profile: \(report.sessionProfileMetrics?.sessionProfile.rawValue ?? "unknown")")
        print("rx-buffer-profile: \(report.sessionProfileMetrics?.rxBufferProfile.rawValue ?? "unknown")")
        printVerdict(report.verdict)
    case let args where args.first == "rx-buffer-benchmark-run":
        let outputPath = try rxBufferBenchmarkOutputPath(args)
        let packetCount = try rxBufferBenchmarkPacketCount(args)
        let report = try RxBufferBenchmarkRunner.runLocal(packetCount: packetCount)
        try writeJSONData(try report.prettyJSONData(), to: outputPath)
        print("RX buffer benchmark report written: \(outputPath)")
        print("profiles: \(report.rows.map(\.profile.rawValue).joined(separator: ","))")
        print("packets-per-profile: \(packetCount)")
        printVerdict(report.verdict)
    default:
        return false
    }

    return true
}

private func latencyProfileBenchmarkSyntheticSmokeReport() throws -> LatencyBenchmarkReport {
    do {
        let report = try LatencyProfileBenchmarkSyntheticSmoke.run()
        try report.validate()
        return report
    } catch {
        throw CommandError.invalidArgument(
            "latency-profile-benchmark-synthetic-smoke failed: \(error)"
        )
    }
}

private func rxBufferBenchmarkOutputPath(_ arguments: [String]) throws -> String {
    guard let outputIndex = arguments.firstIndex(of: "--output"),
          outputIndex + 1 < arguments.count else {
        throw CommandError.invalidArgument("missing --output")
    }
    return arguments[outputIndex + 1]
}

private func rxBufferBenchmarkPacketCount(_ arguments: [String]) throws -> Int {
    guard let packetsIndex = arguments.firstIndex(of: "--packets") else {
        return 48
    }
    guard packetsIndex + 1 < arguments.count,
          let count = Int(arguments[packetsIndex + 1]),
          count > 0 else {
        throw CommandError.invalidArgument("invalid --packets")
    }
    return count
}
