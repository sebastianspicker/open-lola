import Foundation

public enum ExternalConnectorRuntimeEvidenceState: String, Equatable, Sendable {
    case passEvidenceValidated = "pass-evidence-validated"
    case noRuntimeErrorRecordedEvidenceIncomplete = "no-runtime-error-recorded-evidence-incomplete"
    case runtimeErrorStateUnknownEvidenceIncomplete = "runtime-error-state-unknown-evidence-incomplete"
    case runtimeErrorRecorded = "runtime-error-recorded"
}

func externalConnectorRuntimeEvidenceState(
    verdict: MeasurementVerdict,
    runtimeError: String?,
    runtimeErrorFree: Bool?
) -> ExternalConnectorRuntimeEvidenceState {
    if runtimeError != nil || runtimeErrorFree == false {
        return .runtimeErrorRecorded
    }
    guard runtimeErrorFree == true else {
        return .runtimeErrorStateUnknownEvidenceIncomplete
    }
    return verdict == .pass
        ? .passEvidenceValidated
        : .noRuntimeErrorRecordedEvidenceIncomplete
}

func externalConnectorRuntimeEvidenceStatusMessage(
    verdict: MeasurementVerdict,
    state: ExternalConnectorRuntimeEvidenceState
) -> String {
    switch state {
    case .passEvidenceValidated:
        return "PASS evidence validated"
    case .noRuntimeErrorRecordedEvidenceIncomplete:
        return "no runtime error recorded; verdict \(verdict.rawValue) still requires measured evidence"
    case .runtimeErrorStateUnknownEvidenceIncomplete:
        return "runtime error state unknown; verdict \(verdict.rawValue) still requires measured evidence"
    case .runtimeErrorRecorded:
        return "runtime error recorded; verdict \(verdict.rawValue)"
    }
}

public extension ExternalConnectorSessionReport {
    var runtimeEvidenceState: ExternalConnectorRuntimeEvidenceState {
        externalConnectorRuntimeEvidenceState(
            verdict: verdict,
            runtimeError: runtimeError,
            runtimeErrorFree: runtimeErrorFree
        )
    }

    var runtimeEvidenceStatusMessage: String {
        externalConnectorRuntimeEvidenceStatusMessage(
            verdict: verdict,
            state: runtimeEvidenceState
        )
    }
}
