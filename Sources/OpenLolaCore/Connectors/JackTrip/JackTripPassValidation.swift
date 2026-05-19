import Foundation

extension JackTripCompatibilityMediaReport {
    func validatePassEvidence() throws {
        guard realLinkTransmitted else {
            throw ExternalConnectorSessionError.dryRunCannotPass
        }
        guard runtimeError == nil else {
            throw ExternalConnectorSessionError.runtimePassWithRuntimeError("jackTripMedia.runtimeError")
        }
        guard missingEvidenceClassesForPass.isEmpty else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence(
                "jackTripMedia.missingEvidenceClassesForPass"
            )
        }
        let observed = Set(observedEvidenceClasses)
        let missingObserved = ExternalConnectorEvidenceClass.runtimePassRequiredEvidence.filter {
            !observed.contains($0)
        }
        guard missingObserved.isEmpty else {
            throw ExternalConnectorSessionError.runtimePassMissingEvidence(
                "jackTripMedia.observedEvidenceClasses"
            )
        }
    }
}
