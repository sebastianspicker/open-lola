// Represents callback timing evidence independently from direct-peer runtime execution.
import Foundation

public struct EndpointCallbackMetrics: Codable, Equatable, Sendable, LatencyPercentileValuesProviding {
    public typealias Latency = LatencyPercentileMetrics<EndpointCallbackMetrics>

    public struct Events: Equatable, Sendable {
        public var missedDeadlines: Int
        public var underruns: Int
        public var overruns: Int

        public init(missedDeadlines: Int, underruns: Int, overruns: Int) {
            self.missedDeadlines = missedDeadlines
            self.underruns = underruns
            self.overruns = overruns
        }
    }

    public struct Sampling: Equatable, Sendable {
        public var recordedIntervalSamples: Int
        public var droppedIntervalSamples: Int
        public var hostTimeConversionFailures: Int

        public init(recordedIntervalSamples: Int = 0, droppedIntervalSamples: Int = 0, hostTimeConversionFailures: Int = 0) {
            self.recordedIntervalSamples = recordedIntervalSamples
            self.droppedIntervalSamples = droppedIntervalSamples
            self.hostTimeConversionFailures = hostTimeConversionFailures
        }
    }

    public var p50Microseconds: Double
    public var p95Microseconds: Double
    public var p99Microseconds: Double
    public var maxMicroseconds: Double
    public var missedDeadlines: Int
    public var underruns: Int
    public var overruns: Int
    public var recordedIntervalSamples: Int
    public var droppedIntervalSamples: Int
    public var hostTimeConversionFailures: Int

    public init(latency: Latency, events: Events, sampling: Sampling = .init()) {
        self.p50Microseconds = latency.p50Microseconds
        self.p95Microseconds = latency.p95Microseconds
        self.p99Microseconds = latency.p99Microseconds
        self.maxMicroseconds = latency.maxMicroseconds
        self.missedDeadlines = events.missedDeadlines
        self.underruns = events.underruns
        self.overruns = events.overruns
        self.recordedIntervalSamples = sampling.recordedIntervalSamples
        self.droppedIntervalSamples = sampling.droppedIntervalSamples
        self.hostTimeConversionFailures = sampling.hostTimeConversionFailures
    }

    private enum CodingKeys: String, CodingKey, LatencyPercentileCodingKeys {
        case p50Microseconds
        case p95Microseconds
        case p99Microseconds
        case maxMicroseconds
        case missedDeadlines
        case underruns
        case overruns
        case recordedIntervalSamples
        case droppedIntervalSamples
        case hostTimeConversionFailures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let percentiles = try decodeLatencyPercentiles(from: container)
        self.p50Microseconds = percentiles.p50Microseconds
        self.p95Microseconds = percentiles.p95Microseconds
        self.p99Microseconds = percentiles.p99Microseconds
        self.maxMicroseconds = percentiles.maxMicroseconds
        self.missedDeadlines = try container.decode(Int.self, forKey: .missedDeadlines)
        self.underruns = try container.decode(Int.self, forKey: .underruns)
        self.overruns = try container.decode(Int.self, forKey: .overruns)
        self.recordedIntervalSamples = try container.decodeIfPresent(Int.self, forKey: .recordedIntervalSamples) ?? 0
        self.droppedIntervalSamples = try container.decodeIfPresent(Int.self, forKey: .droppedIntervalSamples) ?? 0
        self.hostTimeConversionFailures = try container.decodeIfPresent(Int.self, forKey: .hostTimeConversionFailures) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try encodeLatencyPercentiles(self, to: &container)
        try container.encode(missedDeadlines, forKey: .missedDeadlines)
        try container.encode(underruns, forKey: .underruns)
        try container.encode(overruns, forKey: .overruns)
        try container.encode(recordedIntervalSamples, forKey: .recordedIntervalSamples)
        try container.encode(droppedIntervalSamples, forKey: .droppedIntervalSamples)
        try container.encode(hostTimeConversionFailures, forKey: .hostTimeConversionFailures)
    }
}
