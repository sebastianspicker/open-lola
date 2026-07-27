// Shares the sender timeline carried by UDP audio packet headers.

/// Identifies one audio packet on its stream and sender clock timeline.
public struct UdpAudioPacketTiming: Equatable, Sendable {
    public var sequenceNumber: UInt64
    public var senderFrameIndex: UInt64
    public var senderHostTimeNanoseconds: UInt64

    public init(
        sequenceNumber: UInt64,
        senderFrameIndex: UInt64,
        senderHostTimeNanoseconds: UInt64
    ) {
        self.sequenceNumber = sequenceNumber
        self.senderFrameIndex = senderFrameIndex
        self.senderHostTimeNanoseconds = senderHostTimeNanoseconds
    }
}
