// Runs impairment samples for RX buffer candidates and compares their latency and recovery metrics through one benchmark entry point.
import Foundation

/// Reports `invalidPacketCount` failures that stop invalid timing and drift control work before it reaches a live path.
public enum RxBufferBenchmarkRunnerError: Error, Equatable, Sendable {
    case invalidPacketCount(Int)
}

/// Executes a bounded receive-buffer benchmark and returns accountable timing-control evidence.
public enum RxBufferBenchmarkRunner {
    public static let defaultPacketCount = 500

    public static func runLocal(packetCount: Int = defaultPacketCount) throws -> RxBufferBenchmarkReport {
        guard packetCount > 0 else {
            throw RxBufferBenchmarkRunnerError.invalidPacketCount(packetCount)
        }
        let framesPerPacket = 32
        let sampleRateHertz = 48_000
        let rows = try benchmarkRows(
            packetCount: packetCount,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: sampleRateHertz
        )
        let report = localReport(
            rows: rows,
            framesPerPacket: framesPerPacket,
            sampleRateHertz: sampleRateHertz
        )
        try report.validate()
        return report
    }

    private static func localReport(
        rows: [RxBufferBenchmarkRow],
        framesPerPacket: Int,
        sampleRateHertz: Int
    ) -> RxBufferBenchmarkReport {
        RxBufferBenchmarkReport(
            identity: localReportIdentity(),
            environment: localReportEnvironment(
                framesPerPacket: framesPerPacket,
                sampleRateHertz: sampleRateHertz
            ),
            outcome: localReportOutcome(rows: rows)
        )
    }

    private static func localReportIdentity() -> RxBufferBenchmarkReport.Identity {
        RxBufferBenchmarkReport.Identity(
            id: "m07-rx-buffer-local-benchmark-\(Int(Date().timeIntervalSince1970))",
            title: "M07 RX buffer local benchmark",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            evidenceKind: .localRuntime
        )
    }

    private static func localReportEnvironment(
        framesPerPacket: Int,
        sampleRateHertz: Int
    ) -> RxBufferBenchmarkReport.Environment {
        let hardware = HardwareIdentity(
            referenceMac: "local-mac",
            audioInterface: "local-runtime-no-rme",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            driverVersion: "not-measured"
        )
        let route = RouteIdentity(
            label: "local-impairment-runtime",
            topology: "single-process-rx-policy-benchmark"
        )
        let audioMode = AudioMode(
            sampleRateHertz: sampleRateHertz,
            framesPerBuffer: framesPerPacket,
            channelCount: 2,
            sampleFormat: "float32LittleEndian"
        )
        return RxBufferBenchmarkReport.Environment(
            hardware: hardware,
            route: route,
            audioMode: audioMode
        )
    }

    private static func localReportOutcome(
        rows: [RxBufferBenchmarkRow]
    ) -> RxBufferBenchmarkReport.Outcome {
        RxBufferBenchmarkReport.Outcome(
            rows: rows,
            verdict: .partial,
            notes: "Local runtime benchmark covers Direct, Small, Adaptive, and Stable/WAN RX " +
                "buffer behavior under deterministic impairment. Physical PASS still requires " +
                "same-route two-Mac RME measurements."
        )
    }

    private static func benchmarkRows(
        packetCount: Int,
        framesPerPacket: Int,
        sampleRateHertz: Int
    ) throws -> [RxBufferBenchmarkRow] {
        try [
            row(
                policy: .direct(framesPerPacket: framesPerPacket, sampleRateHertz: sampleRateHertz),
                packetCount: packetCount,
                seed: 11
            ),
            row(
                policy: .small(framesPerPacket: framesPerPacket, sampleRateHertz: sampleRateHertz),
                packetCount: packetCount,
                seed: 13
            ),
            row(
                policy: .adaptive(framesPerPacket: framesPerPacket, sampleRateHertz: sampleRateHertz),
                packetCount: packetCount,
                seed: 17
            ),
            row(
                policy: .stableWan(framesPerPacket: framesPerPacket, sampleRateHertz: sampleRateHertz),
                packetCount: packetCount,
                seed: 19
            )
        ]
    }

