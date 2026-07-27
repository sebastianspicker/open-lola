// Shared peer session runner helpers keep related tests deterministic and focused on their contract.
import Foundation
import Testing

@testable import OpenLolaCore

actor AsyncReadinessGate {
    private var ready = false

    func signal() {
        ready = true
    }

    func wait(timeout: Duration) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if ready {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return ready
    }
}

func makePeerMetadataSnapshot(peerID: String, revision: Int) -> RmeMatrixMetadataSnapshot {
    RmeMatrixMetadataSnapshot(
        identity: .init(
            snapshotID: "\(peerID)-metadata-\(revision)",
            provider: .coreAudioOnly,
            revision: revision,
            capturedAt: "2026-05-12T00:00:00Z"
        ),
        provenance: .init(
            legalBasis: "test fixture",
            confidence: .highForChannelOrder,
            notes: "test metadata"
        ),
        matrix: .init(
            channels: [
                AudioChannelDescriptor(stableSourceIndex: 0, label: "\(peerID)-left"),
                AudioChannelDescriptor(stableSourceIndex: 1, label: "\(peerID)-right")
            ],
            routes: []
        )
    )
}

func expectAVRuntimeDeviceUIDs(
    in report: DirectPeerSessionReport,
    inputDeviceUID: String,
    outputDeviceUID: String
) throws {
    let runtime = try #require(report.avRuntime)
    #expect(runtime.audioDeviceUID == inputDeviceUID)
    #expect(runtime.inputDeviceUID == inputDeviceUID)
    #expect(runtime.outputDeviceUID == outputDeviceUID)
}

func expectSyntheticAVRouteCounters(in report: DirectPeerSessionReport) throws {
    let metrics = try #require(report.avRuntime?.runtimeMetrics)
    #expect(metrics.audioPayloadsCaptured > 0)
    #expect(metrics.audioPayloadsSent > 0)
    #expect(metrics.audioPayloadsQueuedForPlayout > 0)
    #expect(metrics.videoFramesCaptured > 0)
    #expect(metrics.videoFramesSent > 0)
    #expect(metrics.videoFragmentsReceived > 0)
    #expect(metrics.videoFramesReassembled > 0)
}

func receivePeerMetricsEventually(
    from runner: inout PeerSessionRunner,
    timeoutNanoseconds: UInt64 = 50_000_000
) throws -> SessionMetricsMessage? {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    repeat {
        if let metrics = try runner.receivePeerMetricsIfAvailable() {
            return metrics
        }
        Thread.sleep(forTimeInterval: 0.001)
    } while DispatchTime.now().uptimeNanoseconds < deadline
    return nil
}
