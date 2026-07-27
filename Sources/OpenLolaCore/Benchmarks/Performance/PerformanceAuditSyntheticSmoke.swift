// Produces fixed hot-path, copy, counter, and Apple-silicon audit samples for source validation without physical-run provenance.
import Foundation

/// Creates deterministic synthetic performance audit evidence that exercises report validation without claiming physical measurement.
public enum PerformanceAuditSyntheticSmoke {
    public static func run() throws -> PerformanceAuditReport {
        let realtime = try RealtimeAudioEngineSyntheticSmoke.run()
        let transmit = try MadiTransmitSyntheticSmoke.run()
        let receive = try MadiReceiveSyntheticSmoke.run()
        let video = try VideoTransportSyntheticSmoke.run()
        let counters = syntheticCounters(
            realtime: realtime,
            transmit: transmit,
            receive: receive,
            video: video
        )
        return PerformanceAuditReport(
            identity: PerformanceAuditReport.Identity(
                id: "m12-apple-silicon-performance-synthetic-smoke",
                title: "M12 Apple Silicon performance source-validation smoke",
                capturedAt: "2026-05-04T00:00:00Z",
                runMode: .synthetic,
                evidenceKind: .synthetic
            ),
            context: PerformanceAuditReport.Context(
                hardware: syntheticPerformanceHardware(),
                process: syntheticPerformanceProcessContext(),
                appleSiliconPolicy: syntheticAppleSiliconPolicy(),
                sourceReportIDs: [realtime.id, transmit.id, receive.id, video.id]
            ),
            audit: PerformanceAuditReport.Audit(
                hotPaths: syntheticHotPaths(),
                copyEntries: syntheticCopyAudit(counters: counters),
                workerAssignments: syntheticWorkers(),
                counters: counters,
                accelerationDecisions: syntheticAccelerationDecisions()
            ),
            profileReports: syntheticProfileReports(counters: counters),
            outcome: PerformanceAuditReport.Outcome(
                verdict: .partial,
                notes: "Source-validation smoke only; physical Apple Silicon, RME, route, " +
                    "Metal, and VideoToolbox measurements remain open."
            )
        )
    }
}

private func syntheticCounters(
    realtime: RealtimeAudioEngineReport,
    transmit: MadiTransmitSyntheticReport,
    receive: MadiReceiveSyntheticReport,
    video: VideoTransportReport
) -> PerformanceAuditCounters {
    let videoCounters = video.performanceCounters
    return PerformanceAuditCounters(
        callbackDuration: .fromCallback(realtime.runtime.callback),
        packetizationDuration: videoCounters?.packetizationDuration
            ?? .fromSamples(transmit.measurements.map(\.packetizationMicroseconds)),
        depacketizationDuration: videoCounters?.reassemblyDuration
            ?? .fromSamples(receive.measurements.map(\.depacketizationMicroseconds)),
        videoFrameAge: video.frameAge,
        ringOccupancyBlocks: realtime.runtime.handoff.maximumBufferedBlocks,
        ringDropCount: realtime.runtime.handoff.droppedInputBlocks
            + realtime.runtime.handoff.droppedNetworkBlocks,
        queueDepthPackets: realtime.runtime.handoff.maximumPlayoutQueueDepthBlocks,
        videoQueueDepthFrames: video.receiver.observedQueueDepth,
        audioDropCount: realtime.runtime.handoff.outputUnderrunBlocks,
        allocationWarningCount: realtime.runtime.handoff.allocationWarnings,
        memoryBandwidthMegabytesPerSecond: syntheticMemoryBandwidth(
            transmit: transmit,
            receive: receive
        )
    )
}

private func syntheticPerformanceHardware() -> HardwareIdentity {
    HardwareIdentity(
        referenceMac: "synthetic-apple-silicon-host",
        audioInterface: "synthetic-audio-device",
        osVersion: "synthetic-macOS",
        driverVersion: "synthetic-driver"
    )
}

