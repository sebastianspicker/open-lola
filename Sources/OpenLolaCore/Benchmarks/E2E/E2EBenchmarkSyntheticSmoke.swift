// Constructs deterministic end-to-end profile and impairment metrics that exercise report validation without claiming measured hardware.
import Foundation
import OpenLolaContracts

/// Creates deterministic synthetic end-to-end benchmark evidence that exercises report validation without claiming physical measurement.
public enum E2EBenchmarkSyntheticSmoke {
    public static func run() throws -> E2EBenchmarkReport {
        report(E2EBenchmarkSyntheticReportDraft(
            runMode: .synthetic,
            evidenceKind: .synthetic,
            measured: false,
            physicalEvidence: false,
            verdict: .partial,
            durationSeconds: 60,
            hardware: syntheticHardware(),
            componentReports: E2EBenchmarkComponentReports(
                audioBenchmarkReportId: "m02-latency-benchmark-synthetic-smoke",
                integratedAvReportId: "m10-integrated-av-synthetic-smoke",
                videoTransportReportId: "m09-video-transport-run",
                performanceAuditReportId: "m12-apple-silicon-performance-synthetic-smoke"
            ),
            notes: "Synthetic M13 source-contract smoke; physical two-peer benchmark evidence is required for PASS."
        ))
    }

    public static func passCandidate() -> E2EBenchmarkReport {
        report(E2EBenchmarkSyntheticReportDraft(
            runMode: .measured,
            evidenceKind: .physicalTwoPeerRig,
            measured: true,
            physicalEvidence: true,
            verdict: .pass,
            durationSeconds: E2EBenchmarkReport.minimumPassDurationSeconds,
            hardware: physicalPassHardware(),
            componentReports: E2EBenchmarkComponentReports(
                audioBenchmarkReportId: "measured-audio-direct-pass",
                integratedAvReportId: "measured-integrated-av-pass",
                videoTransportReportId: "measured-video-transport-pass",
                performanceAuditReportId: "measured-performance-audit-pass"
            ),
            notes: "Measured pass candidate for M13 validator behavior."
        ))
    }
}

private struct E2EBenchmarkSyntheticReportDraft {
    let runMode: ReportRunMode
    let evidenceKind: E2EBenchmarkEvidenceKind
    let measured: Bool
    let physicalEvidence: Bool
    let verdict: MeasurementVerdict
    let durationSeconds: Double
    let hardware: E2EBenchmarkHardwareIdentity
    let componentReports: E2EBenchmarkComponentReports
    let notes: String
}

private func report(_ draft: E2EBenchmarkSyntheticReportDraft) -> E2EBenchmarkReport {
    E2EBenchmarkReport(
        id: draft.runMode == .measured
            ? "m13-e2e-integrated-benchmark-pass-candidate"
            : "m13-e2e-integrated-benchmark-synthetic-smoke",
        title: "M13 E2E integrated benchmark",
        capturedAt: draft.runMode == .measured
            ? "2026-05-04T12:00:00Z"
            : "2026-05-04T00:00:00Z",
        durationSeconds: draft.durationSeconds,
        runMode: draft.runMode,
        evidenceKind: draft.evidenceKind,
        hardware: draft.hardware,
        componentReports: draft.componentReports,
        profiles: profileRuns(
            measured: draft.measured,
            physicalEvidence: draft.physicalEvidence,
            verdict: draft.verdict
        ),
        impairments: impairmentRuns(measured: draft.measured, verdict: draft.verdict),
        recovery: E2EBenchmarkRecoveryMetrics(
            reconnectEvents: 1,
            reconnectP99Microseconds: 120_000,
            cleanShutdownObserved: true,
            leakedRealtimeCallbacksAfterShutdown: 0,
            recoveryReportId: draft.measured ? "measured-reconnect-pass" : "m13-reconnect-required",
            shutdownReportId: draft.measured ? "measured-shutdown-pass" : "m13-shutdown-required"
        ),
        thresholds: E2EBenchmarkThresholds(
            methodologyDocument: "docs/benchmark-e2e-av.md",
            packetLossMaxPercent: 0,
            cpuP99MaxPercent: 80,
            audioP99DeltaFromBaselineToleranceMicroseconds: 50,
            audioUnderrunMaxCount: 0,
            droppedFrameMaxCount: 0
        ),
        verdict: draft.verdict,
        notes: draft.notes
    )
}

