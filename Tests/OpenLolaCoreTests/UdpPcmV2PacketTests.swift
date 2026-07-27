// Verifies that UDP PCM v2 fragment planning carries metadata.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func udpPcmV2FragmentPlanningCarriesMetadata() throws {
    let fragments = try UdpPcmV2FragmentPlanner.plan(standardUdpPcmV2PlanRequest())
    let mode = udpPcmV2MetadataMode(fragments: fragments)
    let payload = Data((0..<mode.framesPerPacket
        * mode.channelCount
        * mode.sampleFormat.bytesPerSample).map { UInt8($0 % 251) })

    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 12,
        senderFrameIndex: 384,
        senderHostTimeNanoseconds: 1_000,
        mode: mode
    )

    #expect(packets.count == 2)
    #expect(packets.map(\.header.streamID) == [5, 5])
    #expect(packets.map(\.header.metadataRevision) == [77, 77])
    #expect(packets.map(\.header.channelOffset) == [0, 8])
    #expect(packets.map(\.header.channelsInFragment) == [8, 8])
    #expect(packets.map(\.header.fragmentIndex) == [0, 1])
}

private func standardUdpPcmV2PlanRequest() -> UdpPcmV2FragmentPlanRequest {
    udpPcmV2FragmentPlanRequest(
        streamID: 5,
        audio: .init(
            totalChannelCount: 16,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian
        ),
        fragmentationLimits: .init(
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16
        ),
        metadata: .init(
            metadataRevision: 77,
            packingMode: .interleavedChannelRange
        )
    )
}

private func udpPcmV2MetadataMode(
    fragments: [UdpPcmV2ChannelFragmentPlan]
) -> AudioTransportMode {
    v2TestAudioTransportMode(
        .init(
            streamID: 5,
            channelCount: 16,
            sampleFormat: .float32LittleEndian,
            metadataRevision: 77
        ),
        fragments: fragments
    )
}

@Test
func udpPcmV2FragmentPlanValuesRemainCodableAfterInputMigration() throws {
    let request = standardUdpPcmV2PlanRequest()
    try expectFlatFragmentPlanRequestRoundTrip(request)

    let fragments = try UdpPcmV2FragmentPlanner.plan(request)
    try expectFlatFragmentPlanRoundTrip(fragments)
}

private func expectFlatFragmentPlanRequestRoundTrip(
    _ request: UdpPcmV2FragmentPlanRequest
) throws {
    let requestData = try JSONEncoder().encode(request)
    #expect(try JSONDecoder().decode(UdpPcmV2FragmentPlanRequest.self, from: requestData) == request)
    let requestJSON = try #require(
        try JSONSerialization.jsonObject(with: requestData) as? [String: Any]
    )
    #expect(Set(requestJSON.keys) == [
        "streamID",
        "totalChannelCount",
        "framesPerPacket",
        "sampleRateHertz",
        "sampleFormat",
        "maxTransmissionUnitBytes",
        "maxFragmentsPerDeadline",
        "metadataRevision",
        "packingMode"
    ])
}

private func expectFlatFragmentPlanRoundTrip(
    _ fragments: [UdpPcmV2ChannelFragmentPlan]
) throws {
    let fragmentData = try JSONEncoder().encode(fragments)
    #expect(try JSONDecoder().decode([UdpPcmV2ChannelFragmentPlan].self, from: fragmentData) == fragments)
    let fragmentJSON = try #require(
        try JSONSerialization.jsonObject(with: fragmentData) as? [[String: Any]]
    )
    #expect(fragmentJSON.allSatisfy { $0["audio"] == nil && $0["channelRange"] == nil })
}

@Test
func udpPcmV2FragmentPlanningRejectsBytesPerChannelOverflow() {
    #expect(throws: UdpPcmV2FragmentPlanningError.arithmeticOverflow("bytesPerChannel")) {
        _ = try UdpPcmV2FragmentPlanner.plan(
            udpPcmV2FragmentPlanRequest(
                streamID: 1,
                audio: .init(
                    totalChannelCount: 2,
                    framesPerPacket: Int.max,
                    sampleRateHertz: 48_000,
                    sampleFormat: .float32LittleEndian
                ),
                fragmentationLimits: .init(
                    maxTransmissionUnitBytes: Int.max,
                    maxFragmentsPerDeadline: 16
                ),
                metadata: .init(
                    metadataRevision: 0,
                    packingMode: .interleavedChannelRange
                )
            )
        )
    }

}

