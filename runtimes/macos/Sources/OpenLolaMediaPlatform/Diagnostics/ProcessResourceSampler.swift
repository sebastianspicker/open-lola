// Samples this process's CPU share and resident memory on a utility-QoS timer, away from audio and media threads.
// DECISION: Memory is MACH_TASK_BASIC_INFO resident_size, not TASK_VM_INFO phys_footprint. Reports and the
// peer metrics wire field name resident memory, and the capture metrics already use RSS (ru_maxrss), so RSS
// keeps the values comparable; phys_footprint would read lower because it omits clean and shared pages.
#if canImport(Darwin)
import Darwin
#endif
import Dispatch
import Foundation

/// One resource reading: CPU share over the preceding interval and resident memory at the sample time.
public struct ProcessResourceSample: Equatable, Sendable {
    /// User plus system CPU time over wall time times active cores in the interval: percent of the whole machine,
    /// so 100 means every core was busy (evidence validators require 0...100).
    public var cpuPercent: Double
    /// Resident set size of the process at the sample time.
    public var residentMemoryBytes: UInt64

    /// Creates a sample from a measured CPU share and resident size.
    public init(cpuPercent: Double, residentMemoryBytes: UInt64) {
        self.cpuPercent = cpuPercent
        self.residentMemoryBytes = residentMemoryBytes
    }
}

/// Distribution of the samples a run collected; CPU percentiles cover the bounded buffer, maxima the whole run.
public struct ProcessResourceSummary: Equatable, Sendable {
    public var cpuP50Percent: Double
    public var cpuP99Percent: Double
    public var cpuMaxPercent: Double
    public var residentMemoryPeakBytes: UInt64
    public var sampleCount: Int
    /// Wall time between `start()` and `stop()`.
    public var durationSeconds: Double

    /// Creates a summary from already aggregated values.
    public init(
        cpuP50Percent: Double,
        cpuP99Percent: Double,
        cpuMaxPercent: Double,
        residentMemoryPeakBytes: UInt64,
        sampleCount: Int,
        durationSeconds: Double
    ) {
        self.cpuP50Percent = cpuP50Percent
        self.cpuP99Percent = cpuP99Percent
        self.cpuMaxPercent = cpuMaxPercent
        self.residentMemoryPeakBytes = residentMemoryPeakBytes
        self.sampleCount = sampleCount
        self.durationSeconds = durationSeconds
    }
}

/// Periodically samples process CPU (getrusage delta over wall delta and active cores) and resident memory
/// (task_info) on its own utility-QoS queue, keeping the newest samples in a fixed-size ring.
public final class ProcessResourceSampler: @unchecked Sendable {
    public static let defaultIntervalNanoseconds: UInt64 = 250_000_000
    /// 4,096 samples at 250 ms cover about 17 minutes; older samples leave the percentile window.
    public static let defaultCapacity = 4_096

    private let intervalNanoseconds: UInt64
    private let coreCount = Double(max(1, ProcessInfo.processInfo.activeProcessorCount))
    private let queue = DispatchQueue(label: "open-lola.process-resource-sampler", qos: .utility)
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private var cpuRing: [Double]
    private var ringNext = 0
    private var ringCount = 0
    private var totalSamples = 0
    private var cpuMax = 0.0
    private var memoryPeak: UInt64 = 0
    private var latest: ProcessResourceSample?
    private var previousCPUSeconds = 0.0
    private var previousWallNanoseconds: UInt64 = 0
    private var startWallNanoseconds: UInt64 = 0
    private var finalSummary: ProcessResourceSummary?
    private var started = false

    /// Creates a stopped sampler; `capacity` bounds the CPU sample ring.
    public init(
        intervalNanoseconds: UInt64 = ProcessResourceSampler.defaultIntervalNanoseconds,
        capacity: Int = ProcessResourceSampler.defaultCapacity
    ) {
        self.intervalNanoseconds = max(1_000_000, intervalNanoseconds)
        self.cpuRing = Array(repeating: 0, count: max(1, capacity))
    }

    deinit {
        timer?.cancel()
    }

