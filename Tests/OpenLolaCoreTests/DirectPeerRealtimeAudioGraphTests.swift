import CoreAudio
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerRealtimeAudioGraphRejectsInjectedCaptureWhileIOProcIsRunning() throws {
    let graph = DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
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

    let counters = graph.runtimeCounters()
    #expect(counters.capturedInputBlocks == 1)
    #expect(counters.droppedInputBlocks == 1)
}

@Test
func directPeerRealtimeAudioGraphUsesDirectionalIOProcsForSplitDevices() throws {
    let source = try readDirectPeerRealtimeAudioGraphSource()

    #expect(source.contains("makeAndStartIOProc(deviceID: inputDeviceID, ioProc: directPeerRealtimeAudioInputIOProc)"))
    #expect(source.contains("makeAndStartIOProc(deviceID: outputDeviceID, ioProc: directPeerRealtimeAudioOutputIOProc)"))
}

@Test
func directPeerRealtimeAudioGraphAllocatesScratchWithSIMDAlignment() throws {
    let source = try readDirectPeerRealtimeAudioGraphSource()

    #expect(source.contains("let directPeerRealtimeAudioBufferAlignment = max(16, MemoryLayout<Float>.alignment)"))
    #expect(source.contains("alignment: directPeerRealtimeAudioBufferAlignment"))
    #expect(!source.contains("alignment: MemoryLayout<UInt8>.alignment"))
}

@Test
func directPeerAudioPayloadRingDocumentsStrictlyBeforeDropSemantics() throws {
    let source = try readOpenLolaCoreSource(
        "Sources/OpenLolaCore/Audio/Realtime/DirectPeerAudioPayloadRing.swift"
    )

    #expect(source.contains("Only payloads strictly before the requested start frame are stale"))
    #expect(source.contains("startFrames[slot] < startFrame"))
}

@Test
func directPeerRealtimeAudioGraphDeinitStopsIOProcsBeforeScratchDeallocation() throws {
    let source = try readDirectPeerRealtimeAudioGraphSource()
    let deinitRange = try #require(source.range(of: "deinit {"))
    let deinitBodyEnd = try #require(source.range(
        of: "    }",
        range: deinitRange.upperBound..<source.endIndex
    ))
    let deinitBody = String(source[deinitRange.lowerBound..<deinitBodyEnd.upperBound])

    #expect(deinitBody.contains("stop()"))
    let stopRange = try #require(deinitBody.range(of: "stop()"))
    let deallocateRange = try #require(deinitBody.range(of: "inputScratch.deallocate()"))
    #expect(stopRange.lowerBound < deallocateRange.lowerBound)
}

@Test
func directPeerRealtimeAudioGraphConfigurationMarksLegacyAudioDeviceUIDDeprecated() throws {
    let source = try readDirectPeerRealtimeAudioGraphTypesSource()

    #expect(source.contains("@available(*, deprecated"))
    #expect(source.contains("Use inputDeviceUID and outputDeviceUID"))
    #expect(source.contains("legacy config migration"))
}

@Test
func directPeerRealtimeAudioGraphConfigurationMigratesLegacyAudioDeviceUIDJSON() throws {
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

    let configuration = try JSONDecoder().decode(DirectPeerRealtimeAudioGraphConfiguration.self, from: legacyJSON)
    let encoded = try JSONEncoder().encode(configuration)
    let encodedObject = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )

    #expect(configuration.inputDeviceUID == "legacy-full-duplex")
    #expect(configuration.outputDeviceUID == "legacy-full-duplex")
    #expect(encodedObject["audioDeviceUID"] == nil)
}

@Test
func directPeerRealtimeAudioGraphIOProcDoesNotAssertInRealtimeCallback() throws {
    let source = try readDirectPeerRealtimeAudioGraphSource()

    #expect(!source.contains("assertionFailure"))
}

@Test
func directPeerRealtimeAudioGraphReadOnlyBufferListBoundsChecksInRelease() throws {
    let source = try readDirectPeerRealtimeAudioGraphSource()

    #expect(!source.contains("precondition(index >= 0 && index < count"))
    #expect(source.contains("subscript(index: Int) -> AudioBuffer?"))
    #expect(source.contains("guard index >= 0 && index < count else"))
    #expect(source.contains("readOnlyBufferLocation(\n                    forStableChannel: inputChannel"))
}

