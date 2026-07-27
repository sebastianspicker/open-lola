// Shared Direct peer session report AV pass helpers keep multi-file test scenarios deterministic.
import CryptoKit
import Foundation
import Testing

@testable import OpenLolaCore

func directPeerMeasuredAVRuntimeMetrics(
    mediaUnitCount: Int,
    fragmentCount: Int,
    includePreview: Bool
) -> DirectPeerSessionAVRuntimeMetrics {
    var metrics = DirectPeerSessionAVRuntimeMetrics()
    metrics.audioPayloadsCaptured = mediaUnitCount
    metrics.audioPayloadsSent = mediaUnitCount
    metrics.audioPayloadsQueuedForPlayout = mediaUnitCount
    metrics.videoFramesCaptured = mediaUnitCount
    metrics.videoFramesSent = mediaUnitCount
    metrics.videoFragmentsSent = fragmentCount
    metrics.videoFragmentsReceived = fragmentCount
    metrics.videoFramesReassembled = mediaUnitCount
    metrics.previewFramesSubmitted = includePreview ? mediaUnitCount : 0
    metrics.audioReceiveDrainIterations = mediaUnitCount
    metrics.videoReceiveDrainIterations = mediaUnitCount
    return metrics
}

func avPassCandidate() throws -> DirectPeerSessionReport {
    var report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: 2)
    directPeerSessionUsePhysicalEndpointHosts(&report)
    report.metrics.videoPacketsRouted = 2
    configureAVPassCandidateRuntime(&report)
    configureAVPassCandidateMeasuredEvidence(&report)
    report.verdict = .pass
    return report
}

func configureAVPassCandidateRuntime(_ report: inout DirectPeerSessionReport) {
    report.avRuntime = DirectPeerSessionAVRuntimeMetadata(
        session: .init(
            avProfile: .balanced,
            previewMode: .on,
            mediaSourceMode: .production,
            qualityPolicy: .requireUsefulMedia,
            usefulMediaProof: .requiredAndProven
        ),
 audio: directPeerSessionAudioFixture(
    deviceUID: "rme-madi-peer-a",
    inputDeviceUID: "rme-madi-peer-a",
    outputDeviceUID: "rme-madi-peer-a",
    latencyProfile: .balancedAV,
    rxBufferProfile: .small
 ),
 transport: directPeerSessionRawTransportFixture(),
 video: directPeerSessionRawVideoFixture(deviceID: "blackmagic-peer-a", streamID: 7),
        evidence: .init(
            fastestPassBlockedReason: "balanced profile selected for measured AV run",
            runtimeMetrics: directPeerMeasuredAVRuntimeMetrics(
                mediaUnitCount: 2,
                fragmentCount: 4,
                includePreview: true
            ),
            videoFormat: avPassVideoFormat(),
            receiveProof: avPassReceiveProof()
        )
    )
}

func configureAVPassCandidateMeasuredEvidence(_ report: inout DirectPeerSessionReport) {
    report.measuredEvidence = directPeerSessionMeasuredEvidence(
        sourcePeerLabel: "mac-a-m4-lab",
        receiverPeerLabel: "mac-b-m4-lab",
        routeLabel: "direct-en6-cable-run",
        rawVideoReceiveEvidence: "receiver report recorded two BGRA frames from blackmagic-peer-a"
    )
}

@Test
func directPeerSessionAoIPPassRequiresPTPEvidenceSummary() throws {
    var report = try avPassCandidate()
    report.avRuntime?.audioTransport = .aes67ST2110L24
    report.avRuntime?.aoipProfile = AES67ST2110L24Profile.profileName
    report.avRuntime?.rtpPayloadType = AES67ST2110L24Profile.payloadType
    report.avRuntime?.rtpClockRate = AES67ST2110L24Profile.clockRateHertz
    report.avRuntime?.rtpPacketTimeMilliseconds = AES67ST2110L24Profile.packetTimeMilliseconds
    report.avRuntime?.rtpSSRC = 42
    report.avRuntime?.sdpPath = "reports/aoip-peer-a.sdp"

    #expect(throws: DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence(
        "avRuntime.ptpEvidenceSummary"
    )) {
        try report.validate()
    }

    report.avRuntime?.ptpEvidenceSummary = "ptp profile aes67 domain 0 grandmaster 00-11-22 lock true offset 2us"
    try report.validate()
}

