// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Configures DirectPeerTwoPeerLocalRunReportRequest so callers supply explicit inputs before starting direct peer sessions.
public struct DirectPeerTwoPeerLocalRunReportRequest: Sendable {
    public var plan: DirectPeerTwoPeerRunPlanReport
    public var executed: Bool
    public var processResults: [DirectPeerTwoPeerLocalRunProcessResult]?
    public var aggregateReportPath: String?
    public var aggregateExecuted: Bool
    public var aggregateFailureReason: String?
    public var executionMode: DirectPeerTwoPeerRunExecutionMode
    public var remoteTargets: [String: String]

    public init(
        plan: DirectPeerTwoPeerRunPlanReport,
        executed: Bool
    ) {
        self.plan = plan
        self.executed = executed
        self.processResults = nil
        self.aggregateReportPath = nil
        self.aggregateExecuted = false
        self.aggregateFailureReason = nil
        self.executionMode = .local
        self.remoteTargets = [:]
    }
}

/// Builds and validates the two-peer supervisor report from its plan, process results, preflight checks, and collected artifacts.
public enum DirectPeerTwoPeerLocalRunReportBuilder {
    public static func makeReport(
        request: DirectPeerTwoPeerLocalRunReportRequest
    ) throws -> DirectPeerTwoPeerLocalRunReport {
        try request.plan.validate()
        let results = request.processResults ?? defaultProcessResults(for: request)
        let report = DirectPeerTwoPeerLocalRunReport(
            .init(
                metadata: .init(
                    id: "m06-direct-p2p-two-peer-local-run",
                    capturedAt: ISO8601DateFormatter().string(from: Date()),
                    planID: request.plan.id,
                    runDirectory: request.plan.runDirectory
                ),
                processExecution: .init(
                    executed: request.executed,
                    processResults: results,
                    mode: request.executionMode
                ),
                aggregation: .init(
                    command: aggregateCommand(for: request.plan),
                    reportPath: request.aggregateReportPath,
                    executed: request.aggregateExecuted
                ),
                evidence: .init(
                    preflightChecks: DirectPeerTwoPeerRunPreflight.makeChecks(
                        plan: request.plan,
                        executionMode: request.executionMode,
                        remoteTargets: request.remoteTargets
                    ),
                    gates: evidenceGates(for: request.plan),
                    verdict: verdict(for: request, results: results),
                    notes: localRunNotes(
                        executed: request.executed,
                        executionMode: request.executionMode,
                        aggregateFailureReason: request.aggregateFailureReason
                    )
                )
            )
        )
        try report.validate()
        try report.validateReferencedArtifacts()
        return report
    }

    private static func defaultProcessResults(
        for request: DirectPeerTwoPeerLocalRunReportRequest
    ) -> [DirectPeerTwoPeerLocalRunProcessResult] {
        request.plan.commands.map {
            DirectPeerTwoPeerLocalRunProcessResult(
                identity: .init(
                    peerID: $0.peerID,
                    role: $0.role,
                    reportPath: $0.outputReportPath
                ),
                execution: .init(command: $0.arguments, mode: request.executionMode),
                collection: .init(remoteTarget: request.remoteTargets[$0.peerID])
            )
        }
    }

    private static func verdict(
        for request: DirectPeerTwoPeerLocalRunReportRequest,
        results: [DirectPeerTwoPeerLocalRunProcessResult]
    ) -> MeasurementVerdict {
        let hasPassEvidence = request.aggregateExecuted
            && request.aggregateReportPath?.isEmpty == false
            && results.allSatisfy { $0.collectedReportPath?.isEmpty == false }
            && results.allSatisfy { $0.collectedReceiveProofPath?.isEmpty == false }
        return request.executed && results.allSatisfy { $0.exitCode == 0 } && hasPassEvidence
            ? .pass
            : .partial
    }

