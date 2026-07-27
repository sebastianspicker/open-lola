// Shared UDP media transport helpers keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaCore

func expectAudioEnvelopeCarriesMetadata() throws {
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

}

func expectVideoEnvelopeCarriesMetadata() throws {
    let frame = m06CapturedVideoFrame()
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

}

func expectTimingEnvelopeCarriesMetadata() throws {
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

func expectUdpMediaTransportTracksLoss() throws {
    let (first, second) = try connectedUdpMediaTransports()
    defer { first.close(); second.close() }

    try first.send(try m06MediaAudioPacket(streamID: 1, sequenceNumber: 1))
    try first.send(try m06MediaAudioPacket(streamID: 1, sequenceNumber: 3))

    _ = try second.receive(maxByteCount: 1_200)
    _ = try second.receive(maxByteCount: 1_200)

    #expect(first.metrics.packetsSent == 2)
    #expect(second.metrics.packetsReceived == 2)
    #expect(second.metrics.packetsLost == 1)
    #expect(second.metrics.jitterMicroseconds >= 0)

}

func m06CapturedVideoFrame() -> CapturedVideoFrame {
    CapturedVideoFrame(
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
}

func connectedUdpMediaTransports() throws -> (UdpMediaTransport, UdpMediaTransport) {
    let sender = try UdpMediaTransport.bindLoopback()
    let receiver = try UdpMediaTransport.bindLoopback()
    try sender.connect(to: receiver.localEndpoint)
    try receiver.connect(to: sender.localEndpoint)
    return (sender, receiver)
}

func expectUdpMediaTransportTracksRolloverLoss() throws {
    let (rolloverFirst, rolloverSecond) = try connectedUdpMediaTransports()
    defer { rolloverFirst.close(); rolloverSecond.close() }

    try rolloverFirst.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: UInt64.max, timestamp: 1))
    try rolloverFirst.send(keepaliveMediaPacket(streamID: 1, sequenceNumber: 2, timestamp: 2))

    _ = try rolloverSecond.receive(maxByteCount: 1_200)
    _ = try rolloverSecond.receive(maxByteCount: 1_200)

    #expect(rolloverSecond.metrics.packetsLost == 2)

}

func expectUdpMediaTransportTracksStaleDuplicateAndReorderedPackets() throws {
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

}

func expectUdpMediaTransportTracksAdverseOrderingMetrics() throws {
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

}

func expectUdpMediaTransportTracksClockSkew() throws {
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

}

func expectUdpMediaTransportKeepsZeroJitterForUniformTransit() throws {
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

func expectUdpMediaTransportTracksBurstLoss() throws {
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

}

func expectUdpMediaTransportTracksBoundedRolloverDuplicates() throws {
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

}

func expectUdpMediaTransportTracksVideoLateReordering() throws {
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

}

func expectUdpMediaTransportTracksMixedStreams() throws {
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
        keepaliveMediaPacket(streamID: 2, sequenceNumber: 22, timestamp: 22)
    ]
    for packet in mixedPackets {
        try mixedFirst.send(packet)
        _ = try mixedSecond.receive(maxByteCount: 1_200)
    }

    #expect(mixedSecond.metrics.packetsReceived == 4)
    #expect(mixedSecond.metrics.packetsLost == 1)
    #expect(mixedSecond.metrics.latePackets == 0)

}

func expectUdpMediaTransportTimeoutHasNoPackets() throws {
    let timeoutTransport = try UdpMediaTransport.bindLoopback(receiveTimeoutSeconds: 0)
    defer { timeoutTransport.close() }

    #expect(try timeoutTransport.waitForReadable(timeoutMicroseconds: 1_000) == false)
    #expect(try timeoutTransport.tryReceive(maxByteCount: 1_200) == nil)
    #expect(timeoutTransport.metrics.packetsReceived == 0)
}
final class UdpMediaTransportCloseRaceState: @unchecked Sendable {
    private let lock = NSLock()
    private var didComplete = false
    private var receivedErrorDescription: String?

    func finish(error: Error?) {
        lock.lock()
        didComplete = true
        receivedErrorDescription = error.map { String(describing: $0) }
        lock.unlock()
    }

    func snapshot() -> (completed: Bool, errorDescription: String?) {
        lock.lock()
        defer { lock.unlock() }
        return (didComplete, receivedErrorDescription)
    }
}
