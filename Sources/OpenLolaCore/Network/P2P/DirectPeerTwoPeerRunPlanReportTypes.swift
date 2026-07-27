// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

/// Represents DirectPeerTwoPeerRunCommand values used by direct peer sessions.
public struct DirectPeerTwoPeerRunCommand: Codable, Equatable, Sendable {
    public var peerID: String
    public var role: DirectPeerSessionManualRole
    public var outputReportPath: String
    public var arguments: [String]

    public init(
        peerID: String,
        role: DirectPeerSessionManualRole,
        outputReportPath: String,
        arguments: [String]
    ) {
        self.peerID = peerID
        self.role = role
        self.outputReportPath = outputReportPath
        self.arguments = arguments
    }
}

/// Represents DirectPeerTwoPeerRunReportReference values used by direct peer sessions.
public struct DirectPeerTwoPeerRunReportReference: Codable, Equatable, Sendable {
    public var peerID: String
    public var path: String
    public var schema: String

    public init(peerID: String, path: String, schema: String = "DirectPeerSessionReport") {
        self.peerID = peerID
        self.path = path
        self.schema = schema
    }
}

/// Captures DirectPeerTwoPeerRunPlanReport evidence in a stable form for validation and serialized reporting.
public struct DirectPeerTwoPeerRunPlanReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var runDirectory: String
    public var commands: [DirectPeerTwoPeerRunCommand]
    public var reportReferences: [DirectPeerTwoPeerRunReportReference]
    public var evidenceGates: [String]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        runDirectory: String,
        commands: [DirectPeerTwoPeerRunCommand],
        reportReferences: [DirectPeerTwoPeerRunReportReference],
        evidenceGates: [String],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.runDirectory = runDirectory
        self.commands = commands
        self.reportReferences = reportReferences
        self.evidenceGates = evidenceGates
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try requireDirectPeerTwoPeerNonEmpty(id, "id")
        try requireDirectPeerTwoPeerNonEmpty(capturedAt, "capturedAt")
        try requireDirectPeerTwoPeerNonEmpty(runDirectory, "runDirectory")
        guard commands.count == 2 else {
            throw DirectPeerTwoPeerRunPlanError.emptyList("commands")
        }
        for command in commands {
            try requireDirectPeerTwoPeerNonEmpty(command.peerID, "commands.peerID")
            try requireDirectPeerTwoPeerNonEmpty(command.outputReportPath, "commands.outputReportPath")
            guard !command.arguments.isEmpty else {
                throw DirectPeerTwoPeerRunPlanError.emptyList("commands.arguments")
            }
        }
        guard reportReferences.map(\.peerID) == commands.map(\.peerID),
              reportReferences.map(\.path) == commands.map(\.outputReportPath) else {
            throw DirectPeerTwoPeerRunPlanError.mismatchedReportReferences
        }
        for reference in reportReferences {
            try requireDirectPeerTwoPeerNonEmpty(reference.peerID, "reportReferences.peerID")
            try requireDirectPeerTwoPeerNonEmpty(reference.path, "reportReferences.path")
            try requireDirectPeerTwoPeerNonEmpty(reference.schema, "reportReferences.schema")
        }
        guard !evidenceGates.isEmpty else {
            throw DirectPeerTwoPeerRunPlanError.emptyList("evidenceGates")
        }
        try requireDirectPeerTwoPeerNonEmpty(notes, "notes")
        if verdict == .pass {
            throw DirectPeerTwoPeerRunPlanError.passRequiresMeasuredDirectPeerReports
        }
    }
}

/// Captures DirectPeerTwoPeerPrototypePeerEvidence evidence in a stable form for validation and serialized reporting.
public struct DirectPeerTwoPeerPrototypePeerEvidence: Codable, Equatable, Sendable {
    public var peerID: String
    public var reportPath: String
    public var reportID: String
    public var sessionID: String
    public var reportVerdict: MeasurementVerdict
    public var rxProofPath: String?
    public var rxProofArtifactID: String?
    public var packetsSent: Int
    public var packetsReceived: Int
    public var audioPacketsRouted: Int
    public var videoPacketsRouted: Int
    public var videoFramesReassembled: Int
    public var rawVideoReceiveEvidence: String?

