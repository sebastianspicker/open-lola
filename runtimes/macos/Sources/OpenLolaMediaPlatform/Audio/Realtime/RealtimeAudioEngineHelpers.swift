// Validates real-time audio settings and records callback timing evidence for engine reports.
import Foundation

public func isRealtimeRmeMadi(_ value: String) -> Bool {
    let normalized = value.lowercased()
    return normalized.contains("rme") && normalized.contains("madi")
}

public func isRealtimePlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: [PlaceholderDetection.manualEvidenceToken, "placeholder"],
        exactly: ["unknown", "tbd"]
    )
}