    private static func evidenceGates(for plan: DirectPeerTwoPeerRunPlanReport) -> [String] {
        plan.evidenceGates + [
            "Supervisor records role order, launch mode, stdout/stderr logs, "
                + "report collection paths, and aggregate report path.",
            "Executed supervisor runs with required preflight must load a passing "
                + "mac-to-mac connection preflight report before launching media.",
            "SSH execution is an advanced fallback and requires explicit operator "
                + "selection, a reason, and --mac-a-ssh/--mac-b-ssh targets.",
            "Physical Mac-to-Mac PASS still requires measured reports from both Macs."
        ]
    }

    private static func localRunNotes(
        executed: Bool,
        executionMode: DirectPeerTwoPeerRunExecutionMode,
        aggregateFailureReason: String?
    ) -> String {
        let base = executed
            ? "\(executionMode.rawValue) two-peer supervisor launched the planned child "
                + "processes, recorded exit codes, and attempted aggregate report generation."
            : "Dry-run \(executionMode.rawValue) supervisor artifact; rerun with "
                + "--execute true to launch child processes."
        guard executed,
              let aggregateFailureReason,
              !aggregateFailureReason.isEmpty else {
            return base
        }
        return "\(base) Aggregate report generation failed: \(aggregateFailureReason)"
    }

    private static func aggregateCommand(for plan: DirectPeerTwoPeerRunPlanReport) -> [String] {
        var command = [".build/debug/open-lola", "direct-p2p-two-peer-report"]
        if let first = plan.reportReferences.first {
            command += ["--peer-a-report", first.path]
            command += ["--peer-a-rx-proof", rxProofPath(for: first.path)]
        }
        if plan.reportReferences.count > 1 {
            let second = plan.reportReferences[1]
            command += ["--peer-b-report", second.path]
            command += ["--peer-b-rx-proof", rxProofPath(for: second.path)]
        }
        command += ["--output", "\(plan.runDirectory)/m06-direct-p2p-two-peer-prototype.json"]
        return command
    }

    private static func rxProofPath(for reportPath: String) -> String {
        if reportPath.hasSuffix(".json") {
            return String(reportPath.dropLast(5)) + "-rx-proof.json"
        }
        return reportPath + "-rx-proof.json"
    }
}

/// Derives deterministic launch checks for peer count, role order, hosts, ports, routes, and optional SSH targets.
public enum DirectPeerTwoPeerRunPreflight {
    public static func makeChecks(
        plan: DirectPeerTwoPeerRunPlanReport,
        executionMode: DirectPeerTwoPeerRunExecutionMode,
        remoteTargets: [String: String]
    ) -> [DirectPeerTwoPeerPreflightCheck] {
        var preflightChecks = baseChecks(for: plan)
        preflightChecks += plan.commands.flatMap {
            checks(for: $0, executionMode: executionMode, remoteTargets: remoteTargets)
        }
        preflightChecks.append(check(
            id: "cross-hosts",
            passed: crossReferencesMatch(arguments: peerArguments(for: plan)),
            message: "each peer remote host points at the other peer local host"
        ))
        return preflightChecks
    }

    private static func baseChecks(
        for plan: DirectPeerTwoPeerRunPlanReport
    ) -> [DirectPeerTwoPeerPreflightCheck] {
        [
            check(
                id: "command-count",
                passed: plan.commands.count == 2,
                message: "plan contains exactly two peer commands"
            ),
            check(
                id: "role-order",
                passed: plan.commands.map(\.role) == [.responder, .initiator],
                message: "responder is launched before initiator"
            )
        ]
    }

    private static func checks(
        for command: DirectPeerTwoPeerRunCommand,
        executionMode: DirectPeerTwoPeerRunExecutionMode,
        remoteTargets: [String: String]
    ) -> [DirectPeerTwoPeerPreflightCheck] {
        var checks = [
            hostCheck(for: command),
            check(
                id: "\(command.peerID)-ports",
                passed: portsArePresentAndDistinct(command.arguments),
                message: "peer command carries distinct control, audio, and video ports"
            ),
            physicalRouteCheck(for: command)
        ]
        if let sshCheck = sshTargetCheck(
            for: command,
            executionMode: executionMode,
            remoteTargets: remoteTargets
        ) {
            checks.append(sshCheck)
        }
        return checks
    }