@Test
func directPeerRealtimeAudioGraphClassifiesInputCopyFailures() throws {
    let source = try readDirectPeerRealtimeAudioGraphSource()

    #expect(source.contains("private enum DirectPeerInputCopyResult"))
    #expect(source.contains("case inputChannelOutOfRange"))
    #expect(source.contains("case inputBufferUnavailable"))
    #expect(source.contains("case inputBufferTooSmall"))
    #expect(source.contains("case destinationBufferTooSmall"))
    #expect(source.contains("let copyResult = copyMappedInput(from: buffers)"))
    #expect(source.contains("guard copyResult == .copied else"))
    #expect(!source.contains("private func copyMappedInput(from buffers: ReadOnlyAudioBufferListPointer) -> Bool"))
}

@Test
func directPeerRealtimeAudioGraphHostTimeConversionRejectsOverflow() throws {
    let source = try readDirectPeerRealtimeAudioGraphSource()

    #expect(source.contains("hostTime.multipliedReportingOverflow"))
    #expect(source.contains("precondition(hostTimeDenominator > 0"))
    #expect(source.contains("return overflow ? nil : scaled / hostTimeDenominator"))
    #expect(source.contains("guard let hostTimeNanoseconds = graph.nanoseconds(fromHostTime: inNow.pointee.mHostTime) else"))
}

@Test
func directPeerRealtimeAudioGraphSerializesLifecycleAndInjectedCapture() throws {
    let source = try readDirectPeerRealtimeAudioGraphSource()

    #expect(source.contains("private let lifecycleLock = NSLock()"))
    #expect(source.contains("lifecycleLock.lock()"))
    #expect(source.contains("defer { lifecycleLock.unlock() }"))
    #expect(source.contains("stopUnlocked()"))
}

@Test
func directPeerRealtimeAudioGraphRejectsDoubleStartBeforeReplacingIOProcIDs() throws {
    let typeSource = try readDirectPeerRealtimeAudioGraphTypesSource()
    let graphSource = try readDirectPeerRealtimeAudioGraphSource()

    #expect(typeSource.contains("case graphAlreadyStarted"))
    #expect(graphSource.contains("guard inputIOProcID == nil"))
    #expect(graphSource.contains("outputIOProcID == nil"))
    #expect(graphSource.contains("throw DirectPeerAudioGraphError.graphAlreadyStarted"))
}

@Test
func directPeerRealtimeAudioGraphRejectsOverflowingPlayoutStartFrame() throws {
    let graph = DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
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
    let payload = float32Data([1])

    #expect(graph.queuePlayoutPayload(
        payload,
        startFrame: UInt64.max - 10,
        hostTimeNanoseconds: 1
    ) == .invalid)
    #expect(graph.runtimeCounters().droppedOutputBlocks == 1)
}

@Test
func directPeerRealtimeAudioGraphMapsInterleavedInputAndOutputChannels() throws {
    let graph = DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 2,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [2, 0],
        outputChannelMap: [1, 2],
        ringCapacityBlocks: 2
    ))
    var inputSamples: [Float] = [
        10, 11, 12,
        20, 21, 22,
    ]
    var outputSamples = Array(repeating: Float(-1), count: 6)

    try inputSamples.withUnsafeMutableBytes { inputBytes in
        try outputSamples.withUnsafeMutableBytes { outputBytes in
            let inputBase = try #require(inputBytes.baseAddress)
            let outputBase = try #require(outputBytes.baseAddress)
            var inputList = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: 3,
                    mDataByteSize: UInt32(inputBytes.count),
                    mData: inputBase
                )
            )
            var outputList = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: 3,
                    mDataByteSize: UInt32(outputBytes.count),
                    mData: outputBase
                )
            )

            graph.captureInputForTesting(input: &inputList, hostTimeNanoseconds: 100)
            let capturedPayload = try #require(graph.withCapturedPayload { block, payloadBytes in
                guard let baseAddress = payloadBytes.baseAddress else {
                    Issue.record("expected captured payload bytes")
                    return Data()
                }
                let payload = Data(bytes: baseAddress, count: payloadBytes.count)
                #expect(block.startFrame == 0)
                return payload
            })
            #expect(capturedPayload == float32Data([12, 10, 22, 20]))
            #expect(graph.queuePlayoutPayload(capturedPayload, startFrame: 0, hostTimeNanoseconds: 100) == .stored)
            graph.renderPlayoutForTesting(output: &outputList)
        }
    }

    #expect(outputSamples == [0, 12, 10, 0, 22, 20])
    let counters = graph.runtimeCounters()
    #expect(counters.capturedInputBlocks == 1)
    #expect(counters.droppedInputBlocks == 0)
    #expect(counters.outputBlocks == 1)
    #expect(counters.outputUnderrunBlocks == 0)
}

