import Foundation
import Observation
import OpenLolaCore

@MainActor
@Observable
final class AppExecutionController {
    var armedForExecution = false
    var settings: NativeAppShellExecutionSettings
    var status = "Idle."
    var phase: AppExecutionPhase = .idle
    var lastCommand: [String] = []
    var stdoutPath: String
    var stderrPath: String
    var previousStdoutPath: String
    var previousStderrPath: String
    var lastExitCode: Int?
    var lastValidationExitCode: Int?
    var lastValidationResult: AppValidationResult = .unknown
    var lastValidationFinishedAt: String?
    var lastRunWasDryRun = false
    var lastReport: NativeAppShellExecutionReport?
    var lastExternalConnectorReport: ExternalConnectorSessionReport?
    var lastLatencyMetrics: AppLatencyHeroMetrics?
    var lastCaptureReport: LoLaCompatibilityCaptureReport?
    var lastError: String?
    var errorLog: [String] = []
    var elapsedSeconds = 0
    var sessionToken: String?
    var previousRunEvidence: [AppRunEvidenceSnapshot] = []

    @ObservationIgnored private var process: ManagedProcess?
    @ObservationIgnored private var startedAt: String?
    @ObservationIgnored private var wasRunning = false
    @ObservationIgnored private var stopWasRequested = false
    @ObservationIgnored private var executionKind: AppExecutionKind = .directMacPeer
    @ObservationIgnored private var externalConnectorReportPath: String?

    private struct AppLaunchRequest {
        var arguments: [String]
        var runningStatus: String
        var dryRunStatus: String
    }

    init(settings: NativeAppShellExecutionSettings = NativeAppShellExecutionSettings()) {
        self.settings = settings
        let logURLs = AppExecutionDefaultLogURLs.make()
        self.stdoutPath = logURLs.stdout.path
        self.stderrPath = logURLs.stderr.path
        self.previousStdoutPath = logURLs.previousStdout.path
        self.previousStderrPath = logURLs.previousStderr.path
    }

    var isRunning: Bool {
        process?.isRunning == true
    }

