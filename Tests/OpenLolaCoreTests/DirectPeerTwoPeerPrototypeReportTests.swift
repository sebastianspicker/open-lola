import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerFNV1A32ConstantsAreNamedAndScopedToLocalIdentifiers() throws {
    let source = try readDirectPeerSource("Sources/OpenLolaCore/Network/P2P/DirectPeerFNV1A.swift")
    let audioLoopSource = try readDirectPeerSource("Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift")
    let reportSource = try readDirectPeerSource("Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVReportBuilder.swift")

    #expect(source.contains("let directPeerFNV1A32OffsetBasis: UInt32 = 2_166_136_261"))
    #expect(source.contains("let directPeerFNV1A32Prime: UInt32 = 16_777_619"))
    #expect(source.contains("not a cryptographic integrity check"))
    #expect(audioLoopSource.contains("let hash = directPeerFNV1A32(peerID)"))
    #expect(reportSource.contains("let hash = directPeerFNV1A32(peerID)"))
}

@Test
func directPeerRawAudioSameDeadlineComparisonDocumentsFullMetadataBoundary() throws {
    let source = try readDirectPeerSource("Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift")

    #expect(source.contains("Same-deadline raw-audio fragments must describe one playout block"))
    #expect(source.contains("identity, timing, sample shape, fragment plan, metadata revision, and"))
    #expect(source.contains("packing mode all have to match before reassembly can share a buffer"))
}

@Test
func directPeerVideoPayloadDigestDocumentsNonCryptographicEvidenceBoundary() throws {
    let source = try readDirectPeerSource(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoReportSupport.swift"
    )

    #expect(source.contains("Compact evidence label only"))
    #expect(source.contains("packet-capture metadata"))
    #expect(source.contains("Do not use this FNV-1a"))
    #expect(source.contains("cryptographic payload-integrity proof"))
}

@Test
func directPeerReceiveProofDigestDistinguishesNilFromLiteralNilString() throws {
    let report = try measuredPassCandidate()
    let avRuntime = try #require(report.avRuntime)
    let proof = try #require(avRuntime.receiveProof)
    var nilDigestProof = proof
    nilDigestProof.firstFrame.payloadDigest = nil
    var literalDigestProof = proof
    literalDigestProof.firstFrame.payloadDigest = "<nil>"

    let nilDigestArtifact = DirectPeerSessionReceiveProofArtifact(
        report: report,
        proof: nilDigestProof,
        runtimeCounters: avRuntime.runtimeMetrics
    )
    let literalDigestArtifact = DirectPeerSessionReceiveProofArtifact(
        report: report,
        proof: literalDigestProof,
        runtimeCounters: avRuntime.runtimeMetrics
    )

    #expect(nilDigestArtifact.evidenceMetadata.evidenceDigest != literalDigestArtifact.evidenceMetadata.evidenceDigest)
}

@Test
func directPeerTwoPeerPrototypeReportIsPartialWithoutRXProofArtifacts() throws {
    let peerA = try measuredPassCandidate(peerID: "mac-a", reportID: "direct-p2p-session-mac-a")
    let peerB = try measuredPassCandidate(peerID: "mac-b", reportID: "direct-p2p-session-mac-b")

    let report = try DirectPeerTwoPeerPrototypeReportBuilder.makeReport(
        peerAReportPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-a.json",
        peerAReport: peerA,
        peerBReportPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-b.json",
        peerBReport: peerB
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.peerEvidence.map(\.peerID) == ["mac-a", "mac-b"])
    #expect(report.peerEvidence.allSatisfy { $0.reportVerdict == .pass })
    #expect(report.peerEvidence.allSatisfy { $0.rxProofPath == nil })
}

@Test
func directPeerTwoPeerPrototypeReportPassRequiresTwoPassingReportsAndRXProofArtifacts() throws {
    let peerA = try measuredPassCandidate(peerID: "mac-a", reportID: "direct-p2p-session-mac-a")
    let peerB = try measuredPassCandidate(peerID: "mac-b", reportID: "direct-p2p-session-mac-b")
    let peerAProof = try receiveProofArtifact(for: peerA)
    let peerBProof = try receiveProofArtifact(for: peerB)

    let report = try DirectPeerTwoPeerPrototypeReportBuilder.makeReport(
        peerAReportPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-a.json",
        peerAReport: peerA,
        peerARXProofPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-a-rx-proof.json",
        peerARXProof: peerAProof,
        peerBReportPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-b.json",
        peerBReport: peerB,
        peerBRXProofPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-b-rx-proof.json",
        peerBRXProof: peerBProof
    )

    try report.validate()
    #expect(report.verdict == .pass)
    #expect(report.peerEvidence.map(\.rxProofArtifactID) == [peerAProof.id, peerBProof.id])
    #expect(report.peerEvidence.allSatisfy { $0.videoFramesReassembled == 1 })
}

@Test
func directPeerTwoPeerPrototypeReportRejectsMismatchedRXProofArtifact() throws {
    let peerA = try measuredPassCandidate(peerID: "mac-a", reportID: "direct-p2p-session-mac-a")
    let peerB = try measuredPassCandidate(peerID: "mac-b", reportID: "direct-p2p-session-mac-b")
    let peerBProof = try receiveProofArtifact(for: peerB)

    #expect(throws: DirectPeerTwoPeerRunPlanError.mismatchedReceiveProof("peer-a.reportID")) {
        _ = try DirectPeerTwoPeerPrototypeReportBuilder.makeReport(
            peerAReportPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-a.json",
            peerAReport: peerA,
            peerARXProofPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-a-rx-proof.json",
            peerARXProof: peerBProof,
            peerBReportPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-b.json",
            peerBReport: peerB
        )
    }
}

@Test
func directPeerTwoPeerPrototypeValidatorSurfaceAcceptsAggregateReport() throws {
    let peerA = try measuredPassCandidate(peerID: "mac-a", reportID: "direct-p2p-session-mac-a")
    let peerB = try measuredPassCandidate(peerID: "mac-b", reportID: "direct-p2p-session-mac-b")
    let report = try DirectPeerTwoPeerPrototypeReportBuilder.makeReport(
        peerAReportPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-a.json",
        peerAReport: peerA,
        peerARXProofPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-a-rx-proof.json",
        peerARXProof: try receiveProofArtifact(for: peerA),
        peerBReportPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-b.json",
        peerBReport: peerB,
        peerBRXProofPath: "/tmp/open-lola-m06/m06-direct-p2p-av-mac-b-rx-proof.json",
        peerBRXProof: try receiveProofArtifact(for: peerB)
    )

    let output = try ReportValidatorSurface.validate(
        try report.prettyJSONData(),
        as: DirectPeerTwoPeerPrototypeReport.self,
        label: "direct P2P two-peer prototype report"
    )

    #expect(output.lines == [
        "direct P2P two-peer prototype report valid: m06-direct-p2p-two-peer-prototype",
        "VERDICT: PASS",
    ])
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


private func readDirectPeerSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
