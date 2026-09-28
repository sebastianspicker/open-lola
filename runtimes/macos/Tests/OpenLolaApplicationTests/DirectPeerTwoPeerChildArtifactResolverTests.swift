// Verifies mode-aware child artifact resolution and two-peer supervisor validation.
import Foundation
import OpenLolaApplication
import Testing

@Test func localChildArtifactsPreferExplicitReceiveProofPath() throws {
    let result = localResult(
        peerID: "mac-a",
        role: .initiator,
        reportPath: "/artifacts/mac-a-report.json",
        proofPath: "/artifacts/custom-mac-a-proof.json"
    )

    let artifacts = try DirectPeerTwoPeerChildArtifactResolver.resolve(result)

    #expect(artifacts.reportPath == "/artifacts/mac-a-report.json")
    #expect(artifacts.receiveProofPath == "/artifacts/custom-mac-a-proof.json")
    #expect(artifacts.reportField == "processResults.mac-a.reportPath")
    #expect(artifacts.receiveProofField == "processResults.mac-a.command.--rx-proof-output")
}

@Test func localChildArtifactsUseLegacyReceiveProofPathWhenNoExplicitOutputExists() throws {
    let result = localResult(
        peerID: "mac-b",
        role: .responder,
        reportPath: "/artifacts/mac-b-report.json"
    )

    let artifacts = try DirectPeerTwoPeerChildArtifactResolver.resolve(result)

    #expect(artifacts.receiveProofPath == "/artifacts/mac-b-report-rx-proof.json")
    #expect(artifacts.receiveProofField == "processResults.mac-b.reportPath")
}

@Test func sshChildArtifactsRequireSCPCollectionForBothArtifacts() throws {
    var result = DirectPeerTwoPeerLocalRunProcessResult(
        identity: .init(peerID: "mac-a", role: .initiator, reportPath: "/remote/report.json"),
        execution: .init(command: ["open-lola"], exitCode: 0, mode: .ssh),
        collection: .init(remoteTarget: "operator@mac-a")
    )

    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresCollectedReports) {
        try DirectPeerTwoPeerChildArtifactResolver.resolve(result)
    }
    result.collectedReportPath = "/collected/mac-a-report.json"
    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresReceiveProofs) {
        try DirectPeerTwoPeerChildArtifactResolver.resolve(result)
    }
    result.collectedReceiveProofPath = "/collected/mac-a-proof.json"

    let artifacts = try DirectPeerTwoPeerChildArtifactResolver.resolve(result)
    #expect(artifacts.reportPath == "/collected/mac-a-report.json")
    #expect(artifacts.receiveProofPath == "/collected/mac-a-proof.json")
}

@Test func aggregateCommandUsesTheSameResolvedLocalArtifactPaths() throws {
    let initiator = localResult(
        peerID: "mac-a",
        role: .initiator,
        reportPath: "/runs/mac-a-report.json",
        proofPath: "/runs/mac-a-explicit-proof.json"
    )
    let responder = localResult(
        peerID: "mac-b",
        role: .responder,
        reportPath: "/runs/mac-b-report.json"
    )
    var request = DirectPeerTwoPeerLocalRunReportRequest(
        plan: planFor(initiator, responder),
        executed: false
    )
    request.processResults = [responder, initiator]

    let report = try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(request: request)

    #expect(report.aggregateCommand == [
        ".build/debug/open-lola", "direct-p2p-two-peer-report",
        "--peer-a-report", "/runs/mac-b-report.json",
        "--peer-a-rx-proof", "/runs/mac-b-report-rx-proof.json",
        "--peer-b-report", "/runs/mac-a-report.json",
        "--peer-b-rx-proof", "/runs/mac-a-explicit-proof.json",
        "--output", "/runs/m06-direct-p2p-two-peer-prototype.json"
    ])
}

@Test func localPassValidationReportsMissingResolvedChildArtifact() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let supervisor = try passingSupervisorReport(in: directory)

    try supervisor.validate()
    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresReadableArtifact(
        "processResults.mac-a.reportPath"
    )) {
        try supervisor.validateReferencedArtifacts()
    }
}

@Test func localPassValidationReportsMalformedResolvedChildArtifact() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let supervisor = try passingSupervisorReport(in: directory)
    try Data("not a direct-peer report".utf8).write(
        to: directory.appendingPathComponent("mac-a-report.json")
    )

    try supervisor.validate()
    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresValidArtifact(
        "processResults.mac-a.reportPath"
    )) {
        try supervisor.validateReferencedArtifacts()
    }
}

