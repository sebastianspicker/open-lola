// Validates BenchmarkValidators acceptance rules, keeping failure policy close to its contract rather than the runtime path.
enum E2EBenchmarkValidator: ReportPrimitiveValidating {
    typealias ValidationError = E2EBenchmarkValidationError
}

enum LatencyBenchmarkValidator: ReportPrimitiveValidating {
    typealias ValidationError = LatencyBenchmarkValidationError
}

enum PerformanceAuditValidator: ReportPrimitiveValidating {
    typealias ValidationError = PerformanceAuditValidationError
}
