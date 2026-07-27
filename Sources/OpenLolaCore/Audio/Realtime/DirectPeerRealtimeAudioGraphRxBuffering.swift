// Updates adaptive RX targets under a dedicated lock and publishes snapshots without making the render callback run controller logic.
import Foundation

extension DirectPeerRealtimeAudioGraph {
    public func rxBufferRuntimeSnapshot() -> RxBufferRuntimeSnapshot? {
        rxBufferAdaptationLock.lock()
        defer { rxBufferAdaptationLock.unlock() }
        return rxBufferSnapshot
    }

    func currentPlayoutTargetFrames() -> Int {
        // Called from queuePlayoutPayload on the network receive path, not from renderPlayout.
        rxBufferAdaptationLock.lock()
        defer { rxBufferAdaptationLock.unlock() }
        return rxBufferSnapshot?.currentTargetFrames ?? configuration.playoutTargetFrames
    }

    func observeAdaptiveRxBuffer(
        startFrame: UInt64,
        hostTimeNanoseconds: UInt64,
        pressure: Bool
    ) {
        rxBufferAdaptationLock.lock()
        defer { rxBufferAdaptationLock.unlock() }
        guard var controller = adaptiveRxBufferController else {
            return
        }
        let previousEventCount = controller.targetChangeEvents.count
        let now = DispatchTime.now().uptimeNanoseconds
        let ageMicroseconds = hostTimeNanoseconds <= now
            ? Double(now - hostTimeNanoseconds) / 1_000
            : 0
        let sequenceNumber = startFrame / UInt64(max(1, configuration.framesPerBuffer))
        let decision = controller.observe(
            RxBufferAdaptationSample(
                sequenceNumber: sequenceNumber,
                jitterP99Microseconds: ageMicroseconds,
                latePackets: pressure ? 1 : 0
            )
        )
        adaptiveRxBufferController = controller
        guard decision.changed else {
            return
        }
        rxBufferSnapshot?.recordTargetFrames(decision.targetFrames)
        for event in controller.targetChangeEvents.dropFirst(previousEventCount) {
            rxBufferSnapshot?.targetChangeEvents.append(event)
        }
    }
}
