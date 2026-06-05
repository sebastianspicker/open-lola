import Foundation
import OpenLolaCore

func handleMilestoneVideoIntegratedCommand(_ arguments: [String]) throws -> Bool {
    if try handleMilestoneVideoCommand(arguments) { return true }
    if try handleMilestoneIntegratedCommand(arguments) { return true }
    if try handleMilestoneHardwareCommand(arguments) { return true }
    return false
}

private func handleMilestoneVideoCommand(_ arguments: [String]) throws -> Bool {
    if try handleMilestoneVideoCaptureCommand(arguments) { return true }
    if try handleMilestoneVideoTransportCommand(arguments) { return true }
    return false
}

private func handleMilestoneVideoCaptureCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["video-capture-synthetic-smoke"]:
        let report = VideoCaptureSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case ["video-capture-inventory"]:
        let report = AVFoundationVideoDeviceInventoryReader().capture()
        try printValidatedJSONReport(report)
    case let args where args.count == 3 && args[0] == "video-capture-inventory" && args[1] == "--output":
        let report = AVFoundationVideoDeviceInventoryReader().capture()
        try writeValidatedReport(report, to: args[2])
        print("video capture inventory written: \(args[2])")
        printVerdict(report.verdict)
    case let args where args.first == "video-capture-run":
        try runVideoCaptureCommand(args)
    default:
        return false
    }
    return true
}

private func handleMilestoneVideoTransportCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["video-transport-synthetic-smoke"]:
        let report = try VideoTransportSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case let args where args.first == "video-transport-run":
        try runVideoTransportCommand(args)
    default:
        return false
    }
    return true
}

private func handleMilestoneIntegratedCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["integrated-av-synthetic-smoke"]:
        let report = IntegratedHeadlessAvSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case let args where args.first == "integrated-av-run":
        try runIntegratedAvCommand(args)
    case ["integrated-profile-synthetic-smoke"]:
        let report = IntegratedProfileSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case let args where args.first == "integrated-profile-run":
        try runIntegratedProfileCommand(args)
    default:
        return false
    }
    return true
}

private func handleMilestoneHardwareCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case ["hardware-validation-synthetic-smoke"]:
        let report = HardwareValidationSyntheticSmoke.run()
        try printValidatedJSONReport(report)
    case let args where args.first == "hardware-validation-run":
        try runHardwareValidationCommand(args)
    default:
        return false
    }
    return true
}

private func runVideoCaptureCommand(_ args: [String]) throws {
    let configuration = try VideoCaptureRunConfiguration.parse(Array(args.dropFirst()))
    let report = try AVFoundationVideoCaptureRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("video capture run report written: \(configuration.outputPath)")
    print("frames-captured: \(report.framesCaptured)")
    printVerdict(report.verdict)
}

private func runVideoTransportCommand(_ args: [String]) throws {
    let configuration = try VideoTransportRunConfiguration.parse(Array(args.dropFirst()))
    let report = try VideoTransportRunner.run(configuration: configuration)
    try writeValidatedReport(report, to: configuration.outputPath)
    print("video transport report written: \(configuration.outputPath)")
    print("frames-sent: \(report.transmitted.framesSent)")
    print("displayed-frames: \(report.receiver.displayedFrames)")
    print("dropped-frames: \(report.receiver.droppedFrames)")
    printVerdict(report.verdict)
}

private func runIntegratedAvCommand(_ args: [String]) throws {
    let configuration = try IntegratedAvRunConfiguration.parse(Array(args.dropFirst()))
    let videoTransportReport = try configuration.videoTransportReportPath.map {
        try VideoTransportReport.readValidated(fromPath: $0)
    }
    let report = IntegratedAvRunner.run(
        configuration: configuration,
        videoTransportReport: videoTransportReport
    )
    try writeValidatedReport(report, to: configuration.outputPath)
    print("integrated A/V run report written: \(configuration.outputPath)")
    print("duration-seconds: \(Int(report.durationSeconds))")
    print("run-mode: \(report.runMode.rawValue)")
    print("video-capture-enabled: \(report.proof?.videoCaptureEnabled ?? false)")
    print("video-transport-enabled: \(report.proof?.videoTransportEnabled ?? false)")
    print("osc-polling-enabled: \(report.proof?.oscPollingEnabled ?? false)")
    print("atem-readonly-polling-enabled: \(report.proof?.atemReadOnlyPollingEnabled ?? false)")
    printVerdict(report.verdict)
}

private func runIntegratedProfileCommand(_ args: [String]) throws {
    let configuration = try IntegratedProfileRunConfiguration.parse(Array(args.dropFirst()))
    let runtimeEvidence = try IntegratedProfileRuntimeEvidence(
        fastestAudio: configuration.fastestAudioReportPath.map {
            try LatencyBenchmarkReport.readValidated(fromPath: $0)
        },
        integratedAv: configuration.integratedAvReportPath.map {
            try IntegratedAvReport.readValidated(fromPath: $0)
        },
        lightingControl: configuration.lightingControlReportPath.map {
            try LightingFixtureGateReport.readValidated(fromPath: $0)
        }
    )
    let report = IntegratedProfileRunner.run(
        configuration: configuration,
        runtimeEvidence: runtimeEvidence
    )
    try writeValidatedReport(report, to: configuration.outputPath)
    print("integrated profile report written: \(configuration.outputPath)")
    print("run-mode: \(report.runMode.rawValue)")
    print("default-profile: \(report.defaultProfile.rawValue)")
    print("aggregate-verdict: \(report.aggregateSubordinateVerdict.rawValue)")
    print("benchmark-scenarios: \(report.benchmarkMatrix.count)")
    printVerdict(report.verdict)
}

private func runHardwareValidationCommand(_ args: [String]) throws {
    let configuration = try HardwareValidationRunConfiguration.parse(Array(args.dropFirst()))
    let referenceRig = try ReferenceRigReport.readValidated(from: URL(fileURLWithPath: configuration.referenceRigPath))
    let rmeFastestAudio = try RmeFastestAudioPathReport.readValidated(fromPath: configuration.rmeFastestAudioPath)
    let videoCapture = try VideoCaptureReport.readValidated(fromPath: configuration.videoCapturePath)
    let atemControl = try AtemReadOnlyControlReport.readValidated(fromPath: configuration.atemControlPath)
    let lightingGate = try LightingFixtureGateReport.readValidated(fromPath: configuration.lightingGatePath)
    let integratedProfile = try IntegratedProfileReport.readValidated(fromPath: configuration.integratedProfilePath)
    let report = HardwareValidationRunner.run(
        configuration: configuration,
        referenceRig: referenceRig,
        rmeFastestAudio: rmeFastestAudio,
        videoCapture: videoCapture,
        atemControl: atemControl,
        lightingGate: lightingGate,
        integratedProfile: integratedProfile
    )
    try writeValidatedReport(report, to: configuration.outputPath)
    print("hardware validation report written: \(configuration.outputPath)")
    print("routes: \(report.routes.count)")
    printVerdict(report.verdict)
}
