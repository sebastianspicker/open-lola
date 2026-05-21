import CryptoKit
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionAVPassRejectsInvalidPassEvidence() throws {
    try expectDirectPeerSessionReportError(.passRequiresProductionMediaSourceMode(.syntheticFixture)) {
        $0.avRuntime?.mediaSourceMode = .syntheticFixture
    }
    try expectDirectPeerSessionReportError(.passRequiresVideoFormat) {
        $0.avRuntime?.videoFormat = nil
    }
    try expectDirectPeerSessionReportError(.passRequiresVideoReceiveProof) {
        $0.avRuntime?.receiveProof = nil
    }
    try expectDirectPeerSessionReportError(.passWithInconsistentVideoProof(
        "avRuntime.receiveProof.framesProven"
    )) {
        $0.avRuntime?.receiveProof?.framesProven = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.videoFramesDroppedOutsideAudioWindow"
    )) {
        $0.avRuntime?.runtimeMetrics.videoFramesDroppedOutsideAudioWindow = 1
    }
    try expectDirectPeerSessionReportError(.passWithInconsistentVideoProof(
        "avRuntime.receiveProof.latestFrame.width"
    )) {
        $0.avRuntime?.receiveProof?.latestFrame.width = 1_919
    }
    try expectDirectPeerSessionReportError(.passWithInconsistentVideoProof(
        "avRuntime.receiveProof.firstFrame.payloadByteCount"
    )) {
        $0.avRuntime?.receiveProof?.firstFrame.payloadByteCount = 1_920 * 1_080
    }
    try expectDirectPeerSessionReportError(.passWithInconsistentVideoProof(
        "avRuntime.receiveProof.latestFrame.payloadByteCount"
    )) {
        $0.avRuntime?.receiveProof?.latestFrame.payloadByteCount = (1_920 * 4 + 64) * 1_080
    }
    try expectDirectPeerSessionReportError(.passWithInconsistentVideoProof(
        "avRuntime.receiveProof.latestFrame.payloadDigest"
    )) {
        $0.avRuntime?.receiveProof?.latestFrame.payloadDigest = nil
    }
    try expectDirectPeerSessionReportError(.passWithPlaceholderMeasuredEvidence(
        "measuredEvidence.rawVideoReceiveEvidence"
    )) {
        $0.measuredEvidence?.rawVideoReceiveEvidence = nil
    }
    try expectDirectPeerSessionReportError(.passRequiresStructuredEvidence(
        "measuredEvidence.packetCapture"
    )) {
        $0.measuredEvidence?.packetCapture = nil
    }
    try expectDirectPeerSessionReportError(.passWithInvalidEvidenceArtifact(
        "measuredEvidence.packetCapture.sha256"
    )) {
        $0.measuredEvidence?.packetCapture?.sha256 = nil
    }
    try expectDirectPeerSessionReportError(.passWithInvalidEvidenceArtifact(
        "measuredEvidence.dscp.artifact.captured"
    )) {
        $0.measuredEvidence?.dscp?.artifact.captured = false
    }
    for weakClassification in [
        DirectPeerSessionDSCPClassification.rewritten,
        .ignored,
        .harmful,
    ] {
        try expectDirectPeerSessionReportError(.passWithInvalidDSCPEvidence(
            "measuredEvidence.dscp.classification"
        )) {
            $0.measuredEvidence?.dscp?.classification = weakClassification
        }
    }
    try expectDirectPeerSessionReportError(.passWithInvalidDSCPEvidence(
        "measuredEvidence.dscp.observed"
    )) {
        $0.measuredEvidence?.dscp?.observed = nil
    }
    try expectDirectPeerSessionReportError(.passRequiresFastestAVBaselineComparison) {
        $0.avRuntime?.avProfile = .fastest
        $0.avRuntime?.latencyProfile = .directAudioFirst
        $0.avRuntime?.rxBufferProfile = .direct
    }
    try expectDirectPeerSessionReportError(.passWithFailedFastestAVBaselineComparison(
        "avRuntime.fastestAVBaselineComparison.audioLatencyEqualToBaseline"
    )) {
        $0.avRuntime?.avProfile = .fastest
        $0.avRuntime?.latencyProfile = .directAudioFirst
        $0.avRuntime?.rxBufferProfile = .direct
        $0.avRuntime?.fastestAVBaselineComparison = directPeerSessionFastestAVBaselineComparison()
        $0.avRuntime?.fastestAVBaselineComparison?.audioLatencyEqualToBaseline = false
    }
}

