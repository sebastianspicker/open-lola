import Foundation
import Testing

@testable import OpenLolaCore

@Test
func mediaPacketEnvelopeCarriesAudioPayloadTypeAndStreamMetadata() throws {
    let audio = try m06AudioPackets(streamID: 7, sequenceNumber: 3)[0]
    let packet = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioPcmV2,
            streamID: 7,
            sequenceNumber: 3,
            timestampNanoseconds: audio.header.senderHostTimeNanoseconds
        ),
        payload: try audio.encoded()
    )

    let decoded = try UdpMediaPacket.decode(try packet.encoded())
    let decodedAudio = try UdpPcmV2Packet.decode(decoded.payload)

    #expect(decoded.header.payloadType == .audioPcmV2)
    #expect(decoded.header.streamID == 7)
    #expect(decoded.header.sequenceNumber == 3)
    #expect(decodedAudio.header.streamID == 7)
    #expect(decodedAudio.header.sampleRateHertz == 48_000)
    #expect(decodedAudio.header.framesPerPacket == 32)
    #expect(decodedAudio.header.sampleFormat == .int16LittleEndian)
}

@Test
func mediaPacketRejectsEveryTruncatedHeaderBoundary() throws {
    let packet = try m06MediaAudioPacket(streamID: 7, sequenceNumber: 3)
    let encoded = try packet.encoded()

    for byteCount in 0..<UdpMediaPacketHeader.byteCount {
        #expect(throws: UdpMediaPacketError.truncatedPacket(byteCount: byteCount)) {
            _ = try UdpMediaPacket.decode(encoded.prefix(byteCount))
        }
    }
}

@Test
func mediaPacketReadersValidateFullUInt64WindowBeforeSplitRead() throws {
    let source = try readUdpMediaTransportSource()

    #expect(source.contains("guard udpPcmHasBytes(bytes, offset: offset, count: 8) else"))
    #expect(source.contains("NetworkByteReader.readUInt64LE(bytes, offset: offset)"))
    #expect(source.contains("guard udpPcmHasBytes(bytes, offset: offset, count: 4) else"))
    #expect(!source.contains("offset <= bytes.count - 4"))
}

@Test
func mediaPacketHeaderReaderTrySitesCallThrowingReaders() throws {
    let source = try readUdpMediaTransportSource()

    #expect(source.contains("let streamID = try readUdpMediaUInt32LE(bytes, offset: 8)"))
    #expect(source.contains("let sequenceNumber = try readUdpMediaUInt64LE(bytes, offset: 12)"))
    #expect(source.contains("let payloadByteCount = try readUdpMediaUInt32LE(bytes, offset: 28)"))
    #expect(source.contains("private func readUdpMediaUInt32LE(_ bytes: [UInt8], offset: Int) throws -> UInt32"))
    #expect(source.contains("private func readUdpMediaUInt64LE(_ bytes: [UInt8], offset: Int) throws -> UInt64"))
}

@Test
func mediaPacketValidatesNestedBinaryPayloadByteCountsAfterDecode() throws {
    let source = try readUdpMediaTransportSource()

    #expect(source.contains("try validateNestedPayloadByteCount(try rtp.encoded().count)"))
    #expect(source.contains("try validateNestedPayloadByteCount(try audio.encoded().count)"))
    #expect(source.contains("try validateNestedPayloadByteCount(try opus.encoded().count)"))
    #expect(source.contains("try validateNestedPayloadByteCount(try video.encoded().count)"))
    #expect(source.contains("throw UdpMediaPacketError.payloadLengthMismatch("))
}

@Test
func mediaPacketRejectsMismatchedAudioStreamID() throws {
    let audio = try m06AudioPackets(streamID: 8, sequenceNumber: 1)[0]
    let packet = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioPcmV2,
            streamID: 7,
            sequenceNumber: 1,
            timestampNanoseconds: audio.header.senderHostTimeNanoseconds
        ),
        payload: try audio.encoded()
    )

    #expect(throws: UdpMediaPacketError.audioStreamMismatch(expected: 7, actual: 8)) {
        _ = try UdpMediaPacket.decode(try packet.encoded())
    }
}

