// Measures operations with a monotonic clock and summarizes warmup and percentile samples, keeping timing statistics consistent across benchmarks.
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation
import os

/// Captures run configuration required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyBenchmarkSamplingConfiguration: Equatable, Sendable {
    public static let minimumWarmupIterations = 3
    public static let minimumSampleCount = 10
    public static let defaultValue = LatencyBenchmarkSamplingConfiguration(
        validatedWarmupIterations: minimumWarmupIterations,
        validatedSampleCount: minimumSampleCount
    )

    public var warmupIterations: Int
    public var sampleCount: Int

    public init(warmupIterations: Int = 3, sampleCount: Int = 10) throws {
        guard warmupIterations >= Self.minimumWarmupIterations else {
            throw LatencyBenchmarkSamplingConfigurationError.warmupIterationsTooLow(
                actual: warmupIterations,
                minimum: Self.minimumWarmupIterations
            )
        }
        guard sampleCount >= Self.minimumSampleCount else {
            throw LatencyBenchmarkSamplingConfigurationError.sampleCountTooLow(
                actual: sampleCount,
                minimum: Self.minimumSampleCount
            )
        }
        self.init(validatedWarmupIterations: warmupIterations, validatedSampleCount: sampleCount)
    }

    private init(validatedWarmupIterations: Int, validatedSampleCount: Int) {
        self.warmupIterations = validatedWarmupIterations
        self.sampleCount = validatedSampleCount
    }
}

// swiftlint:disable:next type_name
/// Describes failures that prevent latency benchmark inputs or evidence from satisfying the required validation invariants.
public enum LatencyBenchmarkSamplingConfigurationError: Error, Equatable, Sendable {
    case warmupIterationsTooLow(actual: Int, minimum: Int)
    case sampleCountTooLow(actual: Int, minimum: Int)
}

/// Captures summary statistics required to validate, interpret, and reproduce a latency benchmark result.
public struct LatencyBenchmarkSampleSummary: Codable, Equatable, Sendable {
    public var warmupIterations: Int
    public var sampleCount: Int
    public var coldStartMaxMicroseconds: Double?
    public var medianMicroseconds: Double
    public var p99Microseconds: Double
    public var maxMicroseconds: Double

    public init(
        warmupIterations: Int,
        sampleCount: Int,
        coldStartMaxMicroseconds: Double? = nil,
        medianMicroseconds: Double,
        p99Microseconds: Double,
        maxMicroseconds: Double
    ) {
        self.warmupIterations = warmupIterations
        self.sampleCount = sampleCount
        self.coldStartMaxMicroseconds = coldStartMaxMicroseconds
        self.medianMicroseconds = medianMicroseconds
        self.p99Microseconds = p99Microseconds
        self.maxMicroseconds = maxMicroseconds
    }
}

/// Measures operations with a monotonic clock and summarizes warm-up and repeated samples.
public enum LatencyBenchmark {
    private static let logger = Logger(subsystem: "de.hfmt.open-lola", category: "LatencyBenchmark")
    private static let medianPercentile = 0.50
    private static let p99Percentile = 0.99

    public static func measure<T>(_ operation: () throws -> T) rethrows -> (
        value: T,
        durationMicroseconds: Double
    ) {
        let start = monotonicNanoseconds()
        let value = try operation()
        let end = monotonicNanoseconds()
        precondition(end >= start, "LatencyBenchmark monotonic clock went backwards")
        let durationMicroseconds = Double(end - start) / 1_000
        return (value, durationMicroseconds)
    }

    public static func measureMicroseconds(_ operation: () throws -> Void) rethrows -> Double {
        try measure(operation).durationMicroseconds
    }

    public static func measureRepeatedMicroseconds(
        configuration: LatencyBenchmarkSamplingConfiguration = .defaultValue,
        _ operation: () throws -> Void
    ) rethrows -> LatencyBenchmarkSampleSummary {
        var warmupSamples: [Double] = []
        warmupSamples.reserveCapacity(configuration.warmupIterations)
        for _ in 0..<configuration.warmupIterations {
            warmupSamples.append(try measureMicroseconds(operation))
        }
        var samples: [Double] = []
        samples.reserveCapacity(configuration.sampleCount)
        for _ in 0..<configuration.sampleCount {
            samples.append(try measureMicroseconds(operation))
        }
        return summarize(
            samplesMicroseconds: samples,
            warmupSamplesMicroseconds: warmupSamples,
            warmupIterations: configuration.warmupIterations
        )
    }

    public static func summarize(
        samplesMicroseconds: [Double],
        warmupSamplesMicroseconds: [Double] = [],
        warmupIterations: Int
    ) -> LatencyBenchmarkSampleSummary {
        let finiteSamples = samplesMicroseconds.filter(\.isFinite)
        let filteredCount = samplesMicroseconds.count - finiteSamples.count
        if filteredCount > 0 {
            logger.warning("Filtered \(filteredCount, privacy: .public) non-finite latency benchmark sample(s)")
        }
        let finiteWarmupSamples = warmupSamplesMicroseconds.filter(\.isFinite)
        let sanitized = finiteSamples.map { max(0, $0) }.sorted()
        let coldStartMaxMicroseconds = finiteWarmupSamples.map { max(0, $0) }.max()
        return LatencyBenchmarkSampleSummary(
            warmupIterations: max(3, warmupIterations),
            sampleCount: sanitized.count,
            coldStartMaxMicroseconds: coldStartMaxMicroseconds,
            medianMicroseconds: percentile(sanitized, medianPercentile),
            p99Microseconds: percentile(sanitized, p99Percentile),
            maxMicroseconds: sanitized.last ?? 0
        )
    }

    private static func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        guard !sorted.isEmpty else {
            return 0
        }
        let bounded = min(1, max(0, fraction))
        let index = Int(Double(sorted.count - 1) * bounded)
        return sorted[min(max(index, 0), sorted.count - 1)]
    }

    private static func monotonicNanoseconds() -> UInt64 {
        #if canImport(Darwin)
        return clock_gettime_nsec_np(CLOCK_MONOTONIC)
        #else
        var timestamp = timespec()
        clock_gettime(CLOCK_MONOTONIC, &timestamp)
        return UInt64(timestamp.tv_sec) * 1_000_000_000 + UInt64(timestamp.tv_nsec)
        #endif
    }
}
