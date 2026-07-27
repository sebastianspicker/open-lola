// Shared Direct peer two peer run plan report helpers keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaCore

func directPeerRunPlanMeasuredPassCandidate() throws -> DirectPeerSessionReport {
    var report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: 1)
    directPeerSessionUsePhysicalEndpointHosts(&report)
    report.metrics.videoPacketsRouted = 1
    report.avRuntime = measuredPassAVRuntime()
    report.measuredEvidence = measuredPassEvidence()
    report.verdict = .pass
    return report
}

func measuredPassAVRuntime() -> DirectPeerSessionAVRuntimeMetadata {
    DirectPeerSessionAVRuntimeMetadata(
        session: .init(
            avProfile: .balanced,
            previewMode: .on,
            mediaSourceMode: .production,
            qualityPolicy: .requireUsefulMedia,
            usefulMediaProof: .requiredAndProven
        ),
 audio: directPeerSessionAudioFixture(
    deviceUID: "rme-madi-full-duplex-a",
    inputDeviceUID: "rme-madi-full-duplex-a",
    outputDeviceUID: "rme-madi-full-duplex-a",
    latencyProfile: .balancedAV,
    rxBufferProfile: .small
 ),
 transport: directPeerSessionRawTransportFixture(),
 video: directPeerSessionRawVideoFixture(deviceID: "blackmagic-ultrastudio-a"),
        evidence: .init(
            fastestPassBlockedReason: "balanced profile selected for measured AV pass candidate",
            runtimeMetrics: directPeerMeasuredAVRuntimeMetrics(
                mediaUnitCount: 1,
                fragmentCount: 2,
                includePreview: true
            ),
            videoFormat: measuredPassVideoFormat(),
            receiveProof: measuredPassReceiveProof()
        )
    )
}

func measuredPassEvidence() -> DirectPeerSessionMeasuredEvidence {
    directPeerSessionMeasuredEvidence(
        sourcePeerLabel: "mac-a-m4-lab",
        receiverPeerLabel: "mac-b-m4-lab",
        routeLabel: "direct-en6-cable-run",
        rawVideoReceiveEvidence: "m06-direct-p2p-av-mac-b videoFramesReassembled greater than zero"
    )
}

func directPeerRunPlanMeasuredPassCandidate(
    peerID: String,
    reportID: String
) throws -> DirectPeerSessionReport {
    var report = try directPeerRunPlanMeasuredPassCandidate()
    report.id = reportID
    report.configuration.peers[0].peerID = peerID
    report.configuration.peerMediaEndpoints?[0].peerID = peerID
    return report
}

struct DirectPeerTwoPeerPassArtifacts {
    var runDirectory: URL
    var plan: DirectPeerTwoPeerRunPlanReport
    var processResults: [DirectPeerTwoPeerLocalRunProcessResult]
    var aggregateReportPath: String
    var initiatorPeerID: String
    var initiatorReport: DirectPeerSessionReport
    var initiatorReportURL: URL
}

struct DirectPeerTwoPeerPeerArtifact {
    var command: DirectPeerTwoPeerRunCommand
    var report: DirectPeerSessionReport
    var reportURL: URL
    var proof: DirectPeerSessionReceiveProofArtifact
    var proofURL: URL
}

func directPeerTwoPeerPassArtifacts() throws -> DirectPeerTwoPeerPassArtifacts {
    let runDirectory = try directPeerTwoPeerRunDirectory()
    let plan = try directPeerTwoPeerPlan(in: runDirectory)
    let peerArtifacts = try plan.commands.map(directPeerTwoPeerPeerArtifact(for:))
    let initiator = try #require(peerArtifacts.first { $0.command.role == .initiator })
    let responder = try #require(peerArtifacts.first { $0.command.role == .responder })
    let aggregateURL = try directPeerTwoPeerAggregateURL(
        runDirectory: runDirectory,
        initiator: initiator,
        responder: responder
    )

    return DirectPeerTwoPeerPassArtifacts(
        runDirectory: runDirectory,
        plan: plan,
        processResults: directPeerTwoPeerProcessResults(responder: responder, initiator: initiator),
        aggregateReportPath: aggregateURL.path,
        initiatorPeerID: initiator.command.peerID,
        initiatorReport: initiator.report,
        initiatorReportURL: initiator.reportURL
    )
}

