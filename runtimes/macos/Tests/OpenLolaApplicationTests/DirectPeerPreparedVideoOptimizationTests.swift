// Verifies latest-only prepared-video ownership and drop accounting without camera hardware.
import Dispatch
import Foundation
import OpenLolaSessionDomain
import OpenLolaTransport
@testable import OpenLolaApplication
import Testing

@Test func preparedVideoWorkerCancellationCountsPendingAndInFlightFrames() throws {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let worker = DirectPeerVideoPreparationWorker { request in
        entered.signal()
        release.wait()
        return try RawVideoFrameTransport.prepareMediaDatagrams(
            for: request.frame,
            maxPacketBytes: request.maxPacketBytes,
            payloadType: request.payloadType
        )
    }
    worker.submitLatest(preparedVideoRequest(sequence: 1))
    #expect(entered.wait(timeout: .now() + 2) == .success)
    worker.submitLatest(preparedVideoRequest(sequence: 2))

    #expect(worker.cancelAndTakeDroppedFrameCount() == 2)
    release.signal()
    #expect(try worker.takeCompletedPackets() == nil)
}

@Test func preparedVideoSupersessionPreservesFrameIdentityAndCountsOneDrop() throws {
    let first = try preparedTransmit(sequence: 10)
    let second = try preparedTransmit(sequence: 11)
    var pending: DirectPeerPendingVideoTransmit?

    #expect(supersedePendingVideoTransmit(with: first, pending: &pending) == 0)
    #expect(pending?.frameSequenceNumber == 10)
    #expect(supersedePendingVideoTransmit(with: second, pending: &pending) == 1)
    #expect(pending?.frameSequenceNumber == 11)
    #expect(pending?.timestampNanoseconds == 1_011)
    #expect(pending?.remainingPacketCount == second.preparedFrame.fragmentCount)
}

private func preparedTransmit(sequence: UInt64) throws -> DirectPeerPreparedVideoTransmit {
    let request = preparedVideoRequest(sequence: sequence)
    return DirectPeerPreparedVideoTransmit(
        preparedFrame: try RawVideoFrameTransport.prepareMediaDatagrams(
            for: request.frame,
            maxPacketBytes: request.maxPacketBytes,
            payloadType: request.payloadType
        ),
        frameSequenceNumber: sequence,
        timestampNanoseconds: request.frame.metadata.timestampNanoseconds
    )
}

private func preparedVideoRequest(sequence: UInt64) -> DirectPeerVideoPreparationRequest {
    let metadata = CapturedVideoFrame(
        streamID: 100,
        sequenceNumber: sequence,
        timestampNanoseconds: 1_000 + sequence,
        timestampBasis: .syntheticMonotonicNanoseconds,
        sourceRole: .testPattern,
        width: 64,
        height: 64,
        pixelFormat: "BGRA",
        frameRate: .init(numerator: 30, denominator: 1),
        fingerprint: "worker-\(sequence)"
    )
    return DirectPeerVideoPreparationRequest(
        frame: RawCapturedVideoFrame(metadata: metadata, payload: Data(repeating: 0x33, count: 16_384)),
        compression: .raw,
        maxPacketBytes: 512,
        payloadType: .videoRawFrameFragment
    )
}
