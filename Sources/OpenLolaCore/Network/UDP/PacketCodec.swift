import Foundation

public protocol PacketCodec: Equatable, Sendable {
    static func decode<Bytes: DataProtocol>(_ data: Bytes) throws -> Self
    func encoded() throws -> Data
}
