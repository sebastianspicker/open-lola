// Exercises exact-layout bulk copies and mapped fallback copies through the callback-facing audio graph.
import CoreAudio
import Foundation
import XCTest
@testable import OpenLolaMediaPlatform

final class RealtimeAudioCopyRegressionTests: XCTestCase {
    func testIdentityLayoutCopiesInterleavedSamplesExactly() throws {
        try roundTrip(channelMap: [0, 1], expectedCapture: [1, 2, 3, 4])
    }

    func testRemappedLayoutRetainsChannelOrder() throws {
        try roundTrip(channelMap: [1, 0], expectedCapture: [2, 1, 4, 3])
    }

    func testIdentityCaptureRejectsShortBuffer() throws {
        let graph = try makeGraph(channelMap: [0, 1])
        var samples: [Float] = [1, 2, 3]
        samples.withUnsafeMutableBytes { bytes in
            var list = audioBufferList(bytes: bytes)
            withUnsafePointer(to: &list) {
                graph.captureInputForTesting(input: $0, hostTimeNanoseconds: 0)
            }
        }
        XCTAssertNil(graph.withCapturedPayload { _, bytes in Data(bytes) })
        XCTAssertEqual(graph.runtimeCounters().droppedInputBlocks, 1)
    }

    private func roundTrip(channelMap: [Int], expectedCapture: [Float]) throws {
        let graph = try makeGraph(channelMap: channelMap)
        var input: [Float] = [1, 2, 3, 4]
        input.withUnsafeMutableBytes { bytes in
            var list = audioBufferList(bytes: bytes)
            withUnsafePointer(to: &list) {
                graph.captureInputForTesting(input: $0, hostTimeNanoseconds: 7)
            }
        }
        let payload = try XCTUnwrap(graph.withCapturedPayload { block, bytes in
            XCTAssertEqual(block.hostTimeNanoseconds, 7)
            return Data(bytes)
        })
        XCTAssertEqual(payload.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }, expectedCapture)
        XCTAssertEqual(graph.queuePlayoutPayload(payload, startFrame: 0, hostTimeNanoseconds: 7), .stored)
        var output = [Float](repeating: -1, count: 4)
        output.withUnsafeMutableBytes { bytes in
            var list = audioBufferList(bytes: bytes)
            withUnsafeMutablePointer(to: &list) { graph.renderPlayoutForTesting(output: $0) }
        }
        XCTAssertEqual(output, input)
        XCTAssertEqual(graph.runtimeCounters().outputUnderrunBlocks, 0)
    }

    private func makeGraph(channelMap: [Int]) throws -> DirectPeerRealtimeAudioGraph {
        try DirectPeerRealtimeAudioGraph(configuration: .init(
            devices: .init(audioDeviceUID: "synthetic"),
            format: .init(sampleRateHertz: 48_000, framesPerBuffer: 2, channelCount: 2, sampleFormat: .float32LittleEndian),
            channelMaps: .init(input: channelMap, output: channelMap)
        ))
    }

    private func audioBufferList(bytes: UnsafeMutableRawBufferPointer) -> AudioBufferList {
        AudioBufferList(mNumberBuffers: 1, mBuffers: .init(
            mNumberChannels: 2, mDataByteSize: UInt32(bytes.count), mData: bytes.baseAddress
        ))
    }
}