    public init(
        peerID: String,
        reportPath: String,
        report: DirectPeerSessionReport,
        rxProofPath: String?,
        rxProofArtifact: DirectPeerSessionReceiveProofArtifact?
    ) {
        self.peerID = peerID
        self.reportPath = reportPath
        reportID = report.id
        sessionID = report.configuration.sessionID
        reportVerdict = report.verdict
        self.rxProofPath = rxProofPath
        rxProofArtifactID = rxProofArtifact?.id
        packetsSent = report.metrics.packetsSent
        packetsReceived = report.metrics.packetsReceived
        audioPacketsRouted = report.metrics.audioPacketsRouted
        videoPacketsRouted = report.metrics.videoPacketsRouted
        videoFramesReassembled = report.avRuntime?.runtimeMetrics.videoFramesReassembled ?? 0
        rawVideoReceiveEvidence = report.measuredEvidence?.rawVideoReceiveEvidence
    }
}

/// Captures DirectPeerTwoPeerPrototypeReport evidence in a stable form for validation and serialized reporting.
public struct DirectPeerTwoPeerPrototypeReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var peerEvidence: [DirectPeerTwoPeerPrototypePeerEvidence]
    public var evidenceGates: [String]
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        peerEvidence: [DirectPeerTwoPeerPrototypePeerEvidence],
        evidenceGates: [String],
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.peerEvidence = peerEvidence
        self.evidenceGates = evidenceGates
        self.verdict = verdict
        self.notes = notes
    }

    public func validate() throws {
        try requireDirectPeerTwoPeerNonEmpty(id, "id")
        try requireDirectPeerTwoPeerNonEmpty(capturedAt, "capturedAt")
        try validatePeerEvidence()
        try validateEvidenceGatesAndNotes()
        try validatePassEvidence()
    }

    private func validatePeerEvidence() throws {
        guard peerEvidence.count == 2 else {
            throw DirectPeerTwoPeerRunPlanError.emptyList("peerEvidence")
        }
        var peerIDs = Set<String>()
        for peer in peerEvidence {
            try requireDirectPeerTwoPeerNonEmpty(peer.peerID, "peerEvidence.peerID")
            try requireDirectPeerTwoPeerNonEmpty(peer.reportPath, "peerEvidence.reportPath")
            try requireDirectPeerTwoPeerNonEmpty(peer.reportID, "peerEvidence.reportID")
            try requireDirectPeerTwoPeerNonEmpty(peer.sessionID, "peerEvidence.sessionID")
            if !peerIDs.insert(peer.peerID).inserted {
                throw DirectPeerTwoPeerRunPlanError.duplicatePeerID(peer.peerID)
            }
            try validateCounters(peer)
        }
    }

    private func validateCounters(_ peer: DirectPeerTwoPeerPrototypePeerEvidence) throws {
        if peer.packetsSent < 0
            || peer.packetsReceived < 0
            || peer.audioPacketsRouted < 0
            || peer.videoPacketsRouted < 0
            || peer.videoFramesReassembled < 0 {
            throw DirectPeerTwoPeerRunPlanError.invalidPositiveInt("peerEvidence.counters")
        }
    }

    private func validateEvidenceGatesAndNotes() throws {
        guard !evidenceGates.isEmpty else {
            throw DirectPeerTwoPeerRunPlanError.emptyList("evidenceGates")
        }
        try requireDirectPeerTwoPeerNonEmpty(notes, "notes")
    }

    private func validatePassEvidence() throws {
        guard verdict == .pass else {
            return
        }
        guard peerEvidence.allSatisfy({ $0.reportVerdict == .pass }) else {
            throw DirectPeerTwoPeerRunPlanError.passRequiresTwoPassingReports
        }
        guard peerEvidence.allSatisfy({ $0.rxProofPath != nil && $0.rxProofArtifactID != nil }) else {
            throw DirectPeerTwoPeerRunPlanError.passRequiresTwoReceiveProofArtifacts
        }
        guard peerEvidence.allSatisfy({ $0.videoFramesReassembled > 0 && $0.rawVideoReceiveEvidence != nil }) else {
            throw DirectPeerTwoPeerRunPlanError.passRequiresTwoReceiveProofArtifacts
        }
    }
}

