// Validates DirectPeerSessionReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
extension DirectPeerSessionReport {
    public func validate() throws {
        try validateBaseFields()
        try validateMetrics()
        if let avRuntime {
            try validateAVRuntime(avRuntime)
        }
        if let measuredEvidence {
            try validateMeasuredEvidence(measuredEvidence)
        }
        try requireDirectPeerSessionNonEmpty(notes, "notes")
        if verdict == .pass {
            try validatePassMeasuredEvidence()
        }
    }

    private func validateBaseFields() throws {
        try requireDirectPeerSessionNonEmpty(id, "id")
        try requireDirectPeerSessionNonEmpty(capturedAt, "capturedAt")
        try requireDirectPeerSessionNonEmpty(configuration.sessionID, "configuration.sessionID")
        guard let peerMediaEndpoints = configuration.peerMediaEndpoints,
              peerMediaEndpoints.count >= 2 else {
            throw DirectPeerSessionReportError.missingPeerMediaEndpoints
        }
        try configuration.validatePeerMediaTopology()
    }

    private func validateMetrics() throws {
        try validateCoreMetrics()
        try validateControlAndTimingMetrics()
        try validateRemoteMetrics()
    }

    private func validateCoreMetrics() throws {
        try requireDirectPeerSessionNonNegative(metrics.controlMessagesSent, "metrics.controlMessagesSent")
        try requireDirectPeerSessionNonNegative(metrics.packetsSent, "metrics.packetsSent")
        try requireDirectPeerSessionNonNegative(metrics.packetsReceived, "metrics.packetsReceived")
        try requireDirectPeerSessionNonNegative(metrics.packetsLost, "metrics.packetsLost")
        try requireDirectPeerSessionNonNegative(metrics.jitterMicroseconds, "metrics.jitterMicroseconds")
        try requireDirectPeerSessionNonNegative(metrics.audioPacketsRouted, "metrics.audioPacketsRouted")
        try requireDirectPeerSessionNonNegative(metrics.videoPacketsRouted, "metrics.videoPacketsRouted")
        try requireDirectPeerSessionNonNegative(metrics.recoveryEvents, "metrics.recoveryEvents")
        try requireDirectPeerSessionNonNegative(
            metrics.audioPayloadsSentOnControlChannel,
            "metrics.audioPayloadsSentOnControlChannel"
        )
    }

    private func validateControlAndTimingMetrics() throws {
        if let sent = metrics.controlDatagramsSent {
            try requireDirectPeerSessionNonNegative(sent, "metrics.controlDatagramsSent")
        }
        if let received = metrics.controlDatagramsReceived {
            try requireDirectPeerSessionNonNegative(received, "metrics.controlDatagramsReceived")
        }
        try requireDirectPeerSessionNonNegative(
            metrics.audioMetadataMessagesSent,
            "metrics.audioMetadataMessagesSent"
        )
        try requireDirectPeerSessionNonNegative(
            metrics.audioMetadataMessagesReceived,
            "metrics.audioMetadataMessagesReceived"
        )
        try requireDirectPeerSessionNonNegative(
            metrics.timingProbePacketsSent,
            "metrics.timingProbePacketsSent"
        )
        try requireDirectPeerSessionNonNegative(
            metrics.timingProbePacketsReceived,
            "metrics.timingProbePacketsReceived"
        )
        try requireDirectPeerSessionNonNegative(
            metrics.timingProbeMaxAgeMicroseconds,
            "metrics.timingProbeMaxAgeMicroseconds"
        )
    }

    private func validateRemoteMetrics() throws {
        try validateRemoteMetricsMessages()
        try validateRemoteNetworkMetrics()
        try validateRemoteRuntimeMetrics()
        try validateRemoteVideoMetrics()
    }

    private func validateRemoteMetricsMessages() throws {
        if let metricsMessagesSent = metrics.metricsMessagesSent {
            try requireDirectPeerSessionNonNegative(metricsMessagesSent, "metrics.metricsMessagesSent")
        }
        if let remoteMetricsMessagesReceived = metrics.remoteMetricsMessagesReceived {
            try requireDirectPeerSessionNonNegative(
                remoteMetricsMessagesReceived,
                "metrics.remoteMetricsMessagesReceived"
            )
        }
    }

