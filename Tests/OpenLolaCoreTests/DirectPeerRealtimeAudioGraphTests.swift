import CoreAudio
import Foundation
import Testing

@testable import OpenLolaCore


@Test
func directPeerRealtimeAudioGraphRejectsInvalidConfigurationWithoutTrap() throws {
    #expect(throws: RealtimeAudioBufferConfigurationError.nonPositiveField("ringCapacityBlocks")) {
        _ = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
            audioDeviceUID: "synthetic",
            sampleRateHertz: 48_000,
            framesPerBuffer: 1,
            channelCount: 1,
            sampleFormat: .float32LittleEndian,
            inputChannelMap: [0],
            outputChannelMap: [0],
            ringCapacityBlocks: 0
        ))
    }

    #expect(throws: RealtimeAudioBufferConfigurationError.negativeChannelMapIndex("inputChannelMap")) {
        _ = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
            audioDeviceUID: "synthetic",
            sampleRateHertz: 48_000,
            framesPerBuffer: 1,
            channelCount: 1,
            sampleFormat: .float32LittleEndian,
            inputChannelMap: [-1],
            outputChannelMap: [0],
            ringCapacityBlocks: 1
        ))
    }
}

@Test
func directPeerRealtimeAudioGraphConfigurationRequiresSplitDeviceUIDsWhenDecoding() throws {
    let modernJSON = Data("""
    {
      "inputDeviceUID": "modern-input",
      "outputDeviceUID": "modern-output",
      "sampleRateHertz": 48000,
      "framesPerBuffer": 32,
      "channelCount": 2,
      "sampleFormat": 2,
      "inputChannelMap": [0, 1],
      "outputChannelMap": [0, 1]
    }
    """.utf8)
    let legacyJSON = Data("""
    {
      "audioDeviceUID": "legacy-full-duplex",
      "sampleRateHertz": 48000,
      "framesPerBuffer": 32,
      "channelCount": 2,
      "sampleFormat": 2,
      "inputChannelMap": [0, 1],
      "outputChannelMap": [0, 1]
    }
    """.utf8)

    let configuration = try JSONDecoder().decode(
        DirectPeerRealtimeAudioGraphConfiguration.self,
        from: modernJSON
    )

    #expect(configuration.inputDeviceUID == "modern-input")
    #expect(configuration.outputDeviceUID == "modern-output")

    #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(
            DirectPeerRealtimeAudioGraphConfiguration.self,
            from: legacyJSON
        )
    }

    let encoded = try JSONEncoder().encode(configuration)
    let encodedObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(encodedObject["audioDeviceUID"] == nil)
    #expect(encodedObject["inputDeviceUID"] as? String == "modern-input")
    #expect(encodedObject["outputDeviceUID"] as? String == "modern-output")
}

@Test
func directPeerRealtimeAudioGraphStopReportsCleanupFailures() throws {
    let graph = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        inputDeviceUID: "synthetic-input",
        outputDeviceUID: "synthetic-output",
        sampleRateHertz: 48_000,
        framesPerBuffer: 1,
        channelCount: 1,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0],
        outputChannelMap: [0],
        ringCapacityBlocks: 1
    ))

    graph.setCleanupStateForTesting(
        inputDeviceID: 101,
        inputIOProcID: directPeerRealtimeAudioInputIOProc,
        outputDeviceID: 202,
        outputIOProcID: directPeerRealtimeAudioOutputIOProc,
        originalInputSampleRate: 44_100,
        originalInputBufferFrameSize: 64,
        originalOutputSampleRate: 48_000,
        originalOutputBufferFrameSize: 128
    )
    graph.setCleanupOperationOverridesForTesting(
        stop: { deviceID, _ in deviceID == 101 ? OSStatus(-101) : noErr },
        destroy: { deviceID, _ in deviceID == 202 ? OSStatus(-202) : noErr },
        setDouble: { deviceID, _, _, _ in
            if deviceID == 101 {
                throw AudioLoopbackRunError.coreAudioStatus(OSStatus(-301), "test input sample-rate restore")
            }
        },
        setUInt32: { deviceID, _, _, _ in
            if deviceID == 202 {
                throw AudioLoopbackRunError.coreAudioStatus(OSStatus(-402), "test output buffer restore")
            }
        }
    )

    let result = graph.stop()

    #expect(result == DirectPeerRealtimeAudioGraphCleanupResult(failures: [
        .init(operation: "stop input AudioDeviceIOProc", status: OSStatus(-101)),
        .init(operation: "destroy output AudioDeviceIOProc", status: OSStatus(-202)),
        .init(operation: "restore input sample rate", status: OSStatus(-301)),
        .init(operation: "restore output buffer frame size", status: OSStatus(-402)),
    ]))
    #expect(!result.succeeded)
    #expect(graph.lastCleanupResult() == result)
    #expect(graph.stop().succeeded)
}

