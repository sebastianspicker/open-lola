// Packetizes only the newest captured video frame on a worker queue and counts superseded work so preparation cannot backlog the media loop.
import Foundation

struct DirectPeerVideoPreparationRequest: Sendable {
    var frame: RawCapturedVideoFrame
    var compression: DirectPeerSessionVideoCompression
    var maxPacketBytes: Int
    var payloadType: SessionPayloadType
}

struct DirectPeerPreparedVideoTransmit: Sendable {
    var packets: [UdpMediaPacket]
    var frameSequenceNumber: UInt64
    var timestampNanoseconds: UInt64
}

final class DirectPeerVideoPreparationWorker: @unchecked Sendable {
    typealias Prepare = @Sendable (DirectPeerVideoPreparationRequest) throws -> [UdpMediaPacket]
    private let worker: DirectPeerLatestVideoWorker<DirectPeerVideoPreparationRequest, [UdpMediaPacket]>

    init(prepare: @escaping Prepare = DirectPeerVideoPreparationWorker.prepare) {
        worker = DirectPeerLatestVideoWorker(
            queueLabel: "open-lola.direct-peer.video-prepare",
            operation: prepare
        )
    }

    var readinessDescriptor: Int32? { worker.readinessDescriptor }

    func submitLatest(_ request: DirectPeerVideoPreparationRequest) {
        worker.submitLatest(request)
    }

    func takeCompletedPackets() throws -> [UdpMediaPacket]? {
        try takeCompletedTransmit()?.packets
    }

    func takeCompletedTransmit() throws -> DirectPeerPreparedVideoTransmit? {
        let completion = worker.takeCompletion()
        guard let completion else {
            return nil
        }
        return DirectPeerPreparedVideoTransmit(
            packets: try completion.result.get(),
            frameSequenceNumber: completion.request.frame.metadata.sequenceNumber,
            timestampNanoseconds: completion.request.frame.metadata.timestampNanoseconds
        )
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

    private static func prepare(_ request: DirectPeerVideoPreparationRequest) throws -> [UdpMediaPacket] {
        let frame = try videoTransportFrame(request.frame, compression: request.compression)
        return try VideoMediaPacketizer.packets(
            for: frame,
            maxPacketBytes: request.maxPacketBytes,
            payloadType: request.payloadType
        )
    }
}
