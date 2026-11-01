// Bounds per-packet timing samples so hot paths only append and percentiles are built on read.
import Foundation

/// Keeps the most recent 65,536 duration samples (window limit) plus the total number recorded.
public struct PerformanceCounterWindow: Sendable {
    static let capacity = 65_536
    private var samples = [Double](repeating: 0, count: capacity)
    private var nextIndex = 0
    private var totalCount = 0

    public init() {}

    public mutating func record(_ microseconds: Double) {
        samples[nextIndex] = microseconds
        nextIndex = nextIndex + 1 == Self.capacity ? 0 : nextIndex + 1
        totalCount += 1
    }

    /// Percentiles come from the retained window; `sampleCount` still reports every valid sample recorded.
    public var summary: PerformanceCounterSummary {
        var result = PerformanceCounterSummary.fromSamples(Array(samples[0..<min(totalCount, Self.capacity)]))
        result.sampleCount += max(0, totalCount - Self.capacity)
        return result
    }
}
