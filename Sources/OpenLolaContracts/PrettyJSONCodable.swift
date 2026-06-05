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
        let data = try prettyJSONData()
        guard let string = String(data: data, encoding: .utf8) else {
            throw PrettyJSONCodableError.invalidUTF8Output
        }
        return string
    }
}

private enum PrettyJSONCodableError: Error {
    case invalidUTF8Output
}
