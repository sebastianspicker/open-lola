import Foundation

public protocol PrettyJSONCodable: Codable {
    static func decode(from data: Data) throws -> Self
    func prettyJSONData() throws -> Data
    func prettyJSONString() throws -> String
}

public extension PrettyJSONCodable {
    static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }

    func prettyJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    func prettyJSONString() throws -> String {
        String(decoding: try prettyJSONData(), as: UTF8.self)
    }
}
