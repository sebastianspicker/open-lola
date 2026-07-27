// Decodes only the latest reassembled video frame on a worker queue and reports dropped stale requests to bound receive-side latency.
import Foundation

struct DirectPeerPreparedVideoFrame: Sendable {
    var frame: RawCapturedVideoFrame
    var proof: DirectPeerSessionVideoFrameProof
}

struct DirectPeerVideoDecodeRequest: Sendable {
    var frame: RawCapturedVideoFrame
    var compression: DirectPeerSessionVideoCompression
}

final class DirectPeerVideoDecodeWorker: @unchecked Sendable {
    typealias Decode = @Sendable (DirectPeerVideoDecodeRequest) throws -> DirectPeerPreparedVideoFrame

    private let worker: DirectPeerLatestVideoWorker<DirectPeerVideoDecodeRequest, DirectPeerPreparedVideoFrame>

    init(decode: @escaping Decode = DirectPeerVideoDecodeWorker.decode) {
        worker = DirectPeerLatestVideoWorker(
            queueLabel: "open-lola.direct-peer.video-decode",
            operation: decode
        )
    }

    var readinessDescriptor: Int32? { worker.readinessDescriptor }

    func submitLatest(_ request: DirectPeerVideoDecodeRequest) {
        worker.submitLatest(request)
    }

    func takeCompletion() -> Result<DirectPeerPreparedVideoFrame, Error>? {
        worker.takeCompletion()?.result
    }

    func takeDroppedFrameCount() -> Int {
        worker.takeDroppedFrameCount()
    }

    func cancel() {
        worker.cancel()
    }

    func cancelAndTakeDroppedFrameCount() -> Int {
        worker.cancelAndTakeDroppedFrameCount()
    }

    private static func decode(_ request: DirectPeerVideoDecodeRequest) throws -> DirectPeerPreparedVideoFrame {
        let frame = try decodedVideoTransportFrame(request.frame, compression: request.compression)
        return DirectPeerPreparedVideoFrame(
            frame: frame,
            proof: directPeerSessionVideoFrameProof(for: frame)
        )
    }
}
