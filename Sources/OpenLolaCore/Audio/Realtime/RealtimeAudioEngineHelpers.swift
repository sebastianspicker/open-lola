import Foundation

enum RealtimeAudioEngineValidator: ReportValidationProtocol {
    typealias ValidationError = RealtimeAudioEngineValidationError
}

func isRealtimeRmeMadi(_ value: String) -> Bool {
    let normalized = value.lowercased()
    return normalized.contains("rme") && normalized.contains("madi")
}

func isRealtimePlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: ["todo(human)", "placeholder"],
        exactly: ["unknown", "tbd"]
    )
}
