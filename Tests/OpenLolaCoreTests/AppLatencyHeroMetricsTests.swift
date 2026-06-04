import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func appLatencyHeroMetricsMakeIgnoresZeroValuedMeasurements() {
    let metrics = AppLatencyHeroMetrics.make(from: [
        appDirectPeerSessionReport(
            id: "zero-valued-peer-report",
            packetsReceived: 0,
            packetsLost: 0,
            jitterMicroseconds: 0,
            latencyMicroseconds: 0
        ),
    ])

    #expect(metrics != nil)
    #expect(metrics?.jitterMs == nil)
    #expect(metrics?.audioLatencyMs == nil)
    #expect(metrics?.packetLossPercent == nil)
}
