// Verifies that audio routing assumption ledger classifies every fixed stereo assumption.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func audioRoutingAssumptionLedgerClassifiesEveryFixedStereoAssumption() {
    let requiredIDs: Set<String> = [
        "udp-pcm-v1-stereo-fixtures",
        "udp-pcm-localhost-smokes",
        "udp-pcm-default-probe-packet",
        "realtime-synthetic-stereo-map",
        "audio-loopback-synthetic-stereo-map",
        "route-certification-stereo-fixtures",
        "latency-tuning-stereo-candidates",
        "rme-fastest-path-channel-fit",
        "udp-pcm-v2-send-all-channel-fragments",
        "receiver-local-identity-mix",
        "rme-matrix-metadata-advisory"
    ]

    #expect(!AudioRoutingAssumptionLedger.entries.isEmpty)
    #expect(AudioRoutingAssumptionLedger.unclassifiedEntries.isEmpty)
    #expect(Set(AudioRoutingAssumptionLedger.entries.map(\.id)).isSuperset(of: requiredIDs))
}

@Test
func udpPcmV2FragmentPlannerCoversMtuBoundariesAndInvalidInputs() throws {
    let fragments = try planMultichannelFragments(
        totalChannelCount: 64,
        framesPerPacket: 32,
        mtuBytes: 1_200,
        maxFragments: 16
    )
    #expect(fragments.count == 8)
    #expect(fragments.map(\.channelOffset) == stride(from: 0, to: 64, by: 8).map { $0 })
    #expect(fragments.map(\.channelsInFragment).allSatisfy { $0 == 8 })
    #expect(fragments.map(\.payloadByteCount).allSatisfy { $0 == 1_024 })
    expectMultichannelFragmentMetadata(fragments)

    let boundaryFragments = try planMultichannelFragments(
        totalChannelCount: 3,
        framesPerPacket: 37,
        mtuBytes: 376,
        maxFragments: 3
    )
    #expect(!boundaryFragments.isEmpty)
    #expect(boundaryFragments.reduce(0) { $0 + $1.channelsInFragment } == 3)
    #expect(boundaryFragments.allSatisfy { $0.packetByteCount <= 376 })
    #expect(boundaryFragments.allSatisfy {
        UdpPcmV2PacketHeader.byteCount + $0.payloadByteCount == $0.packetByteCount
    })

    expectTooSmallMultichannelMtuRejected()
}

private func planMultichannelFragments(
    totalChannelCount: Int,
    framesPerPacket: Int,
    mtuBytes: Int,
    maxFragments: Int
) throws -> [UdpPcmV2ChannelFragmentPlan] {
    let audio = UdpPcmV2FragmentPlanRequest.AudioDescription(
        totalChannelCount: totalChannelCount,
        framesPerPacket: framesPerPacket,
        sampleRateHertz: 48_000,
        sampleFormat: .float32LittleEndian
    )
    let limits = UdpPcmV2FragmentPlanRequest.FragmentationLimits(
        maxTransmissionUnitBytes: mtuBytes,
        maxFragmentsPerDeadline: maxFragments
    )
    let metadata = UdpPcmV2FragmentPlanRequest.Metadata(
        metadataRevision: 3,
        packingMode: .interleavedChannelRange
    )
    let request = udpPcmV2FragmentPlanRequest(
        streamID: 7,
        audio: audio,
        fragmentationLimits: limits,
        metadata: metadata
    )
    return try UdpPcmV2FragmentPlanner.plan(request)
}

private func expectMultichannelFragmentMetadata(_ fragments: [UdpPcmV2ChannelFragmentPlan]) {
    for (index, fragment) in fragments.enumerated() {
        #expect(fragment.fragmentIndex == index)
        #expect(fragment.fragmentCount == fragments.count)
        #expect(fragment.packetByteCount <= 1_200)
        #expect(fragment.totalChannelCount == 64)
        #expect(fragment.sampleRateHertz == 48_000)
        #expect(fragment.metadataRevision == 3)
    }
}

private func expectTooSmallMultichannelMtuRejected() {
    let expectedError = UdpPcmV2FragmentPlanningError.mtuTooSmallForSingleChannel(
        mtuBytes: 200,
        requiredBytes: 208
    )
    #expect(throws: expectedError) {
        _ = try planMultichannelFragments(
            totalChannelCount: 64,
            framesPerPacket: 32,
            mtuBytes: 200,
            maxFragments: 16
        )
    }
}

