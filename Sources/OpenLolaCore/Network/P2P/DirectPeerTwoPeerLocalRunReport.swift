// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Enumerates failures that callers must handle when working with direct peer sessions.
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

/// Selects local-process or remote-execution supervision for a two-peer run.
public enum DirectPeerTwoPeerRunExecutionMode: String, Codable, Equatable, Sendable {
    case local
    case ssh
}

/// Assigns operator-facing severity to a two-peer preflight result.
public enum DirectPeerTwoPeerPreflightSeverity: String, Codable, Equatable, Sendable {
    case pass
    case warning
    case fail
}

/// Represents DirectPeerTwoPeerPreflightCheck values used by direct peer sessions.
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

/// Represents the DirectPeerTwoPeerLocalRunProcessResult produced by direct peer sessions without exposing its execution state.
public struct DirectPeerTwoPeerLocalRunProcessResult: Codable, Equatable, Sendable {
    public struct Identity: Equatable, Sendable {
        public var peerID: String
        public var role: DirectPeerSessionManualRole
        public var reportPath: String

        public init(peerID: String, role: DirectPeerSessionManualRole, reportPath: String) {
            self.peerID = peerID
            self.role = role
            self.reportPath = reportPath
        }
    }

    public struct Execution: Equatable, Sendable {
        public var command: [String]
        public var stdoutPath: String?
        public var stderrPath: String?
        public var exitCode: Int?
        public var mode: DirectPeerTwoPeerRunExecutionMode

        public init(
            command: [String],
            stdoutPath: String? = nil,
            stderrPath: String? = nil,
            exitCode: Int? = nil,
            mode: DirectPeerTwoPeerRunExecutionMode = .local
        ) {
            self.command = command
            self.stdoutPath = stdoutPath
            self.stderrPath = stderrPath
            self.exitCode = exitCode
            self.mode = mode
        }
    }

    public struct Collection: Equatable, Sendable {
        public var remoteTarget: String?
        public var reportPath: String?
        public var receiveProofPath: String?
        public var startedAt: String?
        public var finishedAt: String?

        public init(
            remoteTarget: String? = nil,
            reportPath: String? = nil,
            receiveProofPath: String? = nil,
            startedAt: String? = nil,
            finishedAt: String? = nil
        ) {
            self.remoteTarget = remoteTarget
            self.reportPath = reportPath
            self.receiveProofPath = receiveProofPath
            self.startedAt = startedAt
            self.finishedAt = finishedAt
        }
    }
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

    public init(identity: Identity, execution: Execution, collection: Collection = .init()) {
        self.peerID = identity.peerID
        self.role = identity.role
        self.reportPath = identity.reportPath
        self.command = execution.command
        self.stdoutPath = execution.stdoutPath
        self.stderrPath = execution.stderrPath
        self.exitCode = execution.exitCode
        self.executionMode = execution.mode
        self.remoteTarget = collection.remoteTarget
        self.collectedReportPath = collection.reportPath
        self.collectedReceiveProofPath = collection.receiveProofPath
        self.startedAt = collection.startedAt
        self.finishedAt = collection.finishedAt
    }
}

/// Captures DirectPeerTwoPeerLocalRunReport evidence in a stable form for validation and serialized reporting.
public struct DirectPeerTwoPeerLocalRunReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Metadata: Equatable, Sendable {
        public var id: String
        public var capturedAt: String
        public var planID: String
        public var runDirectory: String

