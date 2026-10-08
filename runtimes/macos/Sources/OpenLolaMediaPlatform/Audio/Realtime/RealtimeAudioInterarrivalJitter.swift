// Maintains a bounded interarrival jitter percentile without comparing remote and local clock origins.
import Foundation

struct RealtimeAudioInterarrivalJitter {
    private let capacity: Int
    private var samples: [Double] = []
    private var sortedSamples: [Double] = []
    private var nextSampleIndex = 0
    private var previousTransitNanoseconds: Int64?

    init(capacity: Int = 128) {
        self.capacity = max(1, capacity)
        samples.reserveCapacity(self.capacity)
        sortedSamples.reserveCapacity(self.capacity)
    }

    mutating func observe(senderHostTimeNanoseconds: UInt64, arrivalNanoseconds: UInt64) -> Double {
        let transit = Int64(truncatingIfNeeded: arrivalNanoseconds)
            &- Int64(truncatingIfNeeded: senderHostTimeNanoseconds)
        defer { previousTransitNanoseconds = transit }
        guard let previousTransitNanoseconds else { return 0 }
        let jitter = Double(transit &- previousTransitNanoseconds).magnitude / 1_000
        if samples.count == capacity {
            sortedSamples.remove(at: insertionIndex(for: samples[nextSampleIndex]))
            samples[nextSampleIndex] = jitter
            nextSampleIndex = (nextSampleIndex + 1) % capacity
        } else {
            samples.append(jitter)
        }
        sortedSamples.insert(jitter, at: insertionIndex(for: jitter))
        let percentileIndex = max(0, Int(ceil(Double(sortedSamples.count) * 0.99)) - 1)
        return sortedSamples[percentileIndex]
    }

    private func insertionIndex(for sample: Double) -> Int {
        var lower = 0
        var upper = sortedSamples.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if sortedSamples[middle] < sample {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }
}
