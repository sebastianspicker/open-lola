// Verifies that direct peer real-time audio graph signals captured payload without polling.
import CoreAudio
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerRealtimeAudioGraphSignalsCapturedPayloadWithoutPolling() throws {
    let graph = try makeDirectPeerRealtimeAudioGraph(framesPerBuffer: 8, ringCapacityBlocks: 2)

    #expect(!graph.waitForCapturedPayload(until: .now()))
    #expect(graph.captureInjectedPayload(Data(repeating: 0, count: 32), hostTimeNanoseconds: 1) == .stored)
    #expect(graph.waitForCapturedPayload(until: .now() + .milliseconds(10)))
    #expect(graph.withCapturedPayload { block, _ in block.startFrame } == 0)
    #expect(!graph.waitForCapturedPayload(until: .now()))
}

@Test
func directPeerRealtimeAudioGraphDirectProfileSignalsDescriptorReadiness() throws {
    let graph = try makeDirectPeerRealtimeAudioGraph(
        framesPerBuffer: 8,
        ringCapacityBlocks: 2,
        rxBufferPolicy: try RxBufferPolicy.direct(framesPerPacket: 8, sampleRateHertz: 48_000)
    )
    let descriptor = try #require(graph.captureReadinessDescriptor)

    #expect(graph.captureInjectedPayload(Data(repeating: 0, count: 32), hostTimeNanoseconds: 1) == .stored)
    #expect(try waitForReadableSocket(socket: descriptor, timeoutMicroseconds: 10_000))
    graph.consumeCapturedReadiness()
    #expect(try !waitForReadableSocket(socket: descriptor, timeoutMicroseconds: 1))
}

@Test
func directPeerRealtimeAudioGraphFastestFreshnessDropKeepsNewestPayload() throws {
    let graph = try makeDirectPeerRealtimeAudioGraph(ringCapacityBlocks: 4)
    for value in UInt8(1)...UInt8(4) {
        #expect(graph.captureInjectedPayload(
            Data(repeating: value, count: 4),
            hostTimeNanoseconds: UInt64(value)
        ) == .stored)
    }

    #expect(graph.dropCapturedPayloadsKeepingNewest() == 3)
    #expect(graph.withCapturedPayload { _, payload in Data(payload) } == Data(repeating: 4, count: 4))
    #expect(!graph.waitForCapturedPayload(until: .now()))
}

@Test
func directPeerRealtimeAudioGraphAccountsDropsUnderrunsAndOverflowingPlayoutFrames() throws {
    try assertOverflowingPlayoutStartFrameIsRejected()
    try assertRuntimeCountersTrackDropsUnderrunsAndOverflowingPlayoutFrames()
}

private func assertOverflowingPlayoutStartFrameIsRejected() throws {
    let overflowGraph = try makeDirectPeerRealtimeAudioGraph(
        framesPerBuffer: 32,
        rxBufferPolicy: try RxBufferPolicy.direct(framesPerPacket: 32, sampleRateHertz: 48_000)
    )

    #expect(overflowGraph.queuePlayoutPayload(
        directPeerGraphFloat32Data([1]),
        startFrame: UInt64.max - 10,
        hostTimeNanoseconds: 1
    ) == .invalid)
    #expect(overflowGraph.runtimeCounters().droppedOutputBlocks == 1)
}

private func assertRuntimeCountersTrackDropsUnderrunsAndOverflowingPlayoutFrames() throws {
    let graph = try makeDirectPeerRealtimeAudioGraph()
    let payload = directPeerGraphFloat32Data([1])

    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 10) == .stored)
    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 20) == .full)
    #expect(try graph.withCapturedPayload { _, payloadBytes in
        Data(bytes: try #require(payloadBytes.baseAddress), count: payloadBytes.count)
    } == payload)
    #expect(graph.queuePlayoutPayload(payload, startFrame: 0, hostTimeNanoseconds: 30) == .stored)
    #expect(graph.queuePlayoutPayload(payload, startFrame: 1, hostTimeNanoseconds: 40) == .full)

    let rendered = try renderTwoPlayoutSamples(from: graph)
    #expect(rendered.first == 1)
    #expect(rendered.second == 0)

    let counters = graph.runtimeCounters()
    #expect(counters.capturedInputBlocks == 1)
    #expect(counters.droppedInputBlocks == 1)
    #expect(counters.inputOverrunBlocks == 1)
    #expect(counters.callbackOverrunBlocks == 1)
    #expect(counters.droppedOutputBlocks == 1)
    #expect(counters.outputBlocks == 2)
    #expect(counters.outputUnderrunBlocks == 1)
}

private func renderTwoPlayoutSamples(from graph: DirectPeerRealtimeAudioGraph) throws -> (first: Float, second: Float) {
    var outputSamples = [Float(-1)]
    var firstRendered = Float(-1)
    var secondRendered = Float(-1)

    try outputSamples.withUnsafeMutableBytes { outputBytes in
        let outputBase = try #require(outputBytes.baseAddress)
        var outputList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(outputBytes.count),
                mData: outputBase
            )
        )
        graph.renderPlayoutForTesting(output: &outputList)
        firstRendered = outputBytes.load(as: Float.self)
        graph.renderPlayoutForTesting(output: &outputList)
        secondRendered = outputBytes.load(as: Float.self)
    }

    return (firstRendered, secondRendered)
}

