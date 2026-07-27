// Assembles transport report identity, route, fragmentation, sync, degradation, and counter sections from completed run state.
import Foundation

func videoTransportReport(
    configuration: VideoTransportRunConfiguration,
    socketContext: VideoTransportSocketContext,
    context: VideoTransportRunContext
) -> VideoTransportReport {
    let metrics = videoTransportReportMetrics(configuration: configuration, context: context)

    return VideoTransportReport(
            id: videoTransportReportID(configuration),
            title: videoTransportReportTitle(configuration),
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            durationSeconds: Double(configuration.durationSeconds),
            source: videoTransportSourceDescription(configuration),
            format: videoTransportCaptureFormat(configuration),
            transport: videoTransportProfile(configuration),
            routeEvidence: videoTransportRouteEvidence(configuration, socketContext: socketContext),
            fragmentation: videoTransportFragmentationMetrics(context, metrics: metrics),
            reassembly: context.reassembler.metrics,
            renderOutput: metrics.renderMetrics,
            blackmagicOutput: BlackmagicOutputBoundary.detect(),
            multiVideo: videoTransportMultiVideoMetrics(.init(
                configuration: configuration,
                states: context.streamStates,
                streamBandwidthMegabitsPerSecond: metrics.streamBandwidth,
                audioPriority: .init(
                    protected: metrics.audioPriorityProtected,
                    evidence: metrics.audioPriorityEvidence
                ),
                receiverObservedQueueDepthByStreamID: context.receiver.observedQueueDepthByStreamID
            )),
            avSync: videoTransportAVSyncMetrics(configuration, metrics: metrics),
            transmitted: videoTransportTransmittedMetrics(metrics),
            receiver: videoTransportReceiverMetrics(context),
            frameAge: metrics.frameAge,
            performanceCounters: videoTransportPerformanceCounters(context, metrics: metrics),
            degradation: videoTransportDegradationPolicy(configuration),
            audioImpact: metrics.audioImpact,
            verdict: .partial,
            notes: videoTransportReportNotes(configuration)
        )
}

func videoTransportReportID(_ configuration: VideoTransportRunConfiguration) -> String {
    configuration.streamCount == 1
        ? "m09-video-transport-run"
        : "m09-multi-video-transport-run"
}

func videoTransportReportTitle(_ configuration: VideoTransportRunConfiguration) -> String {
    configuration.streamCount == 1
        ? "Raw latest-frame video transport run"
        : "Raw staged multi-video transport run"
}

private func videoTransportSourceDescription(
    _ configuration: VideoTransportRunConfiguration
) -> VideoSourceDescription {
    VideoSourceDescription(
        kind: .testPattern,
        label: configuration.streamCount == 1
            ? "synthetic-test-pattern"
            : "synthetic-test-pattern-multistream",
        deviceUniqueId: nil,
        permissionStatus: "notRequired"
    )
}

private func videoTransportCaptureFormat(
    _ configuration: VideoTransportRunConfiguration
) -> VideoCaptureFormat {
    VideoCaptureFormat(
        width: configuration.width,
        height: configuration.height,
        nominalFrameRate: configuration.frameRate,
        pixelFormat: configuration.pixelFormat
    )
}

private func videoTransportProfile(
    _ configuration: VideoTransportRunConfiguration
) -> VideoTransportProfile {
    VideoTransportProfile(
        mode: configuration.mode,
        networkProtocol: "udpDatagram",
        payloadFormat: "raw-\(configuration.pixelFormat)",
        reliableRetransmission: false,
        maxPacketBytes: configuration.maxPacketBytes,
        encoderQueueDepth: 1,
        frameReorderingAllowed: false,
        videoToolboxAvailable: false,
        videoToolboxRealtimeMode: false
    )
}

private func videoTransportRouteEvidence(
    _ configuration: VideoTransportRunConfiguration,
    socketContext: VideoTransportSocketContext
) -> VideoTransportRouteEvidence {
    VideoTransportRouteEvidence(
        routeKind: configuration.routeKind,
        routeLabel: videoTransportRouteLabel(configuration, socketContext: socketContext),
        packetCapturePoint: configuration.packetCapturePoint,
        rawOrIntraFrameBaselineReportId: nil,
        rawOrIntraFrameBaselineMode: nil,
        baselineAudioRouteVerdict: .partial,
        videoActiveAudioRouteVerdict: .partial
    )
}