@Test
func udpPcmV2FragmentPlanningRejectsPlannedChannelCapacityOverflow() {
    #expect(throws: UdpPcmV2FragmentPlanningError.arithmeticOverflow("plannedChannelCapacity")) {
        _ = try UdpPcmV2FragmentPlanner.plan(
            udpPcmV2FragmentPlanRequest(
                streamID: 1,
                audio: .init(
                    totalChannelCount: Int.max,
                    framesPerPacket: 1,
                    sampleRateHertz: 48_000,
                    sampleFormat: .int16LittleEndian
                ),
                fragmentationLimits: .init(
                    maxTransmissionUnitBytes: UdpPcmV2PacketHeader.byteCount + 4,
                    maxFragmentsPerDeadline: Int.max
                ),
                metadata: .init(
                    metadataRevision: 0,
                    packingMode: .interleavedChannelRange
                )
            )
        )
    }

}

@Test
func udpPcmV2PacketRoundTripRejectsMalformedWireDataAndUsesCheckedReaders() throws {
    let packet = validUdpPcmV2Packet()

    let decoded = try UdpPcmV2Packet.decode(packet.encoded())

    #expect(decoded == packet)

    let encoded = try validUdpPcmV2Packet().encoded()

    for byteCount in 0..<UdpPcmV2PacketHeader.byteCount {
        #expect(throws: UdpPcmV2PacketError.truncatedPacket(byteCount: byteCount)) {
            _ = try UdpPcmV2Packet.decode(encoded.prefix(byteCount))
        }
    }

    var invalidHeaderGuard = try validUdpPcmV2Packet().encoded()
    invalidHeaderGuard[64] = 0

    #expect(throws: UdpPcmV2PacketError.invalidHeaderGuard) {
        _ = try UdpPcmV2Packet.decode(invalidHeaderGuard)
    }

    var shortPayload = try validUdpPcmV2Packet().encoded()
    shortPayload.removeLast()

    #expect(throws: UdpPcmV2PacketError.payloadLengthMismatch(expected: 128, actual: 127)) {
        _ = try UdpPcmV2Packet.decode(shortPayload)
    }

    var invalidMagic = try validUdpPcmV2Packet().encoded()
    invalidMagic[0] = UInt8(ascii: "X")

    #expect(throws: UdpPcmV2PacketError.invalidMagic) {
        _ = try UdpPcmV2Packet.decode(invalidMagic)
    }

    var invalidChannelCount = try validUdpPcmV2Packet().encoded()
    invalidChannelCount[44] = 0
    invalidChannelCount[45] = 0

    #expect(throws: UdpPcmV2PacketError.invalidTotalChannelCount(0)) {
        _ = try UdpPcmV2Packet.decode(invalidChannelCount)
    }

    var invalidFragmentIndex = try validUdpPcmV2Packet().encoded()
    invalidFragmentIndex[50] = 1
    invalidFragmentIndex[51] = 0
    invalidFragmentIndex[52] = 1
    invalidFragmentIndex[53] = 0

    #expect(throws: UdpPcmV2PacketError.invalidFragmentIndex(index: 1, count: 1)) {
        _ = try UdpPcmV2Packet.decode(invalidFragmentIndex)
    }

}

@Test
func udpPcmV2ReassemblerAndPacketizerProtectFragmentCopyBounds() throws {
    let mode = try sixteenChannelMode()
    let payload = Data((0..<mode.framesPerPacket
        * mode.channelCount
        * mode.sampleFormat.bytesPerSample).map { UInt8($0 % 251) })
    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 77,
        senderFrameIndex: 2_464,
        senderHostTimeNanoseconds: 10_000,
        mode: mode
    )

    let result = try UdpPcmV2FragmentReassembler.reassemble([
        packets[1],
        packets[0],
        packets[1]
    ])

    #expect(result.sequenceNumber == 77)
    #expect(result.missingFragmentIndices.isEmpty)
    #expect(result.duplicateFragmentIndices == [1])
    #expect(result.payload == payload)

    let mismatchPayload = Data(repeating: 1, count: mode.framesPerPacket
        * mode.channelCount
        * mode.sampleFormat.bytesPerSample)
    var mismatchPackets = try UdpPcmV2Packetizer.packetize(
        mismatchPayload,
        sequenceNumber: 78,
        senderFrameIndex: 2_496,
        senderHostTimeNanoseconds: 11_000,
        mode: mode
    )
    mismatchPackets[1].header.streamID = 99

    #expect(throws: UdpPcmV2FragmentReassemblyError.inconsistentDeadline("streamID")) {
        _ = try UdpPcmV2FragmentReassembler.reassemble(mismatchPackets)
    }
}

