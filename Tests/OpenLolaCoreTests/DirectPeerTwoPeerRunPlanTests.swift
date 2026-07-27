// Verifies that direct peer session validates measured AV pass and rejects invalid pass evidence.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionValidatesMeasuredAVPassAndRejectsInvalidPassEvidence() throws {
    let passReport = try directPeerRunPlanMeasuredPassCandidate()

    try passReport.validate()
    #expect(passReport.verdict == .pass)
    #expect(passReport.measuredEvidence?.kind == .physicalTwoPeerMacs)
    #expect(passReport.avRuntime?.runtimeMetrics.videoFramesReassembled == 1)

    var report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: 1)
    report.verdict = .pass

    #expect(throws: DirectPeerSessionReportError.passRequiresDirectLanManualAddressEvidence) {
        try report.validate()
    }

    report = try directPeerRunPlanMeasuredPassCandidate()
    report.measuredEvidence?.kind = .synthetic

    #expect(throws: DirectPeerSessionReportError.passRequiresPhysicalTwoPeerEvidence(.synthetic)) {
        try report.validate()
    }

    report = try directPeerRunPlanMeasuredPassCandidate()
    report.avRuntime?.runtimeMetrics.videoFramesReassembled = 0

    #expect(throws: DirectPeerSessionReportError.passWithoutRoutedMedia(
        "avRuntime.runtimeMetrics.videoFramesReassembled"
    )) {
        try report.validate()
    }
}

@Test
func directPeerTwoPeerPlanBuildsCommandsAndSupportsExplicitExecutablePath() throws {
    let configuration = try twoPeerPlanConfiguration()
    let report = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: configuration)

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.commands.map(\.role) == [.responder, .initiator])
    #expect(report.commands[0].arguments.first == "open-lola")
    #expect(report.commands[0].arguments.contains("--media"))
    #expect(report.commands[0].arguments.contains("audio-video"))
    #expect(report.commands[0].arguments.contains("--preview"))
    #expect(report.commands[0].arguments.contains("on"))
    #expect(report.commands[0].outputReportPath == "/tmp/open-lola-m06/m06-direct-p2p-av-mac-b.json")
    #expect(report.commands[1].outputReportPath == "/tmp/open-lola-m06/m06-direct-p2p-av-mac-a.json")
    #expect(report.reportReferences.map(\.path) == report.commands.map(\.outputReportPath))
    #expect(report.reportReferences.map(\.schema) == ["DirectPeerSessionReport", "DirectPeerSessionReport"])
    #expect(report.commands[0].arguments.contains("--rx-proof-output"))
    #expect(report.commands[0].arguments.contains("/tmp/open-lola-m06/m06-direct-p2p-av-mac-b-rx-proof.json"))
    #expect(report.commands[1].arguments.contains("/tmp/open-lola-m06/m06-direct-p2p-av-mac-a-rx-proof.json"))
    #expect(directPeerRunPlanArgumentValue("--video-stream-id", in: report.commands[0].arguments) == "100")
    #expect(directPeerRunPlanArgumentValue("--video-stream-id", in: report.commands[1].arguments) == "100")
    #expect(report.evidenceGates.contains {
        $0.contains("mac-to-mac-connection-preflight-run")
    })

    let explicitConfiguration = try DirectPeerTwoPeerRunPlanConfiguration.parse(
        twoPeerPlanArguments(replacing: ["--executable": "/opt/open-lola/bin/open-lola"])
    )
    let explicitReport = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: explicitConfiguration)

    #expect(explicitConfiguration.executablePath == "/opt/open-lola/bin/open-lola")
    #expect(explicitReport.commands.allSatisfy { $0.arguments.first == "/opt/open-lola/bin/open-lola" })
    #expect(explicitReport.commands.allSatisfy { !$0.arguments.contains(".build/debug/open-lola") })
}

@Test
func directPeerTwoPeerPlanRejectsInvalidPlanContracts() throws {
    var configuration = try twoPeerPlanConfiguration()
    configuration.channelCount = 0

    #expect(throws: DirectPeerTwoPeerRunPlanError.invalidPositiveInt("--channels")) {
        _ = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: configuration)
    }

    var report = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: try twoPeerPlanConfiguration())
    report.verdict = .pass

    #expect(throws: DirectPeerTwoPeerRunPlanError.passRequiresMeasuredDirectPeerReports) {
        try report.validate()
    }

    report = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: try twoPeerPlanConfiguration())
    report.reportReferences.removeLast()

    #expect(throws: DirectPeerTwoPeerRunPlanError.mismatchedReportReferences) {
        try report.validate()
    }
}

@Test
func directPeerTwoPeerLocalRunReportHandlesPassDowngradeAndMissingAggregateEvidence() throws {
    let artifacts = try directPeerTwoPeerPassArtifacts()
    let report = try directPeerTwoPeerLocalRunPassReport(artifacts: artifacts)

    try report.validate()
    try report.validateReferencedArtifacts()
    #expect(report.verdict == MeasurementVerdict.pass)

    let downgradedReport = try directPeerTwoPeerDowngradedReport(plan: artifacts.plan)

    try downgradedReport.validate()
    #expect(downgradedReport.verdict == .partial)
    #expect(downgradedReport.aggregateExecuted == false)
    #expect(downgradedReport.aggregateReportPath == nil)
    #expect(downgradedReport.notes.contains("Aggregate report generation failed: missing receive proof for mac-b"))

    let invalidPassReport = directPeerTwoPeerInvalidPassMissingAggregateReport(plan: artifacts.plan)

    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresAggregateReport) {
        try invalidPassReport.validate()
    }
}