private func syntheticPerformanceProcessContext() -> PerformanceProcessContext {
    PerformanceProcessContext(
        machineModel: "synthetic-host",
        chipName: "Apple Silicon synthetic",
        osVersion: "synthetic-macOS",
        processName: "open-lola",
        thermalState: "notMeasured",
        powerMode: "notMeasured"
    )
}

private func syntheticAppleSiliconPolicy() -> AppleSiliconRuntimePolicy {
    AppleSiliconRuntimePolicy(
        nativeArm64Process: true,
        rosettaTranslated: false,
        usesQoSInsteadOfCorePinning: true,
        keepsAudioOnDeviceCallback: true,
        usesUnifiedMemoryLowCopyVideoPath: true,
        avoidsCPUGPUReadbackRoundTrip: true,
        promotesAccelerationOnlyAfterRawBaseline: true,
 notes: "Source contract uses native arm64, Dispatch QoS, device-owned audio callbacks, " +
 "and low-copy video boundaries; physical Apple Silicon proof remains open."
    )
}

private func syntheticMemoryBandwidth(
    transmit: MadiTransmitSyntheticReport,
    receive: MadiReceiveSyntheticReport
) -> Double {
    let transmitBytes = transmit.measurements.map(\.payloadByteCount).reduce(0, +)
    let receiveBytes = receive.measurements.map(\.outputPayloadByteCount).reduce(0, +)
    return Double(transmitBytes + receiveBytes) / (1024 * 1024)
}

private func syntheticHotPaths() -> [PerformanceHotPathAudit] {
    PerformanceHotPathSurface.allCases.map { surface in
        PerformanceHotPathAudit(
            surface: surface,
            allocationWarnings: 0,
            blockingIOWarnings: 0,
            loggingWarnings: 0,
            lockWarnings: 0,
            usesMonotonicClock: true,
            dynamicConfigurationAfterStart: false,
            notes: "Synthetic source audit for \(surface.rawValue)."
        )
    }
}

private func syntheticCopyAudit(counters: PerformanceAuditCounters) -> [PerformanceCopyAuditEntry] {
    [
        PerformanceCopyAuditEntry(
            id: "audio-callback-preallocated-slab-copy",
            surface: .audioCallback,
            kind: .preallocatedSlabCopy,
            byteCountPerUnit: 32 * 2 * 2,
            copiesPerUnit: 1,
            avoidable: false,
            removed: false,
            measuredCostMicroseconds: nil,
            documentation: "Input copy uses deadline storage; no format conversion in callback."
        ),
        PerformanceCopyAuditEntry(
            id: "audio-packet-boundary-copy",
            surface: .audioPacketization,
            kind: .packetBoundaryCopy,
            byteCountPerUnit: 32 * 2 * 2,
            copiesPerUnit: 1,
            avoidable: false,
            removed: false,
            measuredCostMicroseconds: counters.packetizationDuration.p99Microseconds,
            documentation: "Packet payload copy is outside the audio callback and tied to the packetization counter."
        ),
        PerformanceCopyAuditEntry(
            id: "video-cvpixelbuffer-reference",
            surface: .videoCapture,
            kind: .pixelBufferReference,
            byteCountPerUnit: 0,
            copiesPerUnit: 0,
            avoidable: false,
            removed: false,
 measuredCostMicroseconds: nil,
 documentation: "AVFoundation boundary keeps frame age visible; " +
 "production CVPixelBuffer/IOSurface evidence remains physical."
        ),
        PerformanceCopyAuditEntry(
            id: "video-raw-fragment-copy",
            surface: .videoPacketization,
            kind: .encodedFragmentCopy,
            byteCountPerUnit: 1_280 * 720 * 3,
            copiesPerUnit: 1,
            avoidable: false,
            removed: false,
            measuredCostMicroseconds: counters.packetizationDuration.p99Microseconds,
            documentation: "Synthetic raw fragment copy is documented as the baseline " +
                "before Metal or VideoToolbox promotion."
        )
    ]
}

