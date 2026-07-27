// Translates MilestoneTransportTimingCommands command syntax into core API calls, keeping CLI parsing independent from domain services.
import Foundation
import OpenLolaCore

func handleMilestoneTransportTimingCommand(_ arguments: [String]) throws -> Bool {
    if try handleMilestoneTransportSmokeCommand(arguments) { return true }
    if try handleMilestoneLatencyAudioCommand(arguments) { return true }
    return false
}

private func handleMilestoneTransportSmokeCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.first == "drift-plc-run":
        try runDriftPlcCommand(args)
    case ["udp-pcm-localhost-smoke"]:
        let packet = try UdpPcmLocalhostSmoke.run()
        print(
            "udp-pcm localhost smoke valid: seq=\(packet.header.sequenceNumber) "
                + "bytes=\(packet.header.payloadByteCount)"
        )
        printVerdict(.pass)
    case ["udp-pcm-route-localhost-smoke"]:
        let report = try UdpPcmRouteLocalhostSmoke.run()
        try printValidatedJSONReport(report)
    case ["route-certification-synthetic-smoke"]:
        let report = MacToMacRouteCertificationSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    default:
        return false
    }
    return true
}

private func handleMilestoneLatencyAudioCommand(_ arguments: [String]) throws -> Bool {
    if try handleMilestoneLatencyCommand(arguments) { return true }
    if try handleMilestoneAudioTimingCommand(arguments) { return true }
    return false
}

private func handleMilestoneLatencyCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["latency-benchmark-synthetic-smoke"]:
        let report = try LatencyBenchmarkSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case ["latency-tuning-synthetic-smoke"]:
        let report = LatencyTuningSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case ["latency-profile-synthetic-smoke"]:
        try runLatencyProfileSyntheticSmokeCommand()
    default:
        return false
    }
    return true
}

private func handleMilestoneAudioTimingCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["realtime-audio-synthetic-smoke"]:
        let report = try RealtimeAudioEngineSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case ["madi-tx-synthetic-smoke"]:
        let report = try MadiTransmitSyntheticSmoke.run()
        try printValidatedJSONReport(report, verdict: report.verdict) {
            try report.validate()
        }
    case ["drift-plc-synthetic-smoke"]:
        let report = try DriftPlcSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case ["drift-plc-certification-synthetic-smoke"]:
        let report = DriftPlcFixedTargetCertificationSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case ["aoip-synthetic-smoke"]:
        let report = AoipSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case ["network-aoip-certification-synthetic-smoke"]:
        let report = NetworkAoipCertificationSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    default:
        return false
    }
    return true
}

private func runDriftPlcCommand(_ args: [String]) throws {
    let configuration = try DriftPlcRunConfiguration.parse(Array(args.dropFirst()))
    let routeURL = URL(fileURLWithPath: configuration.routeReportPath)
    let routeReport = try UdpPcmRouteReport.readValidated(from: routeURL)
    let report = try DriftPlcFixedTargetRunner.makeReport(
        routeReport: routeReport,
        configuration: configuration
    )
    try writeValidatedReport(report, to: configuration.outputPath)
    print("drift-plc fixed-target report written: \(configuration.outputPath)")
    print("duration-seconds: \(report.metrics.durationSeconds)")
    printVerdict(report.verdict)
}

private func runLatencyProfileSyntheticSmokeCommand() throws {
    let evidence = try LatencyProfileSyntheticSmoke.run()
    try printValidatedJSONReport(evidence, verdict: evidence.recommendedVerdict) {
        try evidence.validate(
            for: AudioMode(
                sampleRateHertz: evidence.budget.sampleRateHertz,
                framesPerBuffer: evidence.budget.framesPerBuffer,
                channelCount: evidence.budget.channelCount,
                sampleFormat: "int16"
            ),
            verdict: evidence.recommendedVerdict
        )
    }
}
