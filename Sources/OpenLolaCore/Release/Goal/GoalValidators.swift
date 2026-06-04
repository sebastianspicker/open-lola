enum GoalCodewiseClosureValidator: ReportPrimitiveValidating {
    typealias ValidationError = GoalCodewiseClosureValidationError
}

enum GoalCompletionAuditValidator: ReportPrimitiveValidating {
    typealias ValidationError = GoalCompletionAuditValidationError
}

enum GoalRuntimeEvidenceTemplateValidator: ReportPrimitiveValidating {
    typealias ValidationError = GoalRuntimeEvidenceTemplateValidationError
}

enum GoalRuntimePreflightValidator: ReportPrimitiveValidating {
    typealias ValidationError = GoalRuntimePreflightValidationError
}