func directPeerTwoPeerRunDirectory() throws -> URL {
    let runDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-two-peer-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
    return runDirectory
}

func directPeerTwoPeerPlan(in runDirectory: URL) throws -> DirectPeerTwoPeerRunPlanReport {
    let configuration = try DirectPeerTwoPeerRunPlanConfiguration.parse(twoPeerPlanArguments(replacing: [
        "--output": runDirectory.appendingPathComponent("plan.json").path,
        "--run-dir": runDirectory.path
    ]))
    return try DirectPeerTwoPeerRunPlanner.makeReport(configuration: configuration)
}

func directPeerTwoPeerPeerArtifact(
for command: DirectPeerTwoPeerRunCommand
) throws -> DirectPeerTwoPeerPeerArtifact {
    let report = try directPeerRunPlanMeasuredPassCandidate(
        peerID: command.peerID,
        reportID: "direct-p2p-session-\(command.peerID)"
    )
    let proof = try directPeerRunPlanReceiveProofArtifact(for: report)
    let reportURL = URL(fileURLWithPath: command.outputReportPath)
    let proofURL = URL(fileURLWithPath: rxProofPath(for: command.outputReportPath))
    try FileManager.default.createDirectory(
        at: reportURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try report.prettyJSONData().write(to: reportURL)
    try JSONEncoder().encode(proof).write(to: proofURL)
    return DirectPeerTwoPeerPeerArtifact(
        command: command,
        report: report,
        reportURL: reportURL,
        proof: proof,
        proofURL: proofURL
    )
}

func directPeerTwoPeerAggregateURL(
    runDirectory: URL,
    initiator: DirectPeerTwoPeerPeerArtifact,
    responder: DirectPeerTwoPeerPeerArtifact
) throws -> URL {
    let aggregate = try DirectPeerTwoPeerPrototypeReportBuilder.makeReport(
        peerAReportPath: initiator.reportURL.path,
        peerAReport: initiator.report,
        peerARXProofPath: initiator.proofURL.path,
        peerARXProof: initiator.proof,
        peerBReportPath: responder.reportURL.path,
        peerBReport: responder.report,
        peerBRXProofPath: responder.proofURL.path,
        peerBRXProof: responder.proof
    )
    let aggregateURL = runDirectory.appendingPathComponent("m06-direct-p2p-two-peer-prototype.json")
    try aggregate.prettyJSONData().write(to: aggregateURL)
    return aggregateURL
}

func directPeerTwoPeerProcessResults(
    responder: DirectPeerTwoPeerPeerArtifact,
    initiator: DirectPeerTwoPeerPeerArtifact
) -> [DirectPeerTwoPeerLocalRunProcessResult] {
    [responder, initiator].map {
        DirectPeerTwoPeerLocalRunProcessResult(
            identity: .init(
                peerID: $0.command.peerID,
                role: $0.command.role,
                reportPath: $0.command.outputReportPath
            ),
            execution: .init(command: $0.command.arguments, exitCode: 0),
            collection: .init(
                reportPath: $0.reportURL.path,
                receiveProofPath: $0.proofURL.path
            )
        )
    }
}

func directPeerTwoPeerLocalRunPassReport(
    artifacts: DirectPeerTwoPeerPassArtifacts
) throws -> DirectPeerTwoPeerLocalRunReport {
    var request = DirectPeerTwoPeerLocalRunReportRequest(plan: artifacts.plan, executed: true)
    request.processResults = artifacts.processResults
    request.aggregateReportPath = artifacts.aggregateReportPath
    request.aggregateExecuted = true
    return try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(request: request)
}

func directPeerTwoPeerDowngradedReport(
    plan: DirectPeerTwoPeerRunPlanReport
) throws -> DirectPeerTwoPeerLocalRunReport {
    var request = DirectPeerTwoPeerLocalRunReportRequest(plan: plan, executed: true)
    request.processResults = directPeerTwoPeerProcessResultsMissingCollectedEvidence(plan: plan)
    request.aggregateFailureReason = "missing receive proof for mac-b"
    return try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(request: request)
}

func directPeerTwoPeerProcessResultsMissingCollectedEvidence(
    plan: DirectPeerTwoPeerRunPlanReport
) -> [DirectPeerTwoPeerLocalRunProcessResult] {
    plan.commands.map { command in
        directPeerTwoPeerProcessResultMissingCollectedEvidence(command)
    }
}

private func directPeerTwoPeerProcessResultMissingCollectedEvidence(
    _ command: DirectPeerTwoPeerRunCommand,
    collectedReportPath: String? = nil
) -> DirectPeerTwoPeerLocalRunProcessResult {
    DirectPeerTwoPeerLocalRunProcessResult(
        identity: .init(peerID: command.peerID, role: command.role, reportPath: command.outputReportPath),
        execution: .init(command: command.arguments, exitCode: 0),
        collection: .init(reportPath: collectedReportPath)
    )
}

func directPeerTwoPeerInvalidPassMissingAggregateReport(
    plan: DirectPeerTwoPeerRunPlanReport
) -> DirectPeerTwoPeerLocalRunReport {
    DirectPeerTwoPeerLocalRunReport(
        DirectPeerTwoPeerLocalRunReport.Input(
            metadata: DirectPeerTwoPeerLocalRunReport.Metadata(
                id: "m06-direct-p2p-two-peer-local-run",
                capturedAt: "2026-05-12T00:00:00Z",
                planID: plan.id,
                runDirectory: plan.runDirectory
            ),
            processExecution: DirectPeerTwoPeerLocalRunReport.ProcessExecution(
                executed: true,
                processResults: directPeerTwoPeerInvalidPassResults(plan: plan)
            ),
            aggregation: DirectPeerTwoPeerLocalRunReport.Aggregation(
                command: [".build/debug/open-lola", "direct-p2p-two-peer-report"]
            ),
            evidence: DirectPeerTwoPeerLocalRunReport.Evidence(
                preflightChecks: directPeerTwoPeerSyntheticPreflightChecks(),
                gates: ["synthetic"],
                verdict: .pass,
                notes: "synthetic pass candidate missing aggregate and receive proof evidence"
            )
        )
    )
}

func directPeerTwoPeerInvalidPassResults(
    plan: DirectPeerTwoPeerRunPlanReport
) -> [DirectPeerTwoPeerLocalRunProcessResult] {
    plan.commands.map { command in
        directPeerTwoPeerProcessResultMissingCollectedEvidence(
            command,
            collectedReportPath: command.outputReportPath
        )
    }
}

func directPeerTwoPeerSyntheticPreflightChecks() -> [DirectPeerTwoPeerPreflightCheck] {
    [
        DirectPeerTwoPeerPreflightCheck(
            id: "synthetic",
            severity: .pass,
            passed: true,
            message: "synthetic"
        )
    ]
}

func directPeerTwoPeerLocalRunPassReport(
    plan: DirectPeerTwoPeerRunPlanReport,
    processResults: [DirectPeerTwoPeerLocalRunProcessResult],
    aggregateReportPath: String
) -> DirectPeerTwoPeerLocalRunReport {
    DirectPeerTwoPeerLocalRunReport(
        .init(
            metadata: .init(
                id: "m06-direct-p2p-two-peer-local-run",
                capturedAt: "2026-05-12T00:00:00Z",
                planID: plan.id,
                runDirectory: plan.runDirectory
            ),
            processExecution: .init(executed: true, processResults: processResults),
            aggregation: .init(
                command: [".build/debug/open-lola", "direct-p2p-two-peer-report"],
                reportPath: aggregateReportPath,
                executed: true
            ),
            evidence: .init(
                preflightChecks: directPeerTwoPeerSyntheticPreflightChecks(),
                gates: ["synthetic"],
                verdict: .pass,
                notes: "unit test pass candidate"
            )
        )
    )
}
