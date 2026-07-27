// Validates DirectPeerSessionReportPassValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
extension DirectPeerSessionReport {
    func validatePassPeerMediaEndpoints() throws {
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

    func validatePassTransportMetrics() throws {
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

    func validatePassAVRuntimeMetrics(_ metrics: DirectPeerSessionAVRuntimeMetrics) throws {
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
            (metrics.videoFramesDroppedBeforeSend, "avRuntime.runtimeMetrics.videoFramesDroppedBeforeSend"),
            (metrics.videoFragmentsDroppedCorrupt, "avRuntime.runtimeMetrics.videoFragmentsDroppedCorrupt"),
            (metrics.videoFragmentsDroppedOversize, "avRuntime.runtimeMetrics.videoFragmentsDroppedOversize"),
            (metrics.videoUnexpectedPayloadTypes, "avRuntime.runtimeMetrics.videoUnexpectedPayloadTypes"),
            (metrics.videoFramesDroppedDuringReassembly, "avRuntime.runtimeMetrics.videoFramesDroppedDuringReassembly"),
            (metrics.videoReassemblyMissingFragments, "avRuntime.runtimeMetrics.videoReassemblyMissingFragments"),
            (metrics.videoReassemblyLateFragments, "avRuntime.runtimeMetrics.videoReassemblyLateFragments"),
            (metrics.videoReassemblyDuplicateFragments, "avRuntime.runtimeMetrics.videoReassemblyDuplicateFragments"),
            (metrics.previewFramesDropped, "avRuntime.runtimeMetrics.previewFramesDropped"),
            (metrics.previewFramesFailed, "avRuntime.runtimeMetrics.previewFramesFailed"),
            (
                metrics.videoFramesDroppedOutsideAudioWindow,
                "avRuntime.runtimeMetrics.videoFramesDroppedOutsideAudioWindow"
            ),
            (metrics.videoFramesDroppedForSync, "avRuntime.runtimeMetrics.videoFramesDroppedForSync"),
            (metrics.metricsMessagesPublishFailures, "avRuntime.runtimeMetrics.metricsMessagesPublishFailures"),
            (metrics.peerMetricsMessagesDropped, "avRuntime.runtimeMetrics.peerMetricsMessagesDropped")
        ]
        for (value, field) in degradationCounters {
            try requireDirectPeerSessionNoPassDegradation(value, field)
        }
        if let audioRXBuffer = metrics.audioRXBuffer {
            try validatePassAudioRXBuffer(audioRXBuffer)
        }
    }

    func validatePassAVRuntimeCallbackTiming(_ runtime: DirectPeerSessionAVRuntimeMetadata) throws {
        let periodMicroseconds = Double(runtime.selectedBufferFrameSize) * 1_000_000 / Double(runtime.sampleRateHertz)
        if Double(runtime.runtimeMetrics.audioCallbackMaxMicroseconds) > periodMicroseconds {
            throw DirectPeerSessionReportError.passWithRuntimeDegradation(
                "avRuntime.runtimeMetrics.audioCallbackMaxMicroseconds"
            )
        }
    }

    func validatePassAudioRXBuffer(_ snapshot: RxBufferRuntimeSnapshot) throws {
        try requireDirectPeerSessionNoPassDegradation(
            snapshot.latePackets,
            "avRuntime.runtimeMetrics.audioRXBuffer.latePackets"
        )
        try requireDirectPeerSessionNoPassDegradation(
            snapshot.lostPackets,
            "avRuntime.runtimeMetrics.audioRXBuffer.lostPackets"
        )
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
        try requireDirectPeerSessionNoPassDegradation(
            snapshot.underruns,
            "avRuntime.runtimeMetrics.audioRXBuffer.underruns"
        )
        try requireDirectPeerSessionNoPassDegradation(
            snapshot.overruns,
            "avRuntime.runtimeMetrics.audioRXBuffer.overruns"
        )
        try requireDirectPeerSessionNoPassDegradation(
            snapshot.plcEvents,
            "avRuntime.runtimeMetrics.audioRXBuffer.plcEvents"
        )
        if snapshot.hiddenGrowthDetected {
            throw DirectPeerSessionReportError.passWithRuntimeDegradation(
                "avRuntime.runtimeMetrics.audioRXBuffer.hiddenGrowthDetected"
            )
        }
    }
}
