enum FasterThanLoLaClosureValidator: ReportPrimitiveValidating {
    typealias ValidationError = FasterThanLoLaClosureValidationError
}

enum FieldReadyRuntimeValidator: ReportPrimitiveValidating {
    typealias ValidationError = FieldReadyRuntimeValidationError
}

enum LoLaParityDeferredValidator: ReportPrimitiveValidating {
    typealias ValidationError = LoLaParityDeferredValidationError
}

enum LolaBaselineComparisonValidator: ReportPrimitiveValidating {
    typealias ValidationError = LolaBaselineComparisonValidationError
}

enum OpenSourceReleaseReadinessValidator: ReportPrimitiveValidating {
    typealias ValidationError = OpenSourceReleaseReadinessValidationError
}

enum PackagingFieldValidator: ReportPrimitiveValidating {
    typealias ValidationError = PackagingFieldTestValidationError
}

enum RecordingSessionArtifactValidator: ReportPrimitiveValidating {
    typealias ValidationError = RecordingSessionArtifactValidationError
}

enum ReleaseHardeningValidator: ReportPrimitiveValidating {
    typealias ValidationError = ReleaseHardeningValidationError
}