@Test
func mediaPacketEnvelopeCarriesVideoFragmentStreamMetadata() throws {
    let frame = CapturedVideoFrame(
        streamID: 9,
        sequenceNumber: 5,
        timestampNanoseconds: 6,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .blackmagicInput,
        width: 320,
        height: 240,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 60, denominator: 1),
        fingerprint: "blackmagic-video-5"
    )
    let fragments = try RawVideoFrameTransport.fragments(
        for: frame,
        maxPacketBytes: 1_200
    )
    let fragment = try #require(fragments.first)
    let packet = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .videoRawFrameFragment,
            streamID: frame.streamID,
            sequenceNumber: frame.sequenceNumber,
            timestampNanoseconds: frame.timestampNanoseconds
        ),
        payload: try fragment.encoded()
    )

    let decoded = try UdpMediaPacket.decode(try packet.encoded())
    let decodedFragment = try VideoTransportFragment.decode(decoded.payload)

    #expect(decoded.header.payloadType == .videoRawFrameFragment)
    #expect(decoded.header.streamID == 9)
    #expect(decodedFragment.streamID == 9)
    #expect(decodedFragment.sourceRole == .blackmagicInput)
    #expect(decodedFragment.pixelFormat == "bgra8")
}

@Test
func mediaPacketEnvelopeCarriesAudioTimingPayload() throws {
    let timing = MediaTimingPacket(
        streamID: 1,
        sequenceNumber: 2,
        observedPayloadType: .audioPcmV2,
        senderFrameIndex: 64,
        remoteSenderTimeNanoseconds: 3_000_000,
        localObservationTimeNanoseconds: 3_120_000,
        timestampOrigin: .audioPacketSenderHostTimeNanoseconds
    )
    let packet = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioTiming,
            streamID: timing.streamID,
            sequenceNumber: timing.sequenceNumber,
            timestampNanoseconds: timing.localObservationTimeNanoseconds
        ),
        payload: try JSONEncoder().encode(timing)
    )

    let decoded = try UdpMediaPacket.decode(try packet.encoded())
    let decodedTiming = try JSONDecoder().decode(MediaTimingPacket.self, from: decoded.payload)

    #expect(decoded.header.payloadType == .audioTiming)
    #expect(decodedTiming == timing)
    #expect(decodedTiming.observedAgeMicroseconds == 120)
}

@Test
func videoMediaPacketizerKeepsWrappedDatagramsWithinRequestedLimit() throws {
    let frame = RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 9,
            sequenceNumber: 5,
            timestampNanoseconds: 6,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .avFoundationDevice,
            width: 1_280,
            height: 720,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "wrapped-1280x720"
        ),
        payload: Data(repeating: 0x7f, count: 1_280 * 720 * 4)
    )

    let packets = try VideoMediaPacketizer.packets(for: frame, maxPacketBytes: 1_200)

    #expect(!packets.isEmpty)
    #expect(try packets.allSatisfy { try $0.encoded().count <= 1_200 })
}

@Test
func videoMediaPacketizerRejectsTooSmallConfiguredPacketLimitBeforeHeaderSubtraction() throws {
    let frame = CapturedVideoFrame(
        streamID: 9,
        sequenceNumber: 5,
        timestampNanoseconds: 6,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .blackmagicInput,
        width: 320,
        height: 240,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 60, denominator: 1),
        fingerprint: "blackmagic-video-5"
    )
    let maxPacketBytes = UdpMediaPacketHeader.byteCount - 1

    #expect(throws: VideoTransportFragmentError.maxPacketTooSmall(
        maxPacketBytes: maxPacketBytes,
        overheadBytes: UdpMediaPacketHeader.byteCount
    )) {
        _ = try VideoMediaPacketizer.packets(for: frame, maxPacketBytes: maxPacketBytes)
    }
}

@Test
func mediaPacketRejectsMalformedAudioTimingPayload() throws {
    let packet = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioTiming,
            streamID: 1,
            sequenceNumber: 2,
            timestampNanoseconds: 3_120_000
        ),
        payload: Data("not-json".utf8)
    )

    #expect(throws: (any Error).self) {
        _ = try UdpMediaPacket.decode(try packet.encoded())
    }
}

@Test
func mediaPacketRejectsMismatchedVideoStreamID() throws {
    let frame = CapturedVideoFrame(
        streamID: 9,
        sequenceNumber: 5,
        timestampNanoseconds: 6,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .blackmagicInput,
        width: 320,
        height: 240,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 60, denominator: 1),
        fingerprint: "blackmagic-video-5"
    )
    let fragments = try RawVideoFrameTransport.fragments(
        for: frame,
        maxPacketBytes: 1_200
    )
    let fragment = try #require(fragments.first)
    let packet = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .videoRawFrameFragment,
            streamID: 10,
            sequenceNumber: frame.sequenceNumber,
            timestampNanoseconds: frame.timestampNanoseconds
        ),
        payload: try fragment.encoded()
    )

    #expect(throws: UdpMediaPacketError.videoStreamMismatch(expected: 10, actual: 9)) {
        _ = try UdpMediaPacket.decode(try packet.encoded())
    }
}