private func syntheticWorkers() -> [PerformanceWorkerAssignment] {
    [
        performanceWorker(.audioCallback, "device-owned Core Audio callback", .realtimeDeviceOwned, false),
        performanceWorker(.audioNetworkTx, "open-lola.audio-network-tx", .userInteractive, true),
        performanceWorker(.audioNetworkRx, "open-lola.audio-network-rx", .userInteractive, true),
        performanceWorker(.videoCapture, "open-lola.video-capture.avfoundation", .userInitiated, true),
        performanceWorker(.videoEncodePacketize, "open-lola.video-encode-packetize", .userInitiated, true),
        performanceWorker(.videoReceiveRender, "open-lola.video-rx-render", .userInitiated, true),
        performanceWorker(.controlSession, "open-lola.control-session", .utility, true),
        performanceWorker(.observability, "open-lola.metrics", .utility, true),
        performanceWorker(.ui, "main", .main, true)
    ]
}

private func performanceWorker(
    _ role: PerformanceWorkerRole,
    _ queueLabel: String,
    _ qos: PerformanceWorkerQoS,
    _ isolated: Bool
) -> PerformanceWorkerAssignment {
    PerformanceWorkerAssignment(
        role: role,
        queueLabel: queueLabel,
        qos: qos,
        isolatedFromAudioCallback: isolated,
        canBlockAudioCriticalQueue: false,
        notes: "Synthetic worker assignment for \(role.rawValue)."
    )
}

private func syntheticAccelerationDecisions() -> [PerformanceAccelerationDecision] {
    [
        PerformanceAccelerationDecision(
            option: .rawLowCopyBaseline,
            benchmarked: true,
            rawBaselineReportId: "m12-raw-low-copy-synthetic-baseline",
            measuredCostMicroseconds: 0,
            verdict: .partial,
            notes: "Raw/low-copy synthetic baseline exists; physical baseline remains open."
        ),
        PerformanceAccelerationDecision(
            option: .metal,
            benchmarked: false,
            rawBaselineReportId: "m12-raw-low-copy-synthetic-baseline",
            measuredCostMicroseconds: nil,
            verdict: .partial,
            notes: "Metal promotion is blocked until raw physical baseline exists."
        ),
        PerformanceAccelerationDecision(
            option: .videoToolbox,
            benchmarked: false,
            rawBaselineReportId: "m12-raw-low-copy-synthetic-baseline",
            measuredCostMicroseconds: nil,
            verdict: .partial,
            notes: "VideoToolbox promotion is blocked until raw physical baseline exists."
        )
    ]
}

private func syntheticProfileReports(
    counters: PerformanceAuditCounters
) -> [PerformanceProfileReportReference] {
    [
        performanceProfile(.safe, .directAudioFirst, .safeLowLatency, counters),
        performanceProfile(.ultra, .balancedAV, .ultraLowLatency16, counters),
        performanceProfile(.experimental, .multiVideoPerformance, .extremeLowLatency8, counters)
    ]
}

private func performanceProfile(
    _ tier: PerformanceSettingsTier,
    _ sessionProfile: SessionLatencyProfile,
    _ latencyProfile: LatencyProfile,
    _ counters: PerformanceAuditCounters
) -> PerformanceProfileReportReference {
    PerformanceProfileReportReference(
        settingsTier: tier,
        sessionProfile: sessionProfile,
        latencyProfile: latencyProfile,
        reportId: "m12-\(tier.rawValue)-\(sessionProfile.rawValue)-synthetic",
        counters: counters,
        measured: false,
        physicalEvidence: false,
        verdict: .partial,
        notes: "Synthetic \(tier.rawValue) profile; physical evidence remains open."
    )
}
