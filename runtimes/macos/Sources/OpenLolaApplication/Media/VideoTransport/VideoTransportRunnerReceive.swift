import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Receives bounded video datagrams, detects truncation, and feeds fragments into reassembly and rendering outside the send scheduler.
import Darwin
import Dispatch
import Foundation

let videoTransportPostTransmitLoopbackDrainMaximumNanoseconds: UInt64 = 250_000_000

func drainVideoFragments(
    socketContext: VideoTransportSocketContext,
    configuration: VideoTransportRunConfiguration,
    context: inout VideoTransportRunContext,
    totalGeneratedFrames: Int,
    deadline: UInt64
) throws {
    try drainVideoFragmentsUntilTarget(
        totalGeneratedFrames: totalGeneratedFrames,
        receivedFrameCount: { context.reassembler.metrics.framesReassembled },
        deadline: deadline,
        receiveFragmentIfAvailable: {
            try receiveVideoFragmentIfAvailable(
                socketContext: socketContext,
                configuration: configuration,
                context: &context,
                reassemblySignal: nil
            )
        },
        waitForReadableSocket: { timeoutMicroseconds in
            _ = try waitForReadableSocket(
                socket: socketContext.socket,
                timeoutMicroseconds: timeoutMicroseconds
            )
        }
    )
}

func drainVideoFragmentsUntilTarget(
    totalGeneratedFrames: Int,
    receivedFrameCount: () -> Int,
    deadline: UInt64,
    now: () -> UInt64 = { DispatchTime.now().uptimeNanoseconds },
    receiveFragmentIfAvailable: () throws -> Bool,
    waitForReadableSocket: (UInt64) throws -> Void
) rethrows {
    while now() < deadline && receivedFrameCount() < totalGeneratedFrames {
        guard try receiveFragmentIfAvailable() else {
            let currentTime = now()
            let remaining = deadline > currentTime ? deadline - currentTime : 0
            guard remaining > 0 else { break }
            try waitForReadableSocket(remaining / 1_000)
            continue
        }
    }
}

func drainVideoTransportLoopbackAfterTransmitIfNeeded(
    socketContext: VideoTransportSocketContext,
    configuration: VideoTransportRunConfiguration,
    context: inout VideoTransportRunContext
) throws {
    let totalCompletedSendFrames = videoTransportTotalFramesCompletedSend(context.streamStates)
    guard let deadline = videoTransportPostTransmitLoopbackDrainDeadline(
        loopbackSelfProbe: socketContext.loopbackSelfProbe,
        totalCompletedSendFrames: totalCompletedSendFrames,
        reassembledFrames: context.reassembler.metrics.framesReassembled,
        start: DispatchTime.now().uptimeNanoseconds
    ) else {
        return
    }
    try drainVideoFragments(
        socketContext: socketContext,
        configuration: configuration,
        context: &context,
        totalGeneratedFrames: totalCompletedSendFrames,
        deadline: deadline
    )
}

func videoTransportPostTransmitLoopbackDrainDeadline(
    loopbackSelfProbe: Bool,
    totalCompletedSendFrames: Int,
    reassembledFrames: Int,
    start: UInt64,
    maximumWaitNanoseconds: UInt64 = videoTransportPostTransmitLoopbackDrainMaximumNanoseconds
) -> UInt64? {
    guard loopbackSelfProbe, reassembledFrames < totalCompletedSendFrames else {
        return nil
    }
    return start <= UInt64.max - maximumWaitNanoseconds
        ? start + maximumWaitNanoseconds
        : UInt64.max
}

func drainAvailableVideoFragments(
    socketContext: VideoTransportSocketContext,
    configuration: VideoTransportRunConfiguration,
    context: inout VideoTransportRunContext,
    deadline: UInt64
) throws {
    while DispatchTime.now().uptimeNanoseconds < deadline,
          try receiveVideoFragmentIfAvailable(
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
    context.reassemblyDurations.record(reassembled.durationMicroseconds)
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
    context.frameAges.record(videoFrameAgeMicroseconds(
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
    case .remoteRTP90kNanoseconds:
        return Double(syntheticFallbackNanoseconds) / 1_000
    }
}
