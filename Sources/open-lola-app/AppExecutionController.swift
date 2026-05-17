import Foundation
import AppKit
import Observation
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
    case unsupportedExternalConnector
}
enum AppValidationReadiness: Equatable {
    case ready
    case running
    case missingReport(String)
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
        case .unsupported(let reason):
            return reason
        }
    }
}

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
    var lastExitCode: Int?
    var lastValidationExitCode: Int?
    var lastReport: NativeAppShellExecutionReport?
    var lastExternalConnectorReport: ExternalConnectorSessionReport?
    var lastLatencyMetrics: AppLatencyHeroMetrics?
    var lastCaptureReport: LoLaCompatibilityCaptureReport?
    var lastError: String?
    var errorLog: [String] = []
    var elapsedSeconds = 0

    @ObservationIgnored private var process: ManagedProcess?
    @ObservationIgnored private var startedAt: String?
    @ObservationIgnored private var wasRunning = false
    @ObservationIgnored private var stopWasRequested = false
    @ObservationIgnored private var executionKind: AppExecutionKind = .directMacPeer
    @ObservationIgnored private var externalConnectorReportPath: String?

    init(settings: NativeAppShellExecutionSettings = NativeAppShellExecutionSettings()) {
        self.settings = settings
        let logURLs = Self.defaultLogURLs()
        self.stdoutPath = logURLs.stdout.path
        self.stderrPath = logURLs.stderr.path
    }

    var isRunning: Bool {
        process?.isRunning == true
    }

    var hasValidatedRuntimeEvidence: Bool {
        AppRuntimeEvidenceScope.hasValidatedRuntimeEvidence(
            executionKind: executionKind,
            validationExitCode: lastValidationExitCode,
            directPeerLatencyMetrics: lastLatencyMetrics,
            externalConnectorReport: lastExternalConnectorReport
        )
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

    func supervisorCommand(executablePath: String) -> Result<[String], Error> {
        Result { try settings.supervisorArguments(executablePath: AppExecutablePathResolver.verifiedPath(executablePath)) }
    }

    func validatorCommand(executablePath: String) -> Result<[String], Error> {
        Result { try settings.validatorArguments(executablePath: AppExecutablePathResolver.verifiedPath(executablePath)) }
    }

    func executionCommand(
        executablePath: String,
        operatorSurface: NativeAppShellOperatorPrototypeState,
        dryRun: Bool
    ) -> Result<[String], Error> {
        Result {
            let resolvedExecutable = try AppExecutablePathResolver.verifiedPath(executablePath)
            switch operatorSurface.sessionMode {
            case .directMacPeer:
                var previewSettings = settings
                previewSettings.execute = !dryRun
                return try previewSettings.supervisorArguments(executablePath: resolvedExecutable)
            case .windowsLoLa:
                return try operatorSurface.windowsLoLaSessionArguments(
                    executablePath: resolvedExecutable,
                    dryRun: dryRun
                )
            case .jackTrip, .ultraGrid:
                throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
            }
        }
    }

    func validatorCommand(
        executablePath: String,
        operatorSurface: NativeAppShellOperatorPrototypeState
    ) -> Result<[String], Error> {
        Result {
            let resolvedExecutable = try AppExecutablePathResolver.verifiedPath(executablePath)
            switch operatorSurface.sessionMode {
            case .directMacPeer:
                return try settings.validatorArguments(executablePath: resolvedExecutable)
            case .windowsLoLa:
                return try operatorSurface.windowsLoLaValidatorArguments(executablePath: resolvedExecutable)
            case .jackTrip, .ultraGrid:
                throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
            }
        }
    }

    func dryRun(executablePath: String) {
        start(executablePath: executablePath, execute: false)
    }

    func dryRun(operatorSurface: NativeAppShellOperatorPrototypeState) {
        start(operatorSurface: operatorSurface, execute: false)
    }

    @discardableResult
    func writePlanOrLogError(from operatorSurface: NativeAppShellOperatorPrototypeState) -> Bool {
        do {
            _ = try operatorSurface.writeTwoPeerRunPlanArtifact(
                to: URL(fileURLWithPath: settings.planPath),
                runDirectory: URL(fileURLWithPath: settings.planPath)
                    .deletingLastPathComponent()
                    .path
            )
            status = "Plan written."
            phase = .planWritten
            lastError = nil
            return true
        } catch {
            lastError = String(describing: error)
            status = "Plan write failed."
            phase = .runFailed
            return false
        }
    }

    func startArmed(executablePath: String) {
        guard armedForExecution else {
            lastError = "Execution is not armed."
            status = "Execution blocked."
            phase = .failedToStart
            return
        }
        start(executablePath: executablePath, execute: true)
    }

    func startArmed(operatorSurface: NativeAppShellOperatorPrototypeState) {
        guard armedForExecution else {
            lastError = "Execution is not armed."
            status = "Execution blocked."
            phase = .failedToStart
            return
        }
        start(operatorSurface: operatorSurface, execute: true)
    }

    func validateReport(executablePath: String) {
        guard !isRunning else {
            lastError = "Cannot validate while a run is active."
            return
        }
        lastValidationExitCode = nil
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
        guard !isRunning else {
            lastError = "Cannot validate while a run is active."
            return
        }
        lastValidationExitCode = nil
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
        switch operatorSurface.sessionMode {
        case .directMacPeer:
            return validationReadiness(.directMacPeer, reportPath: settings.supervisorReportPath)
        case .windowsLoLa:
            return validationReadiness(.windowsLoLa, reportPath: operatorSurface.windowsLoLaPeerFields.outputPath)
        case .jackTrip, .ultraGrid:
            return .unsupported(operatorSurface.sessionMode.unavailableAppReason ?? operatorSurface.sessionMode.appModeSummary)
        }
    }

    private func validationReadiness(
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
        switch operatorSurface.sessionMode {
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
        case .jackTrip, .ultraGrid:
            executionKind = .unsupportedExternalConnector
            externalConnectorReportPath = nil
            throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
        }
    }

    func finishValidation(exitCode: Int) {
        lastValidationExitCode = exitCode
        finishReport(validationExitCode: exitCode)
        guard exitCode == 0 else {
            status = "Validation failed."
            phase = .validationFailed
            return
        }
        if hasValidatedRuntimeEvidence {
            status = "Validation passed."
            phase = .validationPassed
        } else {
            status = "Validation evidence incomplete."
            phase = .validationFailed
            recordError(validationEvidenceErrorMessage())
        }
    }

    func stop() {
        guard let process else {
            status = "No active process."
            phase = .idle
            return
        }
        stopWasRequested = true
        process.terminate()
        status = "Stop requested."
        phase = .stopRequested
    }

    func tearDown() {
        if isRunning {
            stop()
        }
    }

    func canOpenLogFile(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    func openLogFile(_ path: String) {
        guard canOpenLogFile(path) else {
            recordError("Log file missing: \(path)")
            return
        }
        guard NSWorkspace.shared.open(URL(fileURLWithPath: path)) else {
            recordError("Failed to open log file: \(path)")
            return
        }
    }

    private func start(executablePath: String, execute: Bool) {
        clearFinishedProcess()
        guard !isRunning else {
            lastError = "A run is already active."
            return
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
        } catch {
            let startError = String(describing: error)
            lastError = startError
            status = "Run failed to start."
            phase = .failedToStart
            finishReport()
            lastError = startError
        }
    }

    private func start(operatorSurface: NativeAppShellOperatorPrototypeState, execute: Bool) {
        clearFinishedProcess()
        guard !isRunning else {
            lastError = "A run is already active."
            return
        }
        lastCommand = []
        do {
            let executablePath: String
            let arguments: [String]
            switch operatorSurface.sessionMode {
            case .directMacPeer:
                executablePath = try AppExecutablePathResolver.verifiedPath(operatorSurface.directPeerCommandFields.executablePath)
                settings.execute = execute
                executionKind = .directMacPeer
                externalConnectorReportPath = nil
                arguments = try settings.supervisorArguments(executablePath: executablePath)
            case .windowsLoLa:
                executablePath = try AppExecutablePathResolver.verifiedPath(operatorSurface.windowsLoLaPeerFields.executablePath)
                executionKind = .windowsLoLa
                externalConnectorReportPath = operatorSurface.windowsLoLaPeerFields.outputPath
                arguments = try operatorSurface.windowsLoLaSessionArguments(executablePath: executablePath, dryRun: !execute)
            case .jackTrip, .ultraGrid:
                executionKind = .unsupportedExternalConnector
                externalConnectorReportPath = nil
                throw NativeAppShellSurfaceValidationError.invalidCommandField("sessionMode")
            }
            try launchProcess(
                arguments: arguments,
                execute: execute,
                runningStatus: "Session running.",
                dryRunStatus: "Dry run running."
            )
        } catch {
            let startError = String(describing: error)
            lastError = startError
            status = "Run failed to start."
            phase = .failedToStart
            finishReport()
            lastError = startError
        }
    }

    private func launchProcess(
        arguments: [String],
        execute: Bool,
        runningStatus: String,
        dryRunStatus: String
    ) throws {
        lastCommand = arguments
        startedAt = ISO8601DateFormatter().string(from: Date())
        lastExitCode = nil
        lastValidationExitCode = nil
        lastError = nil
        errorLog = []
        lastExternalConnectorReport = nil
        lastLatencyMetrics = nil
        lastCaptureReport = nil
        stopWasRequested = false
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
                        guard let self, self.process === finished else {
                            return
                        }
                        let wasStopRequested = self.stopWasRequested
                        self.lastExitCode = Int(finished.terminationStatus)
                        if wasStopRequested {
                            self.status = "Stop requested."
                            self.phase = .stopRequested
                        } else {
                            self.status = finished.terminationStatus == 0 ? "Run finished." : "Run failed."
                            self.phase = finished.terminationStatus == 0 ? .runFinished : .runFailed
                        }
                        finished.closeOutputHandles()
                        self.process = nil
                        self.finishReport(stopRequested: wasStopRequested)
                    }
                }
            )
            self.process = managedProcess
        } catch {
            self.process = nil
            throw error
        }
        status = execute ? runningStatus : dryRunStatus
        phase = execute ? .supervisorRunning : .dryRunRunning
    }

    private func runOneShot(arguments: [String], completion: @MainActor @Sendable @escaping (Int) -> Void) {
        clearFinishedProcess()
        lastCommand = arguments
        startedAt = ISO8601DateFormatter().string(from: Date())
        lastExitCode = nil
        lastValidationExitCode = nil
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

    private func prepareLogFiles() throws {
        let directory = URL(fileURLWithPath: stdoutPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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
            supervisorReportPath: settings.supervisorReportPath
        )
        let report = NativeAppShellExecutionReport(
            command: lastCommand,
            startedAt: startedAt ?? ISO8601DateFormatter().string(from: Date()),
            finishedAt: ISO8601DateFormatter().string(from: Date()),
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
        )
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
        case .unsupportedExternalConnector:
            return .partial
        }
    }

    private func validationEvidenceErrorMessage() -> String {
        switch executionKind {
        case .directMacPeer:
            if let metrics = lastLatencyMetrics, metrics.isPartial {
                return "Supervisor evidence incomplete: \(metrics.evidenceStatusMessage ?? "partial peer reports")"
            }
            return "Validated supervisor report missing or unreadable: \(settings.supervisorReportPath)"
        case .windowsLoLa:
            if let report = lastExternalConnectorReport {
                return "External connector evidence incomplete: verdict \(report.verdict.rawValue)"
            }
            return "Validated external connector report missing or unreadable: \(externalConnectorReportPath ?? "unset")"
        case .unsupportedExternalConnector:
            return "External connector mode is not launchable from this app."
        }
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
        case .unsupportedExternalConnector:
            return []
        }
    }

    private func refreshExternalConnectorReport() {
        guard executionKind == .windowsLoLa, let path = externalConnectorReportPath else {
            lastExternalConnectorReport = nil
            return
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            lastExternalConnectorReport = nil
            return
        }
        do {
            let report = try ExternalConnectorSessionReport.readValidated(from: url)
            lastExternalConnectorReport = report
        } catch {
            lastExternalConnectorReport = nil
            recordError("External connector report unavailable: \(error)")
        }
    }

    private var executionNotes: String {
        switch executionKind {
        case .directMacPeer:
            return "App-supervised CLI execution. Real-world PASS remains gated by measured two-Mac evidence."
        case .windowsLoLa:
            return "App-supervised LoLa connector execution. Real-world PASS remains gated by measured endpoint evidence."
        case .unsupportedExternalConnector:
            return "External connector mode is selectable for planning only; this app did not launch it."
        }
    }

    private func refreshCaptureReport() {
        guard AppRuntimeEvidenceScope.allowsDirectPeerCaptureEvidence(executionKind: executionKind) else {
            lastCaptureReport = nil
            return
        }
        let url = captureReportURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            lastCaptureReport = nil
            return
        }
        do {
            let report = try LoLaCompatibilityCaptureReport.readValidated(from: url)
            lastCaptureReport = report
        } catch {
            lastCaptureReport = nil
            recordError("Capture report unavailable: \(error)")
        }
    }

    private func recordError(_ message: String) {
        errorLog.append(message)
        lastError = message
    }

    private func captureReportURL() -> URL {
        URL(fileURLWithPath: settings.supervisorReportPath)
            .deletingLastPathComponent()
            .appendingPathComponent("lola-capture-report.json")
    }

    private func clearFinishedProcess() {
        guard process?.isRunning != true else {
            return
        }
        process?.closeOutputHandles()
        process = nil
        stopWasRequested = false
    }

    private static func defaultLogURLs() -> (stdout: URL, stderr: URL) {
        let baseDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "open-lola-app"
        let logDirectory = baseDirectory
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("logs", isDirectory: true)
        return (
            stdout: logDirectory.appendingPathComponent("execution-stdout.log"),
            stderr: logDirectory.appendingPathComponent("execution-stderr.log")
        )
    }
}