@Test
func udpPcmV2PacketizerReassemblesAndRejectsIncompleteOrOverlappingDeadlines() throws {
    let mode = try multichannelSixtyFourChannelV2Mode()
    let payload = Data((0..<mode.sampleFormat.bytesPerSample
        * mode.framesPerPacket
        * mode.channelCount).map { UInt8($0 % 251) })

    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 17,
        senderFrameIndex: 544,
        senderHostTimeNanoseconds: 1_234_567,
        mode: mode
    )
    let reassembled = try UdpPcmV2FragmentReassembler.reassemble(Array(packets.reversed()))

    #expect(packets.count == 8)
    #expect(packets.map(\.header.fragmentIndex).sorted() == Array(0..<8).map(UInt16.init))
    #expect(packets.allSatisfy { $0.header.packetByteCount <= mode.maxTransmissionUnitBytes })
    #expect(reassembled.isComplete)
    #expect(reassembled.missingFragmentIndices.isEmpty)
    #expect(reassembled.payload == payload)

    let lostPayload = Data(repeating: 0x7F, count: mode.sampleFormat.bytesPerSample
        * mode.framesPerPacket
        * mode.channelCount)
    let lostPackets = try UdpPcmV2Packetizer.packetize(
        lostPayload,
        sequenceNumber: 18,
        senderFrameIndex: 576,
        senderHostTimeNanoseconds: 1_234_568,
        mode: mode
    )

    let incomplete = try UdpPcmV2FragmentReassembler.reassemble(Array(lostPackets.dropLast()))

    #expect(!incomplete.isComplete)
    #expect(incomplete.missingFragmentIndices == [7])
    #expect(incomplete.payload == nil)

    let overlappingPayload = Data(repeating: 0x42, count: mode.sampleFormat.bytesPerSample
        * mode.framesPerPacket
        * mode.channelCount)
    var overlappingPackets = try UdpPcmV2Packetizer.packetize(
        overlappingPayload,
        sequenceNumber: 19,
        senderFrameIndex: 608,
        senderHostTimeNanoseconds: 1_234_569,
        mode: mode
    )
    overlappingPackets[1].header.channelOffset = overlappingPackets[0].header.channelOffset

    #expect(throws: UdpPcmV2FragmentReassemblyError.inconsistentDeadline("channelCoverage")) {
        _ = try UdpPcmV2FragmentReassembler.reassemble(overlappingPackets)
    }
}
// swiftlint:disable function_body_length
@Test
func receiverMixRoutesIdentityPreparedStateAndPanBoundaries() throws {
    let mix = ReceiverMixSnapshot.identity(
        inputChannels: .defaultInput(count: 64), outputChannels: .defaultOutput(count: 64)
    )

    #expect(mix.routes.count == 64)
    #expect(!mix.requiresDestructiveDownmix)

    for (index, route) in mix.routes.enumerated() {
        #expect(route.sourceChannelIndex == index)
        #expect(route.destinationChannelIndex == index)
        #expect(route.gainDb == 0)
        #expect(!route.muted)
        #expect(route.pan == 0)
    }

    let customMix = ReceiverMixSnapshot(
        routes: [
            ReceiverMixRoute(
                sourceChannelIndex: 0,
                destinationChannelIndex: 0,
                gainDb: -6,
                muted: false,
                pan: -1
            ),
            ReceiverMixRoute(
                sourceChannelIndex: 1,
                destinationChannelIndex: 1,
                gainDb: 3,
                muted: true,
                pan: 1
            )
        ],
        requiresDestructiveDownmix: false
    )

    let prepared = try customMix.prepared(inputChannelCount: 2, outputChannelCount: 2)

    #expect(prepared.routes.count == 2)
    #expect(abs(prepared.routes[0].linearGain - 0.5011872336272722) < 0.000_001)
    #expect(prepared.routes[0].leftGain == prepared.routes[0].linearGain)
    #expect(prepared.routes[0].rightGain == 0)
    #expect(prepared.routes[0].pan == -1)
    #expect(prepared.routes[1].linearGain == 0)
    #expect(prepared.routes[1].leftGain == 0)
    #expect(prepared.routes[1].rightGain == 0)
    #expect(prepared.routes[1].pan == 1)

    let hiddenDownmix = ReceiverMixSnapshot.identity(
        inputChannels: .defaultInput(count: 64),
        outputChannels: .defaultOutput(count: 2)
    )
    #expect(hiddenDownmix.requiresDestructiveDownmix)
    #expect(throws: ReceiverMixSnapshotError.destructiveDownmixRequiresExplicitPolicy) {
        _ = try hiddenDownmix.prepared(inputChannelCount: 64, outputChannelCount: 2)
    }

    let boundaryMix = ReceiverMixSnapshot(
        routes: [
            ReceiverMixRoute(
                sourceChannelIndex: 0,
                destinationChannelIndex: 0,
                gainDb: 0,
                muted: false,
                pan: 1.0 + receiverMixPanTolerance / 2
            )
        ],
        requiresDestructiveDownmix: false
    )
    let boundaryPrepared = try boundaryMix.prepared(inputChannelCount: 1, outputChannelCount: 1)
    #expect(boundaryPrepared.routes.count == 1)

    let snapshot = rmeRoutingSnapshot(
        channelLabel: "input-1",
        destinationBusID: "main",
        gainDb: 0,
        pan: -1.0 - rmeMatrixPanTolerance / 2,
        routeLabel: "main"
    )
    try snapshot.validate()
    #expect(snapshot.routes[0].pan < -1.0)

    var store = try ReceiverMixSnapshotStore(
        initial: .identity(
            inputChannels: .defaultInput(count: 2),
            outputChannels: .defaultOutput(count: 2)
        ),
        inputChannelCount: 2,
        outputChannelCount: 2
    )
    let replacement = ReceiverMixSnapshot(
        routes: [
            ReceiverMixRoute(
                sourceChannelIndex: 0,
                destinationChannelIndex: 1,
                gainDb: -3,
                muted: false,
                pan: 0.25
            )
        ],
        requiresDestructiveDownmix: false
    )

    try store.replace(
        with: replacement,
        inputChannelCount: 2,
        outputChannelCount: 2
    )

    #expect(store.revision == 2)
    #expect(store.snapshot == replacement)
    #expect(store.prepared.routes.count == 1)
}
// swiftlint:enable function_body_length
