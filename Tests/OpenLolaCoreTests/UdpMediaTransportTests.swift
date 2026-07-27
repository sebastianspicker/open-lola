// Verifies that media packet envelope carries audio, video, and timing metadata.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func mediaPacketEnvelopeCarriesAudioVideoAndTimingMetadata() throws {
    try expectAudioEnvelopeCarriesMetadata()
    try expectVideoEnvelopeCarriesMetadata()
    try expectTimingEnvelopeCarriesMetadata()
}

@Test
func mediaPacketRejectsTruncatedMismatchedAndMalformedPayloads() throws { // swiftlint:disable:this function_body_length
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

    let mismatchedFrame = m06CapturedVideoFrame()
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

    let frame = m06CapturedVideoFrame()
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
    try expectUdpMediaTransportTracksLoss()
    try expectUdpMediaTransportTracksRolloverLoss()
    try expectUdpMediaTransportTracksStaleDuplicateAndReorderedPackets()
    try expectUdpMediaTransportTracksAdverseOrderingMetrics()
    try expectUdpMediaTransportTracksClockSkew()
    try expectUdpMediaTransportKeepsZeroJitterForUniformTransit()
}

@Test
func udpMediaTransportReportsNonZeroJitterAfterControlledTransitVariation() throws {
    let (first, second) = try connectedUdpMediaTransports()
    defer { first.close(); second.close() }

    for sequence in UInt64(1)...UInt64(20) {
        let timestamp = sequence.isMultiple(of: 2) ? UInt64(1_000) : UInt64(1_000_000)
        try first.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: sequence, timestamp: timestamp))
        _ = try second.receive(maxByteCount: 1_200)
    }

    #expect(second.metrics.packetsReceived == 20)
    #expect(second.metrics.jitterMicroseconds > 0)
}

@Test
func udpMediaTransportTracksBoundedAdverseNetworkConditions() throws {
    try expectUdpMediaTransportTracksBurstLoss()
    try expectUdpMediaTransportTracksBoundedRolloverDuplicates()
    try expectUdpMediaTransportTracksVideoLateReordering()
    try expectUdpMediaTransportTracksMixedStreams()
    try expectUdpMediaTransportTimeoutHasNoPackets()
}

@Test
func udpMediaTransportCloseCompletesWhileReceiveIsBlocking() throws {
    let receiver = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 1)
    let sender = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 1)
    defer { sender.close() }

    try receiver.connect(to: sender.localEndpoint)
    try sender.connect(to: receiver.localEndpoint)

    let state = UdpMediaTransportCloseRaceState()
    let receiveStarted = DispatchSemaphore(value: 0)
    let receiveFinished = DispatchSemaphore(value: 0)

    DispatchQueue.global(qos: .userInitiated).async {
        receiveStarted.signal()
        do {
            _ = try receiver.receive(maxByteCount: 1_200)
            state.finish(error: nil)
        } catch {
            state.finish(error: error)
        }
        receiveFinished.signal()
    }

    #expect(receiveStarted.wait(timeout: .now() + 2) == .success)
    Thread.sleep(forTimeInterval: 0.05)

    let closeStart = DispatchTime.now().uptimeNanoseconds
    receiver.close()
    let closeElapsedMicroseconds = (DispatchTime.now().uptimeNanoseconds - closeStart) / 1_000

    #expect(closeElapsedMicroseconds < 100_000)
    #expect(receiveFinished.wait(timeout: .now() + 2) == .success)

    let snapshot = state.snapshot()
    #expect(snapshot.completed)
    #expect(snapshot.errorDescription != nil)
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
