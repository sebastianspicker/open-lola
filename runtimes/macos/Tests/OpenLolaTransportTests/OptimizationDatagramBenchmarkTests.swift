// Opt-in release benchmark for borrowed parsing and prepared audio/video datagrams.
import Foundation
import OpenLolaSessionDomain
@testable import OpenLolaTransport
import Testing

@Test func datagramHotPathOptimizationBenchmark() throws {
    guard let outputPath = ProcessInfo.processInfo.environment["OPEN_LOLA_DATAGRAM_BENCHMARK_OUTPUT"] else {
        return
    }
    var measurements: [DatagramHotPathMeasurement] = []
    measurements.append(try parserMeasurement())
    for channels in [2, 8, 64] {
        measurements.append(contentsOf: try audioDatagramMeasurements(channelCount: channels))
    }
    measurements.append(contentsOf: try videoDatagramMeasurements(width: 320, height: 180, iterations: 3))
    measurements.append(contentsOf: try videoDatagramMeasurements(width: 1_920, height: 1_080, iterations: 1))
    let report = DatagramHotPathReport(
        seed: 24_517,
        warmupSamples: 5,
        measuredSamples: 31,
        measurements: measurements,
        temporaryWork: [
            .init(path: "nested-parser", temporaryUInt8ArraysPerDatagram: 0,
                  validationSerializationsPerDatagram: 0, eagerPacketArraysPerUnit: 0),
            .init(path: "prepared-audio", temporaryUInt8ArraysPerDatagram: 0,
                  validationSerializationsPerDatagram: 0, eagerPacketArraysPerUnit: 0),
            .init(path: "prepared-video", temporaryUInt8ArraysPerDatagram: 0,
                  validationSerializationsPerDatagram: 0, eagerPacketArraysPerUnit: 0),
        ]
    )
    try JSONEncoder().encode(report).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
}

private func parserMeasurement() throws -> DatagramHotPathMeasurement {
    let mode = try hotPathAudioMode(channelCount: 8)
    let payload = deterministicDatagramPayload(byteCount: mode.payloadByteCount)
    let packet = try #require(UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 7,
        senderFrameIndex: 32,
        senderHostTimeNanoseconds: 99,
        mode: mode
    ).first)
    let datagram = try UdpMediaPacket(
        header: .init(
            payloadType: .audioPcmV2,
            streamID: packet.header.streamID,
            sequenceNumber: packet.header.sequenceNumber,
            timestampNanoseconds: packet.header.senderHostTimeNanoseconds
        ),
        payload: packet.encoded()
    ).encoded()
    return try measureDatagramHotPath(variant: "nested-parser", channelCount: 8, iterations: 2_000) {
        let decoded = try UdpMediaPacket.decodeWithNestedPayload(datagram)
        guard case .audioPcmV2(let nested) = decoded.decodedPayload else {
            preconditionFailure("expected PCM v2 payload")
        }
        return decoded.packet.payload.count + nested.payload.count
    }
}

private func audioDatagramMeasurements(channelCount: Int) throws -> [DatagramHotPathMeasurement] {
    let mode = try hotPathAudioMode(channelCount: channelCount)
    let plan = try UdpPcmV2ValidatedFragmentPlan(mode: mode)
    let payload = deterministicDatagramPayload(byteCount: mode.payloadByteCount)
    let iterations = channelCount == 64 ? 100 : 400
    var eagerSequence: UInt64 = 1
    let eager = try measureDatagramHotPath(
        variant: "audio-eager", channelCount: channelCount, iterations: iterations
    ) {
        defer { eagerSequence &+= 1 }
        return try payload.withUnsafeBytes { source in
            let packets = try UdpPcmV2Packetizer.packetize(
                source,
                sequenceNumber: eagerSequence,
                senderFrameIndex: eagerSequence,
                senderHostTimeNanoseconds: eagerSequence,
                plan: plan
            )
            return try packets.reduce(into: 0) { checksum, packet in
                checksum &+= try UdpMediaPacket(
                    header: .init(
                        payloadType: .audioPcmV2,
                        streamID: packet.header.streamID,
                        sequenceNumber: eagerSequence,
                        timestampNanoseconds: eagerSequence
                    ),
                    payload: packet.encoded()
                ).encoded().count
            }
        }
    }
    var preparedSequence: UInt64 = 1
    var scratch = Data()
    let prepared = try measureDatagramHotPath(
        variant: "audio-prepared", channelCount: channelCount, iterations: iterations
    ) {
        defer { preparedSequence &+= 1 }
        return try payload.withUnsafeBytes { source in
            try UdpPcmV2Packetizer.validatePacketizeRequest(payload: source, mode: mode)
            var checksum = 0
            for fragment in plan.fragments {
                try UdpPcmV2Packetizer.encodePreparedMediaDatagram(
                    source,
                    sequenceNumber: preparedSequence,
                    senderFrameIndex: preparedSequence,
                    senderHostTimeNanoseconds: preparedSequence,
                    fragment: fragment,
                    mode: mode,
                    into: &scratch
                )
                checksum &+= scratch.count
            }
            return checksum
        }
    }
    return [eager, prepared]
}

