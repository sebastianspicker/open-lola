enum DriftPlcFixedTargetCertificationValidator: ReportPrimitiveValidating {
    typealias ValidationError = DriftPlcFixedTargetCertificationValidationError
}

enum DriftPlcValidator: ReportPrimitiveValidating {
    typealias ValidationError = DriftPlcValidationError
}

enum LatencyTuningValidator: ReportPrimitiveValidating {
    typealias ValidationError = LatencyTuningValidationError
}

enum RxBufferBenchmarkValidator: ReportPrimitiveValidating {
    typealias ValidationError = RxBufferBenchmarkValidationError
}

enum RxBufferPolicyValidator: ReportPrimitiveValidating {
    typealias ValidationError = RxBufferPolicyValidationError
}

enum SessionProfileBenchmarkValidator: ReportPrimitiveValidating {
    typealias ValidationError = LatencyBenchmarkValidationError
}
