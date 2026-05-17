import Foundation
import Testing

@testable import OpenLolaCore


@Test
func directPeerSessionValidatesMeasuredAVPassAndRejectsInvalidPassEvidence() throws {
    let passReport = try measuredPassCandidate()

    try passReport.validate()
    #expect(passReport.verdict == .pass)
    #expect(passReport.measuredEvidence?.kind == .physicalTwoPeerMacs)
    #expect(passReport.avRuntime?.runtimeMetrics.videoFramesReassembled == 1)

    var report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: 1)
    report.verdict = .pass

    #expect(throws: DirectPeerSessionReportError.passRequiresDirectLanManualAddressEvidence) {
        try report.validate()
    }

    report = try measuredPassCandidate()
    report.measuredEvidence?.kind = .synthetic

    #expect(throws: DirectPeerSessionReportError.passRequiresPhysicalTwoPeerEvidence(.synthetic)) {
        try report.validate()
    }

    report = try measuredPassCandidate()
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
    #expect(argumentValue("--video-stream-id", in: report.commands[0].arguments) == "100")
    #expect(argumentValue("--video-stream-id", in: report.commands[1].arguments) == "100")
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
    let plan = try DirectPeerTwoPeerRunPlanner.makeReport(configuration: try twoPeerPlanConfiguration())
    let processResults = plan.commands.map {
        DirectPeerTwoPeerLocalRunProcessResult(
            peerID: $0.peerID,
            role: $0.role,
            reportPath: $0.outputReportPath,
            command: $0.arguments,
            exitCode: 0,
            collectedReportPath: $0.outputReportPath,
            collectedReceiveProofPath: rxProofPath(for: $0.outputReportPath)
        )
    }
    let report = try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(
        plan: plan,
        executed: true,
        processResults: processResults,
        aggregateReportPath: "\(plan.runDirectory)/m06-direct-p2p-two-peer-prototype.json",
        aggregateExecuted: true
    )

    try report.validate()
    #expect(report.verdict == MeasurementVerdict.pass)

    let missingEvidenceResults = plan.commands.map {
        DirectPeerTwoPeerLocalRunProcessResult(
            peerID: $0.peerID,
            role: $0.role,
            reportPath: $0.outputReportPath,
            command: $0.arguments,
            exitCode: 0
        )
    }
    let downgradedReport = try DirectPeerTwoPeerLocalRunReportBuilder.makeReport(
        plan: plan,
        executed: true,
        processResults: missingEvidenceResults,
        aggregateFailureReason: "missing receive proof for mac-b"
    )

    try downgradedReport.validate()
    #expect(downgradedReport.verdict == .partial)
    #expect(downgradedReport.aggregateExecuted == false)
    #expect(downgradedReport.aggregateReportPath == nil)
    #expect(downgradedReport.notes.contains("Aggregate report generation failed: missing receive proof for mac-b"))

    let invalidPassResults = plan.commands.map {
        DirectPeerTwoPeerLocalRunProcessResult(
            peerID: $0.peerID,
            role: $0.role,
            reportPath: $0.outputReportPath,
            command: $0.arguments,
            exitCode: 0,
            collectedReportPath: $0.outputReportPath
        )
    }
    let invalidPassReport = DirectPeerTwoPeerLocalRunReport(
        id: "m06-direct-p2p-two-peer-local-run",
        capturedAt: "2026-05-12T00:00:00Z",
        planID: plan.id,
        runDirectory: plan.runDirectory,
        executed: true,
        processResults: invalidPassResults,
        aggregateCommand: [".build/debug/open-lola", "direct-p2p-two-peer-prototype-report"],
        aggregateReportPath: nil,
        aggregateExecuted: false,
        preflightChecks: [
            DirectPeerTwoPeerPreflightCheck(
                id: "synthetic",
                severity: .pass,
                passed: true,
                message: "synthetic"
            ),
        ],
        evidenceGates: ["synthetic"],
        verdict: .pass,
        notes: "synthetic pass candidate missing aggregate and receive proof evidence"
    )

    #expect(throws: DirectPeerTwoPeerLocalRunError.passRequiresAggregateReport) {
        try invalidPassReport.validate()
    }
}

private func measuredPassCandidate() throws -> DirectPeerSessionReport {
    var report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: 1)
    report.metrics.videoPacketsRouted = 1
    report.avRuntime = DirectPeerSessionAVRuntimeMetadata(
        avProfile: .balanced,
        previewMode: .on,
        mediaSourceMode: .production,
        audioDeviceUID: "rme-madi-full-duplex-a",
        inputDeviceUID: "rme-madi-full-duplex-a",
        outputDeviceUID: "rme-madi-full-duplex-a",
        sampleRateHertz: 48_000,
        selectedBufferFrameSize: 32,
        latencyProfile: .balancedAV,
        rxBufferProfile: .small,
        videoDeviceID: "blackmagic-ultrastudio-a",
        videoFrameRate: 30,
        videoStreamID: 100,
        fastestPassBlockedReason: "balanced profile selected for measured AV pass candidate",
        runtimeMetrics: DirectPeerSessionAVRuntimeMetrics(
            audioPayloadsCaptured: 1,
            audioPayloadsSent: 1,
            audioPayloadsQueuedForPlayout: 1,
            videoFramesCaptured: 1,
            videoFramesSent: 1,
            videoFragmentsSent: 2,
            videoFragmentsReceived: 2,
            videoFramesReassembled: 1,
            previewFramesSubmitted: 1,
            audioReceiveDrainIterations: 1,
            videoReceiveDrainIterations: 1
        ),
        videoFormat: measuredPassVideoFormat(),
        receiveProof: measuredPassReceiveProof()
    )
    report.measuredEvidence = DirectPeerSessionMeasuredEvidence(
        kind: .physicalTwoPeerMacs,
        sourcePeerLabel: "mac-a-m4-lab",
        receiverPeerLabel: "mac-b-m4-lab",
        routeLabel: "direct-en6-cable-run",
        packetCapturePath: "reports/captures/direct-p2p-av-mac-b.pcapng",
        packetCapture: directPeerSessionPacketCaptureArtifact(),
        dscpObservation: "EF preserved at receiver ingress",
        dscp: directPeerSessionDSCPEvidence(),
        clockSyncSummary: "PTP offset below one millisecond",
        clock: directPeerSessionClockEvidence(),
        rawVideoReceiveEvidence: "m06-direct-p2p-av-mac-b videoFramesReassembled greater than zero",
        durationSeconds: 30
    )
    report.verdict = .pass
    return report
}