@Test
func directPeerSessionAVPassRequiresExplicitUsefulMediaProof() throws {
    try expectDirectPeerSessionReportError(.passRequiresUsefulMediaProof(.unknown)) {
        $0.avRuntime?.qualityPolicy = nil
        $0.avRuntime?.usefulMediaProof = .unknown
    }
    try expectDirectPeerSessionReportError(.passRequiresUsefulMediaProof(.notRequired)) {
        $0.avRuntime?.qualityPolicy = .structural
        $0.avRuntime?.usefulMediaProof = .notRequired
    }
    try expectDirectPeerSessionReportError(.passRequiresUsefulMediaProof(.requiredButNotProven)) {
        $0.avRuntime?.usefulMediaProof = .requiredButNotProven
    }
}

@Test
func directPeerSessionAVRuntimeRejectsInconsistentUsefulMediaProofState() throws {
    try expectDirectPeerSessionReportError(.invalidUsefulMediaProof("avRuntime.usefulMediaProof")) {
        $0.verdict = .partial
        $0.avRuntime?.qualityPolicy = nil
        $0.avRuntime?.usefulMediaProof = .requiredAndProven
    }
    try expectDirectPeerSessionReportError(.invalidUsefulMediaProof("avRuntime.usefulMediaProof")) {
        $0.verdict = .partial
        $0.avRuntime?.qualityPolicy = .structural
        $0.avRuntime?.usefulMediaProof = .requiredAndProven
    }
}

@Test
func directPeerSessionAVPassRejectsLoopbackDerivedPhysicalEvidence() throws {
    var report = try avPassCandidate()
    report.configuration.peerMediaEndpoints?[0].audioEndpoint.host = "127.0.0.1"

    #expect(throws: DirectPeerSessionReportError.passRequiresNonLoopbackPeerEndpoint(
        "configuration.peerMediaEndpoints.peer-a.audioEndpoint.host"
    )) {
        try report.validate()
    }
}

@Test
func directPeerSessionAVPassRejectsRuntimeDegradationCounters() throws {
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation("metrics.packetsLost")) {
        $0.metrics.packetsLost = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation("metrics.recoveryEvents")) {
        $0.metrics.recoveryEvents = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation("metrics.remoteUnderruns")) {
        $0.metrics.remoteUnderruns = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.audioPayloadsDroppedBeforeSend"
    )) {
        $0.avRuntime?.runtimeMetrics.audioPayloadsDroppedBeforeSend = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.audioTXBudgetExhaustions"
    )) {
        $0.avRuntime?.runtimeMetrics.audioTXBudgetExhaustions = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.audioUnexpectedPayloadTypes"
    )) {
        $0.avRuntime?.runtimeMetrics.audioUnexpectedPayloadTypes = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.audioRXBuffer.lostPackets"
    )) {
        $0.avRuntime?.runtimeMetrics.audioRXBuffer = RxBufferRuntimeSnapshot(
            policy: try RxBufferPolicy.small(framesPerPacket: 32, sampleRateHertz: 48_000),
            lostPackets: 1
        )
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.audioPlayoutUnderruns"
    )) {
        $0.avRuntime?.runtimeMetrics.audioPlayoutUnderruns = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.audioCallbackMaxMicroseconds"
    )) {
        $0.avRuntime?.runtimeMetrics.audioCallbackMaxMicroseconds = 800
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.audioCallbackDeadlineMisses"
    )) {
        $0.avRuntime?.runtimeMetrics.audioCallbackDeadlineMisses = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.audioHostTimeConversionFailures"
    )) {
        $0.avRuntime?.runtimeMetrics.audioHostTimeConversionFailures = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.videoFragmentsDroppedCorrupt"
    )) {
        $0.avRuntime?.runtimeMetrics.videoFragmentsDroppedCorrupt = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.videoUnexpectedPayloadTypes"
    )) {
        $0.avRuntime?.runtimeMetrics.videoUnexpectedPayloadTypes = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.videoReassemblyDuplicateFragments"
    )) {
        $0.avRuntime?.runtimeMetrics.videoReassemblyDuplicateFragments = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.metricsMessagesPublishFailures"
    )) {
        $0.avRuntime?.runtimeMetrics.metricsMessagesPublishFailures = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.peerMetricsMessagesDropped"
    )) {
        $0.avRuntime?.runtimeMetrics.peerMetricsMessagesDropped = 1
    }
}

