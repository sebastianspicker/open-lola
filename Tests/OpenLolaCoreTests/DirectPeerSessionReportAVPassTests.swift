// Verifies that direct peer session AV pass rejects invalid pass evidence.
import CryptoKit
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionAVPassRejectsInvalidPassEvidence() throws {
    try directPeerSessionAVPassRejectsMissingPassEvidence()
    try directPeerSessionAVPassRejectsVideoProofMismatch()
    try directPeerSessionAVPassRejectsMeasuredEvidenceMismatch()
}

private func directPeerSessionAVPassRejectsMissingPassEvidence() throws {
    try expectDirectPeerSessionReportError(.passRequiresProductionMediaSourceMode(.syntheticFixture)) {
        $0.avRuntime?.mediaSourceMode = .syntheticFixture
    }
    try expectDirectPeerSessionReportError(.passRequiresVideoFormat) {
        $0.avRuntime?.videoFormat = nil
    }
    try expectDirectPeerSessionReportError(.passRequiresVideoReceiveProof) {
        $0.avRuntime?.receiveProof = nil
    }
}

private func directPeerSessionAVPassRejectsVideoProofMismatch() throws {
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
}

private func directPeerSessionAVPassRejectsMeasuredEvidenceMismatch() throws {
    try directPeerSessionAVPassRejectsMeasuredArtifactEvidenceMismatch()
    try directPeerSessionAVPassRejectsDSCPAndBaselineEvidenceMismatch()
}

private func directPeerSessionAVPassRejectsMeasuredArtifactEvidenceMismatch() throws {
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
}

private func directPeerSessionAVPassRejectsDSCPAndBaselineEvidenceMismatch() throws {
    for weakClassification in [
        DirectPeerSessionDSCPClassification.rewritten,
        .ignored,
        .harmful
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
    try directPeerSessionAVPassRejectsReportDegradationCounters()
    try directPeerSessionAVPassRejectsAudioDegradationCounters()
    try directPeerSessionAVPassRejectsVideoDegradationCounters()
}

private func directPeerSessionAVPassRejectsReportDegradationCounters() throws {
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation("metrics.packetsLost")) {
        $0.metrics.packetsLost = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation("metrics.recoveryEvents")) {
        $0.metrics.recoveryEvents = 1
    }
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation("metrics.remoteUnderruns")) {
        $0.metrics.remoteUnderruns = 1
    }
}

private func directPeerSessionAVPassRejectsAudioDegradationCounters() throws {
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
            packetCounters: .init(lostPackets: 1)
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
}

private func directPeerSessionAVPassRejectsVideoDegradationCounters() throws {
    try expectDirectPeerSessionReportError(.passWithRuntimeDegradation(
        "avRuntime.runtimeMetrics.videoFramesDroppedBeforeSend"
    )) {
        $0.avRuntime?.runtimeMetrics.videoFramesDroppedBeforeSend = 1
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
        "measuredEvidence.clock.artifact"
    ])
}