private func profileRuns(
    measured: Bool,
    physicalEvidence: Bool,
    verdict: MeasurementVerdict
) -> [E2EBenchmarkProfileRun] {
    [
        profileRun(
            .audioOnlyDirect,
            measured: measured,
            physicalEvidence: physicalEvidence,
            video: nil,
            verdict: verdict
        ),
        profileRun(
            .audioVideoDirect,
            measured: measured,
            physicalEvidence: physicalEvidence,
            video: videoMetrics(streamCount: 1),
            verdict: verdict
        ),
        profileRun(
            .audioMultiVideoDirect,
            measured: measured,
            physicalEvidence: physicalEvidence,
            video: videoMetrics(streamCount: 2),
            verdict: verdict
        ),
        profileRun(
            .wanStable,
            measured: measured,
            physicalEvidence: physicalEvidence,
            video: videoMetrics(streamCount: 1),
            verdict: verdict
        )
    ]
}

private func profileRun(
    _ profile: E2EBenchmarkProfile,
    measured: Bool,
    physicalEvidence: Bool,
    video: E2EBenchmarkVideoMetrics?,
    verdict: MeasurementVerdict
) -> E2EBenchmarkProfileRun {
    E2EBenchmarkProfileRun(
        profile: profile,
        reportId: measured ? "measured-\(profile.rawValue)-pass" : "m13-\(profile.rawValue)-required",
        measured: measured,
        physicalEvidence: physicalEvidence,
        audio: audioMetrics(delta: 0),
        video: video,
        network: networkMetrics(),
        resources: E2EBenchmarkResourceMetrics(
            cpuP99Percent: profile == .audioMultiVideoDirect ? 42 : 28,
            gpuP99Percent: video == nil ? 0 : 18,
            residentMemoryMegabytes: profile == .audioMultiVideoDirect ? 580 : 420,
            hotPathAllocationWarnings: 0
        ),
        verdict: verdict,
        notes: measured
            ? "Measured physical \(profile.rawValue) benchmark row."
            : "M13 \(profile.rawValue) physical two-peer evidence required before PASS."
    )
}

private func audioMetrics(delta: Double) -> E2EBenchmarkAudioMetrics {
    E2EBenchmarkAudioMetrics(
        sampleRateHertz: 48_000,
        channelCount: 64,
        framesPerBuffer: 32,
        callbackDuration: PerformanceCounterSummary(
            sampleCount: 600,
            p50Microseconds: SourceValidationMetrics.callback.p50Microseconds,
            p95Microseconds: SourceValidationMetrics.callback.p95Microseconds,
            p99Microseconds: SourceValidationMetrics.callback.p99Microseconds,
            maxMicroseconds: SourceValidationMetrics.callback.maxMicroseconds
        ),
        oneWayLatencyMicroseconds: SourceValidationMetrics.audioPacketAge.p99Microseconds,
        roundTripLatencyMicroseconds: SourceValidationMetrics.audioPacketAge.p99Microseconds * 2,
        jitter: packetAge(
            p50: SourceValidationMetrics.jitter.p50Microseconds,
            p95: SourceValidationMetrics.jitter.p95Microseconds,
            p99: SourceValidationMetrics.jitter.p99Microseconds,
            max: SourceValidationMetrics.jitter.maxMicroseconds
        ),
        underruns: 0,
        overruns: 0,
        configuredChannelCount: 64,
        hiddenBufferGrowthDetected: false,
        audioP99DeltaFromBaselineMicroseconds: delta
    )
}

private func videoMetrics(streamCount: Int) -> E2EBenchmarkVideoMetrics {
    E2EBenchmarkVideoMetrics(
        streamCount: streamCount,
        width: 1_280,
        height: 720,
        frameRate: 30,
        captureLatency: packetAge(
            p50: SourceValidationMetrics.videoFrameAge.p50Microseconds,
            p95: SourceValidationMetrics.videoFrameAge.p95Microseconds,
            p99: SourceValidationMetrics.videoFrameAge.p99Microseconds,
            max: SourceValidationMetrics.videoFrameAge.maxMicroseconds
        ),
        encodePacketizationLatency: PerformanceCounterSummary(
            sampleCount: 300,
            p50Microseconds: SourceValidationMetrics.videoPacketizationCounter.p50Microseconds,
            p95Microseconds: SourceValidationMetrics.videoPacketizationCounter.p95Microseconds,
            p99Microseconds: SourceValidationMetrics.videoPacketizationCounter.p99Microseconds,
            maxMicroseconds: SourceValidationMetrics.videoPacketizationCounter.maxMicroseconds
        ),
        receiveRenderLatency: packetAge(
            p50: SourceValidationMetrics.videoFrameAge.p50Microseconds,
            p95: SourceValidationMetrics.videoFrameAge.p95Microseconds,
            p99: SourceValidationMetrics.videoFrameAge.p99Microseconds,
            max: SourceValidationMetrics.videoFrameAge.maxMicroseconds
        ),
        droppedFrames: 0,
        blackmagicCaptureReportId: "m08-blackmagic-capture-pass",
        renderOutputReportId: "m09-render-output-pass"
    )
}

