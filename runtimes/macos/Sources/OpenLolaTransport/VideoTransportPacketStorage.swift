// Defines owned video packet header values and their phantom domains.
import OpenLolaSessionDomain

/// Stores packet header fields while phantom domains distinguish builders from validated packets.
public struct VideoTransportPacketStorage<Domain>: Codable, Equatable, Sendable {
    public var streamID: UInt32 = 0
    public var sequenceNumber: UInt64 = 0
    public var timestampNanoseconds: UInt64 = 0
    public var timestampBasis: VideoTimestampBasis = .syntheticMonotonicNanoseconds
    public var sourceRole: VideoStreamRole = .testPattern
    public var width = 0
    public var height = 0
    public var pixelFormat = ""
    public var frameRate = VideoFrameRate.disabled
    public var payloadByteCount = 0
    public var frameFingerprint = ""

    public init() {}

    public init<OtherDomain>(_ fields: VideoTransportPacketStorage<OtherDomain>) {
        self.streamID = fields.streamID
        self.sequenceNumber = fields.sequenceNumber
        self.timestampNanoseconds = fields.timestampNanoseconds
        self.timestampBasis = fields.timestampBasis
        self.sourceRole = fields.sourceRole
        self.width = fields.width
        self.height = fields.height
        self.pixelFormat = fields.pixelFormat
        self.frameRate = fields.frameRate
        self.payloadByteCount = fields.payloadByteCount
        self.frameFingerprint = fields.frameFingerprint
    }
}

/// Keeps mutable packet-field assembly distinct from packet values passed to transport policy.
public enum VideoTransportPacketFieldsDomain {}
/// Names mutable video transport packet fields used while constructing a packet.
public typealias VideoTransportPacketFields = VideoTransportPacketStorage<VideoTransportPacketFieldsDomain>

/// Keeps validated transport packets distinct from their mutable field builders.
public enum VideoTransportPacketDomain {}
/// Names a validated video transport packet passed to transport policy.
public typealias VideoTransportPacket = VideoTransportPacketStorage<VideoTransportPacketDomain>
