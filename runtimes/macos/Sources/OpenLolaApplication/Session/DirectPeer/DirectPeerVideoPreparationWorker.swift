import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Packetizes only the newest captured video frame on a worker queue and counts superseded work so preparation cannot backlog the media loop.
import Foundation

struct DirectPeerVideoPreparationRequest: Sendable {
    var frame: RawCapturedVideoFrame
    var compression: DirectPeerSessionVideoCompression
    var maxPacketBytes: Int
    var payloadType: SessionPayloadType
}

struct DirectPeerPreparedVideoTransmit: Sendable {
    var preparedFrame: UdpMediaPreparedVideoFrame
    var frameSequenceNumber: UInt64
    var timestampNanoseconds: UInt64
}

final class DirectPeerVideoPreparationWorker: @unchecked Sendable {
    typealias Prepare = @Sendable (DirectPeerVideoPreparationRequest) throws -> UdpMediaPreparedVideoFrame
    private let worker: DirectPeerLatestVideoWorker<DirectPeerVideoPreparationRequest, UdpMediaPreparedVideoFrame>

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
        guard let transmit = try takeCompletedTransmit() else {
            return nil
        }
        var cursor = transmit.preparedFrame.makeCursor()
        var packets: [UdpMediaPacket] = []
        packets.reserveCapacity(cursor.fragmentCount)
        var datagram = Data()
        while cursor.encodeNext(into: &datagram) {
            packets.append(try UdpMediaPacket.decode(datagram))
        }
        return packets
    }

    func takeCompletedTransmit() throws -> DirectPeerPreparedVideoTransmit? {
        let completion = worker.takeCompletion()
        guard let completion else {
            return nil
        }
        return DirectPeerPreparedVideoTransmit(
            preparedFrame: try completion.result.get(),
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

    private static func prepare(_ request: DirectPeerVideoPreparationRequest) throws -> UdpMediaPreparedVideoFrame {
        let frame = try videoTransportFrame(request.frame, compression: request.compression)
        return try RawVideoFrameTransport.prepareMediaDatagrams(
            for: frame,
            maxPacketBytes: request.maxPacketBytes,
            payloadType: request.payloadType
        )
    }
}
