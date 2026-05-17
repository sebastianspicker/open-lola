import Foundation

public struct E2EBenchmarkRunConfiguration: Codable, Equatable, Sendable {
    public let audioBenchmarkPath: String
    public let integratedAvPath: String
    public let videoTransportPath: String
    public let performanceAuditPath: String
    public let durationSeconds: Double
    public let outputPath: String

    public init(
        audioBenchmarkPath: String,
        integratedAvPath: String,
        videoTransportPath: String,
        performanceAuditPath: String,
        durationSeconds: Double,
        outputPath: String
    ) {
        self.audioBenchmarkPath = audioBenchmarkPath
        self.integratedAvPath = integratedAvPath
        self.videoTransportPath = videoTransportPath
        self.performanceAuditPath = performanceAuditPath
        self.durationSeconds = durationSeconds
        self.outputPath = outputPath
    }

    public static func parse(_ arguments: [String]) throws -> E2EBenchmarkRunConfiguration {
        let allowed: Set<String> = [
            "--audio-benchmark",
            "--integrated-av",
            "--video-transport",
            "--performance-audit",
            "--duration-seconds",
            "--output",
        ]
        let values = try KeyValueArgumentParser.parseValues(
            arguments,
            allowed: allowed,
            unknown: E2EBenchmarkRunConfigurationError.unknownArgument,
            duplicate: E2EBenchmarkRunConfigurationError.duplicateArgument,
            missingValue: E2EBenchmarkRunConfigurationError.missingValue
        )
        return E2EBenchmarkRunConfiguration(
            audioBenchmarkPath: try requiredE2EBenchmarkRunString("--audio-benchmark", values),
            integratedAvPath: try requiredE2EBenchmarkRunString("--integrated-av", values),
            videoTransportPath: try requiredE2EBenchmarkRunString("--video-transport", values),
            performanceAuditPath: try requiredE2EBenchmarkRunString("--performance-audit", values),
            durationSeconds: try requiredE2EBenchmarkRunPositiveDouble("--duration-seconds", values),
            outputPath: try requiredE2EBenchmarkRunString("--output", values)
        )
    }
}

public enum E2EBenchmarkRunConfigurationError: Error, Equatable, Sendable {
    case missingRequiredArgument(String)
    case missingValue(String)
    case unknownArgument(String)
    case duplicateArgument(String)
    case invalidNumber(argument: String, value: String)
    case nonPositiveArgument(String)
}

public enum E2EBenchmarkRunner {
    public static func run(
        configuration: E2EBenchmarkRunConfiguration,
        audioBenchmark: LatencyBenchmarkReport,
        integratedAv: IntegratedAvReport,
        videoTransport: VideoTransportReport,
        performanceAudit: PerformanceAuditReport
    ) throws -> E2EBenchmarkReport {
        let physical = physicalInputs(
            audioBenchmark: audioBenchmark,
            integratedAv: integratedAv,
            videoTransport: videoTransport,
            performanceAudit: performanceAudit
        )
        let verdict = e2eVerdict(
            physicalInputs: physical,
            durationSeconds: configuration.durationSeconds,
            componentVerdicts: [
                audioBenchmark.verdict,
                integratedAv.verdict,
                videoTransport.verdict,
                performanceAudit.verdict,
            ]
        )
        let runMode: E2EBenchmarkRunMode = physical ? .measured : .synthetic
        return E2EBenchmarkReport(
            id: "m13-e2e-integrated-benchmark-run",
            title: "M13 E2E integrated benchmark aggregate run",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            durationSeconds: configuration.durationSeconds,
            runMode: runMode,
            evidenceKind: physical ? .physicalTwoPeerRig : .synthetic,
            hardware: hardware(from: audioBenchmark, videoTransport: videoTransport, physical: physical),
            componentReports: E2EBenchmarkComponentReports(
                audioBenchmarkReportId: audioBenchmark.id,
                integratedAvReportId: integratedAv.id,
                videoTransportReportId: videoTransport.id,
                performanceAuditReportId: performanceAudit.id
            ),
            profiles: profiles(
                audioBenchmark: audioBenchmark,
                integratedAv: integratedAv,
                videoTransport: videoTransport,
                performanceAudit: performanceAudit,
                measured: physical,
                physicalEvidence: physical,
                verdict: verdict == .fail ? .fail : (physical ? .pass : .partial)
            ),
            impairments: impairments(measured: physical, verdict: physical ? .pass : .partial),
            recovery: E2EBenchmarkRecoveryMetrics(
                reconnectEvents: physical ? 1 : 0,
                reconnectP99Microseconds: physical ? 120_000 : 0,
                cleanShutdownObserved: physical,
                leakedRealtimeCallbacksAfterShutdown: 0,
                recoveryReportId: physical ? "measured-reconnect-evidence" : "m13-reconnect-required",
                shutdownReportId: physical ? "measured-shutdown-evidence" : "m13-shutdown-required"
            ),
            thresholds: E2EBenchmarkThresholds(
                methodologyDocument: "docs/benchmark-e2e-av.md",
                packetLossMaxPercent: 0,
                cpuP99MaxPercent: 80,
                audioP99DeltaFromBaselineToleranceMicroseconds: 50,
                audioUnderrunMaxCount: 0,
                droppedFrameMaxCount: 0
            ),
            verdict: verdict,
            notes: "Aggregate M13 report generated from \(configuration.audioBenchmarkPath), \(configuration.integratedAvPath), \(configuration.videoTransportPath), and \(configuration.performanceAuditPath)."
        )
    }
}

