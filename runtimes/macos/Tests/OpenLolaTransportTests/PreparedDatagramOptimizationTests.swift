// Verifies direct prepared-datagram encoding against the eager packet APIs.
import Foundation
import OpenLolaSessionDomain
@testable import OpenLolaTransport
import Testing

@Test func preparedAudioDatagramsMatchEagerPacketEncodingByteForByte() throws {
    let mode = try preparedAudioMode(channelCount: 8)
    let plan = try UdpPcmV2ValidatedFragmentPlan(mode: mode)
    let payload = Data((0..<mode.payloadByteCount).map(UInt8.init(truncatingIfNeeded:)))
    let eager = try payload.withUnsafeBytes {
        try UdpPcmV2Packetizer.packetize(
            $0,
            sequenceNumber: 7,
            senderFrameIndex: 32,
            senderHostTimeNanoseconds: 99,
            plan: plan
        )
    }
    var scratch = Data()

    try payload.withUnsafeBytes { bytes in
        try UdpPcmV2Packetizer.validatePacketizeRequest(payload: bytes, mode: mode)
        for (fragment, packet) in zip(plan.fragments, eager) {
            try UdpPcmV2Packetizer.encodePreparedMediaDatagram(
                bytes,
                sequenceNumber: 7,
                senderFrameIndex: 32,
                senderHostTimeNanoseconds: 99,
                fragment: fragment,
                mode: mode,
                into: &scratch
            )
            let expected = try UdpMediaPacket(
                header: .init(
                    payloadType: .audioPcmV2,
                    streamID: 1,
                    sequenceNumber: 7,
                    timestampNanoseconds: 99
                ),
                payload: packet.encoded()
            ).encoded()
            #expect(scratch == expected)
            #expect(try UdpMediaPacket.decodeWithNestedPayload(scratch).packet.payload == packet.encoded())
        }
    }
}

@Test func preparedAudioSocketPathReusesItsContiguousDatagramStorage() throws {
    let sender = try UdpMediaTransport.bindLoopback(bufferProfile: .realtimeAudio)
    let receiver = try UdpMediaTransport.bindLoopback(bufferProfile: .realtimeAudio)
    defer {
        sender.close()
        receiver.close()
    }
    try sender.connect(to: receiver.localEndpoint)
    let mode = try preparedAudioMode(channelCount: 2)
    let fragment = try #require(mode.fragments.first)
    let payload = Data(repeating: 0x5A, count: mode.payloadByteCount)
    var firstStorage: UdpMediaReceiveScratchStorage?

    try payload.withUnsafeBytes { bytes in
        for sequence in 1...2 {
            let sendResult = try sender.trySendPreparedPcmV2Datagram(
                bytes,
                sequenceNumber: UInt64(sequence),
                senderFrameIndex: UInt64(sequence * mode.framesPerPacket),
                senderHostTimeNanoseconds: UInt64(100 + sequence),
                fragment: fragment,
                mode: mode
            )
            #expect(sendResult == .sent)
            let storage = sender.sendScratchStorageForTesting
            if let firstStorage {
                #expect(storage.address == firstStorage.address)
                #expect(storage.byteCount == firstStorage.byteCount)
            } else {
                firstStorage = storage
            }
            let received = try receiver.receive(maxByteCount: 1_200)
            #expect(received.header.sequenceNumber == UInt64(sequence))
        }
    }
}

@Test func publicSendPreservesPacketValidationBeforeClosedSocketError() throws {
    let transport = try UdpMediaTransport.bindLoopback()
    transport.close()
    var invalidHeader = UdpMediaPacketHeader(
        payloadType: .keepalive,
        streamID: 1,
        sequenceNumber: 1,
        timestampNanoseconds: 1
    )
    invalidHeader.version = 0
    let packet = UdpMediaPacket(header: invalidHeader, payload: Data())

    #expect(throws: UdpMediaPacketError.unsupportedVersion(0)) {
        try transport.send(packet)
    }
}

