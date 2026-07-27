// Aggregates latency reservoirs, bandwidth probes, audio impact, drift, and stream counters before report construction.
import Foundation

struct VideoTransportReportMetrics {
    var framesScheduled: Int
    var framesGenerated: Int
    var framesFragmented: Int
    var framesCompletedSend: Int
    var framesDroppedBeforeSend: Int
    var fragmentsSent: Int
    var packetsDropped: Int
    var renderMetrics: VideoRenderOutputMetrics
    var audioImpact: VideoAudioImpactMetrics
    var streamBandwidth: Double
    var audioPriorityProtected: Bool?
    var audioPriorityEvidence: VideoAudioPriorityEvidence
    var frameAge: UdpPcmPacketAgeMetrics
    var audioRouteAge: UdpPcmPacketAgeMetrics
    var avOffset: UdpPcmPacketAgeMetrics
    var avJitter: UdpPcmPacketAgeMetrics
    var drift: MediaClockDriftEstimate
}

/// A fixed-capacity reservoir keeps transport telemetry bounded for long runs.
/// Percentiles are estimates over the most recent samples, never an unbounded
/// per-fragment history.
struct VideoTransportLatencyReservoir: Equatable, Sendable {
    private static let capacity = 4_096
    private var storage: [Double] = []
    private var nextIndex = 0

    mutating func record(_ value: Double) {
        if storage.count < Self.capacity {
            storage.append(value)
        } else {
            storage[nextIndex] = value
        }
        nextIndex = (nextIndex + 1) % Self.capacity
    }

    var metrics: UdpPcmPacketAgeMetrics {
        videoTransportPacketAgeMetrics(for: storage)
    }

    var samples: [Double] { storage }
}

func videoTransportReportMetrics(
    configuration: VideoTransportRunConfiguration,
    context: VideoTransportRunContext
) -> VideoTransportReportMetrics {
    let audioImpact = videoTransportModelledAudioImpactMetrics()
    let frameAge = context.frameAges.metrics
    let avOffset = abs(frameAge.p50Microseconds - audioImpact.baselineCallbackP99Microseconds)
    return VideoTransportReportMetrics(
        framesScheduled: videoTransportTotalFramesScheduled(context.streamStates),
        framesGenerated: videoTransportTotalFramesGenerated(context.streamStates),
        framesFragmented: videoTransportTotalFramesFragmented(context.streamStates),
        framesCompletedSend: videoTransportTotalFramesCompletedSend(context.streamStates),
        framesDroppedBeforeSend: videoTransportTotalFramesDroppedBeforeSend(context.streamStates),
        fragmentsSent: videoTransportTotalFragmentsSent(context.streamStates),
        packetsDropped: videoTransportTotalPacketsDropped(context.streamStates),
        renderMetrics: context.renderer.metrics,
        audioImpact: audioImpact,
        streamBandwidth: videoTransportBandwidthProbeStream(
            configuration: configuration
        ).estimatedBandwidthMegabitsPerSecond,
        audioPriorityProtected: nil,
        audioPriorityEvidence: .notMeasured,
        frameAge: frameAge,
        audioRouteAge: videoTransportAudioRouteAgeMetrics(audioImpact),
        avOffset: videoTransportConstantPacketAgeMetrics(avOffset),
        avJitter: videoTransportConstantPacketAgeMetrics(0),
        drift: videoTransportModelledDriftEstimate()
    )
}

private enum VideoTransportModelConstants {
    static let callbackP99Microseconds = 80.0
    static let callbackMaxMicroseconds = 95.0
    static let playoutTargetFrames = 32
    static let modelledClockDurationNanoseconds: UInt64 = 1_000_000_000
}

private func videoTransportModelledAudioImpactMetrics() -> VideoAudioImpactMetrics {
    VideoAudioImpactMetrics(
        baselineCallbackP99Microseconds: VideoTransportModelConstants.callbackP99Microseconds,
        videoCallbackP99Microseconds: VideoTransportModelConstants.callbackP99Microseconds,
        baselineCallbackMaxMicroseconds: VideoTransportModelConstants.callbackMaxMicroseconds,
        videoCallbackMaxMicroseconds: VideoTransportModelConstants.callbackMaxMicroseconds,
        baselinePlayoutTargetFrames: VideoTransportModelConstants.playoutTargetFrames,
        videoPlayoutTargetFrames: VideoTransportModelConstants.playoutTargetFrames,
        underruns: 0,
        hiddenAudioImpactDetected: false,
        synthetic: true
    )
}

private func videoTransportAudioRouteAgeMetrics(
    _ audioImpact: VideoAudioImpactMetrics
) -> UdpPcmPacketAgeMetrics {
    UdpPcmPacketAgeMetrics(
        p50Microseconds: audioImpact.baselineCallbackP99Microseconds,
        p95Microseconds: audioImpact.baselineCallbackP99Microseconds,
        p99Microseconds: audioImpact.baselineCallbackP99Microseconds,
        maxMicroseconds: audioImpact.baselineCallbackMaxMicroseconds
    )
}

private func videoTransportModelledDriftEstimate() -> MediaClockDriftEstimate {
    MediaClockDriftEstimate(
        sampleCount: 2,
        remoteDurationNanoseconds: VideoTransportModelConstants.modelledClockDurationNanoseconds,
        localDurationNanoseconds: VideoTransportModelConstants.modelledClockDurationNanoseconds,
        offsetMicroseconds: 0,
        driftSlopePartsPerMillion: 0
    )
}

private func videoTransportConstantPacketAgeMetrics(_ value: Double) -> UdpPcmPacketAgeMetrics {
    UdpPcmPacketAgeMetrics(
        p50Microseconds: value,
        p95Microseconds: value,
        p99Microseconds: value,
        maxMicroseconds: value
    )
}

private func videoTransportBandwidthProbeStream(
    configuration: VideoTransportRunConfiguration
) -> VideoStreamDescription {
    VideoStreamDescription(
        identity: .init(
            id: Int(configuration.streamID),
            direction: .send,
            role: configuration.sourceRole,
            sourceLabel: "synthetic-test-pattern",
            payloadType: .videoRawFrameFragment
        ),
        format: .init(
            resolution: .init(width: configuration.width, height: configuration.height),
            frameRate: videoFrameRate(from: configuration.frameRate),
            pixelFormat: videoTransportPixelFormat(from: configuration.pixelFormat),
            transportFormat: .rawFrameFragment
        ),
        capture: .init(queueDepth: configuration.queueDepth)
    )
}

private func videoTransportPixelFormat(from pixelFormat: String) -> VideoPixelFormat {
    VideoPixelFormat(rawValue: normalizedVideoPixelFormat(pixelFormat)) ?? .rgb24
}
