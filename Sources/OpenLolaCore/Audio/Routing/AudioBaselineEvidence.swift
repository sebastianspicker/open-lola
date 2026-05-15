import Foundation

public enum SampleRateConversionState: String, Codable, Equatable, Sendable {
    case absent
    case present
    case unknown
}

func isThunderboltPerformancePath(_ fields: [String]) -> Bool {
    let normalized = fields.joined(separator: " ").lowercased()
    return normalized.contains("thunderbolt")
        || normalized.contains("tb3")
        || normalized.contains("tb4")
}

func isClassCompliantDriverMode(_ value: String) -> Bool {
    let normalized = value.lowercased()
    return normalized.contains("class") && normalized.contains("compliant")
}