@Test
func directPeerRealtimeAudioGraphHostTimeConversionReportsOverflowWithoutStoppingCallback() {
    #expect(nanosecondsFromHostTime(UInt64.max, numerator: 2, denominator: 1) == nil)
    #expect(nanosecondsFromHostTime(12, numerator: 3, denominator: 2) == 18)
}

@Test
func directPeerRealtimeAudioGraphCaptureInjectionHonorsIOProcAndBorrowLifetime() throws {
    let graph = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 1,
        channelCount: 1,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0],
        outputChannelMap: [0],
        ringCapacityBlocks: 1
    ))
    let payload = float32Data([1])

    graph.setIOProcRunningForTesting(true)
    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 10) == .invalid)
    #expect(graph.withCapturedPayload { _, _ in true } == nil)

    graph.setIOProcRunningForTesting(false)
    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 20) == .stored)

    let borrowedStartFrame = try #require(graph.withCapturedPayload { block, payloadBytes in
        #expect(Data(bytes: payloadBytes.baseAddress!, count: payloadBytes.count) == payload)
        return block.startFrame
    })

    #expect(borrowedStartFrame == 0)
    #expect(graph.withCapturedPayload { _, _ in true } == nil)

    let counters = graph.runtimeCounters()
    #expect(counters.capturedInputBlocks == 1)
    #expect(counters.droppedInputBlocks == 1)
}

@Test
func directPeerRealtimeAudioGraphAccountsDropsUnderrunsAndOverflowingPlayoutFrames() throws {
    let overflowGraph = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 1,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0],
        outputChannelMap: [0],
        ringCapacityBlocks: 1,
        rxBufferPolicy: try RxBufferPolicy.direct(framesPerPacket: 32, sampleRateHertz: 48_000)
    ))

    #expect(overflowGraph.queuePlayoutPayload(
        float32Data([1]),
        startFrame: UInt64.max - 10,
        hostTimeNanoseconds: 1
    ) == .invalid)
    #expect(overflowGraph.runtimeCounters().droppedOutputBlocks == 1)

    let graph = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 1,
        channelCount: 1,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0],
        outputChannelMap: [0],
        ringCapacityBlocks: 1
    ))
    let payload = float32Data([1])

    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 10) == .stored)
    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 20) == .full)
    #expect(try graph.withCapturedPayload { _, payloadBytes in
        Data(bytes: try #require(payloadBytes.baseAddress), count: payloadBytes.count)
    } == payload)
    #expect(graph.queuePlayoutPayload(payload, startFrame: 0, hostTimeNanoseconds: 30) == .stored)
    #expect(graph.queuePlayoutPayload(payload, startFrame: 1, hostTimeNanoseconds: 40) == .full)

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

    #expect(firstRendered == 1)
    #expect(secondRendered == 0)
    let counters = graph.runtimeCounters()
    #expect(counters.capturedInputBlocks == 1)
    #expect(counters.droppedInputBlocks == 1)
    #expect(counters.inputOverrunBlocks == 1)
    #expect(counters.callbackOverrunBlocks == 1)
    #expect(counters.droppedOutputBlocks == 1)
    #expect(counters.outputBlocks == 2)
    #expect(counters.outputUnderrunBlocks == 1)
}

@Test
func directPeerRealtimeAudioGraphAppliesRxBufferTargetAndPlaysReorderedPayloads() throws {
    let graph = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 1,
        channelCount: 1,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0],
        outputChannelMap: [0],
        ringCapacityBlocks: 2,
        rxBufferPolicy: try .direct(framesPerPacket: 1, sampleRateHertz: 48_000)
    ))
    var outputSamples = [Float(-1)]

    #expect(graph.queuePlayoutPayload(float32Data([9]), startFrame: 0, hostTimeNanoseconds: 100) == .stored)
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
        #expect(outputBytes.load(as: Float.self) == 0)
        graph.renderPlayoutForTesting(output: &outputList)
        #expect(outputBytes.load(as: Float.self) == 9)
    }

    let reorderedGraph = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 1,
        channelCount: 1,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0],
        outputChannelMap: [0],
        ringCapacityBlocks: 3,
        rxBufferPolicy: try .direct(framesPerPacket: 1, sampleRateHertz: 48_000)
    ))
    var reorderedOutputSamples = [Float(-1)]

    #expect(reorderedGraph.queuePlayoutPayload(float32Data([2]), startFrame: 1, hostTimeNanoseconds: 200) == .stored)
    #expect(reorderedGraph.queuePlayoutPayload(float32Data([1]), startFrame: 0, hostTimeNanoseconds: 100) == .stored)
    try reorderedOutputSamples.withUnsafeMutableBytes { outputBytes in
        let outputBase = try #require(outputBytes.baseAddress)
        var outputList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(outputBytes.count),
                mData: outputBase
            )
        )

        reorderedGraph.renderPlayoutForTesting(output: &outputList)
        #expect(outputBytes.load(as: Float.self) == 0)
        reorderedGraph.renderPlayoutForTesting(output: &outputList)
        #expect(outputBytes.load(as: Float.self) == 1)
        reorderedGraph.renderPlayoutForTesting(output: &outputList)
        #expect(outputBytes.load(as: Float.self) == 2)
    }

    let counters = reorderedGraph.runtimeCounters()
    #expect(counters.outputBlocks == 3)
    #expect(counters.outputUnderrunBlocks == 1)
    #expect(counters.droppedOutputBlocks == 0)
}

