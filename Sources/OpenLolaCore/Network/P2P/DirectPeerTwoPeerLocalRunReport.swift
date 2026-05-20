import Foundation

public enum DirectPeerTwoPeerLocalRunError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyList(String)
    case invalidExitCode(String)
    case passRequiresExecution
    case passRequiresTwoPeerReports
    case passRequiresAggregateReport
    case passRequiresCollectedReports
    case passRequiresReceiveProofs
    case passRequiresReadableArtifact(String)
    case passRequiresValidArtifact(String)
    case passRequiresMatchingArtifact(String)
}

public enum DirectPeerTwoPeerRunExecutionMode: String, Codable, Equatable, Sendable {
    case local
    case ssh
}

public enum DirectPeerTwoPeerPreflightSeverity: String, Codable, Equatable, Sendable {
    case pass
    case warning
    case fail
}

public struct DirectPeerTwoPeerPreflightCheck: Codable, Equatable, Sendable {
    public var id: String
    public var severity: DirectPeerTwoPeerPreflightSeverity
    public var passed: Bool
    public var message: String

    public init(
        id: String,
        severity: DirectPeerTwoPeerPreflightSeverity,
        passed: Bool,
        message: String
    ) {
        self.id = id
        self.severity = severity
        self.passed = passed
        self.message = message
    }
}

public struct DirectPeerTwoPeerLocalRunProcessResult: Codable, Equatable, Sendable {
    public var peerID: String
    public var role: DirectPeerSessionManualRole
    public var reportPath: String
    public var command: [String]
    public var stdoutPath: String?
    public var stderrPath: String?
    public var exitCode: Int?
    public var executionMode: DirectPeerTwoPeerRunExecutionMode
    public var remoteTarget: String?
    public var collectedReportPath: String?
    public var collectedReceiveProofPath: String?
    public var startedAt: String?
    public var finishedAt: String?

    public init(
        peerID: String,
        role: DirectPeerSessionManualRole,
        reportPath: String,
        command: [String],
        stdoutPath: String? = nil,
        stderrPath: String? = nil,
        exitCode: Int? = nil,
        executionMode: DirectPeerTwoPeerRunExecutionMode = .local,
        remoteTarget: String? = nil,
        collectedReportPath: String? = nil,
        collectedReceiveProofPath: String? = nil,
        startedAt: String? = nil,
        finishedAt: String? = nil
    ) {
        self.peerID = peerID
        self.role = role
        self.reportPath = reportPath
        self.command = command
        self.stdoutPath = stdoutPath
        self.stderrPath = stderrPath
        self.exitCode = exitCode
        self.executionMode = executionMode
        self.remoteTarget = remoteTarget
        self.collectedReportPath = collectedReportPath
        self.collectedReceiveProofPath = collectedReceiveProofPath
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public struct DirectPeerTwoPeerLocalRunReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var planID: String
    public var runDirectory: String
    public var executed: Bool
    public var processResults: [DirectPeerTwoPeerLocalRunProcessResult]
    public var aggregateCommand: [String]
    public var aggregateReportPath: String?
    public var aggregateExecuted: Bool
    public var executionMode: DirectPeerTwoPeerRunExecutionMode
    public var preflightChecks: [DirectPeerTwoPeerPreflightCheck]
    public var evidenceGates: [String]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        planID: String,
        runDirectory: String,
        executed: Bool,
        processResults: [DirectPeerTwoPeerLocalRunProcessResult],
        aggregateCommand: [String],
        aggregateReportPath: String? = nil,
        aggregateExecuted: Bool = false,
        executionMode: DirectPeerTwoPeerRunExecutionMode = .local,
        preflightChecks: [DirectPeerTwoPeerPreflightCheck] = [],
        evidenceGates: [String],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.planID = planID
        self.runDirectory = runDirectory
        self.executed = executed
        self.processResults = processResults
        self.aggregateCommand = aggregateCommand
        self.aggregateReportPath = aggregateReportPath
        self.aggregateExecuted = aggregateExecuted
        self.executionMode = executionMode
        self.preflightChecks = preflightChecks
        self.evidenceGates = evidenceGates
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try requireNonEmpty(id, "id")
        try requireNonEmpty(capturedAt, "capturedAt")
        try requireNonEmpty(planID, "planID")
        try requireNonEmpty(runDirectory, "runDirectory")
        guard processResults.count == 2 else {
            throw DirectPeerTwoPeerLocalRunError.emptyList("processResults")
        }
        for result in processResults {
            try requireNonEmpty(result.peerID, "processResults.peerID")
            try requireNonEmpty(result.reportPath, "processResults.reportPath")
            guard !result.command.isEmpty else {
                throw DirectPeerTwoPeerLocalRunError.emptyList("processResults.command")
            }
            if let exitCode = result.exitCode, exitCode < 0 {
                throw DirectPeerTwoPeerLocalRunError.invalidExitCode(result.peerID)
            }
            if result.executionMode == .ssh {
                try requireNonEmpty(result.remoteTarget ?? "", "processResults.remoteTarget")
            }
        }
        guard !aggregateCommand.isEmpty else {
            throw DirectPeerTwoPeerLocalRunError.emptyList("aggregateCommand")
        }
        guard !preflightChecks.isEmpty else {
            throw DirectPeerTwoPeerLocalRunError.emptyList("preflightChecks")
        }
        guard !evidenceGates.isEmpty else {
            throw DirectPeerTwoPeerLocalRunError.emptyList("evidenceGates")
        }
        try requireNonEmpty(notes, "notes")
        if verdict == .pass {
            guard executed else {
                throw DirectPeerTwoPeerLocalRunError.passRequiresExecution
            }
            guard processResults.allSatisfy({ $0.exitCode == 0 }) else {
                throw DirectPeerTwoPeerLocalRunError.passRequiresTwoPeerReports
            }
            guard aggregateExecuted, aggregateReportPath?.isEmpty == false else {
                throw DirectPeerTwoPeerLocalRunError.passRequiresAggregateReport
            }
            guard processResults.allSatisfy({ $0.collectedReportPath?.isEmpty == false }) else {
                throw DirectPeerTwoPeerLocalRunError.passRequiresCollectedReports
            }
            guard processResults.allSatisfy({ $0.collectedReceiveProofPath?.isEmpty == false }) else {
                throw DirectPeerTwoPeerLocalRunError.passRequiresReceiveProofs
            }
        }
    }

