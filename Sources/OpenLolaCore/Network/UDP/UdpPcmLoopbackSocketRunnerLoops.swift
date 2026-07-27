// Coordinates UDP media execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Darwin
import Dispatch
import Foundation

struct UdpPcmLoopbackSenderResult {
    let metrics: UdpPcmLoopbackMetrics
    let averageRttMicroseconds: Double
}

private struct UdpPcmLoopbackSenderAccounting {
    var sentBytesBySequence: [UInt64: Data] = [:]
    var seenEchoes = Set<UInt64>()
    var expectedSequence: UInt64?
    var rtts: [Double] = []
    var packetsEchoed = 0
    var byteExactEcho = true
    var duplicatePackets = 0
    var outOfOrderPackets = 0
    var malformedEchoPackets = 0
    var wrongSizeEchoPackets = 0
    var fatalReceiveErrors = 0
}

private struct LoopbackProbeContext {
    let sequenceNumber: UInt64
    let senderFrameIndex: UInt64
    let packetMode: UdpPcmPacketMode
}

struct UdpPcmLoopbackLooperResult {
    let packetsEchoed: Int
    let receiveErrors: Int
}

func runSender(
    configuration: UdpPcmLoopbackRunConfiguration,
    debug: inout DebugTrace
) throws -> UdpPcmLoopbackReport {
    let socket = try makeLoopbackRunSocket(
        configuration: configuration,
        bindPort: 0,
        dscp: configuration.dscp,
        debug: &debug
    )
    defer { close(socket) }
    debug.record(
        event: "socket-connect-attempt",
        fields: ["peer": configuration.peer, "peerPort": "\(configuration.port)"]
    )
    try connectUdpSocket(socket, host: configuration.peer, port: configuration.port.bigEndian)
    debug.record(
        event: "socket-connected",
        fields: ["peer": configuration.peer, "peerPort": "\(configuration.port)"]
    )
    let result = try runSenderLoop(socket: socket, configuration: configuration, debug: &debug)
    let diagnostics = makeDiagnosticsComparison(
        configuration: configuration,
        udpAverageRttMicroseconds: result.averageRttMicroseconds
    )
    return makeSenderReport(
        configuration: configuration,
        metrics: result.metrics,
        diagnostics: diagnostics,
        notes: "UDP PCM loopback sender measured byte-exact echo RTT. " +
"RTT/2 is only an estimate, not proven one-way audio latency."
    )
}

func runLooper(
    configuration: UdpPcmLoopbackRunConfiguration,
    debug: inout DebugTrace
) throws -> UdpPcmLoopbackReport {
    let socket = try makeLoopbackRunSocket(
        configuration: configuration,
        bindPort: configuration.port.bigEndian,
        dscp: nil,
        debug: &debug
    )
    defer { close(socket) }
    let result = try runLooperLoop(
        socket: socket,
        expectedByteCount: expectedByteCount(configuration.packetMode),
        expectedPackets: configuration.packetCount,
        durationSeconds: configuration.durationSeconds,
        debug: &debug
    )
    let metrics = makeLooperMetrics(result: result)
    return makeLooperReport(
        configuration: configuration,
        metrics: metrics,
        notes: "Looper echoed received datagrams unchanged. Sender report carries RTT evidence."
    )
}

private func makeLoopbackRunSocket(
    configuration: UdpPcmLoopbackRunConfiguration,
    bindPort: UInt16,
    dscp: Int?,
    debug: inout DebugTrace
) throws -> Int32 {
    debug.record(event: "socket-create-attempt", fields: ["role": configuration.role.rawValue])
    let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
    var succeeded = false
    defer {
        if !succeeded {
            close(socket)
        }
    }
    debug.record(
        event: "socket-created",
        fields: ["role": configuration.role.rawValue, "receiveTimeoutSeconds": "1"]
    )
    if let dscp {
        debug.record(event: "socket-dscp-attempt", fields: ["dscp": "\(dscp)"])
        try setDscp(dscp, socket: socket)
        debug.record(event: "socket-dscp-set", fields: ["dscp": "\(dscp)"])
    }
    debug.record(
        event: "socket-bind-attempt",
        fields: ["bindHost": configuration.bindHost, "bindPort": "\(UInt16(bigEndian: bindPort))"]
    )
    try bindIPv4(socket, host: configuration.bindHost, port: bindPort)
    debug.record(
        event: "socket-bound",
        fields: ["bindHost": configuration.bindHost, "bindPort": "\(UInt16(bigEndian: bindPort))"]
    )
    debug.record(event: "socket-nonblocking-attempt")
    try setNonBlocking(socket)
    debug.record(event: "socket-nonblocking-set")
    succeeded = true
    return socket
}

