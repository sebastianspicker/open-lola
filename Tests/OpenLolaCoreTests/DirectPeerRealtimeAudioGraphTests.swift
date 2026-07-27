// Verifies that direct peer real-time audio graph rejects invalid configuration without trap.
import CoreAudio
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerRealtimeAudioGraphRejectsInvalidConfigurationWithoutTrap() throws {
    #expect(throws: RealtimeAudioBufferConfigurationError.nonPositiveField("ringCapacityBlocks")) {
        _ = try DirectPeerRealtimeAudioGraph(configuration: directPeerGraphConfiguration(ringCapacityBlocks: 0))
    }

    #expect(throws: RealtimeAudioBufferConfigurationError.negativeChannelMapIndex("inputChannelMap")) {
        _ = try DirectPeerRealtimeAudioGraph(configuration: directPeerGraphConfiguration(inputChannelMap: [-1]))
    }
}

func directPeerGraphConfiguration(
    inputChannelMap: [Int] = [0],
    outputChannelMap: [Int] = [0],
    framesPerBuffer: Int = 1,
    channelCount: Int = 1,
    ringCapacityBlocks: Int = 1,
    rxBufferPolicy: RxBufferPolicy? = nil,
    inputDeviceUID: String? = nil,
    outputDeviceUID: String? = nil
) -> DirectPeerRealtimeAudioGraphConfiguration {
    DirectPeerRealtimeAudioGraphConfiguration(
        devices: .init(
            audioDeviceUID: "synthetic",
            inputDeviceUID: inputDeviceUID,
            outputDeviceUID: outputDeviceUID
        ),
        format: .init(sampleRateHertz: 48_000, framesPerBuffer: framesPerBuffer, channelCount: channelCount, sampleFormat: .float32LittleEndian),
        channelMaps: .init(input: inputChannelMap, output: outputChannelMap),
        buffering: .init(ringCapacityBlocks: ringCapacityBlocks, rxBufferPolicy: rxBufferPolicy)
    )
}

func makeDirectPeerRealtimeAudioGraph(
    inputChannelMap: [Int] = [0],
    outputChannelMap: [Int] = [0],
    framesPerBuffer: Int = 1,
    channelCount: Int = 1,
    ringCapacityBlocks: Int = 1,
    rxBufferPolicy: RxBufferPolicy? = nil
) throws -> DirectPeerRealtimeAudioGraph {
    try DirectPeerRealtimeAudioGraph(configuration: directPeerGraphConfiguration(
        inputChannelMap: inputChannelMap,
        outputChannelMap: outputChannelMap,
        framesPerBuffer: framesPerBuffer,
        channelCount: channelCount,
        ringCapacityBlocks: ringCapacityBlocks,
        rxBufferPolicy: rxBufferPolicy
    ))
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
    let graph = try cleanupFailureGraph()
    installCleanupFailureOverrides(on: graph)

    let result = graph.stop()

    #expect(result == cleanupResult(failures: [
        cleanupFailure("stop input AudioDeviceIOProc", OSStatus(-101)),
        cleanupFailure("destroy output AudioDeviceIOProc", OSStatus(-202)),
        cleanupFailure("restore input sample rate", OSStatus(-301)),
cleanupFailure("restore output buffer frame size", OSStatus(-402))
    ]))
    #expect(!result.succeeded)
    #expect(graph.lastCleanupResult() == result)

    #expect(graph.stop() == cleanupResult(failures: [
        cleanupFailure("destroy output AudioDeviceIOProc", OSStatus(-202)),
        cleanupFailure("restore input sample rate", OSStatus(-301)),
cleanupFailure("restore output buffer frame size", OSStatus(-402))
    ]))
    graph.setCleanupOperationOverridesForTesting()
    let retryResult = graph.stop()
    #expect(retryResult.succeeded)
    #expect(graph.lastCleanupResult() == retryResult)
    #expect(graph.stop().succeeded)
}

@Test
func directPeerRealtimeAudioGraphFailedStopClearsRunningAndDestroysIOProc() throws {
let graph = try failedStopCleanupGraph()
var destroyedDeviceIDs: [AudioObjectID] = []
let stopFailure: (AudioObjectID, AudioDeviceIOProcID) -> OSStatus = { _, _ in OSStatus(-101) }
let destroyTracking: (AudioObjectID, AudioDeviceIOProcID) -> OSStatus = { deviceID, _ in
destroyedDeviceIDs.append(deviceID)
return noErr
}
var cleanupOverrides = DirectPeerRealtimeAudioGraph.DirectPeerCleanupOperationOverrides()
cleanupOverrides.stop = stopFailure
cleanupOverrides.destroy = destroyTracking

graph.setCleanupOperationOverridesForTesting(cleanupOverrides)

    let result = graph.stop()

    #expect(result == cleanupResult(failures: [
cleanupFailure("stop input AudioDeviceIOProc", OSStatus(-101))
    ]))
    #expect(!result.succeeded)
    #expect(destroyedDeviceIDs == [101])
    #expect(graph.captureInjectedPayload(directPeerGraphFloat32Data([1]), hostTimeNanoseconds: 10) == .stored)

    graph.setCleanupOperationOverridesForTesting()
    #expect(graph.stop().succeeded)
}

