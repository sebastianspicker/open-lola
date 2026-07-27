// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Dispatch
import Foundation

public extension PeerSessionRunner {
    func transportMetrics() -> UdpMediaMetrics {
        var merged = audioTransport?.metrics ?? UdpMediaMetrics()
        if let videoMetrics = videoTransportMetrics {
            let audioPacketsReceived = merged.packetsReceived
            let audioJitterMicroseconds = merged.jitterMicroseconds
            merged.packetsSent += videoMetrics.packetsSent
            merged.packetsReceived += videoMetrics.packetsReceived
            merged.packetsLost += videoMetrics.packetsLost
            merged.latePackets += videoMetrics.latePackets
            merged.reorderedPackets += videoMetrics.reorderedPackets
            merged.duplicatePackets += videoMetrics.duplicatePackets
            merged.malformedPackets += videoMetrics.malformedPackets
            merged.jitterMicroseconds = combinedJitterMicroseconds(
                audioJitterMicroseconds: audioJitterMicroseconds,
                audioPacketsReceived: audioPacketsReceived,
                videoJitterMicroseconds: videoMetrics.jitterMicroseconds,
                videoPacketsReceived: videoMetrics.packetsReceived
            )
        }
        return merged
    }

    mutating func publishMetricsSnapshot() throws {
        guard let configuration = acceptedConfiguration else {
            throw PeerSessionRunnerError.missingAcceptedConfiguration
        }
        guard let metricsTransport else {
            throw PeerSessionRunnerError.missingMetricsTransport
        }
        guard let snapshot = transportMetrics().controlMessage(sessionID: configuration.sessionID).metrics else {
            throw PeerSessionRunnerError.unsupportedControlMessage(.metrics)
        }
        let sequenceNumber = UInt64(metrics.metricsMessagesSent + 1)
        let packet = UdpMediaPacket(
            header: UdpMediaPacketHeader(
                payloadType: .metrics,
                streamID: 1,
                sequenceNumber: sequenceNumber,
                timestampNanoseconds: DispatchTime.now().uptimeNanoseconds
            ),
            payload: try JSONEncoder().encode(snapshot)
        )
        try metricsTransport.send(packet)
        metrics.metricsMessagesSent += 1
    }

    @discardableResult
    mutating func receivePeerMetricsIfAvailable() throws -> SessionMetricsMessage? {
        guard let metricsTransport else {
            throw PeerSessionRunnerError.missingMetricsTransport
        }
        guard let packet = try metricsTransport.tryReceive(maxByteCount: peerSessionMediaReceiveByteBudget(
            acceptedConfiguration: acceptedConfiguration
        )) else {
            return nil
        }
        guard packet.header.payloadType == .metrics else {
            return nil
        }
        let remoteMetrics = try JSONDecoder().decode(SessionMetricsMessage.self, from: packet.payload)
        recordRemoteMetrics(remoteMetrics)
        return remoteMetrics
    }
}

private func combinedJitterMicroseconds(
    audioJitterMicroseconds: Double,
    audioPacketsReceived: Int,
    videoJitterMicroseconds: Double,
    videoPacketsReceived: Int
) -> Double {
    let totalPackets = audioPacketsReceived + videoPacketsReceived
    guard totalPackets > 0 else {
        return max(audioJitterMicroseconds, videoJitterMicroseconds)
    }
    return (
        audioJitterMicroseconds * Double(audioPacketsReceived)
            + videoJitterMicroseconds * Double(videoPacketsReceived)
    ) / Double(totalPackets)
}

extension PeerSessionRunner {
    var videoTransportMetrics: UdpMediaMetrics? {
        videoTransport?.metrics
    }

    mutating func recordRemoteMetrics(_ remoteMetrics: SessionMetricsMessage) {
        metrics.remoteMetricsMessagesReceived += 1
        metrics.remotePacketsLost = remoteMetrics.packetsLost
        metrics.remoteJitterMicroseconds = remoteMetrics.jitterMicroseconds
        metrics.remoteLatePackets = remoteMetrics.latePackets
        metrics.remoteCallbackDurationP99Microseconds = remoteMetrics.callbackDurationP99Microseconds
        metrics.remoteQueueDepthPackets = remoteMetrics.queueDepthPackets
        metrics.remoteCPUPercent = remoteMetrics.cpuPercent
        metrics.remoteMemoryResidentBytes = remoteMetrics.memoryResidentBytes
        metrics.remoteUnderruns = remoteMetrics.underruns
        metrics.remoteOverruns = remoteMetrics.overruns
        metrics.remoteVideoFramesDropped = remoteMetrics.videoFramesDropped
    }
}
