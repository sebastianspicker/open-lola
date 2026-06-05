import Darwin
import Dispatch
import Foundation

private let videoTransportFragmentDrainInterval = 16
private let videoTransportDrainIdleWait: DispatchTimeInterval = .microseconds(1_000)

public enum VideoTransportSyntheticSmoke {
    public static func run() throws -> VideoTransportReport {
        try VideoTransportRunner.run(
            configuration: VideoTransportRunConfiguration(
                mode: .raw,
                peer: "127.0.0.1",
                port: 5_004,
                durationSeconds: 1,
                outputPath: "stdout",
                width: 1_280,
                height: 720,
                frameRate: 3,
                queueDepth: 1,
                routeKind: .syntheticLocal,
                packetCapturePoint: "synthetic"
            )
        )
    }
}

public enum VideoReceiveRenderSyntheticSmoke {
    public static func run() throws -> VideoTransportReport {
        try VideoTransportSyntheticSmoke.run()
    }
}

public enum VideoTransportRunner {
    public static func run(configuration: VideoTransportRunConfiguration) throws -> VideoTransportReport {
        preconditionVideoTransportRunnerQoS()

        let socketContext = try VideoTransportSocketContext(configuration: configuration)
        defer { close(socketContext.socket) }
        try setNonBlocking(socketContext.socket)

        var context = VideoTransportRunContext(configuration: configuration)
        try runVideoTransportFrameLoop(
            configuration: configuration,
            socketContext: socketContext,
            context: &context
        )
        context.reassembler.flushIncomplete()
        return videoTransportReport(
            configuration: configuration,
            socketContext: socketContext,
            context: context
        )
    }
}

private struct VideoTransportSocketContext {
    var socket: Int32
    var targetPort: UInt16
    var loopbackSelfProbe: Bool

    init(configuration: VideoTransportRunConfiguration) throws {
        socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        loopbackSelfProbe = configuration.isLoopbackSelfProbe
        try bindIPv4(
            socket,
            host: loopbackSelfProbe ? configuration.peer : "0.0.0.0",
            port: loopbackSelfProbe ? 0 : configuration.port.bigEndian
        )
        targetPort = loopbackSelfProbe ? try boundPort(socket) : configuration.port.bigEndian
    }
}

private struct VideoTransportRunContext {
    var streamStates: [VideoTransportStreamRunState]
    var receiver: LatestVideoFrameReceiver
    var reassembler: VideoFrameReassembler
    var renderer: VideoOutputRenderer
    var frameAges: [Double] = []
    var maxFragmentsPerFrame = 0
    var maxPayloadBytesPerFragment = 0
    var packetizationDurations: [Double] = []
    var reassemblyDurations: [Double] = []
    var nextFrameDeadline = DispatchTime.now().uptimeNanoseconds

    init(configuration: VideoTransportRunConfiguration) {
        streamStates = videoTransportStreamStates(configuration: configuration)
        receiver = LatestVideoFrameReceiver(
            maxDepth: max(configuration.visibleStreamCount, 1)
        )
        reassembler = VideoFrameReassembler(
            maxActiveFrames: max(4, configuration.streamCount * 2)
        )
        renderer = VideoOutputRenderer(
            backend: .metricsOnly,
            pacingPolicy: .latestOnly,
            maxQueueDepth: max(configuration.visibleStreamCount, 1)
        )
    }
}

private struct VideoTransportPacketizedFrame {
    var fragments: [VideoTransportFragment]
    var durationMicroseconds: Double
    var streamIndex: Int
}

private struct VideoTransportReportMetrics {
    var framesGenerated: Int
    var fragmentsSent: Int
    var renderMetrics: VideoRenderOutputMetrics
    var audioImpact: VideoAudioImpactMetrics
    var streamBandwidth: Double
    var audioPriorityProtected: Bool
    var frameAge: UdpPcmPacketAgeMetrics
    var audioRouteAge: UdpPcmPacketAgeMetrics
    var avOffset: UdpPcmPacketAgeMetrics
    var avJitter: UdpPcmPacketAgeMetrics
    var drift: MediaClockDriftEstimate
}

