// Implements PacketCodec encoding and decoding, keeping wire representation apart from transport lifetime.
import Foundation

/// Defines the PacketCodec boundary that implementations of UDP media transport must satisfy.
public protocol PacketCodec: Equatable, Sendable {
    static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> Self
    func encoded() throws -> Data
}
