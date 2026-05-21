import Foundation
import AppKit
import OpenLolaCore

enum AppExecutionDefaultLogURLs {
    static func make() -> (stdout: URL, stderr: URL, previousStdout: URL, previousStderr: URL) {
        let baseDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "open-lola-app"
        let logDirectory = baseDirectory
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("logs", isDirectory: true)
        return (
            stdout: logDirectory.appendingPathComponent("execution-stdout.log"),
            stderr: logDirectory.appendingPathComponent("execution-stderr.log"),
            previousStdout: logDirectory.appendingPathComponent("previous-execution-stdout.log"),
            previousStderr: logDirectory.appendingPathComponent("previous-execution-stderr.log")
        )
    }
}

enum AppExecutionLogSnapshot {
    @discardableResult
    static func preserveCurrentLogIfPresent(sourcePath: String, previousPath: String) throws -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sourcePath) else {
            return false
        }
        let attributes = try fileManager.attributesOfItem(atPath: sourcePath)
        guard let size = attributes[.size] as? NSNumber, size.int64Value > 0 else {
            return false
        }
        let previousURL = URL(fileURLWithPath: previousPath)
        try fileManager.createDirectory(
            at: previousURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: previousPath) {
            try fileManager.removeItem(at: previousURL)
        }
        try fileManager.copyItem(at: URL(fileURLWithPath: sourcePath), to: previousURL)
        return true
    }
}

struct AppRunEvidenceSnapshot: Identifiable, Equatable {
    static let ringLimit = 3

    let id: UUID
    let capturedAt: String
    let status: String
    let phase: AppExecutionPhase
    let commandLine: String
    let exitCode: Int?
    let validationExitCode: Int?
    let validationResult: AppValidationResult
    let lastError: String?
    let errorCount: Int
    let latencySummary: String
    let captureSummary: String
    let externalConnectorSummary: String
    let stdoutPath: String
    let stderrPath: String

    @MainActor
    static func make(from controller: AppExecutionController) -> AppRunEvidenceSnapshot? {
        let commandLine = AppCommandPreview.shellLine(controller.lastCommand)
        let latencySummary = controller.lastLatencyMetrics.map { metrics in
            metrics.isPartial
                ? "partial latency evidence"
                : metrics.audioLatencyMs.map { "\($0) ms audio latency" } ?? "latency evidence available"
        } ?? "none"
        let captureSummary = controller.lastCaptureReport == nil ? "none" : "capture report available"
        let externalSummary = controller.lastExternalConnectorReport?.verdict.rawValue ?? "none"
        let hasEvidence = !controller.lastCommand.isEmpty
            || controller.lastExitCode != nil
            || controller.lastValidationExitCode != nil
            || controller.lastReport != nil
            || controller.lastExternalConnectorReport != nil
            || controller.lastLatencyMetrics != nil
            || controller.lastCaptureReport != nil
            || controller.lastError != nil
            || !controller.errorLog.isEmpty
        guard hasEvidence else {
            return nil
        }
        return AppRunEvidenceSnapshot(
            id: UUID(),
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            status: controller.status,
            phase: controller.phase,
            commandLine: commandLine,
            exitCode: controller.lastExitCode,
            validationExitCode: controller.lastValidationExitCode,
            validationResult: controller.lastValidationResult,
            lastError: controller.lastError,
            errorCount: controller.errorLog.count,
            latencySummary: latencySummary,
            captureSummary: captureSummary,
            externalConnectorSummary: externalSummary,
            stdoutPath: controller.previousStdoutPath,
            stderrPath: controller.previousStderrPath
        )
    }
}

enum AppExecutionLogFileOpener {
    static func canOpen(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    @MainActor
    static func open(_ path: String) -> String? {
        guard canOpen(path) else {
            return "Log file missing: \(path)"
        }
        guard NSWorkspace.shared.open(URL(fileURLWithPath: path)) else {
            return "Failed to open log file: \(path)"
        }
        return nil
    }
}

enum AppExecutionReportLoader {
    static func externalConnectorReport(
        executionKind: AppExecutionKind,
        path: String?
    ) -> (report: ExternalConnectorSessionReport?, errorMessage: String?) {
        guard executionKind == .windowsLoLa, let path else {
            return (nil, nil)
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (nil, nil)
        }
        do {
            return (try ExternalConnectorSessionReport.readValidated(from: url), nil)
        } catch {
            return (nil, "External connector report unavailable: \(error)")
        }
    }

    static func captureReport(
        executionKind: AppExecutionKind,
        supervisorReportPath: String
    ) -> (report: LoLaCompatibilityCaptureReport?, errorMessage: String?) {
        guard AppRuntimeEvidenceScope.allowsDirectPeerCaptureEvidence(executionKind: executionKind) else {
            return (nil, nil)
        }
        let url = URL(fileURLWithPath: supervisorReportPath)
            .deletingLastPathComponent()
            .appendingPathComponent("lola-capture-report.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (nil, nil)
        }
        do {
            return (try LoLaCompatibilityCaptureReport.readValidated(from: url), nil)
        } catch {
            return (nil, "Capture report unavailable: \(error)")
        }
    }
}

enum AppExecutionReportAssembler {
    static func make(
        command: [String],
        startedAt: String,
        exitCode: Int?,
        stdoutPath: String,
        stderrPath: String,
        stopRequested: Bool,
        validatorCommand: [String],
        validationExitCode: Int?,
        verdict: MeasurementVerdict,
        notes: String
    ) -> NativeAppShellExecutionReport {
        NativeAppShellExecutionReport(
            command: command,
            startedAt: startedAt,
            finishedAt: ISO8601DateFormatter().string(from: Date()),
            exitCode: exitCode,
            stdoutPath: stdoutPath,
            stderrPath: stderrPath,
            stopRequested: stopRequested,
            validatorCommand: validatorCommand,
            validationExitCode: validationExitCode,
            verdict: verdict,
            notes: notes
        )
    }
}