private func measuredPassCandidate(peerID: String, reportID: String) throws -> DirectPeerSessionReport {
    var report = try measuredPassCandidate()
    report.id = reportID
    report.configuration.peers[0].peerID = peerID
    report.configuration.peerMediaEndpoints?[0].peerID = peerID
    return report
}

private func receiveProofArtifact(for report: DirectPeerSessionReport) throws -> DirectPeerSessionReceiveProofArtifact {
    let avRuntime = try #require(report.avRuntime)
    let proof = try #require(avRuntime.receiveProof)
    return DirectPeerSessionReceiveProofArtifact(
        report: report,
        proof: proof,
        runtimeCounters: avRuntime.runtimeMetrics
    )
}

private func manualRunConfiguration() -> DirectPeerSessionManualRunConfiguration {
    DirectPeerSessionManualRunConfiguration(
        role: .initiator,
        localPeerID: "mac-a",
        remotePeerID: "mac-b",
        localHost: "127.0.0.1",
        remoteHost: "127.0.0.1",
        controlPort: 57_000,
        remoteControlPort: 57_010,
        audioPort: 57_001,
        videoPort: 57_002,
        metricsPort: 57_003
    )
}

func measuredPassVideoFormat() -> DirectPeerSessionVideoFormatReport {
    DirectPeerSessionVideoFormatReport(
        requestedDeviceID: "blackmagic-ultrastudio-a",
        selectedDeviceID: "blackmagic-ultrastudio-a",
        selectedDeviceLabel: "Blackmagic UltraStudio lab A",
        requestedFrameRate: 30,
        selectedWidth: 1_280,
        selectedHeight: 720,
        selectedPixelFormat: "BGRA",
        outputPixelFormat: "BGRA",
        selectedFrameRate: 30,
        sourcePolicy: .blackmagicFirstAvFoundationFallback
    )
}

func measuredPassReceiveProof() -> DirectPeerSessionVideoReceiveProofArtifact {
    let frame = DirectPeerSessionVideoFrameProof(
        streamID: 100,
        sequenceNumber: 42,
        width: 1_280,
        height: 720,
        pixelFormat: "BGRA",
        payloadByteCount: 1_280 * 720 * 4,
        fingerprint: "avfoundation-42-1280x720-BGRA",
        payloadDigest: "fnv1a64-42"
    )
    return DirectPeerSessionVideoReceiveProofArtifact(
        framesProven: 1,
        previewFramesSubmitted: 1,
        firstFrame: frame,
        latestFrame: frame
    )
}

private func twoPeerPlanConfiguration() throws -> DirectPeerTwoPeerRunPlanConfiguration {
    try DirectPeerTwoPeerRunPlanConfiguration.parse(twoPeerPlanArguments())
}

private func twoPeerPlanArguments() -> [String] {
    [
        "--output", "/tmp/open-lola-m06/plan.json",
        "--run-dir", "/tmp/open-lola-m06",
        "--mac-a-peer", "mac-a",
        "--mac-a-host", "192.0.2.10",
        "--mac-a-port-base", "57000",
        "--mac-a-input-uid", "rme-a",
        "--mac-a-output-uid", "rme-a",
        "--mac-a-video-device-id", "camera-a",
        "--mac-b-peer", "mac-b",
        "--mac-b-host", "192.0.2.20",
        "--mac-b-port-base", "57010",
        "--mac-b-input-uid", "rme-b",
        "--mac-b-output-uid", "rme-b",
        "--mac-b-video-device-id", "camera-b",
        "--duration-seconds", "30",
        "--channels", "2",
        "--preview", "on",
    ]
}

private func twoPeerPlanArguments(replacing replacements: [String: String]) -> [String] {
    var arguments = twoPeerPlanArguments()
    for (argument, value) in replacements {
        guard let index = arguments.firstIndex(of: argument), index + 1 < arguments.count else {
            arguments += [argument, value]
            continue
        }
        arguments[index + 1] = value
    }
    return arguments
}

private func argumentValue(_ name: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        return nil
    }
    return arguments[index + 1]
}

private func rxProofPath(for reportPath: String) -> String {
    if reportPath.hasSuffix(".json") {
        return String(reportPath.dropLast(5)) + "-rx-proof.json"
    }
    return reportPath + "-rx-proof.json"
}
