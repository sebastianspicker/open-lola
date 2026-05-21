import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerFNV1A32FeedsDeterministicAES67SSRCs() throws {
    let peerAHash = directPeerFNV1A32("mac-a")
    let peerBHash = directPeerFNV1A32("mac-b")

    #expect(directPeerFNV1A32("") == 2_166_136_261)
    #expect(peerAHash == directPeerFNV1A32("mac-a"))
    #expect(peerAHash != peerBHash)
    #expect(peerAHash != 0)
    #expect(directPeerAES67SSRC(peerID: "mac-a") == peerAHash)
}

@Test
func directPeerVideoFrameProofUsesPayloadDigestEvidence() throws {
    let payload = Data([0x01, 0x02, 0x03])
    let otherPayload = Data([0x01, 0x02, 0x04])
    let digest = directPeerVideoPayloadDigest(payload)
    let frame = RawCapturedVideoFrame(
        metadata: CapturedVideoFrame(
            streamID: 100,
            sequenceNumber: 42,
            timestampNanoseconds: 1_000,
            timestampBasis: .hostUptimeNanoseconds,
            sourceRole: .avFoundationDevice,
            width: 2,
            height: 2,
            pixelFormat: "bgra8",
            frameRate: VideoFrameRate(numerator: 30, denominator: 1),
            fingerprint: "direct-peer-proof-frame"
        ),
        payload: payload
    )

    let proof = directPeerSessionVideoFrameProof(for: frame)

    #expect(digest.hasPrefix("fnv1a64-"))
    #expect(digest != directPeerVideoPayloadDigest(otherPayload))
    #expect(proof.streamID == 100)
    #expect(proof.sequenceNumber == 42)
    #expect(proof.payloadByteCount == payload.count)
    #expect(proof.fingerprint == "direct-peer-proof-frame")
    #expect(proof.payloadDigest == digest)
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
func directPeerTwoPeerValidatorSurfacesAcceptAggregateReport() throws {
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

    let canonicalOutput = try ReportValidatorSurface.validate(
        try report.prettyJSONData(),
        as: DirectPeerTwoPeerPrototypeReport.self,
        label: "direct P2P two-peer report"
    )
    let compatibilityOutput = try ReportValidatorSurface.validate(
        try report.prettyJSONData(),
        as: DirectPeerTwoPeerPrototypeReport.self,
        label: "direct P2P two-peer prototype report"
    )

    #expect(canonicalOutput.lines == [
        "direct P2P two-peer report valid: m06-direct-p2p-two-peer-prototype",
        "VERDICT: PASS",
    ])
    #expect(compatibilityOutput.lines == [
        "direct P2P two-peer prototype report valid: m06-direct-p2p-two-peer-prototype",
        "VERDICT: PASS",
    ])
}

private func measuredPassCandidate() throws -> DirectPeerSessionReport {
    var report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: 1)
    directPeerSessionUsePhysicalEndpointHosts(&report)
    report.metrics.videoPacketsRouted = 1
    report.avRuntime = DirectPeerSessionAVRuntimeMetadata(
        avProfile: .balanced,
        previewMode: .on,
        mediaSourceMode: .production,
        qualityPolicy: .requireUsefulMedia,
        usefulMediaProof: .requiredAndProven,
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