@Test
func directPeerTwoPeerLocalRunPassRequiresReadableReferencedArtifacts() throws {
    let artifacts = try directPeerTwoPeerPassArtifacts()
    let missingAggregate = artifacts.runDirectory.appendingPathComponent("missing-aggregate.json").path

    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresReadableArtifact("aggregateReportPath")) {
        var request = DirectPeerTwoPeerLocalRunReportRequest(plan: artifacts.plan, executed: true)
        request.processResults = artifacts.processResults
        request.aggregateReportPath = missingAggregate
        request.aggregateExecuted = true
        _ = try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(request: request)
    }

    var missingChildResults = artifacts.processResults
    missingChildResults[0].collectedReportPath = artifacts.runDirectory
        .appendingPathComponent("missing-child.json")
        .path

    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresReadableArtifact(
        "processResults.\(missingChildResults[0].peerID).collectedReportPath"
    )) {
        var request = DirectPeerTwoPeerLocalRunReportRequest(plan: artifacts.plan, executed: true)
        request.processResults = missingChildResults
        request.aggregateReportPath = artifacts.aggregateReportPath
        request.aggregateExecuted = true
        _ = try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(request: request)
    }
}

@Test
func directPeerTwoPeerLocalRunPassRejectsInvalidReferencedArtifacts() throws {
    let artifacts = try directPeerTwoPeerPassArtifacts()
    let invalidAggregateURL = artifacts.runDirectory.appendingPathComponent("invalid-aggregate.json")
    try Data("{".utf8).write(to: invalidAggregateURL)

    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresValidArtifact("aggregateReportPath")) {
        var request = DirectPeerTwoPeerLocalRunReportRequest(plan: artifacts.plan, executed: true)
        request.processResults = artifacts.processResults
        request.aggregateReportPath = invalidAggregateURL.path
        request.aggregateExecuted = true
        _ = try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(request: request)
    }

    var invalidChildResults = artifacts.processResults
    let invalidChildURL = artifacts.runDirectory.appendingPathComponent("invalid-child.json")
    try Data("{".utf8).write(to: invalidChildURL)
    invalidChildResults[0].collectedReportPath = invalidChildURL.path

    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresValidArtifact(
        "processResults.\(invalidChildResults[0].peerID).collectedReportPath"
    )) {
        var request = DirectPeerTwoPeerLocalRunReportRequest(plan: artifacts.plan, executed: true)
        request.processResults = invalidChildResults
        request.aggregateReportPath = artifacts.aggregateReportPath
        request.aggregateExecuted = true
        _ = try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(request: request)
    }

    var invalidProofResults = artifacts.processResults
    let invalidProofURL = artifacts.runDirectory.appendingPathComponent("invalid-rx-proof.json")
    try Data("{".utf8).write(to: invalidProofURL)
    invalidProofResults[0].collectedReceiveProofPath = invalidProofURL.path

    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresValidArtifact(
        "processResults.\(invalidProofResults[0].peerID).collectedReceiveProofPath"
    )) {
        var request = DirectPeerTwoPeerLocalRunReportRequest(plan: artifacts.plan, executed: true)
        request.processResults = invalidProofResults
        request.aggregateReportPath = artifacts.aggregateReportPath
        request.aggregateExecuted = true
        _ = try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(request: request)
    }
}

@Test
func directPeerTwoPeerLocalRunPassRejectsPartialOrIncompleteChildEvidence() throws {
    let artifacts = try directPeerTwoPeerPassArtifacts()

    var missingProofResults = artifacts.processResults
    missingProofResults[0].collectedReceiveProofPath = nil
    let missingProofReport = directPeerTwoPeerLocalRunPassReport(
        plan: artifacts.plan,
        processResults: missingProofResults,
        aggregateReportPath: artifacts.aggregateReportPath
    )

    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresReceiveProofs) {
        try missingProofReport.validate()
    }

    var partialChild = artifacts.initiatorReport
    partialChild.verdict = .partial
    try partialChild.prettyJSONData().write(to: artifacts.initiatorReportURL)

    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresValidArtifact(
        "processResults.\(artifacts.initiatorPeerID).collectedReportPath"
    )) {
        _ = try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(
            request: directPeerTwoPeerPassReportRequest(artifacts: artifacts)
        )
    }

    var missingPacketCapture = artifacts.initiatorReport
    missingPacketCapture.measuredEvidence?.packetCapture = nil
    try missingPacketCapture.prettyJSONData().write(to: artifacts.initiatorReportURL)

    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresValidArtifact(
        "processResults.\(artifacts.initiatorPeerID).collectedReportPath"
    )) {
        _ = try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(
            request: directPeerTwoPeerPassReportRequest(artifacts: artifacts)
        )
    }
}

private func directPeerTwoPeerPassReportRequest(
    artifacts: DirectPeerTwoPeerPassArtifacts
) -> DirectPeerTwoPeerLocalRunReportRequest {
    var request = DirectPeerTwoPeerLocalRunReportRequest(plan: artifacts.plan, executed: true)
    request.processResults = artifacts.processResults
    request.aggregateReportPath = artifacts.aggregateReportPath
    request.aggregateExecuted = true
    return request
}
