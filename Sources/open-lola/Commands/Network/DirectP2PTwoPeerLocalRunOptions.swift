// Maps DirectP2PTwoPeerLocalRunOptions CLI input into core calls, keeping argument normalization outside domain services.
import Foundation
import OpenLolaCore

struct DirectP2PTwoPeerLocalRunOptions {
    var planPath: String
    var outputPath: String
    var execute: Bool
    var executablePath: String?
    var executionMode: DirectPeerTwoPeerRunExecutionMode
    var macASSH: String?
    var macBSSH: String?
    var macAExecutable: String?
    var macBExecutable: String?
    var macAWorkingDirectory: String?
    var macBWorkingDirectory: String?
    var sshExecutable: String
    var scpExecutable: String
    var sshFallbackExplicit: Bool
    var sshFallbackReason: String?
    var readinessDelayMilliseconds: Int
    var requirePreflight: Bool
    var connectionPreflightReportPath: String?

    static func parse(_ arguments: [String]) throws -> DirectP2PTwoPeerLocalRunOptions {
        let values = try directP2PTwoPeerLocalRunValues(arguments)
        let options = DirectP2PTwoPeerLocalRunOptions(
            planPath: try directP2PTwoPeerLocalRunRequired("--plan", values),
            outputPath: try directP2PTwoPeerLocalRunRequired("--output", values),
            execute: try directP2PTwoPeerLocalRunBool(values["--execute"]),
            executablePath: values["--executable"],
            executionMode: try directP2PTwoPeerExecutionMode(values["--execution-mode"]),
            macASSH: values["--mac-a-ssh"],
            macBSSH: values["--mac-b-ssh"],
            macAExecutable: values["--mac-a-executable"],
            macBExecutable: values["--mac-b-executable"],
            macAWorkingDirectory: values["--mac-a-workdir"],
            macBWorkingDirectory: values["--mac-b-workdir"],
            sshExecutable: values["--ssh-executable"] ?? "/usr/bin/ssh",
            scpExecutable: values["--scp-executable"] ?? "/usr/bin/scp",
            sshFallbackExplicit: try directP2PTwoPeerLocalRunBool(values["--ssh-fallback-explicit"]),
            sshFallbackReason: values["--ssh-fallback-reason"],
            readinessDelayMilliseconds: try directP2PTwoPeerLocalRunPositiveInt(
                values["--readiness-delay-ms"],
                defaultValue: 300,
                label: "--readiness-delay-ms"
            ),
            requirePreflight: try directP2PTwoPeerLocalRunBool(values["--require-preflight"]),
            connectionPreflightReportPath: values["--connection-preflight-report"]
        )
        try options.validate()
        return options
    }

    func validate() throws {
        if requirePreflight {
            guard connectionPreflightReportPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw CommandError.invalidArgument("missing --connection-preflight-report")
            }
        }
        guard executionMode == .ssh else {
            return
        }
        guard sshFallbackExplicit else {
            throw CommandError.invalidArgument("ssh execution requires --ssh-fallback-explicit true")
        }
        guard sshFallbackReason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw CommandError.invalidArgument("ssh execution requires --ssh-fallback-reason")
        }
        guard macASSH?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw CommandError.invalidArgument("ssh execution requires --mac-a-ssh")
        }
        guard macBSSH?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw CommandError.invalidArgument("ssh execution requires --mac-b-ssh")
        }
    }

    func sshTarget(for command: DirectPeerTwoPeerRunCommand) -> String? {
        switch command.role {
        case .initiator:
            return macASSH
        case .responder:
            return macBSSH
        }
    }

    func remoteTargets(for plan: DirectPeerTwoPeerRunPlanReport) -> [String: String] {
        Dictionary(uniqueKeysWithValues: plan.commands.compactMap { command in
            sshTarget(for: command).map { (command.peerID, $0) }
        })
    }

    func executablePath(for command: DirectPeerTwoPeerRunCommand) -> String? {
        switch command.role {
        case .initiator:
            return macAExecutable ?? executablePath
        case .responder:
            return macBExecutable ?? executablePath
        }
    }

    func remoteWorkingDirectory(for command: DirectPeerTwoPeerRunCommand) -> String? {
        switch command.role {
        case .initiator:
            return macAWorkingDirectory
        case .responder:
            return macBWorkingDirectory
        }
    }
}

private func directP2PTwoPeerLocalRunValues(_ arguments: [String]) throws -> [String: String] {
    let allowed = Set([
        "--plan",
        "--output",
        "--execute",
        "--executable",
        "--execution-mode",
        "--mac-a-ssh",
        "--mac-b-ssh",
        "--mac-a-executable",
        "--mac-b-executable",
        "--mac-a-workdir",
        "--mac-b-workdir",
        "--ssh-executable",
        "--scp-executable",
        "--ssh-fallback-explicit",
        "--ssh-fallback-reason",
        "--readiness-delay-ms",
        "--require-preflight",
        "--connection-preflight-report"
    ])
    return try KeyValueArgumentParser.parseValues(
        arguments,
        allowed: allowed,
        allowsDashPrefixedValues: false,
        unknown: { CommandError.invalidArgument("unknown \($0)") },
        duplicate: { CommandError.invalidArgument("duplicate \($0)") },
        missingValue: { CommandError.invalidArgument("missing value for \($0)") }
    )
}

private func directP2PTwoPeerLocalRunRequired(
    _ key: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[key], !value.isEmpty else {
        throw CommandError.invalidArgument("missing \(key)")
    }
    return value
}

private func directP2PTwoPeerLocalRunBool(_ value: String?) throws -> Bool {
    guard let value else {
        return false
    }
    switch value {
    case "true":
        return true
    case "false":
        return false
    default:
        throw CommandError.invalidArgument("invalid --execute")
    }
}

private func directP2PTwoPeerExecutionMode(_ value: String?) throws -> DirectPeerTwoPeerRunExecutionMode {
    guard let value else {
        return .local
    }
    guard let mode = DirectPeerTwoPeerRunExecutionMode(rawValue: value) else {
        throw CommandError.invalidArgument("invalid --execution-mode")
    }
    return mode
}

private func directP2PTwoPeerLocalRunPositiveInt(
    _ value: String?,
    defaultValue: Int,
    label: String
) throws -> Int {
    guard let value else {
        return defaultValue
    }
    guard let parsed = Int(value), parsed > 0 else {
        throw CommandError.invalidArgument("invalid \(label)")
    }
    return parsed
}
