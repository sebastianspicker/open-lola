// Validates MadiValidators acceptance rules, keeping failure policy close to its contract rather than the runtime path.
enum MadiFullDuplexValidator: ReportPrimitiveValidating {
    typealias ValidationError = MadiFullDuplexError
}

enum MadiReceiveValidator: ReportPrimitiveValidating {
    typealias ValidationError = MadiReceiveError
}

enum MadiTransmitValidator: ReportPrimitiveValidating {
    typealias ValidationError = MadiTransmitValidationError
}