    private func validateRemoteNetworkMetrics() throws {
        if let remotePacketsLost = metrics.remotePacketsLost {
            try requireDirectPeerSessionNonNegative(remotePacketsLost, "metrics.remotePacketsLost")
        }
        if let remoteJitterMicroseconds = metrics.remoteJitterMicroseconds {
            try requireDirectPeerSessionNonNegative(remoteJitterMicroseconds, "metrics.remoteJitterMicroseconds")
        }
        if let remoteLatePackets = metrics.remoteLatePackets {
            try requireDirectPeerSessionNonNegative(remoteLatePackets, "metrics.remoteLatePackets")
        }
    }

    private func validateRemoteRuntimeMetrics() throws {
        if let remoteCallbackDurationP99Microseconds = metrics.remoteCallbackDurationP99Microseconds {
            try requireDirectPeerSessionNonNegative(
                remoteCallbackDurationP99Microseconds,
                "metrics.remoteCallbackDurationP99Microseconds"
            )
        }
        if let remoteQueueDepthPackets = metrics.remoteQueueDepthPackets {
            try requireDirectPeerSessionNonNegative(remoteQueueDepthPackets, "metrics.remoteQueueDepthPackets")
        }
        if let remoteCPUPercent = metrics.remoteCPUPercent {
            try requireDirectPeerSessionNonNegative(remoteCPUPercent, "metrics.remoteCPUPercent")
        }
        if let remoteUnderruns = metrics.remoteUnderruns {
            try requireDirectPeerSessionNonNegative(remoteUnderruns, "metrics.remoteUnderruns")
        }
        if let remoteOverruns = metrics.remoteOverruns {
            try requireDirectPeerSessionNonNegative(remoteOverruns, "metrics.remoteOverruns")
        }
    }

    private func validateRemoteVideoMetrics() throws {
        if let remoteVideoFramesDropped = metrics.remoteVideoFramesDropped {
            try requireDirectPeerSessionNonNegative(remoteVideoFramesDropped, "metrics.remoteVideoFramesDropped")
        }
    }

private func validateAVRuntime(_ avRuntime: DirectPeerSessionAVRuntimeMetadata) throws {
    try requireDirectPeerSessionNonEmpty(avRuntime.audioDeviceUID, "avRuntime.audioDeviceUID")
    try requireDirectPeerSessionNonEmpty(avRuntime.inputDeviceUID, "avRuntime.inputDeviceUID")
    try requireDirectPeerSessionNonEmpty(avRuntime.outputDeviceUID, "avRuntime.outputDeviceUID")
    try requireDirectPeerSessionNonEmpty(avRuntime.videoDeviceID, "avRuntime.videoDeviceID")
        try requireDirectPeerSessionNonEmpty(
            avRuntime.fastestPassBlockedReason,
            "avRuntime.fastestPassBlockedReason"
        )
        try requireDirectPeerSessionNonNegative(avRuntime.sampleRateHertz, "avRuntime.sampleRateHertz")
        try requireDirectPeerSessionNonNegative(
        avRuntime.selectedBufferFrameSize,
        "avRuntime.selectedBufferFrameSize"
    )
    try validateAVRuntimeOpusTransport(avRuntime)
    try validateAVRuntimeAoIPTransport(avRuntime)
    try requireDirectPeerSessionNonNegative(avRuntime.videoFrameRate, "avRuntime.videoFrameRate")
    try requireDirectPeerSessionNonNegative(avRuntime.videoStreamID, "avRuntime.videoStreamID")
    try validateAVRuntimeMetrics(avRuntime.runtimeMetrics)
    if let videoFormat = avRuntime.videoFormat {
        try validateDirectPeerSessionVideoFormat(videoFormat)
    }
    if let receiveProof = avRuntime.receiveProof {
        try validateDirectPeerSessionVideoReceiveProof(receiveProof)
    }
    try validateDirectPeerSessionAVRuntimeUsefulMediaProof(avRuntime)
}

private func validateAVRuntimeOpusTransport(_ avRuntime: DirectPeerSessionAVRuntimeMetadata) throws {
    if avRuntime.audioTransport == .openLolaOpusCeltLowDelay {
        try requireDirectPeerSessionPositiveReportValue(
            avRuntime.opusBitrateBitsPerSecond ?? 0,
            "avRuntime.opusBitrateBitsPerSecond"
            )
            try requireDirectPeerSessionPositiveReportValue(
                avRuntime.opusFrameDurationMilliseconds ?? 0,
            "avRuntime.opusFrameDurationMilliseconds"
        )
    }
}

private func validateAVRuntimeAoIPTransport(_ avRuntime: DirectPeerSessionAVRuntimeMetadata) throws {
    if avRuntime.audioTransport == .aes67ST2110L24 {
        try requireDirectPeerSessionNonEmpty(avRuntime.aoipProfile ?? "", "avRuntime.aoipProfile")
        try requireDirectPeerSessionPositiveReportValue(
            Int(avRuntime.rtpPayloadType ?? 0),
            "avRuntime.rtpPayloadType"
            )
            try requireDirectPeerSessionPositiveReportValue(avRuntime.rtpClockRate ?? 0, "avRuntime.rtpClockRate")
            try requireDirectPeerSessionPositiveReportValue(
                avRuntime.rtpPacketTimeMilliseconds ?? 0,
                "avRuntime.rtpPacketTimeMilliseconds"
            )
            try requireDirectPeerSessionPositiveReportValue(Int(avRuntime.rtpSSRC ?? 0), "avRuntime.rtpSSRC")
            if let sdpPath = avRuntime.sdpPath {
            try requireDirectPeerSessionNonEmpty(sdpPath, "avRuntime.sdpPath")
        }
    }
}

