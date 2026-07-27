// Shares percentile storage while phantom domains keep each metric family type-safe.

/// Stores the common latency percentile distribution for one semantic metric domain.
public struct LatencyPercentileMetrics<Domain>: Codable, Equatable, Sendable,
    LatencyPercentileValuesProviding {
    public var p50Microseconds: Double
    public var p95Microseconds: Double
    public var p99Microseconds: Double
    public var maxMicroseconds: Double

    public init(
        p50Microseconds: Double,
        p95Microseconds: Double,
        p99Microseconds: Double,
        maxMicroseconds: Double
    ) {
        self.p50Microseconds = p50Microseconds
        self.p95Microseconds = p95Microseconds
        self.p99Microseconds = p99Microseconds
        self.maxMicroseconds = maxMicroseconds
    }
}

/// Keeps benchmark jitter distinct from other percentile distributions.
public enum LatencyJitterMetricsDomain {}

/// Keeps UDP loopback RTT timing distinct from other percentile distributions.
public enum LoopbackTimingMetricsDomain {}

/// Keeps UDP packet age distinct from other percentile distributions.
public enum UdpPcmPacketAgeMetricsDomain {}

/// Names percentile metrics collected for latency jitter measurements.
public typealias LatencyJitterMetrics = LatencyPercentileMetrics<LatencyJitterMetricsDomain>
/// Names percentile metrics collected for UDP loopback timing measurements.
public typealias LoopbackTimingMetrics = LatencyPercentileMetrics<LoopbackTimingMetricsDomain>
/// Names percentile metrics collected for UDP packet age measurements.
public typealias UdpPcmPacketAgeMetrics = LatencyPercentileMetrics<UdpPcmPacketAgeMetricsDomain>
