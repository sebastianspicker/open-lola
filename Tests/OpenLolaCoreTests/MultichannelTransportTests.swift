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
        "rme-matrix-metadata-advisory",
    ]

    #expect(!AudioRoutingAssumptionLedger.entries.isEmpty)
    #expect(AudioRoutingAssumptionLedger.unclassifiedEntries.isEmpty)
    #expect(Set(AudioRoutingAssumptionLedger.entries.map(\.id)).isSuperset(of: requiredIDs))
}

@Test
func audioTransportModeExposesSharedPayloadByteCount() throws {
    let mode = try sixtyFourChannelV2Mode()

    #expect(mode.payloadByteCount == 32 * 64 * UdpPcmSampleFormat.float32LittleEndian.bytesPerSample)
}

@Test
func multichannelNegotiationAcceptsSixtyFourChannelUdpPcmV2Mode() throws {
    let sender = AudioTransportCapabilities(
        supportedProtocolVersions: [.udpPcmV2, .udpPcmV1],
        channelSet: AudioChannelSet(
            channels: (0..<64).reversed().map { index in
                AudioChannelDescriptor(
                    stableSourceIndex: index,
                    label: "madi-input-\(index + 1)"
                )
            }
        ),
        sampleRatesHertz: [48_000, 96_000],
        framesPerPacketOptions: [16, 32],
        sampleFormats: [.float32LittleEndian, .int16LittleEndian],
        maxTransmissionUnitBytes: 1_200,
        maxFragmentsPerDeadline: 16,
        latencyProfiles: [.safeLowLatency],
        rxBufferProfiles: [.direct],
        supportsMatrixMetadata: false
    )
    let receiver = AudioTransportCapabilities(
        supportedProtocolVersions: [.udpPcmV2],
        channelSet: .defaultOutput(count: 64),
        sampleRatesHertz: [48_000],
        framesPerPacketOptions: [32],
        sampleFormats: [.float32LittleEndian],
        maxTransmissionUnitBytes: 1_200,
        maxFragmentsPerDeadline: 16,
        latencyProfiles: [.safeLowLatency],
        rxBufferProfiles: [.direct],
        supportsMatrixMetadata: false
    )

    let result = try AudioTransportNegotiation.negotiate(
        sender: sender,
        receiver: receiver,
        request: AudioTransportModeRequest(
            preferredProtocolVersion: .udpPcmV2,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 64,
            sampleFormat: .float32LittleEndian,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct
        )
    )

    #expect(result.mode.protocolVersion == .udpPcmV2)
    #expect(result.mode.channelCount == 64)
    #expect(result.mode.sampleFormat == .float32LittleEndian)
    #expect(result.mode.fragments.count == 8)
    #expect(result.mode.channelOrder.map(\.stableSourceIndex) == Array(0..<64))
    #expect(result.warnings.isEmpty)
}

@Test
func multichannelNegotiationFallsBackToExplicitStereoV1Compatibility() throws {
    let sender = AudioTransportCapabilities(
        supportedProtocolVersions: [.udpPcmV2, .udpPcmV1],
        channelSet: .defaultInput(count: 64),
        sampleRatesHertz: [48_000],
        framesPerPacketOptions: [32],
        sampleFormats: [.float32LittleEndian, .int16LittleEndian],
        maxTransmissionUnitBytes: 1_200,
        maxFragmentsPerDeadline: 16,
        latencyProfiles: [.safeLowLatency],
        rxBufferProfiles: [.direct],
        supportsMatrixMetadata: true
    )
    let receiver = AudioTransportCapabilities(
        supportedProtocolVersions: [.udpPcmV1],
        channelSet: .defaultOutput(count: 2),
        sampleRatesHertz: [48_000],
        framesPerPacketOptions: [32],
        sampleFormats: [.int16LittleEndian],
        maxTransmissionUnitBytes: 1_200,
        maxFragmentsPerDeadline: 1,
        latencyProfiles: [.safeLowLatency],
        rxBufferProfiles: [.direct],
        supportsMatrixMetadata: false
    )

    let result = try AudioTransportNegotiation.negotiate(
        sender: sender,
        receiver: receiver,
        request: AudioTransportModeRequest(
            preferredProtocolVersion: .udpPcmV2,
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 64,
            sampleFormat: .float32LittleEndian,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct
        )
    )

    #expect(result.mode.protocolVersion == .udpPcmV1)
    #expect(result.mode.channelCount == 2)
    #expect(result.mode.sampleFormat == .int16LittleEndian)
    #expect(result.mode.fragments.isEmpty)
    #expect(result.mode.channelOrder.map(\.stableSourceIndex) == [0, 1])
    #expect(result.warnings == [
        .preferredV2NotAvailable,
        .fallbackToStereoV1(requestedChannelCount: 64),
    ])
}

