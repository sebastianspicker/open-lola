// Opt-in packetization benchmark. It writes reproducible samples only when its output path is supplied.
import Foundation
import OpenLolaContracts
import OpenLolaSessionDomain
@testable import OpenLolaTransport
import Testing

@Test func packetizationOptimizationBenchmark() throws {
    guard let outputPath = ProcessInfo.processInfo.environment["OPEN_LOLA_PACKETIZATION_BENCHMARK_OUTPUT"] else {
        return
    }
    let summaries = try [2, 8, 64].flatMap { channels in
        try packetizationSamples(channelCount: channels)
    }
    let data = try JSONEncoder().encode(PacketizationBenchmarkReport(
        seed: 14_921,
        warmupSamples: 5,
        measuredSamples: 31,
        summaries: summaries
    ))
    try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
}

private func packetizationSamples(channelCount: Int) throws -> [PacketizationBenchmarkSummary] {
    let mode = try packetizationMode(channelCount: channelCount)
    let plan = try UdpPcmV2ValidatedFragmentPlan(mode: mode)
    let payload = deterministicPayload(byteCount: mode.payloadByteCount, seed: 14_921)
    let reference = try UdpPcmV2Packetizer.packetize(
        payload,
        sequenceNumber: 1,
        senderFrameIndex: 2,
        senderHostTimeNanoseconds: 3,
        mode: mode
    )
    let prepared = try payload.withUnsafeBytes {
        try UdpPcmV2Packetizer.packetize(
            $0,
            sequenceNumber: 1,
            senderFrameIndex: 2,
            senderHostTimeNanoseconds: 3,
            plan: plan
        )
    }
    #expect(prepared == reference)
    let iterations = channelCount == 2 ? 1_000 : 400
    return try [
        packetizationBenchmarkSummary(
            variant: "public-mode",
            channelCount: channelCount,
            mode: mode,
            iterations: iterations
        ) { sequence in
            try UdpPcmV2Packetizer.packetize(
                payload,
                sequenceNumber: sequence,
                senderFrameIndex: sequence,
                senderHostTimeNanoseconds: sequence,
                mode: mode
            )
        },
        packetizationBenchmarkSummary(
            variant: "prepared-plan",
            channelCount: channelCount,
            mode: mode,
            iterations: iterations
        ) { sequence in
            try payload.withUnsafeBytes {
                try UdpPcmV2Packetizer.packetize(
                    $0,
                    sequenceNumber: sequence,
                    senderFrameIndex: sequence,
                    senderHostTimeNanoseconds: sequence,
                    plan: plan
                )
            }
        }
    ]
}

private func packetizationBenchmarkSummary(
    variant: String,
    channelCount: Int,
    mode: AudioTransportMode,
    iterations: Int,
    operation: (UInt64) throws -> [UdpPcmV2Packet]
) throws -> PacketizationBenchmarkSummary {
    for warmup in 0..<(5 * iterations) {
        _ = try operation(UInt64(warmup))
    }
    var samples: [Double] = []
    samples.reserveCapacity(31)
    var checksum = 0
    for sample in 0..<31 {
        let start = DispatchTime.now().uptimeNanoseconds
        for iteration in 0..<iterations {
            let packets = try operation(UInt64(sample * iterations + iteration))
            checksum &+= packets.reduce(0) { $0 + $1.payload.count }
        }
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        samples.append(Double(elapsed) / Double(iterations) / 1_000)
    }
    precondition(checksum > 0)
    return PacketizationBenchmarkSummary(
        variant: variant,
        channelCount: channelCount,
        payloadByteCount: mode.payloadByteCount,
        fragmentCount: mode.fragments.count,
        samplesMicroseconds: samples
    )
}

private func packetizationMode(channelCount: Int) throws -> AudioTransportMode {
    let request = UdpPcmV2FragmentPlanRequest(.init(
        streamID: 42,
        audio: .init(
            totalChannelCount: channelCount,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian
        ),
        fragmentationLimits: .init(maxTransmissionUnitBytes: 1_200, maxFragmentsPerDeadline: 16),
        metadata: .init(metadataRevision: 0, packingMode: .interleavedChannelRange)
    ))
    let fragments = try UdpPcmV2FragmentPlanner.plan(request)
    return AudioTransportMode(
        transport: .init(
            protocolVersion: .udpPcmV2,
            latencyProfile: .safeLowLatency,
            rxBufferProfile: .direct,
            maxTransmissionUnitBytes: 1_200
        ),
        format: .init(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: channelCount,
            sampleFormat: .float32LittleEndian
        ),
        layout: .init(
            channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
            fragments: fragments
        )
    )
}

private func deterministicPayload(byteCount: Int, seed: Int) -> Data {
    Data((0..<byteCount).map { UInt8((seed + $0 * 31) & 0xff) })
}

private struct PacketizationBenchmarkReport: Encodable {
    let seed: Int
    let warmupSamples: Int
    let measuredSamples: Int
    let summaries: [PacketizationBenchmarkSummary]
}

private struct PacketizationBenchmarkSummary: Encodable {
    let variant: String
    let channelCount: Int
    let payloadByteCount: Int
    let fragmentCount: Int
    let samplesMicroseconds: [Double]
}
