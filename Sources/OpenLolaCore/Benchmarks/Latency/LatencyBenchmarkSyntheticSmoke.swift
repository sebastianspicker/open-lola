import Foundation

public enum LatencyBenchmarkSyntheticSmoke {
    public static func run() throws -> LatencyBenchmarkReport {
        let rxPolicy = try syntheticLatencyRxPolicy()
        let impairment = try syntheticLatencyImpairment()
        return syntheticLatencyReport(rxPolicy: rxPolicy, impairment: impairment)
    }

    private static func syntheticLatencyRxPolicy() throws -> RxBufferPolicy {
        try RxBufferPolicy.direct(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            targetPackets: 1
        )
    }

    private static func syntheticLatencyImpairment() throws -> RxImpairmentSimulationResult {
        try RxImpairmentSimulator.run(
            profile: RxImpairmentProfile(
                seed: 7,
                packetCount: 8,
                framesPerPacket: 32,
                sampleRateHertz: 48_000,
                baseTransitMicroseconds: 100,
                jitterAmplitudeMicroseconds: 40,
                lossEveryNthPacket: nil,
                duplicateEveryNthPacket: nil,
                reorderEveryNthPacket: nil,
                lateEveryNthPacket: 6,
                fragmentCount: 1,
                fragmentLossEveryNthPacket: nil
            )
        )
    }

    private static func syntheticLatencyReport(
        rxPolicy: RxBufferPolicy,
        impairment: RxImpairmentSimulationResult
    ) -> LatencyBenchmarkReport {
        LatencyBenchmarkReport(
            id: "m02-latency-benchmark-synthetic-smoke",
            title: "M02 latency benchmark source-validation smoke",
            capturedAt: "2026-05-03T00:00:00Z",
            category: .sourceValidation,
            runMode: .synthetic,
            evidenceKind: .synthetic,
            hardware: HardwareIdentity(
                referenceMac: "synthetic-mac",
                audioInterface: "synthetic-built-in-audio",
                osVersion: "not-measured",
                driverVersion: "not-measured"
            ),
            route: RouteIdentity(
                label: "synthetic-loopback-route",
                topology: "source-validation-only"
            ),
            mediaMode: syntheticLatencyMediaMode(),
            timing: syntheticLatencyTiming(impairment: impairment),
            loss: LatencyBenchmarkLossMetrics(lostPackets: 0, latePackets: 1, lossPercent: 0),
            faults: syntheticLatencyFaults(),
            resources: syntheticLatencyResources(),
            thresholds: syntheticLatencyThresholds(),
            components: syntheticLatencyComponents(),
            rxBufferImpact: syntheticLatencyRxImpact(rxPolicy: rxPolicy, impairment: impairment),
            verdict: .partial,
            notes: "Source-validation smoke only; cannot be used as physical latency evidence."
        )
    }

    private static func syntheticLatencyMediaMode() -> LatencyBenchmarkMediaMode {
        LatencyBenchmarkMediaMode(
            domain: .audio,
            audio: AudioMode(
                sampleRateHertz: 48_000,
                framesPerBuffer: 32,
                channelCount: 2,
                sampleFormat: "int16LittleEndian"
            ),
            video: nil,
            lighting: nil
        )
    }

    private static func syntheticLatencyTiming(
        impairment: RxImpairmentSimulationResult
    ) -> LatencyBenchmarkTimingMetrics {
        SourceValidationMetrics.timing(
            oneWayMicroseconds: impairment.summary.packetAge.p99Microseconds,
            jitter: impairment.summary.jitter
        )
    }

    private static func syntheticLatencyFaults() -> LatencyBenchmarkFaultMetrics {
        LatencyBenchmarkFaultMetrics(
            underruns: 1,
            overruns: 0,
            missedDeadlines: 1,
            droppedFrames: 0
        )
    }

    private static func syntheticLatencyResources() -> LatencyBenchmarkResourceMetrics {
        LatencyBenchmarkResourceMetrics(
            cpuP50Percent: SourceValidationMetrics.cpuP50Percent,
            cpuP95Percent: SourceValidationMetrics.cpuP95Percent,
            cpuP99Percent: SourceValidationMetrics.cpuP99Percent,
            cpuMaxPercent: SourceValidationMetrics.cpuMaxPercent,
            residentMemoryMegabytes: 96,
            allocationWarnings: [syntheticAllocationWarning],
            threadWarnings: [syntheticThreadWarning]
        )
    }

    private static var syntheticAllocationWarning: LatencyBenchmarkWarning {
        LatencyBenchmarkWarning(
            field: "audio.callback",
            message: "synthetic smoke records the warning field only"
        )
    }

    private static var syntheticThreadWarning: LatencyBenchmarkWarning {
        LatencyBenchmarkWarning(
            field: "audio.callback",
            message: "synthetic smoke is not a realtime thread proof"
        )
    }

    private static func syntheticLatencyThresholds() -> LatencyBenchmarkThresholds {
        LatencyBenchmarkThresholds(
            budgetDocument: "docs/latency-budget.md#audio-budget",
            oneWayTargetMicroseconds: 5_000,
            roundTripTargetMicroseconds: 10_000,
            jitterP99MaxMicroseconds: 1_000,
            packetLossMaxPercent: 0.1,
            cpuP99MaxPercent: 75,
            underrunMaxCount: 0,
            droppedFrameMaxCount: 0,
            allocationWarningMaxCount: 0,
            threadWarningMaxCount: 0
        )
    }

    private static func syntheticLatencyComponents() -> [LatencyBudgetComponentMeasurement] {
        [
            syntheticLatencyComponent(
                id: "audio-interface-buffer",
                label: "Audio interface buffer",
                criticality: .criticalPath,
                budgetTargetMicroseconds: 667,
                measuredMicroseconds: 667
            ),
            syntheticLatencyComponent(
                id: "callback-handoff",
                label: "Callback handoff",
                criticality: .criticalPath,
                budgetTargetMicroseconds: 100,
                measuredMicroseconds: 80
            ),
            syntheticLatencyComponent(
                id: "video-capture",
                label: "Video capture",
                criticality: .nearCriticalPath,
                budgetTargetMicroseconds: nil,
                measuredMicroseconds: nil
            ),
            syntheticLatencyComponent(
                id: "debug-report-writing",
                label: "Debug report writing",
                criticality: .debugOnly,
                budgetTargetMicroseconds: nil,
                measuredMicroseconds: nil
            )
        ]
    }

    private static func syntheticLatencyComponent(
        id: String,
        label: String,
        criticality: LatencyComponentCriticality,
        budgetTargetMicroseconds: Double?,
        measuredMicroseconds: Double?
    ) -> LatencyBudgetComponentMeasurement {
        LatencyBudgetComponentMeasurement(
            id: id,
            label: label,
            criticality: criticality,
            budgetTargetMicroseconds: budgetTargetMicroseconds,
            measuredMicroseconds: measuredMicroseconds,
            source: "docs/latency-budget.md"
        )
    }

    private static func syntheticLatencyRxImpact(
        rxPolicy: RxBufferPolicy,
        impairment: RxImpairmentSimulationResult
    ) -> RxBufferBenchmarkImpact {
        RxBufferBenchmarkImpact(
            profile: rxPolicy,
            targetFramesOverTime: [rxPolicy.targetFrames],
            targetChangeEvents: [],
            impairmentSummary: impairment.summary
        )
    }
}
