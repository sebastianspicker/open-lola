import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
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

// Input reports identify only the machine that recorded them, so that machine is reported as the source peer;
// a direct-peer session report's host block names its own peer's machine and takes precedence. The receiver peer
// and fields no input carries stay "unknown" (a placeholder that blocks PASS).
func hardware(
    from audioBenchmark: LatencyBenchmarkReport,
    videoTransport: VideoTransportReport,
    performanceAudit: PerformanceAuditReport,
    sessions: E2EBenchmarkSessionInputs = E2EBenchmarkSessionInputs()
) -> E2EBenchmarkHardwareIdentity {
    let sourceHost = sessions.sourceHost
    let receiverHost = sessions.receiverHost
    return E2EBenchmarkHardwareIdentity(
        sourcePeer: E2EBenchmarkPeerIdentity(
            peerId: "m13-source-peer",
            machineModel: sourceHost.map { e2eKnownValue($0.machineModel) } ?? audioBenchmark.hardware.referenceMac,
            chipName: e2eKnownValue(sourceHost?.chipName ?? performanceAudit.processContext.chipName),
            osVersion: sourceHost.map { e2eKnownValue($0.osVersion) } ?? audioBenchmark.hardware.osVersion,
            audioInterface: audioBenchmark.hardware.audioInterface,
            audioDeviceUID: "source-audio-device-uid-required",
            videoDevice: videoTransport.source.label,
            networkInterface: e2eUnknownValue
        ),
        receiverPeer: E2EBenchmarkPeerIdentity(
            peerId: "m13-receiver-peer",
            machineModel: e2eKnownValue(receiverHost?.machineModel ?? ""),
            chipName: e2eKnownValue(receiverHost?.chipName ?? ""),
            osVersion: e2eKnownValue(receiverHost?.osVersion ?? ""),
            audioInterface: e2eUnknownValue,
            audioDeviceUID: "receiver-audio-device-uid-required",
            videoDevice: e2eUnknownValue,
            networkInterface: e2eUnknownValue
        ),
        rmeMadiIdentity: audioBenchmark.hardware.audioInterface,
        blackmagicIdentity: videoTransport.source.label,
        routeLabel: audioBenchmark.route.label,
        networkTopology: audioBenchmark.route.topology,
        packetCapturePoint: videoTransport.routeEvidence?.packetCapturePoint ?? "m13-packet-capture-required",
        clockAlignmentMethod: e2eUnknownValue
    )
}

let e2eUnknownValue = "unknown"

func e2eKnownValue(_ value: String) -> String {
    value.isEmpty ? e2eUnknownValue : value
}

struct E2EBenchmarkProfileBuildContext {
    let audioBenchmark: LatencyBenchmarkReport
    let integratedAv: IntegratedAvReport
    let videoTransport: VideoTransportReport
    let performanceAudit: PerformanceAuditReport
    let sessions: E2EBenchmarkSessionInputs
    let measured: Bool
    let physicalEvidence: Bool
    let verdict: MeasurementVerdict
}

struct E2EBenchmarkProfileRowContext {
    let audio: E2EBenchmarkAudioMetrics
    let video: E2EBenchmarkVideoMetrics?
    let network: E2EBenchmarkNetworkMetrics
    let resources: E2EBenchmarkResourceMetrics
    let measured: Bool
    let physicalEvidence: Bool
    let verdict: MeasurementVerdict
}

func profiles(context: E2EBenchmarkProfileBuildContext) -> [E2EBenchmarkProfileRun] {
    let audio = audioMetrics(
        from: context.audioBenchmark,
        integratedAv: context.integratedAv,
        performanceAudit: context.performanceAudit
    )
    let video = videoMetrics(from: context.videoTransport)
    let network = networkMetrics(from: context.audioBenchmark, sessions: context.sessions)
    // Session reports measure a direct route, so the WAN row keeps throughput and packet order unmeasured.
    let wanNetwork = networkMetrics(from: context.audioBenchmark, sessions: E2EBenchmarkSessionInputs())
    let rows: [(E2EBenchmarkProfile, E2EBenchmarkVideoMetrics?)] = [
        (.audioOnlyDirect, nil),
        (.audioVideoDirect, video),
        (.audioMultiVideoDirect, multiVideoMetrics(from: context.videoTransport)),
        (.wanStable, video)
    ]
    return rows.map { benchmarkProfile, rowVideo in
        let wanStable = benchmarkProfile == .wanStable
        return profile(
            benchmarkProfile,
            context: E2EBenchmarkProfileRowContext(
                audio: audio,
                video: rowVideo,
                network: wanStable ? wanNetwork : network,
                resources: resourceMetrics(context: context, video: rowVideo),
                measured: wanStable ? context.measured && context.integratedAv.verdict == .pass : context.measured,
                physicalEvidence: context.physicalEvidence,
                verdict: wanStable && !context.physicalEvidence ? .partial : context.verdict
            )
        )
    }
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
        network: context.network,
        resources: context.resources,
        verdict: context.verdict,
        notes: context.measured ? "Measured aggregate row." : "Physical two-peer evidence remains open."
    )
}