/// Aggregates two validated peer reports and their receive proofs into a prototype evidence verdict.
public enum DirectPeerTwoPeerPrototypeReportBuilder {
    public static func makeReport(
        peerAReportPath: String,
        peerAReport: DirectPeerSessionReport,
        peerARXProofPath: String? = nil,
        peerARXProof: DirectPeerSessionReceiveProofArtifact? = nil,
        peerBReportPath: String,
        peerBReport: DirectPeerSessionReport,
        peerBRXProofPath: String? = nil,
        peerBRXProof: DirectPeerSessionReceiveProofArtifact? = nil
    ) throws -> DirectPeerTwoPeerPrototypeReport {
        try peerAReport.validate()
        try peerBReport.validate()
        try validate(rxProof: peerARXProof, path: peerARXProofPath, report: peerAReport, label: "peer-a")
        try validate(rxProof: peerBRXProof, path: peerBRXProofPath, report: peerBReport, label: "peer-b")

        let peerEvidence = try makePeerEvidence(
            peerA: PrototypePeerEvidenceInput(
                reportPath: peerAReportPath,
                report: peerAReport,
                rxProofPath: peerARXProofPath,
                rxProof: peerARXProof
            ),
            peerB: PrototypePeerEvidenceInput(
                reportPath: peerBReportPath,
                report: peerBReport,
                rxProofPath: peerBRXProofPath,
                rxProof: peerBRXProof
            )
        )
        let verdict = prototypeVerdict(for: peerEvidence)
        let report = DirectPeerTwoPeerPrototypeReport(
            id: "m06-direct-p2p-two-peer-prototype",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            peerEvidence: peerEvidence,
            evidenceGates: prototypeEvidenceGates,
            verdict: verdict,
            notes: prototypeNotes(for: verdict)
        )
        try report.validate()
        return report
    }

    private static let prototypeEvidenceGates = [
        "Both DirectPeerSessionReport files must validate.",
        "PASS requires both subordinate reports to be PASS.",
        "PASS requires RX proof artifacts for both peers.",
        "PASS requires nonzero raw video receive evidence on both peers."
    ]

    private static func makePeerEvidence(
        peerA: PrototypePeerEvidenceInput,
        peerB: PrototypePeerEvidenceInput
    ) throws -> [DirectPeerTwoPeerPrototypePeerEvidence] {
        [
            try makePeerEvidence(peerA),
            try makePeerEvidence(peerB)
        ]
    }

    private static func makePeerEvidence(
        _ peer: PrototypePeerEvidenceInput
    ) throws -> DirectPeerTwoPeerPrototypePeerEvidence {
        DirectPeerTwoPeerPrototypePeerEvidence(
            peerID: try localPeerID(from: peer.report),
            reportPath: peer.reportPath,
            report: peer.report,
            rxProofPath: peer.rxProofPath,
            rxProofArtifact: peer.rxProof
        )
    }

    private static func prototypeVerdict(
        for peerEvidence: [DirectPeerTwoPeerPrototypePeerEvidence]
    ) -> MeasurementVerdict {
        peerEvidence.allSatisfy {
            $0.reportVerdict == .pass
                && $0.rxProofPath != nil
                && $0.rxProofArtifactID != nil
                && $0.videoFramesReassembled > 0
                && $0.rawVideoReceiveEvidence != nil
        } ? .pass : .partial
    }

    private static func prototypeNotes(for verdict: MeasurementVerdict) -> String {
        verdict == .pass
            ? "Two-peer prototype evidence is complete for source-level PASS promotion."
            : "Two-peer prototype remains PARTIAL until both peer reports PASS "
                + "and both RX proof artifacts are attached."
    }

    private static func validate(
        rxProof: DirectPeerSessionReceiveProofArtifact?,
        path: String?,
        report: DirectPeerSessionReport,
        label: String
    ) throws {
        guard let rxProof else {
            if path != nil {
                throw DirectPeerTwoPeerRunPlanError.mismatchedReceiveProof("\(label).missingArtifact")
            }
            return
        }
        guard path != nil else {
            throw DirectPeerTwoPeerRunPlanError.mismatchedReceiveProof("\(label).missingPath")
        }
        guard rxProof.reportID == report.id else {
            throw DirectPeerTwoPeerRunPlanError.mismatchedReceiveProof("\(label).reportID")
        }
        guard rxProof.sessionID == report.configuration.sessionID else {
            throw DirectPeerTwoPeerRunPlanError.mismatchedReceiveProof("\(label).sessionID")
        }
        guard rxProof.receiveProof == report.avRuntime?.receiveProof else {
            throw DirectPeerTwoPeerRunPlanError.mismatchedReceiveProof("\(label).receiveProof")
        }
    }

    private static func localPeerID(from report: DirectPeerSessionReport) throws -> String {
        guard let peerID = report.configuration.peers.first?.peerID else {
            throw DirectPeerTwoPeerRunPlanError.emptyList("report.configuration.peers")
        }
        return peerID
    }
}

private struct PrototypePeerEvidenceInput {
    var reportPath: String
    var report: DirectPeerSessionReport
    var rxProofPath: String?
    var rxProof: DirectPeerSessionReceiveProofArtifact?
}

private func requireDirectPeerTwoPeerNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw DirectPeerTwoPeerRunPlanError.emptyField(field)
    }
}