private func localResult(
    peerID: String,
    role: DirectPeerSessionManualRole,
    reportPath: String,
    proofPath: String? = nil
) -> DirectPeerTwoPeerLocalRunProcessResult {
    var command = ["open-lola", "direct-p2p-session-run"]
    if let proofPath {
        command += ["--rx-proof-output", proofPath]
    }
    return DirectPeerTwoPeerLocalRunProcessResult(
        identity: .init(peerID: peerID, role: role, reportPath: reportPath),
        execution: .init(command: command, exitCode: 0, mode: .local)
    )
}

private func planFor(
    _ initiator: DirectPeerTwoPeerLocalRunProcessResult,
    _ responder: DirectPeerTwoPeerLocalRunProcessResult
) -> DirectPeerTwoPeerRunPlanReport {
    let commands = [responder, initiator].map {
        DirectPeerTwoPeerRunCommand(
            peerID: $0.peerID,
            role: $0.role,
            outputReportPath: $0.reportPath,
            arguments: $0.command
        )
    }
    return DirectPeerTwoPeerRunPlanReport(
        id: "test-plan",
        capturedAt: "2026-09-04T12:00:00Z",
        runDirectory: "/runs",
        commands: commands,
        reportReferences: commands.map { .init(peerID: $0.peerID, path: $0.outputReportPath) },
        evidenceGates: ["test gate"],
        verdict: .partial,
        notes: "test plan"
    )
}

private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-artifact-resolver-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func passingSupervisorReport(in directory: URL) throws -> DirectPeerTwoPeerLocalRunReport {
    let aggregatePath = directory.appendingPathComponent("aggregate.json")
    let aggregate = DirectPeerTwoPeerPrototypeReport(
        id: "aggregate",
        capturedAt: "2026-09-04T12:00:00Z",
        peerEvidence: [
            try passingAggregatePeer(peerID: "mac-a", reportPath: "mac-a-report.json"),
            try passingAggregatePeer(peerID: "mac-b", reportPath: "mac-b-report.json")
        ],
        evidenceGates: ["test gate"],
        verdict: .pass,
        notes: "test aggregate"
    )
    try aggregate.prettyJSONData().write(to: aggregatePath)
    let initiator = localResult(
        peerID: "mac-a",
        role: .initiator,
        reportPath: directory.appendingPathComponent("mac-a-report.json").path,
        proofPath: directory.appendingPathComponent("mac-a-proof.json").path
    )
    let responder = localResult(
        peerID: "mac-b",
        role: .responder,
        reportPath: directory.appendingPathComponent("mac-b-report.json").path,
        proofPath: directory.appendingPathComponent("mac-b-proof.json").path
    )
    return DirectPeerTwoPeerLocalRunReport(
        .init(
            metadata: .init(
                id: "supervisor",
                capturedAt: "2026-09-04T12:00:00Z",
                planID: "test-plan",
                runDirectory: directory.path
            ),
            processExecution: .init(
                executed: true,
                processResults: [initiator, responder],
                mode: .local
            ),
            aggregation: .init(command: ["test"], reportPath: aggregatePath.path, executed: true),
            evidence: .init(
                preflightChecks: [.init(id: "test", severity: .pass, passed: true, message: "test")],
                gates: ["test gate"],
                verdict: .pass,
                notes: "test supervisor"
            )
        )
    )
}

private func passingAggregatePeer(
    peerID: String,
    reportPath: String
) throws -> DirectPeerTwoPeerPrototypePeerEvidence {
    let report = try DirectP2PLocalhostSmoke.run(packetCount: 1).report
    let frame = DirectPeerSessionVideoFrameProof(
        streamID: 1,
        sequenceNumber: 1,
        width: 1,
        height: 1,
        pixelFormat: "BGRA",
        payloadByteCount: 4,
        fingerprint: "test-frame",
        payloadDigest: "test-digest"
    )
    let proof = DirectPeerSessionVideoReceiveProofArtifact(
        framesProven: 1,
        previewFramesSubmitted: 1,
        firstFrame: frame,
        latestFrame: frame
    )
    let receiveProof = DirectPeerSessionReceiveProofArtifact(
        report: report,
        proof: proof,
        runtimeCounters: .empty
    )
    var evidence = DirectPeerTwoPeerPrototypePeerEvidence(
        peerID: peerID,
        reportPath: reportPath,
        report: report,
        rxProofPath: "\(peerID)-proof.json",
        rxProofArtifact: receiveProof
    )
    evidence.reportVerdict = .pass
    evidence.videoFramesReassembled = 1
    evidence.rawVideoReceiveEvidence = "\(peerID)-raw-video.json"
    return evidence
}
