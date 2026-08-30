import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
import OpenLolaEvidenceModels

// The evidence-owned error remains usable by Core's generic validation surface.
extension RxBufferPolicyValidationError: ValidationEmptyFieldError, ValidationNonPositiveFieldError,
    ValidationNegativeFieldError, ValidationNonFiniteFieldError {}
