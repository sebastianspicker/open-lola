// Validates AudioRoutingValidators acceptance rules, keeping failure policy close to its contract rather than the runtime path.
enum AudioLoopbackRunValidator: ReportPrimitiveValidating {
    typealias ValidationError = AudioLoopbackRunValidationError
}
