// Protects chunked resampling, backpressure recovery, and cross-clock audio timing.
import Foundation
import XCTest
@testable import OpenLolaMediaPlatform

final class RealtimeMediaRegressionTests: XCTestCase {
    func testShortHighRateChunksPreserveDownsamplingPhase() {
        let resampler = LoLaLinearPCMResampler(inputRate: 192_000, outputRate: 48_000, channels: 1)
        var output: [Float] = []
        for base in stride(from: 0, to: 20, by: 2) {
            output += resampler.appendAndProduce([Float(base), Float(base + 1)])
        }
        XCTAssertEqual(output, [0, 4, 8, 12, 16])
    }

    func testExtremeRateDoesNotOverflowBufferedFrameConversion() {
        let resampler = LoLaLinearPCMResampler(inputRate: Int.max, outputRate: 1, channels: 1)
        XCTAssertEqual(resampler.appendAndProduce([0, 1]), [0])
        XCTAssertEqual(resampler.appendAndProduce([2, 3]), [])
    }

    func testFractionalResamplingIsIndependentOfChunkBoundaries() {
        let source = (0..<120).map { Float($0) / 120 }
        let whole = LoLaLinearPCMResampler(inputRate: 44_100, outputRate: 48_000, channels: 2)
        let chunked = LoLaLinearPCMResampler(inputRate: 44_100, outputRate: 48_000, channels: 2)
        let expected = whole.appendAndProduce(source)
        var actual: [Float] = []
        for base in stride(from: 0, to: source.count, by: 4) {
            actual += chunked.appendAndProduce(Array(source[base..<(base + 4)]))
        }
        XCTAssertEqual(actual.count, expected.count)
        for (sample, reference) in zip(actual, expected) {
            XCTAssertEqual(sample, reference, accuracy: 0.000_001)
        }
    }

    func testDroppedDecodedBlockDoesNotReserveOutputTime() throws {
        let target = BackpressurePlayoutTarget()
        let sink = DecodedAudioPlayoutSink(target: target, outputRate: 48_000, channels: 1, framesPerBlock: 2)
        let samples: [Float] = [0.25, 0.5]
        let block = DecodedInterleavedPCM(
            payload: samples.withUnsafeBytes { Data($0) }, sampleRateHertz: 48_000,
            channels: 1, representation: .float32LittleEndian
        )
        sink.start()
        XCTAssertEqual(try sink.enqueue(block, hostTimeNanoseconds: 0).queuedBlocks, 1)
        XCTAssertEqual(try sink.enqueue(block, hostTimeNanoseconds: 1).droppedBlocks, 1)
        XCTAssertEqual(try sink.enqueue(block, hostTimeNanoseconds: 2).queuedBlocks, 1)
        XCTAssertEqual(target.attemptedStartFrames, [2, 4, 4])
        XCTAssertEqual(sink.snapshot.queuedBlocks, 2)
        XCTAssertEqual(sink.snapshot.droppedBlocks, 1)
    }

    func testHostTimeConversionHandlesIntermediateOverflow() {
        XCTAssertEqual(nanosecondsFromHostTime(UInt64.max, numerator: 2, denominator: 2), UInt64.max)
        XCTAssertEqual(nanosecondsFromHostTime(UInt64.max, numerator: 1, denominator: 3), UInt64.max / 3)
        XCTAssertNil(nanosecondsFromHostTime(UInt64.max, numerator: 3, denominator: 2))
        XCTAssertEqual(nanosecondsFromHostTime(0, numerator: 125, denominator: 3), 0)
    }

    func testJitterPercentilePreservesBurstsAndExpiresOldSamples() {
        var jitter = RealtimeAudioInterarrivalJitter(capacity: 128)
        var sender: UInt64 = 5_000_000_000
        var arrival: UInt64 = 1_000_000
        XCTAssertEqual(jitter.observe(senderHostTimeNanoseconds: sender, arrivalNanoseconds: arrival), 0)
        for _ in 0..<126 {
            sender += 1_000_000
            arrival += 1_000_000
            XCTAssertEqual(jitter.observe(senderHostTimeNanoseconds: sender, arrivalNanoseconds: arrival), 0)
        }
        arrival += 10_000_000
        XCTAssertEqual(jitter.observe(senderHostTimeNanoseconds: sender, arrivalNanoseconds: arrival), 0)
        arrival -= 10_000_000
        XCTAssertEqual(jitter.observe(senderHostTimeNanoseconds: sender, arrivalNanoseconds: arrival), 10_000)
        var percentile = 0.0
        for _ in 0..<128 {
            sender += 1_000_000
            arrival += 1_000_000
            percentile = jitter.observe(senderHostTimeNanoseconds: sender, arrivalNanoseconds: arrival)
        }
        XCTAssertEqual(percentile, 0)
    }
}

private final class BackpressurePlayoutTarget: DecodedAudioPlayoutTarget {
    var nextOutputFrameForPlayout: UInt64 { 0 }
    var outputUnderrunBlocksForPlayout: Int { 0 }
    var attemptedStartFrames: [UInt64] = []

    func queuePlayoutForDecodedAudio(_ payload: Data, startFrame: UInt64, hostTimeNanoseconds: UInt64) -> SPSCAtomicRingResult {
        attemptedStartFrames.append(startFrame)
        return attemptedStartFrames.count == 2 ? .full : .stored
    }
}