    private static func hostCheck(
        for command: DirectPeerTwoPeerRunCommand
    ) -> DirectPeerTwoPeerPreflightCheck {
        let hasHosts = argumentValue("--local-host", in: command.arguments) != nil
            && argumentValue("--remote-host", in: command.arguments) != nil
        return check(
            id: "\(command.peerID)-hosts",
            passed: hasHosts,
            message: "peer command carries local and remote hosts"
        )
    }

    private static func physicalRouteCheck(
        for command: DirectPeerTwoPeerRunCommand
    ) -> DirectPeerTwoPeerPreflightCheck {
        let localHost = argumentValue("--local-host", in: command.arguments) ?? ""
        let loopback = isLoopback(localHost)
        return DirectPeerTwoPeerPreflightCheck(
            id: "\(command.peerID)-physical-route",
            severity: loopback ? .warning : .pass,
            passed: !loopback,
            message: loopback
                ? "local host is loopback; useful for dry-runs only, not physical Mac-to-Mac evidence"
                : "local host is non-loopback"
        )
    }

    private static func sshTargetCheck(
        for command: DirectPeerTwoPeerRunCommand,
        executionMode: DirectPeerTwoPeerRunExecutionMode,
        remoteTargets: [String: String]
    ) -> DirectPeerTwoPeerPreflightCheck? {
        guard executionMode == .ssh else {
            return nil
        }
        let target = remoteTargets[command.peerID] ?? ""
        return check(
            id: "\(command.peerID)-ssh-target",
            passed: !target.isEmpty,
            message: "SSH target is configured for \(command.peerID)"
        )
    }

    private static func peerArguments(
        for plan: DirectPeerTwoPeerRunPlanReport
    ) -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: plan.commands.map { ($0.peerID, $0.arguments) })
    }

    private static func check(id: String, passed: Bool, message: String) -> DirectPeerTwoPeerPreflightCheck {
        DirectPeerTwoPeerPreflightCheck(id: id, severity: passed ? .pass : .fail, passed: passed, message: message)
    }

    private static func portsArePresentAndDistinct(_ arguments: [String]) -> Bool {
        guard let localHost = argumentValue("--local-host", in: arguments),
              let remoteHost = argumentValue("--remote-host", in: arguments),
              let controlPort = argumentValue("--control-port", in: arguments).flatMap(UInt16.init),
              let remoteControlPort = argumentValue("--remote-control-port", in: arguments).flatMap(UInt16.init),
              let audioPort = argumentValue("--audio-port", in: arguments).flatMap(UInt16.init),
              let videoPort = argumentValue("--video-port", in: arguments).flatMap(UInt16.init),
              let metricsPort = argumentValue("--metrics-port", in: arguments).flatMap(UInt16.init) else {
            return false
        }
        do {
            try DirectPeerPortSet(
                controlPort: controlPort,
                remoteControlPort: remoteControlPort,
                audioPort: audioPort,
                videoPort: videoPort,
                metricsPort: metricsPort
            ).validate(localHost: localHost, remoteHost: remoteHost)
            return true
        } catch {
            return false
        }
    }

    private static func crossReferencesMatch(arguments: [String: [String]]) -> Bool {
        guard arguments.count == 2 else {
            return false
        }
        let values = Array(arguments.values)
        let firstLocal = argumentValue("--local-host", in: values[0])
        let firstRemote = argumentValue("--remote-host", in: values[0])
        let secondLocal = argumentValue("--local-host", in: values[1])
        let secondRemote = argumentValue("--remote-host", in: values[1])
        return firstLocal == secondRemote && secondLocal == firstRemote
    }

    private static func isLoopback(_ host: String) -> Bool {
        host == "127.0.0.1" || host == "::1" || host == "localhost"
    }

    private static func argumentValue(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }
}