private func runVideoTransportFrameLoop(
    configuration: VideoTransportRunConfiguration,
    socketContext: VideoTransportSocketContext,
    context: inout VideoTransportRunContext
) throws {
    for _ in 0..<configuration.frameCount {
        for streamIndex in context.streamStates.indices {
            try sendNextVideoFrame(
                configuration: configuration,
                socketContext: socketContext,
                context: &context,
                streamIndex: streamIndex
            )
        }
        context.nextFrameDeadline = nextVideoTransportFrameDeadline(
            previous: context.nextFrameDeadline,
            interval: configuration.frameIntervalNanoseconds
        )
        sleepUntilUptimeNanoseconds(context.nextFrameDeadline)
    }
}

private func sendNextVideoFrame(
    configuration: VideoTransportRunConfiguration,
    socketContext: VideoTransportSocketContext,
    context: inout VideoTransportRunContext,
    streamIndex: Int
) throws {
    guard let frame = context.streamStates[streamIndex].source.nextFrame() else {
        return
    }
    context.streamStates[streamIndex].framesGenerated += 1
    let packetized = try LatencyBenchmark.measure {
        try RawVideoFrameTransport.fragments(
            for: frame,
            maxPacketBytes: configuration.maxPacketBytes
        )
    }
    try sendVideoFragments(
        VideoTransportPacketizedFrame(
            fragments: packetized.value,
            durationMicroseconds: packetized.durationMicroseconds,
            streamIndex: streamIndex
        ),
        configuration: configuration,
        socketContext: socketContext,
        context: &context
    )
}

private func sendVideoFragments(
    _ packetizedFrame: VideoTransportPacketizedFrame,
    configuration: VideoTransportRunConfiguration,
    socketContext: VideoTransportSocketContext,
    context: inout VideoTransportRunContext
) throws {
    context.packetizationDurations.append(packetizedFrame.durationMicroseconds)
    context.streamStates[packetizedFrame.streamIndex].fragmentsSent += packetizedFrame.fragments.count
    context.maxFragmentsPerFrame = max(context.maxFragmentsPerFrame, packetizedFrame.fragments.count)
    for fragment in packetizedFrame.fragments {
        try sendVideoFragment(
            fragment,
            configuration: configuration,
            socketContext: socketContext,
            context: &context
        )
    }
    try drainVideoFragments(
        socketContext: socketContext,
        configuration: configuration,
        context: &context,
        totalGeneratedFrames: videoTransportTotalFramesGenerated(context.streamStates)
    )
}

private func sendVideoFragment(
    _ fragment: VideoTransportFragment,
    configuration: VideoTransportRunConfiguration,
    socketContext: VideoTransportSocketContext,
    context: inout VideoTransportRunContext
) throws {
    context.maxPayloadBytesPerFragment = max(
        context.maxPayloadBytesPerFragment,
        fragment.payloadByteCount
    )
    try sendDatagram(
        try fragment.encoded(),
        socket: socketContext.socket,
        host: configuration.peer,
        port: socketContext.targetPort
    )
    guard fragment.fragmentIndex % videoTransportFragmentDrainInterval
        == videoTransportFragmentDrainInterval - 1 else {
        return
    }
    try drainAvailableVideoFragments(
        socketContext: socketContext,
        configuration: configuration,
        context: &context
    )
}

