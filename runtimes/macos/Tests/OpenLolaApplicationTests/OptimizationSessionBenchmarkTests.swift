// Opt-in release benchmark for incremental reassembly and latest-only video state.
import Foundation
import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaTransport
@testable import OpenLolaApplication
import Testing

@Test func sessionHotPathOptimizationBenchmark() throws {
    guard let outputPath = ProcessInfo.processInfo.environment["OPEN_LOLA_SESSION_BENCHMARK_OUTPUT"] else {
        return
    }
    let firstVideo = try sessionBenchmarkPreparedVideo(sequence: 1)
    let secondVideo = try sessionBenchmarkPreparedVideo(sequence: 2)
    var measurements: [SessionHotPathMeasurement] = []
    for channels in [2, 8, 64] {
        let packets = try sessionBenchmarkAudioPackets(channelCount: channels)
        let reorderedPackets = Array(packets.reversed())
        measurements.append(try measureSessionHotPath(
            variant: "audio-reassembly-ordered", channelCount: channels, iterations: 500
        ) {
            try consumeSessionAudioPackets(packets)
        })
        measurements.append(try measureSessionHotPath(
            variant: "audio-reassembly-reordered", channelCount: channels, iterations: 500
        ) {
            try consumeSessionAudioPackets(reorderedPackets)
        })
    }
    measurements.append(try measureSessionHotPath(
        variant: "video-stalled-after-one-datagram", channelCount: nil, iterations: 1_000
    ) {
        var pending: DirectPeerPendingVideoTransmit? = .init(
            preparedFrame: firstVideo.preparedFrame,
            frameSequenceNumber: firstVideo.frameSequenceNumber,
            timestampNanoseconds: firstVideo.timestampNanoseconds
        )
        var scratch = Data()
        _ = pending?.cursor.encodeNext(into: &scratch)
        let dropped = supersedePendingVideoTransmit(with: secondVideo, pending: &pending)
        return scratch.count + dropped + (pending?.remainingPacketCount ?? 0)
    })
    measurements.append(try measureSessionHotPath(
        variant: "video-backpressure-drop-supersession", channelCount: nil, iterations: 2_000
    ) {
        var pending: DirectPeerPendingVideoTransmit?
        _ = supersedePendingVideoTransmit(with: firstVideo, pending: &pending)
        let dropped = supersedePendingVideoTransmit(with: secondVideo, pending: &pending)
        return dropped + (pending?.remainingPacketCount ?? 0)
    })
    let report = SessionHotPathReport(
        seed: 61_337,
        warmupSamples: 5,
        measuredSamples: 31,
        measurements: measurements,
        incrementalReassemblyBuffersPerDeadline: 1,
        maximumPendingDeadlines: 8,
        preparedVideoEagerPacketArraysPerFrame: 0
    )
    try JSONEncoder().encode(report).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
}

@inline(never)
private func consumeSessionAudioPackets(_ packets: [UdpPcmV2Packet]) throws -> Int {
    var state = DirectPeerOpenLolaRawAudioReassemblyState()
    var checksum = 0
    for packet in packets {
        if let block = try state.receive(packet) {
            checksum &+= block.payload.count
            checksum &+= Int(truncatingIfNeeded: block.senderFrameIndex)
        }
    }
    return checksum
}

@inline(never)
private func measureSessionHotPath(
    variant: String,
    channelCount: Int?,
    iterations: Int,
    operation: () throws -> Int
) throws -> SessionHotPathMeasurement {
    var checksum = 0
    for _ in 0..<5 {
        for _ in 0..<iterations { checksum &+= try operation() }
    }
    var samples: [Double] = []
    samples.reserveCapacity(31)
    for _ in 0..<31 {
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations { checksum &+= try operation() }
        samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / Double(iterations) / 1_000)
    }
    precondition(checksum != 0)
    return .init(variant: variant, channelCount: channelCount, samplesMicroseconds: samples)
}

private func sessionBenchmarkAudioPackets(channelCount: Int) throws -> [UdpPcmV2Packet] {
    let request = UdpPcmV2FragmentPlanRequest(.init(
        streamID: 1,
        audio: .init(totalChannelCount: channelCount, framesPerPacket: 32,
                     sampleRateHertz: 48_000, sampleFormat: .float32LittleEndian),
        fragmentationLimits: .init(maxTransmissionUnitBytes: 1_200, maxFragmentsPerDeadline: 16),
        metadata: .init(metadataRevision: 0, packingMode: .interleavedChannelRange)
    ))
    let mode = AudioTransportMode(
        transport: .init(protocolVersion: .udpPcmV2, latencyProfile: .safeLowLatency,
                         rxBufferProfile: .direct, maxTransmissionUnitBytes: 1_200),
        format: .init(sampleRateHertz: 48_000, framesPerPacket: 32,
                      channelCount: channelCount, sampleFormat: .float32LittleEndian),
        layout: .init(channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
                      fragments: try UdpPcmV2FragmentPlanner.plan(request))
    )
    return try UdpPcmV2Packetizer.packetize(
        Data((0..<mode.payloadByteCount).map { UInt8(($0 * 17 + 61_337) & 0xff) }),
        sequenceNumber: 73,
        senderFrameIndex: 2_336,
        senderHostTimeNanoseconds: 80_000,
        mode: mode
    )
}

private func sessionBenchmarkPreparedVideo(sequence: UInt64) throws -> DirectPeerPreparedVideoTransmit {
    let metadata = CapturedVideoFrame(
        streamID: 5,
        sequenceNumber: sequence,
        timestampNanoseconds: 1_000 + sequence,
        timestampBasis: .syntheticMonotonicNanoseconds,
        sourceRole: .testPattern,
        width: 320,
        height: 180,
        pixelFormat: "BGRA",
        frameRate: .init(numerator: 30, denominator: 1),
        fingerprint: "session-benchmark-\(sequence)"
    )
    let prepared = try RawVideoFrameTransport.prepareMediaDatagrams(
        for: RawCapturedVideoFrame(metadata: metadata, payload: Data(repeating: 0x41, count: 320 * 180 * 4)),
        maxPacketBytes: 1_200,
        payloadType: .videoRawFrameFragment
    )
    return .init(preparedFrame: prepared, frameSequenceNumber: sequence,
                 timestampNanoseconds: metadata.timestampNanoseconds)
}

private struct SessionHotPathReport: Encodable {
    let seed: Int
    let warmupSamples: Int
    let measuredSamples: Int
    let measurements: [SessionHotPathMeasurement]
    let incrementalReassemblyBuffersPerDeadline: Int
    let maximumPendingDeadlines: Int
    let preparedVideoEagerPacketArraysPerFrame: Int
}

private struct SessionHotPathMeasurement: Encodable {
    let variant: String
    let channelCount: Int?
    let samplesMicroseconds: [Double]
}
