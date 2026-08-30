// Collects PerformanceCounterSummary measurements, keeping metric aggregation separate from report validation.
import Foundation
import OpenLolaContracts

/// Captures summary statistics required to validate, interpret, and reproduce a performance audit result.
public struct PerformanceCounterSummary: Codable, Equatable, Sendable, LatencyPercentileValuesProviding {
    public var sampleCount: Int
    public var p50Microseconds: Double
    public var p95Microseconds: Double
    public var p99Microseconds: Double
    public var maxMicroseconds: Double
    public var invalidSampleCount: Int
    private var recordedSamplesMicroseconds: [Double]

    public var rawSamplesMicroseconds: [Double] {
        recordedSamplesMicroseconds
    }

    public static let empty = PerformanceCounterSummary(
        sampleCount: 0,
        p50Microseconds: 0,
        p95Microseconds: 0,
        p99Microseconds: 0,
        maxMicroseconds: 0,
        invalidSampleCount: 0,
        recordedSamplesMicroseconds: []
    )

    public init(
        sampleCount: Int,
        p50Microseconds: Double,
        p95Microseconds: Double,
        p99Microseconds: Double,
        maxMicroseconds: Double,
        invalidSampleCount: Int = 0,
        recordedSamplesMicroseconds: [Double] = []
    ) {
        self.sampleCount = sampleCount
        self.p50Microseconds = p50Microseconds
        self.p95Microseconds = p95Microseconds
        self.p99Microseconds = p99Microseconds
        self.maxMicroseconds = maxMicroseconds
        self.invalidSampleCount = invalidSampleCount
        self.recordedSamplesMicroseconds = recordedSamplesMicroseconds
    }

    public static func fromCallback(_ callback: EndpointCallbackMetrics) -> PerformanceCounterSummary {
        PerformanceCounterSummary(
            sampleCount: 1,
            p50Microseconds: callback.p50Microseconds,
            p95Microseconds: callback.p95Microseconds,
            p99Microseconds: callback.p99Microseconds,
            maxMicroseconds: callback.maxMicroseconds
        )
    }

    public static func fromSamples(_ samples: [Double]) -> PerformanceCounterSummary {
        guard !samples.isEmpty else {
            return .empty
        }
        let invalidSampleCount = samples.filter { !$0.isFinite || $0 < 0 }.count
        let sorted = samples.filter { $0.isFinite && $0 >= 0 }.sorted()
        guard !sorted.isEmpty else {
            return PerformanceCounterSummary(
                sampleCount: 0,
                p50Microseconds: 0,
                p95Microseconds: 0,
                p99Microseconds: 0,
                maxMicroseconds: 0,
                invalidSampleCount: invalidSampleCount
            )
        }
        return PerformanceCounterSummary(
            sampleCount: sorted.count,
            p50Microseconds: performancePercentile(sorted, 0.50),
            p95Microseconds: performancePercentile(sorted, 0.95),
            p99Microseconds: performancePercentile(sorted, 0.99),
            maxMicroseconds: sorted.last ?? 0,
            invalidSampleCount: invalidSampleCount
        )
    }

    public mutating func record(_ microseconds: Double) {
        recordedSamplesMicroseconds.append(microseconds)
        finalize()
    }

    public mutating func finalize() {
        guard !recordedSamplesMicroseconds.isEmpty else {
            return
        }
        let samples = recordedSamplesMicroseconds
        self = PerformanceCounterSummary.fromSamples(samples)
        recordedSamplesMicroseconds = samples
    }

    enum CodingKeys: String, CodingKey, LatencyPercentileCodingKeys {
        case sampleCount
        case p50Microseconds
        case p95Microseconds
        case p99Microseconds
        case maxMicroseconds
        case invalidSampleCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sampleCount = try container.decode(Int.self, forKey: .sampleCount)
        let percentiles = try decodeLatencyPercentiles(from: container)
        self.p50Microseconds = percentiles.p50Microseconds
        self.p95Microseconds = percentiles.p95Microseconds
        self.p99Microseconds = percentiles.p99Microseconds
        self.maxMicroseconds = percentiles.maxMicroseconds
        self.invalidSampleCount = try container.decodeIfPresent(Int.self, forKey: .invalidSampleCount) ?? 0
        self.recordedSamplesMicroseconds = []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sampleCount, forKey: .sampleCount)
        try encodeLatencyPercentiles(self, to: &container)
        try container.encode(invalidSampleCount, forKey: .invalidSampleCount)
    }

    public static func == (lhs: PerformanceCounterSummary, rhs: PerformanceCounterSummary) -> Bool {
        lhs.sampleCount == rhs.sampleCount
            && lhs.p50Microseconds == rhs.p50Microseconds
            && lhs.p95Microseconds == rhs.p95Microseconds
            && lhs.p99Microseconds == rhs.p99Microseconds
            && lhs.maxMicroseconds == rhs.maxMicroseconds
            && lhs.invalidSampleCount == rhs.invalidSampleCount
    }
}

private func performancePercentile(_ sorted: [Double], _ fraction: Double) -> Double {
    guard !sorted.isEmpty else {
        return 0
    }
    let bounded = min(1, max(0, fraction))
    let index = Int((Double(sorted.count - 1) * bounded).rounded(.up))
    return sorted[min(sorted.count - 1, max(0, index))]
}
