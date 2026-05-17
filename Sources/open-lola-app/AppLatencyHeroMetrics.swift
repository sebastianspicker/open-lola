import Foundation
import OpenLolaCore

struct AppLatencyHeroMetrics: Equatable {
    let audioLatencyMs: Double?
    let packetLossPercent: Double?
    let jitterMs: Double?
    let expectedPeerReportCount: Int
    let loadedPeerReportCount: Int
    let loadFailures: [String]
    let supervisorVerdict: MeasurementVerdict

    var isPartial: Bool {
        supervisorVerdict != .pass || loadedPeerReportCount < expectedPeerReportCount || !loadFailures.isEmpty
    }

    var evidenceStatusMessage: String? {
        guard isPartial else {
            return nil
        }
        var reasons: [String] = []
        if supervisorVerdict != .pass {
            reasons.append("supervisor verdict \(supervisorVerdict.rawValue)")
        }
        let loaded = "\(loadedPeerReportCount)/\(expectedPeerReportCount) peer reports loaded"
        if loadedPeerReportCount < expectedPeerReportCount || !loadFailures.isEmpty {
            reasons.append(loaded)
        }
        if !loadFailures.isEmpty {
            reasons.append(loadFailures.joined(separator: "; "))
        }
        return reasons.joined(separator: ": ")
    }

    static func load(fromSupervisorReportPath path: String) -> AppLatencyHeroMetrics? {
        guard
            let data = try? BoundedFileReader.data(atPath: path),
            let supervisor = try? DirectPeerTwoPeerLocalRunReport.decode(from: data)
        else {
            return nil
        }
        var reports: [DirectPeerSessionReport] = []
        var failures: [String] = []
        for result in supervisor.processResults {
            do {
                reports.append(try loadSessionReport(result))
            } catch {
                failures.append("\(result.peerID): \(error)")
            }
        }
        return make(
            from: reports,
            expectedPeerReportCount: supervisor.processResults.count,
            loadFailures: failures,
            supervisorVerdict: supervisor.verdict
        )
    }

    static func make(from reports: [DirectPeerSessionReport]) -> AppLatencyHeroMetrics? {
        make(
            from: reports,
            expectedPeerReportCount: reports.count,
            loadFailures: [],
            supervisorVerdict: .pass
        )
    }

    static func make(
        from reports: [DirectPeerSessionReport],
        expectedPeerReportCount: Int,
        loadFailures: [String],
        supervisorVerdict: MeasurementVerdict
    ) -> AppLatencyHeroMetrics? {
        let hasPartialEvidence = expectedPeerReportCount > 0 && (!loadFailures.isEmpty || supervisorVerdict != .pass)
        guard !reports.isEmpty else {
            return hasPartialEvidence
                ? AppLatencyHeroMetrics(
                    audioLatencyMs: nil,
                    packetLossPercent: nil,
                    jitterMs: nil,
                    expectedPeerReportCount: expectedPeerReportCount,
                    loadedPeerReportCount: 0,
                    loadFailures: loadFailures,
                    supervisorVerdict: supervisorVerdict
                )
                : nil
        }
        let packetsReceived = reports.reduce(0) { $0 + $1.metrics.packetsReceived }
        let packetsLost = reports.reduce(0) { $0 + $1.metrics.packetsLost }
        let observedPackets = packetsReceived + packetsLost
        let packetLoss = observedPackets > 0 ? Double(packetsLost) / Double(observedPackets) * 100 : nil
        let jitter = reports.map(\.metrics.jitterMicroseconds).max().map { $0 / 1_000 }
        let latency = reports.compactMap {
            $0.avRuntime?.fastestAVBaselineComparison?.fastestAVAudioLatencyP99Microseconds
        }.max().map { $0 / 1_000 }
        return AppLatencyHeroMetrics(
            audioLatencyMs: latency,
            packetLossPercent: packetLoss,
            jitterMs: jitter,
            expectedPeerReportCount: expectedPeerReportCount,
            loadedPeerReportCount: reports.count,
            loadFailures: loadFailures,
            supervisorVerdict: supervisorVerdict
        )
    }

    private static func loadSessionReport(_ result: DirectPeerTwoPeerLocalRunProcessResult) throws -> DirectPeerSessionReport {
        let path = result.collectedReportPath ?? result.reportPath
        let data = try BoundedFileReader.data(atPath: path)
        return try DirectPeerSessionReport.decode(from: data)
    }
}
