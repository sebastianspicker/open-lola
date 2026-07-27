// Shared peer session avraw audio helpers keep related tests deterministic and focused on their contract.
import Foundation
import Testing

@testable import OpenLolaCore

func assertRawAudioReassemblyCompletes(payload: Data, mode: AudioTransportMode) throws {
 var state = DirectPeerOpenLolaRawAudioReassemblyState()
 let packets = try UdpPcmV2Packetizer.packetize(
 payload,
 sequenceNumber: 11,
 senderFrameIndex: 352,
 senderHostTimeNanoseconds: 99_000,
 mode: mode
 )

 #expect(packets.count > 1)
 for packet in packets.dropLast() {
 #expect(try state.receive(packet) == nil)
 }
 let lastPacket = try #require(packets.last)
 let block = try #require(try state.receive(lastPacket))

 #expect(block.payload == payload)
 #expect(block.senderFrameIndex == 352)
 #expect(block.senderHostTimeNanoseconds == 99_000)
}

func assertRawAudioReassemblyCountsDuplicateFlood(payload: Data, mode: AudioTransportMode) throws {
 var state = DirectPeerOpenLolaRawAudioReassemblyState()
 let packets = try UdpPcmV2Packetizer.packetize(
 payload,
 sequenceNumber: 18,
 senderFrameIndex: 576,
 senderHostTimeNanoseconds: 99_007,
 mode: mode
 )
 let firstFragment = try #require(packets.first)
 #expect(try state.receive(firstFragment) == nil)
 for _ in 0..<10_000 {
 #expect(try state.receive(firstFragment) == nil)
 }
 #expect(state.consumeDroppedDuplicateFragments() == 10_000)
 for (index, packet) in packets.dropFirst().dropLast().enumerated() {
 #expect(index >= 0)
 #expect(try state.receive(packet) == nil)
 }
 let lastPacket = try #require(packets.last)
 let block = try #require(try state.receive(lastPacket))
 let expectedSenderFrameIndex: UInt64 = 576
 #expect(block.payload == payload)
 #expect(block.senderFrameIndex == expectedSenderFrameIndex)
 #expect(state.consumeDroppedDuplicateFragments() == 0)
}

func assertRawAudioReassemblyRejectsOversizedFragmentCount(payload: Data, mode: AudioTransportMode) throws {
 var state = DirectPeerOpenLolaRawAudioReassemblyState(maxFragmentCount: 2)
 var packet = try #require(UdpPcmV2Packetizer.packetize(
 payload,
 sequenceNumber: 12,
 senderFrameIndex: 384,
 senderHostTimeNanoseconds: 99_001,
 mode: mode
 ).first)
 packet.header.fragmentCount = UInt16.max

 #expect(throws: UdpPcmV2FragmentReassemblyError.fragmentCountExceedsLimit(actual: UInt16.max, max: 2)) {
 _ = try state.receive(packet)
 }
}

func assertRawAudioReassemblyDropsOldIncompleteDeadline(payload: Data, mode: AudioTransportMode) throws {
 var state = DirectPeerOpenLolaRawAudioReassemblyState(maxPendingDeadlines: 1)
 let firstDeadline = try UdpPcmV2Packetizer.packetize(
 payload,
 sequenceNumber: 13,
 senderFrameIndex: 416,
 senderHostTimeNanoseconds: 99_002,
 mode: mode
 )
 let secondDeadline = try UdpPcmV2Packetizer.packetize(
 payload,
 sequenceNumber: 14,
 senderFrameIndex: 448,
 senderHostTimeNanoseconds: 99_003,
 mode: mode
 )

 #expect(try state.receive(try #require(firstDeadline.first)) == nil)
 #expect(state.consumeDroppedIncompleteDeadlines() == 0)
 #expect(try state.receive(try #require(secondDeadline.first)) == nil)
 #expect(state.consumeDroppedIncompleteDeadlines() == 1)
}

func assertRawAudioReassemblyKeepsReorderedPendingDeadlines(mode: AudioTransportMode) throws {
 var state = DirectPeerOpenLolaRawAudioReassemblyState(maxPendingDeadlines: 2)
 let firstPayload = directPeerRawAudioPayload(mode: mode, repeating: 0x7d)
 let secondPayload = directPeerRawAudioPayload(mode: mode, repeating: 0x7e)
 let firstDeadline = try directPeerRawAudioPackets(
 payload: firstPayload,
 sequenceNumber: 16,
 senderFrameIndex: 512,
 senderHostTimeNanoseconds: 99_005,
 mode: mode
 )
 let secondDeadline = try directPeerRawAudioPackets(
 payload: secondPayload,
 sequenceNumber: 17,
 senderFrameIndex: 544,
 senderHostTimeNanoseconds: 99_006,
 mode: mode
 )

 #expect(firstDeadline.count > 1)
 #expect(secondDeadline.count > 1)
 #expect(try state.receive(try #require(firstDeadline.first)) == nil)
 #expect(try state.receive(try #require(secondDeadline.first)) == nil)
 let firstBlock = try receiveRemainingRawAudioFragments(firstDeadline, state: &state)
 let secondBlock = try receiveRemainingRawAudioFragments(secondDeadline, state: &state)

 #expect(firstBlock.payload == firstPayload)
 #expect(secondBlock.payload == secondPayload)
 #expect(state.consumeDroppedIncompleteDeadlines() == 0)
}

func assertRawAudioReassemblyFlushesIncomplete(payload: Data, mode: AudioTransportMode) throws {
 var state = DirectPeerOpenLolaRawAudioReassemblyState()
 let packets = try UdpPcmV2Packetizer.packetize(
 payload,
 sequenceNumber: 15,
 senderFrameIndex: 480,
 senderHostTimeNanoseconds: 99_004,
 mode: mode
 )

    #expect(try state.receive(try #require(packets.first)) == nil)
    #expect(state.flushIncomplete() == 1)
    #expect(state.flushIncomplete() == 0)
}

func directPeerFragmentedRawAudioMode() throws -> AudioTransportMode {
    try udpPcmV2TestMode(
        channelCount: 64,
        metadataRevision: 1
    )
}

func directPeerRawAudioPayload(mode: AudioTransportMode, repeating byte: UInt8) -> Data {
 Data(repeating: byte, count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample)
}

func directPeerRawAudioPackets(
 payload: Data,
 sequenceNumber: UInt64,
 senderFrameIndex: UInt64,
 senderHostTimeNanoseconds: UInt64,
 mode: AudioTransportMode
) throws -> [UdpPcmV2Packet] {
 try UdpPcmV2Packetizer.packetize(
 payload,
 sequenceNumber: sequenceNumber,
 senderFrameIndex: senderFrameIndex,
 senderHostTimeNanoseconds: senderHostTimeNanoseconds,
 mode: mode
 )
}

func receiveRemainingRawAudioFragments(
 _ packets: [UdpPcmV2Packet],
 state: inout DirectPeerOpenLolaRawAudioReassemblyState
) throws -> DirectPeerOpenLolaRawAudioBlock {
 for packet in packets.dropFirst().dropLast() {
 #expect(try state.receive(packet) == nil)
 }
 let lastPacket = try #require(packets.last)
 return try #require(try state.receive(lastPacket))
}
