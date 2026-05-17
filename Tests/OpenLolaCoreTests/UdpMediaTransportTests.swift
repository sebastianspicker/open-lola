import Foundation
import Testing

@testable import OpenLolaCore

@Test
func mediaPacketEnvelopeCarriesAudioVideoAndTimingMetadata() throws {
    let audio = try m06AudioPackets(streamID: 7, sequenceNumber: 3)[0]
    let audioEnvelope = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioPcmV2,
            streamID: 7,
            sequenceNumber: 3,
            timestampNanoseconds: audio.header.senderHostTimeNanoseconds
        ),
        payload: try audio.encoded()
    )

    let decodedAudioEnvelope = try UdpMediaPacket.decode(try audioEnvelope.encoded())
    let decodedAudio = try UdpPcmV2Packet.decode(decodedAudioEnvelope.payload)

    #expect(decodedAudioEnvelope.header.payloadType == .audioPcmV2)
    #expect(decodedAudioEnvelope.header.streamID == 7)
    #expect(decodedAudioEnvelope.header.sequenceNumber == 3)
    #expect(decodedAudio.header.streamID == 7)
    #expect(decodedAudio.header.sampleRateHertz == 48_000)
    #expect(decodedAudio.header.framesPerPacket == 32)
    #expect(decodedAudio.header.sampleFormat == .int16LittleEndian)

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
    let videoPacket = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .videoRawFrameFragment,
            streamID: frame.streamID,
            sequenceNumber: frame.sequenceNumber,
            timestampNanoseconds: frame.timestampNanoseconds
        ),
        payload: try fragment.encoded()
    )
    let decodedVideo = try UdpMediaPacket.decode(try videoPacket.encoded())
    let decodedFragment = try VideoTransportFragment.decode(decodedVideo.payload)

    #expect(decodedVideo.header.payloadType == .videoRawFrameFragment)
    #expect(decodedVideo.header.streamID == 9)
    #expect(decodedFragment.streamID == 9)
    #expect(decodedFragment.sourceRole == .blackmagicInput)
    #expect(decodedFragment.pixelFormat == "bgra8")

    let timing = MediaTimingPacket(
        streamID: 1,
        sequenceNumber: 2,
        observedPayloadType: .audioPcmV2,
        senderFrameIndex: 64,
        remoteSenderTimeNanoseconds: 3_000_000,
        localObservationTimeNanoseconds: 3_120_000,
        timestampOrigin: .audioPacketSenderHostTimeNanoseconds
    )
    let timingEnvelope = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioTiming,
            streamID: timing.streamID,
            sequenceNumber: timing.sequenceNumber,
            timestampNanoseconds: timing.localObservationTimeNanoseconds
        ),
        payload: try JSONEncoder().encode(timing)
    )

    let decodedTimingPacket = try UdpMediaPacket.decode(try timingEnvelope.encoded())
    let decodedTiming = try JSONDecoder().decode(MediaTimingPacket.self, from: decodedTimingPacket.payload)

    #expect(decodedTimingPacket.header.payloadType == .audioTiming)
    #expect(decodedTiming == timing)
    #expect(decodedTiming.observedAgeMicroseconds == 120)
}

