// Coordinates AppExecutionControllerLaunch application state, keeping UI actions and long-running execution in one observable boundary.
import Foundation
import OpenLolaCore

@MainActor
extension AppExecutionController {
    struct AppLaunchRequest {
        var arguments: [String]
        var runningStatus: String
        var dryRunStatus: String
    }
    @discardableResult
    func start(executablePath: String, execute: Bool) -> Bool {
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
    func start(operatorSurface: NativeAppShellOperatorPrototypeState, execute: Bool) -> Bool {
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
    func launchRequest(
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
    func directMacPeerLaunchRequest(
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
    func windowsLoLaLaunchRequest(
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
    func externalConnectorLaunchRequest(
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
    func launchProcess(
        arguments: [String],
        execute: Bool,
        runningStatus: String,
        dryRunStatus: String
    ) throws {
        try prepareLaunchState(arguments: arguments, execute: execute)
        try prepareLogFiles()

        do {
            let managedProcess = try startManagedProcess(arguments: arguments) { [weak self] finished in
                Task { @MainActor in
                    self?.finishLaunchedProcess(finished)
                }
            }
            self.process = managedProcess
        } catch {
            self.process = nil
            self.sessionToken = nil
            throw error
        }
        status = execute ? runningStatus : dryRunStatus
        phase = execute ? .supervisorRunning : .dryRunRunning
    }
    func prepareLaunchState(arguments: [String], execute: Bool) throws {
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
    func finishLaunchedProcess(_ finished: ManagedProcess) {
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
    func finishedStatus(_ exitCode: Int32, stopRequested: Bool) -> String {
        if stopRequested {
            return "Stop requested."
        }
        return exitCode == 0 ? "Run finished." : "Run failed."
    }
    func finishedPhase(_ exitCode: Int32, stopRequested: Bool) -> AppExecutionPhase {
        if stopRequested {
            return .stopRequested
        }
        return exitCode == 0 ? .runFinished : .runFailed
    }
    func runOneShot(arguments: [String], completion: @MainActor @Sendable @escaping (Int) -> Void) {
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
            let managedProcess = try startManagedProcess(arguments: arguments) { [weak self] finished in
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
    func resetValidationResult() {
        lastValidationExitCode = nil
        lastValidationResult = .unknown
        lastValidationFinishedAt = nil
    }

    private func startManagedProcess(
        arguments: [String],
        terminationHandler: @escaping @Sendable (ManagedProcess) -> Void
    ) throws -> ManagedProcess {
        try ManagedProcessRunner.start(
            executable: arguments[0],
            arguments: Array(arguments.dropFirst()),
            standardOutputPath: stdoutPath,
            standardErrorPath: stderrPath,
            onPrepared: { [weak self] prepared in
                self?.process = prepared
            },
            terminationHandler: terminationHandler
        )
    }

    func prepareLogFiles() throws {
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
    func clearFinishedProcess() {
        guard process?.isRunning != true else {
            return
        }
        process?.closeOutputHandles()
        process = nil
        stopWasRequested = false
    }
}
