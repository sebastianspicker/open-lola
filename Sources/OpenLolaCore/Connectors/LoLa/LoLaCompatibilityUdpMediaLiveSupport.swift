// Provides focused support types and helpers for LoLa live UDP media sessions.
import Foundation

func enqueueLoLaLiveAudioIfNeeded(
    _ datagram: LoLaUdpMediaDatagram,
    audioBridge: LoLaCoreAudioLiveBridge?
) throws {
    guard datagram.stream == .audio, let audioBridge else {
        return
    }
    let decoded = try LoLaCompatibilityMediaCodec.decode(datagram.payload)
    guard let body = decoded.normalFragment?.body else {
        return
    }
    try audioBridge.enqueueLoLaPlaybackPayload(
        body.payload,
        hostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds
    )
}

func loLaLiveAudioSnapshotNote(_ snapshot: LoLaCoreAudioLiveSnapshot?) -> String {
    guard let snapshot else {
        return ""
    }
    return "Live Core Audio graph ran at \(snapshot.graphSampleRateHertz) Hz; captured "
        + "\(snapshot.capturedBlocks) block(s), dropped \(snapshot.droppedCapturedBlocksBeforeSend) stale "
        + "capture block(s) before send, prepared \(snapshot.preparedAudioPackets) "
        + "LoLa audio packet(s) for socket delivery, received \(snapshot.receivedAudioPackets) LoLa audio packet(s), "
        + "queued \(snapshot.queuedPlayoutBlocks) playout block(s), and dropped "
        + "\(snapshot.droppedPlayoutBlocks) playout block(s). "
}

func loLaAudioReceiveFreshnessNote(_ snapshot: LoLaAudioReceiveFreshnessSnapshot?) -> String {
    guard let snapshot else {
        return ""
    }
    return "Coalesced \(snapshot.coalescedStaleAudioDatagrams) stale received audio datagram(s) "
        + "before playout and rejected \(snapshot.rejectedAudioSourceDatagrams) audio datagram(s) "
        + "from a non-peer source. "
}

func requireLoLaBidirectionalTransmitReport(
    _ result: Result<LoLaCompatibilityMediaSessionReport, Error>?
) throws -> LoLaCompatibilityMediaSessionReport {
    guard let result else {
        throw ExternalConnectorSessionError.socketFailed(
            "udp media tx-rx did not run transmitter after binding receivers"
        )
    }
    return try result.get()
}

struct LoLaLiveTransmitAggregateError: LocalizedError, CustomStringConvertible {
    var errors: [Error]

    var description: String {
        let messages = errors.enumerated()
            .map { index, error in "\(index + 1): \(error)" }
            .joined(separator: "; ")
        return "LoLa live transmit failed with \(errors.count) error(s): \(messages)"
    }

    var errorDescription: String? {
        description
    }
}

struct LoLaLivePacketSendOutcome: Equatable {
    var sentBytes: Int
    var sentDatagrams: Int
    var droppedForBackpressure: Bool
    var abandonedAtDeadline: Bool
}

struct LoLaLivePacketSendRequest {
    var socket: Int32
    var peer: String
    var port: UInt16
    var deadline: DispatchTime
}

func sendLoLaLivePackets(
    _ packets: [LoLaCompatibilityMediaPacket],
    request: LoLaLivePacketSendRequest,
    nowNanoseconds: () -> UInt64 = { DispatchTime.now().uptimeNanoseconds },
    send: (Data, Int32, String, UInt16) throws -> LoLaUdpMediaSendResult = sendLoLaUdpMediaPayload
) throws -> LoLaLivePacketSendOutcome {
    var outcome = LoLaLivePacketSendOutcome(
        sentBytes: 0,
        sentDatagrams: 0,
        droppedForBackpressure: false,
        abandonedAtDeadline: false
    )
    for packet in packets {
        guard nowNanoseconds() < request.deadline.uptimeNanoseconds else {
            outcome.abandonedAtDeadline = true
            break
        }
        guard case let .sent(byteCount) = try send(
            packet.payload,
            request.socket,
            request.peer,
            request.port
        ) else {
            outcome.droppedForBackpressure = true
            break
        }
        outcome.sentBytes += byteCount
        outcome.sentDatagrams += 1
    }
    return outcome
}
