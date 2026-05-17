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
    try expectDirectPeerSessionReportError(.passWithInconsistentVideoProof(
        "avRuntime.receiveProof.framesProven"
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
        "measuredEvidence.dscp.artifact.captured"
    )) {
        $0.measuredEvidence?.dscp?.artifact.captured = false
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

private func avPassCandidate() throws -> DirectPeerSessionReport {
    var report = try DirectPeerSessionSocketRunner.runLoopback(packetCount: 2)
    report.metrics.videoPacketsRouted = 2
    report.avRuntime = DirectPeerSessionAVRuntimeMetadata(
        avProfile: .balanced,
        previewMode: .on,
        mediaSourceMode: .production,
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
