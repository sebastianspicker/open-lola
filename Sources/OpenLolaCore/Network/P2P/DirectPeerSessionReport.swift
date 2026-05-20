import Foundation

public struct DirectPeerSessionReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var configuration: SessionConfiguration
    public var metrics: DirectPeerSessionReportMetrics
    public var avRuntime: DirectPeerSessionAVRuntimeMetadata?
    public var measuredEvidence: DirectPeerSessionMeasuredEvidence?
    public var verdict: MeasurementVerdict
    public var notes: String

    public init(
        id: String,
        capturedAt: String,
        configuration: SessionConfiguration,
        metrics: DirectPeerSessionReportMetrics,
        avRuntime: DirectPeerSessionAVRuntimeMetadata? = nil,
        measuredEvidence: DirectPeerSessionMeasuredEvidence? = nil,
        verdict: MeasurementVerdict,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.configuration = configuration
        self.metrics = metrics
        self.avRuntime = avRuntime
        self.measuredEvidence = measuredEvidence
        self.verdict = verdict
        self.notes = notes
    }

    public static func decode(from data: Data) throws -> DirectPeerSessionReport {
        try JSONDecoder().decode(DirectPeerSessionReport.self, from: data)
    }

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
        if let metricsMessagesSent = metrics.metricsMessagesSent {
            try requireDirectPeerSessionNonNegative(metricsMessagesSent, "metrics.metricsMessagesSent")
        }
        if let remoteMetricsMessagesReceived = metrics.remoteMetricsMessagesReceived {
            try requireDirectPeerSessionNonNegative(
                remoteMetricsMessagesReceived,
                "metrics.remoteMetricsMessagesReceived"
            )
        }
        if let remotePacketsLost = metrics.remotePacketsLost {
            try requireDirectPeerSessionNonNegative(remotePacketsLost, "metrics.remotePacketsLost")
        }
        if let remoteJitterMicroseconds = metrics.remoteJitterMicroseconds {
            try requireDirectPeerSessionNonNegative(remoteJitterMicroseconds, "metrics.remoteJitterMicroseconds")
        }
        if let remoteLatePackets = metrics.remoteLatePackets {
            try requireDirectPeerSessionNonNegative(remoteLatePackets, "metrics.remoteLatePackets")
        }
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
        if avRuntime.audioTransport == .aes67ST2110L24 {
            try requireDirectPeerSessionNonEmpty(avRuntime.aoipProfile ?? "", "avRuntime.aoipProfile")
            try requireDirectPeerSessionPositiveReportValue(Int(avRuntime.rtpPayloadType ?? 0), "avRuntime.rtpPayloadType")
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
        try requireDirectPeerSessionNonNegative(avRuntime.videoFrameRate, "avRuntime.videoFrameRate")
        try requireDirectPeerSessionNonNegative(avRuntime.videoStreamID, "avRuntime.videoStreamID")
        try validateAVRuntimeMetrics(avRuntime.runtimeMetrics)
        if let videoFormat = avRuntime.videoFormat {
            try validateDirectPeerSessionVideoFormat(videoFormat)
        }
        if let receiveProof = avRuntime.receiveProof {
            try validateDirectPeerSessionVideoReceiveProof(receiveProof)
        }
    }

    private func validatePassMeasuredEvidence() throws {
        guard let measuredEvidence else {
            throw DirectPeerSessionReportError.passRequiresDirectLanManualAddressEvidence
        }
        guard measuredEvidence.kind == .physicalTwoPeerMacs else {
            throw DirectPeerSessionReportError.passRequiresPhysicalTwoPeerEvidence(measuredEvidence.kind)
        }
        try validatePassPeerMediaEndpoints()
        try requireDirectPeerSessionPassEvidenceArtifact(
            measuredEvidence.packetCapture,
            "measuredEvidence.packetCapture",
            allowedExtensions: ["pcap", "pcapng"]
        )
        try requireDirectPeerSessionPassEvidenceArtifact(
            measuredEvidence.dscp?.artifact,
            "measuredEvidence.dscp.artifact",
            allowedExtensions: ["json", "pcap", "pcapng"]
        )
        try requireDirectPeerSessionPassEvidenceArtifact(
            measuredEvidence.clock?.artifact,
            "measuredEvidence.clock.artifact",
            allowedExtensions: ["json", "txt", "log"]
        )
        try requireDirectPeerSessionPositive(metrics.packetsSent, "metrics.packetsSent")
        try requireDirectPeerSessionPositive(metrics.packetsReceived, "metrics.packetsReceived")
        try requireDirectPeerSessionPositive(metrics.audioPacketsRouted, "metrics.audioPacketsRouted")
        try validatePassTransportMetrics()
        if let avRuntime {
            let runtime = avRuntime.runtimeMetrics
            guard avRuntime.mediaSourceMode == .production else {
                throw DirectPeerSessionReportError.passRequiresProductionMediaSourceMode(avRuntime.mediaSourceMode)
            }
            guard let videoFormat = avRuntime.videoFormat else {
                throw DirectPeerSessionReportError.passRequiresVideoFormat
            }
            guard let receiveProof = avRuntime.receiveProof else {
                throw DirectPeerSessionReportError.passRequiresVideoReceiveProof
            }
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
            try requireDirectPeerSessionPositive(
                runtime.videoFramesCaptured,
                "avRuntime.runtimeMetrics.videoFramesCaptured"
            )
            try requireDirectPeerSessionPositive(
                runtime.videoFramesSent,
                "avRuntime.runtimeMetrics.videoFramesSent"
            )
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
            try validatePassVideoProof(
                receiveProof,
                format: videoFormat,
                runtime: avRuntime
            )
            if avRuntime.avProfile == .fastest {
                guard avRuntime.audioTransport == .openLolaRaw else {
                    throw DirectPeerSessionReportError.passWithFailedFastestAVBaselineComparison("avRuntime.audioTransport")
                }
                try validatePassFastestAVBaselineComparison(avRuntime.fastestAVBaselineComparison)
            }
            if avRuntime.audioTransport == .aes67ST2110L24 {
                try validatePassAoIPPTPEvidence(avRuntime: avRuntime, measuredEvidence: measuredEvidence)
            }
        }
    }

    private func validatePassPeerMediaEndpoints() throws {
        try requireDirectPeerSessionNonLoopbackEndpoint(
            configuration.controlEndpoint,
            "configuration.controlEndpoint.host"
        )
        try requireDirectPeerSessionNonLoopbackEndpoint(
            configuration.audioEndpoint,
            "configuration.audioEndpoint.host"
        )
        try requireDirectPeerSessionNonLoopbackEndpoint(
            configuration.videoEndpoint,
            "configuration.videoEndpoint.host"
        )
        try requireDirectPeerSessionNonLoopbackEndpoint(
            configuration.metricsEndpoint,
            "configuration.metricsEndpoint.host"
        )
        for endpoint in configuration.peerMediaEndpoints ?? [] {
            try requireDirectPeerSessionNonLoopbackEndpoint(
                endpoint.controlEndpoint,
                "configuration.peerMediaEndpoints.\(endpoint.peerID).controlEndpoint.host"
            )
            try requireDirectPeerSessionNonLoopbackEndpoint(
                endpoint.audioEndpoint,
                "configuration.peerMediaEndpoints.\(endpoint.peerID).audioEndpoint.host"
            )
            try requireDirectPeerSessionNonLoopbackEndpoint(
                endpoint.videoEndpoint,
                "configuration.peerMediaEndpoints.\(endpoint.peerID).videoEndpoint.host"
            )
            try requireDirectPeerSessionNonLoopbackEndpoint(
                endpoint.metricsEndpoint,
                "configuration.peerMediaEndpoints.\(endpoint.peerID).metricsEndpoint.host"
            )
        }
    }

    private func validatePassTransportMetrics() throws {
        try requireDirectPeerSessionNoPassDegradation(metrics.packetsLost, "metrics.packetsLost")
        try requireDirectPeerSessionNoPassDegradation(metrics.recoveryEvents, "metrics.recoveryEvents")
        try requireDirectPeerSessionNoPassDegradation(
            metrics.audioPayloadsSentOnControlChannel,
            "metrics.audioPayloadsSentOnControlChannel"
        )
        try requireDirectPeerSessionNoPassDegradation(metrics.remotePacketsLost, "metrics.remotePacketsLost")
        try requireDirectPeerSessionNoPassDegradation(metrics.remoteLatePackets, "metrics.remoteLatePackets")
        try requireDirectPeerSessionNoPassDegradation(metrics.remoteUnderruns, "metrics.remoteUnderruns")
        try requireDirectPeerSessionNoPassDegradation(metrics.remoteOverruns, "metrics.remoteOverruns")
        try requireDirectPeerSessionNoPassDegradation(
            metrics.remoteVideoFramesDropped,
            "metrics.remoteVideoFramesDropped"
        )
    }

    private func validatePassAVRuntimeMetrics(_ metrics: DirectPeerSessionAVRuntimeMetrics) throws {
        let degradationCounters: [(Int, String)] = [
            (metrics.audioPayloadsDroppedBeforeSend, "avRuntime.runtimeMetrics.audioPayloadsDroppedBeforeSend"),
            (metrics.audioTXBudgetExhaustions, "avRuntime.runtimeMetrics.audioTXBudgetExhaustions"),
            (metrics.audioPayloadsDroppedBeforePlayout, "avRuntime.runtimeMetrics.audioPayloadsDroppedBeforePlayout"),
            (metrics.audioPayloadsDroppedByPlayoutQueue, "avRuntime.runtimeMetrics.audioPayloadsDroppedByPlayoutQueue"),
            (metrics.audioUnexpectedPayloadTypes, "avRuntime.runtimeMetrics.audioUnexpectedPayloadTypes"),
            (metrics.audioPlayoutUnderruns, "avRuntime.runtimeMetrics.audioPlayoutUnderruns"),
            (metrics.audioCallbackDeadlineMisses, "avRuntime.runtimeMetrics.audioCallbackDeadlineMisses"),
            (metrics.audioCallbackOverruns, "avRuntime.runtimeMetrics.audioCallbackOverruns"),
            (metrics.audioHostTimeConversionFailures, "avRuntime.runtimeMetrics.audioHostTimeConversionFailures"),
            (metrics.videoFragmentsDroppedCorrupt, "avRuntime.runtimeMetrics.videoFragmentsDroppedCorrupt"),
            (metrics.videoFragmentsDroppedOversize, "avRuntime.runtimeMetrics.videoFragmentsDroppedOversize"),
            (metrics.videoUnexpectedPayloadTypes, "avRuntime.runtimeMetrics.videoUnexpectedPayloadTypes"),
            (metrics.videoFramesDroppedDuringReassembly, "avRuntime.runtimeMetrics.videoFramesDroppedDuringReassembly"),
            (metrics.videoReassemblyMissingFragments, "avRuntime.runtimeMetrics.videoReassemblyMissingFragments"),
            (metrics.videoReassemblyLateFragments, "avRuntime.runtimeMetrics.videoReassemblyLateFragments"),
            (metrics.videoReassemblyDuplicateFragments, "avRuntime.runtimeMetrics.videoReassemblyDuplicateFragments"),
            (metrics.previewFramesDropped, "avRuntime.runtimeMetrics.previewFramesDropped"),
            (metrics.previewFramesFailed, "avRuntime.runtimeMetrics.previewFramesFailed"),
            (metrics.videoFramesDroppedOutsideAudioWindow, "avRuntime.runtimeMetrics.videoFramesDroppedOutsideAudioWindow"),
            (metrics.videoFramesDroppedForSync, "avRuntime.runtimeMetrics.videoFramesDroppedForSync"),
            (metrics.metricsMessagesPublishFailures, "avRuntime.runtimeMetrics.metricsMessagesPublishFailures"),
            (metrics.peerMetricsMessagesDropped, "avRuntime.runtimeMetrics.peerMetricsMessagesDropped"),
        ]
        for (value, field) in degradationCounters {
            try requireDirectPeerSessionNoPassDegradation(value, field)
        }
        if let audioRXBuffer = metrics.audioRXBuffer {
            try validatePassAudioRXBuffer(audioRXBuffer)
        }
    }

    private func validatePassAVRuntimeCallbackTiming(_ runtime: DirectPeerSessionAVRuntimeMetadata) throws {
        let periodMicroseconds = Double(runtime.selectedBufferFrameSize) * 1_000_000 / Double(runtime.sampleRateHertz)
        if Double(runtime.runtimeMetrics.audioCallbackMaxMicroseconds) > periodMicroseconds {
            throw DirectPeerSessionReportError.passWithRuntimeDegradation(
                "avRuntime.runtimeMetrics.audioCallbackMaxMicroseconds"
            )
        }
    }

    private func validatePassAudioRXBuffer(_ snapshot: RxBufferRuntimeSnapshot) throws {
        try requireDirectPeerSessionNoPassDegradation(snapshot.latePackets, "avRuntime.runtimeMetrics.audioRXBuffer.latePackets")
        try requireDirectPeerSessionNoPassDegradation(snapshot.lostPackets, "avRuntime.runtimeMetrics.audioRXBuffer.lostPackets")
        try requireDirectPeerSessionNoPassDegradation(
            snapshot.fragmentLostPackets,
            "avRuntime.runtimeMetrics.audioRXBuffer.fragmentLostPackets"
        )
        try requireDirectPeerSessionNoPassDegradation(
            snapshot.duplicatePackets,
            "avRuntime.runtimeMetrics.audioRXBuffer.duplicatePackets"
        )
        try requireDirectPeerSessionNoPassDegradation(
            snapshot.reorderedPackets,
            "avRuntime.runtimeMetrics.audioRXBuffer.reorderedPackets"
        )
        try requireDirectPeerSessionNoPassDegradation(snapshot.underruns, "avRuntime.runtimeMetrics.audioRXBuffer.underruns")
        try requireDirectPeerSessionNoPassDegradation(snapshot.overruns, "avRuntime.runtimeMetrics.audioRXBuffer.overruns")
        try requireDirectPeerSessionNoPassDegradation(snapshot.plcEvents, "avRuntime.runtimeMetrics.audioRXBuffer.plcEvents")
        if snapshot.hiddenGrowthDetected {
            throw DirectPeerSessionReportError.passWithRuntimeDegradation(
                "avRuntime.runtimeMetrics.audioRXBuffer.hiddenGrowthDetected"
            )
        }
    }
}

