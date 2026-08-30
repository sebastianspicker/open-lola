import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Validates AudioRoutingValidators acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import OpenLolaEvidenceModels
enum AudioLoopbackRunValidator: ReportPrimitiveValidating {
    typealias ValidationError = AudioLoopbackRunValidationError
}
