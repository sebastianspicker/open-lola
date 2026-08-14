// Verifies that direct-peer session reports preserve their persisted JSON contract.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionReportPreservesPersistedJSONContract() throws {
    let report = DirectPeerSessionReport(
        id: "direct-peer-session-characterization",
        capturedAt: "2026-08-02T00:00:00Z",
        configuration: appSessionConfiguration(),
        metrics: DirectPeerSessionReportMetrics(
            traffic: .init(
                controlMessagesSent: 2,
                packetsSent: 4,
                packetsReceived: 3,
                packetsLost: 1,
                jitterMicroseconds: 125,
                audioPacketsRouted: 3,
                videoPacketsRouted: 0,
                recoveryEvents: 1
            ),
            control: .init(audioPayloadsSentOnControlChannel: 0),
            remote: .init(),
            remoteResources: .init()
        ),
        verdict: .partial,
        notes: "deterministic characterization report"
    )

    #expect(report.avRuntime == nil)
    #expect(report.measuredEvidence == nil)

    let data = try report.prettyJSONData()
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(Set(object.keys) == [
        "id", "capturedAt", "configuration", "metrics", "verdict", "notes"
    ])
    #expect(object["avRuntime"] == nil)
    #expect(object["measuredEvidence"] == nil)
    #expect(try DirectPeerSessionReport.decode(from: data) == report)
}

@Test
func directPeerSessionReportDecodesLegacyMetricsWithLaterFieldsOmitted() throws {
    let report = DirectPeerSessionReport(
        id: "direct-peer-session-legacy-report",
        capturedAt: "2026-08-02T00:00:00Z",
        configuration: appSessionConfiguration(),
        metrics: DirectPeerSessionReportMetrics(
            traffic: .init(
                controlMessagesSent: 2,
                packetsSent: 4,
                packetsReceived: 3,
                packetsLost: 1,
                jitterMicroseconds: 125,
                audioPacketsRouted: 3,
                videoPacketsRouted: 0,
                recoveryEvents: 1
            ),
            control: .init(audioPayloadsSentOnControlChannel: 0),
            remote: .init(),
            remoteResources: .init()
        ),
        verdict: .partial,
        notes: "legacy report schema characterization"
    )
    let object = try #require(
        JSONSerialization.jsonObject(with: report.prettyJSONData()) as? [String: Any]
    )
    var metrics = try #require(object["metrics"] as? [String: Any])
    for key in [
        "audioMetadataMessagesSent",
        "audioMetadataMessagesReceived",
        "timingProbePacketsSent",
        "timingProbePacketsReceived",
        "timingProbeMaxAgeMicroseconds"
    ] {
        metrics.removeValue(forKey: key)
    }
    var legacyObject = object
    legacyObject["metrics"] = metrics
    let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)

    let decoded = try DirectPeerSessionReport.decode(from: legacyData)

    #expect(decoded.metrics.audioMetadataMessagesSent == 0)
    #expect(decoded.metrics.audioMetadataMessagesReceived == 0)
    #expect(decoded.metrics.timingProbePacketsSent == 0)
    #expect(decoded.metrics.timingProbePacketsReceived == 0)
    #expect(decoded.metrics.timingProbeMaxAgeMicroseconds == 0)
    #expect(decoded.metrics.controlMessagesSent == report.metrics.controlMessagesSent)
}
