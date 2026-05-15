import Testing

@testable import OpenLolaCore

@Test
func directPeerSessionAVPassRejectsSyntheticMediaSourceMode() throws {
    var report = try avPassCandidate()
    report.avRuntime?.mediaSourceMode = .syntheticFixture

    #expect(throws: DirectPeerSessionReportError.passRequiresProductionMediaSourceMode(.syntheticFixture)) {
        try report.validate()
    }
}

@Test
func directPeerSessionAVPassRequiresVideoFormat() throws {
    var report = try avPassCandidate()
    report.avRuntime?.videoFormat = nil

    #expect(throws: DirectPeerSessionReportError.passRequiresVideoFormat) {
        try report.validate()
    }
}

@Test
func directPeerSessionAVPassRequiresReceiveProof() throws {
    var report = try avPassCandidate()
    report.avRuntime?.receiveProof = nil

    #expect(throws: DirectPeerSessionReportError.passRequiresVideoReceiveProof) {
        try report.validate()
    }
}

@Test
func directPeerSessionAVPassRequiresProofFrameCountToMatchRuntime() throws {
    var report = try avPassCandidate()
    report.avRuntime?.receiveProof?.framesProven = 1

    #expect(throws: DirectPeerSessionReportError.passWithInconsistentVideoProof(
        "avRuntime.receiveProof.framesProven"
    )) {
        try report.validate()
    }
}

@Test
func directPeerSessionAVPassAccountsForVideoFramesDroppedOutsideAudioWindow() throws {
    var report = try avPassCandidate()
    report.avRuntime?.runtimeMetrics.videoFramesDroppedOutsideAudioWindow = 1

    #expect(throws: DirectPeerSessionReportError.passWithInconsistentVideoProof(
        "avRuntime.receiveProof.framesProven"
    )) {
        try report.validate()
    }
}

@Test
func directPeerSessionAVPassRequiresProofDimensionsToMatchFormat() throws {
    var report = try avPassCandidate()
    report.avRuntime?.receiveProof?.latestFrame.width = 1_919

    #expect(throws: DirectPeerSessionReportError.passWithInconsistentVideoProof(
        "avRuntime.receiveProof.latestFrame.width"
    )) {
        try report.validate()
    }
}

@Test
func directPeerSessionAVPassRequiresProofPayloadToMatchFormat() throws {
    var report = try avPassCandidate()
    report.avRuntime?.receiveProof?.firstFrame.payloadByteCount = 1_920 * 1_080

    #expect(throws: DirectPeerSessionReportError.passWithInconsistentVideoProof(
        "avRuntime.receiveProof.firstFrame.payloadByteCount"
    )) {
        try report.validate()
    }
}

@Test
func directPeerSessionAVPassRejectsPaddedPayloadWhenFormatIsNormalized() throws {
    var report = try avPassCandidate()
    report.avRuntime?.receiveProof?.latestFrame.payloadByteCount = (1_920 * 4 + 64) * 1_080

    #expect(throws: DirectPeerSessionReportError.passWithInconsistentVideoProof(
        "avRuntime.receiveProof.latestFrame.payloadByteCount"
    )) {
        try report.validate()
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
func directPeerSessionAVPassRequiresPayloadDigest() throws {
    var report = try avPassCandidate()
    report.avRuntime?.receiveProof?.latestFrame.payloadDigest = nil

    #expect(throws: DirectPeerSessionReportError.passWithInconsistentVideoProof(
        "avRuntime.receiveProof.latestFrame.payloadDigest"
    )) {
        try report.validate()
    }
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
func directPeerSessionAVPassRequiresStructuredPacketCaptureArtifact() throws {
    var report = try avPassCandidate()
    report.measuredEvidence?.packetCapture = nil

    #expect(throws: DirectPeerSessionReportError.passRequiresStructuredEvidence(
        "measuredEvidence.packetCapture"
    )) {
        try report.validate()
    }
}

@Test
func directPeerSessionAVPassRejectsUncapturedDSCPArtifact() throws {
    var report = try avPassCandidate()
    report.measuredEvidence?.dscp?.artifact.captured = false

    #expect(throws: DirectPeerSessionReportError.passWithInvalidEvidenceArtifact(
        "measuredEvidence.dscp.artifact.captured"
    )) {
        try report.validate()
    }
}

@Test
func directPeerSessionFastestAVPassRequiresBaselineComparison() throws {
    var report = try avPassCandidate()
    report.avRuntime?.avProfile = .fastest
    report.avRuntime?.latencyProfile = .directAudioFirst
    report.avRuntime?.rxBufferProfile = .direct

    #expect(throws: DirectPeerSessionReportError.passRequiresFastestAVBaselineComparison) {
        try report.validate()
    }
}

@Test
func directPeerSessionFastestAVPassRejectsBaselineRegression() throws {
    var report = try avPassCandidate()
    report.avRuntime?.avProfile = .fastest
    report.avRuntime?.latencyProfile = .directAudioFirst
    report.avRuntime?.rxBufferProfile = .direct
    report.avRuntime?.fastestAVBaselineComparison = directPeerSessionFastestAVBaselineComparison()
    report.avRuntime?.fastestAVBaselineComparison?.audioLatencyEqualToBaseline = false

    #expect(throws: DirectPeerSessionReportError.passWithFailedFastestAVBaselineComparison(
        "avRuntime.fastestAVBaselineComparison.audioLatencyEqualToBaseline"
    )) {
        try report.validate()
    }
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