private func videoDatagramMeasurements(
    width: Int,
    height: Int,
    iterations: Int
) throws -> [DatagramHotPathMeasurement] {
    let resolution = "\(width)x\(height)"
    let metadata = CapturedVideoFrame(
        streamID: 9,
        sequenceNumber: 11,
        timestampNanoseconds: 12,
        timestampBasis: .syntheticMonotonicNanoseconds,
        sourceRole: .testPattern,
        width: width,
        height: height,
        pixelFormat: "BGRA",
        frameRate: .init(numerator: 30, denominator: 1),
        fingerprint: "benchmark-video-\(resolution)"
    )
    let frame = RawCapturedVideoFrame(
        metadata: metadata,
        payload: Data(repeating: 0x5a, count: width * height * 4)
    )
    return try [
        measureDatagramHotPath(
            variant: "video-eager-full-\(resolution)", channelCount: nil, iterations: iterations
        ) {
            try RawVideoFrameTransport.fragments(
                for: frame, maxPacketBytes: 1_200 - UdpMediaPacketHeader.byteCount
            ).reduce(0) { checksum, fragment in
                checksum &+ (try UdpMediaPacket(
                    header: .init(
                        payloadType: .videoRawFrameFragment,
                        streamID: fragment.streamID,
                        sequenceNumber: fragment.frameSequenceNumber,
                        timestampNanoseconds: fragment.timestampNanoseconds
                    ),
                    payload: fragment.encoded()
                ).encoded().count)
            }
        },
        measureDatagramHotPath(
            variant: "video-prepared-full-\(resolution)", channelCount: nil, iterations: iterations
        ) {
            var cursor = try RawVideoFrameTransport.prepareMediaDatagrams(
                for: frame, maxPacketBytes: 1_200, payloadType: .videoRawFrameFragment
            ).makeCursor()
            var scratch = Data()
            var checksum = 0
            while cursor.encodeNext(into: &scratch) { checksum &+= scratch.count }
            return checksum
        },
        measureDatagramHotPath(
            variant: "video-prepared-one-datagram-quantum-\(resolution)",
            channelCount: nil,
            iterations: 1_000
        ) {
            var cursor = try RawVideoFrameTransport.prepareMediaDatagrams(
                for: frame, maxPacketBytes: 1_200, payloadType: .videoRawFrameFragment
            ).makeCursor()
            var scratch = Data()
            _ = cursor.encodeNext(into: &scratch)
            return scratch.count + cursor.remainingFragmentCount
        },
    ]
}

@inline(never)
private func measureDatagramHotPath(
    variant: String,
    channelCount: Int?,
    iterations: Int,
    operation: () throws -> Int
) throws -> DatagramHotPathMeasurement {
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

private func hotPathAudioMode(channelCount: Int) throws -> AudioTransportMode {
    let request = UdpPcmV2FragmentPlanRequest(.init(
        streamID: 1,
        audio: .init(totalChannelCount: channelCount, framesPerPacket: 32,
                     sampleRateHertz: 48_000, sampleFormat: .float32LittleEndian),
        fragmentationLimits: .init(maxTransmissionUnitBytes: 1_200, maxFragmentsPerDeadline: 16),
        metadata: .init(metadataRevision: 0, packingMode: .interleavedChannelRange)
    ))
    return AudioTransportMode(
        transport: .init(protocolVersion: .udpPcmV2, latencyProfile: .safeLowLatency,
                         rxBufferProfile: .direct, maxTransmissionUnitBytes: 1_200),
        format: .init(sampleRateHertz: 48_000, framesPerPacket: 32,
                      channelCount: channelCount, sampleFormat: .float32LittleEndian),
        layout: .init(channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
                      fragments: try UdpPcmV2FragmentPlanner.plan(request))
    )
}

private func deterministicDatagramPayload(byteCount: Int) -> Data {
    Data((0..<byteCount).map { UInt8(($0 * 31 + 24_517) & 0xff) })
}

private struct DatagramHotPathReport: Encodable {
    let seed: Int
    let warmupSamples: Int
    let measuredSamples: Int
    let measurements: [DatagramHotPathMeasurement]
    let temporaryWork: [DatagramTemporaryWork]
}

private struct DatagramHotPathMeasurement: Encodable {
    let variant: String
    let channelCount: Int?
    let samplesMicroseconds: [Double]
}

private struct DatagramTemporaryWork: Encodable {
    let path: String
    let temporaryUInt8ArraysPerDatagram: Int
    let validationSerializationsPerDatagram: Int
    let eagerPacketArraysPerUnit: Int
}