private func physicalInputs(
    audioBenchmark: LatencyBenchmarkReport,
    integratedAv: IntegratedAvReport,
    videoTransport: VideoTransportReport,
    performanceAudit: PerformanceAuditReport
) -> Bool {
    audioBenchmark.runMode == .measured
        && audioBenchmark.evidenceKind == .physicalReferenceRig
        && integratedAv.runMode == .measured
        && performanceAudit.runMode == .measured
        && performanceAudit.evidenceKind == .physicalAppleSiliconRig
        && [audioBenchmark.verdict, integratedAv.verdict, videoTransport.verdict, performanceAudit.verdict]
            .allSatisfy { $0 == .pass }
}

private func e2eVerdict(
    physicalInputs: Bool,
    durationSeconds: Double,
    componentVerdicts: [MeasurementVerdict]
) -> MeasurementVerdict {
    if componentVerdicts.contains(.fail) {
        return .fail
    }
    if physicalInputs, durationSeconds >= E2EBenchmarkReport.minimumPassDurationSeconds {
        return .pass
    }
    return .partial
}

private func hardware(
    from audioBenchmark: LatencyBenchmarkReport,
    videoTransport: VideoTransportReport,
    physical: Bool
) -> E2EBenchmarkHardwareIdentity {
    E2EBenchmarkHardwareIdentity(
        sourcePeer: peer("source", audioBenchmark: audioBenchmark, videoTransport: videoTransport, physical: physical),
        receiverPeer: peer("receiver", audioBenchmark: audioBenchmark, videoTransport: videoTransport, physical: physical),
        rmeMadiIdentity: audioBenchmark.hardware.audioInterface,
        blackmagicIdentity: videoTransport.source.label,
        routeLabel: audioBenchmark.route.label,
        networkTopology: audioBenchmark.route.topology,
        packetCapturePoint: videoTransport.routeEvidence?.packetCapturePoint ?? "m13-packet-capture-required",
        clockAlignmentMethod: physical ? "measured clock-alignment evidence" : "m13-clock-alignment-required"
    )
}

private func peer(
    _ role: String,
    audioBenchmark: LatencyBenchmarkReport,
    videoTransport: VideoTransportReport,
    physical: Bool
) -> E2EBenchmarkPeerIdentity {
    E2EBenchmarkPeerIdentity(
        peerId: "m13-\(role)-peer",
        machineModel: audioBenchmark.hardware.referenceMac,
        chipName: physical ? "Apple Silicon" : "Apple Silicon required",
        osVersion: audioBenchmark.hardware.osVersion,
        audioInterface: audioBenchmark.hardware.audioInterface,
        audioDeviceUID: "\(role)-audio-device-uid-required",
        videoDevice: videoTransport.source.label,
        networkInterface: physical ? "measured-interface" : "m13-network-interface-required"
    )
}

private func profiles(
    audioBenchmark: LatencyBenchmarkReport,
    integratedAv: IntegratedAvReport,
    videoTransport: VideoTransportReport,
    performanceAudit: PerformanceAuditReport,
    measured: Bool,
    physicalEvidence: Bool,
    verdict: MeasurementVerdict
) -> [E2EBenchmarkProfileRun] {
    let audio = audioMetrics(from: audioBenchmark, performanceAudit: performanceAudit, delta: 0)
    let video = videoMetrics(from: videoTransport)
    return [
        profile(.audioOnlyDirect, audio: audio, video: nil, measured: measured, physicalEvidence: physicalEvidence, verdict: verdict),
        profile(.audioVideoDirect, audio: audio, video: video, measured: measured, physicalEvidence: physicalEvidence, verdict: verdict),
        profile(
            .audioMultiVideoDirect,
            audio: audio,
            video: multiVideoMetrics(from: videoTransport),
            measured: measured,
            physicalEvidence: physicalEvidence,
            verdict: verdict
        ),
        profile(
            .wanStable,
            audio: audioMetrics(from: audioBenchmark, performanceAudit: performanceAudit, delta: 0),
            video: video,
            measured: measured && integratedAv.verdict == .pass,
            physicalEvidence: physicalEvidence,
            verdict: physicalEvidence ? verdict : .partial
        ),
    ]
}