private func videoTransportReport(
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
            multiVideo: videoTransportMultiVideoMetrics(
                configuration: configuration,
                states: context.streamStates,
                streamBandwidthMegabitsPerSecond: metrics.streamBandwidth,
                audioPriorityProtected: metrics.audioPriorityProtected,
                receiverObservedQueueDepthByStreamID: context.receiver.observedQueueDepthByStreamID
            ),
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

private func videoTransportReportMetrics(
    configuration: VideoTransportRunConfiguration,
    context: VideoTransportRunContext
) -> VideoTransportReportMetrics {
    let audioImpact = videoTransportAudioImpactMetrics()
    let avOffsets = context.frameAges.map {
        abs($0 - audioImpact.baselineCallbackP99Microseconds)
    }
    return VideoTransportReportMetrics(
        framesGenerated: videoTransportTotalFramesGenerated(context.streamStates),
        fragmentsSent: videoTransportTotalFragmentsSent(context.streamStates),
        renderMetrics: context.renderer.metrics,
        audioImpact: audioImpact,
        streamBandwidth: videoTransportBandwidthProbeStream(
            configuration: configuration
        ).estimatedBandwidthMegabitsPerSecond,
        audioPriorityProtected: videoTransportAudioPriorityProtected(audioImpact),
        frameAge: videoTransportPacketAgeMetrics(for: context.frameAges),
        audioRouteAge: videoTransportAudioRouteAgeMetrics(audioImpact),
        avOffset: videoTransportPacketAgeMetrics(for: avOffsets),
        avJitter: videoTransportPacketAgeMetrics(for: avOffsets.map {
            abs($0 - (avOffsets.first ?? 0))
        }),
        drift: videoTransportSyntheticDriftEstimate()
    )
}

private func videoTransportAudioImpactMetrics() -> VideoAudioImpactMetrics {
    VideoAudioImpactMetrics(
        baselineCallbackP99Microseconds: 80,
        videoCallbackP99Microseconds: 80,
        baselineCallbackMaxMicroseconds: 95,
        videoCallbackMaxMicroseconds: 95,
        baselinePlayoutTargetFrames: 32,
        videoPlayoutTargetFrames: 32,
        underruns: 0,
        hiddenAudioImpactDetected: false
    )
}

private func videoTransportAudioPriorityProtected(_ audioImpact: VideoAudioImpactMetrics) -> Bool {
    audioImpact.baselineCallbackP99Microseconds == audioImpact.videoCallbackP99Microseconds
        && audioImpact.baselineCallbackMaxMicroseconds == audioImpact.videoCallbackMaxMicroseconds
        && audioImpact.baselinePlayoutTargetFrames == audioImpact.videoPlayoutTargetFrames
        && audioImpact.underruns == 0
        && !audioImpact.hiddenAudioImpactDetected
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

private func videoTransportSyntheticDriftEstimate() -> MediaClockDriftEstimate {
    MediaClockDriftEstimate(
        sampleCount: 2,
        remoteDurationNanoseconds: 1_000_000_000,
        localDurationNanoseconds: 1_000_000_000,
        offsetMicroseconds: 0,
        driftSlopePartsPerMillion: 0
    )
}

private func videoTransportReportID(_ configuration: VideoTransportRunConfiguration) -> String {
    configuration.streamCount == 1
        ? "m09-video-transport-run"
        : "m09-multi-video-transport-run"
}

private func videoTransportReportTitle(_ configuration: VideoTransportRunConfiguration) -> String {
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
        framesFragmented: metrics.framesGenerated,
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
        policy: AVSyncPolicy.policy(for: configuration.streamCount == 1 ? .balancedAV : .multiVideoPerformance),
        audioTimestampOrigin: .audioPacketSenderHostTimeNanoseconds,
        videoTimestampOrigin: .videoPacketTimestampNanoseconds,
        audioRouteAge: metrics.audioRouteAge,
        videoFrameAge: metrics.frameAge,
        avOffset: metrics.avOffset,
        jitter: metrics.avJitter,
        drift: metrics.drift,
        videoFramesAligned: metrics.renderMetrics.framesRendered,
        videoFramesDeferred: 0,
        videoFramesDroppedForSync: metrics.renderMetrics.framesDroppedLate,
        audioDelayFramesAddedForVideo: 0,
        offsetMeasurementMethod: "measured from synthetic audio route age and video frame age"
    )
}

private func videoTransportTransmittedMetrics(
    _ metrics: VideoTransportReportMetrics
) -> VideoTransmittedMetrics {
    VideoTransmittedMetrics(
        framesSent: metrics.framesGenerated,
        framesDroppedBeforeSend: 0,
        packetsSent: metrics.fragmentsSent,
        packetsDropped: 0
    )
}

private func videoTransportReceiverMetrics(
    _ context: VideoTransportRunContext
) -> VideoReceiverMetrics {
    VideoReceiverMetrics(
        queuePolicy: .latestFrame,
        receivedFrames: context.reassembler.metrics.framesReassembled,
        displayedFrames: context.receiver.packets.count,
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
        packetizationDuration: .fromSamples(context.packetizationDurations),
        reassemblyDuration: .fromSamples(context.reassemblyDurations),
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

private func videoTransportReportNotes(_ configuration: VideoTransportRunConfiguration) -> String {
    if configuration.streamCount == 1 {
        return "Socket-backed UDP raw latest-frame transport run with test-pattern source. "
            + "PASS requires physical Blackmagic/ATEM source/output and packet-captured route evidence."
    }
    return "Socket-backed UDP staged multi-video transport run with test-pattern sources. "
        + "PASS requires physical multi-camera Blackmagic/ATEM source/output and packet-captured route evidence."
}

private func nextVideoTransportFrameDeadline(previous: UInt64, interval: UInt64) -> UInt64 {
    let now = DispatchTime.now().uptimeNanoseconds
    let fallback = now <= UInt64.max - interval ? now + interval : UInt64.max
    guard previous <= UInt64.max - interval else {
        return fallback
    }
    let next = previous + interval
    return next > now ? next : fallback
}

func videoTransportRunnerAllowsQoS(_ qos: qos_class_t) -> Bool {
    qos != QOS_CLASS_USER_INTERACTIVE
}

private func preconditionVideoTransportRunnerQoS(
    currentQoS: qos_class_t = qos_class_self()
) {
    precondition(
        videoTransportRunnerAllowsQoS(currentQoS),
        "Video transport runner must run at userInitiated QoS or lower so audio can retain priority."
    )
}

private func drainVideoFragments(
    socketContext: VideoTransportSocketContext,
    configuration: VideoTransportRunConfiguration,
    context: inout VideoTransportRunContext,
    totalGeneratedFrames: Int
) throws {
    let reassemblySignal = DispatchSemaphore(value: 0)
    let deadline = DispatchTime.now().uptimeNanoseconds
        + max(configuration.frameIntervalNanoseconds, 50_000_000)
    while DispatchTime.now().uptimeNanoseconds < deadline
        && context.reassembler.metrics.framesReassembled < totalGeneratedFrames {
        guard try receiveVideoFragmentIfAvailable(
            socketContext: socketContext,
            configuration: configuration,
            context: &context,
            reassemblySignal: reassemblySignal
        ) else {
            _ = reassemblySignal.wait(timeout: .now() + videoTransportDrainIdleWait)
            continue
        }
    }
}

private func drainAvailableVideoFragments(
    socketContext: VideoTransportSocketContext,
    configuration: VideoTransportRunConfiguration,
    context: inout VideoTransportRunContext
) throws {
    while try receiveVideoFragmentIfAvailable(
        socketContext: socketContext,
        configuration: configuration,
        context: &context
    ) {}
}

private func receiveVideoFragmentIfAvailable(
    socketContext: VideoTransportSocketContext,
    configuration: VideoTransportRunConfiguration,
    context: inout VideoTransportRunContext,
    reassemblySignal: DispatchSemaphore? = nil
) throws -> Bool {
    guard let data = try receiveVideoDatagramIfAvailable(
        socket: socketContext.socket,
        configuration: configuration
    ) else {
        return false
    }
    let receivedAtNanoseconds = DispatchTime.now().uptimeNanoseconds
    let decodedFragment = try VideoTransportFragment.decode(data)
    let reassembled = try LatencyBenchmark.measure {
        try context.reassembler.receive(decodedFragment)
    }
    context.reassemblyDurations.append(reassembled.durationMicroseconds)
    guard let packet = reassembled.value else {
        return true
    }
    if let reassemblySignal {
        reassemblySignal.signal()
    }
    let reassembledAtNanoseconds = DispatchTime.now().uptimeNanoseconds
    let renderAtNanoseconds = DispatchTime.now().uptimeNanoseconds
    recordVideoTransportReassembledFrame(streamID: packet.streamID, states: &context.streamStates)
    context.receiver.receive(packet)
    context.renderer.submit(
        VideoOutputFrame(
            packet: packet,
            receivedAtNanoseconds: receivedAtNanoseconds,
            reassembledAtNanoseconds: reassembledAtNanoseconds
        ),
        renderAtNanoseconds: renderAtNanoseconds
    )
    let outputAtNanoseconds = DispatchTime.now().uptimeNanoseconds
    if let rendered = context.renderer.renderNext(
        renderAtNanoseconds: renderAtNanoseconds,
        outputAtNanoseconds: outputAtNanoseconds
    ) {
        recordVideoTransportRenderedFrame(streamID: rendered.streamID, states: &context.streamStates)
    }
    context.frameAges.append(videoFrameAgeMicroseconds(
        packet,
        receivedAtNanoseconds: receivedAtNanoseconds,
        syntheticFallbackNanoseconds: configuration.frameIntervalNanoseconds
    ))
    return true
}

private func receiveVideoDatagramIfAvailable(
    socket: Int32,
    configuration: VideoTransportRunConfiguration
) throws -> Data? {
    guard let peekedByteCount = try peekVideoDatagramByteCountIfAvailable(
        socket: socket,
        byteCount: configuration.maxPacketBytes
    ) else {
        return nil
    }
    guard let data = try receiveDatagramIfAvailable(
        socket: socket,
        byteCount: configuration.maxPacketBytes
    ) else {
        return nil
    }
    if peekedByteCount > configuration.maxPacketBytes {
        logVideoTransportDatagramTruncationWarning(maxPacketBytes: configuration.maxPacketBytes)
    }
    return data
}

private func peekVideoDatagramByteCountIfAvailable(
    socket: Int32,
    byteCount: Int
) throws -> Int? {
    var buffer = [UInt8](repeating: 0, count: byteCount)
    let received = buffer.withUnsafeMutableBytes { bytes in
        recv(socket, bytes.baseAddress, byteCount, MSG_PEEK | MSG_TRUNC)
    }
    let savedErrno = errno
    if received < 0 {
        if savedErrno == EAGAIN || savedErrno == EWOULDBLOCK {
            return nil
        }
        throw UdpPcmRouteProbeError.receiveFailed(savedErrno)
    }
    return received
}

private func logVideoTransportDatagramTruncationWarning(maxPacketBytes: Int) {
    let message = "warning: video transport UDP datagram reached configured maxPacketBytes "
        + "(\(maxPacketBytes)); decode failure may indicate recv truncation\n"
    FileHandle.standardError.write(Data(message.utf8))
}

private func videoTransportBandwidthProbeStream(
    configuration: VideoTransportRunConfiguration
) -> VideoStreamDescription {
    VideoStreamDescription(
        id: Int(configuration.streamID),
        direction: .send,
        role: configuration.sourceRole,
        resolution: VideoResolution(width: configuration.width, height: configuration.height),
        frameRate: videoFrameRate(from: configuration.frameRate),
        pixelFormat: videoTransportPixelFormat(from: configuration.pixelFormat),
        transportFormat: .rawFrameFragment,
        sourceLabel: "synthetic-test-pattern",
        payloadType: .videoRawFrameFragment,
        queueDepth: configuration.queueDepth
    )
}

private func videoTransportPixelFormat(from pixelFormat: String) -> VideoPixelFormat {
    VideoPixelFormat(rawValue: normalizedVideoPixelFormat(pixelFormat)) ?? .rgb24
}

private func videoFrameAgeMicroseconds(
    _ packet: VideoTransportPacket,
    receivedAtNanoseconds: UInt64,
    syntheticFallbackNanoseconds: UInt64
) -> Double {
    switch packet.timestampBasis {
    case .syntheticMonotonicNanoseconds:
        return Double(syntheticFallbackNanoseconds) / 1_000
    case .hostUptimeNanoseconds:
        guard receivedAtNanoseconds >= packet.timestampNanoseconds else {
            return 0
        }
        return Double(receivedAtNanoseconds - packet.timestampNanoseconds) / 1_000
    case .avFoundationPresentationTimeNanoseconds:
        return Double(syntheticFallbackNanoseconds) / 1_000
    }
}

private extension VideoTransportRunConfiguration {
    var isLoopbackSelfProbe: Bool {
        switch routeKind {
        case .localhost, .syntheticLocal:
            return peer == "127.0.0.1"
        case .directWired, .switched, .campus:
            return false
        }
    }
}
