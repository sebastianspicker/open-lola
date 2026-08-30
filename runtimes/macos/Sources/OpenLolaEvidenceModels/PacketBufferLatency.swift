// Shares frame, packet, and time costs while phantom domains preserve metric identity.

/// Reports one buffering cost in frames, packets, and microseconds.
public struct PacketBufferLatency<Domain>: Codable, Equatable, Sendable {
    public var frames: Int
    public var packets: Int
    public var microseconds: Double

    public init(frames: Int, packets: Int, microseconds: Double) {
        self.frames = frames
        self.packets = packets
        self.microseconds = microseconds
    }
}
