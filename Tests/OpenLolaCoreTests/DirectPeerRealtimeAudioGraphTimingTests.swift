// Verifies that direct peer real-time audio graph callback timing avoids DispatchTime.now() as a clock source.
import CoreAudio
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerRealtimeAudioGraphCallbackTimingAvoidsDispatchTimeNowSource() throws {
    let source = try repositoryFile("Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphIO.swift")

    #expect(!source.contains("DispatchTime.now()"))
    #expect(source.contains("mach_absolute_time()"))
}

@Test
func directPeerRealtimeAudioGraphCallbackCopyAvoidsPerSampleOffsetGuardSource() throws {
    let source = try repositoryFile(
        "Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphAudioCopy.swift"
    )

    #expect(!source.contains("audioByteOffset("))
    #expect(source.contains("audioChannelCopyPlan("))
}

@Test
func realtimeAudioCaptureRingBufferListAccessAvoidsForceUnwrapAndTrapSource() throws {
    let source = try repositoryFile("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift")

    #expect(!source.contains("offset(of: \\.mBuffers)!"))
    #expect(!source.contains("AudioBufferList index out of bounds"))
    #expect(source.contains("guard index >= 0 && index < count"))
}

@Test
func directPeerRealtimeAudioGraphCallbackTimingRecordsMachTickDurationAndDeadlineMiss() throws {
    let graph = try makeDirectPeerRealtimeAudioGraph()
    let ticks = DirectPeerCallbackTimingTickSequence([100, 5_000_000_100])
    graph.setCallbackTimingTickForTesting { ticks.next() }
    var inputSamples = [Float(1)]
    var outputSamples = [Float(-1)]

    try withMutableAudioBufferList(samples: &inputSamples, channelCount: 1) { inputList in
        try withMutableAudioBufferList(samples: &outputSamples, channelCount: 1) { outputList in
            graph.processIO(hostTimeNanoseconds: 100, input: inputList, output: outputList)
        }
    }

    let counters = graph.runtimeCounters()
    #expect(ticks.remainingCount == 0)
    #expect(counters.callbackInvocationBlocks == 1)
    #expect(counters.callbackMaxMicroseconds > 0)
    #expect(counters.callbackDeadlineMisses == 1)
}

@Test
func directPeerRealtimeAudioGraphCallbackCopyKeepsPlanarBuffers() throws {
    let graph = try makeDirectPeerRealtimeAudioGraph(
        inputChannelMap: [1, 0],
        outputChannelMap: [1, 0],
        framesPerBuffer: 2,
        channelCount: 2,
        ringCapacityBlocks: 2
    )
    var input0: [Float] = [1, 2]
    var input1: [Float] = [10, 20]

    try withTwoPlanarFloatBufferList(channel0: &input0, channel1: &input1) { inputList in
        graph.captureInputForTesting(input: inputList, hostTimeNanoseconds: 100)
    }

    let captured = try #require(graph.withCapturedPayload { _, payload in Data(payload) })
    #expect(captured == float32Data([10, 1, 20, 2]))

    #expect(
        graph.queuePlayoutPayload(
            float32Data([100, 200, 101, 201]),
            startFrame: 0,
            hostTimeNanoseconds: 200
        ) == .stored
    )
    var output0 = Array(repeating: Float(-1), count: 2)
    var output1 = Array(repeating: Float(-1), count: 2)

    try withTwoPlanarFloatBufferList(channel0: &output0, channel1: &output1) { outputList in
        graph.renderPlayoutForTesting(output: outputList)
    }

    #expect(output0 == [200, 201])
    #expect(output1 == [100, 101])
}

@Test
func directPeerRealtimeAudioGraphCallbackCopyDropsMalformedPlanarBuffers() throws {
    let graph = try makeDirectPeerRealtimeAudioGraph(
        inputChannelMap: [1, 0],
        outputChannelMap: [1, 0],
        framesPerBuffer: 2,
        channelCount: 2
    )
    var input0: [Float] = [1, 2]
    var input1: [Float] = [10, 20]

    try withTwoPlanarFloatBufferList(
        channel0: &input0,
        channel1: &input1,
        channel1ByteCountOverride: MemoryLayout<Float>.stride
    ) { inputList in
        graph.captureInputForTesting(input: inputList, hostTimeNanoseconds: 300)
    }

    let counters = graph.runtimeCounters()
    #expect(counters.capturedInputBlocks == 0)
    #expect(counters.droppedInputBlocks == 1)
}

private func repositoryFile(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

private func float32Data(_ values: [Float]) -> Data {
    var values = values
    return values.withUnsafeMutableBytes { Data($0) }
}

private func withTwoPlanarFloatBufferList<Result>(
    channel0: inout [Float],
    channel1: inout [Float],
    channel1ByteCountOverride: Int? = nil,
    _ body: (UnsafeMutablePointer<AudioBufferList>) throws -> Result
) throws -> Result {
    try channel0.withUnsafeMutableBytes { channel0Bytes in
        try channel1.withUnsafeMutableBytes { channel1Bytes in
            let channel0Base = try #require(channel0Bytes.baseAddress)
            let channel1Base = try #require(channel1Bytes.baseAddress)
            let bufferList = AudioBufferList.allocate(maximumBuffers: 2)
            defer { bufferList.unsafeMutablePointer.deallocate() }

            bufferList.unsafeMutablePointer.pointee.mNumberBuffers = 2
            bufferList[0] = AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(channel0Bytes.count),
                mData: channel0Base
            )
            bufferList[1] = AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(channel1ByteCountOverride ?? channel1Bytes.count),
                mData: channel1Base
            )

            return try body(bufferList.unsafeMutablePointer)
        }
    }
}

final class DirectPeerCallbackTimingTickSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var ticks: [UInt64]

    init(_ ticks: [UInt64]) {
        self.ticks = ticks
    }

    var remainingCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return ticks.count
    }

    func next() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return ticks.isEmpty ? 0 : ticks.removeFirst()
    }
}