func requireDirectPeerSessionConfiguration(
    _ configuration: SessionConfiguration?
) throws -> SessionConfiguration {
    guard let configuration else {
        throw DirectPeerSessionReportError.missingAcceptedConfiguration
    }
    return configuration
}

private func requireDirectPeerSessionNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw DirectPeerSessionReportError.emptyField(field)
    }
}

private func requireDirectPeerSessionNonNegative(_ value: Int, _ field: String) throws {
    if value < 0 {
        throw DirectPeerSessionReportError.negativeMetric(field)
    }
}

private func requireDirectPeerSessionPositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw DirectPeerSessionReportError.passWithoutRoutedMedia(field)
    }
}

private func requireDirectPeerSessionNoPassDegradation(_ value: Int, _ field: String) throws {
    if value > 0 {
        throw DirectPeerSessionReportError.passWithRuntimeDegradation(field)
    }
}

private func requireDirectPeerSessionNoPassDegradation(_ value: Int?, _ field: String) throws {
    if let value {
        try requireDirectPeerSessionNoPassDegradation(value, field)
    }
}

private func requireDirectPeerSessionNonLoopbackEndpoint(
    _ endpoint: SessionNetworkEndpoint,
    _ field: String
) throws {
    if directPeerSessionIsLoopbackHost(endpoint.host) {
        throw DirectPeerSessionReportError.passRequiresNonLoopbackPeerEndpoint(field)
    }
}

