// Verifies that live packet sender accumulates complete send.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func livePacketSenderAccumulatesCompleteSend() throws {
    let packets = [livePacket([1, 2]), livePacket([3, 4, 5])]
    var sentPayloads: [Data] = []

    let outcome = try sendLoLaLivePackets(
        packets,
        request: livePacketSendRequest(),
        nowNanoseconds: { 0 },
        send: { payload, socket, peer, port in
            #expect(socket == 7)
            #expect(peer == "127.0.0.1")
            #expect(port == 50_004)
            sentPayloads.append(payload)
            return .sent(payload.count)
        }
    )

    #expect(sentPayloads == packets.map(\.payload))
    #expect(outcome == LoLaLivePacketSendOutcome(
        sentBytes: 5,
        sentDatagrams: 2,
        droppedForBackpressure: false,
        abandonedAtDeadline: false
    ))
}

@Test
func livePacketSenderStopsAfterBackpressure() throws {
    let packets = [livePacket([1]), livePacket([2])]
    var sendAttempts = 0

    let outcome = try sendLoLaLivePackets(
        packets,
        request: livePacketSendRequest(),
        nowNanoseconds: { 0 },
        send: { payload, _, _, _ in
            sendAttempts += 1
            return sendAttempts == 1 ? .sent(payload.count) : .wouldBlock
        }
    )

    #expect(sendAttempts == 2)
    #expect(outcome == LoLaLivePacketSendOutcome(
        sentBytes: 1,
        sentDatagrams: 1,
        droppedForBackpressure: true,
        abandonedAtDeadline: false
    ))
}

@Test
func livePacketSenderAbandonsAtDeadlineWithoutSending() throws {
    var sendAttempts = 0

    let outcome = try sendLoLaLivePackets(
        [livePacket([1])],
        request: livePacketSendRequest(),
        nowNanoseconds: { UInt64.max },
        send: { _, _, _, _ in
            sendAttempts += 1
            return .sent(1)
        }
    )

    #expect(sendAttempts == 0)
    #expect(outcome == LoLaLivePacketSendOutcome(
        sentBytes: 0,
        sentDatagrams: 0,
        droppedForBackpressure: false,
        abandonedAtDeadline: true
    ))
}

private func livePacketSendRequest() -> LoLaLivePacketSendRequest {
    LoLaLivePacketSendRequest(
        socket: 7,
        peer: "127.0.0.1",
        port: 50_004,
        deadline: DispatchTime(uptimeNanoseconds: 100)
    )
}

private func livePacket(_ payload: [UInt8]) -> LoLaCompatibilityMediaPacket {
    LoLaCompatibilityMediaPacket(
        stream: .audio,
        kind: .audioFragment,
        frameID: 0,
        fragmentIndex: 0,
        fragmentCount: 1,
        fragmentPayloadLength: nil,
        serializedMediaPayloadLength: nil,
        finalFragment: nil,
        payload: Data(payload)
    )
}
