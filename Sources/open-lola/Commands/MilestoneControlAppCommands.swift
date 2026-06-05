import Foundation
import OpenLolaCore

func handleMilestoneControlAppCommand(_ arguments: [String]) throws -> Bool {
    if try handleMilestoneControlCommand(arguments) { return true }
    if try handleMilestoneNativeAppCommand(arguments) { return true }
    return false
}

private func handleMilestoneControlCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["osc-cue-synthetic-smoke"]:
        let report = OscCueSyntheticLoopback.run()
        try printValidatedJSONReport(report)
    case let args where args.first == "osc-cue-run":
        try runOscCueCommand(args)
    case let args where args.first == "osc-cue-external-run":
        try runOscCueExternalCommand(args)
    case let args where args.first == "atem-readonly-probe":
        try runAtemReadonlyProbeCommand(args)
    case ["lighting-gate-synthetic-smoke"]:
        let report = try LightingFixtureGateSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case let args where args.first == "lighting-gate-run":
        try runLightingGateCommand(args)
    default:
        return false
    }
    return true
}

private func handleMilestoneNativeAppCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["native-app-shell-synthetic-smoke"]:
        let report = NativeAppShellSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case ["native-app-shell-surface-probe"]:
        let sourceReport = NativeAppShellSyntheticSmoke.run()
        try sourceReport.validate()
        let report = NativeAppShellSurfaceProbe.run(sourceReport: sourceReport)
        try printValidatedJSONReport(report)
    case let args where args.first == "native-app-runtime-smoke":
        try runNativeAppRuntimeSmokeCommand(args)
    default:
        return false
    }
    return true
}

private func runOscCueCommand(_ args: [String]) throws {
    let peer = try requiredArgument("--peer", in: args)
    guard peer == "127.0.0.1" || peer == "localhost" else {
        throw CommandError.invalidArgument("osc-cue-run currently supports live UDP loopback only")
    }
    guard let port = UInt16(try requiredArgument("--port", in: args)) else {
        throw CommandError.invalidArgument("invalid --port")
    }
    guard let count = Int(try requiredArgument("--count", in: args)) else {
        throw CommandError.invalidArgument("invalid --count")
    }
    let outputPath = try requiredArgument("--output", in: args)
    let report = try OscCueUdpLoopbackRunner.run(count: count, port: port)
    try writeValidatedReport(report, to: outputPath)
    print("OSC cue live UDP loopback report written: \(outputPath)")
    printVerdict(report.verdict)
}

private func runOscCueExternalCommand(_ args: [String]) throws {
    let configuration = try OscCueExternalRunConfiguration.parse(Array(args.dropFirst()))
    let report = try OscCueExternalRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("OSC cue external-peer report written: \(configuration.outputPath)")
    print("audio-baseline: \(configuration.audioBaselineReportId)")
    print("first-external-peer: \(configuration.firstExternalPeerKind.rawValue)")
    print("external-available: \(configuration.externalAvailable)")
    printVerdict(report.verdict)
}

private func runAtemReadonlyProbeCommand(_ args: [String]) throws {
    let configuration = try AtemReadOnlyProbeConfiguration.parse(Array(args.dropFirst()))
    let report = AtemReadOnlyControlProbe.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("ATEM read-only control report written: \(configuration.outputPath)")
    print("health: \(report.health.rawValue)")
    print("armed-commands-allowed: \(report.armedCommandsAllowed)")
    printVerdict(report.verdict)
}

private func runLightingGateCommand(_ args: [String]) throws {
    let configuration = try LightingGateRunConfiguration.parse(Array(args.dropFirst()))
    let report = try LightingGateRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    let decision = report.policy.decision(for: report.probe.request)
    print("lighting gate report written: \(configuration.outputPath)")
    print("audio-baseline: \(configuration.audioBaselineReportId)")
    print("osc-cue-report: \(configuration.oscCueReportId)")
    print("protocol: \(configuration.protocolName.rawValue)")
    print("interop-target: \(configuration.interopTarget.rawValue)")
    print("can-transmit: \(decision.canTransmit)")
    if let reason = decision.reason {
        print("block-reason: \(reason.rawValue)")
    }
    printVerdict(report.verdict)
}

private func runNativeAppRuntimeSmokeCommand(_ args: [String]) throws {
    let configuration = try NativeAppRuntimeSmokeConfiguration.parse(Array(args.dropFirst()))
    let headlessURL = URL(fileURLWithPath: configuration.headlessReportPath)
    let headlessReport = try IntegratedAvReport.readValidated(from: headlessURL)
    let report = NativeAppRuntimeSmoke.run(
        configuration: configuration,
        headlessReport: headlessReport
    )
    try writeValidatedReport(report, to: configuration.outputPath)
    print("native app runtime smoke report written: \(configuration.outputPath)")
    print("headless-report: \(headlessReport.id)")
    print("runtime-smoke-probed: \(report.smokeProbe.runtimeSmokeProbed)")
    print("cli-metrics-compared: \(report.smokeProbe.comparedWithCLIMetrics)")
    printVerdict(report.verdict)
}
