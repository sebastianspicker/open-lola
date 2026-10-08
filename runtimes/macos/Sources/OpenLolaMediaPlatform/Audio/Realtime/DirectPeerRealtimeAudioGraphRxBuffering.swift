// Updates adaptive RX targets under a dedicated lock and publishes snapshots without making the render callback run controller logic.
import Foundation

extension DirectPeerRealtimeAudioGraph {
    public func rxBufferRuntimeSnapshot() -> RxBufferRuntimeSnapshot? {
        rxBufferAdaptationLock.lock()
        defer { rxBufferAdaptationLock.unlock() }
        return rxBufferSnapshot
    }

    /// Current playout target that `queuePlayoutPayload` adds to every start frame.
    public func playoutTargetFramesSnapshot() -> Int {
        currentPlayoutTargetFrames()
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
        let jitterMicroseconds = updateInterarrivalJitterLocked(
            senderHostTimeNanoseconds: hostTimeNanoseconds,
            arrivalNanoseconds: DispatchTime.now().uptimeNanoseconds
        )
        let sequenceNumber = startFrame / UInt64(max(1, configuration.framesPerBuffer))
        let decision = controller.observe(
            RxBufferAdaptationSample(
                sequenceNumber: sequenceNumber,
                jitterP99Microseconds: jitterMicroseconds,
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

    /// Sender and receiver clocks may have different origins. Transit changes
    /// cancel that offset; the bounded p99 preserves burst jitter that an RFC
    /// 3550 smoothed mean would hide from the adaptive controller's p99 input.
    private func updateInterarrivalJitterLocked(
        senderHostTimeNanoseconds: UInt64,
        arrivalNanoseconds: UInt64
    ) -> Double {
        rxInterarrivalJitter.observe(
            senderHostTimeNanoseconds: senderHostTimeNanoseconds,
            arrivalNanoseconds: arrivalNanoseconds
        )
    }
}