private func videoTransportRouteLabel(
    _ configuration: VideoTransportRunConfiguration,
    socketContext: VideoTransportSocketContext
) -> String {
    socketContext.loopbackSelfProbe
        ? "\(configuration.routeKind.rawValue)-udp-socket-loopback"
        : configuration.routeKind.rawValue
}

private func videoTransportFragmentationMetrics(
    _ context: VideoTransportRunContext,
    metrics: VideoTransportReportMetrics
) -> VideoFragmentationMetrics {
    VideoFragmentationMetrics(
        framesFragmented: metrics.framesFragmented,
        fragmentsSent: metrics.fragmentsSent,
        maxFragmentsPerFrame: context.maxFragmentsPerFrame,
        maxPayloadBytesPerFragment: context.maxPayloadBytesPerFragment
    )
}

private func videoTransportAVSyncMetrics(
    _ configuration: VideoTransportRunConfiguration,
    metrics: VideoTransportReportMetrics
) -> AVSyncTimingMetrics {
    AVSyncTimingMetrics(
        clockOrigins: .init(
            policy: AVSyncPolicy.policy(for: configuration.streamCount == 1 ? .balancedAV : .multiVideoPerformance),
            audioTimestampOrigin: .audioPacketSenderHostTimeNanoseconds,
            videoTimestampOrigin: .videoPacketTimestampNanoseconds
        ),
        measurements: .init(
            audioRouteAge: metrics.audioRouteAge,
            videoFrameAge: metrics.frameAge,
            avOffset: metrics.avOffset,
            jitter: metrics.avJitter,
            drift: metrics.drift
        ),
        alignment: .init(
            videoFramesAligned: metrics.renderMetrics.framesRendered,
            videoFramesDeferred: 0,
            videoFramesDroppedForSync: metrics.renderMetrics.framesDroppedLate,
            audioDelayFramesAddedForVideo: 0,
            offsetMeasurementMethod: "modelled callback/buffer/drift constants with local video timing; not physical end-to-end measurement"
        )
    )
}

func videoTransportTransmittedMetrics(
    _ metrics: VideoTransportReportMetrics
) -> VideoTransmittedMetrics {
    VideoTransmittedMetrics(
        framesSent: metrics.framesCompletedSend,
        framesDroppedBeforeSend: metrics.framesDroppedBeforeSend,
        packetsSent: metrics.fragmentsSent,
        packetsDropped: metrics.packetsDropped
    )
}

private func videoTransportReceiverMetrics(
    _ context: VideoTransportRunContext
) -> VideoReceiverMetrics {
    VideoReceiverMetrics(
        queuePolicy: .latestFrame,
        receivedFrames: context.reassembler.metrics.framesReassembled,
        // The generic runner exercises reassembly and latest-frame selection only.
        // It has no physical output backend, so it must not claim presentation.
        displayedFrames: context.renderer.backend == .metricsOnly ? 0 : context.receiver.packets.count,
        droppedFrames: context.receiver.droppedFrames,
        lateFrames: 0,
        observedQueueDepth: context.receiver.observedQueueDepth
    )
}

private func videoTransportPerformanceCounters(
    _ context: VideoTransportRunContext,
    metrics: VideoTransportReportMetrics
) -> VideoTransportPerformanceCounters {
    VideoTransportPerformanceCounters(
        packetizationDuration: .fromSamples(context.packetizationDurations.samples),
        reassemblyDuration: .fromSamples(context.reassemblyDurations.samples),
        frameAge: metrics.frameAge,
        queueDepthFrames: context.receiver.observedQueueDepth
    )
}

private func videoTransportDegradationPolicy(
    _ configuration: VideoTransportRunConfiguration
) -> VideoDegradationPolicy {
    VideoDegradationPolicy(
        actions: [.dropFrame, .disableVideo],
        triggeredBeforeAudioTargetChange: true,
        triggeredBeforeAudioOrRouteImpact: configuration.streamCount > 1
    )
}

func videoTransportReportNotes(_ configuration: VideoTransportRunConfiguration) -> String {
    if configuration.streamCount == 1 {
        return "Socket-backed UDP raw latest-frame transport model run with test-pattern source. "
            + "metricsOnly reports reassembly and selection, not physical display; PASS requires physical Blackmagic/ATEM source/output and packet-captured route evidence."
    }
    return "Socket-backed UDP staged multi-video transport run with test-pattern sources. "
        + "PASS requires physical multi-camera Blackmagic/ATEM source/output and packet-captured route evidence."
}