func makeLooperMetrics(result: UdpPcmLoopbackLooperResult) -> UdpPcmLoopbackMetrics {
    let delivery = UdpPcmLoopbackMetrics.Delivery(
        packetsSent: 0,
        packetsEchoed: result.packetsEchoed,
        lostPackets: 0,
        duplicatePackets: 0,
        outOfOrderPackets: 0
    )
    let rtt = LoopbackTimingMetrics(
        p50Microseconds: 0,
        p95Microseconds: 0,
        p99Microseconds: 0,
        maxMicroseconds: 0
    )
    let timing = UdpPcmLoopbackMetrics.Timing(
        rtt: rtt,
        oneWayEstimateMicroseconds: 0,
        jitterP99Microseconds: 0
    )
    return UdpPcmLoopbackMetrics(
        delivery: delivery,
        byteExactEcho: true,
        timing: timing
    )
}

func runSenderLoop(
    socket: Int32,
    configuration: UdpPcmLoopbackRunConfiguration,
    debug: inout DebugTrace
) throws -> UdpPcmLoopbackSenderResult {
    var accounting = UdpPcmLoopbackSenderAccounting()
    let intervalNanoseconds = packetIntervalNanoseconds(configuration.packetMode)
    let start = DispatchTime.now().uptimeNanoseconds
    let expectedBytes = expectedByteCount(configuration.packetMode)

    for index in 0..<configuration.packetCount {
        let probe = LoopbackProbeContext(
            sequenceNumber: UInt64(index),
            senderFrameIndex: UInt64(index * configuration.packetMode.framesPerPacket),
            packetMode: configuration.packetMode
        )
        let sentAt = try sendLoopbackProbe(
            socket: socket,
            probe: probe,
            sentBytesBySequence: &accounting.sentBytesBySequence,
            debug: &debug
        )

        if let echo = try waitForConnectedEcho(
            socket: socket,
            byteCount: expectedBytes,
            timeoutMicroseconds: connectedEchoTimeoutMicroseconds(packetIntervalNanoseconds: intervalNanoseconds),
            accounting: &accounting
        ) {
            recordConnectedEcho(
                echo,
                sentAt: sentAt,
                fallbackSequence: probe.sequenceNumber,
                accounting: &accounting,
                debug: &debug
            )
        }

        let nextDeadline = start + (UInt64(index + 1) * intervalNanoseconds)
        sleepUntilUptimeNanoseconds(nextDeadline)
    }

    let metrics = makeSenderLoopMetrics(configuration: configuration, accounting: accounting)
    return UdpPcmLoopbackSenderResult(
        metrics: metrics,
        averageRttMicroseconds: average(accounting.rtts)
    )
}

private func sendLoopbackProbe(
    socket: Int32,
    probe: LoopbackProbeContext,
    sentBytesBySequence: inout [UInt64: Data],
    debug: inout DebugTrace
) throws -> UInt64 {
    let packet = makeProbePacket(
        sequenceNumber: probe.sequenceNumber,
        senderFrameIndex: probe.senderFrameIndex,
        packetMode: probe.packetMode
    )
    let data = try packet.encoded()
    sentBytesBySequence[probe.sequenceNumber] = data
    let sentAt = DispatchTime.now().uptimeNanoseconds
    try sendConnectedDatagram(data, socket: socket)
    debug.record(
        event: "packet-sent",
        fields: ["sequence": "\(probe.sequenceNumber)", "bytes": "\(data.count)"]
    )
    return sentAt
}

private func recordConnectedEcho(
    _ echo: Data,
    sentAt: UInt64,
    fallbackSequence: UInt64,
    accounting: inout UdpPcmLoopbackSenderAccounting,
    debug: inout DebugTrace
) {
    let receivedAt = DispatchTime.now().uptimeNanoseconds
    let decoded = try? UdpPcmPacket.decode(echo)
    if let decoded {
        recordDecodedEcho(decoded.header.sequenceNumber, echo: echo, accounting: &accounting)
    } else {
        accounting.byteExactEcho = false
    }
    accounting.packetsEchoed += 1
    accounting.rtts.append(Double(receivedAt - sentAt) / 1_000)
    debug.record(
        event: "packet-echoed",
        fields: ["sequence": "\(decoded?.header.sequenceNumber ?? fallbackSequence)", "bytes": "\(echo.count)"]
    )
}

private func recordDecodedEcho(
    _ echoedSequence: UInt64,
    echo: Data,
    accounting: inout UdpPcmLoopbackSenderAccounting
) {
    if accounting.seenEchoes.contains(echoedSequence) {
        accounting.duplicatePackets += 1
    }
    if let expectedSequence = accounting.expectedSequence, echoedSequence < expectedSequence {
        accounting.outOfOrderPackets += 1
    }
    accounting.expectedSequence = echoedSequence + 1
    accounting.seenEchoes.insert(echoedSequence)
    if accounting.sentBytesBySequence[echoedSequence] != echo {
        accounting.byteExactEcho = false
    }
}