@Test
func directPeerSessionAVPassAcceptsBGRAPixelFormatAlias() throws {
    var report = try avPassCandidate()
    report.avRuntime?.videoFormat?.outputPixelFormat = "bgra8"
    report.avRuntime?.receiveProof?.firstFrame.pixelFormat = "BGRA"
    report.avRuntime?.receiveProof?.latestFrame.pixelFormat = "BGRA"

    try report.validate()

    let receiveProof = try #require(report.avRuntime?.receiveProof)
    #expect(report.avRuntime?.videoFormat?.outputPixelFormat == "bgra8")
    #expect(receiveProof.firstFrame.pixelFormat == "BGRA")
    #expect(receiveProof.latestFrame.pixelFormat == "BGRA")
}

@Test
func directPeerSessionPassSchemaValidationDoesNotReadArtifactFiles() throws {
    let report = try avPassCandidate()

    try report.validate()
}

@Test
func directPeerSessionEvidenceBundleVerifierRejectsMissingArtifacts() throws {
    let report = try avPassCandidate()
    let bundleRoot = try makeDirectPeerSessionEvidenceBundleRoot()
    defer { try? FileManager.default.removeItem(at: bundleRoot) }

    let packetPath = bundleRoot
        .appendingPathComponent("reports/captures/direct-p2p-av-mac-b.pcapng")
        .standardizedFileURL
        .path
    #expect(throws: DirectPeerSessionEvidenceBundleVerificationError.artifactNotFound(
        field: "measuredEvidence.packetCapture",
        path: packetPath
    )) {
        _ = try DirectPeerSessionEvidenceBundleVerifier.verify(report: report, bundleRoot: bundleRoot)
    }
}

@Test
func directPeerSessionEvidenceBundleVerifierRejectsHashMismatch() throws {
    var report = try avPassCandidate()
    let bundleRoot = try makeDirectPeerSessionEvidenceBundleRoot()
    defer { try? FileManager.default.removeItem(at: bundleRoot) }
    try writeDirectPeerSessionEvidenceArtifacts(for: &report, under: bundleRoot)
    report.measuredEvidence?.dscp?.artifact.sha256 = String(repeating: "0", count: 64)

    let dscpPath = bundleRoot
        .appendingPathComponent("reports/evidence/dscp-observation.json")
        .standardizedFileURL
        .path
    let actual = directPeerSessionTestSHA256(Data("dscp evidence".utf8))
    #expect(throws: DirectPeerSessionEvidenceBundleVerificationError.artifactHashMismatch(
        field: "measuredEvidence.dscp.artifact",
        path: dscpPath,
        expected: String(repeating: "0", count: 64),
        actual: actual
    )) {
        _ = try DirectPeerSessionEvidenceBundleVerifier.verify(report: report, bundleRoot: bundleRoot)
    }
}