    private func validatePassMeasuredEvidence() throws {
        let measuredEvidence = try requirePassMeasuredEvidence()
        try validatePassPeerMediaEndpoints()
        try validatePassMeasuredEvidenceArtifacts(measuredEvidence)
        try validatePassMediaCounters()
        try validatePassAVRuntimeIfPresent(measuredEvidence)
    }

    private func requirePassMeasuredEvidence() throws -> DirectPeerSessionMeasuredEvidence {
        guard let measuredEvidence else {
            throw DirectPeerSessionReportError.passRequiresDirectLanManualAddressEvidence
        }
        guard measuredEvidence.kind == .physicalTwoPeerMacs else {
            throw DirectPeerSessionReportError.passRequiresPhysicalTwoPeerEvidence(measuredEvidence.kind)
        }
        return measuredEvidence
    }

    private func validatePassMeasuredEvidenceArtifacts(_ measuredEvidence: DirectPeerSessionMeasuredEvidence) throws {
        try requireDirectPeerSessionPassEvidenceArtifact(
            measuredEvidence.packetCapture,
            "measuredEvidence.packetCapture",
            allowedExtensions: ["pcap", "pcapng"]
        )
        let dscp = try requireDirectPeerSessionPassDSCPEvidence(measuredEvidence.dscp)
        try requireDirectPeerSessionPassEvidenceArtifact(
            dscp.artifact,
            "measuredEvidence.dscp.artifact",
            allowedExtensions: ["json", "pcap", "pcapng"]
        )
        try requireDirectPeerSessionPassEvidenceArtifact(
            measuredEvidence.clock?.artifact,
            "measuredEvidence.clock.artifact",
            allowedExtensions: ["json", "txt", "log"]
        )
    }

    private func validatePassMediaCounters() throws {
        try requireDirectPeerSessionPositive(metrics.packetsSent, "metrics.packetsSent")
        try requireDirectPeerSessionPositive(metrics.packetsReceived, "metrics.packetsReceived")
        try requireDirectPeerSessionPositive(metrics.audioPacketsRouted, "metrics.audioPacketsRouted")
        try validatePassTransportMetrics()
    }

    private func validatePassAVRuntimeIfPresent(_ measuredEvidence: DirectPeerSessionMeasuredEvidence) throws {
        guard let avRuntime else {
            return
        }
        try validatePassAVRuntimeIdentity(avRuntime)
        try validatePassAVRuntimeAudio(avRuntime)
        try validatePassAVRuntimeVideo(avRuntime, measuredEvidence: measuredEvidence)
        try validatePassFastestAVBaselineIfNeeded(avRuntime)
        try validatePassAoIPIfNeeded(avRuntime, measuredEvidence: measuredEvidence)
    }

