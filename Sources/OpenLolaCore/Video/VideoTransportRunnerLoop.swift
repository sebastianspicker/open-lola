// Schedules frame deadlines, packetizes source frames, and drains fragments while enforcing the transport worker's QoS contract.
import Darwin
import Dispatch
import Foundation

// One fragment is the maximum video send quantum before the runner returns to
// socket receive readiness. This prevents a large video frame from imposing a
// fixed multi-fragment service delay on other realtime work.
private let videoTransportFragmentDrainInterval = 1

struct VideoTransportSocketContext {
    var socket: Int32
    var targetPort: UInt16
    var loopbackSelfProbe: Bool

    init(configuration: VideoTransportRunConfiguration) throws {
        socket = try makeUdpSocket(
            receiveTimeoutSeconds: 1,
            bufferProfile: .realtimeVideo
        )
        try setNonBlocking(socket)
        loopbackSelfProbe = configuration.isLoopbackSelfProbe
        try bindIPv4(
            socket,
            host: loopbackSelfProbe ? configuration.peer : "0.0.0.0",
            port: loopbackSelfProbe ? 0 : configuration.port.bigEndian
        )
        targetPort = loopbackSelfProbe ? try boundPort(socket) : configuration.port.bigEndian
    }
}

struct VideoTransportRunContext {
    var streamStates: [VideoTransportStreamRunState]
    var receiver: LatestVideoFrameReceiver
    var reassembler: VideoFrameReassembler
    var renderer: VideoOutputRenderer
    var frameAges = VideoTransportLatencyReservoir()
    var maxFragmentsPerFrame = 0
    var maxPayloadBytesPerFragment = 0
    var packetizationDurations = VideoTransportLatencyReservoir()
    var reassemblyDurations = VideoTransportLatencyReservoir()
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
    var cursor: RawVideoFrameTransport.SyntheticFragmentCursor
    var durationMicroseconds: Double
    var streamIndex: Int
}

private struct VideoTransportPreparedFragment {
    var fragment: VideoTransportFragment
    var datagram: Data
}

private struct VideoTransportFragmentSendState {
    var cursor: RawVideoFrameTransport.SyntheticFragmentCursor
    var packetizationDurationMicroseconds: Double
    var maxPayloadBytesPerFragment = 0

    init(_ packetizedFrame: VideoTransportPacketizedFrame) {
        cursor = packetizedFrame.cursor
        packetizationDurationMicroseconds = packetizedFrame.durationMicroseconds
    }
}

private struct VideoTransportFrameSendContext {
    var socketContext: VideoTransportSocketContext
    var configuration: VideoTransportRunConfiguration
    var deadline: UInt64
}

struct VideoTransportDeadlineSendOutcome: Equatable, Sendable {
    var unitsSent: Int
    var unitsDropped: Int
}