@Test
func udpMediaTransportSendsReceivesVideoFragment() throws {
    let first = try UdpMediaTransport.bindLoopback()
    defer { first.close() }
    let second = try UdpMediaTransport.bindLoopback()
    defer { second.close() }
    try first.connect(to: second.localEndpoint)
    try second.connect(to: first.localEndpoint)
    let frame = CapturedVideoFrame(
        streamID: 9,
        sequenceNumber: 1,
        timestampNanoseconds: 2,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .blackmagicInput,
        width: 4,
        height: 4,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 60, denominator: 1),
        fingerprint: "blackmagic-video-1"
    )
    let packets = try VideoMediaPacketizer.packets(for: frame, maxPacketBytes: 1_200)

    try first.send(try #require(packets.first))
    let received = try second.receive(maxByteCount: 1_200)
    let receivedFragment = try VideoTransportFragment.decode(received.payload)

    #expect(received.header.payloadType == .videoRawFrameFragment)
    #expect(received.header.streamID == 9)
    #expect(receivedFragment.streamID == 9)
    #expect(receivedFragment.sourceRole == .blackmagicInput)
    #expect(first.metrics.packetsSent == 1)
    #expect(second.metrics.packetsReceived == 1)
}

@Test
func udpMediaTransportRecordsRequestedDscp() throws {
    let transport = try UdpMediaTransport.bindLoopback(dscp: 0)
    defer { transport.close() }

    #expect(transport.requestedDscp == 0)
}

@Test
func udpMediaTransportSendsReceivesAndTracksLossJitter() throws {
    let first = try UdpMediaTransport.bindLoopback()
    defer { first.close() }
    let second = try UdpMediaTransport.bindLoopback()
    defer { second.close() }

    try first.connect(to: second.localEndpoint)
    try second.connect(to: first.localEndpoint)

    try first.send(try m06MediaAudioPacket(streamID: 1, sequenceNumber: 1))
    try first.send(try m06MediaAudioPacket(streamID: 1, sequenceNumber: 3))

    _ = try second.receive(maxByteCount: 1_200)
    _ = try second.receive(maxByteCount: 1_200)

    #expect(first.metrics.packetsSent == 2)
    #expect(second.metrics.packetsReceived == 2)
    #expect(second.metrics.packetsLost == 1)
    #expect(second.metrics.jitterMicroseconds >= 0)
}

@Test
func udpMediaTransportCountsLossAcrossSequenceRollover() throws {
    let first = try UdpMediaTransport.bindLoopback()
    defer { first.close() }
    let second = try UdpMediaTransport.bindLoopback()
    defer { second.close() }

    try first.connect(to: second.localEndpoint)
    try second.connect(to: first.localEndpoint)

    try first.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: UInt64.max, timestamp: 1))
    try first.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 2, timestamp: 2))

    _ = try second.receive(maxByteCount: 1_200)
    _ = try second.receive(maxByteCount: 1_200)

    #expect(second.metrics.packetsLost == 2)
}

@Test
func udpMediaTransportDoesNotTreatStaleSequenceAsHugeLoss() throws {
    let first = try UdpMediaTransport.bindLoopback()
    defer { first.close() }
    let second = try UdpMediaTransport.bindLoopback()
    defer { second.close() }

    try first.connect(to: second.localEndpoint)
    try second.connect(to: first.localEndpoint)

    try first.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 10, timestamp: 1))
    try first.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 9, timestamp: 2))

    _ = try second.receive(maxByteCount: 1_200)
    _ = try second.receive(maxByteCount: 1_200)

    #expect(second.metrics.packetsLost == 0)
}

@Test
func udpMediaTransportDoesNotRegressExpectedSequenceOnReorderedPacket() throws {
    let first = try UdpMediaTransport.bindLoopback()
    defer { first.close() }
    let second = try UdpMediaTransport.bindLoopback()
    defer { second.close() }

    try first.connect(to: second.localEndpoint)
    try second.connect(to: first.localEndpoint)

    try first.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 10, timestamp: 1))
    try first.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 9, timestamp: 2))
    try first.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 11, timestamp: 3))
    try first.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 11, timestamp: 4))

    _ = try second.receive(maxByteCount: 1_200)
    _ = try second.receive(maxByteCount: 1_200)
    _ = try second.receive(maxByteCount: 1_200)
    _ = try second.receive(maxByteCount: 1_200)

    #expect(second.metrics.packetsLost == 0)
    #expect(second.metrics.latePackets == 2)
    #expect(second.metrics.reorderedPackets == 1)
    #expect(second.metrics.duplicatePackets == 1)
}