@Test
func directPeerRealtimeAudioGraphCallbackTimingCountersCoverMaxChannelFrameShape() throws {
    let channelCount = 64
    let framesPerBuffer = 32
    let graph = try makeDirectPeerRealtimeAudioGraph(
        inputChannelMap: Array(0..<channelCount),
        outputChannelMap: Array(0..<channelCount),
        framesPerBuffer: framesPerBuffer,
        channelCount: channelCount,
        ringCapacityBlocks: 2
    )
    let callbackTicks = DirectPeerCallbackTimingTickSequence([100, 200])
    graph.setCallbackTimingTickForTesting { callbackTicks.next() }
    var inputSamples = Array(repeating: Float(1), count: framesPerBuffer * channelCount)
    var outputSamples = Array(repeating: Float(-1), count: framesPerBuffer * channelCount)

    try withMutableAudioBufferList(samples: &inputSamples, channelCount: UInt32(channelCount)) { inputList in
        try withMutableAudioBufferList(samples: &outputSamples, channelCount: UInt32(channelCount)) { outputList in
            graph.processIO(hostTimeNanoseconds: 100, input: inputList, output: outputList)
        }
    }

    let counters = graph.runtimeCounters()
    #expect(counters.callbackInvocationBlocks == 1)
    #expect(counters.capturedInputBlocks == 1)
    #expect(counters.outputBlocks == 1)
    #expect(counters.outputUnderrunBlocks == 1)
    #expect(counters.hostTimeConversionFailures == 0)
    #expect(callbackTicks.remainingCount == 0)
    #expect(counters.callbackMaxMicroseconds < framesPerBuffer * 1_000_000 / 48_000)
    #expect(counters.callbackDeadlineMisses == 0)
}

@Test
func directPeerRealtimeAudioGraphAppliesRxBufferTargetAndPlaysReorderedPayloads() throws {
    try assertRxBufferTargetDelaysFirstPayload()
    let reorderedGraph = try reorderedPayloadGraph()
    try assertReorderedPayloadsPlayInStartFrameOrder(reorderedGraph)

    let counters = reorderedGraph.runtimeCounters()
    #expect(counters.outputBlocks == 3)
    #expect(counters.outputUnderrunBlocks == 1)
    #expect(counters.droppedOutputBlocks == 0)
}

@Test
func directPeerRealtimeAudioGraphMovesCapturedPayloadsAcrossConcurrentProducerConsumer() throws {
    let iterations = 32
    let graph = try concurrentProducerConsumerGraph()
    let semaphores = DirectPeerGraphCaptureSemaphores()
    let producerState = DirectPeerGraphConcurrentProducerState()

    startConcurrentPayloadProducer(
        graph: graph,
        iterations: iterations,
        semaphores: semaphores,
        producerState: producerState
    )
    let captured = try consumeConcurrentPayloads(
        from: graph,
        iterations: iterations,
        semaphores: semaphores
    )
    let (results, timedOut) = producerState.snapshot()

    #expect(!timedOut)
    #expect(results == Array(repeating: .stored, count: iterations))
    #expect(captured.map(\.startFrame) == (0..<UInt64(iterations)).map { $0 })
    #expect(captured.map(\.payload) == (0..<iterations).map { directPeerGraphFloat32Data([Float($0)]) })

    let counters = graph.runtimeCounters()
    #expect(counters.capturedInputBlocks == iterations)
    #expect(counters.droppedInputBlocks == 0)
    #expect(counters.inputOverrunBlocks == 0)
}

private func concurrentProducerConsumerGraph() throws -> DirectPeerRealtimeAudioGraph {
    try makeDirectPeerRealtimeAudioGraph(ringCapacityBlocks: 2)
}

private func startConcurrentPayloadProducer(
    graph: DirectPeerRealtimeAudioGraph,
    iterations: Int,
    semaphores: DirectPeerGraphCaptureSemaphores,
    producerState: DirectPeerGraphConcurrentProducerState
) {
    DispatchQueue.global(qos: .userInitiated).async {
        for index in 0..<iterations {
            let result = graph.captureInjectedPayload(
                directPeerGraphFloat32Data([Float(index)]),
                hostTimeNanoseconds: UInt64(index + 1)
            )
            producerState.append(result)
            semaphores.produced.signal()

            guard semaphores.consumed.wait(timeout: .now() + 2) == .success else {
                producerState.markTimedOut()
                break
            }
        }
        semaphores.done.signal()
    }
}

private func consumeConcurrentPayloads(
    from graph: DirectPeerRealtimeAudioGraph,
    iterations: Int,
    semaphores: DirectPeerGraphCaptureSemaphores
) throws -> [(startFrame: UInt64, payload: Data)] {
    var captured: [(startFrame: UInt64, payload: Data)] = []
    for _ in 0..<iterations {
        #expect(semaphores.produced.wait(timeout: .now() + 2) == .success)
        let item = try #require(graph.withCapturedPayload { block, payloadBytes in
            guard let baseAddress = payloadBytes.baseAddress else {
                return (startFrame: block.startFrame, payload: Data())
            }
            return (
                startFrame: block.startFrame,
                payload: Data(bytes: baseAddress, count: payloadBytes.count)
            )
        })
        captured.append(item)
        semaphores.consumed.signal()
    }
    #expect(semaphores.done.wait(timeout: .now() + 2) == .success)
    return captured
}