@Test
func directPeerRealtimeAudioGraphMapsStableChannelsAcrossMultibufferLayouts() throws {
    let graph = DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 2,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [2, 1],
        outputChannelMap: [3, 0],
        ringCapacityBlocks: 2
    ))
    var inputBufferA: [Float] = [
        10, 11,
        20, 21,
    ]
    var inputBufferB: [Float] = [
        12, 13,
        22, 23,
    ]
    var outputBufferA = Array(repeating: Float(-1), count: 4)
    var outputBufferB = Array(repeating: Float(-1), count: 4)

    try inputBufferA.withUnsafeMutableBytes { inputABytes in
        try inputBufferB.withUnsafeMutableBytes { inputBBytes in
            try outputBufferA.withUnsafeMutableBytes { outputABytes in
                try outputBufferB.withUnsafeMutableBytes { outputBBytes in
                    let inputList = AudioBufferList.allocate(maximumBuffers: 2)
                    defer { inputList.unsafeMutablePointer.deallocate() }
                    let outputList = AudioBufferList.allocate(maximumBuffers: 2)
                    defer { outputList.unsafeMutablePointer.deallocate() }
                    inputList.count = 2
                    outputList.count = 2
                    inputList.unsafeMutablePointer.pointee.mNumberBuffers = 2
                    outputList.unsafeMutablePointer.pointee.mNumberBuffers = 2
                    inputList[0] = AudioBuffer(
                        mNumberChannels: 2,
                        mDataByteSize: UInt32(inputABytes.count),
                        mData: inputABytes.baseAddress!
                    )
                    inputList[1] = AudioBuffer(
                        mNumberChannels: 2,
                        mDataByteSize: UInt32(inputBBytes.count),
                        mData: inputBBytes.baseAddress!
                    )
                    outputList[0] = AudioBuffer(
                        mNumberChannels: 2,
                        mDataByteSize: UInt32(outputABytes.count),
                        mData: outputABytes.baseAddress!
                    )
                    outputList[1] = AudioBuffer(
                        mNumberChannels: 2,
                        mDataByteSize: UInt32(outputBBytes.count),
                        mData: outputBBytes.baseAddress!
                    )
                    inputList.count = 2
                    outputList.count = 2
                    inputList.unsafeMutablePointer.pointee.mNumberBuffers = 2
                    outputList.unsafeMutablePointer.pointee.mNumberBuffers = 2
                    #expect(inputList.unsafePointer.pointee.mNumberBuffers == 2)
                    let readOnlyInput = ReadOnlyAudioBufferListPointer(inputList.unsafePointer)
                    #expect(readOnlyInput.count == 2)
                    #expect(readOnlyInput[0]?.mNumberChannels == 2)
                    #expect(readOnlyInput[1]?.mNumberChannels == 2)
                    #expect(readOnlyInput[1]?.mDataByteSize == UInt32(inputBBytes.count))
                    #expect(readOnlyInput[1]?.mData != nil)

                    graph.captureInputForTesting(
                        input: inputList.unsafePointer,
                        hostTimeNanoseconds: 100
                    )
                    #expect(graph.runtimeCounters().capturedInputBlocks == 1)
                    #expect(graph.runtimeCounters().droppedInputBlocks == 0)
                    let capturedPayload = try #require(graph.withCapturedPayload { _, payloadBytes in
                        guard let baseAddress = payloadBytes.baseAddress else {
                            Issue.record("expected captured payload bytes")
                            return Data()
                        }
                        return Data(bytes: baseAddress, count: payloadBytes.count)
                    })
                    #expect(capturedPayload == float32Data([12, 11, 22, 21]))
                    #expect(graph.queuePlayoutPayload(
                        capturedPayload,
                        startFrame: 0,
                        hostTimeNanoseconds: 100
                    ) == .stored)
                    graph.renderPlayoutForTesting(output: outputList.unsafeMutablePointer)
                }
            }
        }
    }

    #expect(outputBufferA == [11, 0, 21, 0])
    #expect(outputBufferB == [0, 12, 0, 22])
    let counters = graph.runtimeCounters()
    #expect(counters.capturedInputBlocks == 1)
    #expect(counters.droppedInputBlocks == 0)
    #expect(counters.droppedOutputBlocks == 0)
}