@Test
func udpPcmV2FragmentPlannerKeepsSixtyFourChannelDeadlineUnderMtu() throws {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: 7,
            totalChannelCount: 64,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian,
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            metadataRevision: 3,
            packingMode: .interleavedChannelRange
        )
    )

    #expect(fragments.count == 8)
    #expect(fragments.map(\.channelOffset) == stride(from: 0, to: 64, by: 8).map { $0 })
    #expect(fragments.map(\.channelsInFragment).allSatisfy { $0 == 8 })
    #expect(fragments.map(\.payloadByteCount).allSatisfy { $0 == 1_024 })

    for (index, fragment) in fragments.enumerated() {
        #expect(fragment.fragmentIndex == index)
        #expect(fragment.fragmentCount == fragments.count)
        #expect(fragment.packetByteCount <= 1_200)
        #expect(fragment.totalChannelCount == 64)
        #expect(fragment.sampleRateHertz == 48_000)
        #expect(fragment.metadataRevision == 3)
    }
}

@Test
func udpPcmV2FragmentPlannerKeepsEveryPlannedPacketWithinMtuAtBoundary() throws {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: 7,
            totalChannelCount: 3,
            framesPerPacket: 37,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian,
            maxTransmissionUnitBytes: 376,
            maxFragmentsPerDeadline: 3,
            metadataRevision: 3,
            packingMode: .interleavedChannelRange
        )
    )

    #expect(!fragments.isEmpty)
    #expect(fragments.reduce(0) { $0 + $1.channelsInFragment } == 3)
    #expect(fragments.allSatisfy { $0.packetByteCount <= 376 })
    #expect(fragments.allSatisfy { UdpPcmV2PacketHeader.byteCount + $0.payloadByteCount == $0.packetByteCount })
}

@Test
func udpPcmV2FragmentPlannerRejectsMtuTooSmallForOneChannel() {
    #expect(throws: UdpPcmV2FragmentPlanningError.mtuTooSmallForSingleChannel(
        mtuBytes: 200,
        requiredBytes: 208
    )) {
        _ = try UdpPcmV2FragmentPlanner.plan(
            UdpPcmV2FragmentPlanRequest(
                streamID: 7,
                totalChannelCount: 64,
                framesPerPacket: 32,
                sampleRateHertz: 48_000,
                sampleFormat: .float32LittleEndian,
                maxTransmissionUnitBytes: 200,
                maxFragmentsPerDeadline: 16,
                metadataRevision: 3,
                packingMode: .interleavedChannelRange
            )
        )
    }
}

@Test
func udpPcmV2FragmentPlannerAssertsPositiveFragmentCountAfterCast() throws {
    let source = try readMultichannelSource("Sources/OpenLolaCore/Network/UDP/UdpPcmV2FragmentPlanner.swift")

    #expect(source.contains("guard fragmentCount > 0, plannedChannelCapacity >= request.totalChannelCount else"))
    #expect(source.contains("throw UdpPcmV2FragmentPlanningError.arithmeticOverflow(\"fragmentCount\")"))
}

@Test
func udpPcmV2PacketizerReassemblesSixtyFourChannelDeadlineExactly() throws {
    let mode = try sixtyFourChannelV2Mode()
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
}

@Test
func udpPcmV2ReassemblerAccountsForLostFragmentsWithoutInventingAudio() throws {
    let mode = try sixtyFourChannelV2Mode()
    let payload = Data(repeating: 0x7F, count: mode.sampleFormat.bytesPerSample
        * mode.framesPerPacket
        * mode.channelCount)
    let packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 18,
        senderFrameIndex: 576,
        senderHostTimeNanoseconds: 1_234_568,
        mode: mode
    )

    let reassembled = try UdpPcmV2FragmentReassembler.reassemble(Array(packets.dropLast()))

    #expect(!reassembled.isComplete)
    #expect(reassembled.missingFragmentIndices == [7])
    #expect(reassembled.payload == nil)
}

@Test
func udpPcmV2ReassemblerRejectsOverlappingChannelCoverage() throws {
    let mode = try sixtyFourChannelV2Mode()
    let payload = Data(repeating: 0x42, count: mode.sampleFormat.bytesPerSample
        * mode.framesPerPacket
        * mode.channelCount)
    var packets = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 19,
        senderFrameIndex: 608,
        senderHostTimeNanoseconds: 1_234_569,
        mode: mode
    )
    packets[1].header.channelOffset = packets[0].header.channelOffset

    #expect(throws: UdpPcmV2FragmentReassemblyError.inconsistentDeadline("channelCoverage")) {
        _ = try UdpPcmV2FragmentReassembler.reassemble(packets)
    }
}

@Test
func receiverIdentityMixRoutesMatchingChannelsWithoutDestructiveDownmix() {
    let mix = ReceiverMixSnapshot.identity(
        inputChannels: .defaultInput(count: 64),
        outputChannels: .defaultOutput(count: 64)
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
}

@Test
func receiverMixPrecomputesGainMutePanAndRejectsHiddenDownmix() throws {
    let mix = ReceiverMixSnapshot(
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
            ),
        ],
        requiresDestructiveDownmix: false
    )

    let prepared = try mix.prepared(inputChannelCount: 2, outputChannelCount: 2)

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
}

