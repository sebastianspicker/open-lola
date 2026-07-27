// Validates RealtimeAudioValidators acceptance rules, keeping failure policy close to its contract rather than the runtime path.
enum RealtimeAudioEngineValidator: ReportPrimitiveValidating {
    typealias ValidationError = RealtimeAudioEngineValidationError
}