func expectDirectPeerSessionReportError(
    _ expected: DirectPeerSessionReportError,
    mutate: (inout DirectPeerSessionReport) throws -> Void
) throws {
    var report = try avPassCandidate()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

func avPassVideoFormat() -> DirectPeerSessionVideoFormatReport {
    DirectPeerSessionVideoFormatReport(
        request: .init(deviceID: "blackmagic-peer-a", frameRate: 30),
        selection: .init(
            deviceID: "blackmagic-peer-a", deviceLabel: "Blackmagic UltraStudio peer A",
            width: 1_920, height: 1_080, selectedPixelFormat: "BGRA", outputPixelFormat: "bgra8",
            frameRate: 30, sourcePolicy: .blackmagicFirstAvFoundationFallback
        )
    )
}

func avPassReceiveProof() -> DirectPeerSessionVideoReceiveProofArtifact {
    DirectPeerSessionVideoReceiveProofArtifact(
        framesProven: 2,
        previewFramesSubmitted: 2,
        firstFrame: avPassFrame(sequenceNumber: 11),
        latestFrame: avPassFrame(sequenceNumber: 12)
    )
}

func avPassFrame(sequenceNumber: UInt64) -> DirectPeerSessionVideoFrameProof {
    DirectPeerSessionVideoFrameProof(
        streamID: 7,
        sequenceNumber: sequenceNumber,
        width: 1_920,
        height: 1_080,
        pixelFormat: "BGRA",
        payloadByteCount: 1_920 * 1_080 * 4,
        fingerprint: "avfoundation-\(sequenceNumber)-1920x1080-BGRA",
        payloadDigest: "fnv1a64-\(sequenceNumber)"
    )
}

func makeDirectPeerSessionEvidenceBundleRoot() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-direct-p2p-evidence-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func writeDirectPeerSessionEvidenceArtifacts(
    for report: inout DirectPeerSessionReport,
    under bundleRoot: URL
) throws {
    try writeDirectPeerSessionEvidenceArtifact(
        field: "measuredEvidence.packetCapture",
        data: Data("packet capture".utf8),
        bundleRoot: bundleRoot
    ) {
        report.measuredEvidence?.packetCapture?.sha256 = $0
    }
    try writeDirectPeerSessionEvidenceArtifact(
        field: "measuredEvidence.dscp.artifact",
        data: Data("dscp evidence".utf8),
        bundleRoot: bundleRoot
    ) {
        report.measuredEvidence?.dscp?.artifact.sha256 = $0
    }
    try writeDirectPeerSessionEvidenceArtifact(
        field: "measuredEvidence.clock.artifact",
        data: Data("clock evidence".utf8),
        bundleRoot: bundleRoot
    ) {
        report.measuredEvidence?.clock?.artifact.sha256 = $0
    }
}

func writeDirectPeerSessionEvidenceArtifact(
    field: String,
    data: Data,
    bundleRoot: URL,
    assignSHA256: (String) -> Void
) throws {
    let path: String
    switch field {
    case "measuredEvidence.packetCapture":
        path = "reports/captures/direct-p2p-av-mac-b.pcapng"
    case "measuredEvidence.dscp.artifact":
        path = "reports/evidence/dscp-observation.json"
    case "measuredEvidence.clock.artifact":
        path = "reports/evidence/clock-sync.json"
    default:
        Issue.record("unexpected Direct P2P evidence field \(field)")
        return
    }
    let url = bundleRoot.appendingPathComponent(path)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url)
    assignSHA256(directPeerSessionTestSHA256(data))
}

func directPeerSessionTestSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
