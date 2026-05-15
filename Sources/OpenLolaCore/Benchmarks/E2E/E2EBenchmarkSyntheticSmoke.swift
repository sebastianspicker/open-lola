import Foundation

public enum E2EBenchmarkSyntheticSmoke {
    public static func run() throws -> E2EBenchmarkReport {
        report(
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
        )
    }

    public static func passCandidate() -> E2EBenchmarkReport {
        report(
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
        )
    }
}

private func report(
    runMode: E2EBenchmarkRunMode,
    evidenceKind: E2EBenchmarkEvidenceKind,
    measured: Bool,
    physicalEvidence: Bool,
    verdict: MeasurementVerdict,
    durationSeconds: Double,
    hardware: E2EBenchmarkHardwareIdentity,
    componentReports: E2EBenchmarkComponentReports,
    notes: String
) -> E2EBenchmarkReport {
    E2EBenchmarkReport(
        id: runMode == .measured
            ? "m13-e2e-integrated-benchmark-pass-candidate"
            : "m13-e2e-integrated-benchmark-synthetic-smoke",
        title: "M13 E2E integrated benchmark",
        capturedAt: runMode == .measured
            ? "2026-05-04T12:00:00Z"
            : "2026-05-04T00:00:00Z",
        durationSeconds: durationSeconds,
        runMode: runMode,
        evidenceKind: evidenceKind,
        hardware: hardware,
        componentReports: componentReports,
        profiles: profileRuns(measured: measured, physicalEvidence: physicalEvidence, verdict: verdict),
        impairments: impairmentRuns(measured: measured, verdict: verdict),
        recovery: E2EBenchmarkRecoveryMetrics(
            reconnectEvents: 1,
            reconnectP99Microseconds: 120_000,
            cleanShutdownObserved: true,
            leakedRealtimeCallbacksAfterShutdown: 0,
            recoveryReportId: measured ? "measured-reconnect-pass" : "m13-reconnect-required",
            shutdownReportId: measured ? "measured-shutdown-pass" : "m13-shutdown-required"
        ),
        thresholds: E2EBenchmarkThresholds(
            methodologyDocument: "docs/benchmarks/e2e-av-benchmark-methodology.md",
            packetLossMaxPercent: 0,
            cpuP99MaxPercent: 80,
            audioP99DeltaFromBaselineToleranceMicroseconds: 50,
            audioUnderrunMaxCount: 0,
            droppedFrameMaxCount: 0
        ),
        verdict: verdict,
        notes: notes
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
        ),
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
            : "TODO(human): [M13 \(profile.rawValue)] -> Replace synthetic row with physical two-peer evidence -> [lab / venue / defer]"
    )
}

private func audioMetrics(delta: Double) -> E2EBenchmarkAudioMetrics {
    E2EBenchmarkAudioMetrics(
        sampleRateHertz: 48_000,
        channelCount: 64,
        framesPerBuffer: 32,
        callbackDuration: PerformanceCounterSummary(
            sampleCount: 600,
            p50Microseconds: 70,
            p95Microseconds: 90,
            p99Microseconds: 110,
            maxMicroseconds: 140
        ),
        oneWayLatencyMicroseconds: 4_200,
        roundTripLatencyMicroseconds: 8_400,
        jitter: packetAge(p50: 70, p95: 120, p99: 160, max: 220),
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
        captureLatency: packetAge(p50: 1_000, p95: 1_500, p99: 1_800, max: 2_200),
        encodePacketizationLatency: PerformanceCounterSummary(
            sampleCount: 300,
            p50Microseconds: 500,
            p95Microseconds: 700,
            p99Microseconds: 900,
            maxMicroseconds: 1_200
        ),
        receiveRenderLatency: packetAge(p50: 1_200, p95: 1_700, p99: 2_100, max: 2_500),
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
        jitter: packetAge(p50: 60, p95: 110, p99: 150, max: 210),
        dscpClassification: .honored
    )
}

private func impairmentRuns(measured: Bool, verdict: MeasurementVerdict) -> [E2EBenchmarkImpairmentRun] {
    E2EBenchmarkImpairmentProfile.allCases.map { profile in
        E2EBenchmarkImpairmentRun(
            profile: profile,
            reportId: measured ? "measured-\(profile.rawValue)-impairment-pass" : "m13-\(profile.rawValue)-impairment-required",
            measured: measured,
            injectedPackets: 120,
            observedPackets: 120,
            recoveredPackets: 120,
            audioUnderruns: 0,
            videoDroppedFrames: profile == .loss ? 2 : 0,
            verdict: verdict,
            notes: measured
                ? "Measured impairment response for \(profile.rawValue)."
                : "TODO(human): [M13 \(profile.rawValue)] -> Run impairment profile and attach counters -> [loss / jitter / reorder / duplicate / late]"
        )
    }
}

private func syntheticHardware() -> E2EBenchmarkHardwareIdentity {
    E2EBenchmarkHardwareIdentity(
        sourcePeer: syntheticPeer("source"),
        receiverPeer: syntheticPeer("receiver"),
        rmeMadiIdentity: "TODO(human): [M13 RME MADI] -> Record source and receiver RME identity -> [device inventory]",
        blackmagicIdentity: "TODO(human): [M13 Blackmagic] -> Record capture/output hardware identity -> [ATEM / DeckLink / UltraStudio]",
        routeLabel: "TODO(human): [M13 route] -> Record direct route label -> [direct cable / switch]",
        networkTopology: "two-peer-direct-ip-required",
        packetCapturePoint: "TODO(human): [M13 packet capture] -> Record capture point -> [receiver ingress / tap]",
        clockAlignmentMethod: "TODO(human): [M13 clock alignment] -> Record one-way timing method -> [PTP / loopback / external]"
    )
}

private func syntheticPeer(_ role: String) -> E2EBenchmarkPeerIdentity {
    E2EBenchmarkPeerIdentity(
        peerId: "m13-\(role)-peer-required",
        machineModel: "TODO(human): [M13 \(role) Mac] -> Record machine model -> [system_profiler]",
        chipName: "Apple Silicon required",
        osVersion: "TODO(human): [M13 \(role) macOS] -> Record macOS version -> [sw_vers]",
        audioInterface: "TODO(human): [M13 \(role) audio] -> Record RME interface -> [Core Audio inventory]",
        audioDeviceUID: "TODO(human): [M13 \(role) audio UID] -> Record Core Audio UID -> [device inventory]",
        videoDevice: "TODO(human): [M13 \(role) video] -> Record Blackmagic path -> [AVFoundation / Desktop Video]",
        networkInterface: "TODO(human): [M13 \(role) network] -> Record interface -> [ifconfig]"
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
