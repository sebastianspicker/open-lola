import Foundation

func requireRealtimeNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, error: RealtimeAudioEngineValidationError.self)
}

func requireRealtimePositive(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, error: RealtimeAudioEngineValidationError.self)
}

func requireRealtimeNonNegative(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, error: RealtimeAudioEngineValidationError.self)
}

func requireRealtimeNonNegative(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, error: RealtimeAudioEngineValidationError.self)
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
