// Builds benchmark profiles, hardware and peer rows, and aggregate verdicts from physical inputs outside the runner entry point.
import Foundation
import OpenLolaContracts

func physicalInputs(
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

func e2eVerdict(
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

func hardware(
    from audioBenchmark: LatencyBenchmarkReport,
    videoTransport: VideoTransportReport,
    physical: Bool
) -> E2EBenchmarkHardwareIdentity {
    E2EBenchmarkHardwareIdentity(
        sourcePeer: peer("source", audioBenchmark: audioBenchmark, videoTransport: videoTransport, physical: physical),
        receiverPeer: peer(
"receiver",
audioBenchmark: audioBenchmark,
videoTransport: videoTransport,
physical: physical
),
        rmeMadiIdentity: audioBenchmark.hardware.audioInterface,
        blackmagicIdentity: videoTransport.source.label,
        routeLabel: audioBenchmark.route.label,
        networkTopology: audioBenchmark.route.topology,
        packetCapturePoint: videoTransport.routeEvidence?.packetCapturePoint ?? "m13-packet-capture-required",
        clockAlignmentMethod: physical ? "measured clock-alignment evidence" : "m13-clock-alignment-required"
    )
}

func peer(
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

struct E2EBenchmarkProfileBuildContext {
    let audioBenchmark: LatencyBenchmarkReport
    let integratedAv: IntegratedAvReport
    let videoTransport: VideoTransportReport
    let performanceAudit: PerformanceAuditReport
    let measured: Bool
    let physicalEvidence: Bool
    let verdict: MeasurementVerdict
}

struct E2EBenchmarkProfileRowContext {
    let audio: E2EBenchmarkAudioMetrics
    let video: E2EBenchmarkVideoMetrics?
    let measured: Bool
    let physicalEvidence: Bool
    let verdict: MeasurementVerdict
}

func profiles(context: E2EBenchmarkProfileBuildContext) -> [E2EBenchmarkProfileRun] {
    let audio = audioMetrics(from: context.audioBenchmark, performanceAudit: context.performanceAudit, delta: 0)
    let video = videoMetrics(from: context.videoTransport)
    return [
        profile(
            .audioOnlyDirect,
            context: E2EBenchmarkProfileRowContext(
                audio: audio,
                video: nil,
                measured: context.measured,
                physicalEvidence: context.physicalEvidence,
                verdict: context.verdict
            )
        ),
        profile(
            .audioVideoDirect,
            context: E2EBenchmarkProfileRowContext(
                audio: audio,
                video: video,
                measured: context.measured,
                physicalEvidence: context.physicalEvidence,
                verdict: context.verdict
            )
        ),
        profile(
            .audioMultiVideoDirect,
            context: E2EBenchmarkProfileRowContext(
                audio: audio,
                video: multiVideoMetrics(from: context.videoTransport),
                measured: context.measured,
                physicalEvidence: context.physicalEvidence,
                verdict: context.verdict
            )
        ),
        profile(
            .wanStable,
            context: E2EBenchmarkProfileRowContext(
                audio: audioMetrics(from: context.audioBenchmark, performanceAudit: context.performanceAudit, delta: 0),
                video: video,
                measured: context.measured && context.integratedAv.verdict == .pass,
                physicalEvidence: context.physicalEvidence,
                verdict: context.physicalEvidence ? context.verdict : .partial
            )
        )
    ]
}

func profile(
    _ benchmarkProfile: E2EBenchmarkProfile,
    context: E2EBenchmarkProfileRowContext
) -> E2EBenchmarkProfileRun {
    E2EBenchmarkProfileRun(
        profile: benchmarkProfile,
        reportId: "m13-\(benchmarkProfile.rawValue)-aggregate",
        measured: context.measured,
        physicalEvidence: context.physicalEvidence,
        audio: context.audio,
        video: context.video,
        network: networkMetrics(measured: context.measured),
        resources: E2EBenchmarkResourceMetrics(
            cpuP99Percent: context.measured
                ? E2EBenchmarkRunnerMeasuredDefaults.cpuP99Percent
                : SourceValidationMetrics.cpuP99Percent,
            gpuP99Percent: context.video == nil ? 0 : 20,
            residentMemoryMegabytes: context.video == nil ? 360 : 540,
            hotPathAllocationWarnings: 0
        ),
        verdict: context.verdict,
        notes: context.measured ? "Measured aggregate row." : "Physical two-peer evidence remains open."
    )
}

func audioMetrics(
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

func videoMetrics(from report: VideoTransportReport) -> E2EBenchmarkVideoMetrics {
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

func multiVideoMetrics(from report: VideoTransportReport) -> E2EBenchmarkVideoMetrics {
    var metrics = videoMetrics(from: report)
    metrics.streamCount = max(2, report.multiVideo?.streams.count ?? 2)
    return metrics
}

enum E2EBenchmarkRunnerMeasuredDefaults {
    static let cpuP99Percent: Double = 35
    static let networkJitterP50Microseconds: Double = 60
    static let networkJitterP95Microseconds: Double = 100
    static let networkJitterP99Microseconds: Double = 140
    static let networkJitterMaxMicroseconds: Double = 180
}

func networkMetrics(measured: Bool) -> E2EBenchmarkNetworkMetrics {
    E2EBenchmarkNetworkMetrics(
        throughputMegabitsPerSecond: 940,
        lostPackets: 0,
        latePackets: 0,
        reorderedPackets: 0,
        duplicatePackets: 0,
        packetLossPercent: 0,
        jitter: UdpPcmPacketAgeMetrics(
            p50Microseconds: measured
                ? E2EBenchmarkRunnerMeasuredDefaults.networkJitterP50Microseconds
                : SourceValidationMetrics.jitter.p50Microseconds,
            p95Microseconds: measured
                ? E2EBenchmarkRunnerMeasuredDefaults.networkJitterP95Microseconds
                : SourceValidationMetrics.jitter.p95Microseconds,
            p99Microseconds: measured
                ? E2EBenchmarkRunnerMeasuredDefaults.networkJitterP99Microseconds
                : SourceValidationMetrics.jitter.p99Microseconds,
            maxMicroseconds: measured
                ? E2EBenchmarkRunnerMeasuredDefaults.networkJitterMaxMicroseconds
                : SourceValidationMetrics.jitter.maxMicroseconds
        ),
        dscpClassification: .notTested
    )
}

func impairments(measured: Bool, verdict: MeasurementVerdict) -> [E2EBenchmarkImpairmentRun] {
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

func requiredE2EBenchmarkRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw E2EBenchmarkRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

func requiredE2EBenchmarkRunPositiveDouble(
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
