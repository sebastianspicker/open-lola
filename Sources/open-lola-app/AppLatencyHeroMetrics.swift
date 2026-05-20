import Foundation
import OpenLolaCore

struct AppLatencyHeroMetrics: Equatable {
    let audioLatencyMs: Double?
    let packetLossPercent: Double?
    let jitterMs: Double?
    let expectedPeerReportCount: Int
    let loadedPeerReportCount: Int
    let loadFailures: [String]
    let peerReportFailures: [String]
    let supervisorVerdict: MeasurementVerdict

    var isPartial: Bool {
        supervisorVerdict != .pass
            || loadedPeerReportCount < expectedPeerReportCount
            || !loadFailures.isEmpty
            || !peerReportFailures.isEmpty
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
        if !peerReportFailures.isEmpty {
            reasons.append(peerReportFailures.joined(separator: "; "))
        }
        return reasons.joined(separator: ": ")
    }

    enum LoadResult: Equatable {
        case loaded(AppLatencyHeroMetrics)
        case absent
        case readFailure(String)
        case decodeFailure(String)
    }

    static func load(fromSupervisorReportPath path: String) -> AppLatencyHeroMetrics? {
        guard case .loaded(let metrics) = loadResult(fromSupervisorReportPath: path) else {
            return nil
        }
        return metrics
    }

    static func loadResult(fromSupervisorReportPath path: String) -> LoadResult {
        guard FileManager.default.fileExists(atPath: path) else {
            return .absent
        }
        let data: Data
        do {
            data = try BoundedFileReader.data(atPath: path)
        } catch {
            return .readFailure(String(describing: error))
        }
        let supervisor: DirectPeerTwoPeerLocalRunReport
        do {
            supervisor = try DirectPeerTwoPeerLocalRunReport.decode(from: data)
            try supervisor.validate()
        } catch {
            return .decodeFailure(String(describing: error))
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
        guard let metrics = make(
            from: reports,
            expectedPeerReportCount: supervisor.processResults.count,
            loadFailures: failures,
            supervisorVerdict: supervisor.verdict
        ) else {
            return .absent
        }
        return .loaded(metrics)
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
                    peerReportFailures: [],
                    supervisorVerdict: supervisorVerdict
                )
                : nil
        }
        let peerReportFailures = reports
            .filter { $0.verdict != .pass }
            .map { "\($0.id): peer report verdict \($0.verdict.rawValue)" }
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
            peerReportFailures: peerReportFailures,
            supervisorVerdict: supervisorVerdict
        )
    }

    private static func loadSessionReport(_ result: DirectPeerTwoPeerLocalRunProcessResult) throws -> DirectPeerSessionReport {
        let path = result.collectedReportPath ?? result.reportPath
        return try DirectPeerSessionReport.readValidated(fromPath: path)
    }
}
