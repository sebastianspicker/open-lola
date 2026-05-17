import OpenLolaCore

enum AppRuntimeEvidenceScope {
    static func directPeerSupervisorMetrics(
        executionKind: AppExecutionKind,
        validationExitCode: Int?,
        supervisorReportPath: String
    ) -> AppLatencyHeroMetrics? {
        guard executionKind == .directMacPeer, validationExitCode == 0 else {
            return nil
        }
        return AppLatencyHeroMetrics.load(fromSupervisorReportPath: supervisorReportPath)
    }

    static func hasValidatedRuntimeEvidence(
        executionKind: AppExecutionKind,
        validationExitCode: Int?,
        directPeerLatencyMetrics: AppLatencyHeroMetrics?,
        externalConnectorReport: ExternalConnectorSessionReport?
    ) -> Bool {
        guard validationExitCode == 0 else {
            return false
        }
        switch executionKind {
        case .directMacPeer:
            guard let directPeerLatencyMetrics else {
                return false
            }
            return !directPeerLatencyMetrics.isPartial
        case .windowsLoLa:
            return externalConnectorReport?.verdict == .pass
        case .unsupportedExternalConnector:
            return false
        }
    }

    static func allowsDirectPeerCaptureEvidence(executionKind: AppExecutionKind) -> Bool {
        executionKind == .directMacPeer
    }
}
