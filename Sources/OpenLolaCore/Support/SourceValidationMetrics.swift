import Foundation

enum SourceValidationMetrics {
    static let cpuP50Percent: Double = 3
    static let cpuP95Percent: Double = 5
    static let cpuP99Percent: Double = 7
    static let cpuMaxPercent: Double = 9

    static let callback = EndpointCallbackMetrics(
        p50Microseconds: 24,
        p95Microseconds: 38,
        p99Microseconds: 47,
        maxMicroseconds: 55,
        missedDeadlines: 0,
        underruns: 0,
        overruns: 0,
        recordedIntervalSamples: 4
    )

    static let audioPacketAge = UdpPcmPacketAgeMetrics(
        p50Microseconds: 180,
        p95Microseconds: 230,
        p99Microseconds: 260,
        maxMicroseconds: 300
    )

    static let videoFrameAge = UdpPcmPacketAgeMetrics(
        p50Microseconds: 16_667,
        p95Microseconds: 20_000,
        p99Microseconds: 23_333,
        maxMicroseconds: 26_667
    )

    static let localPacketAge = UdpPcmPacketAgeMetrics(
        p50Microseconds: 90,
        p95Microseconds: 130,
        p99Microseconds: 160,
        maxMicroseconds: 190
    )

    static let jitter = LatencyJitterMetrics(
        p50Microseconds: 25,
        p95Microseconds: 45,
        p99Microseconds: 60,
        maxMicroseconds: 80
    )

    static var callbackCounter: PerformanceCounterSummary {
        PerformanceCounterSummary.fromCallback(callback)
    }

    static var videoPacketizationCounter: PerformanceCounterSummary {
        PerformanceCounterSummary.fromSamples([220, 245, 260, 275, 300, 330])
    }

    static var loopbackTiming: LoopbackTimingMetrics {
        LoopbackTimingMetrics(
            p50Microseconds: 180,
            p95Microseconds: 240,
            p99Microseconds: 280,
            maxMicroseconds: 320
        )
    }

    static func packetAge(
        p50: Double,
        p95: Double,
        p99: Double,
        max: Double
    ) -> UdpPcmPacketAgeMetrics {
        UdpPcmPacketAgeMetrics(
            p50Microseconds: p50,
            p95Microseconds: p95,
            p99Microseconds: p99,
            maxMicroseconds: max
        )
    }

    static func jitter(
        p50: Double,
        p95: Double,
        p99: Double,
        max: Double
    ) -> LatencyJitterMetrics {
        LatencyJitterMetrics(
            p50Microseconds: p50,
            p95Microseconds: p95,
            p99Microseconds: p99,
            maxMicroseconds: max
        )
    }

    static func timing(oneWayMicroseconds: Double, jitter: LatencyJitterMetrics) -> LatencyBenchmarkTimingMetrics {
        LatencyBenchmarkTimingMetrics(
            oneWayEstimateMicroseconds: oneWayMicroseconds,
            roundTripMicroseconds: oneWayMicroseconds * 2,
            jitter: jitter
        )
    }
}
