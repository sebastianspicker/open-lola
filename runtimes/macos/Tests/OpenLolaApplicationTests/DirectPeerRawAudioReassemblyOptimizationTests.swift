// Verifies incremental direct-peer raw-audio reassembly against the public stateless oracle.
import Foundation
import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaTransport
@testable import OpenLolaApplication
import Testing

@Test func incrementalRawAudioReassemblyMatchesStatelessOracleForReorderedFragments() throws {
    let packets = try rawAudioPackets(sequenceNumber: 41)
    let reordered = packets.reversed()
    let expected = try UdpPcmV2FragmentReassembler.reassemble(Array(reordered))
    var state = DirectPeerOpenLolaRawAudioReassemblyState()
    var actual: DirectPeerOpenLolaRawAudioBlock?

    for packet in reordered {
        actual = try state.receive(packet) ?? actual
    }

    #expect(actual?.payload == expected.payload)
    #expect(actual?.senderFrameIndex == packets[0].header.senderFrameIndex)
    #expect(actual?.senderHostTimeNanoseconds == packets[0].header.senderHostTimeNanoseconds)
    #expect(state.pendingDeadlineCount == 0)
}

@Test func incrementalRawAudioReassemblyDefersPayloadFailureUntilDeadlineIsComplete() throws {
    var packets = try rawAudioPackets(sequenceNumber: 42)
    packets[0].payload.removeLast()
    let expectedError = #expect(throws: UdpPcmV2FragmentReassemblyError.self) {
        _ = try UdpPcmV2FragmentReassembler.reassemble(packets)
    }
    var state = DirectPeerOpenLolaRawAudioReassemblyState()

    for packet in packets.dropLast() {
        #expect(try state.receive(packet) == nil)
    }
    let actualError = #expect(throws: UdpPcmV2FragmentReassemblyError.self) {
        _ = try state.receive(packets[packets.count - 1])
    }

    #expect(String(describing: actualError) == String(describing: expectedError))
}

@Test func incrementalRawAudioReassemblyBoundsDeadlinesCountsDuplicatesAndRecoversAfterEviction() throws {
    let first = try rawAudioPackets(sequenceNumber: 1)
    let second = try rawAudioPackets(sequenceNumber: 2)
    let third = try rawAudioPackets(sequenceNumber: 3)
    var state = DirectPeerOpenLolaRawAudioReassemblyState(maxPendingDeadlines: 2)

    #expect(try state.receive(first[0]) == nil)
    #expect(try state.receive(first[0]) == nil)
    #expect(state.consumeDroppedDuplicateFragments() == 1)
    #expect(try state.receive(second[0]) == nil)
    #expect(try state.receive(third[0]) == nil)
    #expect(state.pendingDeadlineCount == 2)
    #expect(state.consumeDroppedIncompleteDeadlines() == 1)

    var completedSecond: DirectPeerOpenLolaRawAudioBlock?
    for packet in second.dropFirst() {
        completedSecond = try state.receive(packet) ?? completedSecond
    }
    #expect(completedSecond != nil)

    for packet in first.dropFirst() {
        #expect(try state.receive(packet) == nil)
    }
    #expect(try state.receive(first[0]) != nil)
}

@Test func incrementalRawAudioReassemblyReturnsPayloadOwnedPastStateReuse() throws {
    let first = try rawAudioPackets(sequenceNumber: 7)
    let second = try rawAudioPackets(sequenceNumber: 8)
    var state = DirectPeerOpenLolaRawAudioReassemblyState()
    var firstBlock: DirectPeerOpenLolaRawAudioBlock?
    for packet in first {
        firstBlock = try state.receive(packet) ?? firstBlock
    }
    let retainedPayload = firstBlock?.payload

    for packet in second {
        _ = try state.receive(packet)
    }

    #expect(firstBlock?.payload == retainedPayload)
    let oraclePayload = try UdpPcmV2FragmentReassembler.reassemble(first).payload
    #expect(firstBlock?.payload == oraclePayload)
}

private func rawAudioPackets(sequenceNumber: UInt64) throws -> [UdpPcmV2Packet] {
    let request = UdpPcmV2FragmentPlanRequest(.init(
        streamID: 1,
        audio: .init(
            totalChannelCount: 8,
            framesPerPacket: 8,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian
        ),
        fragmentationLimits: .init(maxTransmissionUnitBytes: 144, maxFragmentsPerDeadline: 16),
        metadata: .init(metadataRevision: 3, packingMode: .interleavedChannelRange)
    ))
    let fragments = try UdpPcmV2FragmentPlanner.plan(request)
    let mode = AudioTransportMode(
        transport: .init(
            protocolVersion: .udpPcmV2,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct,
            maxTransmissionUnitBytes: 144
        ),
        format: .init(
            sampleRateHertz: 48_000,
            framesPerPacket: 8,
            channelCount: 8,
            sampleFormat: .float32LittleEndian
        ),
        layout: .init(
            channelOrder: AudioChannelSet.defaultInput(count: 8).sortedByStableSourceIndex,
            fragments: fragments
        )
    )
    let payload = Data((0..<mode.payloadByteCount).map {
        UInt8(truncatingIfNeeded: Int(sequenceNumber) &+ $0)
    })
    return try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: sequenceNumber,
        senderFrameIndex: sequenceNumber * 8,
        senderHostTimeNanoseconds: 1_000 + sequenceNumber,
        mode: mode
    )
}
