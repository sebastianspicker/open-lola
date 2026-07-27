// Provides integrated A/V operations used by the surrounding workflow, keeping this focused compatibility or analysis logic outside the primary execution path.
import Foundation

/// Applies deterministic packet loss and delay to integrated AV evidence for degradation tests.
public enum IntegratedAvNetworkDegradation {
    public static func apply(
        impairment: RxImpairmentSimulationResult,
        to report: VideoTransportReport
    ) -> VideoTransportReport {
        var degraded = report
        let summary = impairment.summary
        let frameLosses = summary.wholePacketLosses + summary.fragmentLosses
        let receiverDrops = summary.deadlineLatePackets + summary.reorderedPackets
        let additionalDrops = min(
            max(0, degraded.receiver.receivedFrames - degraded.receiver.droppedFrames - 1),
            receiverDrops
        )

        degraded.transmitted.packetsDropped += frameLosses
        degraded.reassembly = degradedReassemblyMetrics(
            degraded.reassembly,
            summary: summary
        )
        degraded.receiver.droppedFrames += additionalDrops
        degraded.receiver.displayedFrames = degraded.renderOutput?.backend == .metricsOnly
            ? 0
            : max(0, degraded.receiver.receivedFrames - degraded.receiver.droppedFrames)
        degraded.receiver.lateFrames += summary.deadlineLatePackets + summary.reorderedPackets
        degraded.frameAge = summary.packetAge
        degraded.degradation.triggeredBeforeAudioTargetChange = true
        degraded.degradation.triggeredBeforeAudioOrRouteImpact = true
        degraded.avSync = degradedAVSyncMetrics(
            degraded.avSync,
            summary: summary,
            videoFramesDropped: additionalDrops
        )
        degraded.performanceCounters?.frameAge = summary.packetAge
        degraded.notes += " Deterministic degraded-network overlay applied with packet loss, reorder, "
            + "and jitter before audio impact."
        return degraded
    }
}

private func degradedReassemblyMetrics(
    _ metrics: VideoReassemblyMetrics?,
    summary: RxImpairmentSimulationSummary
) -> VideoReassemblyMetrics? {
    guard var metrics else {
        return nil
    }
    let frameLosses = summary.wholePacketLosses + summary.fragmentLosses
    metrics.framesDroppedIncomplete += frameLosses
    metrics.missingFragments += frameLosses
    metrics.lateFragments += summary.deadlineLatePackets + summary.reorderedPackets
    metrics.duplicateFragments += summary.duplicatePackets
    return metrics
}

private func degradedAVSyncMetrics(
    _ metrics: AVSyncTimingMetrics?,
    summary: RxImpairmentSimulationSummary,
    videoFramesDropped: Int
) -> AVSyncTimingMetrics? {
    guard var metrics else {
        return nil
    }
    metrics.videoFrameAge = summary.packetAge
    metrics.avOffset = summary.packetAge
    metrics.jitter = UdpPcmPacketAgeMetrics(
        p50Microseconds: summary.jitter.p50Microseconds,
        p95Microseconds: summary.jitter.p95Microseconds,
        p99Microseconds: summary.jitter.p99Microseconds,
        maxMicroseconds: summary.jitter.maxMicroseconds
    )
    metrics.videoFramesDroppedForSync += videoFramesDropped
    metrics.offsetMeasurementMethod = "deterministic integrated AV degraded-network impairment overlay"
    return metrics
}
