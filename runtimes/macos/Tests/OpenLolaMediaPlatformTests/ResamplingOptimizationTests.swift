// Exact-output fixtures and opt-in release measurements for decoded PCM buffering.
import Foundation
@testable import OpenLolaMediaPlatform
import Testing

private struct ResamplingMeasurement: Encodable {
    let channels: Int
    let inputRate: Int
    let outputRate: Int
    let fingerprint: UInt64
    let sampleCount: Int
    let samplesMicroseconds: [Double]
}

@inline(never) private func resamplingInput(channels: Int) -> [[Float]] {
    var inputs: [[Float]] = []
    for block in 0..<48 {
        let count = (block % 5 + 1) * 32 * channels + block % channels
        var values: [Float] = []
        for index in 0..<count {
            let integer = (index * 13 + block * 17) % 199 - 99
            values.append(Float(integer) / 128)
        }
        inputs.append(values)
    }
    return inputs
}

@inline(never) private func resamplingFingerprint(channels: Int, inputRate: Int, outputRate: Int) -> (UInt64, Int) {
    let resampler = LoLaLinearPCMResampler(inputRate: inputRate, outputRate: outputRate, channels: channels)
    let inputs = resamplingInput(channels: channels)
    var fingerprint: UInt64 = 14_695_981_039_346_656_037
    var sampleCount = 0
    var retained: [Float] = []
    for iteration in 0..<192 {
        if iteration == 96 { resampler.reset() }
        let output = resampler.appendAndProduce(inputs[iteration % inputs.count])
        sampleCount += output.count
        for sample in output {
            fingerprint = (fingerprint ^ UInt64(sample.bitPattern)) &* 1_099_511_628_211
        }
        if iteration == 0 { retained = output }
        if iteration == 1 {
            let separate = LoLaLinearPCMResampler(inputRate: inputRate, outputRate: outputRate, channels: channels)
            #expect(retained == separate.appendAndProduce(inputs[0]))
        }
    }
    resampler.reset()
    #expect(resampler.produce().isEmpty)
    return (fingerprint, sampleCount)
}

@Test func resamplingOptimizationBenchmark() throws {
    guard let path = ProcessInfo.processInfo.environment["OPEN_LOLA_RESAMPLING_BENCHMARK_OUTPUT"] else { return }
    var results: [ResamplingMeasurement] = []
    for channels in [2, 8, 64] {
        for rates in [(48_000, 48_000), (44_100, 48_000), (48_000, 44_100)] {
            let inputs = resamplingInput(channels: channels)
            let resampler = LoLaLinearPCMResampler(inputRate: rates.0, outputRate: rates.1, channels: channels)
            var samples: [Double] = []
            var observed = 0
            for repetition in 0..<36 {
                resampler.reset()
                let start = DispatchTime.now().uptimeNanoseconds
                for block in inputs {
                    let output = resampler.appendAndProduce(block)
                    observed &+= output.count
                    observed &+= Int(output.last?.bitPattern ?? 0)
                }
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000
                if repetition >= 5 { samples.append(elapsed) }
            }
            #expect(observed != 0)
            let (fingerprint, count) = resamplingFingerprint(channels: channels, inputRate: rates.0, outputRate: rates.1)
            results.append(.init(channels: channels, inputRate: rates.0, outputRate: rates.1,
                                 fingerprint: fingerprint, sampleCount: count, samplesMicroseconds: samples))
        }
    }
    try JSONEncoder().encode(results).write(to: URL(fileURLWithPath: path), options: .atomic)
}

private final class BufferingTestTarget: DecodedAudioPlayoutTarget {
    let nextOutputFrameForPlayout: UInt64 = 0
    let outputUnderrunBlocksForPlayout = 0
    var writes: [Data] = []
    var storeWrites = true
    var count = 0
    func queuePlayoutForDecodedAudio(_ payload: Data, startFrame: UInt64, hostTimeNanoseconds: UInt64) -> SPSCAtomicRingResult {
        if storeWrites { writes.append(payload) }
        count += payload.count
        return .stored
    }
}