@Test
func mediaPacketRejectsTruncatedMismatchedAndMalformedPayloads() throws {
    let packet = try m06MediaAudioPacket(streamID: 7, sequenceNumber: 3)
    let encoded = try packet.encoded()

    for byteCount in 0..<UdpMediaPacketHeader.byteCount {
        #expect(throws: UdpMediaPacketError.truncatedPacket(byteCount: byteCount)) {
            _ = try UdpMediaPacket.decode(encoded.prefix(byteCount))
        }
    }

    let mismatchedAudio = try m06AudioPackets(streamID: 8, sequenceNumber: 1)[0]
    let audioPacket = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioPcmV2,
            streamID: 7,
            sequenceNumber: 1,
            timestampNanoseconds: mismatchedAudio.header.senderHostTimeNanoseconds
        ),
        payload: try mismatchedAudio.encoded()
    )

    #expect(throws: UdpMediaPacketError.audioStreamMismatch(expected: 7, actual: 8)) {
        _ = try UdpMediaPacket.decode(try audioPacket.encoded())
    }

    let mismatchedFrame = CapturedVideoFrame(
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
    let mismatchedFragment = try #require(RawVideoFrameTransport.fragments(
        for: mismatchedFrame,
        maxPacketBytes: 1_200
    ).first)
    let videoPacket = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .videoRawFrameFragment,
            streamID: 10,
            sequenceNumber: mismatchedFrame.sequenceNumber,
            timestampNanoseconds: mismatchedFrame.timestampNanoseconds
        ),
        payload: try mismatchedFragment.encoded()
    )

    #expect(throws: UdpMediaPacketError.videoStreamMismatch(expected: 10, actual: 9)) {
        _ = try UdpMediaPacket.decode(try videoPacket.encoded())
    }

    let audio = try m06AudioPackets(streamID: 7, sequenceNumber: 3)[0]
    var audioPayload = try audio.encoded()
    audioPayload.append(0)
    let malformedAudioPacket = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioPcmV2,
            streamID: audio.header.streamID,
            sequenceNumber: audio.header.sequenceNumber,
            timestampNanoseconds: audio.header.senderHostTimeNanoseconds
        ),
        payload: audioPayload
    )

    #expect(throws: (any Error).self) {
        _ = try UdpMediaPacket.decode(try malformedAudioPacket.encoded())
    }

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
    let fragment = try #require(RawVideoFrameTransport.fragments(
        for: frame,
        maxPacketBytes: 1_200
    ).first)
    var videoPayload = try fragment.encoded()
    videoPayload.append(0)
    let malformedVideoPacket = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .videoRawFrameFragment,
            streamID: frame.streamID,
            sequenceNumber: frame.sequenceNumber,
            timestampNanoseconds: frame.timestampNanoseconds
        ),
        payload: videoPayload
    )

    #expect(throws: (any Error).self) {
        _ = try UdpMediaPacket.decode(try malformedVideoPacket.encoded())
    }

    let timingPacket = UdpMediaPacket(
        header: UdpMediaPacketHeader(
            payloadType: .audioTiming,
            streamID: 1,
            sequenceNumber: 2,
            timestampNanoseconds: 3_120_000
        ),
        payload: Data("not-json".utf8)
    )

    #expect(throws: (any Error).self) {
        _ = try UdpMediaPacket.decode(try timingPacket.encoded())
    }
}

@Test
func videoMediaPacketizerKeepsDatagramsWithinLimitAndRejectsTooSmallLimit() throws {
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
    let maxPacketBytes = UdpMediaPacketHeader.byteCount - 1

    #expect(throws: VideoTransportFragmentError.maxPacketTooSmall(
        maxPacketBytes: maxPacketBytes,
        overheadBytes: UdpMediaPacketHeader.byteCount
    )) {
        _ = try VideoMediaPacketizer.packets(for: frame.metadata, maxPacketBytes: maxPacketBytes)
    }
}

@Test
func udpMediaTransportSendsReceivesVideoFragmentAndRecordsRequestedDscp() throws {
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

    let transport = try UdpMediaTransport.bindLoopback(dscp: 0)
    defer { transport.close() }

    #expect(transport.requestedDscp == 0)
}