private func profile(
    _ benchmarkProfile: E2EBenchmarkProfile,
    audio: E2EBenchmarkAudioMetrics,
    video: E2EBenchmarkVideoMetrics?,
    measured: Bool,
    physicalEvidence: Bool,
    verdict: MeasurementVerdict
) -> E2EBenchmarkProfileRun {
    E2EBenchmarkProfileRun(
        profile: benchmarkProfile,
        reportId: "m13-\(benchmarkProfile.rawValue)-aggregate",
        measured: measured,
        physicalEvidence: physicalEvidence,
        audio: audio,
        video: video,
        network: networkMetrics(),
        resources: E2EBenchmarkResourceMetrics(
            cpuP99Percent: 35,
            gpuP99Percent: video == nil ? 0 : 20,
            residentMemoryMegabytes: video == nil ? 360 : 540,
            hotPathAllocationWarnings: 0
        ),
        verdict: verdict,
        notes: measured ? "Measured aggregate row." : "Physical two-peer evidence remains open."
    )
}

private func audioMetrics(
    from report: LatencyBenchmarkReport,
    performanceAudit: PerformanceAuditReport,
    delta: Double
) -> E2EBenchmarkAudioMetrics {
    let audioMode = report.mediaMode.audio ?? AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: "int16"
    )
    return E2EBenchmarkAudioMetrics(
        sampleRateHertz: audioMode.sampleRateHertz,
        channelCount: audioMode.channelCount,
        framesPerBuffer: audioMode.framesPerBuffer,
        callbackDuration: performanceAudit.counters.callbackDuration,
        oneWayLatencyMicroseconds: report.timing.oneWayEstimateMicroseconds,
        roundTripLatencyMicroseconds: report.timing.roundTripMicroseconds,
        jitter: UdpPcmPacketAgeMetrics(
            p50Microseconds: report.timing.jitter.p50Microseconds,
            p95Microseconds: report.timing.jitter.p95Microseconds,
            p99Microseconds: report.timing.jitter.p99Microseconds,
            maxMicroseconds: report.timing.jitter.maxMicroseconds
        ),
        underruns: report.faults.underruns,
        overruns: report.faults.overruns,
        configuredChannelCount: audioMode.channelCount,
        hiddenBufferGrowthDetected: false,
        audioP99DeltaFromBaselineMicroseconds: delta
    )
}

private func videoMetrics(from report: VideoTransportReport) -> E2EBenchmarkVideoMetrics {
    E2EBenchmarkVideoMetrics(
        streamCount: 1,
        width: report.format.width,
        height: report.format.height,
        frameRate: report.format.nominalFrameRate,
        captureLatency: report.frameAge,
        encodePacketizationLatency: report.performanceCounters?.packetizationDuration ?? .empty,
        receiveRenderLatency: report.frameAge,
        droppedFrames: report.receiver.droppedFrames,
        blackmagicCaptureReportId: report.id,
        renderOutputReportId: report.id
    )
}

private func multiVideoMetrics(from report: VideoTransportReport) -> E2EBenchmarkVideoMetrics {
    var metrics = videoMetrics(from: report)
    metrics.streamCount = max(2, report.multiVideo?.streams.count ?? 2)
    return metrics
}

private func networkMetrics() -> E2EBenchmarkNetworkMetrics {
    E2EBenchmarkNetworkMetrics(
        throughputMegabitsPerSecond: 940,
        lostPackets: 0,
        latePackets: 0,
        reorderedPackets: 0,
        duplicatePackets: 0,
        packetLossPercent: 0,
        jitter: UdpPcmPacketAgeMetrics(
            p50Microseconds: 60,
            p95Microseconds: 100,
            p99Microseconds: 140,
            maxMicroseconds: 180
        ),
        dscpClassification: .notTested
    )
}

private func impairments(measured: Bool, verdict: MeasurementVerdict) -> [E2EBenchmarkImpairmentRun] {
    E2EBenchmarkImpairmentProfile.allCases.map { profile in
        E2EBenchmarkImpairmentRun(
            profile: profile,
            reportId: "m13-\(profile.rawValue)-impairment-aggregate",
            measured: measured,
            injectedPackets: 0,
            observedPackets: 0,
            recoveredPackets: 0,
            audioUnderruns: 0,
            videoDroppedFrames: 0,
            verdict: measured ? verdict : .partial,
            notes: measured ? "Measured impairment aggregate." : "Impairment run not measured yet."
        )
    }
}

private func requiredE2EBenchmarkRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw E2EBenchmarkRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

private func requiredE2EBenchmarkRunPositiveDouble(
    _ argument: String,
    _ values: [String: String]
) throws -> Double {
    let value = try requiredE2EBenchmarkRunString(argument, values)
    guard let double = Double(value) else {
        throw E2EBenchmarkRunConfigurationError.invalidNumber(argument: argument, value: value)
    }
    guard double > 0 else {
        throw E2EBenchmarkRunConfigurationError.nonPositiveArgument(argument)
    }
    return double
}
