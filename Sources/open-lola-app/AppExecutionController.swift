// Coordinates AppExecutionController application state, keeping UI actions and long-running execution in one observable boundary.
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

    @ObservationIgnored var process: ManagedProcess?
    @ObservationIgnored var startedAt: String?
    @ObservationIgnored var wasRunning = false
    @ObservationIgnored var stopWasRequested = false
    @ObservationIgnored var executionKind: AppExecutionKind = .directMacPeer
    @ObservationIgnored var externalConnectorReportPath: String?

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
        return "Last validated \(lastValidationFinishedAt): \(lastValidationResult.displayTitle)"
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

    func archiveCurrentEvidenceForNextRun() {
        guard let snapshot = AppRunEvidenceSnapshot.make(from: self) else {
            return
        }
        previousRunEvidence.insert(snapshot, at: 0)
        if previousRunEvidence.count > AppRunEvidenceSnapshot.ringLimit {
            previousRunEvidence.removeLast(previousRunEvidence.count - AppRunEvidenceSnapshot.ringLimit)
        }
    }

}
