import OpenLolaContracts

extension RxBufferPolicyValidationError: ValidationEmptyFieldError, ValidationNonPositiveFieldError,
    ValidationNegativeFieldError, ValidationNonFiniteFieldError {}

enum RxBufferPolicyValidator: ReportPrimitiveValidating {
    typealias ValidationError = RxBufferPolicyValidationError
}