@Test func preparedAudioSendPreservesTimestampValidationBeforeClosedSocketError() throws {
    let transport = try UdpMediaTransport.bindLoopback()
    transport.close()
    let mode = try preparedAudioMode(channelCount: 2)
    let fragment = try #require(mode.fragments.first)
    let payload = Data(repeating: 0, count: mode.payloadByteCount)

    #expect(throws: UdpPcmV2PacketError.invalidTimestamp(0)) {
        try payload.withUnsafeBytes {
            _ = try transport.trySendPreparedPcmV2Datagram(
                $0,
                sequenceNumber: 1,
                senderFrameIndex: 1,
                senderHostTimeNanoseconds: 0,
                fragment: fragment,
                mode: mode
            )
        }
    }
}

@Test func preparedVideoCursorMatchesEagerPacketsAndRetainsOwnedFrameBytes() throws {
    var source = Data((0..<20_000).map(UInt8.init(truncatingIfNeeded:)))
    let rawFrame = RawCapturedVideoFrame(metadata: preparedVideoMetadata(sequence: 4), payload: source)
    let prepared = try RawVideoFrameTransport.prepareMediaDatagrams(
        for: rawFrame,
        maxPacketBytes: 512,
        payloadType: .videoRawFrameFragment
    )
    let eagerFragments = try RawVideoFrameTransport.fragments(
        for: rawFrame,
        maxPacketBytes: 512 - UdpMediaPacketHeader.byteCount
    )
    let eager = try eagerFragments.map { fragment in
        try UdpMediaPacket(
            header: .init(
                payloadType: .videoRawFrameFragment,
                streamID: fragment.streamID,
                sequenceNumber: fragment.frameSequenceNumber,
                timestampNanoseconds: fragment.timestampNanoseconds
            ),
            payload: fragment.encoded()
        ).encoded()
    }
    source.resetBytes(in: source.startIndex..<source.endIndex)
    var cursor = prepared.makeCursor()
    var scratch = Data()
    var actual: [Data] = []
    while cursor.encodeNext(into: &scratch) {
        actual.append(scratch)
    }

    #expect(actual == eager)
    #expect(cursor.isComplete)
    #expect(cursor.remainingFragmentCount == 0)
}

@Test func preparedVideoAdmissionPreservesEagerValidationError() throws {
    var invalidMetadata = preparedVideoMetadata(sequence: 5)
    invalidMetadata.width = 0
    let frame = RawCapturedVideoFrame(metadata: invalidMetadata, payload: Data([1, 2, 3, 4]))
    let eagerError = #expect(throws: VideoTransportFragmentError.self) {
        let fragment = try #require(
            RawVideoFrameTransport.fragments(
                for: frame,
                maxPacketBytes: 512 - UdpMediaPacketHeader.byteCount
            ).first
        )
        _ = try fragment.encoded()
    }
    let preparedError = #expect(throws: VideoTransportFragmentError.self) {
        _ = try RawVideoFrameTransport.prepareMediaDatagrams(
            for: frame,
            maxPacketBytes: 512,
            payloadType: .videoRawFrameFragment
        )
    }
    #expect(String(describing: preparedError) == String(describing: eagerError))
}

private func preparedAudioMode(channelCount: Int) throws -> AudioTransportMode {
    let request = UdpPcmV2FragmentPlanRequest(.init(
        streamID: 1,
        audio: .init(
            totalChannelCount: channelCount,
            framesPerPacket: 8,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian
        ),
        fragmentationLimits: .init(maxTransmissionUnitBytes: 256, maxFragmentsPerDeadline: 16),
        metadata: .init(metadataRevision: 0, packingMode: .interleavedChannelRange)
    ))
    return AudioTransportMode(
        transport: .init(
            protocolVersion: .udpPcmV2,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct,
            maxTransmissionUnitBytes: 256
        ),
        format: .init(
            sampleRateHertz: 48_000,
            framesPerPacket: 8,
            channelCount: channelCount,
            sampleFormat: .float32LittleEndian
        ),
        layout: .init(
            channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
            fragments: try UdpPcmV2FragmentPlanner.plan(request)
        )
    )
}

private func preparedVideoMetadata(sequence: UInt64) -> CapturedVideoFrame {
    CapturedVideoFrame(
        streamID: 100,
        sequenceNumber: sequence,
        timestampNanoseconds: 1_000 + sequence,
        timestampBasis: .syntheticMonotonicNanoseconds,
        sourceRole: .testPattern,
        width: 100,
        height: 50,
        pixelFormat: "BGRA",
        frameRate: .init(numerator: 30, denominator: 1),
        fingerprint: "prepared-video-\(sequence)"
    )
}
