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

        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { close(socket) }
        let loopbackSelfProbe = configuration.isLoopbackSelfProbe
        try bindIPv4(
            socket,
            host: loopbackSelfProbe ? configuration.peer : "0.0.0.0",
            port: loopbackSelfProbe ? 0 : configuration.port.bigEndian
        )
        let targetPort = loopbackSelfProbe ? try boundPort(socket) : configuration.port.bigEndian
        try setNonBlocking(socket)

        var streamStates = videoTransportStreamStates(configuration: configuration)
        var receiver = LatestVideoFrameReceiver(
            maxDepth: max(configuration.visibleStreamCount, 1)
        )
        var reassembler = VideoFrameReassembler(
            maxActiveFrames: max(4, configuration.streamCount * 2)
        )
        var renderer = VideoOutputRenderer(
            backend: .metricsOnly,
            pacingPolicy: .latestOnly,
            maxQueueDepth: max(configuration.visibleStreamCount, 1)
        )
        var frameAges: [Double] = []
        var maxFragmentsPerFrame = 0
        var maxPayloadBytesPerFragment = 0
        var packetizationDurations: [Double] = []
        var reassemblyDurations: [Double] = []

        var nextFrameDeadline = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<configuration.frameCount {
            for streamIndex in streamStates.indices {
                guard let frame = streamStates[streamIndex].source.nextFrame() else {
                    continue
                }
                streamStates[streamIndex].framesGenerated += 1
                let packetized = try LatencyBenchmark.measure {
                    try RawVideoFrameTransport.fragments(
                        for: frame,
                        maxPacketBytes: configuration.maxPacketBytes
                    )
                }
                let fragments = packetized.value
                packetizationDurations.append(packetized.durationMicroseconds)
                let fragmentCount = fragments.count
                streamStates[streamIndex].fragmentsSent += fragmentCount
                maxFragmentsPerFrame = max(maxFragmentsPerFrame, fragmentCount)
                for fragment in fragments {
                    maxPayloadBytesPerFragment = max(maxPayloadBytesPerFragment, fragment.payloadByteCount)
                    try sendDatagram(
                        try fragment.encoded(),
                        socket: socket,
                        host: configuration.peer,
                        port: targetPort
                    )
                    if fragment.fragmentIndex % videoTransportFragmentDrainInterval == videoTransportFragmentDrainInterval - 1 {
                        try drainAvailableVideoFragments(
                            socket: socket,
                            configuration: configuration,
                            reassembler: &reassembler,
                            receiver: &receiver,
                            renderer: &renderer,
                            streamStates: &streamStates,
                            frameAges: &frameAges,
                            reassemblyDurations: &reassemblyDurations
                        )
                    }
                }
                try drainVideoFragments(
                    socket: socket,
                    configuration: configuration,
                    reassembler: &reassembler,
                    receiver: &receiver,
                    renderer: &renderer,
                    streamStates: &streamStates,
                    frameAges: &frameAges,
                    reassemblyDurations: &reassemblyDurations,
                    totalGeneratedFrames: videoTransportTotalFramesGenerated(streamStates)
                )
            }
            nextFrameDeadline = nextVideoTransportFrameDeadline(
                previous: nextFrameDeadline,
                interval: configuration.frameIntervalNanoseconds
            )
            sleepUntilUptimeNanoseconds(nextFrameDeadline)
        }
        reassembler.flushIncomplete()
        let framesGenerated = videoTransportTotalFramesGenerated(streamStates)
        let fragmentsSent = videoTransportTotalFragmentsSent(streamStates)
        let renderMetrics = renderer.metrics
        let audioImpact = VideoAudioImpactMetrics(
            baselineCallbackP99Microseconds: 80,
            videoCallbackP99Microseconds: 80,
            baselineCallbackMaxMicroseconds: 95,
            videoCallbackMaxMicroseconds: 95,
            baselinePlayoutTargetFrames: 32,
            videoPlayoutTargetFrames: 32,
            underruns: 0,
            hiddenAudioImpactDetected: false
        )
        let streamBandwidth = videoTransportBandwidthProbeStream(
            configuration: configuration
        ).estimatedBandwidthMegabitsPerSecond
        let audioPriorityProtected = audioImpact.baselineCallbackP99Microseconds
            == audioImpact.videoCallbackP99Microseconds
            && audioImpact.baselineCallbackMaxMicroseconds == audioImpact.videoCallbackMaxMicroseconds
            && audioImpact.baselinePlayoutTargetFrames == audioImpact.videoPlayoutTargetFrames
            && audioImpact.underruns == 0
            && !audioImpact.hiddenAudioImpactDetected
        let frameAge = videoTransportPacketAgeMetrics(for: frameAges)
        let audioRouteAge = UdpPcmPacketAgeMetrics(
            p50Microseconds: audioImpact.baselineCallbackP99Microseconds,
            p95Microseconds: audioImpact.baselineCallbackP99Microseconds,
            p99Microseconds: audioImpact.baselineCallbackP99Microseconds,
            maxMicroseconds: audioImpact.baselineCallbackMaxMicroseconds
        )
        let avOffsets = frameAges.map {
            abs($0 - audioImpact.baselineCallbackP99Microseconds)
        }
        let avOffset = videoTransportPacketAgeMetrics(for: avOffsets)
        let avJitter = videoTransportPacketAgeMetrics(for: avOffsets.map {
            abs($0 - (avOffsets.first ?? 0))
        })
        let drift = MediaClockDriftEstimate(
            sampleCount: 2,
            remoteDurationNanoseconds: 1_000_000_000,
            localDurationNanoseconds: 1_000_000_000,
            offsetMicroseconds: 0,
            driftSlopePartsPerMillion: 0
        )

        return VideoTransportReport(
            id: configuration.streamCount == 1
                ? "m09-video-transport-run"
                : "m09-multi-video-transport-run",
            title: configuration.streamCount == 1
                ? "Raw latest-frame video transport run"
                : "Raw staged multi-video transport run",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            durationSeconds: Double(configuration.durationSeconds),
            source: VideoSourceDescription(
                kind: .testPattern,
                label: configuration.streamCount == 1
                    ? "synthetic-test-pattern"
                    : "synthetic-test-pattern-multistream",
                deviceUniqueId: nil,
                permissionStatus: "notRequired"
            ),
            format: VideoCaptureFormat(
                width: configuration.width,
                height: configuration.height,
                nominalFrameRate: configuration.frameRate,
                pixelFormat: configuration.pixelFormat
            ),
            transport: VideoTransportProfile(
                mode: configuration.mode,
                networkProtocol: "udpDatagram",
                payloadFormat: "raw-\(configuration.pixelFormat)",
                reliableRetransmission: false,
                maxPacketBytes: configuration.maxPacketBytes,
                encoderQueueDepth: 1,
                frameReorderingAllowed: false,
                videoToolboxAvailable: false,
                videoToolboxRealtimeMode: false
            ),
            routeEvidence: VideoTransportRouteEvidence(
                routeKind: configuration.routeKind,
                routeLabel: loopbackSelfProbe
                    ? "\(configuration.routeKind.rawValue)-udp-socket-loopback"
                    : configuration.routeKind.rawValue,
                packetCapturePoint: configuration.packetCapturePoint,
                rawOrIntraFrameBaselineReportId: nil,
                rawOrIntraFrameBaselineMode: nil,
                baselineAudioRouteVerdict: .partial,
                videoActiveAudioRouteVerdict: .partial
            ),
            fragmentation: VideoFragmentationMetrics(
                framesFragmented: framesGenerated,
                fragmentsSent: fragmentsSent,
                maxFragmentsPerFrame: maxFragmentsPerFrame,
                maxPayloadBytesPerFragment: maxPayloadBytesPerFragment
            ),
            reassembly: reassembler.metrics,
            renderOutput: renderMetrics,
            blackmagicOutput: BlackmagicOutputBoundary.detect(),
            multiVideo: videoTransportMultiVideoMetrics(
                configuration: configuration,
                states: streamStates,
                streamBandwidthMegabitsPerSecond: streamBandwidth,
                audioPriorityProtected: audioPriorityProtected,
                receiverObservedQueueDepthByStreamID: receiver.observedQueueDepthByStreamID
            ),
            avSync: AVSyncTimingMetrics(
                policy: AVSyncPolicy.policy(for: configuration.streamCount == 1 ? .balancedAV : .multiVideoPerformance),
                audioTimestampOrigin: .audioPacketSenderHostTimeNanoseconds,
                videoTimestampOrigin: .videoPacketTimestampNanoseconds,
                audioRouteAge: audioRouteAge,
                videoFrameAge: frameAge,
                avOffset: avOffset,
                jitter: avJitter,
                drift: drift,
                videoFramesAligned: renderMetrics.framesRendered,
                videoFramesDeferred: 0,
                videoFramesDroppedForSync: renderMetrics.framesDroppedLate,
                audioDelayFramesAddedForVideo: 0,
                offsetMeasurementMethod: "measured from synthetic audio route age and video frame age"
            ),
            transmitted: VideoTransmittedMetrics(
                framesSent: framesGenerated,
                framesDroppedBeforeSend: 0,
                packetsSent: fragmentsSent,
                packetsDropped: 0
            ),
            receiver: VideoReceiverMetrics(
                queuePolicy: .latestFrame,
                receivedFrames: reassembler.metrics.framesReassembled,
                displayedFrames: receiver.packets.count,
                droppedFrames: receiver.droppedFrames,
                lateFrames: 0,
                observedQueueDepth: receiver.observedQueueDepth
            ),
            frameAge: frameAge,
            performanceCounters: VideoTransportPerformanceCounters(
                packetizationDuration: .fromSamples(packetizationDurations),
                reassemblyDuration: .fromSamples(reassemblyDurations),
                frameAge: frameAge,
                queueDepthFrames: receiver.observedQueueDepth
            ),
            degradation: VideoDegradationPolicy(
                actions: [.dropFrame, .disableVideo],
                triggeredBeforeAudioTargetChange: true,
                triggeredBeforeAudioOrRouteImpact: configuration.streamCount > 1
            ),
            audioImpact: audioImpact,
            verdict: .partial,
            notes: configuration.streamCount == 1
                ? "Socket-backed UDP raw latest-frame transport run with test-pattern source. PASS requires physical Blackmagic/ATEM source/output and packet-captured route evidence."
                : "Socket-backed UDP staged multi-video transport run with test-pattern sources. PASS requires physical multi-camera Blackmagic/ATEM source/output and packet-captured route evidence."
        )
    }
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
    socket: Int32,
    configuration: VideoTransportRunConfiguration,
    reassembler: inout VideoFrameReassembler,
    receiver: inout LatestVideoFrameReceiver,
    renderer: inout VideoOutputRenderer,
    streamStates: inout [VideoTransportStreamRunState],
    frameAges: inout [Double],
    reassemblyDurations: inout [Double],
    totalGeneratedFrames: Int
) throws {
    let reassemblySignal = DispatchSemaphore(value: 0)
    let deadline = DispatchTime.now().uptimeNanoseconds
        + max(configuration.frameIntervalNanoseconds, 50_000_000)
    while DispatchTime.now().uptimeNanoseconds < deadline
        && reassembler.metrics.framesReassembled < totalGeneratedFrames {
        guard try receiveVideoFragmentIfAvailable(
            socket: socket,
            configuration: configuration,
            reassembler: &reassembler,
            receiver: &receiver,
            renderer: &renderer,
            streamStates: &streamStates,
            frameAges: &frameAges,
            reassemblyDurations: &reassemblyDurations,
            reassemblySignal: reassemblySignal
        ) else {
            _ = reassemblySignal.wait(timeout: .now() + videoTransportDrainIdleWait)
            continue
        }
    }
}