@Test
func directPeerSessionEvidenceBundleVerifierAcceptsMatchingArtifacts() throws {
    var report = try avPassCandidate()
    let bundleRoot = try makeDirectPeerSessionEvidenceBundleRoot()
    defer { try? FileManager.default.removeItem(at: bundleRoot) }
    try writeDirectPeerSessionEvidenceArtifacts(for: &report, under: bundleRoot)

    let verification = try DirectPeerSessionEvidenceBundleVerifier.verify(
        report: report,
        bundleRoot: bundleRoot
    )

    #expect(verification.reportID == report.id)
    #expect(verification.bundleRootPath == bundleRoot.standardizedFileURL.path)
    #expect(verification.verifiedArtifacts.map(\.field) == [
        "measuredEvidence.packetCapture",
        "measuredEvidence.dscp.artifact",
        "measuredEvidence.clock.artifact",
    ])
}

private func avPassCandidate() throws -> DirectPeerSessionReport {
    var report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: 2)
    directPeerSessionUsePhysicalEndpointHosts(&report)
    report.metrics.videoPacketsRouted = 2
    report.avRuntime = DirectPeerSessionAVRuntimeMetadata(
        avProfile: .balanced,
        previewMode: .on,
        mediaSourceMode: .production,
        qualityPolicy: .requireUsefulMedia,
        usefulMediaProof: .requiredAndProven,
        audioDeviceUID: "rme-madi-peer-a",
        inputDeviceUID: "rme-madi-peer-a",
        outputDeviceUID: "rme-madi-peer-a",
        sampleRateHertz: 48_000,
        selectedBufferFrameSize: 32,
        latencyProfile: .balancedAV,
        rxBufferProfile: .small,
        videoDeviceID: "blackmagic-peer-a",
        videoFrameRate: 30,
        videoStreamID: 7,
        fastestPassBlockedReason: "balanced profile selected for measured AV run",
        runtimeMetrics: DirectPeerSessionAVRuntimeMetrics(
            audioPayloadsCaptured: 2,
            audioPayloadsSent: 2,
            audioPayloadsQueuedForPlayout: 2,
            videoFramesCaptured: 2,
            videoFramesSent: 2,
            videoFragmentsSent: 4,
            videoFragmentsReceived: 4,
            videoFramesReassembled: 2,
            previewFramesSubmitted: 2,
            audioReceiveDrainIterations: 2,
            videoReceiveDrainIterations: 2
        ),
        videoFormat: avPassVideoFormat(),
        receiveProof: avPassReceiveProof()
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
        rawVideoReceiveEvidence: "receiver report recorded two BGRA frames from blackmagic-peer-a",
        durationSeconds: 30
    )
    report.verdict = .pass
    return report
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

private func expectDirectPeerSessionReportError(
    _ expected: DirectPeerSessionReportError,
    mutate: (inout DirectPeerSessionReport) throws -> Void
) throws {
    var report = try avPassCandidate()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func avPassVideoFormat() -> DirectPeerSessionVideoFormatReport {
    DirectPeerSessionVideoFormatReport(
        requestedDeviceID: "blackmagic-peer-a",
        selectedDeviceID: "blackmagic-peer-a",
        selectedDeviceLabel: "Blackmagic UltraStudio peer A",
        requestedFrameRate: 30,
        selectedWidth: 1_920,
        selectedHeight: 1_080,
        selectedPixelFormat: "BGRA",
        outputPixelFormat: "bgra8",
        selectedFrameRate: 30,
        sourcePolicy: .blackmagicFirstAvFoundationFallback
    )
}

private func avPassReceiveProof() -> DirectPeerSessionVideoReceiveProofArtifact {
    DirectPeerSessionVideoReceiveProofArtifact(
        framesProven: 2,
        previewFramesSubmitted: 2,
        firstFrame: avPassFrame(sequenceNumber: 11),
        latestFrame: avPassFrame(sequenceNumber: 12)
    )
}

private func avPassFrame(sequenceNumber: UInt64) -> DirectPeerSessionVideoFrameProof {
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

private func makeDirectPeerSessionEvidenceBundleRoot() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-direct-p2p-evidence-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeDirectPeerSessionEvidenceArtifacts(
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

private func writeDirectPeerSessionEvidenceArtifact(
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

private func directPeerSessionTestSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
