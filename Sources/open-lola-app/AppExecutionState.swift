import OpenLolaCore

enum AppExecutionPhase: Equatable {
    case idle
    case planWritten
    case dryRunRunning
    case supervisorRunning
    case stopRequested
    case validationRunning
    case validationPassed
    case validationFailed
    case runFinished
    case runFailed
    case failedToStart
}

enum AppExecutionKind: Equatable {
    case directMacPeer
    case windowsLoLa
    case externalConnector(ExternalConnectorKind)
    case unsupportedExternalConnector
}

enum AppValidationResult: Equatable {
    case unknown
    case passed
    case failed

    var displayTitle: String {
        switch self {
        case .unknown:
            return "UNKNOWN"
        case .passed:
            return "PASSED"
        case .failed:
            return "FAILED"
        }
    }
}

enum AppValidationReadiness: Equatable {
    case ready
    case running
    case missingReport(String)
    case staleReport(String)
    case evidenceReadError(String)
    case unsupported(String)

    var isReady: Bool {
        self == .ready
    }

    var unavailableMessage: String? {
        switch self {
        case .ready:
            return nil
        case .running:
            return "Cannot validate while a run is active."
        case .missingReport(let path):
            return "Cannot validate missing report artifact: \(path)"
        case .staleReport(let path):
            return "Cannot validate stale report artifact from a previous session: \(path)"
        case .evidenceReadError(let message):
            return "Cannot validate evidence state: \(message)"
        case .unsupported(let reason):
            return reason
        }
    }
}

enum AppRuntimeEvidenceInvalidationPolicy {
    static func shouldInvalidateRuntimeEvidence(
        oldSurface: NativeAppShellOperatorPrototypeState,
        newSurface: NativeAppShellOperatorPrototypeState
    ) -> Bool {
        oldSurface.sessionMode != newSurface.sessionMode
            || oldSurface.inventory != newSurface.inventory
            || oldSurface.remoteInventory != newSurface.remoteInventory
            || oldSurface.remoteOrchestrationEnabled != newSurface.remoteOrchestrationEnabled
            || oldSurface.startsLongRunningProcess != newSurface.startsLongRunningProcess
            || oldSurface.directPeerCommandFields != newSurface.directPeerCommandFields
            || oldSurface.windowsLoLaPeerFields != newSurface.windowsLoLaPeerFields
            || oldSurface.jackTripPeerFields != newSurface.jackTripPeerFields
            || oldSurface.ultraGridPeerFields != newSurface.ultraGridPeerFields
    }
}