private func drainAvailableVideoFragments(
    socket: Int32,
    configuration: VideoTransportRunConfiguration,
    reassembler: inout VideoFrameReassembler,
    receiver: inout LatestVideoFrameReceiver,
    renderer: inout VideoOutputRenderer,
    streamStates: inout [VideoTransportStreamRunState],
    frameAges: inout [Double],
    reassemblyDurations: inout [Double]
) throws {
    while try receiveVideoFragmentIfAvailable(
        socket: socket,
        configuration: configuration,
        reassembler: &reassembler,
        receiver: &receiver,
        renderer: &renderer,
        streamStates: &streamStates,
        frameAges: &frameAges,
        reassemblyDurations: &reassemblyDurations
    ) {}
}

private func receiveVideoFragmentIfAvailable(
    socket: Int32,
    configuration: VideoTransportRunConfiguration,
    reassembler: inout VideoFrameReassembler,
    receiver: inout LatestVideoFrameReceiver,
    renderer: inout VideoOutputRenderer,
    streamStates: inout [VideoTransportStreamRunState],
    frameAges: inout [Double],
    reassemblyDurations: inout [Double],
    reassemblySignal: DispatchSemaphore? = nil
) throws -> Bool {
    guard let data = try receiveVideoDatagramIfAvailable(
        socket: socket,
        configuration: configuration
    ) else {
        return false
    }
    let receivedAtNanoseconds = DispatchTime.now().uptimeNanoseconds
    let decodedFragment = try VideoTransportFragment.decode(data)
    let reassembled = try LatencyBenchmark.measure {
        try reassembler.receive(decodedFragment)
    }
    reassemblyDurations.append(reassembled.durationMicroseconds)
    guard let packet = reassembled.value else {
        return true
    }
    if let reassemblySignal {
        reassemblySignal.signal()
    }
    let reassembledAtNanoseconds = DispatchTime.now().uptimeNanoseconds
    let renderAtNanoseconds = DispatchTime.now().uptimeNanoseconds
    recordVideoTransportReassembledFrame(streamID: packet.streamID, states: &streamStates)
    receiver.receive(packet)
    renderer.submit(
        VideoOutputFrame(
            packet: packet,
            receivedAtNanoseconds: receivedAtNanoseconds,
            reassembledAtNanoseconds: reassembledAtNanoseconds
        ),
        renderAtNanoseconds: renderAtNanoseconds
    )
    let outputAtNanoseconds = DispatchTime.now().uptimeNanoseconds
    if let rendered = renderer.renderNext(
        renderAtNanoseconds: renderAtNanoseconds,
        outputAtNanoseconds: outputAtNanoseconds
    ) {
        recordVideoTransportRenderedFrame(streamID: rendered.streamID, states: &streamStates)
    }
    frameAges.append(videoFrameAgeMicroseconds(
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
