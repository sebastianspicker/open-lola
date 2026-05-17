import Testing

@testable import OpenLolaCore

@Test
func reportPrimitiveValidatorRoutesSharedProtocolErrors() throws {
    #expect(throws: RxBufferBenchmarkValidationError.emptyField("field")) {
        try RxBufferBenchmarkValidator.requireNonEmpty("", "field")
    }
    #expect(throws: RxBufferBenchmarkValidationError.nonPositiveField("field")) {
        try RxBufferBenchmarkValidator.requirePositive(0, "field")
    }
    #expect(throws: RxBufferBenchmarkValidationError.negativeField("field")) {
        try RxBufferBenchmarkValidator.requireNonNegative(-1, "field")
    }
    #expect(throws: RxBufferBenchmarkValidationError.nonFiniteField("field")) {
        try RxBufferBenchmarkValidator.requireNonNegative(Double.nan, "field")
    }
    #expect(throws: RecordingSessionArtifactValidationError.nonFiniteField("field")) {
        try RecordingSessionArtifactValidator.requirePositive(Double.nan, "field")
    }
    #expect(throws: PerformanceAuditValidationError.emptyList("field")) {
        try PerformanceAuditValidator.requireNonEmpty([Int](), "field")
    }
    #expect(throws: PerformanceAuditValidationError.passWithCounterWarning("field")) {
        try PerformanceAuditValidator.validateThreshold(
            value: 1,
            max: 0,
            error: PerformanceAuditValidationError.passWithCounterWarning("field")
        )
    }
    var passValidated = false
    PerformanceAuditValidator.validateVerdictPass(.pass) {
        passValidated = true
    }
    #expect(passValidated)
    var partialValidated = false
    PerformanceAuditValidator.validateVerdictPass(.partial) {
        partialValidated = true
    }
    #expect(!partialValidated)
}

@Test
func validationPrimitiveProtocolsRouteSharedBehavior() throws {
    #expect(throws: TestValidationError.emptyField("field")) {
        try TestValidator.requireNonEmpty("", "field")
    }
    #expect(throws: TestValidationError.emptyList("field")) {
        try TestValidator.requireNonEmpty([Int](), "field")
    }
    #expect(throws: TestValidationError.emptyField("field")) {
        try TestValidator.requireNonEmptyStrings(["ok", ""], "field")
    }
    #expect(throws: TestValidationError.nonPositiveField("field")) {
        try TestValidator.requirePositive(0, "field")
    }
    #expect(throws: TestValidationError.nonPositiveField("field")) {
        try TestValidator.requirePositive(-0.1, "field")
    }
    #expect(throws: TestValidationError.negativeField("field")) {
        try TestValidator.requireNonNegative(-1, "field")
    }
    #expect(throws: TestValidationError.nonFiniteField("field")) {
        try TestValidator.requireFinite(Double.infinity, "field")
    }
    #expect(throws: TestValidationError.notRunDisallowed) {
        try TestValidator.validateVerdictNotRun(
            TestRunVerdict.notRun,
            TestValidationError.notRunDisallowed
        )
    }
    #expect(throws: TestValidationError.thresholdExceeded) {
        try TestValidator.validateThreshold(
            value: 2,
            max: 1,
            error: TestValidationError.thresholdExceeded
        )
    }

    try TestValidator.requireNonEmptyStrings(["a", "b"], "field")
    try TestValidator.requirePositive(1, "field")
    try TestValidator.requirePositive(0.1, "field")
    try TestValidator.requireNonNegative(0, "field")
    try TestValidator.requireFinite(1, "field")
    try TestValidator.validateVerdictNotRun(
        TestRunVerdict.pass,
        TestValidationError.notRunDisallowed
    )
}

@Test
func timingValidationPercentileOrderingHelperRejectsEveryInversion() {
    #expect(timingPercentilesAreOrdered(p50: 1, p95: 2, p99: 3, max: 4))
    #expect(timingPercentilesAreOrdered(p50: 1, p95: 1, p99: 1, max: 1))
    #expect(!timingPercentilesAreOrdered(p50: 2, p95: 1, p99: 3, max: 4))
    #expect(!timingPercentilesAreOrdered(p50: 1, p95: 3, p99: 2, max: 4))
    #expect(!timingPercentilesAreOrdered(p50: 1, p95: 2, p99: 4, max: 3))
}

private enum TestValidationError: Error, Equatable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError {
    case emptyField(String)
    case emptyList(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case notRunDisallowed
    case thresholdExceeded
}

private enum TestValidator: ReportValidationProtocol {
    typealias ValidationError = TestValidationError
}

private enum TestRunVerdict: String {
    case pass
    case notRun
}
