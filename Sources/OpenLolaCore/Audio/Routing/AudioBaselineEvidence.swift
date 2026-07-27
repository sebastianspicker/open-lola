// Normalizes Thunderbolt, driver-mode, and sample-rate-conversion observations used to judge whether an audio route matches the baseline.
import Foundation

/// Defines `absent`, `present`, and `unknown` states used to make sample rate conversion state decisions in CoreAudio loopback routing.
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
