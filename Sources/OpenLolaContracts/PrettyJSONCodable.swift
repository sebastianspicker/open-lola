import Foundation

public enum JSONReportCoder {
    public static func decode<Report: Decodable>(
        _ type: Report.Type,
        from data: Data
    ) throws -> Report {
        try JSONDecoder().decode(type, from: data)
    }

    public static func prettyJSONData<Report: Encodable>(
        for report: Report
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }

    public static func prettyJSONString<Report: Encodable>(
        for report: Report
    ) throws -> String {
        String(decoding: try prettyJSONData(for: report), as: UTF8.self)
    }
}

public protocol PrettyJSONCodable: Codable {
    static func decode(from data: Data) throws -> Self
    func prettyJSONData() throws -> Data
    func prettyJSONString() throws -> String
}

public extension PrettyJSONCodable {
    static func decode(from data: Data) throws -> Self {
        try JSONReportCoder.decode(Self.self, from: data)
    }

    func prettyJSONData() throws -> Data {
        try JSONReportCoder.prettyJSONData(for: self)
    }

    func prettyJSONString() throws -> String {
        try JSONReportCoder.prettyJSONString(for: self)
    }
}
