// Translates MilestoneLoLaCompatibilityCommands command syntax into core API calls, keeping CLI parsing independent from domain services.
import Foundation
import OpenLolaCore

func handleMilestoneLoLaCompatibilityCommand(_ arguments: [String]) throws -> Bool {
    if try handleMilestoneLoLaCaptureCommand(arguments) { return true }
    if try handleMilestoneLoLaRawUdpCommand(arguments) { return true }
    return false
}

private func handleMilestoneLoLaCaptureCommand(_ arguments: [String]) throws -> Bool {
    if try handleMilestoneLoLaCaptureDecodeCommand(arguments) { return true }
    if try handleMilestoneLoLaFixtureReportCommand(arguments) { return true }
    return false
}

private func handleMilestoneLoLaCaptureDecodeCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.count == 5 && args[0] == "lola-capture-decode"
        && args[1] == "--input" && args[3] == "--output":
        let report = try LoLaCompatibilityCaptureDecoder.decode(inputPath: args[2])
        try writeValidatedReport(report, to: args[4])
        print("LoLa compatibility capture report written: \(args[4])")
        print("input-format: \(report.inputFormat.rawValue)")
        print("packets: \(report.summary.packetCount)")
        print("media-envelope-packets: \(report.summary.lolaMediaEnvelopePacketCount)")
        printVerdict(report.verdict)
    default:
        return false
    }
    return true
}

private func handleMilestoneLoLaFixtureReportCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.first == "lola-packet-fixture-run":
        try runLoLaPacketFixtureCommand(args)
    case let args where args.count == 3 && args[0] == "lola-media-report-run" && args[1] == "--output":
        try runLoLaMediaReportCommand(outputPath: args[2])
    default:
        return false
    }
    return true
}

private func handleMilestoneLoLaRawUdpCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.first == "lola-raw-link-tx-run":
        try runLoLaRawLinkTransmitCommand(args)
    case let args where args.first == "lola-raw-link-rx-run":
        try runLoLaRawLinkReceiveCommand(args)
    case let args where args.first == "lola-udp-media-tx-run":
        try runLoLaUdpMediaTransmitCommand(args)
    case let args where args.first == "lola-udp-media-rx-run":
        try runLoLaUdpMediaReceiveCommand(args)
    default:
        return false
    }
    return true
}

private func runLoLaPacketFixtureCommand(_ args: [String]) throws {
    let configuration = try LoLaPacketFixtureRunConfiguration.parse(Array(args.dropFirst()))
    let report = try LoLaCompatibilityPacketFixtureRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("LoLa packet fixture report written: \(configuration.outputPath)")
    if let captureOutputPath = configuration.captureOutputPath {
        print("synthetic-capture: \(captureOutputPath)")
    }
    print("packets: \(report.decodedCapturePacketCount)")
    printVerdict(report.verdict)
}

private func runLoLaMediaReportCommand(outputPath: String) throws {
 let configuration = ExternalConnectorSessionConfiguration(.init(
 connector: .lola,
 role: .tx,
 peer: "192.0.2.20",
 outputPath: outputPath
 ) { input in
 input.localHost = "192.0.2.10"
 input.mediaMode = .audioVideo
 })
 let report = try LoLaCompatibilityMediaSession.transmitReport(configuration: configuration)
    try writeValidatedReport(report, to: outputPath)
    print("LoLa compatibility media session report written: \(outputPath)")
    print("frames: \(report.frames.count)")
    print("real-link-transmitted: \(report.realLinkTransmitted)")
    printVerdict(report.verdict)
}

private func runLoLaRawLinkTransmitCommand(_ args: [String]) throws {
    let configuration = try LoLaRawLinkTransmitRunConfiguration.parse(Array(args.dropFirst()))
    let report = try LoLaRawLinkTransmitRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("LoLa raw-link TX report written: \(configuration.outputPath)")
    print("interface: \(configuration.interfaceName)")
    print("frames: \(report.frames.count)")
    print("real-link-transmitted: \(report.realLinkTransmitted)")
    printVerdict(report.verdict)
}

private func runLoLaRawLinkReceiveCommand(_ args: [String]) throws {
    let configuration = try LoLaRawLinkReceiveRunConfiguration.parse(Array(args.dropFirst()))
    let report = try LoLaRawLinkReceiveRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("LoLa raw-link RX report written: \(configuration.outputPath)")
    print("interface: \(configuration.interfaceName)")
    print("frames: \(report.frames.count)")
    printVerdict(report.verdict)
}

private func runLoLaUdpMediaTransmitCommand(_ args: [String]) throws {
    let configuration = try LoLaUdpMediaTransmitRunConfiguration.parse(Array(args.dropFirst()))
    let report = try LoLaUdpMediaTransmitRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("LoLa UDP media TX report written: \(configuration.outputPath)")
    print("peer: \(configuration.peer)")
    print("frames: \(report.frames.count)")
    print("real-link-transmitted: \(report.realLinkTransmitted)")
    printVerdict(report.verdict)
}

private func runLoLaUdpMediaReceiveCommand(_ args: [String]) throws {
    let configuration = try LoLaUdpMediaReceiveRunConfiguration.parse(Array(args.dropFirst()))
    let report = try LoLaUdpMediaReceiveRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("LoLa UDP media RX report written: \(configuration.outputPath)")
    print("local-host: \(configuration.localHost)")
    print("frames: \(report.frames.count)")
    print("real-link-transmitted: \(report.realLinkTransmitted)")
    printVerdict(report.verdict)
}
