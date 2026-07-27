// Shared Latency benchmark report tests helpers keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaCore

func expectLatencyBenchmarkError(
    _ expected: LatencyBenchmarkValidationError,
    mutate: (inout LatencyBenchmarkReport) throws -> Void
) throws {
    var report = try latencyBenchmarkPassCandidate()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

func latencyBenchmarkPassCandidate() throws -> LatencyBenchmarkReport {
    try latencyBenchmarkPhysicalValidationCandidate(
        id: "m02-latency-benchmark-physical-pass-candidate",
        title: "M02 latency benchmark physical pass candidate",
        category: .directPeerToPeer
    )
}

func sessionProfileMetrics(
    profile: SessionLatencyProfile,
    rxBufferProfile: RxBufferProfile,
    fastestPassClaimed: Bool
) -> SessionLatencyProfileBenchmarkMetrics {
    let profiles = SessionLatencyProfileBenchmarkMetrics.Profiles(
        sessionProfile: profile,
        rxBufferProfile: rxBufferProfile
    )
    let routeAge = UdpPcmPacketAgeMetrics(
        p50Microseconds: 100,
        p95Microseconds: 150,
        p99Microseconds: 180,
        maxMicroseconds: 220
    )
    let packetAge = UdpPcmPacketAgeMetrics(
        p50Microseconds: 90,
        p95Microseconds: 140,
        p99Microseconds: 170,
        maxMicroseconds: 210
    )
    let jitter = LatencyJitterMetrics(
        p50Microseconds: 30,
        p95Microseconds: 70,
        p99Microseconds: 90,
        maxMicroseconds: 120
    )
    let timing = SessionLatencyProfileBenchmarkMetrics.Timing(
        callbackDurationP99Microseconds: 120,
        routeAge: routeAge,
        packetAge: packetAge,
        jitter: jitter
    )
    let runtime = SessionLatencyProfileBenchmarkMetrics.Runtime(
        underruns: 0,
        overruns: 0,
        fastestPassClaimed: fastestPassClaimed
    )
    let bufferCost = SessionLatencyProfileBenchmarkMetrics.BufferCost(
        frames: rxBufferProfile == .direct ? 32 : 64,
        packets: rxBufferProfile == .direct ? 1 : 2,
        microseconds: rxBufferProfile == .direct ? 666.6666666666666 : 1_333.3333333333333
    )
    return SessionLatencyProfileBenchmarkMetrics(
        profiles: profiles,
        timing: timing,
        runtime: runtime,
        bufferCost: bufferCost
    )
}

func lowBufferEvidence(
    profile: LatencyProfile,
    maxStableChannelCount: Int?,
    rmeDirectPhysicalEvidence: Bool = true,
    routeBenchmarkPassed: Bool = true,
    longRunDurationSeconds: Int? = 7_200,
    sampleFormat: UdpPcmSampleFormat = .int16LittleEndian
) throws -> LatencyProfileEvidence {
    try LatencyProfileEvidence(
        selection: LatencyProfileEvidence.Selection(
            profile: profile,
            explicitOptIn: true,
            experimentalOptIn: profile == .extremeLowLatency8,
            warningAcknowledged: profile == .extremeLowLatency8 || profile == .ultraLowLatency16
        ),
        physicalEvidence: LatencyProfileEvidence.PhysicalEvidence(
            rmeDirect: rmeDirectPhysicalEvidence,
            routeBenchmarkPassed: routeBenchmarkPassed,
            maxStableChannelCount: maxStableChannelCount,
            longRunDurationSeconds: longRunDurationSeconds
        ),
        recovery: LatencyProfileEvidence.Recovery(
            rollbackProfile: profile == .extremeLowLatency8 ? .ultraLowLatency16 : .safeLowLatency,
            budget: .calculate(
                profile: profile,
                sampleRateHertz: 48_000,
                channelCount: 2,
                sampleFormat: sampleFormat
            )
        )
    )
}

func loadLatencyBenchmarkFixture(named name: String) throws -> LatencyBenchmarkReport {
    let url = try latencyBenchmarkFixtureURL(named: name, directory: "valid")
    let report = try LatencyBenchmarkReport.decode(from: Data(contentsOf: url))
    try report.validate()
    return report
}

func loadInvalidLatencyBenchmarkFixture(named name: String) throws -> LatencyBenchmarkReport {
    let url = try latencyBenchmarkFixtureURL(named: name, directory: "invalid")
    let report = try LatencyBenchmarkReport.decode(from: Data(contentsOf: url))
    try report.validate()
    return report
}

func latencyBenchmarkFixtureURL(named name: String, directory: String) throws -> URL {
    let nestedURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "LatencyBenchmarkReports/\(directory)"
    )
    return try #require(nestedURL ?? Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    ))
}