@Test
func udpMediaTransportTracksLossRolloverReorderDuplicateAndClockSkew() throws {
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

    let rolloverFirst = try UdpMediaTransport.bindLoopback()
    defer { rolloverFirst.close() }
    let rolloverSecond = try UdpMediaTransport.bindLoopback()
    defer { rolloverSecond.close() }

    try rolloverFirst.connect(to: rolloverSecond.localEndpoint)
    try rolloverSecond.connect(to: rolloverFirst.localEndpoint)

    try rolloverFirst.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: UInt64.max, timestamp: 1))
    try rolloverFirst.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 2, timestamp: 2))

    _ = try rolloverSecond.receive(maxByteCount: 1_200)
    _ = try rolloverSecond.receive(maxByteCount: 1_200)

    #expect(rolloverSecond.metrics.packetsLost == 2)

    let staleFirst = try UdpMediaTransport.bindLoopback()
    defer { staleFirst.close() }
    let staleSecond = try UdpMediaTransport.bindLoopback()
    defer { staleSecond.close() }

    try staleFirst.connect(to: staleSecond.localEndpoint)
    try staleSecond.connect(to: staleFirst.localEndpoint)

    try staleFirst.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 10, timestamp: 1))
    try staleFirst.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 9, timestamp: 2))
    try staleFirst.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 11, timestamp: 3))
    try staleFirst.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 11, timestamp: 4))

    _ = try staleSecond.receive(maxByteCount: 1_200)
    _ = try staleSecond.receive(maxByteCount: 1_200)
    _ = try staleSecond.receive(maxByteCount: 1_200)
    _ = try staleSecond.receive(maxByteCount: 1_200)

    #expect(staleSecond.metrics.packetsLost == 0)
    #expect(staleSecond.metrics.latePackets == 2)
    #expect(staleSecond.metrics.reorderedPackets == 1)
    #expect(staleSecond.metrics.duplicatePackets == 1)

    let adverseFirst = try UdpMediaTransport.bindLoopback()
    defer { adverseFirst.close() }
    let adverseSecond = try UdpMediaTransport.bindLoopback()
    defer { adverseSecond.close() }

    try adverseFirst.connect(to: adverseSecond.localEndpoint)
    try adverseSecond.connect(to: adverseFirst.localEndpoint)

    for sequence in [UInt64(1), 3, 2, 2, 5] {
        try adverseFirst.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: sequence, timestamp: sequence))
        _ = try adverseSecond.receive(maxByteCount: 1_200)
    }

    #expect(adverseSecond.metrics.packetsReceived == 5)
    #expect(adverseSecond.metrics.packetsLost == 2)
    #expect(adverseSecond.metrics.latePackets == 2)
    #expect(adverseSecond.metrics.reorderedPackets == 1)
    #expect(adverseSecond.metrics.duplicatePackets == 1)

    let skewFirst = try UdpMediaTransport.bindLoopback()
    defer { skewFirst.close() }
    let skewSecond = try UdpMediaTransport.bindLoopback()
    defer { skewSecond.close() }

    try skewFirst.connect(to: skewSecond.localEndpoint)
    try skewSecond.connect(to: skewFirst.localEndpoint)

    try skewFirst.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 1, timestamp: UInt64.max))
    _ = try skewSecond.receive(maxByteCount: 1_200)

    #expect(skewSecond.metrics.clockSkewEventCount == 1)
    #expect(skewSecond.metrics.jitterMicroseconds == 0)

    let jitterFirst = try UdpMediaTransport.bindLoopback()
    defer { jitterFirst.close() }
    let jitterSecond = try UdpMediaTransport.bindLoopback()
    defer { jitterSecond.close() }

    try jitterFirst.connect(to: jitterSecond.localEndpoint)
    try jitterSecond.connect(to: jitterFirst.localEndpoint)

    for sequence in UInt64(1)...UInt64(3) {
        try jitterFirst.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: sequence, timestamp: sequence))
        _ = try jitterSecond.receive(maxByteCount: 1_200)
    }

    #expect(jitterSecond.metrics.jitterMicroseconds == 0)
}

