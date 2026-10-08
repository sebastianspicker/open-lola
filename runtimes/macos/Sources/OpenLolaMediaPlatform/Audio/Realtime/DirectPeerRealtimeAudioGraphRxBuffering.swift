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

    /// RFC 3550 interarrival jitter. The sender host time and the local arrival time come from
    /// different clocks, so only the change in transit between packets is meaningful; the constant
    /// clock offset cancels out. Caller holds `rxBufferAdaptationLock`.
    private func updateInterarrivalJitterLocked(
        senderHostTimeNanoseconds: UInt64,
        arrivalNanoseconds: UInt64
    ) -> Double {
        let transit = Int64(truncatingIfNeeded: arrivalNanoseconds)
            &- Int64(truncatingIfNeeded: senderHostTimeNanoseconds)
        defer { rxInterarrivalPreviousTransitNanoseconds = transit }
        guard let previousTransit = rxInterarrivalPreviousTransitNanoseconds else {
            rxInterarrivalJitterMicroseconds = 0
            return 0
        }
        let differenceMicroseconds = Double(transit &- previousTransit).magnitude / 1_000
        rxInterarrivalJitterMicroseconds += (differenceMicroseconds - rxInterarrivalJitterMicroseconds) / 16
        return rxInterarrivalJitterMicroseconds
    }
}
