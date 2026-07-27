// Validates DirectPeerSessionAVRuntimeReportValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
func validateDirectPeerSessionDSCPEvidence(_ evidence: DirectPeerSessionDSCPEvidence) throws {
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

func validateDirectPeerSessionClockEvidence(_ evidence: DirectPeerSessionClockEvidence) throws {
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

func validatePassFastestAVBaselineComparison(
    _ comparison: DirectPeerSessionFastestAVBaselineComparison?
) throws {
    guard let comparison else {
        throw DirectPeerSessionReportError.passRequiresFastestAVBaselineComparison
    }
    try requireDirectPeerSessionNonPlaceholder(
        comparison.audioOnlyBaselineReportID,
        "avRuntime.fastestAVBaselineComparison.audioOnlyBaselineReportID"
    )
    try requireDirectPeerSessionNonPlaceholder(
        comparison.audioOnlyBaselineReportPath,
        "avRuntime.fastestAVBaselineComparison.audioOnlyBaselineReportPath"
    )
    try requireDirectPeerSessionNonPlaceholder(
        comparison.comparisonArtifactPath,
        "avRuntime.fastestAVBaselineComparison.comparisonArtifactPath"
    )
    try requireDirectPeerSessionNonNegative(
        comparison.audioOnlyLatencyP99Microseconds,
        "avRuntime.fastestAVBaselineComparison.audioOnlyLatencyP99Microseconds"
    )
    try requireDirectPeerSessionNonNegative(
        comparison.fastestAVAudioLatencyP99Microseconds,
        "avRuntime.fastestAVBaselineComparison.fastestAVAudioLatencyP99Microseconds"
    )
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

func validatePassAoIPPTPEvidence(
    avRuntime: DirectPeerSessionAVRuntimeMetadata,
    measuredEvidence: DirectPeerSessionMeasuredEvidence
) throws {
    guard let ptpEvidenceSummary = avRuntime.ptpEvidenceSummary?.lowercased(), !ptpEvidenceSummary.isEmpty else {
        throw DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence("avRuntime.ptpEvidenceSummary")
    }
    for required in ["ptp", "profile", "domain", "grandmaster", "lock", "offset"] {
        guard ptpEvidenceSummary.contains(required) else {
        throw DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence(
            "avRuntime.ptpEvidenceSummary.\(required)"
        )
        }
    }
 let clockText = (
 "\(measuredEvidence.clockSyncSummary) "
 + "\(measuredEvidence.clock?.clockSource ?? "") "
 + "\(measuredEvidence.clock?.method ?? "")"
 ).lowercased()
    guard clockText.contains("ptp") else {
        throw DirectPeerSessionReportError.passWithPlaceholderMeasuredEvidence("measuredEvidence.clock.ptp")
    }
}

func requireDirectPeerSessionDSCPValue(_ value: Int, _ field: String) throws {
    if value < 0 || value > 63 {
        throw DirectPeerSessionReportError.negativeMetric(field)
    }
}

func validateAVRuntimeMetrics(_ metrics: DirectPeerSessionAVRuntimeMetrics) throws {
    try validateAVRuntimeAudioPayloadMetrics(metrics)
    try validateAVRuntimeAudioCallbackMetrics(metrics)
    try validateAVRuntimeVideoTransportMetrics(metrics)
    try validateAVRuntimeVideoReassemblyMetrics(metrics)
    try validateAVRuntimeVideoSyncMetrics(metrics)
    try validateAVRuntimeDrainAndPeerMetrics(metrics)
}

func validateAVRuntimeAudioPayloadMetrics(_ metrics: DirectPeerSessionAVRuntimeMetrics) throws {
    try requireDirectPeerSessionNonNegative(
        metrics.audioPayloadsCaptured,
        "avRuntime.runtimeMetrics.audioPayloadsCaptured"
    )
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
}

func validateAVRuntimeAudioCallbackMetrics(_ metrics: DirectPeerSessionAVRuntimeMetrics) throws {
    try requireDirectPeerSessionNonNegative(
        metrics.audioPlayoutUnderruns,
        "avRuntime.runtimeMetrics.audioPlayoutUnderruns"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.audioCallbackMaxMicroseconds,
        "avRuntime.runtimeMetrics.audioCallbackMaxMicroseconds"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.audioCallbackDeadlineMisses,
        "avRuntime.runtimeMetrics.audioCallbackDeadlineMisses"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.audioCallbackOverruns,
        "avRuntime.runtimeMetrics.audioCallbackOverruns"
    )
    try requireDirectPeerSessionNonNegative(
        metrics.audioHostTimeConversionFailures,
        "avRuntime.runtimeMetrics.audioHostTimeConversionFailures"
    )
}

func validateAVRuntimeVideoTransportMetrics(_ metrics: DirectPeerSessionAVRuntimeMetrics) throws {
    try requireDirectPeerSessionNonNegative(metrics.videoFramesCaptured, "avRuntime.runtimeMetrics.videoFramesCaptured")
    try requireDirectPeerSessionNonNegative(metrics.videoFramesSent, "avRuntime.runtimeMetrics.videoFramesSent")
    try requireDirectPeerSessionNonNegative(
        metrics.videoFramesDroppedBeforeSend,
        "avRuntime.runtimeMetrics.videoFramesDroppedBeforeSend"
    )
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
}

func validateAVRuntimeVideoReassemblyMetrics(_ metrics: DirectPeerSessionAVRuntimeMetrics) throws {
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
}

func validateAVRuntimeVideoSyncMetrics(_ metrics: DirectPeerSessionAVRuntimeMetrics) throws {
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
}

func validateAVRuntimeDrainAndPeerMetrics(_ metrics: DirectPeerSessionAVRuntimeMetrics) throws {
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
