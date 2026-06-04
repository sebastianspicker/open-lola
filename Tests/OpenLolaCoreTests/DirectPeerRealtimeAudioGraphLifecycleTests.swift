import CoreAudio
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerRealtimeAudioGraphStopWaitsForActiveCallbackBeforeDestroyingIOProc() throws {
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
    let state = DirectPeerGraphQuiescenceTestState()
    let callbackEntered = DispatchSemaphore(value: 0)
    let releaseCallback = DispatchSemaphore(value: 0)
    let callbackFinished = DispatchSemaphore(value: 0)
    let stopReturned = DispatchSemaphore(value: 0)

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
    graph.setCleanupOperationOverridesForTesting(
        stop: { _, _ in noErr },
        destroy: { _, _ in
            state.markDestroySawCallbackActive(state.callbackActive)
            return noErr
        }
    )

    DispatchQueue.global(qos: .userInitiated).async {
        defer { callbackFinished.signal() }
        var timestamp = AudioTimeStamp()
        timestamp.mHostTime = 42
        var inputSamples = [Float(1)]
        var outputSamples = [Float(-1)]
        do {
            try withMutableAudioBufferList(samples: &inputSamples, channelCount: 1) { inputList in
                try withMutableAudioBufferList(samples: &outputSamples, channelCount: 1) { outputList in
                    let status = directPeerRealtimeAudioIOProc(
                        0,
                        &timestamp,
                        inputList,
                        &timestamp,
                        outputList,
                        &timestamp,
                        Unmanaged.passUnretained(graph).toOpaque()
                    )
                    state.setCallbackStatus(status)
                }
            }
        } catch {
            state.setCallbackError(String(describing: error))
        }
        state.setCallbackActive(false)
    }

    #expect(callbackEntered.wait(timeout: .now() + 2) == .success)

    DispatchQueue.global(qos: .userInitiated).async {
        state.setStopResult(graph.stop())
        stopReturned.signal()
    }

    let earlyStopReturn = stopReturned.wait(timeout: .now() + .milliseconds(50))
    #expect(earlyStopReturn == .timedOut)

    releaseCallback.signal()
    if earlyStopReturn == .timedOut {
        #expect(stopReturned.wait(timeout: .now() + 2) == .success)
    }
    #expect(callbackFinished.wait(timeout: .now() + 2) == .success)

    let snapshot = state.snapshot()
    #expect(snapshot.callbackTimedOut == false)
    #expect(snapshot.callbackStatus == noErr)
    #expect(snapshot.callbackError == nil)
    #expect(snapshot.stopResult?.succeeded == true)
    #expect(snapshot.destroySawCallbackActive == false)
}

@Test
func directPeerRealtimeAudioGraphDeinitDoesNotAcquireLifecycleLock() throws {
    var graph: DirectPeerRealtimeAudioGraph? = try DirectPeerRealtimeAudioGraph(configuration: DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "synthetic",
        sampleRateHertz: 48_000,
        framesPerBuffer: 1,
        channelCount: 1,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0],
        outputChannelMap: [0],
        ringCapacityBlocks: 1
    ))
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

    func snapshot() -> (
        callbackTimedOut: Bool,
        callbackStatus: OSStatus?,
        callbackError: String?,
        stopResult: DirectPeerRealtimeAudioGraphCleanupResult?,
        destroySawCallbackActive: Bool
    ) {
        lock.lock()
        defer { lock.unlock() }
        return (
            callbackTimedOut: timedOut,
            callbackStatus: status,
            callbackError: error,
            stopResult: stopCleanupResult,
            destroySawCallbackActive: destroyObservedActive
        )
    }
}