@Test
func directPeerRealtimeAudioGraphMovesCapturedPayloadsAcrossConcurrentProducerConsumer() throws {
    let graph = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 1,
        channelCount: 1,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0],
        outputChannelMap: [0],
        ringCapacityBlocks: 2
    ))
    let iterations = 32
    let produced = DispatchSemaphore(value: 0)
    let consumed = DispatchSemaphore(value: 0)
    let done = DispatchSemaphore(value: 0)
    let producerState = DirectPeerGraphConcurrentProducerState()

    DispatchQueue.global(qos: .userInitiated).async {
        for index in 0..<iterations {
            let result = graph.captureInjectedPayload(
                float32Data([Float(index)]),
                hostTimeNanoseconds: UInt64(index + 1)
            )
            producerState.append(result)
            produced.signal()

            guard consumed.wait(timeout: .now() + 2) == .success else {
                producerState.markTimedOut()
                break
            }
        }
        done.signal()
    }

    var captured: [(startFrame: UInt64, payload: Data)] = []
    for _ in 0..<iterations {
        #expect(produced.wait(timeout: .now() + 2) == .success)
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
        consumed.signal()
    }

    #expect(done.wait(timeout: .now() + 2) == .success)
    let (results, timedOut) = producerState.snapshot()

    #expect(!timedOut)
    #expect(results == Array(repeating: .stored, count: iterations))
    #expect(captured.map(\.startFrame) == (0..<UInt64(iterations)).map { $0 })
    #expect(captured.map(\.payload) == (0..<iterations).map { float32Data([Float($0)]) })
    let counters = graph.runtimeCounters()
    #expect(counters.capturedInputBlocks == iterations)
    #expect(counters.droppedInputBlocks == 0)
    #expect(counters.inputOverrunBlocks == 0)
}

@Test
func directPeerRealtimeAudioGraphRejectsZeroChannelInterleavedInputAndOutput() throws {
    let graph = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 1,
        channelCount: 1,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0],
        outputChannelMap: [0],
        ringCapacityBlocks: 1
    ))
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

    #expect(graph.withCapturedPayload { _, _ in true } == nil)
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

    let capturedStartFrame = try #require(graph.withCapturedPayload { block, _ in
        block.startFrame
    })
    #expect(capturedStartFrame == 0)

    let outputGraph = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 1,
        channelCount: 1,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0],
        outputChannelMap: [0],
        ringCapacityBlocks: 1
    ))
    var outputSample = Float(-1)

    #expect(outputGraph.queuePlayoutPayload(float32Data([7]), startFrame: 0, hostTimeNanoseconds: 100) == .stored)
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

private func float32Data(_ values: [Float]) -> Data {
    var values = values
    return values.withUnsafeMutableBytes { Data($0) }
}

private final class DirectPeerGraphConcurrentProducerState: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [SPSCAtomicRingResult] = []
    private var timedOut = false

    func append(_ result: SPSCAtomicRingResult) {
        lock.lock()
        results.append(result)
        lock.unlock()
    }

    func markTimedOut() {
        lock.lock()
        timedOut = true
        lock.unlock()
    }

    func snapshot() -> (results: [SPSCAtomicRingResult], timedOut: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (results, timedOut)
    }
}

private func directPeerFullDuplexDevice() -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        id: 1,
        name: "Full Duplex",
        uid: "full-duplex",
        manufacturer: nil,
        transportType: nil,
        isAggregate: false,
        inputChannelCount: 2,
        outputChannelCount: 2,
        inputStreamCount: 1,
        outputStreamCount: 1,
        nominalSampleRateHertz: 48_000,
        availableSampleRateRanges: [AudioValueRangeSnapshot(minimum: 48_000, maximum: 48_000)],
        currentBufferFrameSize: 32,
        bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 32, maximum: 128),
        candidateBufferFrames: BufferFrameCandidates(
            candidates: [32, 64, 128],
            reportedRange: AudioValueRangeSnapshot(minimum: 32, maximum: 128)
        ),
        inputLatencyFrames: nil,
        outputLatencyFrames: nil,
        inputSafetyOffsetFrames: nil,
        outputSafetyOffsetFrames: nil,
        clockDomain: nil,
        diagnosticNotes: []
    )
}
