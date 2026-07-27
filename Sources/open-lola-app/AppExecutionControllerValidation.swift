// Validates AppExecutionControllerValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation
import OpenLolaCore

@MainActor
extension AppExecutionController {
    func validateReport(executablePath: String) {
        guard process == nil, !isRunning, phase != .validationRunning else {
            lastError = "Cannot validate while a run is active."
            return
        }
        resetValidationResult()
        lastCommand = []
        guard requireValidationReadiness(.directMacPeer, reportPath: settings.supervisorReportPath) else {
            return
        }
        do {
            executionKind = .directMacPeer
            externalConnectorReportPath = nil
            let arguments = try settings.validatorArguments(
                executablePath: AppExecutablePathResolver.verifiedPath(executablePath)
            )
            runOneShot(arguments: arguments) { [weak self] exitCode in
                self?.finishValidation(exitCode: exitCode)
            }
        } catch {
            lastError = String(describing: error)
            status = "Validation unavailable."
            phase = .validationFailed
        }
    }
    func validateReport(operatorSurface: NativeAppShellOperatorPrototypeState) {
        guard process == nil, !isRunning, phase != .validationRunning else {
            lastError = "Cannot validate while a run is active."
            return
        }
        resetValidationResult()
        lastCommand = []
        guard requireValidationReadiness(operatorSurface: operatorSurface) else {
            return
        }
        do {
            let arguments = try prepareValidationContext(operatorSurface: operatorSurface)
            runOneShot(arguments: arguments) { [weak self] exitCode in
                self?.finishValidation(exitCode: exitCode)
            }
        } catch {
            lastError = String(describing: error)
            status = "Validation unavailable."
            phase = .validationFailed
        }
    }
    func canValidateReport(operatorSurface: NativeAppShellOperatorPrototypeState) -> Bool {
        validationReadiness(operatorSurface: operatorSurface).isReady
    }
    func validationReadiness(operatorSurface: NativeAppShellOperatorPrototypeState) -> AppValidationReadiness {
        switch operatorSurface.sessionMode.appExecutionRoute {
        case .directMacPeer:
            return validationReadiness(.directMacPeer, reportPath: settings.supervisorReportPath)
        case .windowsLoLa:
            return validationReadiness(.windowsLoLa, reportPath: operatorSurface.windowsLoLaPeerFields.outputPath)
        case .externalConnector(let connector):
            return validationReadiness(
                .externalConnector(connector),
                reportPath: operatorSurface.externalConnectorFields(connector: connector).outputPath
            )
        case .unsupportedExternalConnector(let reason):
            return .unsupported(reason)
        }
    }
    func requireValidationReadiness(
        _ kind: AppExecutionKind,
        reportPath: String
    ) -> Bool {
        applyValidationReadiness(validationReadiness(kind, reportPath: reportPath))
    }
    func requireValidationReadiness(operatorSurface: NativeAppShellOperatorPrototypeState) -> Bool {
        applyValidationReadiness(validationReadiness(operatorSurface: operatorSurface))
    }
    func applyValidationReadiness(_ readiness: AppValidationReadiness) -> Bool {
        if readiness.isReady {
            return true
        }
        lastError = readiness.unavailableMessage
        status = "Validation unavailable."
        phase = .validationFailed
        return false
    }
    func prepareValidationContext(operatorSurface: NativeAppShellOperatorPrototypeState) throws -> [String] {
        switch operatorSurface.sessionMode.appExecutionRoute {
        case .directMacPeer:
            executionKind = .directMacPeer
            externalConnectorReportPath = nil
            return try settings.validatorArguments(
                executablePath: AppExecutablePathResolver.verifiedPath(
                    operatorSurface.directPeerCommandFields.executablePath
                )
            )
        case .windowsLoLa:
            let resolvedWindowsExecutable = try AppExecutablePathResolver.verifiedPath(
                operatorSurface.windowsLoLaPeerFields.executablePath
            )
            executionKind = .windowsLoLa
            externalConnectorReportPath = operatorSurface.windowsLoLaPeerFields.outputPath
            return try operatorSurface.windowsLoLaValidatorArguments(executablePath: resolvedWindowsExecutable)
        case .externalConnector(let connector):
            let fields = operatorSurface.externalConnectorFields(connector: connector)
            let resolvedExecutable = try AppExecutablePathResolver.verifiedPath(fields.executablePath)
            executionKind = .externalConnector(connector)
            externalConnectorReportPath = fields.outputPath
            return try operatorSurface.externalConnectorValidatorArguments(
                connector: connector,
                executablePath: resolvedExecutable
            )
        case .unsupportedExternalConnector:
            executionKind = .unsupportedExternalConnector
            externalConnectorReportPath = nil
            throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
        }
    }
    func finishValidation(exitCode: Int) {
        lastValidationExitCode = exitCode
        lastValidationFinishedAt = ISO8601DateFormatter().string(from: Date())
        finishReport(validationExitCode: exitCode)
        guard exitCode == 0 else {
            lastValidationResult = .failed
            status = "Validation failed."
            phase = .validationFailed
            return
        }
        if hasValidatedRuntimeEvidence {
            lastValidationResult = .passed
            status = "Validation passed."
            phase = .validationPassed
        } else {
            lastValidationResult = .failed
            status = "Validation evidence incomplete."
            phase = .validationFailed
            recordError(validationEvidenceErrorMessage())
        }
    }
    func validationEvidenceErrorMessage() -> String {
        switch executionKind {
        case .directMacPeer:
            return directMacPeerValidationEvidenceErrorMessage()
        case .windowsLoLa:
            return externalConnectorValidationEvidenceErrorMessage()
        case .externalConnector:
            return externalConnectorValidationEvidenceErrorMessage()
        case .unsupportedExternalConnector:
            return "Unsupported external connector route cannot be launched from this app."
        }
    }
    func directMacPeerValidationEvidenceErrorMessage() -> String {
        let evidenceState = AppRuntimeEvidenceScope.hasValidatedRuntimeEvidenceState(
            executionKind: executionKind,
            validationExitCode: lastValidationExitCode,
            directPeerLatencyMetrics: lastLatencyMetrics,
            externalConnectorReport: lastExternalConnectorReport,
            reportPath: currentRuntimeEvidenceReportPath(),
            currentSessionToken: sessionToken
        )
        if case .tokenReadError(let error) = evidenceState {
            return "Validated supervisor session token unreadable: \(error)"
        }
        if evidenceState == .staleReport {
            return "Validated supervisor report is older than the current session token: "
            + settings.supervisorReportPath
        }
        if let metrics = lastLatencyMetrics, metrics.isPartial {
            return "Supervisor evidence incomplete: \(metrics.evidenceStatusMessage ?? "partial peer reports")"
        }
        return "Validated supervisor report missing or unreadable: \(settings.supervisorReportPath)"
    }
    func externalConnectorValidationEvidenceErrorMessage() -> String {
        if let report = lastExternalConnectorReport {
            return "External connector evidence incomplete: \(report.runtimeEvidenceStatusMessage)"
        }
        return "Validated external connector report missing or unreadable: \(externalConnectorReportPath ?? "unset")"
    }
    func executablePathFromCommand() throws -> String {
        guard let executablePath = lastCommand.first else {
            throw AppExecutablePathResolutionError(
                resolution: .unavailable(path: "unset", reason: "no verified command has been prepared")
            )
        }
        return executablePath
    }
    func validatorArgumentsFromCurrentExecution() throws -> [String] {
        switch executionKind {
        case .directMacPeer:
            return try settings.validatorArguments(executablePath: executablePathFromCommand())
        case .windowsLoLa:
            return [
                try executablePathFromCommand(),
                "validate-external-connector-session-report",
                externalConnectorReportPath ?? ""
            ]
        case .externalConnector:
            return [
                try executablePathFromCommand(),
                "validate-external-connector-session-report",
                externalConnectorReportPath ?? ""
            ]
        case .unsupportedExternalConnector:
            return []
        }
    }
}