func runVideoTransportFrameLoop(
    configuration: VideoTransportRunConfiguration,
    socketContext: VideoTransportSocketContext,
    context: inout VideoTransportRunContext
) throws {
    for _ in 0..<configuration.frameCount {
        let frameDeadline = videoTransportFrameDeadline(
            start: context.nextFrameDeadline,
            interval: configuration.frameIntervalNanoseconds
        )
        for streamIndex in context.streamStates.indices {
            context.streamStates[streamIndex].framesScheduled += 1
            guard DispatchTime.now().uptimeNanoseconds < frameDeadline else {
                context.streamStates[streamIndex].framesDroppedBeforeSend += 1
                continue
            }
            try sendNextVideoFrame(
                configuration: configuration,
                socketContext: socketContext,
                context: &context,
                streamIndex: streamIndex,
                frameDeadline: frameDeadline
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
    streamIndex: Int,
    frameDeadline: UInt64
) throws {
    guard let frame = context.streamStates[streamIndex].source.nextFrame() else {
        context.streamStates[streamIndex].framesDroppedBeforeSend += 1
        return
    }
    context.streamStates[streamIndex].framesGenerated += 1
    guard DispatchTime.now().uptimeNanoseconds < frameDeadline else {
        context.streamStates[streamIndex].framesDroppedBeforeSend += 1
        return
    }
    let packetized = try LatencyBenchmark.measure {
        try RawVideoFrameTransport.syntheticFragmentCursor(
            for: frame,
            maxPacketBytes: configuration.maxPacketBytes
        )
    }
    context.streamStates[streamIndex].framesFragmented += 1
    try sendVideoFragments(
        VideoTransportPacketizedFrame(
            cursor: packetized.value,
            durationMicroseconds: packetized.durationMicroseconds,
            streamIndex: streamIndex
        ),
        configuration: configuration,
        socketContext: socketContext,
        context: &context,
        frameDeadline: frameDeadline
    )
}

private func sendVideoFragments(
    _ packetizedFrame: VideoTransportPacketizedFrame,
    configuration: VideoTransportRunConfiguration,
    socketContext: VideoTransportSocketContext,
    context: inout VideoTransportRunContext,
    frameDeadline: UInt64
) throws {
    var state = VideoTransportFragmentSendState(packetizedFrame)
    context.maxFragmentsPerFrame = max(context.maxFragmentsPerFrame, state.cursor.fragmentCount)
    let outcome = try sendVideoTransportUnitsUntilDeadline(
        unitCount: state.cursor.fragmentCount,
        deadline: frameDeadline,
        now: { DispatchTime.now().uptimeNanoseconds },
        prepare: { _ in try prepareVideoTransportFragment(state: &state) },
        send: { prepared in try sendVideoTransportFragment(
            prepared, socketContext: socketContext, configuration: configuration,
            context: &context, deadline: frameDeadline
        ) }
    )
    try finishVideoTransportFrameSend(
        packetizedFrame,
        outcome: outcome,
        sendState: state,
        context: &context,
        frame: VideoTransportFrameSendContext(
            socketContext: socketContext,
            configuration: configuration,
            deadline: frameDeadline
        )
    )
}

private func prepareVideoTransportFragment(
    state: inout VideoTransportFragmentSendState
) throws -> VideoTransportPreparedFragment {
    let prepared = try LatencyBenchmark.measure {
        guard let fragment = state.cursor.next() else {
            preconditionFailure("video fragment cursor ended before its declared fragment count")
        }
        return VideoTransportPreparedFragment(fragment: fragment, datagram: try fragment.encoded())
    }
    state.packetizationDurationMicroseconds += prepared.durationMicroseconds
    state.maxPayloadBytesPerFragment = max(state.maxPayloadBytesPerFragment, prepared.value.fragment.payloadByteCount)
    return prepared.value
}

private func sendVideoTransportFragment(
    _ prepared: VideoTransportPreparedFragment,
    socketContext: VideoTransportSocketContext,
    configuration: VideoTransportRunConfiguration,
    context: inout VideoTransportRunContext,
    deadline: UInt64
) throws -> UdpDatagramSendResult {
    let result = try trySendDatagram(
        prepared.datagram, socket: socketContext.socket, host: configuration.peer,
        port: socketContext.targetPort, nonBlocking: true
    )
    guard result == .sent,
          prepared.fragment.fragmentIndex % videoTransportFragmentDrainInterval
            == videoTransportFragmentDrainInterval - 1 else { return result }
    try drainAvailableVideoFragments(
        socketContext: socketContext, configuration: configuration, context: &context, deadline: deadline
    )
    return result
}

private func finishVideoTransportFrameSend(
    _ packetizedFrame: VideoTransportPacketizedFrame,
    outcome: VideoTransportDeadlineSendOutcome,
    sendState: VideoTransportFragmentSendState,
    context: inout VideoTransportRunContext,
    frame: VideoTransportFrameSendContext
) throws {
    context.packetizationDurations.record(sendState.packetizationDurationMicroseconds)
    context.maxPayloadBytesPerFragment = max(
        context.maxPayloadBytesPerFragment,
        sendState.maxPayloadBytesPerFragment
    )
    context.streamStates[packetizedFrame.streamIndex].fragmentsSent += outcome.unitsSent
    context.streamStates[packetizedFrame.streamIndex].packetsDropped += outcome.unitsDropped
    guard outcome.unitsDropped == 0 else {
        context.streamStates[packetizedFrame.streamIndex].framesDroppedBeforeSend += 1
        return
    }
    context.streamStates[packetizedFrame.streamIndex].framesCompletedSend += 1

    try drainVideoTransportLoopbackIfNeeded(
        frame: frame,
        context: &context
    )
}

private func drainVideoTransportLoopbackIfNeeded(
    frame: VideoTransportFrameSendContext,
    context: inout VideoTransportRunContext
) throws {
    // TX and loopback RX share the frame slot's original absolute deadline.
    // One-way routes never wait for an echo that their route does not provide.
    guard videoTransportWaitsForLoopbackReassembly(frame.socketContext.loopbackSelfProbe) else { return }
    try drainVideoFragments(
        socketContext: frame.socketContext, configuration: frame.configuration, context: &context,
        totalGeneratedFrames: videoTransportTotalFramesCompletedSend(context.streamStates), deadline: frame.deadline
    )
}

func sendVideoTransportUnitsUntilDeadline<Unit>(
    unitCount: Int,
    deadline: UInt64,
    now: () -> UInt64,
    prepare: (Int) throws -> Unit,
    send: (Unit) throws -> UdpDatagramSendResult
) rethrows -> VideoTransportDeadlineSendOutcome {
    var unitsSent = 0
    for index in 0..<max(0, unitCount) {
        guard now() < deadline else {
            break
        }
        let unit = try prepare(index)
        guard now() < deadline else {
            break
        }
        guard try send(unit) == .sent else {
            break
        }
        unitsSent += 1
    }
    return VideoTransportDeadlineSendOutcome(
        unitsSent: unitsSent,
        unitsDropped: max(0, unitCount - unitsSent)
    )
}

func videoTransportWaitsForLoopbackReassembly(_ loopbackSelfProbe: Bool) -> Bool {
    loopbackSelfProbe
}

func videoTransportFrameDeadline(start: UInt64, interval: UInt64) -> UInt64 {
    start <= UInt64.max - interval ? start + interval : UInt64.max
}

func nextVideoTransportFrameDeadline(previous: UInt64, interval: UInt64) -> UInt64 {
    videoTransportFrameDeadline(start: previous, interval: interval)
}

func videoTransportRunnerAllowsQoS(_ qos: qos_class_t) -> Bool {
    qos != QOS_CLASS_USER_INTERACTIVE
}

func preconditionVideoTransportRunnerQoS(
    currentQoS: qos_class_t = qos_class_self()
) {
    precondition(
        videoTransportRunnerAllowsQoS(currentQoS),
        "Video transport runner must run at userInitiated QoS or lower so audio can retain priority."
    )
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
