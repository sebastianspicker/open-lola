// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

struct DirectPeerAVMetricsServiceResult: Equatable, Sendable {
    var metricsMessagesPublished = 0
    var metricsMessagesPublishFailures = 0
    var peerMetricsMessagesReceived = 0
    var peerMetricsMessagesDropped = 0
}

func serviceDirectPeerAVMetrics(
    runner: inout PeerSessionRunner,
    nextMetricsPublishTimeNanoseconds: inout UInt64,
    nowNanoseconds: UInt64,
    maxPeerMetricsDatagrams: Int = 32
) -> DirectPeerAVMetricsServiceResult {
    var result = DirectPeerAVMetricsServiceResult()
    var drained = 0
    while drained < maxPeerMetricsDatagrams {
        do {
            guard try runner.receivePeerMetricsIfAvailable() != nil else {
                break
            }
            result.peerMetricsMessagesReceived += 1
            drained += 1
        } catch is UdpMediaMalformedDatagramError {
            result.peerMetricsMessagesDropped += 1
            drained += 1
        } catch {
            result.peerMetricsMessagesDropped += 1
            break
        }
    }

    guard nowNanoseconds >= nextMetricsPublishTimeNanoseconds else {
        return result
    }
    do {
        try runner.publishMetricsSnapshot()
        result.metricsMessagesPublished += 1
    } catch {
        result.metricsMessagesPublishFailures += 1
    }
    let next = nowNanoseconds.addingReportingOverflow(directPeerAVMetricsSnapshotIntervalNanoseconds)
    nextMetricsPublishTimeNanoseconds = next.overflow ? UInt64.max : next.partialValue
    return result
}