        public init(id: String, capturedAt: String, planID: String, runDirectory: String) {
            self.id = id
            self.capturedAt = capturedAt
            self.planID = planID
            self.runDirectory = runDirectory
        }
    }

    public struct ProcessExecution: Equatable, Sendable {
        public var executed: Bool
        public var processResults: [DirectPeerTwoPeerLocalRunProcessResult]
        public var mode: DirectPeerTwoPeerRunExecutionMode

        public init(
            executed: Bool,
            processResults: [DirectPeerTwoPeerLocalRunProcessResult],
            mode: DirectPeerTwoPeerRunExecutionMode = .local
        ) {
            self.executed = executed
            self.processResults = processResults
            self.mode = mode
        }
    }

    public struct Aggregation: Equatable, Sendable {
        public var command: [String]
        public var reportPath: String?
        public var executed: Bool

        public init(command: [String], reportPath: String? = nil, executed: Bool = false) {
            self.command = command
            self.reportPath = reportPath
            self.executed = executed
        }
    }

    public struct Evidence: Equatable, Sendable {
        public var preflightChecks: [DirectPeerTwoPeerPreflightCheck]
        public var gates: [String]
        public var verdict: MeasurementVerdict
        public var notes: String

        public init(
            preflightChecks: [DirectPeerTwoPeerPreflightCheck] = [],
            gates: [String],
            verdict: MeasurementVerdict,
            notes: String
        ) {
            self.preflightChecks = preflightChecks
            self.gates = gates
            self.verdict = verdict
            self.notes = notes
        }
    }

    public struct Input: Equatable, Sendable {
        public var metadata: Metadata
        public var processExecution: ProcessExecution
        public var aggregation: Aggregation
        public var evidence: Evidence

        public init(
            metadata: Metadata,
            processExecution: ProcessExecution,
            aggregation: Aggregation,
            evidence: Evidence
        ) {
            self.metadata = metadata
            self.processExecution = processExecution
            self.aggregation = aggregation
            self.evidence = evidence
        }
    }

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

    public init(_ input: Input) {
        self.id = input.metadata.id
        self.capturedAt = input.metadata.capturedAt
        self.planID = input.metadata.planID
        self.runDirectory = input.metadata.runDirectory
        self.executed = input.processExecution.executed
        self.processResults = input.processExecution.processResults
        self.aggregateCommand = input.aggregation.command
        self.aggregateReportPath = input.aggregation.reportPath
        self.aggregateExecuted = input.aggregation.executed
        self.executionMode = input.processExecution.mode
        self.preflightChecks = input.evidence.preflightChecks
        self.evidenceGates = input.evidence.gates
        self.verdict = input.evidence.verdict
        self.notes = input.evidence.notes
    }

    public func validate() throws {
        try requireNonEmpty(id, "id")
        try requireNonEmpty(capturedAt, "capturedAt")
        try requireNonEmpty(planID, "planID")
        try requireNonEmpty(runDirectory, "runDirectory")
        try validateProcessResults()
        try validateRequiredCollections()
        try requireNonEmpty(notes, "notes")
        try validatePassVerdict()
    }

    private func validateProcessResults() throws {
        guard processResults.count == 2 else {
            throw DirectPeerTwoPeerLocalRunError.emptyList("processResults")
        }
        for result in processResults {
            try validateProcessResult(result)
        }
    }

    private func validateProcessResult(_ result: DirectPeerTwoPeerLocalRunProcessResult) throws {
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

    private func validateRequiredCollections() throws {
        guard !aggregateCommand.isEmpty else {
            throw DirectPeerTwoPeerLocalRunError.emptyList("aggregateCommand")
        }
        guard !preflightChecks.isEmpty else {
            throw DirectPeerTwoPeerLocalRunError.emptyList("preflightChecks")
        }
        guard !evidenceGates.isEmpty else {
            throw DirectPeerTwoPeerLocalRunError.emptyList("evidenceGates")
        }
    }

    private func validatePassVerdict() throws {
        guard verdict == .pass else {
            return
        }
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

    public func validateReferencedArtifacts() throws {
        guard verdict == .pass else {
            return
        }
        let aggregate = try readPassAggregateReport()
        let rebuilt = try rebuiltPassAggregateReportFromChildArtifacts()
        try validateAggregateReport(aggregate, matches: rebuilt)
    }

    private func readPassAggregateReport() throws -> DirectPeerTwoPeerPrototypeReport {
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
        return aggregate
    }

    private func rebuiltPassAggregateReportFromChildArtifacts() throws -> DirectPeerTwoPeerPrototypeReport {
        let initiator = try passProcessResult(role: .initiator)
        let responder = try passProcessResult(role: .responder)
        let initiatorArtifacts = try readPassArtifacts(from: initiator)
        let responderArtifacts = try readPassArtifacts(from: responder)
        do {
            return try DirectPeerTwoPeerPrototypeReportBuilder.makeReport(
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
    }

    private func validateAggregateReport(
        _ aggregate: DirectPeerTwoPeerPrototypeReport,
        matches rebuilt: DirectPeerTwoPeerPrototypeReport
    ) throws {
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
    ) throws -> DirectPeerTwoPeerPassArtifacts {
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
        return DirectPeerTwoPeerPassArtifacts(
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

private struct DirectPeerTwoPeerPassArtifacts {
    var reportPath: String
    var report: DirectPeerSessionReport
    var receiveProofPath: String
    var receiveProof: DirectPeerSessionReceiveProofArtifact
}
