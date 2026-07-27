// Builds native-shell execution paths, validates run settings, and records command outcomes.
import Foundation
import OpenLolaContracts

/// Builds default run, plan, supervisor-report, and preflight-report paths for native execution.
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

    public static func defaultConnectionPreflightReportPath() -> String {
        URL(fileURLWithPath: defaultRunDirectory(), isDirectory: true)
            .appendingPathComponent("connection-preflight.json")
            .path
    }
}

/// Defines failures reported when native app shell execution validation error cannot continue.
public enum NativeAppShellExecutionValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case nonPositiveField(String)
    case invalidSupervisorExecutable(String)
    case sshModeMissingTarget(String)
    case preflightReportMissing(String)
    case sshFallbackRequiresExplicitSelection
    case sshFallbackMissingReason
    case passWithoutSuccessfulExit
    case passWithoutValidatedReport
}

/// Defines the validated fields for native app shell execution settings.
public struct NativeAppShellExecutionSettings: Codable, Equatable, Sendable {
    public struct Paths: Equatable, Sendable {
        public let plan: String
        public let supervisorReport: String
        public let connectionPreflightReport: String

        public init(plan: String, supervisorReport: String, connectionPreflightReport: String) {
            self.plan = plan
            self.supervisorReport = supervisorReport
            self.connectionPreflightReport = connectionPreflightReport
        }
    }

    public struct Behavior: Equatable, Sendable {
        public let executionMode: DirectPeerTwoPeerRunExecutionMode
        public let execute: Bool
        public let requirePreflight: Bool
        public let sshFallbackExplicitlySelected: Bool
        public let sshFallbackReason: String
        public let readinessDelayMilliseconds: Int

        public init(
            executionMode: DirectPeerTwoPeerRunExecutionMode,
            execute: Bool,
            requirePreflight: Bool,
            sshFallbackExplicitlySelected: Bool,
            sshFallbackReason: String,
            readinessDelayMilliseconds: Int
        ) {
            self.executionMode = executionMode
            self.execute = execute
            self.requirePreflight = requirePreflight
            self.sshFallbackExplicitlySelected = sshFallbackExplicitlySelected
            self.sshFallbackReason = sshFallbackReason
            self.readinessDelayMilliseconds = readinessDelayMilliseconds
        }
    }

    public struct SSH: Equatable, Sendable {
        public let macAHost: String
        public let macBHost: String
        public let macAWorkingDirectory: String
        public let macBWorkingDirectory: String
        public let executable: String
        public let scpExecutable: String

        public init(
            macAHost: String,
            macBHost: String,
            macAWorkingDirectory: String,
            macBWorkingDirectory: String,
            executable: String,
            scpExecutable: String
        ) {
            self.macAHost = macAHost
            self.macBHost = macBHost
            self.macAWorkingDirectory = macAWorkingDirectory
            self.macBWorkingDirectory = macBWorkingDirectory
            self.executable = executable
            self.scpExecutable = scpExecutable
        }
    }

    public var planPath: String
    public var supervisorReportPath: String
    public var executionMode: DirectPeerTwoPeerRunExecutionMode
    public var execute: Bool
    public var requirePreflight: Bool
    public var connectionPreflightReportPath: String
    public var sshFallbackExplicitlySelected: Bool
    public var sshFallbackReason: String
    public var readinessDelayMilliseconds: Int
    public var macASSH: String
    public var macBSSH: String
    public var macAWorkingDirectory: String
    public var macBWorkingDirectory: String
    public var sshExecutable: String
    public var scpExecutable: String

    public init() {
        planPath = NativeAppShellExecutionPaths.defaultPlanPath()
        supervisorReportPath = NativeAppShellExecutionPaths.defaultSupervisorReportPath()
        executionMode = .local
        execute = false
        requirePreflight = true
        connectionPreflightReportPath = NativeAppShellExecutionPaths.defaultConnectionPreflightReportPath()
        sshFallbackExplicitlySelected = false
        sshFallbackReason = ""
        readinessDelayMilliseconds = 300
        macASSH = "mac-a.local"
        macBSSH = "mac-b.local"
        macAWorkingDirectory = ""
        macBWorkingDirectory = ""
        sshExecutable = "/usr/bin/ssh"
        scpExecutable = "/usr/bin/scp"
    }

    public init(paths: Paths, behavior: Behavior, ssh: SSH) {
        planPath = paths.plan
        supervisorReportPath = paths.supervisorReport
        executionMode = behavior.executionMode
        execute = behavior.execute
        requirePreflight = behavior.requirePreflight
        connectionPreflightReportPath = paths.connectionPreflightReport
        sshFallbackExplicitlySelected = behavior.sshFallbackExplicitlySelected
        sshFallbackReason = behavior.sshFallbackReason
        readinessDelayMilliseconds = behavior.readinessDelayMilliseconds
        macASSH = ssh.macAHost
        macBSSH = ssh.macBHost
        macAWorkingDirectory = ssh.macAWorkingDirectory
        macBWorkingDirectory = ssh.macBWorkingDirectory
        sshExecutable = ssh.executable
        scpExecutable = ssh.scpExecutable
    }