    public func validateReferencedArtifacts() throws {
        guard verdict == .pass else {
            return
        }
        guard let aggregateReportPath, !aggregateReportPath.isEmpty else {
            throw DirectPeerTwoPeerLocalRunError.passRequiresAggregateReport
        }
        let aggregate = try readValidatedReport(
            DirectPeerTwoPeerPrototypeReport.self,
            path: aggregateReportPath,
            field: "aggregateReportPath"
        )
        guard aggregate.verdict == .pass else {
            throw DirectPeerTwoPeerLocalRunError.passRequiresAggregateReport
        }

        let initiator = try passProcessResult(role: .initiator)
        let responder = try passProcessResult(role: .responder)
        let initiatorArtifacts = try readPassArtifacts(from: initiator)
        let responderArtifacts = try readPassArtifacts(from: responder)
        let rebuilt: DirectPeerTwoPeerPrototypeReport
        do {
            rebuilt = try DirectPeerTwoPeerPrototypeReportBuilder.makeReport(
                peerAReportPath: initiatorArtifacts.reportPath,
                peerAReport: initiatorArtifacts.report,
                peerARXProofPath: initiatorArtifacts.receiveProofPath,
                peerARXProof: initiatorArtifacts.receiveProof,
                peerBReportPath: responderArtifacts.reportPath,
                peerBReport: responderArtifacts.report,
                peerBRXProofPath: responderArtifacts.receiveProofPath,
                peerBRXProof: responderArtifacts.receiveProof
            )
        } catch {
            throw DirectPeerTwoPeerLocalRunError.passRequiresMatchingArtifact("processResults.receiveProof")
        }
        guard rebuilt.verdict == .pass else {
            throw DirectPeerTwoPeerLocalRunError.passRequiresAggregateReport
        }
        guard aggregate.peerEvidence == rebuilt.peerEvidence else {
            throw DirectPeerTwoPeerLocalRunError.passRequiresMatchingArtifact("aggregateReportPath.peerEvidence")
        }
    }

    private func requireNonEmpty(_ value: String, _ field: String) throws {
        if value.isEmpty {
            throw DirectPeerTwoPeerLocalRunError.emptyField(field)
        }
    }