private func networkMetrics() -> E2EBenchmarkNetworkMetrics {
    E2EBenchmarkNetworkMetrics(
        throughputMegabitsPerSecond: 940,
        lostPackets: 0,
        latePackets: 0,
        reorderedPackets: 0,
        duplicatePackets: 0,
        packetLossPercent: 0,
        jitter: packetAge(
            p50: SourceValidationMetrics.jitter.p50Microseconds,
            p95: SourceValidationMetrics.jitter.p95Microseconds,
            p99: SourceValidationMetrics.jitter.p99Microseconds,
            max: SourceValidationMetrics.jitter.maxMicroseconds
        ),
        dscpClassification: .honored
    )
}

private func impairmentRuns(measured: Bool, verdict: MeasurementVerdict) -> [E2EBenchmarkImpairmentRun] {
    E2EBenchmarkImpairmentProfile.allCases.map { profile in
        E2EBenchmarkImpairmentRun(
            profile: profile,
            reportId: measured
                ? "measured-\(profile.rawValue)-impairment-pass"
                : "m13-\(profile.rawValue)-impairment-required",
            measured: measured,
            injectedPackets: 120,
            observedPackets: 120,
            recoveredPackets: 120,
            audioUnderruns: 0,
            videoDroppedFrames: profile == .loss ? 2 : 0,
            verdict: verdict,
            notes: measured
                ? "Measured impairment response for \(profile.rawValue)."
                : "M13 \(profile.rawValue) impairment counters required before PASS."
        )
    }
}

private func syntheticHardware() -> E2EBenchmarkHardwareIdentity {
    E2EBenchmarkHardwareIdentity(
        sourcePeer: syntheticPeer("source"),
        receiverPeer: syntheticPeer("receiver"),
        rmeMadiIdentity: "M13 source and receiver RME identity evidence required.",
        blackmagicIdentity: "M13 Blackmagic capture/output hardware identity evidence required.",
        routeLabel: "M13 direct route label evidence required.",
        networkTopology: "two-peer-direct-ip-required",
        packetCapturePoint: "M13 receiver packet-capture point evidence required.",
        clockAlignmentMethod: "M13 one-way clock-alignment method evidence required."
    )
}

private func syntheticPeer(_ role: String) -> E2EBenchmarkPeerIdentity {
    E2EBenchmarkPeerIdentity(
        peerId: "m13-\(role)-peer-required",
        machineModel: "M13 \(role) Mac model evidence required.",
        chipName: "Apple Silicon required",
        osVersion: "M13 \(role) macOS version evidence required.",
        audioInterface: "M13 \(role) RME audio interface evidence required.",
        audioDeviceUID: "M13 \(role) Core Audio UID evidence required.",
        videoDevice: "M13 \(role) Blackmagic video path evidence required.",
        networkInterface: "M13 \(role) network interface evidence required."
    )
}

private func physicalPassHardware() -> E2EBenchmarkHardwareIdentity {
    E2EBenchmarkHardwareIdentity(
        sourcePeer: physicalPeer("source", machine: "Mac16,12"),
        receiverPeer: physicalPeer("receiver", machine: "Mac15,13"),
        rmeMadiIdentity: "RME MADIface XT source and receiver pair",
        blackmagicIdentity: "Blackmagic UltraStudio and ATEM Television Studio pair",
        routeLabel: "direct-wired-p2p",
        networkTopology: "two Apple Silicon peers on direct manual-IP Ethernet",
        packetCapturePoint: "receiver ingress mirrored on en6",
        clockAlignmentMethod: "PTP-aligned clocks with round-trip sanity check"
    )
}

private func physicalPeer(_ role: String, machine: String) -> E2EBenchmarkPeerIdentity {
    E2EBenchmarkPeerIdentity(
        peerId: "m13-\(role)-peer-pass",
        machineModel: machine,
        chipName: "Apple M4",
        osVersion: "macOS 15.5",
        audioInterface: "RME MADIface XT",
        audioDeviceUID: "rme-\(role)-madi-uid",
        videoDevice: "Blackmagic UltraStudio 4K Mini",
        networkInterface: "en6"
    )
}

private func packetAge(p50: Double, p95: Double, p99: Double, max: Double) -> UdpPcmPacketAgeMetrics {
    UdpPcmPacketAgeMetrics(
        p50Microseconds: p50,
        p95Microseconds: p95,
        p99Microseconds: p99,
        maxMicroseconds: max
    )
}
