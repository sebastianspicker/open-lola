import Foundation

func isRealtimeRmeMadi(_ value: String) -> Bool {
    let normalized = value.lowercased()
    return normalized.contains("rme") && normalized.contains("madi")
}

func isRealtimePlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: [PlaceholderDetection.manualEvidenceToken, "placeholder"],
        exactly: ["unknown", "tbd"]
    )
}