    private func passProcessResult(role: DirectPeerSessionManualRole) throws -> DirectPeerTwoPeerLocalRunProcessResult {
        guard let result = processResults.first(where: { $0.role == role }) else {
            throw DirectPeerTwoPeerLocalRunError.passRequiresTwoPeerReports
        }
        return result
    }

    private func readPassArtifacts(
        from result: DirectPeerTwoPeerLocalRunProcessResult
    ) throws -> (
        reportPath: String,
        report: DirectPeerSessionReport,
        receiveProofPath: String,
        receiveProof: DirectPeerSessionReceiveProofArtifact
    ) {
        guard let reportPath = result.collectedReportPath, !reportPath.isEmpty else {
            throw DirectPeerTwoPeerLocalRunError.passRequiresCollectedReports
        }
        guard let receiveProofPath = result.collectedReceiveProofPath, !receiveProofPath.isEmpty else {
            throw DirectPeerTwoPeerLocalRunError.passRequiresReceiveProofs
        }
        let report = try readValidatedReport(
            DirectPeerSessionReport.self,
            path: reportPath,
            field: "processResults.\(result.peerID).collectedReportPath"
        )
        guard report.verdict == .pass else {
            throw DirectPeerTwoPeerLocalRunError.passRequiresValidArtifact(
                "processResults.\(result.peerID).collectedReportPath"
            )
        }
        return (
            reportPath: reportPath,
            report: report,
            receiveProofPath: receiveProofPath,
            receiveProof: try readReceiveProof(
                path: receiveProofPath,
                field: "processResults.\(result.peerID).collectedReceiveProofPath"
            )
        )
    }

    private func readValidatedReport<Report: ReportValidatingArtifact>(
        _ type: Report.Type,
        path: String,
        field: String
    ) throws -> Report {
        let url = artifactURL(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DirectPeerTwoPeerLocalRunError.passRequiresReadableArtifact(field)
        }
        do {
            return try type.readValidated(from: url)
        } catch {
            throw DirectPeerTwoPeerLocalRunError.passRequiresValidArtifact(field)
        }
    }

    private func readReceiveProof(
        path: String,
        field: String
    ) throws -> DirectPeerSessionReceiveProofArtifact {
        let url = artifactURL(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DirectPeerTwoPeerLocalRunError.passRequiresReadableArtifact(field)
        }
        do {
            return try JSONDecoder().decode(
                DirectPeerSessionReceiveProofArtifact.self,
                from: BoundedFileReader.data(at: url)
            )
        } catch {
            throw DirectPeerTwoPeerLocalRunError.passRequiresValidArtifact(field)
        }
    }

    private func artifactURL(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: runDirectory, isDirectory: true)
            .appendingPathComponent(path)
    }
}

public enum DirectPeerTwoPeerLocalRunReportBuilder {
    public static func makeReport(
        plan: DirectPeerTwoPeerRunPlanReport,
        executed: Bool,
        processResults: [DirectPeerTwoPeerLocalRunProcessResult]? = nil,
        aggregateReportPath: String? = nil,
        aggregateExecuted: Bool = false,
        aggregateFailureReason: String? = nil,
        executionMode: DirectPeerTwoPeerRunExecutionMode = .local,
        remoteTargets: [String: String] = [:]
    ) throws -> DirectPeerTwoPeerLocalRunReport {
        try plan.validate()
        let results = processResults ?? plan.commands.map {
            DirectPeerTwoPeerLocalRunProcessResult(
                peerID: $0.peerID,
                role: $0.role,
                reportPath: $0.outputReportPath,
                command: $0.arguments,
                executionMode: executionMode,
                remoteTarget: remoteTargets[$0.peerID]
            )
        }
        let aggregateCommand = aggregateCommand(for: plan)
        let preflightChecks = DirectPeerTwoPeerRunPreflight.makeChecks(
            plan: plan,
            executionMode: executionMode,
            remoteTargets: remoteTargets
        )
        let hasPassEvidence = aggregateExecuted
            && aggregateReportPath?.isEmpty == false
            && results.allSatisfy { $0.collectedReportPath?.isEmpty == false }
            && results.allSatisfy { $0.collectedReceiveProofPath?.isEmpty == false }
        let verdict: MeasurementVerdict = executed
            && results.allSatisfy { $0.exitCode == 0 }
            && hasPassEvidence ? .pass : .partial
        let notes = localRunNotes(
            executed: executed,
            executionMode: executionMode,
            aggregateFailureReason: aggregateFailureReason
        )
        let report = DirectPeerTwoPeerLocalRunReport(
            id: "m06-direct-p2p-two-peer-local-run",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            planID: plan.id,
            runDirectory: plan.runDirectory,
            executed: executed,
            processResults: results,
            aggregateCommand: aggregateCommand,
            aggregateReportPath: aggregateReportPath,
            aggregateExecuted: aggregateExecuted,
            executionMode: executionMode,
            preflightChecks: preflightChecks,
            evidenceGates: plan.evidenceGates + [
                "Supervisor records role order, launch mode, stdout/stderr logs, report collection paths, and aggregate report path.",
                "Executed supervisor runs with required preflight must load a passing mac-to-mac connection preflight report before launching media.",
                "SSH execution is an advanced fallback and requires explicit operator selection, a reason, and --mac-a-ssh/--mac-b-ssh targets.",
                "Physical Mac-to-Mac PASS still requires measured reports from both Macs.",
            ],
            verdict: verdict,
            notes: notes
        )
        try report.validate()
        try report.validateReferencedArtifacts()
        return report
    }

