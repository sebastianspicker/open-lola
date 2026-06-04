enum MadiFullDuplexValidator: ReportPrimitiveValidating {
    typealias ValidationError = MadiFullDuplexError
}

enum MadiReceiveValidator: ReportPrimitiveValidating {
    typealias ValidationError = MadiReceiveError
}

enum MadiTransmitValidator: ReportPrimitiveValidating {
    typealias ValidationError = MadiTransmitValidationError
}
