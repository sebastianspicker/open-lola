import Foundation
import OpenLolaContracts

public enum NativeAppShellExecutionPaths {
    public static let installedCLIPlaceholder = "<installed-open-lola-cli>"

    public static func defaultRunDirectory() -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("OpenLoLa", isDirectory: true)
            .appendingPathComponent("MacToMac", isDirectory: true)
            .path
    }

    public static func defaultPlanPath() -> String {
        URL(fileURLWithPath: defaultRunDirectory(), isDirectory: true)
            .appendingPathComponent("plan.json")
            .path
    }

    public static func defaultSupervisorReportPath() -> String {
        URL(fileURLWithPath: defaultRunDirectory(), isDirectory: true)
            .appendingPathComponent("supervisor.json")
            .path
    }
}

public enum NativeAppShellExecutionValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case invalidSupervisorExecutable(String)
    case sshModeMissingTarget(String)
    case passWithoutSuccessfulExit
    case passWithoutValidatedReport
}

public struct NativeAppShellExecutionSettings: Codable, Equatable, Sendable {
    public var planPath: String
    public var supervisorReportPath: String
    public var executionMode: DirectPeerTwoPeerRunExecutionMode
    public var execute: Bool
    public var requirePreflight: Bool
    public var readinessDelayMilliseconds: Int
    public var macASSH: String
    public var macBSSH: String
    public var macAWorkingDirectory: String
    public var macBWorkingDirectory: String
    public var sshExecutable: String
    public var scpExecutable: String

    public init(
        planPath: String = NativeAppShellExecutionPaths.defaultPlanPath(),
        supervisorReportPath: String = NativeAppShellExecutionPaths.defaultSupervisorReportPath(),
        executionMode: DirectPeerTwoPeerRunExecutionMode = .local,
        execute: Bool = false,
        requirePreflight: Bool = true,
        readinessDelayMilliseconds: Int = 300,
        macASSH: String = "mac-a.local",
        macBSSH: String = "mac-b.local",
        macAWorkingDirectory: String = "",
        macBWorkingDirectory: String = "",
        sshExecutable: String = "/usr/bin/ssh",
        scpExecutable: String = "/usr/bin/scp"
    ) {
        self.planPath = planPath
        self.supervisorReportPath = supervisorReportPath
        self.executionMode = executionMode
        self.execute = execute
        self.requirePreflight = requirePreflight
        self.readinessDelayMilliseconds = readinessDelayMilliseconds
        self.macASSH = macASSH
        self.macBSSH = macBSSH
        self.macAWorkingDirectory = macAWorkingDirectory
        self.macBWorkingDirectory = macBWorkingDirectory
        self.sshExecutable = sshExecutable
        self.scpExecutable = scpExecutable
    }

    public func validate() throws {
        try requireNativeAppExecutionNonEmpty(planPath, "planPath")
        try requireNativeAppExecutionNonEmpty(supervisorReportPath, "supervisorReportPath")
        try requireNativeAppExecutionPositive(readinessDelayMilliseconds, "readinessDelayMilliseconds")
        if executionMode == .ssh {
            try requireNativeAppExecutionNonEmpty(macASSH, "macASSH")
            try requireNativeAppExecutionNonEmpty(macBSSH, "macBSSH")
            try requireNativeAppExecutionNonEmpty(sshExecutable, "sshExecutable")
            try requireNativeAppExecutionNonEmpty(scpExecutable, "scpExecutable")
        }
    }

    public func supervisorArguments(executablePath: String) throws -> [String] {
        try validate()
        try validateSupervisorExecutablePath(executablePath)
        var arguments = [
            executablePath,
            "direct-p2p-two-peer-local-run",
            "--plan", planPath,
            "--output", supervisorReportPath,
            "--execute", execute ? "true" : "false",
            "--execution-mode", executionMode.rawValue,
            "--readiness-delay-ms", "\(readinessDelayMilliseconds)",
            "--require-preflight", requirePreflight ? "true" : "false",
        ]
        if executionMode == .local {
            arguments += ["--executable", executablePath]
        }
        if executionMode == .ssh {
            arguments += [
                "--mac-a-ssh", macASSH,
                "--mac-b-ssh", macBSSH,
                "--ssh-executable", sshExecutable,
                "--scp-executable", scpExecutable,
            ]
            if !macAWorkingDirectory.isEmpty {
                arguments += ["--mac-a-workdir", macAWorkingDirectory]
            }
            if !macBWorkingDirectory.isEmpty {
                arguments += ["--mac-b-workdir", macBWorkingDirectory]
            }
        }
        return arguments
    }

    public func validatorArguments(executablePath: String) throws -> [String] {
        try validate()
        try validateSupervisorExecutablePath(executablePath)
        return [
            executablePath,
            "validate-direct-p2p-two-peer-local-run-report",
            supervisorReportPath,
        ]
    }
}

private func validateSupervisorExecutablePath(_ executablePath: String) throws {
    try requireNativeAppExecutionNonEmpty(executablePath, "executablePath")
    guard URL(fileURLWithPath: executablePath).lastPathComponent == "open-lola" else {
        throw NativeAppShellExecutionValidationError.invalidSupervisorExecutable(executablePath)
    }
}

public struct NativeAppShellExecutionReport: Codable, Equatable, Sendable {
    public var id: String
    public var command: [String]
    public var startedAt: String
    public var finishedAt: String?
    public var exitCode: Int?
    public var stdoutPath: String
    public var stderrPath: String
    public var stopRequested: Bool
    public var validatorCommand: [String]
    public var validationExitCode: Int?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String = "native-app-shell-execution",
        command: [String],
        startedAt: String,
        finishedAt: String? = nil,
        exitCode: Int? = nil,
        stdoutPath: String,
        stderrPath: String,
        stopRequested: Bool = false,
        validatorCommand: [String] = [],
        validationExitCode: Int? = nil,
        verdict: MeasurementVerdict = .partial,
        notes: String
    ) {
        self.id = id
        self.command = command
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.exitCode = exitCode
        self.stdoutPath = stdoutPath
        self.stderrPath = stderrPath
        self.stopRequested = stopRequested
        self.validatorCommand = validatorCommand
        self.validationExitCode = validationExitCode
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try requireNativeAppExecutionNonEmpty(id, "id")
        guard !command.isEmpty else {
            throw NativeAppShellExecutionValidationError.emptyField("command")
        }
        try requireNativeAppExecutionNonEmpty(startedAt, "startedAt")
        try requireNativeAppExecutionNonEmpty(stdoutPath, "stdoutPath")
        try requireNativeAppExecutionNonEmpty(stderrPath, "stderrPath")
        try requireNativeAppExecutionNonEmpty(notes, "notes")
        if verdict == .pass {
            guard exitCode == 0 else {
                throw NativeAppShellExecutionValidationError.passWithoutSuccessfulExit
            }
            guard validationExitCode == 0 else {
                throw NativeAppShellExecutionValidationError.passWithoutValidatedReport
            }
        }
    }
}

private func requireNativeAppExecutionNonEmpty(_ value: String, _ field: String) throws {
    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw NativeAppShellExecutionValidationError.emptyField(field)
    }
}

private func requireNativeAppExecutionPositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw NativeAppShellExecutionValidationError.nonPositiveField(field)
    }
}