private func requireDirectPeerSessionNonNegative(_ value: Double, _ field: String) throws {
    if value < 0 || !value.isFinite {
        throw DirectPeerSessionReportError.negativeMetric(field)
    }
}

private func requireDirectPeerSessionPositiveReportValue(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw DirectPeerSessionReportError.negativeMetric(field)
    }
}

private func requireDirectPeerSessionPositiveReportValue(_ value: Double, _ field: String) throws {
    if value <= 0 || !value.isFinite {
        throw DirectPeerSessionReportError.negativeMetric(field)
    }
}

private func validateDirectPeerSessionVideoFormat(_ report: DirectPeerSessionVideoFormatReport) throws {
    try requireDirectPeerSessionNonEmpty(report.requestedDeviceID, "avRuntime.videoFormat.requestedDeviceID")
    try requireDirectPeerSessionNonEmpty(report.selectedDeviceID, "avRuntime.videoFormat.selectedDeviceID")
    try requireDirectPeerSessionNonEmpty(report.selectedDeviceLabel, "avRuntime.videoFormat.selectedDeviceLabel")
    try requireDirectPeerSessionPositiveReportValue(report.requestedFrameRate, "avRuntime.videoFormat.requestedFrameRate")
    try requireDirectPeerSessionPositiveReportValue(report.selectedWidth, "avRuntime.videoFormat.selectedWidth")
    try requireDirectPeerSessionPositiveReportValue(report.selectedHeight, "avRuntime.videoFormat.selectedHeight")
    try requireDirectPeerSessionNonEmpty(report.selectedPixelFormat, "avRuntime.videoFormat.selectedPixelFormat")
    try requireDirectPeerSessionNonEmpty(report.outputPixelFormat, "avRuntime.videoFormat.outputPixelFormat")
    try requireDirectPeerSessionPositiveReportValue(report.selectedFrameRate, "avRuntime.videoFormat.selectedFrameRate")
}