@Test
func directPeerRealtimeAudioGraphHostTimeConversionReportsOverflowWithoutStoppingCallback() throws {
    #expect(nanosecondsFromHostTime(UInt64.max, numerator: 2, denominator: 1) == nil)
    #expect(nanosecondsFromHostTime(12, numerator: 3, denominator: 2) == 18)

    let graph = try DirectPeerRealtimeAudioGraph(configuration: directPeerGraphConfiguration())
    graph.setIOProcRunningForTesting(true)
    graph.setHostTimeConversionForTesting { _ in nil }
    var timestamp = AudioTimeStamp()
    timestamp.mHostTime = 42
    var inputSamples = [Float(1)]
    var outputSamples = [Float(-1)]

    #expect(try invokeDirectPeerRealtimeAudioIOProc(
        graph: graph,
        timestamp: &timestamp,
        inputSamples: &inputSamples,
        outputSamples: &outputSamples
    ) == noErr)

    let counters = graph.runtimeCounters()
    #expect(counters.hostTimeConversionFailures == 1)
    #expect(counters.callbackInvocationBlocks == 0)
    #expect(counters.capturedInputBlocks == 0)
}

@Test
func directPeerRealtimeAudioGraphCaptureInjectionHonorsIOProcAndBorrowLifetime() throws {
    let graph = try DirectPeerRealtimeAudioGraph(configuration: directPeerGraphConfiguration())
    let payload = directPeerGraphFloat32Data([1])

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

private func cleanupResult(
    failures: [DirectPeerRealtimeAudioGraphCleanupFailure]
) -> DirectPeerRealtimeAudioGraphCleanupResult {
    DirectPeerRealtimeAudioGraphCleanupResult(failures: failures)
}

private func cleanupFailure(
_ operation: String,
_ status: OSStatus
) -> DirectPeerRealtimeAudioGraphCleanupFailure {
DirectPeerRealtimeAudioGraphCleanupFailure(operation: operation, status: status)
}

private func failedStopCleanupGraph() throws -> DirectPeerRealtimeAudioGraph {
let graph = try DirectPeerRealtimeAudioGraph(configuration: directPeerGraphConfiguration())
graph.setIOProcRunningForTesting(true)
graph.setCleanupStateForTesting(
inputDeviceID: 101,
inputIOProcID: directPeerRealtimeAudioIOProc,
outputDeviceID: nil,
outputIOProcID: nil,
originalInputSampleRate: nil,
originalInputBufferFrameSize: nil,
originalOutputSampleRate: nil,
originalOutputBufferFrameSize: nil
)
return graph
}

private func cleanupFailureGraph() throws -> DirectPeerRealtimeAudioGraph {
let graph = try DirectPeerRealtimeAudioGraph(configuration: directPeerGraphConfiguration(
    inputDeviceUID: "synthetic-input",
    outputDeviceUID: "synthetic-output"
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
    return graph
}

private func installCleanupFailureOverrides(on graph: DirectPeerRealtimeAudioGraph) {
var overrides = DirectPeerRealtimeAudioGraph.DirectPeerCleanupOperationOverrides()
overrides.stop = { deviceID, _ in deviceID == 101 ? OSStatus(-101) : noErr }
overrides.destroy = { deviceID, _ in deviceID == 202 ? OSStatus(-202) : noErr }
overrides.setDouble = { deviceID, _, _, _ in
if deviceID == 101 {
throw AudioLoopbackRunError.coreAudioStatus(OSStatus(-301), "test input sample-rate restore")
}
}
overrides.setUInt32 = { deviceID, _, _, _ in
if deviceID == 202 {
throw AudioLoopbackRunError.coreAudioStatus(OSStatus(-402), "test output buffer restore")
}
}
graph.setCleanupOperationOverridesForTesting(overrides)
}

func directPeerGraphFloat32Data(_ values: [Float]) -> Data {
    var values = values
    return values.withUnsafeMutableBytes { Data($0) }
}

func withMutableAudioBufferList<Sample, Result>(
    samples: inout [Sample],
    channelCount: UInt32,
    _ body: (UnsafeMutablePointer<AudioBufferList>) throws -> Result
) throws -> Result {
    try samples.withUnsafeMutableBytes { bytes in
        let baseAddress = try #require(bytes.baseAddress)
        let buffer = AudioBuffer(
            mNumberChannels: channelCount,
            mDataByteSize: UInt32(bytes.count),
            mData: baseAddress
        )
        var list = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)
        return try withUnsafeMutablePointer(to: &list, body)
    }
}

func invokeDirectPeerRealtimeAudioIOProc(
    graph: DirectPeerRealtimeAudioGraph,
    timestamp: inout AudioTimeStamp,
    inputSamples: inout [Float],
    outputSamples: inout [Float]
) throws -> OSStatus {
    try withMutableAudioBufferList(samples: &inputSamples, channelCount: 1) { inputList in
        try withMutableAudioBufferList(samples: &outputSamples, channelCount: 1) { outputList in
            directPeerRealtimeAudioIOProc(
                0,
                &timestamp,
                inputList,
                &timestamp,
                outputList,
                &timestamp,
                Unmanaged.passUnretained(graph).toOpaque()
            )
        }
    }
}

func singleChannelAudioBufferList(
    bytes: UnsafeMutableRawBufferPointer,
    baseAddress: UnsafeMutableRawPointer
) -> AudioBufferList {
    AudioBufferList(
        mNumberBuffers: 1,
        mBuffers: AudioBuffer(
            mNumberChannels: 1,
            mDataByteSize: UInt32(bytes.count),
            mData: baseAddress
        )
    )
}

final class DirectPeerGraphConcurrentProducerState: @unchecked Sendable {
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
    syntheticFullDuplexDevice(.init(
        id: 1,
        name: "Full Duplex",
        uid: "full-duplex",
        manufacturer: nil,
        transportType: nil,
        inputChannelCount: 2,
        outputChannelCount: 2,
        candidateBufferFrames: syntheticFullDuplexBufferCandidates(),
        diagnosticNotes: []
    ))
}
