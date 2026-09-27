// Verifies UDP packet encoding and fake-kernel send, drop, and receive policy behavior.
import Darwin
import Foundation
import OpenLolaContracts
import OpenLolaSessionDomain
@testable import OpenLolaTransport
import Testing

@Test func udpMediaPacketRoundTripsExactHeaderAndRejectsTruncation() throws {
    let packet = UdpMediaPacket(
        header: .init(
            payloadType: .keepalive,
            streamID: 7,
            sequenceNumber: 42,
            timestampNanoseconds: 1_000
        ),
        payload: Data([0, 1, 2, 3])
    )
    let encoded = try packet.encoded()
    #expect(encoded.count == UdpMediaPacketHeader.byteCount + 4)
    #expect(try UdpMediaPacket.decode(encoded) == packet)
    #expect(throws: UdpMediaPacketError.self) {
        try UdpMediaPacket.decode(encoded.prefix(UdpMediaPacketHeader.byteCount - 1))
    }
}

@Test func udpPacketCodecUsesFakeKernelOutcomesForSendDropAndReceivePolicy() throws {
    let packet = UdpMediaPacket(
        header: .init(
            payloadType: .keepalive,
            streamID: 9,
            sequenceNumber: 3,
            timestampNanoseconds: 2_000
        ),
        payload: Data()
    )
    let transmittedDatagram = try packet.encoded()

    #expect(
        try udpDatagramSendResult(
            sentByteCount: transmittedDatagram.count,
            expectedByteCount: transmittedDatagram.count,
            savedErrno: 0,
            nonBlocking: true
        ) == .sent
    )
    #expect(
        try udpDatagramSendResult(
            sentByteCount: -1,
            expectedByteCount: transmittedDatagram.count,
            savedErrno: EAGAIN,
            nonBlocking: true
        ) == .wouldBlock
    )
    #expect(throws: UdpPcmRouteProbeError.self) {
        try udpDatagramSendResult(
            sentByteCount: transmittedDatagram.count - 1,
            expectedByteCount: transmittedDatagram.count,
            savedErrno: 0,
            nonBlocking: true
        )
    }
    #expect(try UdpMediaPacket.decode(transmittedDatagram) == packet)
}

@Test func udpMediaTransportReusesScratchAndTracksDuplicatesOnItsOwningReceivePath() throws {
    let sender = try UdpMediaTransport.bindLoopback(bufferProfile: .realtimeAudio)
    let receiver = try UdpMediaTransport.bindLoopback(bufferProfile: .realtimeAudio)
    defer {
        sender.close()
        receiver.close()
    }
    try sender.connect(to: receiver.localEndpoint)
    let packet = UdpMediaPacket(
        header: .init(
            payloadType: .keepalive,
            streamID: 3,
            sequenceNumber: 8,
            timestampNanoseconds: 1
        ),
        payload: Data([1, 2, 3, 4])
    )
    let encoded = try packet.encoded()

    #expect(try receiver.tryReceiveRawDatagram(maxByteCount: encoded.count) == nil)

    try sender.sendRawDatagram(Data([0]))
    #expect(try waitForReadableSocket(socket: receiver.descriptor, timeoutMicroseconds: 1_000_000))
    #expect(throws: UdpMediaMalformedDatagramError.self) {
        _ = try receiver.tryReceive(maxByteCount: encoded.count)
    }

    try sender.sendRawDatagram(encoded)
    #expect(try waitForReadableSocket(socket: receiver.descriptor, timeoutMicroseconds: 1_000_000))
    #expect(throws: UdpMediaMalformedDatagramError.self) {
        _ = try receiver.tryReceive(maxByteCount: encoded.count - 1)
    }

    try sender.sendRawDatagram(encoded)
    #expect(try waitForReadableSocket(socket: receiver.descriptor, timeoutMicroseconds: 1_000_000))
    guard let firstRaw = try receiver.tryReceiveRawDatagram(maxByteCount: encoded.count) else {
        Issue.record("expected first retained raw datagram")
        return
    }
    let firstScratch = receiver.receiveScratchStorageForTesting
    try sender.sendRawDatagram(encoded)
    #expect(try waitForReadableSocket(socket: receiver.descriptor, timeoutMicroseconds: 1_000_000))
    guard let secondRaw = try receiver.tryReceiveRawDatagram(maxByteCount: encoded.count) else {
        Issue.record("expected second retained raw datagram")
        return
    }
    let secondScratch = receiver.receiveScratchStorageForTesting
    #expect(firstRaw == encoded)
    #expect(secondRaw == encoded)
    #expect(firstScratch == secondScratch)

    try sender.send(packet)
    #expect(try waitForReadableSocket(socket: receiver.descriptor, timeoutMicroseconds: 1_000_000))
    #expect(try receiver.tryReceive(maxByteCount: encoded.count) == packet)
    try sender.send(packet)
    #expect(try waitForReadableSocket(socket: receiver.descriptor, timeoutMicroseconds: 1_000_000))
    #expect(try receiver.tryReceive(maxByteCount: encoded.count) == packet)
    #expect(receiver.metrics.duplicatePackets == 1)
}