private func validateDirectPeerSessionVideoReceiveProof(_ proof: DirectPeerSessionVideoReceiveProofArtifact) throws {
    try requireDirectPeerSessionPositiveReportValue(proof.framesProven, "avRuntime.receiveProof.framesProven")
    try requireDirectPeerSessionNonNegative(proof.previewFramesSubmitted, "avRuntime.receiveProof.previewFramesSubmitted")
    try validateDirectPeerSessionVideoFrameProof(proof.firstFrame, "avRuntime.receiveProof.firstFrame")
    try validateDirectPeerSessionVideoFrameProof(proof.latestFrame, "avRuntime.receiveProof.latestFrame")
}

private func validateDirectPeerSessionVideoFrameProof(
    _ proof: DirectPeerSessionVideoFrameProof,
    _ fieldPrefix: String
) throws {
    try requireDirectPeerSessionNonNegative(proof.streamID, "\(fieldPrefix).streamID")
    try requireDirectPeerSessionPositiveReportValue(proof.width, "\(fieldPrefix).width")
    try requireDirectPeerSessionPositiveReportValue(proof.height, "\(fieldPrefix).height")
    try requireDirectPeerSessionNonEmpty(proof.pixelFormat, "\(fieldPrefix).pixelFormat")
    try requireDirectPeerSessionPositiveReportValue(proof.payloadByteCount, "\(fieldPrefix).payloadByteCount")
    try requireDirectPeerSessionNonEmpty(proof.fingerprint, "\(fieldPrefix).fingerprint")
    if let payloadDigest = proof.payloadDigest {
        try requireDirectPeerSessionNonEmpty(payloadDigest, "\(fieldPrefix).payloadDigest")
    }
}