@Test
func directPeerRealtimeAudioGraphPreflightValidatesChannelMapLength() throws {
    let inventory = CoreAudioInventoryReport(
        capturedAt: "2026-05-10T00:00:00Z",
        hostName: "test-host",
        devices: [directPeerFullDuplexDevice()]
    )
    let missingOutput = DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "full-duplex",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0]
    )
    let negativeInput = DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "full-duplex",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [-1, 0],
        outputChannelMap: [0, 1]
    )

    #expect(throws: DirectPeerAudioGraphError.channelMapOutOfRange(
        scope: .output,
        index: 1,
        available: 2
    )) {
        _ = try DirectPeerRealtimeAudioGraph.preflight(
            configuration: missingOutput,
            inventory: inventory
        )
    }
    let negativePreflight = DirectPeerRealtimeAudioGraphPreflight.evaluate(
        configuration: negativeInput,
        inventory: inventory
    )
    #expect(negativePreflight.blockers.contains(
        "requested input channel map contains a negative channel index"
    ))
}

@Test
func directPeerRealtimeAudioGraphAccountsDropsAndUnderruns() throws {
    let graph = DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
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
func directPeerRealtimeAudioGraphAppliesRxBufferTargetBeforePlayout() throws {
    let graph = DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
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
}

@Test
func directPeerRealtimeAudioGraphPlaysReorderedPayloadAtDueFrame() throws {
    let graph = DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
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
    var outputSamples = [Float(-1)]

    #expect(graph.queuePlayoutPayload(float32Data([2]), startFrame: 1, hostTimeNanoseconds: 200) == .stored)
    #expect(graph.queuePlayoutPayload(float32Data([1]), startFrame: 0, hostTimeNanoseconds: 100) == .stored)
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
        #expect(outputBytes.load(as: Float.self) == 1)
        graph.renderPlayoutForTesting(output: &outputList)
        #expect(outputBytes.load(as: Float.self) == 2)
    }

    let counters = graph.runtimeCounters()
    #expect(counters.outputBlocks == 3)
    #expect(counters.outputUnderrunBlocks == 1)
    #expect(counters.droppedOutputBlocks == 0)
}

@Test
func directPeerRealtimeAudioGraphCanBorrowCapturedPayloadUntilSendCompletes() throws {
    let graph = DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 1,
        channelCount: 1,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0],
        outputChannelMap: [0],
        ringCapacityBlocks: 1
    ))
    let payload = float32Data([3])

    #expect(graph.captureInjectedPayload(payload, hostTimeNanoseconds: 10) == .stored)
    let borrowedStartFrame = try #require(graph.withCapturedPayload { block, payloadBytes in
        #expect(Data(bytes: payloadBytes.baseAddress!, count: payloadBytes.count) == payload)
        return block.startFrame
    })

    #expect(borrowedStartFrame == 0)
    #expect(graph.withCapturedPayload { _, _ in true } == nil)
}

@Test
func directPeerRealtimeAudioGraphRejectsZeroChannelInterleavedInput() throws {
    let graph = DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
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
}

@Test
func directPeerRealtimeAudioGraphRejectsZeroChannelInterleavedOutput() throws {
    let graph = DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
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

    #expect(graph.queuePlayoutPayload(float32Data([7]), startFrame: 0, hostTimeNanoseconds: 100) == .stored)
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

        graph.renderPlayoutForTesting(output: &outputList)
    }

    #expect(outputSample == 0)
    let counters = graph.runtimeCounters()
    #expect(counters.outputBlocks == 1)
    #expect(counters.droppedOutputBlocks == 1)
}

@Test
func directPeerRealtimeAudioGraphStartRollsBackPartialStartup() throws {
    let source = try readDirectPeerRealtimeAudioGraphSource()

    #expect(source.contains("originalInputSampleRate = doubleProperty"))
    #expect(source.contains("originalInputBufferFrameSize = uint32Property"))
    #expect(source.contains("} catch {\n            stopUnlocked()\n            throw error\n        }"))
    #expect(source.contains("AudioDeviceDestroyIOProcID(deviceID, createdIOProcID)"))
    #expect(source.contains("if let inputDeviceID, let originalInputSampleRate"))
    #expect(source.contains("if let inputDeviceID, let originalInputBufferFrameSize"))
    #expect(source.contains("Unmanaged.passUnretained(self).toOpaque()"))
    #expect(source.contains(".takeUnretainedValue()"))
    #expect(!source.contains("Unmanaged.passRetained(self).toOpaque()"))
    #expect(!source.contains(".takeRetainedValue()"))
}

private func float32Data(_ values: [Float]) -> Data {
    var values = values
    return values.withUnsafeMutableBytes { Data($0) }
}

private func readDirectPeerRealtimeAudioGraphSource() throws -> String {
    try [
        "Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift",
        "Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphCallbacks.swift",
    ]
        .map(readOpenLolaCoreSource)
        .joined(separator: "\n")
}

private func readDirectPeerRealtimeAudioGraphTypesSource() throws -> String {
    try readOpenLolaCoreSource(
        "Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift"
    )
}

private func readOpenLolaCoreSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
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
