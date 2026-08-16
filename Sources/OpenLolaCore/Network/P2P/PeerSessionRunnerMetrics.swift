// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Dispatch
import Foundation

let peerSessionMetricsStreamID: UInt32 = 1

public extension PeerSessionRunner {
    func transportMetrics() -> UdpMediaMetrics {
        var merged = audioTransport?.metrics ?? UdpMediaMetrics()
        if let videoMetrics = videoTransportMetrics {
            let audioPacketsReceived = merged.packetsReceived
            let audioJitterMicroseconds = merged.jitterMicroseconds
            merged.packetsSent = saturatingOpenLolaCounterSum(merged.packetsSent, videoMetrics.packetsSent)
            merged.packetsReceived = saturatingOpenLolaCounterSum(merged.packetsReceived, videoMetrics.packetsReceived)
            merged.packetsLost = saturatingOpenLolaCounterSum(merged.packetsLost, videoMetrics.packetsLost)
            merged.latePackets = saturatingOpenLolaCounterSum(merged.latePackets, videoMetrics.latePackets)
            merged.reorderedPackets = saturatingOpenLolaCounterSum(merged.reorderedPackets, videoMetrics.reorderedPackets)
            merged.duplicatePackets = saturatingOpenLolaCounterSum(merged.duplicatePackets, videoMetrics.duplicatePackets)
            merged.malformedPackets = saturatingOpenLolaCounterSum(merged.malformedPackets, videoMetrics.malformedPackets)
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
        let nextMetricsMessagesSent = saturatingOpenLolaCounterSum(metrics.metricsMessagesSent, 1)
        let packet = UdpMediaPacket(
            header: UdpMediaPacketHeader(
                payloadType: .metrics,
                streamID: peerSessionMetricsStreamID,
                sequenceNumber: UInt64(nextMetricsMessagesSent),
                timestampNanoseconds: DispatchTime.now().uptimeNanoseconds
            ),
            payload: try JSONEncoder().encode(snapshot)
        )
        try metricsTransport.send(packet)
        metrics.metricsMessagesSent = nextMetricsMessagesSent
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
        guard packet.header.payloadType == .metrics,
              packet.header.streamID == peerSessionMetricsStreamID else {
            recordRejectedRemoteMetrics()
            return nil
        }
        let remoteMetrics: SessionMetricsMessage
        do {
            remoteMetrics = try JSONDecoder().decode(SessionMetricsMessage.self, from: packet.payload)
        } catch {
            recordRejectedRemoteMetrics()
            return nil
        }
        guard acceptsControlSessionID(remoteMetrics.sessionID),
              remoteMetrics.hasValidMeasurements else {
            recordRejectedRemoteMetrics()
            return nil
        }
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
    let audioPacketCount = Double(audioPacketsReceived)
    let videoPacketCount = Double(videoPacketsReceived)
    let totalPackets = audioPacketCount + videoPacketCount
    guard totalPackets > 0 else {
        return max(audioJitterMicroseconds, videoJitterMicroseconds)
    }
    return (
        audioJitterMicroseconds * audioPacketCount
            + videoJitterMicroseconds * videoPacketCount
    ) / totalPackets
}

extension PeerSessionRunner {
    var videoTransportMetrics: UdpMediaMetrics? {
        videoTransport?.metrics
    }

    mutating func recordRemoteMetrics(_ remoteMetrics: SessionMetricsMessage) {
        guard remoteMetrics.hasValidMeasurements else {
            recordRejectedRemoteMetrics()
            return
        }
        metrics.remoteMetricsMessagesReceived = saturatingOpenLolaCounterSum(
            metrics.remoteMetricsMessagesReceived,
            1
        )
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

    mutating func recordRejectedRemoteMetrics() {
        remoteMetricsMessagesRejected = saturatingOpenLolaCounterSum(
            remoteMetricsMessagesRejected,
            1
        )
    }
}

extension SessionMetricsMessage {
    var hasValidMeasurements: Bool {
        packetsLost >= 0
            && jitterMicroseconds.isFinite
            && jitterMicroseconds >= 0
            && latePackets >= 0
            && callbackDurationP99Microseconds.isFinite
            && callbackDurationP99Microseconds >= 0
            && queueDepthPackets >= 0
            && cpuPercent.isFinite
            && cpuPercent >= 0
            && underruns >= 0
            && overruns >= 0
            && videoFramesDropped >= 0
    }
}