@Test func playoutAccumulatorPreservesOrderOwnershipAndStopBoundary() throws {
    let target = BufferingTestTarget()
    let sink = DecodedAudioPlayoutSink(target: target, outputRate: 48_000, channels: 2, framesPerBlock: 32)
    let samples = (0..<514).map { Float($0) / 1_024 }
    let data = samples.withUnsafeBytes { Data($0) }
    let block = DecodedInterleavedPCM(payload: data, sampleRateHertz: 48_000, channels: 2, representation: .float32LittleEndian)
    sink.start()
    var combined = Data()
    for _ in 0..<32 {
        try sink.enqueue(block, hostTimeNanoseconds: 1)
        combined.append(data)
    }
    let output = target.writes.reduce(into: Data()) { $0.append($1) }
    #expect(output == combined.prefix(output.count))
    #expect(output.count == combined.count / 256 * 256)
    let retained = target.writes[0]
    sink.stop()
    sink.start()
    let countBefore = target.writes.count
    try sink.enqueue(block, hostTimeNanoseconds: 2)
    #expect(target.writes.count - countBefore == 8)
    #expect(target.writes[countBefore] == retained)
    #expect(retained == data.prefix(256))
}

@Test func playoutBufferingOptimizationBenchmark() throws {
    guard let path = ProcessInfo.processInfo.environment["OPEN_LOLA_PLAYOUT_BENCHMARK_OUTPUT"] else { return }
    var results: [ResamplingMeasurement] = []
    for channels in [2, 8, 64] {
        let samples = (0..<(channels * 4_096)).map { Float($0 % 997) / 1_024 }
        let data = samples.withUnsafeBytes { Data($0) }
        let block = DecodedInterleavedPCM(payload: data, sampleRateHertz: 48_000, channels: channels, representation: .float32LittleEndian)
        let target = BufferingTestTarget()
        target.storeWrites = false
        let sink = DecodedAudioPlayoutSink(target: target, outputRate: 48_000, channels: channels, framesPerBlock: 32)
        var timings: [Double] = []
        for repetition in 0..<36 {
            sink.start()
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<8 { try sink.enqueue(block, hostTimeNanoseconds: 1) }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000
            sink.stop()
            if repetition >= 5 { timings.append(elapsed) }
        }
        #expect(target.count == data.count * 8 * 36)
        results.append(.init(channels: channels, inputRate: 48_000, outputRate: 48_000,
                             fingerprint: UInt64(target.count), sampleCount: samples.count,
                             samplesMicroseconds: timings))
    }
    try JSONEncoder().encode(results).write(to: URL(fileURLWithPath: path), options: .atomic)
}

@Test func resamplingMatchesDirtyBaselineBitPatternsAcrossChunksAndReset() {
    let fixtures: [(Int, Int, Int, UInt64, Int)] = [
        (2, 48000, 48000, 15578353063024189093, 36192),
        (2, 44100, 48000, 6758595744268478621, 39392),
        (2, 48000, 44100, 12164233346256612657, 33248),
        (8, 48000, 48000, 5178540008459204517, 145056),
        (8, 44100, 48000, 16446919433624337869, 157872),
        (8, 48000, 44100, 16923570345099801637, 133264),
        (64, 48000, 48000, 18054608468283769125, 1159552),
        (64, 44100, 48000, 14717754533700857873, 1262080),
        (64, 48000, 44100, 9789515530607845441, 1065344),
    ]
    for (channels, inputRate, outputRate, fingerprint, count) in fixtures {
        let actual = resamplingFingerprint(channels: channels, inputRate: inputRate, outputRate: outputRate)
        #expect(actual.0 == fingerprint)
        #expect(actual.1 == count)
    }
}