@Test
func directPeerRealtimeAudioGraphRejectsZeroChannelInterleavedInputAndOutput() throws {
    try assertZeroChannelInputIsDropped()
    try assertZeroChannelOutputIsDropped()
}

private func assertZeroChannelInputIsDropped() throws {
    let graph = try makeDirectPeerRealtimeAudioGraph()
    var inputSample = Float(1)

    try withUnsafeMutableBytes(of: &inputSample) { inputBytes in
        let inputBase = try #require(inputBytes.baseAddress)
        var inputList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: 0,
                mDataByteSize: UInt32(inputBytes.count),
                mData: inputBase
            )
        )
        graph.captureInputForTesting(input: &inputList, hostTimeNanoseconds: 100)
    }

    let counters = graph.runtimeCounters()
    #expect(counters.capturedInputBlocks == 0)
    #expect(counters.droppedInputBlocks == 1)
    #expect(counters.inputOverrunBlocks == 0)
    #expect(counters.callbackOverrunBlocks == 0)

    inputSample = 2
    try withUnsafeMutableBytes(of: &inputSample) { inputBytes in
        let inputBase = try #require(inputBytes.baseAddress)
        var inputList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(inputBytes.count),
                mData: inputBase
            )
        )
        graph.captureInputForTesting(input: &inputList, hostTimeNanoseconds: 200)
    }
    let capturedStartFrame = try #require(graph.withCapturedPayload { block, _ in block.startFrame })
    #expect(capturedStartFrame == 0)
}

private func assertZeroChannelOutputIsDropped() throws {
    let outputGraph = try makeDirectPeerRealtimeAudioGraph()
    var outputSample = Float(-1)

    #expect(outputGraph.queuePlayoutPayload(
        directPeerGraphFloat32Data([7]),
        startFrame: 0,
        hostTimeNanoseconds: 100
    ) == .stored)
    try withUnsafeMutableBytes(of: &outputSample) { outputBytes in
        let outputBase = try #require(outputBytes.baseAddress)
        var outputList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: 0,
                mDataByteSize: UInt32(outputBytes.count),
                mData: outputBase
            )
        )
        outputGraph.renderPlayoutForTesting(output: &outputList)
    }

    #expect(outputSample == 0)
    let outputCounters = outputGraph.runtimeCounters()
    #expect(outputCounters.outputBlocks == 1)
    #expect(outputCounters.droppedOutputBlocks == 1)
}

private func assertRxBufferTargetDelaysFirstPayload() throws {
    let graph = try makeDirectPeerRealtimeAudioGraph(
        ringCapacityBlocks: 2,
        rxBufferPolicy: try .direct(framesPerPacket: 1, sampleRateHertz: 48_000)
    )
    #expect(graph.queuePlayoutPayload(
        directPeerGraphFloat32Data([9]),
        startFrame: 0,
        hostTimeNanoseconds: 100
    ) == .stored)
    try expectPlayoutSamples(from: graph, equal: [0, 9])
}

private func reorderedPayloadGraph() throws -> DirectPeerRealtimeAudioGraph {
    try makeDirectPeerRealtimeAudioGraph(
        ringCapacityBlocks: 3,
        rxBufferPolicy: try .direct(framesPerPacket: 1, sampleRateHertz: 48_000)
    )
}

private func assertReorderedPayloadsPlayInStartFrameOrder(_ graph: DirectPeerRealtimeAudioGraph) throws {
    #expect(graph.queuePlayoutPayload(
        directPeerGraphFloat32Data([2]),
        startFrame: 1,
        hostTimeNanoseconds: 200
    ) == .stored)
    #expect(graph.queuePlayoutPayload(
        directPeerGraphFloat32Data([1]),
        startFrame: 0,
        hostTimeNanoseconds: 100
    ) == .stored)
    try expectPlayoutSamples(from: graph, equal: [0, 1, 2])
}

private func expectPlayoutSamples(
    from graph: DirectPeerRealtimeAudioGraph,
    equal expected: [Float]
) throws {
    var outputSamples = [Float(-1)]
    try outputSamples.withUnsafeMutableBytes { outputBytes in
        let outputBase = try #require(outputBytes.baseAddress)
        var outputList = singleChannelAudioBufferList(bytes: outputBytes, baseAddress: outputBase)
        for expectedSample in expected {
            graph.renderPlayoutForTesting(output: &outputList)
            #expect(outputBytes.load(as: Float.self) == expectedSample)
        }
    }
}
private struct DirectPeerGraphCaptureSemaphores {
    let produced = DispatchSemaphore(value: 0)
    let consumed = DispatchSemaphore(value: 0)
    let done = DispatchSemaphore(value: 0)
}
