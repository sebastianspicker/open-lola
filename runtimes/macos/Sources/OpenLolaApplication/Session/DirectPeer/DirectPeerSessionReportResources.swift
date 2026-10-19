// Holds the optional resource and media-traffic blocks of a direct-peer session report; both are absent in older reports.
import Foundation
import OpenLolaMediaPlatform

/// Records the CPU share and resident memory of this peer's process, sampled while the session ran.
public struct DirectPeerSessionResourceUsage: Codable, Equatable, Sendable {
    /// CPU percentages are user plus system time over wall time and active cores, in percent of the whole machine.
    public var cpuP50Percent: Double
    public var cpuP99Percent: Double
    public var cpuMaxPercent: Double
    /// Peak resident set size in MiB (1,048,576 bytes).
    public var residentMemoryPeakMegabytes: Double
    public var sampleCount: Int

    /// Creates a resource block from already aggregated values.
    public init(
        cpuP50Percent: Double,
        cpuP99Percent: Double,
        cpuMaxPercent: Double,
        residentMemoryPeakMegabytes: Double,
        sampleCount: Int
    ) {
        self.cpuP50Percent = cpuP50Percent
        self.cpuP99Percent = cpuP99Percent
        self.cpuMaxPercent = cpuMaxPercent
        self.residentMemoryPeakMegabytes = residentMemoryPeakMegabytes
        self.sampleCount = sampleCount
    }

    /// Converts a process sampler summary into the report block.
    public init(summary: ProcessResourceSummary) {
        self.init(
            cpuP50Percent: summary.cpuP50Percent,
            cpuP99Percent: summary.cpuP99Percent,
            cpuMaxPercent: summary.cpuMaxPercent,
            residentMemoryPeakMegabytes: Double(summary.residentMemoryPeakBytes) / 1_048_576,
            sampleCount: summary.sampleCount
        )
    }
}

/// Records media UDP payload volume and receive order counters from this peer's audio and video transports.
/// A nil counter was not measured: the order counters are nil when a received stream carries no transport
/// sequence number (AES67 RTP audio is read as raw datagrams).
public struct DirectPeerSessionMediaTraffic: Codable, Equatable, Sendable {
    public var bytesSent: Int?
    public var bytesReceived: Int?
    /// Packets older than the newest sequence number seen on their stream that were not duplicates.
    public var reorderedPackets: Int?
    /// Packets whose sequence number already arrived within the 256-packet window of their stream.
    public var duplicatePackets: Int?
    /// Wall time over which the byte counters accumulated.
    public var durationSeconds: Double?

    /// Creates a media-traffic block; omitted values stay not measured.
    public init(
        bytesSent: Int? = nil,
        bytesReceived: Int? = nil,
        reorderedPackets: Int? = nil,
        duplicatePackets: Int? = nil,
        durationSeconds: Double? = nil
    ) {
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.reorderedPackets = reorderedPackets
        self.duplicatePackets = duplicatePackets
        self.durationSeconds = durationSeconds
    }

    /// Larger one-way media rate in Mbit/s, or nil when bytes or a positive duration are missing.
    public var throughputMegabitsPerSecond: Double? {
        guard let durationSeconds, durationSeconds > 0 else {
            return nil
        }
        let bytes = [bytesSent, bytesReceived].compactMap { $0 }.max()
        return bytes.map { Double($0) * 8 / durationSeconds / 1_000_000 }
    }
}

/// Samples process resources around one direct-peer session and fills the report's optional blocks.
struct DirectPeerSessionResourceRecorder {
    let sampler = ProcessResourceSampler()

    /// Starts sampling and lets `runner` publish the newest sample in its peer metrics.
    func start(attachingTo runner: inout PeerSessionRunner) {
        sampler.start()
        runner.resourceSampler = sampler
    }

    /// Stops sampling and writes the resource, media-traffic and host blocks into `report`.
    func finish(
        _ report: inout DirectPeerSessionReport,
        runner: PeerSessionRunner,
        sequenceNumbersCoverReceivedMedia: Bool = true
    ) {
        let summary = sampler.stop()
        report.resources = summary.map(DirectPeerSessionResourceUsage.init(summary:))
        report.host = DirectPeerSessionHostIdentity.current()
        let transport = runner.transportMetrics()
        report.mediaTraffic = DirectPeerSessionMediaTraffic(
            bytesSent: transport.bytesSent,
            bytesReceived: transport.bytesReceived,
            reorderedPackets: sequenceNumbersCoverReceivedMedia ? transport.reorderedPackets : nil,
            duplicatePackets: sequenceNumbersCoverReceivedMedia ? transport.duplicatePackets : nil,
            durationSeconds: summary?.durationSeconds
        )
    }
}
