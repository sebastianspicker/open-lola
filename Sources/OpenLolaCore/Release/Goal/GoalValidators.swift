// Validates GoalValidators acceptance rules, keeping failure policy close to its contract rather than the runtime path.
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