    var hasValidatedRuntimeEvidence: Bool {
        AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
            executionKind: executionKind,
            validationExitCode: lastValidationExitCode,
            directPeerLatencyMetrics: lastLatencyMetrics,
            externalConnectorReport: lastExternalConnectorReport,
            reportPath: currentRuntimeEvidenceReportPath(),
            currentSessionToken: sessionToken
        )
    }

    var lastValidationSummary: String {
        guard let lastValidationFinishedAt else {
            return "No validation run yet"
        }
        return "Last validated \(lastValidationFinishedAt) — \(lastValidationResult.displayTitle)"
    }

    func runElapsedTimer() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            let running = isRunning
            if running {
                if !wasRunning {
                    elapsedSeconds = 0
                }
                elapsedSeconds += 1
            }
            wasRunning = running
        }
    }

    func dryRun(executablePath: String) {
        start(executablePath: executablePath, execute: false)
    }

    func dryRun(operatorSurface: NativeAppShellOperatorPrototypeState) {
        start(operatorSurface: operatorSurface, execute: false)
    }

    @discardableResult
    func startArmed(executablePath: String) -> Bool {
        guard armedForExecution else {
            lastError = "Execution is not armed."
            status = "Execution blocked."
            phase = .failedToStart
            return false
        }
        return start(executablePath: executablePath, execute: true)
    }

    @discardableResult
    func startArmed(operatorSurface: NativeAppShellOperatorPrototypeState) -> Bool {
        guard armedForExecution else {
            lastError = "Execution is not armed."
            status = "Execution blocked."
            phase = .failedToStart
            return false
        }
        return start(operatorSurface: operatorSurface, execute: true)
    }

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

    func validationReadiness(
        _ kind: AppExecutionKind,
        reportPath: String
    ) -> AppValidationReadiness {
        if isRunning {
            return .running
        }
        let trimmedPath = reportPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty, FileManager.default.fileExists(atPath: trimmedPath) else {
            return .missingReport(trimmedPath.isEmpty ? "unset" : trimmedPath)
        }
        switch AppRuntimeEvidenceScope.sessionTokenMatchResult(
            reportPath: trimmedPath,
            currentSessionToken: sessionToken
        ) {
        case .match:
            break
        case .mismatch, .absent:
            return .staleReport(trimmedPath)
        case .staleReport:
            return .staleReport(trimmedPath)
        case .readError(let error):
            return .evidenceReadError("Session token unreadable for \(trimmedPath): \(error)")
        }
        return .ready
    }

    private func requireValidationReadiness(
        _ kind: AppExecutionKind,
        reportPath: String
    ) -> Bool {
        applyValidationReadiness(validationReadiness(kind, reportPath: reportPath))
    }

    private func requireValidationReadiness(operatorSurface: NativeAppShellOperatorPrototypeState) -> Bool {
        applyValidationReadiness(validationReadiness(operatorSurface: operatorSurface))
    }

    private func applyValidationReadiness(_ readiness: AppValidationReadiness) -> Bool {
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
                executablePath: AppExecutablePathResolver.verifiedPath(operatorSurface.directPeerCommandFields.executablePath)
            )
        case .windowsLoLa:
            let resolvedWindowsExecutable = try AppExecutablePathResolver.verifiedPath(operatorSurface.windowsLoLaPeerFields.executablePath)
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

    func stop() {
        armedForExecution = false
        guard let process else {
            status = "No active process."
            phase = .idle
            return
        }
        stopWasRequested = true
        sessionToken = nil
        process.terminate()
        status = "Stop requested."
        phase = .stopRequested
    }

    func tearDown() {
        if isRunning {
            stop()
        }
    }

    func invalidateRuntimeEvidenceAfterConfigurationChange() {
        guard process == nil, !isRunning, phase != .validationRunning else {
            return
        }
        let hadValidationOrEvidence = lastValidationExitCode != nil
            || lastValidationResult != .unknown
            || lastValidationFinishedAt != nil
            || lastLatencyMetrics != nil
            || lastExternalConnectorReport != nil
            || lastCaptureReport != nil
        guard hadValidationOrEvidence else {
            return
        }
        resetValidationResult()
        lastLatencyMetrics = nil
        lastExternalConnectorReport = nil
        lastCaptureReport = nil
        lastError = nil
        sessionToken = nil
        status = "Configuration changed. Revalidate before starting."
        phase = .idle
    }

    func canOpenLogFile(_ path: String) -> Bool {
        AppExecutionLogFileOpener.canOpen(path)
    }

    func openLogFile(_ path: String) {
        if let error = AppExecutionLogFileOpener.open(path) {
            recordError(error)
            return
        }
    }

    @discardableResult
    private func start(executablePath: String, execute: Bool) -> Bool {
        clearFinishedProcess()
        guard !isRunning else {
            lastError = "A run is already active."
            return false
        }
        lastCommand = []
        do {
            settings.execute = execute
            executionKind = .directMacPeer
            externalConnectorReportPath = nil
            let arguments = try settings.supervisorArguments(
                executablePath: AppExecutablePathResolver.verifiedPath(executablePath)
            )
            try launchProcess(
                arguments: arguments,
                execute: execute,
                runningStatus: "Supervisor running.",
                dryRunStatus: "Supervisor dry run running."
            )
            return true
        } catch {
            let startError = String(describing: error)
            lastError = startError
            status = "Run failed to start."
            phase = .failedToStart
            finishReport()
            lastError = startError
            return false
        }
    }

    @discardableResult
    private func start(operatorSurface: NativeAppShellOperatorPrototypeState, execute: Bool) -> Bool {
        clearFinishedProcess()
        guard !isRunning else {
            lastError = "A run is already active."
            return false
        }
        lastCommand = []
        do {
            let request = try launchRequest(operatorSurface: operatorSurface, execute: execute)
            try launchProcess(
                arguments: request.arguments,
                execute: execute,
                runningStatus: request.runningStatus,
                dryRunStatus: request.dryRunStatus
            )
            return true
        } catch {
            let startError = String(describing: error)
            lastError = startError
            status = "Run failed to start."
            phase = .failedToStart
            finishReport()
            lastError = startError
            return false
        }
    }

    private func launchRequest(
        operatorSurface: NativeAppShellOperatorPrototypeState,
        execute: Bool
    ) throws -> AppLaunchRequest {
        switch operatorSurface.sessionMode.appExecutionRoute {
        case .directMacPeer:
            return try directMacPeerLaunchRequest(operatorSurface: operatorSurface, execute: execute)
        case .windowsLoLa:
            return try windowsLoLaLaunchRequest(operatorSurface: operatorSurface, execute: execute)
        case .externalConnector(let connector):
            return try externalConnectorLaunchRequest(
                operatorSurface: operatorSurface,
                connector: connector,
                execute: execute
            )
        case .unsupportedExternalConnector:
            executionKind = .unsupportedExternalConnector
            externalConnectorReportPath = nil
            throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
        }
    }

    private func directMacPeerLaunchRequest(
        operatorSurface: NativeAppShellOperatorPrototypeState,
        execute: Bool
    ) throws -> AppLaunchRequest {
        let executablePath = try AppExecutablePathResolver.verifiedPath(
            operatorSurface.directPeerCommandFields.executablePath
        )
        settings.execute = execute
        executionKind = .directMacPeer
        externalConnectorReportPath = nil
        return AppLaunchRequest(
            arguments: try settings.supervisorArguments(executablePath: executablePath),
            runningStatus: "Session running.",
            dryRunStatus: "Dry run running."
        )
    }

    private func windowsLoLaLaunchRequest(
        operatorSurface: NativeAppShellOperatorPrototypeState,
        execute: Bool
    ) throws -> AppLaunchRequest {
        let executablePath = try AppExecutablePathResolver.verifiedPath(
            operatorSurface.windowsLoLaPeerFields.executablePath
        )
        executionKind = .windowsLoLa
        externalConnectorReportPath = operatorSurface.windowsLoLaPeerFields.outputPath
        return AppLaunchRequest(
            arguments: try operatorSurface.windowsLoLaSessionArguments(
                executablePath: executablePath,
                dryRun: !execute
            ),
            runningStatus: "Session running.",
            dryRunStatus: "Dry run running."
        )
    }

    private func externalConnectorLaunchRequest(
        operatorSurface: NativeAppShellOperatorPrototypeState,
        connector: ExternalConnectorKind,
        execute: Bool
    ) throws -> AppLaunchRequest {
        let fields = operatorSurface.externalConnectorFields(connector: connector)
        let executablePath = try AppExecutablePathResolver.verifiedPath(fields.executablePath)
        executionKind = .externalConnector(connector)
        externalConnectorReportPath = fields.outputPath
        return AppLaunchRequest(
            arguments: try operatorSurface.externalConnectorSessionArguments(
                connector: connector,
                executablePath: executablePath,
                dryRun: !execute
            ),
            runningStatus: "Session running.",
            dryRunStatus: "Dry run running."
        )
    }

    private func launchProcess(
        arguments: [String],
        execute: Bool,
        runningStatus: String,
        dryRunStatus: String
    ) throws {
        try prepareLaunchState(arguments: arguments, execute: execute)
        try prepareLogFiles()

        do {
            let managedProcess = try ManagedProcessRunner.start(
                executable: arguments[0],
                arguments: Array(arguments.dropFirst()),
                standardOutputPath: stdoutPath,
                standardErrorPath: stderrPath,
                onPrepared: { [weak self] prepared in
                    self?.process = prepared
                },
                terminationHandler: { [weak self] finished in
                    Task { @MainActor in
                        self?.finishLaunchedProcess(finished)
                    }
                }
            )
            self.process = managedProcess
        } catch {
            self.process = nil
            self.sessionToken = nil
            throw error
        }
        status = execute ? runningStatus : dryRunStatus
        phase = execute ? .supervisorRunning : .dryRunRunning
    }

    private func prepareLaunchState(arguments: [String], execute: Bool) throws {
        archiveCurrentEvidenceForNextRun()
        lastCommand = arguments
        startedAt = ISO8601DateFormatter().string(from: Date())
        lastExitCode = nil
        lastRunWasDryRun = !execute
        resetValidationResult()
        lastError = nil
        errorLog = []
        lastExternalConnectorReport = nil
        lastLatencyMetrics = nil
        lastCaptureReport = nil
        stopWasRequested = false
        let nextSessionToken = UUID().uuidString
        sessionToken = nextSessionToken
        if let reportPath = currentRuntimeEvidenceReportPath() {
            try AppRuntimeEvidenceScope.writeSessionToken(nextSessionToken, reportPath: reportPath)
        }
    }

    private func finishLaunchedProcess(_ finished: ManagedProcess) {
        guard process === finished else {
            return
        }
        let wasStopRequested = stopWasRequested
        lastExitCode = Int(finished.terminationStatus)
        status = finishedStatus(finished.terminationStatus, stopRequested: wasStopRequested)
        phase = finishedPhase(finished.terminationStatus, stopRequested: wasStopRequested)
        finished.closeOutputHandles()
        process = nil
        finishReport(stopRequested: wasStopRequested)
    }

    private func finishedStatus(_ exitCode: Int32, stopRequested: Bool) -> String {
        if stopRequested {
            return "Stop requested."
        }
        return exitCode == 0 ? "Run finished." : "Run failed."
    }

    private func finishedPhase(_ exitCode: Int32, stopRequested: Bool) -> AppExecutionPhase {
        if stopRequested {
            return .stopRequested
        }
        return exitCode == 0 ? .runFinished : .runFailed
    }

    private func runOneShot(arguments: [String], completion: @MainActor @Sendable @escaping (Int) -> Void) {
        clearFinishedProcess()
        archiveCurrentEvidenceForNextRun()
        lastCommand = arguments
        startedAt = ISO8601DateFormatter().string(from: Date())
        lastExitCode = nil
        lastRunWasDryRun = false
        resetValidationResult()
        lastError = nil
        errorLog = []
        do {
            try prepareLogFiles()
            let managedProcess = try ManagedProcessRunner.start(
                executable: arguments[0],
                arguments: Array(arguments.dropFirst()),
                standardOutputPath: stdoutPath,
                standardErrorPath: stderrPath,
                onPrepared: { [weak self] prepared in
                    self?.process = prepared
                },
                terminationHandler: { [weak self] finished in
                    Task { @MainActor in
                        guard let self else {
                            completion(1)
                            return
                        }
                        guard self.process === finished else {
                            return
                        }
                        finished.closeOutputHandles()
                        self.process = nil
                        completion(Int(finished.terminationStatus))
                    }
                }
            )
            self.process = managedProcess
            status = "Validation running."
            phase = .validationRunning
        } catch {
            self.process = nil
            recordError("Validation launch failed: \(error)")
            status = "Validation failed to start."
            phase = .validationFailed
            finishReport()
        }
    }

    private func resetValidationResult() {
        lastValidationExitCode = nil
        lastValidationResult = .unknown
        lastValidationFinishedAt = nil
    }

    func archiveCurrentEvidenceForNextRun() {
        guard let snapshot = AppRunEvidenceSnapshot.make(from: self) else {
            return
        }
        previousRunEvidence.insert(snapshot, at: 0)
        if previousRunEvidence.count > AppRunEvidenceSnapshot.ringLimit {
            previousRunEvidence.removeLast(previousRunEvidence.count - AppRunEvidenceSnapshot.ringLimit)
        }
    }

    private func prepareLogFiles() throws {
        let directory = URL(fileURLWithPath: stdoutPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try AppExecutionLogSnapshot.preserveCurrentLogIfPresent(
            sourcePath: stdoutPath,
            previousPath: previousStdoutPath
        )
        try AppExecutionLogSnapshot.preserveCurrentLogIfPresent(
            sourcePath: stderrPath,
            previousPath: previousStderrPath
        )
        try Data().write(to: URL(fileURLWithPath: stdoutPath))
        try Data().write(to: URL(fileURLWithPath: stderrPath))
    }

    private func finishReport(stopRequested: Bool = false, validationExitCode: Int? = nil) {
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

    private func executionReportVerdict(
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

    private func validationEvidenceErrorMessage() -> String {
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

    private func directMacPeerValidationEvidenceErrorMessage() -> String {
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
            return "Validated supervisor report is older than the current session token: \(settings.supervisorReportPath)"
        }
        if let metrics = lastLatencyMetrics, metrics.isPartial {
            return "Supervisor evidence incomplete: \(metrics.evidenceStatusMessage ?? "partial peer reports")"
        }
        return "Validated supervisor report missing or unreadable: \(settings.supervisorReportPath)"
    }

    private func externalConnectorValidationEvidenceErrorMessage() -> String {
        if let report = lastExternalConnectorReport {
            return "External connector evidence incomplete: \(report.runtimeEvidenceStatusMessage)"
        }
        return "Validated external connector report missing or unreadable: \(externalConnectorReportPath ?? "unset")"
    }

    private func executablePathFromCommand() throws -> String {
        guard let executablePath = lastCommand.first else {
            throw AppExecutablePathResolutionError(
                resolution: .unavailable(path: "unset", reason: "no verified command has been prepared")
            )
        }
        return executablePath
    }

    private func validatorArgumentsFromCurrentExecution() throws -> [String] {
        switch executionKind {
        case .directMacPeer:
            return try settings.validatorArguments(executablePath: executablePathFromCommand())
        case .windowsLoLa:
            return [
                try executablePathFromCommand(),
                "validate-external-connector-session-report",
                externalConnectorReportPath ?? "",
            ]
        case .externalConnector:
            return [
                try executablePathFromCommand(),
                "validate-external-connector-session-report",
                externalConnectorReportPath ?? "",
            ]
        case .unsupportedExternalConnector:
            return []
        }
    }

    private func refreshExternalConnectorReport() {
        let loadedReport = AppExecutionReportLoader.externalConnectorReport(
            executionKind: executionKind,
            path: externalConnectorReportPath
        )
        lastExternalConnectorReport = loadedReport.report
        if let error = loadedReport.errorMessage {
            recordError(error)
        }
    }

    private var executionNotes: String {
        switch executionKind {
        case .directMacPeer:
            return "App-supervised CLI execution. Real-world PASS remains gated by measured two-Mac evidence."
        case .windowsLoLa:
            return "App-supervised LoLa connector execution. Real-world PASS remains gated by measured endpoint evidence."
        case .externalConnector(let connector):
            return "App-supervised \(connector.rawValue) connector execution. Real-world PASS remains gated by measured endpoint evidence."
        case .unsupportedExternalConnector:
            return "External connector mode is selectable for planning only; this app did not launch it."
        }
    }

    private func refreshCaptureReport() {
        let loadedReport = AppExecutionReportLoader.captureReport(
            executionKind: executionKind,
            supervisorReportPath: settings.supervisorReportPath
        )
        lastCaptureReport = loadedReport.report
        if let error = loadedReport.errorMessage {
            recordError(error)
        }
    }

    private func currentRuntimeEvidenceReportPath() -> String? {
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

    private func recordError(_ message: String) {
        errorLog.append(message)
        lastError = message
    }

    private func clearFinishedProcess() {
        guard process?.isRunning != true else {
            return
        }
        process?.closeOutputHandles()
        process = nil
        stopWasRequested = false
    }
}