private func validatePassVideoProof(
    _ proof: DirectPeerSessionVideoReceiveProofArtifact,
    format: DirectPeerSessionVideoFormatReport,
    runtime: DirectPeerSessionAVRuntimeMetadata
) throws {
    let metrics = runtime.runtimeMetrics
    let videoFramesInsideAudioWindow = metrics.videoFramesReassembled
        - metrics.videoFramesDroppedOutsideAudioWindow
    if proof.framesProven != videoFramesInsideAudioWindow {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof("avRuntime.receiveProof.framesProven")
    }
    if proof.previewFramesSubmitted != metrics.previewFramesSubmitted {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.previewFramesSubmitted"
        )
    }
    try validatePassVideoFrameProof(proof.firstFrame, format: format, runtime: runtime, fieldPrefix: "firstFrame")
    try validatePassVideoFrameProof(proof.latestFrame, format: format, runtime: runtime, fieldPrefix: "latestFrame")
    if proof.latestFrame.sequenceNumber < proof.firstFrame.sequenceNumber {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.latestFrame.sequenceNumber"
        )
    }
}

private func validatePassVideoFrameProof(
    _ frame: DirectPeerSessionVideoFrameProof,
    format: DirectPeerSessionVideoFormatReport,
    runtime: DirectPeerSessionAVRuntimeMetadata,
    fieldPrefix: String
) throws {
    if frame.streamID != runtime.videoStreamID {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.\(fieldPrefix).streamID"
        )
    }
    if frame.width != format.selectedWidth {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.\(fieldPrefix).width"
        )
    }
    if frame.height != format.selectedHeight {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.\(fieldPrefix).height"
        )
    }
    if directPeerNormalizedVideoPixelFormat(frame.pixelFormat)
        != directPeerNormalizedVideoPixelFormat(format.outputPixelFormat) {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.\(fieldPrefix).pixelFormat"
        )
    }
    let expectedPayloadBytes = format.selectedWidth
        * format.selectedHeight
        * directPeerVideoBytesPerPixel(format.outputPixelFormat)
    if frame.payloadByteCount != expectedPayloadBytes {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.\(fieldPrefix).payloadByteCount"
        )
    }
    guard let payloadDigest = frame.payloadDigest, !payloadDigest.isEmpty else {
        throw DirectPeerSessionReportError.passWithInconsistentVideoProof(
            "avRuntime.receiveProof.\(fieldPrefix).payloadDigest"
        )
    }
}

private func validateMeasuredEvidence(_ evidence: DirectPeerSessionMeasuredEvidence) throws {
    try requireDirectPeerSessionNonPlaceholder(evidence.sourcePeerLabel, "measuredEvidence.sourcePeerLabel")
    try requireDirectPeerSessionNonPlaceholder(evidence.receiverPeerLabel, "measuredEvidence.receiverPeerLabel")
    try requireDirectPeerSessionNonPlaceholder(evidence.routeLabel, "measuredEvidence.routeLabel")
    try requireDirectPeerSessionNonPlaceholder(evidence.packetCapturePath, "measuredEvidence.packetCapturePath")
    try requireDirectPeerSessionNonPlaceholder(evidence.dscpObservation, "measuredEvidence.dscpObservation")
        try requireDirectPeerSessionNonPlaceholder(evidence.clockSyncSummary, "measuredEvidence.clockSyncSummary")
        if let packetCapture = evidence.packetCapture {
            try validateDirectPeerSessionEvidenceArtifact(
                packetCapture,
                "measuredEvidence.packetCapture",
                allowedExtensions: ["pcap", "pcapng"]
            )
        }
        if let dscp = evidence.dscp {
            try validateDirectPeerSessionDSCPEvidence(dscp)
        }
        if let clock = evidence.clock {
            try validateDirectPeerSessionClockEvidence(clock)
        }
        try requireDirectPeerSessionNonNegative(evidence.durationSeconds, "measuredEvidence.durationSeconds")
        if evidence.durationSeconds == 0 {
            throw DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence("measuredEvidence.durationSeconds")
        }
}

