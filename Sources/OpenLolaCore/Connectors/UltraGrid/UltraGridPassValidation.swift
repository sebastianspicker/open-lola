// Validates UltraGridPassValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension UltraGridCompatibilityMediaReport {
    func validatePassEvidence() throws {
        guard realLinkTransmitted else {
            throw ExternalConnectorSessionError.dryRunCannotPass
        }
        guard runtimeError == nil else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("ultraGridMedia.runtimeError")
        }
        guard runtimeErrorFree == true else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("ultraGridMedia.runtimeErrorFree")
        }
        guard sink.rejectedMediaCount == 0 else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence(
                "ultraGridMedia.sink.rejectedMediaCount"
            )
        }
        guard videoFrameReassemblyFailureCount == 0 else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence(
                "ultraGridMedia.videoFrameReassemblyFailureCount"
            )
        }
        guard missingEvidenceClassesForPass.isEmpty else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence(
                "ultraGridMedia.missingEvidenceClassesForPass"
            )
        }
        let observed = Set(observedEvidenceClasses)
        let missingObserved = ExternalConnectorEvidenceClass.runtimePassRequiredEvidence.filter {
            !observed.contains($0)
        }
        guard missingObserved.isEmpty else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence(
                "ultraGridMedia.observedEvidenceClasses"
            )
        }
    }
}