    private static func row(
        policy: RxBufferPolicy,
        packetCount: Int,
        seed: UInt64
    ) throws -> RxBufferBenchmarkRow {
        let result = try RxImpairmentSimulator.run(
            profile: impairmentProfile(policy: policy, packetCount: packetCount, seed: seed)
        )
        let impact = try impact(policy: policy, result: result)
        let latePackets = latePacketCount(policy: policy, result: result)
        let lostPackets = result.summary.wholePacketLosses + result.summary.fragmentLosses
        let underruns = max(0, latePackets + lostPackets - policy.targetPackets)
        let oneWay = policy.latencyCostMicroseconds + result.summary.packetAge.p99Microseconds
        let timing = LatencyBenchmarkTimingMetrics(
            oneWayEstimateMicroseconds: oneWay,
            roundTripMicroseconds: oneWay * 2,
            jitter: result.summary.jitter
        )
        let loss = LatencyBenchmarkLossMetrics(
            lostPackets: lostPackets,
            latePackets: latePackets,
            lossPercent: Double(lostPackets) / Double(result.summary.sentPackets) * 100
        )
        let faults = LatencyBenchmarkFaultMetrics(
            underruns: underruns,
            overruns: 0,
            missedDeadlines: latePackets,
            droppedFrames: 0
        )
        let measurements = RxBufferBenchmarkRow.Measurements(
            benchmark: impact,
            timing: timing,
            loss: loss,
            faults: faults
        )
        let evidence = RxBufferBenchmarkRow.Evidence(
            physicalEvidence: false,
            fastestPassEligible: policy.fastestAudioPassEligible,
            notes: "\(policy.profile.rawValue) RX buffer row from deterministic local runtime impairment."
        )
        return RxBufferBenchmarkRow(
            profile: policy.profile,
            measurements: measurements,
            evidence: evidence
        )
    }

    private static func impairmentProfile(
        policy: RxBufferPolicy,
        packetCount: Int,
        seed: UInt64
    ) -> RxImpairmentProfile {
        RxImpairmentProfile(
            transport: RxImpairmentProfile.Transport(
                seed: seed,
                packetCount: packetCount,
                framesPerPacket: policy.framesPerPacket,
                sampleRateHertz: policy.sampleRateHertz
            ),
            transit: RxImpairmentProfile.Transit(
                baseMicroseconds: 120,
                jitterAmplitudeMicroseconds: 420
            ),
            packetFaults: RxImpairmentProfile.PacketFaults(
                lossEveryNthPacket: 23,
                duplicateEveryNthPacket: 11,
                reorderEveryNthPacket: 7,
                lateEveryNthPacket: 13
            ),
            fragmentation: RxImpairmentProfile.Fragmentation(count: 2, lossEveryNthPacket: 29)
        )
    }

    private static func impact(
        policy: RxBufferPolicy,
        result: RxImpairmentSimulationResult
    ) throws -> RxBufferBenchmarkImpact {
        guard policy.profile == .adaptive else {
            return RxBufferBenchmarkImpact(
                profile: policy,
                targetFramesOverTime: [policy.targetFrames],
                targetChangeEvents: [],
                impairmentSummary: result.summary
            )
        }
        var controller = try RxBufferAdaptiveController(
            policy: policy,
            increaseAfterSamples: 2,
            decreaseAfterSamples: 3,
            highJitterMicroseconds: 500,
            lowJitterMicroseconds: 180
        )
        var targets = [policy.targetFrames]
        for event in result.events where !event.duplicate {
            let late = event.packetAgeMicroseconds > controller.snapshot.latencyCostMicroseconds
            let decision = controller.observe(.sample(
                event.sequenceNumber,
                jitterP99Microseconds: result.summary.jitter.p99Microseconds,
                latePackets: late ? 1 : 0,
                underruns: late ? 1 : 0
            ))
            if targets.last != decision.targetFrames {
                targets.append(decision.targetFrames)
            }
        }
        return RxBufferBenchmarkImpact(
            profile: policy,
            targetFramesOverTime: targets,
            targetChangeEvents: controller.targetChangeEvents,
            impairmentSummary: result.summary
        )
    }

    private static func latePacketCount(
        policy: RxBufferPolicy,
        result: RxImpairmentSimulationResult
    ) -> Int {
        result.events.filter {
            !$0.duplicate && $0.packetAgeMicroseconds > policy.latencyCostMicroseconds
        }.count
    }
}