private func requireDirectPeerSessionNonPlaceholder(_ value: String?, _ field: String) throws {
    guard let value else {
        throw DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence(field)
    }
    try requireDirectPeerSessionNonEmpty(value, field)
    if PlaceholderDetection.matches(
        value,
        containing: ["todo", "required", "synthetic", "placeholder", "not supplied", "localhost"],
        emptyIsPlaceholder: false
    ) {
        throw DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence(field)
    }
}

private func requireDirectPeerSessionPassEvidenceArtifact(
    _ artifact: DirectPeerSessionEvidenceArtifact?,
    _ field: String,
    allowedExtensions: Set<String>
) throws {
    guard let artifact else {
        throw DirectPeerSessionReportError.passRequiresStructuredEvidence(field)
    }
    try validateDirectPeerSessionEvidenceArtifact(
        artifact,
        field,
        allowedExtensions: allowedExtensions
    )
    guard artifact.captured else {
        throw DirectPeerSessionReportError.passWithInvalidEvidenceArtifact("\(field).captured")
    }
    try requireDirectPeerSessionPassArtifactHash(artifact, field)
}

private func validateDirectPeerSessionEvidenceArtifact(
    _ artifact: DirectPeerSessionEvidenceArtifact,
    _ field: String,
    allowedExtensions: Set<String>
) throws {
    try requireDirectPeerSessionNonPlaceholder(artifact.path, "\(field).path")
    if artifact.path.contains("\n") || artifact.path.hasSuffix("/") {
        throw DirectPeerSessionReportError.passWithInvalidEvidenceArtifact("\(field).path")
    }
    let ext = URL(fileURLWithPath: artifact.path).pathExtension.lowercased()
    if ext.isEmpty || !allowedExtensions.contains(ext) {
        throw DirectPeerSessionReportError.passWithInvalidEvidenceArtifact("\(field).path")
    }
    if let sha256 = artifact.sha256 {
        try requireDirectPeerSessionNonEmpty(sha256, "\(field).sha256")
    }
}

private func requireDirectPeerSessionPassArtifactHash(
    _ artifact: DirectPeerSessionEvidenceArtifact,
    _ field: String
) throws {
    guard let sha256 = artifact.sha256 else {
        throw DirectPeerSessionReportError.passWithInvalidEvidenceArtifact("\(field).sha256")
    }
    try requireDirectPeerSessionNonEmpty(sha256, "\(field).sha256")
    let hex = Set("0123456789abcdefABCDEF")
    if sha256.count != 64 || sha256.contains(where: { !hex.contains($0) }) {
        throw DirectPeerSessionReportError.passWithInvalidEvidenceArtifact("\(field).sha256")
    }
}

private func directPeerSessionIsLoopbackHost(_ host: String) -> Bool {
    let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return normalized == "localhost"
        || normalized == "::1"
        || normalized == "[::1]"
        || normalized == "0:0:0:0:0:0:0:1"
        || normalized == "0000:0000:0000:0000:0000:0000:0000:0001"
        || normalized.hasPrefix("127.")
}

private func validateDirectPeerSessionDSCPEvidence(_ evidence: DirectPeerSessionDSCPEvidence) throws {
    if let requested = evidence.requested {
        try requireDirectPeerSessionDSCPValue(requested, "measuredEvidence.dscp.requested")
    }
    if let observed = evidence.observed {
        try requireDirectPeerSessionDSCPValue(observed, "measuredEvidence.dscp.observed")
    }
    try requireDirectPeerSessionNonPlaceholder(evidence.capturePoint, "measuredEvidence.dscp.capturePoint")
    try validateDirectPeerSessionEvidenceArtifact(
        evidence.artifact,
        "measuredEvidence.dscp.artifact",
        allowedExtensions: ["json", "pcap", "pcapng"]
    )
}