@Test func validatedFragmentPlanPreservesFragmentOrderAndPublicRequestValidation() throws {
    let request = UdpPcmV2FragmentPlanRequest(.init(
        streamID: 7,
        audio: .init(
            totalChannelCount: 8,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .int16LittleEndian
        ),
        fragmentationLimits: .init(maxTransmissionUnitBytes: 320, maxFragmentsPerDeadline: 16),
        metadata: .init(metadataRevision: 4, packingMode: .interleavedChannelRange)
    ))
    let fragments = try UdpPcmV2FragmentPlanner.plan(request)
    var mode = AudioTransportMode(
        transport: .init(
            protocolVersion: .udpPcmV2,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct,
            maxTransmissionUnitBytes: 320
        ),
        format: .init(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 8,
            sampleFormat: .int16LittleEndian
        ),
        layout: .init(
            channelOrder: AudioChannelSet.defaultInput(count: 8).sortedByStableSourceIndex,
            fragments: Array(fragments.reversed())
        )
    )
    let plan = try UdpPcmV2ValidatedFragmentPlan(mode: mode)
    #expect(plan.fragments == mode.fragments)
    let pcm = Data((0..<mode.payloadByteCount).map { UInt8(truncatingIfNeeded: $0) })
    let dynamic = try UdpPcmV2Packetizer.packetize(
        pcm, sequenceNumber: 1, senderFrameIndex: 32, senderHostTimeNanoseconds: 99, mode: mode
    )
    let prepared = try pcm.withUnsafeBytes {
        try UdpPcmV2Packetizer.packetize(
            $0, sequenceNumber: 1, senderFrameIndex: 32, senderHostTimeNanoseconds: 99, mode: mode, plan: plan
        )
    }
    #expect(prepared == dynamic)
    #expect(prepared.map(\.header.fragmentIndex) == mode.fragments.map { UInt16($0.fragmentIndex) })

    var invalidMode = mode
    invalidMode.fragments[0].fragmentCount = fragments.count + 1
    #expect(throws: UdpPcmV2FragmentPlanValidationError.self) {
        _ = try UdpPcmV2ValidatedFragmentPlan(mode: invalidMode)
    }
    mode.fragments[0].metadataRevision += 1
    #expect(throws: UdpPcmV2PacketizerError.fragmentPlanMismatch("preparedMode")) {
        try pcm.withUnsafeBytes {
            try UdpPcmV2Packetizer.packetize(
                $0, sequenceNumber: 1, senderFrameIndex: 32, senderHostTimeNanoseconds: 99, mode: mode, plan: plan
            )
        }
    }
    #expect(throws: UdpPcmV2FragmentPlanningError.nonPositiveField("streamID")) {
        _ = try UdpPcmV2FragmentPlanner.plan(.init(.init(
            streamID: 0,
            audio: requestAudioDescription(),
            fragmentationLimits: .init(maxTransmissionUnitBytes: 320, maxFragmentsPerDeadline: 16),
            metadata: .init(metadataRevision: 4, packingMode: .interleavedChannelRange)
        )))
    }
}

@Test func recentSequenceHistoryEvictsAndWrapsAtItsFixedCapacity() {
    var history = UdpMediaRecentSequences()
    for sequence in 0..<UdpMediaRecentSequences.capacity {
        let inserted = history.insert(UInt64(sequence))
        #expect(inserted)
    }
    let duplicateZero = history.insert(0)
    #expect(!duplicateZero)
    let insertedCapacity = history.insert(UInt64(UdpMediaRecentSequences.capacity))
    #expect(insertedCapacity)
    let insertedEvictedZero = history.insert(0)
    #expect(insertedEvictedZero)

    for sequence in (UdpMediaRecentSequences.capacity + 1)..<(UdpMediaRecentSequences.capacity * 2) {
        let inserted = history.insert(UInt64(sequence))
        #expect(inserted)
    }
    let insertedEvictedOne = history.insert(1)
    #expect(insertedEvictedOne)
    let duplicateOne = history.insert(1)
    #expect(!duplicateOne)
}

private func requestAudioDescription() -> UdpPcmV2FragmentPlanRequest.AudioDescription {
    .init(
        totalChannelCount: 8,
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        sampleFormat: .int16LittleEndian
    )
}
