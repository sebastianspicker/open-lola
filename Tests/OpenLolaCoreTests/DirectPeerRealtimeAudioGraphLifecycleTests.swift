// Verifies that direct peer real-time audio graph stop waits for active callback before destroying I/O proc.
import CoreAudio
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerRealtimeAudioGraphStopWaitsForActiveCallbackBeforeDestroyingIOProc() throws {
    let fixture = try directPeerGraphQuiescenceFixture()

    directPeerGraphRunBlockedCallback(
        graph: fixture.graph,
        state: fixture.state,
        callbackFinished: fixture.callbackFinished
    )

    #expect(fixture.callbackEntered.wait(timeout: .now() + 2) == .success)

    DispatchQueue.global(qos: .userInitiated).async {
        fixture.state.setStopResult(fixture.graph.stop())
        fixture.stopReturned.signal()
    }

    fixture.releaseCallback.signal()
    #expect(fixture.stopReturned.wait(timeout: .now() + 2) == .success)
    #expect(fixture.callbackFinished.wait(timeout: .now() + 2) == .success)

    let snapshot = fixture.state.snapshot()
    #expect(snapshot.callbackTimedOut == false)
    #expect(snapshot.callbackStatus == noErr)
    #expect(snapshot.callbackError == nil)
    #expect(snapshot.stopResult?.succeeded == true)
    #expect(snapshot.destroySawCallbackActive == false)
}

private struct DirectPeerGraphQuiescenceFixture {
    var graph: DirectPeerRealtimeAudioGraph
    var state: DirectPeerGraphQuiescenceTestState
    var callbackEntered: DispatchSemaphore
    var releaseCallback: DispatchSemaphore
    var callbackFinished: DispatchSemaphore
    var stopReturned: DispatchSemaphore
}

private func directPeerGraphQuiescenceFixture() throws -> DirectPeerGraphQuiescenceFixture {
    let graph = try directPeerGraphForQuiescenceTest()
    let state = DirectPeerGraphQuiescenceTestState()
    let callbackEntered = DispatchSemaphore(value: 0)
    let releaseCallback = DispatchSemaphore(value: 0)

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
    graph.setHostTimeConversionForTesting { _ in
        state.setCallbackActive(true)
        callbackEntered.signal()
        if releaseCallback.wait(timeout: .now() + 2) != .success {
            state.markCallbackTimedOut()
        }
        return 100
    }
    graph.setCleanupOperationOverridesForTesting(.init(
        stop: { _, _ in noErr },
        destroy: { _, _ in
            state.markDestroySawCallbackActive(state.callbackActive)
            return noErr
        }
    ))

    return DirectPeerGraphQuiescenceFixture(
        graph: graph,
        state: state,
        callbackEntered: callbackEntered,
        releaseCallback: releaseCallback,
        callbackFinished: DispatchSemaphore(value: 0),
        stopReturned: DispatchSemaphore(value: 0)
    )
}

private func directPeerGraphForQuiescenceTest() throws -> DirectPeerRealtimeAudioGraph {
    try makeDirectPeerRealtimeAudioGraph()
}

private func directPeerGraphRunBlockedCallback(
    graph: DirectPeerRealtimeAudioGraph,
    state: DirectPeerGraphQuiescenceTestState,
    callbackFinished: DispatchSemaphore
) {
    DispatchQueue.global(qos: .userInitiated).async {
        defer { callbackFinished.signal() }
        var timestamp = AudioTimeStamp()
        timestamp.mHostTime = 42
        var inputSamples = [Float(1)]
        var outputSamples = [Float(-1)]
        do {
            let status = try invokeDirectPeerRealtimeAudioIOProc(
                graph: graph,
                timestamp: &timestamp,
                inputSamples: &inputSamples,
                outputSamples: &outputSamples
            )
            state.setCallbackStatus(status)
        } catch {
            state.setCallbackError(String(describing: error))
        }
        state.setCallbackActive(false)
    }
}

