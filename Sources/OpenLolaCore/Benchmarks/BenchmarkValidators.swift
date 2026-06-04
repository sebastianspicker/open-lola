enum E2EBenchmarkValidator: ReportPrimitiveValidating {
    typealias ValidationError = E2EBenchmarkValidationError
}

enum LatencyBenchmarkValidator: ReportPrimitiveValidating {
    typealias ValidationError = LatencyBenchmarkValidationError
}

enum PerformanceAuditValidator: ReportPrimitiveValidating {
    typealias ValidationError = PerformanceAuditValidationError
}
