// Implements VideoTransportReassemblyBucket media transport boundary, separating packet I/O from session policy.
import Foundation

struct VideoFrameReassemblyKey: Hashable, Sendable {
    var streamID: UInt32
    var frameSequenceNumber: UInt64
}

let videoFrameSequenceHalfWindowThreshold = UInt64.max / 2

func videoFrameSequenceIsLate(_ sequenceNumber: UInt64, after latestCompleted: UInt64) -> Bool {
    sequenceNumber == latestCompleted
        || (sequenceNumber &- latestCompleted) > videoFrameSequenceHalfWindowThreshold
}

func videoFrameSequenceIsNewer(_ sequenceNumber: UInt64, than latestCompleted: UInt64) -> Bool {
    let forwardDistance = sequenceNumber &- latestCompleted
    return forwardDistance > 0 && forwardDistance <= videoFrameSequenceHalfWindowThreshold
}

struct VideoFrameReassemblyBucket: Equatable, Sendable {
    var streamID: UInt32
    var frameSequenceNumber: UInt64
    var timestampNanoseconds: UInt64
    var timestampBasis: VideoTimestampBasis
    var sourceRole: VideoStreamRole
    var width: Int
    var height: Int
    var pixelFormat: String
    var frameRate: VideoFrameRate
    var framePayloadByteCount: Int
    var fragmentCount: Int
    var frameFingerprint: String
    var fragmentsByIndex: [Int: VideoTransportFragment]
    var firstFragmentReceivedAt: UInt64

    var missingFragmentCount: Int {
        max(0, fragmentCount - fragmentsByIndex.count)
    }

    init(firstFragment: VideoTransportFragment, firstFragmentReceivedAt: UInt64) {
        streamID = firstFragment.streamID
        frameSequenceNumber = firstFragment.frameSequenceNumber
        timestampNanoseconds = firstFragment.timestampNanoseconds
        timestampBasis = firstFragment.timestampBasis
        sourceRole = firstFragment.sourceRole
        width = firstFragment.width
        height = firstFragment.height
        pixelFormat = firstFragment.pixelFormat
        frameRate = firstFragment.frameRate
        framePayloadByteCount = firstFragment.framePayloadByteCount
        fragmentCount = firstFragment.fragmentCount
        frameFingerprint = firstFragment.frameFingerprint
        fragmentsByIndex = [firstFragment.fragmentIndex: firstFragment]
        self.firstFragmentReceivedAt = firstFragmentReceivedAt
    }

    mutating func insert(_ fragment: VideoTransportFragment) throws -> Bool {
        guard fragment.streamID == streamID,
              fragment.frameSequenceNumber == frameSequenceNumber,
              fragment.timestampNanoseconds == timestampNanoseconds,
              fragment.timestampBasis == timestampBasis,
              fragment.sourceRole == sourceRole,
              fragment.width == width,
              fragment.height == height,
              fragment.pixelFormat == pixelFormat,
              fragment.frameRate == frameRate,
              fragment.framePayloadByteCount == framePayloadByteCount,
              fragment.fragmentCount == fragmentCount,
              fragment.frameFingerprint == frameFingerprint else {
            throw VideoTransportFragmentError.inconsistentFrameMetadata
        }
        guard fragmentsByIndex[fragment.fragmentIndex] == nil else {
            return false
        }
        fragmentsByIndex[fragment.fragmentIndex] = fragment
        return true
    }

    func completedPacket() throws -> VideoTransportPacket? {
        guard fragmentsByIndex.count == fragmentCount else {
            return nil
        }

        var expectedPayloadOffset = 0
        for fragmentIndex in 0..<fragmentCount {
            guard let fragment = fragmentsByIndex[fragmentIndex] else {
                return nil
            }
            guard fragment.payloadOffset == expectedPayloadOffset else {
                throw VideoTransportFragmentError.fragmentOffsetMismatch(
                    expected: expectedPayloadOffset,
                    actual: fragment.payloadOffset
                )
            }
            expectedPayloadOffset += fragment.payloadByteCount
        }
        guard expectedPayloadOffset == framePayloadByteCount else {
            throw VideoTransportFragmentError.payloadLengthMismatch(
                expected: framePayloadByteCount,
                actual: expectedPayloadOffset
            )
        }

        var fields = VideoTransportPacketFields()
        fields.streamID = streamID
        fields.sequenceNumber = frameSequenceNumber
        fields.timestampNanoseconds = timestampNanoseconds
        fields.timestampBasis = timestampBasis
        fields.sourceRole = sourceRole
        fields.width = width
        fields.height = height
        fields.pixelFormat = pixelFormat
        fields.frameRate = frameRate
        fields.payloadByteCount = framePayloadByteCount
        fields.frameFingerprint = frameFingerprint
        return VideoTransportPacket(fields)
    }

    func completedRawFrame() throws -> RawCapturedVideoFrame? {
        guard let packet = try completedPacket() else {
            return nil
        }
        var payload = Data()
        payload.reserveCapacity(framePayloadByteCount)
        for fragmentIndex in 0..<fragmentCount {
            guard let fragment = fragmentsByIndex[fragmentIndex] else {
                return nil
            }
            payload.append(fragment.payload)
        }
        return RawCapturedVideoFrame(
            metadata: CapturedVideoFrame(
                streamID: packet.streamID,
                sequenceNumber: packet.sequenceNumber,
                timestampNanoseconds: packet.timestampNanoseconds,
                timestampBasis: packet.timestampBasis,
                sourceRole: packet.sourceRole,
                width: packet.width,
                height: packet.height,
                pixelFormat: packet.pixelFormat,
                frameRate: packet.frameRate,
                fingerprint: packet.frameFingerprint
            ),
            payload: payload
        )
    }
}