private func validateDirectPeerSessionClockEvidence(_ evidence: DirectPeerSessionClockEvidence) throws {
    try requireDirectPeerSessionNonPlaceholder(evidence.clockSource, "measuredEvidence.clock.clockSource")
    try requireDirectPeerSessionNonPlaceholder(evidence.method, "measuredEvidence.clock.method")
    try requireDirectPeerSessionNonNegative(
        evidence.maxOffsetMicroseconds,
        "measuredEvidence.clock.maxOffsetMicroseconds"
    )
    try validateDirectPeerSessionEvidenceArtifact(
        evidence.artifact,
        "measuredEvidence.clock.artifact",
        allowedExtensions: ["json", "txt", "log"]
    )
}

private func validatePassFastestAVBaselineComparison(
    _ comparison: DirectPeerSessionFastestAVBaselineComparison?
) throws {
    guard let comparison else {
        throw DirectPeerSessionReportError.passRequiresFastestAVBaselineComparison
    }
    try requireDirectPeerSessionNonPlaceholder(comparison.audioOnlyBaselineReportID, "avRuntime.fastestAVBaselineComparison.audioOnlyBaselineReportID")
    try requireDirectPeerSessionNonPlaceholder(comparison.audioOnlyBaselineReportPath, "avRuntime.fastestAVBaselineComparison.audioOnlyBaselineReportPath")
    try requireDirectPeerSessionNonPlaceholder(comparison.comparisonArtifactPath, "avRuntime.fastestAVBaselineComparison.comparisonArtifactPath")
    try requireDirectPeerSessionNonNegative(comparison.audioOnlyLatencyP99Microseconds, "avRuntime.fastestAVBaselineComparison.audioOnlyLatencyP99Microseconds")
    try requireDirectPeerSessionNonNegative(comparison.fastestAVAudioLatencyP99Microseconds, "avRuntime.fastestAVBaselineComparison.fastestAVAudioLatencyP99Microseconds")
    if !comparison.audioLatencyEqualToBaseline {
        throw DirectPeerSessionReportError.passWithFailedFastestAVBaselineComparison(
            "avRuntime.fastestAVBaselineComparison.audioLatencyEqualToBaseline"
        )
    }
    if !comparison.rxBufferEqualToBaseline {
        throw DirectPeerSessionReportError.passWithFailedFastestAVBaselineComparison(
            "avRuntime.fastestAVBaselineComparison.rxBufferEqualToBaseline"
        )
    }
    if !comparison.lossJitterEqualToBaseline {
        throw DirectPeerSessionReportError.passWithFailedFastestAVBaselineComparison(
            "avRuntime.fastestAVBaselineComparison.lossJitterEqualToBaseline"
        )
    }
}

private func validatePassAoIPPTPEvidence(
    avRuntime: DirectPeerSessionAVRuntimeMetadata,
    measuredEvidence: DirectPeerSessionMeasuredEvidence
) throws {
    guard let ptpEvidenceSummary = avRuntime.ptpEvidenceSummary?.lowercased(), !ptpEvidenceSummary.isEmpty else {
        throw DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence("avRuntime.ptpEvidenceSummary")
    }
    for required in ["ptp", "profile", "domain", "grandmaster", "lock", "offset"] {
        guard ptpEvidenceSummary.contains(required) else {
            throw DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence("avRuntime.ptpEvidenceSummary.\(required)")
        }
    }
    let clockText = "\(measuredEvidence.clockSyncSummary) \(measuredEvidence.clock?.clockSource ?? "") \(measuredEvidence.clock?.method ?? "")"
        .lowercased()
    guard clockText.contains("ptp") else {
        throw DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence("measuredEvidence.clock.ptp")
    }
}

private func requireDirectPeerSessionDSCPValue(_ value: Int, _ field: String) throws {
    if value < 0 || value > 63 {
        throw DirectPeerSessionReportError.negativeMetric(field)
    }
}