// CPU is the worst P99 any input or session measured; GPU comes only from a measured integrated A/V load sample
// and only applies to video rows; memory is the largest of the audio benchmark and session peaks, and hot-path
// allocations come from the performance audit.
func resourceMetrics(
    context: E2EBenchmarkProfileBuildContext,
    video: E2EBenchmarkVideoMetrics?
) -> E2EBenchmarkResourceMetrics {
    let audioCpu = context.audioBenchmark.resources.cpuP99Percent
    let cpuValues = [audioCpu, context.integratedAv.systemLoad.cpuP99Percent, context.sessions.cpuP99Percent]
    let memory = context.audioBenchmark.resources.residentMemoryMegabytes
    return E2EBenchmarkResourceMetrics(
        cpuP99Percent: cpuValues.compactMap { $0 }.max() ?? audioCpu,
        gpuP99Percent: video == nil ? nil : context.integratedAv.systemLoad.gpuP99Percent,
        residentMemoryMegabytes: max(memory, context.sessions.residentMemoryPeakMegabytes ?? memory),
        hotPathAllocationWarnings: context.performanceAudit.counters.allocationWarningCount
    )
}

func audioMetrics(
    from report: LatencyBenchmarkReport,
    integratedAv: IntegratedAvReport,
    performanceAudit: PerformanceAuditReport
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
        jitter: e2ePacketAge(from: report.timing.jitter),
        underruns: report.faults.underruns,
        overruns: report.faults.overruns,
        configuredChannelCount: audioMode.channelCount,
        hiddenBufferGrowthDetected: integratedAv.audio.hiddenPlayoutGrowthDetected,
        audioP99DeltaFromBaselineMicroseconds: integratedAv.audio.integratedCallbackP99Microseconds
            - integratedAv.audio.baselineCallbackP99Microseconds
    )
}

func e2ePacketAge(from jitter: LatencyJitterMetrics) -> UdpPcmPacketAgeMetrics {
    UdpPcmPacketAgeMetrics(
        p50Microseconds: jitter.p50Microseconds,
        p95Microseconds: jitter.p95Microseconds,
        p99Microseconds: jitter.p99Microseconds,
        maxMicroseconds: jitter.maxMicroseconds
    )
}

// The video transport report measures capture-to-receive frame age but no receive-to-render latency, so the
// render latency stays nil rather than reusing the capture value.
func videoMetrics(from report: VideoTransportReport) -> E2EBenchmarkVideoMetrics {
    E2EBenchmarkVideoMetrics(
        streamCount: 1,
        width: report.format.width,
        height: report.format.height,
        frameRate: report.format.nominalFrameRate,
        captureLatency: report.frameAge,
        encodePacketizationLatency: report.performanceCounters?.packetizationDuration ?? .empty,
        receiveRenderLatency: nil,
        droppedFrames: report.receiver.droppedFrames,
        blackmagicCaptureReportId: report.id,
        renderOutputReportId: report.id
    )
}

func multiVideoMetrics(from report: VideoTransportReport) -> E2EBenchmarkVideoMetrics {
    var metrics = videoMetrics(from: report)
    metrics.streamCount = report.multiVideo?.streams.count ?? 1
    return metrics
}

// Network jitter uses the audio benchmark's packet jitter: it is a jitter measurement of the same UDP route,
// whereas the integrated A/V packet age is an end-to-end age that may be unmeasured. Throughput, reordering,
// and duplication come only from direct-peer session reports and stay nil without them.
func networkMetrics(
    from audioBenchmark: LatencyBenchmarkReport,
    sessions: E2EBenchmarkSessionInputs
) -> E2EBenchmarkNetworkMetrics {
    E2EBenchmarkNetworkMetrics(
        throughputMegabitsPerSecond: sessions.throughputMegabitsPerSecond,
        lostPackets: audioBenchmark.loss.lostPackets,
        latePackets: audioBenchmark.loss.latePackets,
        reorderedPackets: sessions.reorderedPackets,
        duplicatePackets: sessions.duplicatePackets,
        packetLossPercent: audioBenchmark.loss.lossPercent,
        jitter: e2ePacketAge(from: audioBenchmark.timing.jitter),
        dscpClassification: .notTested
    )
}

// No input report runs injected impairments, so every impairment row is reported as not measured.
func impairments() -> [E2EBenchmarkImpairmentRun] {
    E2EBenchmarkImpairmentProfile.allCases.map { profile in
        E2EBenchmarkImpairmentRun(
            profile: profile,
            reportId: "m13-\(profile.rawValue)-impairment-aggregate",
            measured: false,
            injectedPackets: 0,
            observedPackets: 0,
            recoveredPackets: 0,
            audioUnderruns: 0,
            videoDroppedFrames: 0,
            verdict: .partial,
            notes: "Impairment run not measured yet."
        )
    }
}

// PASS needs every gating field measured; GPU, impairment, reconnect, and receive-render fields still have no
// source, so a physical run stops at PARTIAL and the notes name the fields that withheld PASS.
func withholdingUnmeasuredPass(_ report: E2EBenchmarkReport) -> E2EBenchmarkReport {
    var report = report
    for index in report.profiles.indices
        where report.profiles[index].verdict == .pass && !report.profiles[index].unmeasuredFields.isEmpty {
        report.profiles[index].verdict = .partial
    }
    let unmeasured = report.unmeasuredPassFields
        + report.impairments.filter { !$0.measured }.map { "impairments[\($0.profile.rawValue)]" }
    guard report.verdict == .pass, !unmeasured.isEmpty else {
        return report
    }
    report.verdict = .partial
    report.notes += " PASS withheld because these fields were not measured: "
        + unmeasured.joined(separator: ", ") + "."
    return report
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
