// Verifies nested direct-peer metrics retain all reported control and remote evidence fields.
import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionReportMetricsFlattensNestedTrafficControlAndRemoteEvidence() {
    let metrics = DirectPeerSessionReportMetrics(
        traffic: .init(
            controlMessagesSent: 3,
            packetsSent: 10,
            packetsReceived: 9,
            packetsLost: 1,
            jitterMicroseconds: 42.5,
            audioPacketsRouted: 8,
            videoPacketsRouted: 1,
            recoveryEvents: 2
        ),
        control: .init(
            audioPayloadsSentOnControlChannel: 0,
            controlDatagramsSent: 4,
            controlDatagramsReceived: 5,
            audioMetadataMessagesSent: 6,
            audioMetadataMessagesReceived: 7,
            timingProbePacketsSent: 8,
            timingProbePacketsReceived: 9,
            timingProbeMaxAgeMicroseconds: 10.5
        ),
        remote: .init(
            metricsMessagesSent: 11,
            remoteMetricsMessagesReceived: 12,
            remotePacketsLost: 13,
            remoteJitterMicroseconds: 14.5,
            remoteLatePackets: 15,
            remoteCallbackDurationP99Microseconds: 16.5,
            remoteQueueDepthPackets: 17,
            remoteCPUPercent: 18.5
        ),
        remoteResources: .init(
            remoteMemoryResidentBytes: 19,
            remoteUnderruns: 20,
            remoteOverruns: 21,
            remoteVideoFramesDropped: 22
        )
    )

    #expect(metrics.controlMessagesSent == 3)
    #expect(metrics.packetsSent == 10)
    #expect(metrics.packetsReceived == 9)
    #expect(metrics.packetsLost == 1)
    #expect(metrics.jitterMicroseconds == 42.5)
    #expect(metrics.audioPacketsRouted == 8)
    #expect(metrics.videoPacketsRouted == 1)
    #expect(metrics.recoveryEvents == 2)
    #expect(metrics.controlDatagramsSent == 4)
    #expect(metrics.controlDatagramsReceived == 5)
    #expect(metrics.audioMetadataMessagesSent == 6)
    #expect(metrics.audioMetadataMessagesReceived == 7)
    #expect(metrics.timingProbePacketsSent == 8)
    #expect(metrics.timingProbePacketsReceived == 9)
    #expect(metrics.timingProbeMaxAgeMicroseconds == 10.5)
    #expect(metrics.metricsMessagesSent == 11)
    #expect(metrics.remoteMetricsMessagesReceived == 12)
    #expect(metrics.remotePacketsLost == 13)
    #expect(metrics.remoteJitterMicroseconds == 14.5)
    #expect(metrics.remoteLatePackets == 15)
    #expect(metrics.remoteCallbackDurationP99Microseconds == 16.5)
    #expect(metrics.remoteQueueDepthPackets == 17)
    #expect(metrics.remoteCPUPercent == 18.5)
    #expect(metrics.remoteMemoryResidentBytes == 19)
    #expect(metrics.remoteUnderruns == 20)
    #expect(metrics.remoteOverruns == 21)
    #expect(metrics.remoteVideoFramesDropped == 22)
}