    private func validatePassAVRuntimeIdentity(_ avRuntime: DirectPeerSessionAVRuntimeMetadata) throws {
        try requireDirectPeerSessionPassUsefulMediaProof(avRuntime)
        guard avRuntime.mediaSourceMode == .production else {
            throw DirectPeerSessionReportError.passRequiresProductionMediaSourceMode(avRuntime.mediaSourceMode)
        }
        guard avRuntime.videoFormat != nil else {
            throw DirectPeerSessionReportError.passRequiresVideoFormat
        }
        guard avRuntime.receiveProof != nil else {
            throw DirectPeerSessionReportError.passRequiresVideoReceiveProof
        }
    }

    private func validatePassAVRuntimeAudio(_ avRuntime: DirectPeerSessionAVRuntimeMetadata) throws {
        let runtime = avRuntime.runtimeMetrics
        try requireDirectPeerSessionPositive(metrics.videoPacketsRouted, "metrics.videoPacketsRouted")
        try requireDirectPeerSessionPositive(
            runtime.audioPayloadsSent,
            "avRuntime.runtimeMetrics.audioPayloadsSent"
        )
        try requireDirectPeerSessionPositive(
            runtime.audioPayloadsQueuedForPlayout,
            "avRuntime.runtimeMetrics.audioPayloadsQueuedForPlayout"
        )
        try validatePassAVRuntimeMetrics(runtime)
        try validatePassAVRuntimeCallbackTiming(avRuntime)
    }

    private func validatePassAVRuntimeVideo(
        _ avRuntime: DirectPeerSessionAVRuntimeMetadata,
        measuredEvidence: DirectPeerSessionMeasuredEvidence
    ) throws {
        let runtime = avRuntime.runtimeMetrics
        try requireDirectPeerSessionPositive(
            runtime.videoFramesCaptured,
            "avRuntime.runtimeMetrics.videoFramesCaptured"
        )
        try requireDirectPeerSessionPositive(runtime.videoFramesSent, "avRuntime.runtimeMetrics.videoFramesSent")
        try requireDirectPeerSessionPositive(
            runtime.videoFragmentsReceived,
            "avRuntime.runtimeMetrics.videoFragmentsReceived"
        )
        try requireDirectPeerSessionPositive(
            runtime.videoFramesReassembled,
            "avRuntime.runtimeMetrics.videoFramesReassembled"
        )
        try requireDirectPeerSessionNonPlaceholder(
            measuredEvidence.rawVideoReceiveEvidence,
            "measuredEvidence.rawVideoReceiveEvidence"
        )
        if avRuntime.previewMode == .on {
            try requireDirectPeerSessionPositive(
                runtime.previewFramesSubmitted,
                "avRuntime.runtimeMetrics.previewFramesSubmitted"
            )
        }
        if let receiveProof = avRuntime.receiveProof, let videoFormat = avRuntime.videoFormat {
            try validatePassVideoProof(receiveProof, format: videoFormat, runtime: avRuntime)
        }
    }

    private func validatePassFastestAVBaselineIfNeeded(_ avRuntime: DirectPeerSessionAVRuntimeMetadata) throws {
        if avRuntime.avProfile == .fastest {
            guard avRuntime.audioTransport == .openLolaRaw else {
                throw DirectPeerSessionReportError.passWithFailedFastestAVBaselineComparison("avRuntime.audioTransport")
            }
            try validatePassFastestAVBaselineComparison(avRuntime.fastestAVBaselineComparison)
        }
    }

    private func validatePassAoIPIfNeeded(
        _ avRuntime: DirectPeerSessionAVRuntimeMetadata,
        measuredEvidence: DirectPeerSessionMeasuredEvidence
    ) throws {
        if avRuntime.audioTransport == .aes67ST2110L24 {
            try validatePassAoIPPTPEvidence(avRuntime: avRuntime, measuredEvidence: measuredEvidence)
        }
    }

}
