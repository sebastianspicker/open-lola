// Runs the connection preflight before a two-Mac start and launches the supervisor only when that preflight passed.
import Foundation
import OpenLolaCore

/// What the app does once the connection preflight process has exited.
enum AppConnectionPreflightDecision: Equatable {
    case startSupervisor
    case blocked(String)
}

/// What a preflight report must match to count as this launch's result rather than a leftover from an earlier run.
struct AppConnectionPreflightFreshness: Equatable {
    /// Fingerprint of the plan the preflight was launched against; nil when that plan could not be read.
    var expectedPlanFingerprint: String?
    var launchedAt: Date
}

/// Pure rules for chaining the connection preflight in front of an executed two-Mac start.
enum AppConnectionPreflightChain {
    /// Only an executed two-Mac (ssh) run needs the preflight; local runs and dry runs skip it.
    static func requiresPreflight(execute: Bool, settings: NativeAppShellExecutionSettings) -> Bool {
        execute && settings.effectiveRequirePreflight
    }

    /// Starts the supervisor only for exit status 0 with a fresh PASS report; otherwise names why it must not start.
    static func decide(
        exitCode: Int32,
        report: MacToMacConnectionEstablishmentReport?,
        freshness: AppConnectionPreflightFreshness,
        stderrTail: String,
        stderrPath: String
    ) -> AppConnectionPreflightDecision {
        guard exitCode == 0 else {
            return .blocked(failureMessage(exitCode: exitCode, stderrTail: stderrTail, stderrPath: stderrPath))
        }
        guard let report else {
            return .blocked("Connection preflight finished but its report could not be read.\nFull log: \(stderrPath)")
        }
        if let staleReason = staleReason(report, freshness: freshness) {
            return .blocked("Connection preflight report is not from this start (\(staleReason)); "
                + "the run was not started.\nFull log: \(stderrPath)")
        }
        guard report.verdict == .pass else {
            return .blocked(blockedMessage(report))
        }
        return .startSupervisor
    }

    /// Why `report` cannot be this launch's result, or nil when it names the current plan and was captured after
    /// launch. `capturedAt` has whole-second precision, so the launch second itself still counts.
    static func staleReason(
        _ report: MacToMacConnectionEstablishmentReport,
        freshness: AppConnectionPreflightFreshness
    ) -> String? {
        guard let expected = freshness.expectedPlanFingerprint else {
            return "the current plan could not be read"
        }
        guard report.planFingerprint == expected else {
            return "it was made for a different plan"
        }
        guard let captured = ISO8601DateFormatter().date(from: report.capturedAt),
              captured.timeIntervalSince1970 >= freshness.launchedAt.timeIntervalSince1970.rounded(.down) else {
            return "it was captured before this preflight started"
        }
        return nil
    }

    /// Fingerprint of the plan at `planPath`, or nil when it cannot be read and validated.
    static func planFingerprint(atPath planPath: String) -> String? {
        guard let plan = try? DirectPeerTwoPeerRunPlanReport.readValidated(fromPath: planPath) else {
            return nil
        }
        return DirectPeerTwoPeerPreflightBinding.fingerprint(for: plan)
    }

    /// Deletes a report left by an earlier preflight so a run that writes nothing cannot reuse it.
    static func removeStaleReport(atPath path: String, fileManager: FileManager = .default) throws {
        guard fileManager.fileExists(atPath: path) else {
            return
        }
        try fileManager.removeItem(atPath: path)
    }

    private static func blockedMessage(_ report: MacToMacConnectionEstablishmentReport) -> String {
        var message = "Connection preflight did not pass (\(report.verdict.rawValue)); the run was not started."
        if report.blockers.isEmpty {
            message += "\n\(report.notes)"
        } else {
            message += "\nBlockers:\n" + report.blockers.map { "- \($0)" }.joined(separator: "\n")
        }
        return message
    }