private func validateAVRuntimeMetrics(_ metrics: DirectPeerSessionAVRuntimeMetrics) throws {
    try requireDirectPeerSessionNonNegative(metrics.audioPayloadsCaptured, "avRuntime.runtimeMetrics.audioPayloadsCaptured")
    try requireDirectPeerSessionNonNegative(metrics.audioPayloadsSent, "avRuntime.runtimeMetrics.audioPayloadsSent")
    try requireDirectPeerSessionNonNegative(
        metrics.audioTXBudgetExhaustions,
        "avRuntime.runtimeMetrics.audioTXBudgetExhaustions"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.audioPayloadsQueuedForPlayout,
        "avRuntime.runtimeMetrics.audioPayloadsQueuedForPlayout"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.audioPayloadsDroppedBeforeSend,
        "avRuntime.runtimeMetrics.audioPayloadsDroppedBeforeSend"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.audioPayloadsDroppedBeforePlayout,
        "avRuntime.runtimeMetrics.audioPayloadsDroppedBeforePlayout"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.audioPayloadsDroppedByPlayoutQueue,
        "avRuntime.runtimeMetrics.audioPayloadsDroppedByPlayoutQueue"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.audioUnexpectedPayloadTypes,
        "avRuntime.runtimeMetrics.audioUnexpectedPayloadTypes"
    )
    try metrics.audioRXBuffer?.validate()
    try requireDirectPeerSessionNonNegative(metrics.audioPlayoutUnderruns, "avRuntime.runtimeMetrics.audioPlayoutUnderruns")
    try requireDirectPeerSessionNonNegative(
        metrics.audioCallbackMaxMicroseconds,
        "avRuntime.runtimeMetrics.audioCallbackMaxMicroseconds"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.audioCallbackDeadlineMisses,
        "avRuntime.runtimeMetrics.audioCallbackDeadlineMisses"
    )
    try requireDirectPeerSessionNonNegative(metrics.audioCallbackOverruns, "avRuntime.runtimeMetrics.audioCallbackOverruns")
    try requireDirectPeerSessionNonNegative(
        metrics.audioHostTimeConversionFailures,
        "avRuntime.runtimeMetrics.audioHostTimeConversionFailures"
    )
    try requireDirectPeerSessionNonNegative(metrics.videoFramesCaptured, "avRuntime.runtimeMetrics.videoFramesCaptured")
    try requireDirectPeerSessionNonNegative(metrics.videoFramesSent, "avRuntime.runtimeMetrics.videoFramesSent")
    try requireDirectPeerSessionNonNegative(metrics.videoFragmentsSent, "avRuntime.runtimeMetrics.videoFragmentsSent")
    try requireDirectPeerSessionNonNegative(
        metrics.videoFragmentsReceived,
        "avRuntime.runtimeMetrics.videoFragmentsReceived"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoFragmentsDroppedCorrupt,
        "avRuntime.runtimeMetrics.videoFragmentsDroppedCorrupt"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoFragmentsDroppedOversize,
        "avRuntime.runtimeMetrics.videoFragmentsDroppedOversize"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoUnexpectedPayloadTypes,
        "avRuntime.runtimeMetrics.videoUnexpectedPayloadTypes"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoFramesReassembled,
        "avRuntime.runtimeMetrics.videoFramesReassembled"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoFramesDroppedDuringReassembly,
        "avRuntime.runtimeMetrics.videoFramesDroppedDuringReassembly"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoReassemblyMissingFragments,
        "avRuntime.runtimeMetrics.videoReassemblyMissingFragments"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoReassemblyLateFragments,
        "avRuntime.runtimeMetrics.videoReassemblyLateFragments"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoReassemblyDuplicateFragments,
        "avRuntime.runtimeMetrics.videoReassemblyDuplicateFragments"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.previewFramesSubmitted,
        "avRuntime.runtimeMetrics.previewFramesSubmitted"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.previewFramesDropped,
        "avRuntime.runtimeMetrics.previewFramesDropped"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.previewFramesFailed,
        "avRuntime.runtimeMetrics.previewFramesFailed"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoFramesDroppedOutsideAudioWindow,
        "avRuntime.runtimeMetrics.videoFramesDroppedOutsideAudioWindow"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoFramesAlignedForSync,
        "avRuntime.runtimeMetrics.videoFramesAlignedForSync"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoFramesDeferredForSync,
        "avRuntime.runtimeMetrics.videoFramesDeferredForSync"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoFramesDroppedForSync,
        "avRuntime.runtimeMetrics.videoFramesDroppedForSync"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoFramesReplacedDuringSyncDefer,
        "avRuntime.runtimeMetrics.videoFramesReplacedDuringSyncDefer"
    )
    try requireDirectPeerSessionNonNegative(metrics.cameraWarmupWaits, "avRuntime.runtimeMetrics.cameraWarmupWaits")
    try requireDirectPeerSessionNonNegative(
        metrics.audioReceiveDrainIterations,
        "avRuntime.runtimeMetrics.audioReceiveDrainIterations"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.videoReceiveDrainIterations,
        "avRuntime.runtimeMetrics.videoReceiveDrainIterations"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.metricsMessagesPublished,
        "avRuntime.runtimeMetrics.metricsMessagesPublished"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.metricsMessagesPublishFailures,
        "avRuntime.runtimeMetrics.metricsMessagesPublishFailures"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.peerMetricsMessagesReceived,
        "avRuntime.runtimeMetrics.peerMetricsMessagesReceived"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.peerMetricsMessagesDropped,
        "avRuntime.runtimeMetrics.peerMetricsMessagesDropped"
    )
}