@Test
func udpPcmV2ReassemblerRejectsInvalidFragmentPayload() throws {
    let packet = UdpPcmV2Packet(
        header: UdpPcmV2PacketHeader(
            stream: .init(streamID: 5),
            timing: .init(
                sequenceNumber: 79,
                senderFrameIndex: 2_528,
                senderHostTimeNanoseconds: 12_000
            ),
            format: .init(
                sampleRateHertz: 48_000,
                framesPerPacket: 32,
                totalChannelCount: 16,
                sampleFormat: .float32LittleEndian,
                metadataRevision: 77,
                packingMode: .interleavedChannelRange
            ),
            fragment: .init(
                channelOffset: 15,
                channelsInFragment: 2,
                fragmentIndex: 0,
                fragmentCount: 1
            )
        ),
        payload: Data(repeating: 1, count: 32 * 2 * 4)
    )

    #expect(throws: UdpPcmV2FragmentReassemblyError.invalidFragmentPayload(index: 0)) {
        _ = try UdpPcmV2FragmentReassembler.reassemble([packet])
    }
}

@Test
func udpPcmV2PacketizerRejectsInvalidFragmentCopyBounds() throws {
    var invalidCopyMode = try sixteenChannelMode()
    let invalidCopyAudio = UdpPcmV2FragmentPlanRequest.AudioDescription(
        totalChannelCount: 16,
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        sampleFormat: .float32LittleEndian
    )
    let invalidCopyMetadata = UdpPcmV2FragmentPlanRequest.Metadata(
        metadataRevision: 77,
        packingMode: .interleavedChannelRange
    )
    let invalidCopyPlanInput = UdpPcmV2ChannelFragmentPlan.Input(
        streamID: 5,
        audio: invalidCopyAudio,
        metadata: invalidCopyMetadata,
        channelRange: .init(offset: 15, count: 2),
        position: .init(index: 0, count: 1),
        byteCounts: .init(
            payload: 32 * 2 * 4,
            packet: UdpPcmV2PacketHeader.byteCount + (32 * 2 * 4)
        )
    )
    invalidCopyMode.fragments = [
        UdpPcmV2ChannelFragmentPlan(invalidCopyPlanInput)
    ]
    let invalidCopyPayload = Data(repeating: 1, count: invalidCopyMode.framesPerPacket
        * invalidCopyMode.channelCount
        * invalidCopyMode.sampleFormat.bytesPerSample)

    #expect(throws: UdpPcmV2PacketizerError.fragmentPlanMismatch("fragmentPayloadBounds")) {
        _ = try UdpPcmV2Packetizer.packetize(
            invalidCopyPayload,
            sequenceNumber: 80,
            senderFrameIndex: 2_560,
            senderHostTimeNanoseconds: 13_000,
            mode: invalidCopyMode
        )
    }

}
private func sixteenChannelMode() throws -> AudioTransportMode {
    let fragments = try UdpPcmV2FragmentPlanner.plan(standardUdpPcmV2PlanRequest())
    return udpPcmV2MetadataMode(fragments: fragments)
}

private func validUdpPcmV2Packet() -> UdpPcmV2Packet {
    UdpPcmV2Packet(
        header: UdpPcmV2PacketHeader(
            stream: .init(streamID: 7),
            timing: .init(
                sequenceNumber: 42,
                senderFrameIndex: 1_344,
                senderHostTimeNanoseconds: 9_000
            ),
            format: .init(
                sampleRateHertz: 48_000,
                framesPerPacket: 32,
                totalChannelCount: 2,
                sampleFormat: .int16LittleEndian,
                metadataRevision: 3,
                packingMode: .interleavedChannelRange
            ),
            fragment: .init(
                channelOffset: 0,
                channelsInFragment: 2,
                fragmentIndex: 0,
                fragmentCount: 1
            )
        ),
        payload: Data((0..<128).map(UInt8.init))
    )
}
