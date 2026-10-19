// Derives E2E throughput, packet-order, CPU and memory values from optional direct-peer session reports.
import Foundation
import OpenLolaTransport

/// Optional direct-peer session reports from the source and receiver peers of an E2E run.
/// A value derived here is nil when no supplied report measured it, so the aggregate keeps it "not measured".
public struct E2EBenchmarkSessionInputs: Equatable, Sendable {
    public var source: DirectPeerSessionReport?
    public var receiver: DirectPeerSessionReport?

    /// Creates the inputs; both reports are optional.
    public init(source: DirectPeerSessionReport? = nil, receiver: DirectPeerSessionReport? = nil) {
        self.source = source
        self.receiver = receiver
    }

    var reports: [DirectPeerSessionReport] {
        [source, receiver].compactMap { $0 }
    }

    /// The busiest one-way media rate any session measured.
    var throughputMegabitsPerSecond: Double? {
        reports.compactMap { $0.mediaTraffic?.throughputMegabitsPerSecond }.max()
    }

    /// Reordered packets summed over the sessions, nil unless every supplied session counted them.
    var reorderedPackets: Int? {
        summedCounter(\.reorderedPackets)
    }

    /// Duplicate packets summed over the sessions, nil unless every supplied session counted them.
    var duplicatePackets: Int? {
        summedCounter(\.duplicatePackets)
    }

    /// Machine identity of the source peer, when its session report recorded one.
    var sourceHost: DirectPeerSessionHostIdentity? {
        source?.host
    }

    /// Machine identity of the receiver peer, when its session report recorded one.
    var receiverHost: DirectPeerSessionHostIdentity? {
        receiver?.host
    }

    var cpuP99Percent: Double? {
        reports.compactMap { $0.resources?.cpuP99Percent }.max()
    }

    var residentMemoryPeakMegabytes: Double? {
        reports.compactMap { $0.resources?.residentMemoryPeakMegabytes }.max()
    }

    // Names the session reports used and the fields no input can measure yet.
    var provenanceNote: String {
        let sessionNote = reports.isEmpty
            ? " No direct-peer session report was supplied, so throughput and packet order stay not measured."
            : " Throughput, packet order, CPU, and memory also use the direct-peer session reports "
                + reports.map(\.id).joined(separator: " and ") + "."
        return sessionNote
            + " GPU load, impairment runs, reconnect timing, receive-to-render latency, cue timing, and WAN"
            + " throughput have no measurement source yet, so they stay not measured and PASS stays withheld."
    }

    private func summedCounter(_ counter: KeyPath<DirectPeerSessionMediaTraffic, Int?>) -> Int? {
        let counts = reports.map { $0.mediaTraffic?[keyPath: counter] }
        guard !counts.isEmpty, counts.allSatisfy({ $0 != nil }) else {
            return nil
        }
        return counts.compactMap { $0 }.reduce(0) { saturatingOpenLolaCounterSum($0, $1) }
    }
}