    private static func localRunNotes(
        executed: Bool,
        executionMode: DirectPeerTwoPeerRunExecutionMode,
        aggregateFailureReason: String?
    ) -> String {
        let base = executed
            ? "\(executionMode.rawValue) two-peer supervisor launched the planned child processes, recorded exit codes, and attempted aggregate report generation."
            : "Dry-run \(executionMode.rawValue) supervisor artifact; rerun with --execute true to launch child processes."
        guard executed,
              let aggregateFailureReason,
              !aggregateFailureReason.isEmpty else {
            return base
        }
        return "\(base) Aggregate report generation failed: \(aggregateFailureReason)"
    }

    private static func aggregateCommand(for plan: DirectPeerTwoPeerRunPlanReport) -> [String] {
        var command = [".build/debug/open-lola", "direct-p2p-two-peer-prototype-report"]
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

public enum DirectPeerTwoPeerRunPreflight {
    public static func makeChecks(
        plan: DirectPeerTwoPeerRunPlanReport,
        executionMode: DirectPeerTwoPeerRunExecutionMode,
        remoteTargets: [String: String]
    ) -> [DirectPeerTwoPeerPreflightCheck] {
        let arguments = Dictionary(uniqueKeysWithValues: plan.commands.map { ($0.peerID, $0.arguments) })
        var checks: [DirectPeerTwoPeerPreflightCheck] = [
            check(
                id: "command-count",
                passed: plan.commands.count == 2,
                message: "plan contains exactly two peer commands"
            ),
            check(
                id: "role-order",
                passed: plan.commands.map(\.role) == [.responder, .initiator],
                message: "responder is launched before initiator"
            ),
        ]
        for command in plan.commands {
            let hasHosts = argumentValue("--local-host", in: command.arguments) != nil
                && argumentValue("--remote-host", in: command.arguments) != nil
            checks.append(check(id: "\(command.peerID)-hosts", passed: hasHosts, message: "peer command carries local and remote hosts"))
            checks.append(check(
                id: "\(command.peerID)-ports",
                passed: portsArePresentAndDistinct(command.arguments),
                message: "peer command carries distinct control, audio, and video ports"
            ))
            let localHost = argumentValue("--local-host", in: command.arguments) ?? ""
            checks.append(DirectPeerTwoPeerPreflightCheck(
                id: "\(command.peerID)-physical-route",
                severity: isLoopback(localHost) ? .warning : .pass,
                passed: !isLoopback(localHost),
                message: isLoopback(localHost)
                    ? "local host is loopback; useful for dry-runs only, not physical Mac-to-Mac evidence"
                    : "local host is non-loopback"
            ))
            if executionMode == .ssh {
                let target = remoteTargets[command.peerID] ?? ""
                checks.append(check(
                    id: "\(command.peerID)-ssh-target",
                    passed: !target.isEmpty,
                    message: "SSH target is configured for \(command.peerID)"
                ))
            }
        }
        checks.append(check(
            id: "cross-hosts",
            passed: crossReferencesMatch(arguments: arguments),
            message: "each peer remote host points at the other peer local host"
        ))
        return checks
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