@Test
func directPeerRealtimeAudioGraphDeinitDoesNotAcquireLifecycleLock() throws {
    var graph: DirectPeerRealtimeAudioGraph? = try DirectPeerRealtimeAudioGraph(
        configuration: DirectPeerRealtimeAudioGraphConfiguration(
            devices: .init(audioDeviceUID: "synthetic", inputDeviceUID: nil, outputDeviceUID: nil),
            format: .init(sampleRateHertz: 48_000, framesPerBuffer: 1, channelCount: 1, sampleFormat: .float32LittleEndian),
            channelMaps: .init(input: [0], output: [0]),
            buffering: .init(ringCapacityBlocks: 1, rxBufferPolicy: nil)
        )
    )
    let lifecycleLock = try #require(graph?.lifecycleLockForTesting())
    graph?.setCleanupStateForTesting(
        inputDeviceID: 101,
        inputIOProcID: directPeerRealtimeAudioIOProc,
        outputDeviceID: nil,
        outputIOProcID: nil,
        originalInputSampleRate: nil,
        originalInputBufferFrameSize: nil,
        originalOutputSampleRate: nil,
        originalOutputBufferFrameSize: nil
    )
    graph?.setCleanupOperationOverridesForTesting()

    let weakBox = DirectPeerGraphWeakBox(graph)
    let releaseBox = DirectPeerGraphReleaseBox(try #require(graph))
    let releaseReturned = DispatchSemaphore(value: 0)
    graph = nil

    lifecycleLock.lock()
    DispatchQueue.global(qos: .userInitiated).async {
        releaseBox.release()
        releaseReturned.signal()
    }

    let releaseResult = releaseReturned.wait(timeout: .now() + .milliseconds(200))
    lifecycleLock.unlock()
    if releaseResult != .success {
        #expect(releaseReturned.wait(timeout: .now() + 2) == .success)
    }

    #expect(releaseResult == .success)
    #expect(weakBox.graph == nil)
}

private final class DirectPeerGraphReleaseBox: @unchecked Sendable {
    private var graph: DirectPeerRealtimeAudioGraph?

    init(_ graph: DirectPeerRealtimeAudioGraph) {
        self.graph = graph
    }

    func release() {
        graph = nil
    }
}

private final class DirectPeerGraphWeakBox {
    weak var graph: DirectPeerRealtimeAudioGraph?

    init(_ graph: DirectPeerRealtimeAudioGraph?) {
        self.graph = graph
    }
}

private final class DirectPeerGraphQuiescenceTestState: @unchecked Sendable {
    struct Snapshot {
        var callbackTimedOut: Bool
        var callbackStatus: OSStatus?
        var callbackError: String?
        var stopResult: DirectPeerRealtimeAudioGraphCleanupResult?
        var destroySawCallbackActive: Bool
    }

    private let lock = NSLock()
    private var active = false
    private var timedOut = false
    private var status: OSStatus?
    private var error: String?
    private var stopCleanupResult: DirectPeerRealtimeAudioGraphCleanupResult?
    private var destroyObservedActive = false

    var callbackActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return active
    }

    func setCallbackActive(_ active: Bool) {
        lock.lock()
        self.active = active
        lock.unlock()
    }

    func markCallbackTimedOut() {
        lock.lock()
        timedOut = true
        lock.unlock()
    }

    func setCallbackStatus(_ status: OSStatus) {
        lock.lock()
        self.status = status
        lock.unlock()
    }

    func setCallbackError(_ error: String) {
        lock.lock()
        self.error = error
        lock.unlock()
    }

    func setStopResult(_ result: DirectPeerRealtimeAudioGraphCleanupResult) {
        lock.lock()
        stopCleanupResult = result
        lock.unlock()
    }

    func markDestroySawCallbackActive(_ active: Bool) {
        lock.lock()
        destroyObservedActive = active
        lock.unlock()
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(
            callbackTimedOut: timedOut,
            callbackStatus: status,
            callbackError: error,
            stopResult: stopCleanupResult,
            destroySawCallbackActive: destroyObservedActive
        )
    }
}