@Test
func udpMediaTransportRecordsClockSkewInsteadOfZeroLatencySample() throws {
    let first = try UdpMediaTransport.bindLoopback()
    defer { first.close() }
    let second = try UdpMediaTransport.bindLoopback()
    defer { second.close() }

    try first.connect(to: second.localEndpoint)
    try second.connect(to: first.localEndpoint)

    try first.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 1, timestamp: UInt64.max))
    _ = try second.receive(maxByteCount: 1_200)

    #expect(second.metrics.clockSkewEventCount == 1)
    #expect(second.metrics.jitterMicroseconds == 0)
}

@Test
func udpMediaTransportGatesJitterUntilMinimumSampleCount() throws {
    let first = try UdpMediaTransport.bindLoopback()
    defer { first.close() }
    let second = try UdpMediaTransport.bindLoopback()
    defer { second.close() }

    try first.connect(to: second.localEndpoint)
    try second.connect(to: first.localEndpoint)

    for sequence in UInt64(1)...UInt64(3) {
        try first.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: sequence, timestamp: sequence))
        _ = try second.receive(maxByteCount: 1_200)
    }

    #expect(second.metrics.jitterMicroseconds == 0)
}

@Test
func rawVideoPacketizerAndReassemblerPreserveExactPayloadBytes() throws {
    let payload = Data((0..<250).map { UInt8($0 % 251) })
    let rawFrame = RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 12,
            sequenceNumber: 7,
            timestampNanoseconds: 99,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .avFoundationDevice,
            width: 25,
            height: 10,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "raw-byte-exact"
        ),
        payload: payload
    )
    let fragments = try RawVideoFrameTransport.fragments(for: rawFrame, maxPacketBytes: 120)
    let reassembler = VideoFrameReassembler(maxActiveFrames: 2)
    var completed: RawCapturedVideoFrame?

    for fragment in fragments {
        completed = try reassembler.receiveRaw(fragment) ?? completed
    }

    let reassembled = try #require(completed)
    #expect(reassembled.metadata == rawFrame.metadata)
    #expect(reassembled.payload == payload)
    #expect(reassembler.metrics.framesReassembled == 1)
}

private func m06MediaAudioPacket(
    streamID: Int,
    sequenceNumber: UInt64
) throws -> UdpMediaPacket {
    let audio = try m06AudioPackets(streamID: streamID, sequenceNumber: sequenceNumber)[0]
    return UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioPcmV2,
            streamID: UInt32(streamID),
            sequenceNumber: sequenceNumber,
            timestampNanoseconds: audio.header.senderHostTimeNanoseconds
        ),
        payload: try audio.encoded()
    )
}

private func keepaliveMediaPacket(
    streamID: UInt32,
    sequenceNumber: UInt64,
    timestamp: UInt64
) -> UdpMediaPacket {
    UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .keepalive,
            streamID: streamID,
            sequenceNumber: sequenceNumber,
            timestampNanoseconds: timestamp
        ),
        payload: Data()
    )
}

private func m06AudioPackets(
    streamID: Int,
    sequenceNumber: UInt64
) throws -> [UdpPcmV2Packet] {
    let mode = try m06AudioMode(streamID: streamID)
    return try UdpPcmV2Packetizer.packetize(
        Data(
            repeating: UInt8(sequenceNumber),
            count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample
        ),
        sequenceNumber: sequenceNumber,
        senderFrameIndex: sequenceNumber * UInt64(mode.framesPerPacket),
        senderHostTimeNanoseconds: sequenceNumber + 1,
        mode: mode
    )
}

private func m06AudioMode(streamID: Int) throws -> AudioTransportMode {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: streamID,
            totalChannelCount: 2,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .int16LittleEndian,
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            metadataRevision: 0,
            packingMode: .interleavedChannelRange
        )
    )
    return AudioTransportMode(
        protocolVersion: .udpPcmV2,
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian,
        latencyProfile: .safeLowLatency,
        rxBufferProfile: .direct,
        maxTransmissionUnitBytes: 1_200,
        channelOrder: AudioChannelSet.defaultInput(count: 2).sortedByStableSourceIndex,
        fragments: fragments
    )
}

private func readUdpMediaTransportSource() throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: root.appendingPathComponent("Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift"),
        encoding: .utf8
    )
}
