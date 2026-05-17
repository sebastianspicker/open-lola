import Foundation

public enum LatencyBenchmarkSyntheticSmoke {
    public static func run() throws -> LatencyBenchmarkReport {
        let rxPolicy = try RxBufferPolicy.direct(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            targetPackets: 1
        )
        let impairment = try RxImpairmentSimulator.run(
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
        return LatencyBenchmarkReport(
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
            mediaMode: LatencyBenchmarkMediaMode(
                domain: .audio,
                audio: AudioMode(
                    sampleRateHertz: 48_000,
                    framesPerBuffer: 32,
                    channelCount: 2,
                    sampleFormat: "int16LittleEndian"
                ),
                video: nil,
                lighting: nil
            ),
            timing: LatencyBenchmarkTimingMetrics(
                oneWayEstimateMicroseconds: 2_400,
                roundTripMicroseconds: 4_800,
                jitter: LatencyJitterMetrics(
                    p50Microseconds: 80,
                    p95Microseconds: 160,
                    p99Microseconds: 240,
                    maxMicroseconds: 320
                )
            ),
            loss: LatencyBenchmarkLossMetrics(lostPackets: 0, latePackets: 1, lossPercent: 0),
            faults: LatencyBenchmarkFaultMetrics(
                underruns: 1,
                overruns: 0,
                missedDeadlines: 1,
                droppedFrames: 0
            ),
            resources: LatencyBenchmarkResourceMetrics(
                cpuP50Percent: 8,
                cpuP95Percent: 16,
                cpuP99Percent: 22,
                cpuMaxPercent: 28,
                residentMemoryMegabytes: 96,
                allocationWarnings: [
                    LatencyBenchmarkWarning(
                        field: "audio.callback",
                        message: "synthetic smoke records the warning field only"
                    ),
                ],
                threadWarnings: [
                    LatencyBenchmarkWarning(
                        field: "audio.callback",
                        message: "synthetic smoke is not a realtime thread proof"
                    ),
                ]
            ),
            thresholds: LatencyBenchmarkThresholds(
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
            ),
            components: [
                LatencyBudgetComponentMeasurement(
                    id: "audio-interface-buffer",
                    label: "Audio interface buffer",
                    criticality: .criticalPath,
                    budgetTargetMicroseconds: 667,
                    measuredMicroseconds: 667,
                    source: "docs/latency-budget.md"
                ),
                LatencyBudgetComponentMeasurement(
                    id: "callback-handoff",
                    label: "Callback handoff",
                    criticality: .criticalPath,
                    budgetTargetMicroseconds: 100,
                    measuredMicroseconds: 80,
                    source: "docs/latency-budget.md"
                ),
                LatencyBudgetComponentMeasurement(
                    id: "video-capture",
                    label: "Video capture",
                    criticality: .nearCriticalPath,
                    budgetTargetMicroseconds: nil,
                    measuredMicroseconds: nil,
                    source: "docs/latency-budget.md"
                ),
                LatencyBudgetComponentMeasurement(
                    id: "debug-report-writing",
                    label: "Debug report writing",
                    criticality: .debugOnly,
                    budgetTargetMicroseconds: nil,
                    measuredMicroseconds: nil,
                    source: "docs/latency-budget.md"
                ),
            ],
            rxBufferImpact: RxBufferBenchmarkImpact(
                profile: rxPolicy,
                targetFramesOverTime: [rxPolicy.targetFrames],
                targetChangeEvents: [],
                impairmentSummary: impairment.summary
            ),
            verdict: .partial,
            notes: "Source-validation smoke only; cannot be used as physical latency evidence."
        )
    }
}