@Test
func receiverAndRmePanValidationAllowsTinyBoundaryRounding() throws {
    let mix = ReceiverMixSnapshot(
        routes: [
            ReceiverMixRoute(
                sourceChannelIndex: 0,
                destinationChannelIndex: 0,
                gainDb: 0,
                muted: false,
                pan: 1.0 + receiverMixPanTolerance / 2
            ),
        ],
        requiresDestructiveDownmix: false
    )
    let prepared = try mix.prepared(inputChannelCount: 1, outputChannelCount: 1)
    #expect(prepared.routes.count == 1)

    let snapshot = RmeMatrixMetadataSnapshot(
        snapshotID: "operator-rme-routing",
        provider: .userProvidedSnapshot,
        revision: 1,
        capturedAt: "2026-05-04T00:00:00Z",
        legalBasis: "operator-provided routing snapshot",
        confidence: .operatorConfirmed,
        channels: [
            AudioChannelDescriptor(stableSourceIndex: 0, label: "input-1", sourceKind: .userProvided),
        ],
        routes: [
            RmeMatrixRouteMetadata(
                sourceChannelIndex: 0,
                destinationBusID: "main",
                gainDb: 0,
                muted: false,
                solo: false,
                pan: -1.0 - rmeMatrixPanTolerance / 2,
                stereoPairID: nil,
                label: "main"
            ),
        ],
        notes: "Metadata is advisory; media playback does not depend on it."
    )
    try snapshot.validate()
    #expect(snapshot.routes[0].pan < -1.0)
}

@Test
func rmeMatrixMetadataSnapshotRoutesValidateThroughHelper() throws {
    let source = try readMultichannelSource("Sources/OpenLolaCore/Audio/MADI/RmeMatrixMetadata.swift")

    #expect(source.contains("for route in routes {\n            try validateRoute(route)\n        }"))
    #expect(source.contains("private func validateRoute(_ route: RmeMatrixRouteMetadata) throws"))
    #expect(source.contains("RmeMatrixMetadataValidationError.nonFiniteGain(route.gainDb)"))
}

@Test
func receiverMixSnapshotStoreReplacesPreparedStateImmutably() throws {
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
            ),
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

@Test
func rmeMatrixMetadataRoundTripsAndRateLimitsControlUpdates() throws {
    let snapshot = RmeMatrixMetadataSnapshot(
        snapshotID: "operator-rme-routing",
        provider: .userProvidedSnapshot,
        revision: 1,
        capturedAt: "2026-05-04T00:00:00Z",
        legalBasis: "operator-provided routing snapshot",
        confidence: .operatorConfirmed,
        channels: [
            AudioChannelDescriptor(
                stableSourceIndex: 0,
                label: "violin-close",
                sourceKind: .userProvided
            ),
        ],
        routes: [
            RmeMatrixRouteMetadata(
                sourceChannelIndex: 0,
                destinationBusID: "phones-a",
                gainDb: -4,
                muted: false,
                solo: false,
                pan: -0.2,
                stereoPairID: nil,
                label: "player monitor"
            ),
        ],
        notes: "Metadata is advisory; media playback does not depend on it."
    )

    try snapshot.validate()
    let decoded = try JSONDecoder().decode(
        RmeMatrixMetadataSnapshot.self,
        from: JSONEncoder().encode(snapshot)
    )
    var control = RmeMatrixMetadataControlState(minUpdateIntervalNanoseconds: 1_000)
    var newer = snapshot
    newer.revision = 2

    #expect(decoded == snapshot)
    #expect(control.record(snapshot, nowNanoseconds: 10_000) == .accepted(revision: 1))
    #expect(control.record(newer, nowNanoseconds: 10_500) == .rateLimited(
        revision: 2,
        nextAllowedNanoseconds: 11_000
    ))
    #expect(control.record(newer, nowNanoseconds: 11_000) == .accepted(revision: 2))
}

@Test
func unavailableRmeMatrixMetadataStillAllowsMediaPlayback() throws {
    let snapshot = RmeMatrixMetadataSnapshot.unavailable(
        revision: 0,
        capturedAt: "2026-05-04T00:00:00Z",
        notes: "RME matrix metadata unavailable; receiver uses local identity mix."
    )

    try snapshot.validate()

    #expect(snapshot.provider == .unavailable)
    #expect(snapshot.channels.isEmpty)
    #expect(snapshot.routes.isEmpty)
    #expect(!snapshot.requiresMetadataForPlayback)
}

private func sixtyFourChannelV2Mode() throws -> AudioTransportMode {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: 1,
            totalChannelCount: 64,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian,
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            metadataRevision: 3,
            packingMode: .interleavedChannelRange
        )
    )
    return AudioTransportMode(
        protocolVersion: .udpPcmV2,
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 64,
        sampleFormat: .float32LittleEndian,
        latencyProfile: .safeLowLatency,
        rxBufferProfile: .direct,
        maxTransmissionUnitBytes: 1_200,
        channelOrder: AudioChannelSet.defaultInput(count: 64).sortedByStableSourceIndex,
        fragments: fragments
    )
}

private func readMultichannelSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
