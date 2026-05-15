import Foundation
import OpenLolaCore

func handleMilestoneCommand(_ arguments: [String]) throws -> Bool {
    if try handleMilestoneValidationCommand(arguments) {
        return true
    }

    switch arguments {
    case let args where args.first == "drift-plc-run":
        let configuration = try DriftPlcRunConfiguration.parse(Array(args.dropFirst()))
        let routeURL = URL(fileURLWithPath: configuration.routeReportPath)
        let routeReport = try UdpPcmRouteReport.readValidated(from: routeURL)
        let report = try DriftPlcFixedTargetRunner.makeReport(
            routeReport: routeReport,
            configuration: configuration
        )
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("drift-plc fixed-target report written: \(configuration.outputPath)")
        print("duration-seconds: \(report.metrics.durationSeconds)")
        printVerdict(report.verdict)
    case ["udp-pcm-localhost-smoke"]:
        let packet = try UdpPcmLocalhostSmoke.run()
        print(
            "udp-pcm localhost smoke valid: seq=\(packet.header.sequenceNumber) "
                + "bytes=\(packet.header.payloadByteCount)"
        )
        printVerdict(.pass)
    case ["udp-pcm-route-localhost-smoke"]:
        let report = try UdpPcmRouteLocalhostSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["route-certification-synthetic-smoke"]:
        let report = MacToMacRouteCertificationSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["latency-benchmark-synthetic-smoke"]:
        let report = try LatencyBenchmarkSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["latency-tuning-synthetic-smoke"]:
        let report = LatencyTuningSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["latency-profile-synthetic-smoke"]:
        let evidence = try LatencyProfileSyntheticSmoke.run()
        try evidence.validate(
            for: AudioMode(
                sampleRateHertz: evidence.budget.sampleRateHertz,
                framesPerBuffer: evidence.budget.framesPerBuffer,
                channelCount: evidence.budget.channelCount,
                sampleFormat: "int16"
            ),
            verdict: evidence.recommendedVerdict
        )
        print(try evidence.prettyJSONString())
        printVerdict(evidence.recommendedVerdict)
    case ["realtime-audio-synthetic-smoke"]:
        let report = try RealtimeAudioEngineSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["madi-tx-synthetic-smoke"]:
        let report = try MadiTransmitSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["drift-plc-synthetic-smoke"]:
        let report = try DriftPlcSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["drift-plc-certification-synthetic-smoke"]:
        let report = DriftPlcFixedTargetCertificationSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["aoip-synthetic-smoke"]:
        let report = AoipSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["network-aoip-certification-synthetic-smoke"]:
        let report = NetworkAoipCertificationSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["video-capture-synthetic-smoke"]:
        let report = VideoCaptureSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["video-capture-inventory"]:
        let report = AVFoundationVideoDeviceInventoryReader().capture()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.count == 3 && args[0] == "video-capture-inventory" && args[1] == "--output":
        let report = AVFoundationVideoDeviceInventoryReader().capture()
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: args[2])
        print("video capture inventory written: \(args[2])")
        printVerdict(report.verdict)
    case let args where args.first == "video-capture-run":
        let configuration = try VideoCaptureRunConfiguration.parse(Array(args.dropFirst()))
        let report = try AVFoundationVideoCaptureRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("video capture run report written: \(configuration.outputPath)")
        print("frames-captured: \(report.framesCaptured)")
        printVerdict(report.verdict)
    case ["video-transport-synthetic-smoke"]:
        let report = try VideoTransportSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.first == "video-transport-run":
        let configuration = try VideoTransportRunConfiguration.parse(Array(args.dropFirst()))
        let report = try VideoTransportRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("video transport report written: \(configuration.outputPath)")
        print("frames-sent: \(report.transmitted.framesSent)")
        print("displayed-frames: \(report.receiver.displayedFrames)")
        print("dropped-frames: \(report.receiver.droppedFrames)")
        printVerdict(report.verdict)
    case ["integrated-av-synthetic-smoke"]:
        let report = IntegratedHeadlessAvSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.first == "integrated-av-run":
        let configuration = try IntegratedAvRunConfiguration.parse(Array(args.dropFirst()))
        let videoTransportReport = try configuration.videoTransportReportPath.map {
            try VideoTransportReport.readValidated(fromPath: $0)
        }
        let report = IntegratedAvRunner.run(
            configuration: configuration,
            videoTransportReport: videoTransportReport
        )
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("integrated A/V run report written: \(configuration.outputPath)")
        print("duration-seconds: \(Int(report.durationSeconds))")
        print("run-mode: \(report.runMode.rawValue)")
        print("video-capture-enabled: \(report.proof?.videoCaptureEnabled ?? false)")
        print("video-transport-enabled: \(report.proof?.videoTransportEnabled ?? false)")
        print("osc-polling-enabled: \(report.proof?.oscPollingEnabled ?? false)")
        print("atem-readonly-polling-enabled: \(report.proof?.atemReadOnlyPollingEnabled ?? false)")
        printVerdict(report.verdict)
    case ["integrated-profile-synthetic-smoke"]:
        let report = IntegratedProfileSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.first == "integrated-profile-run":
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
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("integrated profile report written: \(configuration.outputPath)")
        print("run-mode: \(report.runMode.rawValue)")
        print("default-profile: \(report.defaultProfile.rawValue)")
        print("aggregate-verdict: \(report.aggregateSubordinateVerdict.rawValue)")
        print("benchmark-scenarios: \(report.benchmarkMatrix.count)")
        printVerdict(report.verdict)
    case ["hardware-validation-synthetic-smoke"]:
        let report = HardwareValidationSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.first == "hardware-validation-run":
        let configuration = try HardwareValidationRunConfiguration.parse(Array(args.dropFirst()))
        let referenceRigURL = URL(fileURLWithPath: configuration.referenceRigPath)
        let rmeFastestAudioURL = URL(fileURLWithPath: configuration.rmeFastestAudioPath)
        let videoCaptureURL = URL(fileURLWithPath: configuration.videoCapturePath)
        let atemControlURL = URL(fileURLWithPath: configuration.atemControlPath)
        let lightingGateURL = URL(fileURLWithPath: configuration.lightingGatePath)
        let integratedProfileURL = URL(fileURLWithPath: configuration.integratedProfilePath)
        let referenceRig = try ReferenceRigReport.readValidated(from: referenceRigURL)
        let rmeFastestAudio = try RmeFastestAudioPathReport.readValidated(from: rmeFastestAudioURL)
        let videoCapture = try VideoCaptureReport.readValidated(from: videoCaptureURL)
        let atemControl = try AtemReadOnlyControlReport.readValidated(from: atemControlURL)
        let lightingGate = try LightingFixtureGateReport.readValidated(from: lightingGateURL)
        let integratedProfile = try IntegratedProfileReport.readValidated(from: integratedProfileURL)
        let report = HardwareValidationRunner.run(
            configuration: configuration,
            referenceRig: referenceRig,
            rmeFastestAudio: rmeFastestAudio,
            videoCapture: videoCapture,
            atemControl: atemControl,
            lightingGate: lightingGate,
            integratedProfile: integratedProfile
        )
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("hardware validation report written: \(configuration.outputPath)")
        print("routes: \(report.routes.count)")
        printVerdict(report.verdict)
    case ["osc-cue-synthetic-smoke"]:
        let report = OscCueSyntheticLoopback.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.first == "osc-cue-run":
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
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: outputPath)
        print("OSC cue live UDP loopback report written: \(outputPath)")
        printVerdict(report.verdict)
    case let args where args.first == "osc-cue-external-run":
        let configuration = try OscCueExternalRunConfiguration.parse(Array(args.dropFirst()))
        let report = try OscCueExternalRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("OSC cue external-peer report written: \(configuration.outputPath)")
        print("audio-baseline: \(configuration.audioBaselineReportId)")
        print("first-external-peer: \(configuration.firstExternalPeerKind.rawValue)")
        print("external-available: \(configuration.externalAvailable)")
        printVerdict(report.verdict)
    case let args where args.first == "atem-readonly-probe":
        let configuration = try AtemReadOnlyProbeConfiguration.parse(Array(args.dropFirst()))
        let report = AtemReadOnlyControlProbe.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("ATEM read-only control report written: \(configuration.outputPath)")
        print("health: \(report.health.rawValue)")
        print("armed-commands-allowed: \(report.armedCommandsAllowed)")
        printVerdict(report.verdict)
    case ["lighting-gate-synthetic-smoke"]:
        let report = try LightingFixtureGateSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.first == "lighting-gate-run":
        let configuration = try LightingGateRunConfiguration.parse(Array(args.dropFirst()))
        let report = try LightingGateRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
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
    case ["native-app-shell-synthetic-smoke"]:
        let report = NativeAppShellSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["native-app-shell-surface-probe"]:
        let sourceReport = NativeAppShellSyntheticSmoke.run()
        try sourceReport.validate()
        let report = NativeAppShellSurfaceProbe.run(sourceReport: sourceReport)
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.first == "native-app-runtime-smoke":
        let configuration = try NativeAppRuntimeSmokeConfiguration.parse(Array(args.dropFirst()))
        let headlessURL = URL(fileURLWithPath: configuration.headlessReportPath)
        let headlessReport = try IntegratedAvReport.readValidated(from: headlessURL)
        let report = NativeAppRuntimeSmoke.run(
            configuration: configuration,
            headlessReport: headlessReport
        )
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("native app runtime smoke report written: \(configuration.outputPath)")
        print("headless-report: \(headlessReport.id)")
        print("runtime-smoke-probed: \(report.smokeProbe.runtimeSmokeProbed)")
        print("cli-metrics-compared: \(report.smokeProbe.comparedWithCLIMetrics)")
        printVerdict(report.verdict)
    case ["recording-session-synthetic-smoke"]:
        let report = RecordingSessionSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.first == "recording-session-run":
        let configuration = try RecordingSessionRunConfiguration.parse(Array(args.dropFirst()))
        let baselineURL = URL(fileURLWithPath: configuration.integratedBaselinePath)
        let baseline = try IntegratedAvReport.readValidated(from: baselineURL)
        let report = try RecordingSessionRunner.run(
            configuration: configuration,
            integratedBaseline: baseline
        )
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.reportPath)
        print("recording session report written: \(configuration.reportPath)")
        print("artifact-root: \(report.manifest.rootDirectory)")
        print("artifacts: \(report.manifest.entries.count)")
        print("dropped-chunks: \(report.writerPressure.droppedChunkCount)")
        print("gap-markers: \(report.writerPressure.gapMarkerCount)")
        printVerdict(report.verdict)
    case let args where args.first == "packaging-field-run":
        let configuration = try PackagingFieldRunConfiguration.parse(Array(args.dropFirst()))
        let integratedURL = URL(fileURLWithPath: configuration.integratedReportPath)
        let appURL = URL(fileURLWithPath: configuration.appReportPath)
        let recordingURL = URL(fileURLWithPath: configuration.recordingReportPath)
        let integratedReport = try IntegratedAvReport.readValidated(from: integratedURL)
        let appReport = try NativeAppShellReport.readValidated(from: appURL)
        let recordingReport = try RecordingSessionArtifactReport.readValidated(from: recordingURL)
        let report = try PackagingFieldRunner.run(
            configuration: configuration,
            integratedReport: integratedReport,
            appShellReport: appReport,
            recordingReport: recordingReport
        )
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.reportPath)
        print("packaging field-test report written: \(configuration.reportPath)")
        print("package-root: \(configuration.outputDirectory)")
        print("artifacts: \(report.package.artifacts.count)")
        print("distribution: \(report.distributionMethod.rawValue)")
        printVerdict(report.verdict)
    case ["packaging-field-synthetic-smoke"]:
        let report = PackagingFieldTestSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.first == "field-runtime-proof-run":
        let configuration = try FieldReadyRuntimeProofRunConfiguration.parse(Array(args.dropFirst()))
        let integratedURL = URL(fileURLWithPath: configuration.integratedReportPath)
        let appURL = URL(fileURLWithPath: configuration.appReportPath)
        let recordingURL = URL(fileURLWithPath: configuration.recordingReportPath)
        let packagingURL = URL(fileURLWithPath: configuration.packagingReportPath)
        let integratedReport = try IntegratedAvReport.readValidated(from: integratedURL)
        let appReport = try NativeAppShellReport.readValidated(from: appURL)
        let recordingReport = try RecordingSessionArtifactReport.readValidated(from: recordingURL)
        let packagingReport = try PackagingFieldTestReport.readValidated(from: packagingURL)
        let report = FieldReadyRuntimeProofRunner.run(
            configuration: configuration,
            integratedReport: integratedReport,
            appShellReport: appReport,
            recordingReport: recordingReport,
            packagingReport: packagingReport
        )
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("field-ready runtime proof written: \(configuration.outputPath)")
        print("integrated-report: \(integratedReport.id)")
        print("packaging-report: \(packagingReport.id)")
        printVerdict(report.verdict)
    case let args where args.first == "field-readiness-run":
        let configuration = try FieldReadinessRunConfiguration.parse(Array(args.dropFirst()))
        let integratedURL = URL(fileURLWithPath: configuration.integratedReportPath)
        let integratedReport = try IntegratedAvReport.readValidated(from: integratedURL)
        let result = try FieldReadinessRunner.run(
            configuration: configuration,
            integratedReport: integratedReport
        )
        print("field readiness reports written: \(configuration.outputDirectory)")
        print("integrated-report: \(result.integratedReportId)")
        print("app-report: \(result.appReportPath)")
        print("recording-report: \(result.recordingReportPath)")
        print("packaging-report: \(result.packagingReportPath)")
        print("field-runtime-proof: \(result.proofReportPath)")
        printVerdict(result.verdict)
    case ["field-runtime-synthetic-smoke"]:
        let report = FieldReadyRuntimeSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["faster-than-lola-closure-synthetic-smoke"]:
        let report = FasterThanLoLaClosureSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case ["external-connector-synthetic-smoke"]:
        let report = ExternalConnectorSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        print("source-level-verdict: \(report.sourceLevelVerdict.rawValue)")
        print("real-world-verdict: \(report.realWorldVerdict.rawValue)")
        printVerdict(report.verdict)
    case let args where args.count == 3 && args[0] == "external-connector-report-run" && args[1] == "--output":
        let report = ExternalConnectorSyntheticSmoke.run()
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: args[2])
        print("external connector report written: \(args[2])")
        print("connectors: \(report.connectors.count)")
        print("source-level-verdict: \(report.sourceLevelVerdict.rawValue)")
        print("real-world-verdict: \(report.realWorldVerdict.rawValue)")
        printVerdict(report.verdict)
    case let args where args.first == "external-connector-session-run":
        let configuration = try ExternalConnectorSessionConfiguration.parse(Array(args.dropFirst()))
        let report = try ExternalConnectorSessionRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("external connector session report written: \(configuration.outputPath)")
        print("connector: \(report.connector.rawValue)")
        print("role: \(report.role.rawValue)")
        print("dry-run: \(report.dryRun)")
        printVerdict(report.verdict)
    case let args where args.first == "external-connector-connection-plan-run":
        let configuration = try ExternalConnectorConnectionPlanConfiguration.parse(Array(args.dropFirst()))
        let report = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("external connector connection plan written: \(configuration.outputPath)")
        print("connector: \(report.connector.rawValue)")
        print("endpoints: \(report.endpoints.count)")
        printVerdict(report.verdict)
    case let args where args.first == "external-connector-nmp-plan-run":
        let configuration = try ExternalConnectorNmpPlanConfiguration.parse(Array(args.dropFirst()))
        let report = try ExternalConnectorNmpPlanRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("external connector NMP plan written: \(configuration.outputPath)")
        print("connectors: \(report.connectors.count)")
        print("plans: \(report.plans.count)")
        printVerdict(report.verdict)
    case let args where args.first == "external-connector-nmp-preflight-run":
        let configuration = try ExternalConnectorNmpPreflightConfiguration.parse(Array(args.dropFirst()))
        let plan = try ExternalConnectorNmpPlanReport.readValidated(fromPath: configuration.planPath)
        let report = try ExternalConnectorNmpPreflightRunner.run(configuration: configuration, plan: plan)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("external connector NMP preflight written: \(configuration.outputPath)")
        print("plan: \(report.planID)")
        print("results: \(report.results.count)")
        printVerdict(report.verdict)
    case let args where args.first == "external-connector-nmp-endpoint-run":
        let configuration = try ExternalConnectorNmpEndpointRunConfiguration.parse(Array(args.dropFirst()))
        let plan = try ExternalConnectorNmpPlanReport.readValidated(fromPath: configuration.planPath)
        let preflight = try configuration.preflightPath.map {
            try ExternalConnectorNmpPreflightReport.readValidated(fromPath: $0)
        }
        let report = try ExternalConnectorNmpEndpointRunRunner.run(
            configuration: configuration,
            plan: plan,
            preflight: preflight
        )
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("external connector NMP endpoint run written: \(configuration.outputPath)")
        print("plan: \(report.planID)")
        print("side: \(report.side.rawValue)")
        print("results: \(report.results.count)")
        printVerdict(report.verdict)
    case let args where args.first == "external-connector-nmp-workflow-run":
        let configuration = try ExternalConnectorNmpWorkflowConfiguration.parse(Array(args.dropFirst()))
        let report = try ExternalConnectorNmpWorkflowRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.plan.prettyJSONData(), to: report.planPath)
        try writeJSONData(try report.preflight.prettyJSONData(), to: report.preflightPath)
        try writeJSONData(try report.endpointRun.prettyJSONData(), to: report.endpointRunPath)
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("external connector NMP workflow written: \(configuration.outputPath)")
        print("plan: \(report.planPath)")
        print("preflight: \(report.preflightPath)")
        print("endpoint-run: \(report.endpointRunPath)")
        print("side: \(report.side.rawValue)")
        printVerdict(report.verdict)
    case let args where args.first == "external-connector-executable-preflight-run":
        let configuration = try ExternalConnectorExecutablePreflightConfiguration.parse(Array(args.dropFirst()))
        let report = ExternalConnectorExecutablePreflightRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("external connector executable preflight written: \(configuration.outputPath)")
        print("probes: \(report.probes.count)")
        print("failing-probes: \(report.probes.filter { $0.verdict == .fail }.count)")
        printVerdict(report.verdict)
    case let args where args.count == 5 && args[0] == "lola-capture-decode" && args[1] == "--input" && args[3] == "--output":
        let report = try LoLaCompatibilityCaptureDecoder.decode(inputPath: args[2])
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: args[4])
        print("LoLa compatibility capture report written: \(args[4])")
        print("input-format: \(report.inputFormat.rawValue)")
        print("packets: \(report.summary.packetCount)")
        print("media-envelope-packets: \(report.summary.lolaMediaEnvelopePacketCount)")
        printVerdict(report.verdict)
    case let args where args.first == "lola-packet-fixture-run":
        let configuration = try LoLaCompatibilityPacketFixtureRunConfiguration.parse(Array(args.dropFirst()))
        let report = try LoLaCompatibilityPacketFixtureRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("LoLa packet fixture report written: \(configuration.outputPath)")
        if let captureOutputPath = configuration.captureOutputPath {
            print("synthetic-capture: \(captureOutputPath)")
        }
        print("packets: \(report.decodedCapturePacketCount)")
        printVerdict(report.verdict)
    case let args where args.count == 3 && args[0] == "lola-media-report-run" && args[1] == "--output":
        let configuration = ExternalConnectorSessionConfiguration(
            connector: .lola,
            role: .tx,
            peer: "192.0.2.20",
            localHost: "192.0.2.10",
            outputPath: args[2],
            mediaMode: .audioVideo
        )
        let report = try LoLaCompatibilityMediaSession.transmitReport(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: args[2])
        print("LoLa compatibility media session report written: \(args[2])")
        print("frames: \(report.frames.count)")
        print("real-link-transmitted: \(report.realLinkTransmitted)")
        printVerdict(report.verdict)
    case let args where args.first == "lola-raw-link-tx-run":
        let configuration = try LoLaRawLinkTransmitRunConfiguration.parse(Array(args.dropFirst()))
        let report = try LoLaRawLinkTransmitRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("LoLa raw-link TX report written: \(configuration.outputPath)")
        print("interface: \(configuration.interfaceName)")
        print("frames: \(report.frames.count)")
        print("real-link-transmitted: \(report.realLinkTransmitted)")
        printVerdict(report.verdict)
    case let args where args.first == "lola-raw-link-rx-run":
        let configuration = try LoLaRawLinkReceiveRunConfiguration.parse(Array(args.dropFirst()))
        let report = try LoLaRawLinkReceiveRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("LoLa raw-link RX report written: \(configuration.outputPath)")
        print("interface: \(configuration.interfaceName)")
        print("frames: \(report.frames.count)")
        printVerdict(report.verdict)
    case let args where args.first == "lola-udp-media-tx-run":
        let configuration = try LoLaUdpMediaTransmitRunConfiguration.parse(Array(args.dropFirst()))
        let report = try LoLaUdpMediaTransmitRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("LoLa UDP media TX report written: \(configuration.outputPath)")
        print("peer: \(configuration.peer)")
        print("frames: \(report.frames.count)")
        print("real-link-transmitted: \(report.realLinkTransmitted)")
        printVerdict(report.verdict)
    case let args where args.first == "lola-udp-media-rx-run":
        let configuration = try LoLaUdpMediaReceiveRunConfiguration.parse(Array(args.dropFirst()))
        let report = try LoLaUdpMediaReceiveRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("LoLa UDP media RX report written: \(configuration.outputPath)")
        print("local-host: \(configuration.localHost)")
        print("frames: \(report.frames.count)")
        print("real-link-transmitted: \(report.realLinkTransmitted)")
        printVerdict(report.verdict)
    case let args where args.first == "faster-than-lola-closure-run":
        let configuration = try FasterThanLoLaClosureRunConfiguration.parse(Array(args.dropFirst()))
        let report = FasterThanLoLaClosureRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("faster-than-LoLa closure report written: \(configuration.outputPath)")
        print("claim-scope: \(report.claimScope.rawValue)")
        print("evidence-count: \(report.evidence.count)")
        print("comparison-result: \(report.comparison.result.rawValue)")
        printVerdict(report.verdict)
    case ["release-hardening-synthetic-smoke"]:
        let report = ReleaseHardeningSyntheticSmoke.run()
        try report.validate()
        print(try report.prettyJSONString())
        printVerdict(report.verdict)
    case let args where args.first == "release-hardening-run":
        let configuration = try ReleaseHardeningRunConfiguration.parse(Array(args.dropFirst()))
        let report = ReleaseHardeningRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("release hardening report written: \(configuration.outputPath)")
        print("claims: \(report.claims.count)")
        print("remaining-partial-gates: \(report.remainingPartialGates.count)")
        printVerdict(report.verdict)
    case let args where args.first == "open-source-release-readiness-run":
        let configuration = try OpenSourceReleaseReadinessRunConfiguration.parse(Array(args.dropFirst()))
        let report = OpenSourceReleaseReadinessRunner.run(configuration: configuration)
        try report.validate()
        try writeJSONData(try report.prettyJSONData(), to: configuration.outputPath)
        print("open-source release readiness report written: \(configuration.outputPath)")
        print("requirements: \(report.requirements.count)")
        print("blockers: \(report.blockers.count)")
        printVerdict(report.verdict)
    default:
        return false
    }
    return true
}
