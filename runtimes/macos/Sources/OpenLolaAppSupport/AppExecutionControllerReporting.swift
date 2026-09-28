// Finalizes app execution reports, refreshes connector or capture artifacts, and records terminal errors at the UI-controller boundary.
import Foundation
import OpenLolaCore

@MainActor
extension AppExecutionController {
    func finishReport(stopRequested: Bool = false, validationExitCode: Int? = nil) {
        let validatorCommand: [String]
        do {
            validatorCommand = try validatorArgumentsFromCurrentExecution()
        } catch {
            validatorCommand = []
            recordError(String(describing: error))
        }
        refreshExternalConnectorReport()
        let effectiveValidationExitCode = validationExitCode ?? lastValidationExitCode
        let directPeerLatencyMetrics = AppRuntimeEvidenceScope.directPeerSupervisorMetrics(
            executionKind: executionKind,
            validationExitCode: effectiveValidationExitCode,
            supervisorReportPath: settings.supervisorReportPath,
            currentSessionToken: sessionToken
        )
        let report = AppExecutionReportAssembler.make(AppExecutionReportDraft(
            command: lastCommand,
            startedAt: startedAt ?? ISO8601DateFormatter().string(from: Date()),
            exitCode: lastExitCode,
            stdoutPath: stdoutPath,
            stderrPath: stderrPath,
            stopRequested: stopRequested,
            validatorCommand: validatorCommand,
            validationExitCode: effectiveValidationExitCode,
            verdict: executionReportVerdict(
                validationExitCode: effectiveValidationExitCode,
                directPeerLatencyMetrics: directPeerLatencyMetrics
            ),
            notes: executionNotes
        ))
        lastReport = report
        lastLatencyMetrics = directPeerLatencyMetrics
        refreshCaptureReport()
        clearFinishedProcess()
    }
    func executionReportVerdict(
        validationExitCode: Int?,
        directPeerLatencyMetrics: AppLatencyHeroMetrics?
    ) -> MeasurementVerdict {
        guard validationExitCode == 0 else {
            return .partial
        }
        switch executionKind {
        case .directMacPeer:
            return directPeerLatencyMetrics?.supervisorVerdict ?? .partial
        case .windowsLoLa:
            return lastExternalConnectorReport?.verdict ?? .partial
        case .externalConnector:
            return lastExternalConnectorReport?.verdict ?? .partial
        case .unsupportedExternalConnector:
            return .partial
        }
    }
    func refreshExternalConnectorReport() {
        let loadedReport = AppExecutionReportLoader.externalConnectorReport(
            executionKind: executionKind,
            path: externalConnectorReportPath
        )
        lastExternalConnectorReport = loadedReport.report
        if let error = loadedReport.errorMessage {
            recordError(error)
        }
    }
    var executionNotes: String {
        switch executionKind {
        case .directMacPeer:
            return "App-supervised CLI execution. Real-world PASS remains gated by measured two-Mac evidence."
        case .windowsLoLa:
            return "App-supervised LoLa connector execution. "
            + "Real-world PASS remains gated by measured endpoint evidence."
        case .externalConnector(let connector):
            return "App-supervised \(connector.rawValue) connector execution. "
            + "Real-world PASS remains gated by measured endpoint evidence."
        case .unsupportedExternalConnector:
            return "External connector mode is selectable for planning only; this app did not launch it."
        }
    }
    func refreshCaptureReport() {
        let loadedReport = AppExecutionReportLoader.captureReport(
            executionKind: executionKind,
            supervisorReportPath: settings.supervisorReportPath
        )
        lastCaptureReport = loadedReport.report
        if let error = loadedReport.errorMessage {
            recordError(error)
        }
    }
    func currentRuntimeEvidenceReportPath() -> String? {
        switch executionKind {
        case .directMacPeer:
            return settings.supervisorReportPath
        case .windowsLoLa:
            return externalConnectorReportPath
        case .externalConnector:
            return externalConnectorReportPath
        case .unsupportedExternalConnector:
            return nil
        }
    }
    func recordError(_ message: String) {
        errorLog.append(message)
        lastError = message
    }
}
