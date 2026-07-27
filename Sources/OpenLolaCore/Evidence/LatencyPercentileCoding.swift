// Shares stable percentile-field coding across measured latency artifacts.
import Foundation

protocol LatencyPercentileCodingKeys: CodingKey {
    static var p50Microseconds: Self { get }
    static var p95Microseconds: Self { get }
    static var p99Microseconds: Self { get }
    static var maxMicroseconds: Self { get }
}

protocol LatencyPercentileValuesProviding {
    var p50Microseconds: Double { get }
    var p95Microseconds: Double { get }
    var p99Microseconds: Double { get }
    var maxMicroseconds: Double { get }
}

struct LatencyPercentileValues {
    let p50Microseconds: Double
    let p95Microseconds: Double
    let p99Microseconds: Double
    let maxMicroseconds: Double
}

func decodeLatencyPercentiles<Key: LatencyPercentileCodingKeys>(
    from container: KeyedDecodingContainer<Key>
) throws -> LatencyPercentileValues {
    LatencyPercentileValues(
        p50Microseconds: try container.decode(Double.self, forKey: .p50Microseconds),
        p95Microseconds: try container.decode(Double.self, forKey: .p95Microseconds),
        p99Microseconds: try container.decode(Double.self, forKey: .p99Microseconds),
        maxMicroseconds: try container.decode(Double.self, forKey: .maxMicroseconds)
    )
}

func encodeLatencyPercentiles<Values: LatencyPercentileValuesProviding, Key: LatencyPercentileCodingKeys>(
    _ values: Values,
    to container: inout KeyedEncodingContainer<Key>
) throws {
    try container.encode(values.p50Microseconds, forKey: .p50Microseconds)
    try container.encode(values.p95Microseconds, forKey: .p95Microseconds)
    try container.encode(values.p99Microseconds, forKey: .p99Microseconds)
    try container.encode(values.maxMicroseconds, forKey: .maxMicroseconds)
}