    /// The newest sample, or nil before the first interval elapsed.
    public var latestSample: ProcessResourceSample? {
        lock.withLock { latest }
    }

    /// Starts sampling; a second call is ignored.
    public func start() {
        lock.withLock {
            guard !started else {
                return
            }
            started = true
            startWallNanoseconds = DispatchTime.now().uptimeNanoseconds
            previousWallNanoseconds = startWallNanoseconds
            previousCPUSeconds = processCPUSeconds() ?? 0
        }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(
            deadline: .now() + .nanoseconds(Int(intervalNanoseconds)),
            repeating: .nanoseconds(Int(intervalNanoseconds))
        )
        source.setEventHandler { [weak self] in
            self?.recordSample()
        }
        lock.withLock { timer = source }
        source.resume()
    }

    /// Stops the timer, takes a closing sample, and returns the run summary; later calls return the same summary.
    @discardableResult
    public func stop() -> ProcessResourceSummary? {
        let source: DispatchSourceTimer? = lock.withLock {
            defer { timer = nil }
            return timer
        }
        guard let source else {
            return lock.withLock { finalSummary }
        }
        source.cancel()
        queue.sync {}
        recordSample()
        return lock.withLock {
            finalSummary = currentSummary()
            return finalSummary
        }
    }

    /// Summary of the samples so far, or nil when no sample was recorded.
    public func summary() -> ProcessResourceSummary? {
        lock.withLock { finalSummary ?? currentSummary() }
    }

    private func recordSample() {
        let now = DispatchTime.now().uptimeNanoseconds
        let cpuSeconds = processCPUSeconds()
        let memory = processResidentMemoryBytes()
        lock.withLock {
            guard let cpuSeconds, now > previousWallNanoseconds else {
                return
            }
            let wallSeconds = Double(now - previousWallNanoseconds) / 1_000_000_000
            let cpuPercent = min(100, max(0, cpuSeconds - previousCPUSeconds) / (wallSeconds * coreCount) * 100)
            previousCPUSeconds = cpuSeconds
            previousWallNanoseconds = now
            let sample = ProcessResourceSample(cpuPercent: cpuPercent, residentMemoryBytes: memory ?? 0)
            latest = sample
            cpuRing[ringNext] = cpuPercent
            ringNext = (ringNext + 1) % cpuRing.count
            ringCount = min(ringCount + 1, cpuRing.count)
            totalSamples += 1
            cpuMax = max(cpuMax, cpuPercent)
            memoryPeak = max(memoryPeak, sample.residentMemoryBytes)
        }
    }

    // Caller holds `lock`.
    private func currentSummary() -> ProcessResourceSummary? {
        guard ringCount > 0 else {
            return nil
        }
        let sorted = cpuRing.prefix(ringCount).sorted()
        return ProcessResourceSummary(
            cpuP50Percent: processResourcePercentile(sorted, 0.50),
            cpuP99Percent: processResourcePercentile(sorted, 0.99),
            cpuMaxPercent: cpuMax,
            residentMemoryPeakBytes: memoryPeak,
            sampleCount: totalSamples,
            durationSeconds: Double(previousWallNanoseconds - startWallNanoseconds) / 1_000_000_000
        )
    }
}

// Nearest-rank percentile over an ascending, non-empty array.
func processResourcePercentile(_ sorted: [Double], _ fraction: Double) -> Double {
    let rank = Int((fraction * Double(sorted.count)).rounded(.up))
    return sorted[min(max(rank, 1), sorted.count) - 1]
}

/// Total user plus system CPU time this process has used, in seconds.
public func processCPUSeconds() -> Double? {
    #if canImport(Darwin)
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else {
        return nil
    }
    let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
    let system = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
    return user + system
    #else
    return nil
    #endif
}

/// Current resident set size of this process from `MACH_TASK_BASIC_INFO`.
public func processResidentMemoryBytes() -> UInt64? {
    #if canImport(Darwin)
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
        MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else {
        return nil
    }
    return UInt64(info.resident_size)
    #else
    return nil
    #endif
}
