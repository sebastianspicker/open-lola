// Validates EvidenceValidators acceptance rules, keeping failure policy close to its contract rather than the runtime path.
enum HardwareValidationValidator: ReportPrimitiveValidating {
    typealias ValidationError = HardwareValidationValidationError
}
