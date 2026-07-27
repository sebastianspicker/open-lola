// Verifies that app latency hero metrics omit zero-valued measurements.
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
        )
    ])

    #expect(metrics != nil)
    #expect(metrics?.jitterMs == nil)
    #expect(metrics?.audioLatencyMs == nil)
    #expect(metrics?.packetLossPercent == nil)
}

@Test
func appLatencyHeroMetricsUsesWorstPeerAudioP99WithRecordedEvidenceProvenance() {
    let metrics = AppLatencyHeroMetrics.make(from: [
        appDirectPeerSessionReport(
            id: "lower-p99-peer-report",
            packetsReceived: 100,
            packetsLost: 0,
            jitterMicroseconds: 400,
            latencyMicroseconds: 2_700
        ),
        appDirectPeerSessionReport(
            id: "higher-p99-peer-report",
            packetsReceived: 100,
            packetsLost: 0,
            jitterMicroseconds: 700,
            latencyMicroseconds: 5_100
        )
    ])

    #expect(AppLatencyHeroMetrics.audioLatencyMetricLabel == "Worst-peer audio p99")
    #expect(
        AppLatencyHeroMetrics.audioLatencyMetricProvenance
            == "Maximum audio p99 across loaded peer reports"
    )
    #expect(metrics?.audioLatencyMs == 5.1)
}

@Test
func appSessionStateOnlyAnimatesWhileConnectingOrValidating() {
    #expect(AppSessionState.connecting.isAnimated)
    #expect(AppSessionState.validating.isAnimated)

    for state in AppSessionState.allCases where state != .connecting && state != .validating {
        #expect(!state.isAnimated)
    }
}