    public func validate() throws {
        try requireNativeAppExecutionNonEmpty(planPath, "planPath")
        try requireNativeAppExecutionNonEmpty(supervisorReportPath, "supervisorReportPath")
        try requireNativeAppExecutionPositive(readinessDelayMilliseconds, "readinessDelayMilliseconds")
        if requirePreflight {
            guard !connectionPreflightReportPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NativeAppShellExecutionValidationError.preflightReportMissing("connectionPreflightReportPath")
            }
        }
        if executionMode == .ssh {
            guard sshFallbackExplicitlySelected else {
                throw NativeAppShellExecutionValidationError.sshFallbackRequiresExplicitSelection
            }
            guard !sshFallbackReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NativeAppShellExecutionValidationError.sshFallbackMissingReason
            }
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
            "--require-preflight", requirePreflight ? "true" : "false"
        ]
        if requirePreflight {
            arguments += ["--connection-preflight-report", connectionPreflightReportPath]
        }
        if executionMode == .local {
            arguments += ["--executable", executablePath]
        }
        if executionMode == .ssh {
            arguments += sshSupervisorArguments()
        }
        return arguments
    }

    private func sshSupervisorArguments() -> [String] {
        var arguments = [
            "--mac-a-ssh", macASSH,
            "--mac-b-ssh", macBSSH,
            "--ssh-executable", sshExecutable,
            "--scp-executable", scpExecutable,
            "--ssh-fallback-explicit", sshFallbackExplicitlySelected ? "true" : "false",
            "--ssh-fallback-reason", sshFallbackReason
        ]
        if !macAWorkingDirectory.isEmpty {
            arguments += ["--mac-a-workdir", macAWorkingDirectory]
        }
        if !macBWorkingDirectory.isEmpty {
            arguments += ["--mac-b-workdir", macBWorkingDirectory]
        }
        return arguments
    }

    public func validatorArguments(executablePath: String) throws -> [String] {
        try validate()
        try validateSupervisorExecutablePath(executablePath)
        return [
            executablePath,
            "validate-direct-p2p-two-peer-local-run-report",
            supervisorReportPath
        ]
    }
}

private func validateSupervisorExecutablePath(_ executablePath: String) throws {
    try requireNativeAppExecutionNonEmpty(executablePath, "executablePath")
    guard URL(fileURLWithPath: executablePath).lastPathComponent == "open-lola" else {
        throw NativeAppShellExecutionValidationError.invalidSupervisorExecutable(executablePath)
    }
}

/// Records the evidence and outcome for native app shell execution report.
public struct NativeAppShellExecutionReport: Codable, Equatable, Sendable {
    public struct Lifecycle: Equatable, Sendable {
        public let id: String
        public let command: [String]
        public let startedAt: String
        public let finishedAt: String?
        public let exitCode: Int?
        public let stopRequested: Bool

        public init(
            id: String = "native-app-shell-execution",
            command: [String],
            startedAt: String,
            finishedAt: String? = nil,
            exitCode: Int? = nil,
            stopRequested: Bool = false
        ) {
            self.id = id
            self.command = command
            self.startedAt = startedAt
            self.finishedAt = finishedAt
            self.exitCode = exitCode
            self.stopRequested = stopRequested
        }
    }

    public struct Artifacts: Equatable, Sendable {
        public let stdoutPath: String
        public let stderrPath: String

        public init(stdoutPath: String, stderrPath: String) {
            self.stdoutPath = stdoutPath
            self.stderrPath = stderrPath
        }
    }

    public struct Validation: Equatable, Sendable {
        public let command: [String]
        public let exitCode: Int?

        public init(command: [String] = [], exitCode: Int? = nil) {
            self.command = command
            self.exitCode = exitCode
        }
    }

    public struct Outcome: Equatable, Sendable {
        public let verdict: MeasurementVerdict
        public let notes: String

        public init(verdict: MeasurementVerdict = .partial, notes: String) {
            self.verdict = verdict
            self.notes = notes
        }
    }

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

    public init(lifecycle: Lifecycle, artifacts: Artifacts, validation: Validation = .init(), outcome: Outcome) {
        id = lifecycle.id
        command = lifecycle.command
        startedAt = lifecycle.startedAt
        finishedAt = lifecycle.finishedAt
        exitCode = lifecycle.exitCode
        stdoutPath = artifacts.stdoutPath
        stderrPath = artifacts.stderrPath
        stopRequested = lifecycle.stopRequested
        validatorCommand = validation.command
        validationExitCode = validation.exitCode
        verdict = outcome.verdict
        notes = outcome.notes
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