    private static func failureMessage(exitCode: Int32, stderrTail: String, stderrPath: String) -> String {
        var message = "Connection preflight failed (exit status \(exitCode)); the run was not started."
        let lines = AppRunFailureMessage.lastLines(of: stderrTail)
        if !lines.isEmpty {
            message += " Last stderr lines:\n" + lines.joined(separator: "\n")
        }
        return message + "\nFull log: \(stderrPath)"
    }
}

@MainActor
extension AppExecutionController {
    /// Builds the preflight command for an executed two-Mac Direct Mac peer start; nil when no preflight applies.
    func connectionPreflightArguments(
        operatorSurface: NativeAppShellOperatorPrototypeState,
        execute: Bool
    ) throws -> [String]? {
        guard case .directMacPeer = operatorSurface.sessionMode.appExecutionRoute,
              AppConnectionPreflightChain.requiresPreflight(execute: execute, settings: settings) else {
            return nil
        }
        let executablePath = try AppExecutablePathResolver.verifiedPath(
            operatorSurface.directPeerCommandFields.executablePath
        )
        return try operatorSurface.localDirectPeerCommandHandoff(
            executablePath: executablePath,
            planPath: settings.planPath,
            preflightReportPath: settings.connectionPreflightReportPath
        ).command.arguments
    }

    /// Runs the preflight process; Stop terminates it, and the supervisor launches only from its passing result.
    func runConnectionPreflight(arguments: [String], request: AppLaunchRequest, execute: Bool) throws {
        archiveCurrentEvidenceForNextRun()
        lastCommand = arguments
        startedAt = ISO8601DateFormatter().string(from: Date())
        lastExitCode = nil
        lastRunWasDryRun = false
        resetValidationResult()
        lastError = nil
        errorLog = []
        lastExternalConnectorReport = nil
        lastLatencyMetrics = nil
        lastCaptureReport = nil
        stopWasRequested = false
        try prepareLogFiles()
        try AppConnectionPreflightChain.removeStaleReport(atPath: settings.connectionPreflightReportPath)
        let freshness = AppConnectionPreflightFreshness(
            expectedPlanFingerprint: AppConnectionPreflightChain.planFingerprint(atPath: settings.planPath),
            launchedAt: Date()
        )
        let managedProcess = try startManagedProcess(arguments: arguments) { [weak self] finished in
            Task { @MainActor in
                self?.finishConnectionPreflight(finished, request: request, execute: execute, freshness: freshness)
            }
        }
        process = managedProcess
        status = "Connection preflight running."
        phase = .preflightRunning
    }

    func finishConnectionPreflight(
        _ finished: ManagedProcess,
        request: AppLaunchRequest,
        execute: Bool,
        freshness: AppConnectionPreflightFreshness
    ) {
        guard process === finished else {
            return
        }
        finished.closeOutputHandles()
        process = nil
        lastExitCode = Int(finished.terminationStatus)
        guard !stopWasRequested else {
            status = "Stop requested."
            phase = .stopRequested
            return
        }
        let decision = AppConnectionPreflightChain.decide(
            exitCode: finished.terminationStatus,
            report: try? MacToMacConnectionEstablishmentReport.readValidated(
                fromPath: settings.connectionPreflightReportPath
            ),
            freshness: freshness,
            stderrTail: AppRunFailureMessage.stderrTail(atPath: stderrPath),
            stderrPath: stderrPath
        )
        switch decision {
        case .startSupervisor:
            launchSupervisorAfterPreflight(request: request, execute: execute)
        case .blocked(let message):
            status = "Connection preflight did not pass."
            phase = .failedToStart
            finishReport()
            recordError(message)
        }
    }

    private func launchSupervisorAfterPreflight(request: AppLaunchRequest, execute: Bool) {
        do {
            try launchProcess(
                arguments: request.arguments,
                execute: execute,
                runningStatus: request.runningStatus,
                dryRunStatus: request.dryRunStatus
            )
        } catch {
            status = "Run failed to start."
            phase = .failedToStart
            finishReport()
            recordError(AppRunFailureMessage.describe(error))
        }
    }
}