private func makeSenderLoopMetrics(
    configuration: UdpPcmLoopbackRunConfiguration,
    accounting: UdpPcmLoopbackSenderAccounting
) -> UdpPcmLoopbackMetrics {
    let delivery = UdpPcmLoopbackMetrics.Delivery(
        packetsSent: configuration.packetCount,
        packetsEchoed: accounting.packetsEchoed,
        lostPackets: max(0, configuration.packetCount - accounting.seenEchoes.count),
        duplicatePackets: accounting.duplicatePackets,
        outOfOrderPackets: accounting.outOfOrderPackets,
        malformedEchoPackets: accounting.malformedEchoPackets,
        wrongSizeEchoPackets: accounting.wrongSizeEchoPackets,
        fatalReceiveErrors: accounting.fatalReceiveErrors
    )
    let timing = UdpPcmLoopbackMetrics.Timing(
        rtt: loopbackTimingMetrics(for: accounting.rtts),
        oneWayEstimateMicroseconds: percentile(accounting.rtts, rank: 0.50) / 2,
        jitterP99Microseconds: jitterP99Microseconds(for: accounting.rtts)
    )
    return UdpPcmLoopbackMetrics(
        delivery: delivery,
        byteExactEcho: accounting.byteExactEcho,
        timing: timing
    )
}

func runLooperLoop(
    socket: Int32,
    expectedByteCount: Int,
    expectedPackets: Int,
    durationSeconds: Int,
    debug: inout DebugTrace
) throws -> UdpPcmLoopbackLooperResult {
    try runUdpPcmLooperLoop(
        request: UdpPcmLooperLoopRequest(
            socket: socket,
            expectedByteCount: expectedByteCount,
            expectedPackets: expectedPackets,
            durationSeconds: durationSeconds
        ),
        debug: &debug,
        io: UdpPcmLooperLoopIO(
            receive: receiveDatagramFromIfAvailable,
            echo: echoAddressedLooperDatagram
        )
    )
}

struct UdpPcmLooperLoopRequest {
    let socket: Int32
    let expectedByteCount: Int
    let expectedPackets: Int
    let durationSeconds: Int
}

struct UdpPcmLooperLoopIO<Datagram> {
    let receive: (Int32, Int) throws -> Datagram?
    let echo: (Datagram, Int32, Int, inout DebugTrace) throws -> Bool
}

func runUdpPcmLooperLoop<Datagram>(
    request: UdpPcmLooperLoopRequest,
    debug: inout DebugTrace,
    io: UdpPcmLooperLoopIO<Datagram>
) throws -> UdpPcmLoopbackLooperResult {
    let deadline = try routeDeadlineNanoseconds(durationSeconds: request.durationSeconds)
    var echoed = 0
    var errors = 0
    while DispatchTime.now().uptimeNanoseconds < deadline && echoed < request.expectedPackets {
        do {
            guard let received = try io.receive(request.socket, request.expectedByteCount) else {
                try waitForReadableSocket(socket: request.socket, timeoutMicroseconds: 1_000)
                continue
            }
            if try io.echo(received, request.socket, request.expectedByteCount, &debug) {
                echoed += 1
            }
        } catch UdpPcmRouteProbeError.receiveFailed(let error)
            where error == EAGAIN || error == EWOULDBLOCK {
            try waitForReadableSocket(socket: request.socket, timeoutMicroseconds: 1_000)
        } catch {
            errors += 1
        }
    }
    return UdpPcmLoopbackLooperResult(packetsEchoed: echoed, receiveErrors: errors)
}

private func echoAddressedLooperDatagram(
    _ received: ReceivedDatagram,
    socket: Int32,
    expectedByteCount: Int,
    debug: inout DebugTrace
) throws -> Bool {
    guard received.data.count == expectedByteCount,
          (try? UdpPcmPacket.decode(received.data)) != nil else {
        debug.record(
            event: "non-pcm-datagram-ignored",
            fields: ["bytes": "\(received.data.count)"]
        )
        return false
    }
    try sendDatagram(received.data, socket: socket, address: received.address)
    debug.record(event: "packet-looped", fields: ["bytes": "\(received.data.count)"])
    return true
}

private func waitForConnectedEcho(
    socket: Int32,
    byteCount: Int,
    timeoutMicroseconds: UInt64,
    accounting: inout UdpPcmLoopbackSenderAccounting
) throws -> Data? {
    let deadline = try routeDeadlineNanoseconds(timeoutMicroseconds: timeoutMicroseconds)
    while DispatchTime.now().uptimeNanoseconds < deadline {
        do {
            if let data = try receiveDatagramIfAvailable(socket: socket, byteCount: byteCount) {
                guard data.count == byteCount else {
                    accounting.wrongSizeEchoPackets += 1
                    continue
                }
                guard (try? UdpPcmPacket.decode(data)) != nil else {
                    accounting.malformedEchoPackets += 1
                    continue
                }
                return data
            }
        } catch UdpPcmRouteProbeError.receiveFailed(let error)
            where isFatalConnectedUdpReceiveError(error) {
            accounting.fatalReceiveErrors += 1
            return nil
        }
        let now = DispatchTime.now().uptimeNanoseconds
        guard deadline > now else {
            break
        }
        try waitForReadableSocket(
            socket: socket,
            timeoutMicroseconds: min(1_000, max(1, (deadline - now) / 1_000))
        )
    }
    return nil
}