@Test
func udpMediaTransportTracksBoundedAdverseNetworkConditions() throws {
    let burstFirst = try UdpMediaTransport.bindLoopback()
    defer { burstFirst.close() }
    let burstSecond = try UdpMediaTransport.bindLoopback()
    defer { burstSecond.close() }
    try burstFirst.connect(to: burstSecond.localEndpoint)
    try burstSecond.connect(to: burstFirst.localEndpoint)

    for sequence in [UInt64(1), 8] {
        try burstFirst.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: sequence, timestamp: sequence))
        _ = try burstSecond.receive(maxByteCount: 1_200)
    }

    #expect(burstSecond.metrics.packetsLost == 6)
    #expect(burstSecond.metrics.packetsReceived == 2)

    let rolloverFirst = try UdpMediaTransport.bindLoopback()
    defer { rolloverFirst.close() }
    let rolloverSecond = try UdpMediaTransport.bindLoopback()
    defer { rolloverSecond.close() }
    try rolloverFirst.connect(to: rolloverSecond.localEndpoint)
    try rolloverSecond.connect(to: rolloverFirst.localEndpoint)

    for sequence in [UInt64.max - 1, UInt64.max, 0, 0] {
        try rolloverFirst.send(keepaliveMediaPacket(
            streamID: 2,
            sequenceNumber: sequence,
            timestamp: sequence == 0 ? 1 : sequence
        ))
        _ = try rolloverSecond.receive(maxByteCount: 1_200)
    }

    #expect(rolloverSecond.metrics.packetsLost == 0)
    #expect(rolloverSecond.metrics.duplicatePackets == 1)
    #expect(rolloverSecond.metrics.latePackets == 1)
    #expect(rolloverSecond.metrics.reorderedPackets == 0)

    let videoFirst = try UdpMediaTransport.bindLoopback()
    defer { videoFirst.close() }
    let videoSecond = try UdpMediaTransport.bindLoopback()
    defer { videoSecond.close() }
    try videoFirst.connect(to: videoSecond.localEndpoint)
    try videoSecond.connect(to: videoFirst.localEndpoint)

    try videoFirst.send(try singleVideoMediaPacket(streamID: 7, sequenceNumber: 5))
    try videoFirst.send(try singleVideoMediaPacket(streamID: 7, sequenceNumber: 4))
    _ = try videoSecond.receive(maxByteCount: 1_200)
    _ = try videoSecond.receive(maxByteCount: 1_200)

    #expect(videoSecond.metrics.packetsLost == 0)
    #expect(videoSecond.metrics.latePackets == 1)
    #expect(videoSecond.metrics.reorderedPackets == 1)

    let mixedFirst = try UdpMediaTransport.bindLoopback()
    defer { mixedFirst.close() }
    let mixedSecond = try UdpMediaTransport.bindLoopback()
    defer { mixedSecond.close() }
    try mixedFirst.connect(to: mixedSecond.localEndpoint)
    try mixedSecond.connect(to: mixedFirst.localEndpoint)

    let mixedPackets = [
        keepaliveMediaPacket(streamID: 1, sequenceNumber: 1, timestamp: 1),
        keepaliveMediaPacket(streamID: 2, sequenceNumber: 20, timestamp: 20),
        keepaliveMediaPacket(streamID: 1, sequenceNumber: 2, timestamp: 2),
        keepaliveMediaPacket(streamID: 2, sequenceNumber: 22, timestamp: 22),
    ]
    for packet in mixedPackets {
        try mixedFirst.send(packet)
        _ = try mixedSecond.receive(maxByteCount: 1_200)
    }

    #expect(mixedSecond.metrics.packetsReceived == 4)
    #expect(mixedSecond.metrics.packetsLost == 1)
    #expect(mixedSecond.metrics.latePackets == 0)

    let timeoutTransport = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 0)
    defer { timeoutTransport.close() }

    #expect(try timeoutTransport.waitForReadable(timeoutMicroseconds: 1_000) == false)
    #expect(try timeoutTransport.tryReceive(maxByteCount: 1_200) == nil)
    #expect(timeoutTransport.metrics.packetsReceived == 0)
}

@Test
func udpMediaJitterAggregationKeepsPerStreamStateAndReportsMax() {
    var jitter = UdpMediaJitterState()

    for _ in 0..<15 {
        _ = jitter.record(payloadType: .audioPcmV2, streamID: 1, transitMicroseconds: 0)
    }
    let audioJitter = jitter.record(payloadType: .audioPcmV2, streamID: 1, transitMicroseconds: 160)
    #expect(audioJitter == 10)

    for _ in 0..<15 {
        _ = jitter.record(payloadType: .videoRawFrameFragment, streamID: 2, transitMicroseconds: 0)
    }
    let aggregateWithVideoJitter = jitter.record(
        payloadType: .videoRawFrameFragment,
        streamID: 2,
        transitMicroseconds: 1_600
    )
    #expect(aggregateWithVideoJitter == 100)

    let aggregateAfterAudioUpdate = jitter.record(
        payloadType: .audioPcmV2,
        streamID: 1,
        transitMicroseconds: 160
    )
    #expect(aggregateAfterAudioUpdate == 100)
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

private func singleVideoMediaPacket(
    streamID: UInt32,
    sequenceNumber: UInt64
) throws -> UdpMediaPacket {
    let frame = CapturedVideoFrame(
        streamID: streamID,
        sequenceNumber: sequenceNumber,
        timestampNanoseconds: sequenceNumber,
        timestampBasis: .hostUptimeNanoseconds,
        sourceRole: .avFoundationDevice,
        width: 4,
        height: 4,
        pixelFormat: "bgra8",
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        fingerprint: "adverse-video-\(sequenceNumber)"
    )
    return try #require(VideoMediaPacketizer.packets(for: frame, maxPacketBytes: 1_200).first)
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
