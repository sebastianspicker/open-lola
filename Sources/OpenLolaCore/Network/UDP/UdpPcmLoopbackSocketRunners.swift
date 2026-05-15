import Darwin
import Dispatch
import Foundation

public enum UdpPcmLoopbackEstablishedSocketRunner {
    public static func run(
        socket: Int32,
        configuration: UdpPcmLoopbackRunConfiguration,
        debug: inout DebugTrace
    ) throws -> UdpPcmLoopbackReport {
        switch configuration.role {
        case .sender:
            let result = try runSenderLoop(
                socket: socket,
                configuration: configuration,
                debug: &debug
            )
            return makeSenderReport(
                configuration: configuration,
                metrics: result.metrics,
                diagnostics: nil,
                notes: "UDP PCM loopback sender measured byte-exact echo RTT through an established NAT traversal socket."
            )
        case .looper:
            let result = try runConnectedLooperLoop(
                socket: socket,
                expectedByteCount: expectedByteCount(configuration.packetMode),
                expectedPackets: configuration.packetCount,
                durationSeconds: configuration.durationSeconds,
                debug: &debug
            )
            let metrics = UdpPcmLoopbackMetrics(
                packetsSent: 0,
                packetsEchoed: result.packetsEchoed,
                lostPackets: 0,
                byteExactEcho: true,
                rtt: LoopbackTimingMetrics(
                    p50Microseconds: 0,
                    p95Microseconds: 0,
                    p99Microseconds: 0,
                    maxMicroseconds: 0
                ),
                oneWayEstimateMicroseconds: 0,
                jitterP99Microseconds: 0,
                duplicatePackets: 0,
                outOfOrderPackets: 0
            )
            return makeLooperReport(
                configuration: configuration,
                metrics: metrics,
                notes: "Looper echoed NAT traversal socket datagrams unchanged. Sender report carries RTT evidence."
            )
        }
    }
}

private func runConnectedLooperLoop(
    socket: Int32,
    expectedByteCount: Int,
    expectedPackets: Int,
    durationSeconds: Int,
    debug: inout DebugTrace
) throws -> UdpPcmLoopbackLooperResult {
    let deadline = try routeDeadlineNanoseconds(durationSeconds: durationSeconds)
    var echoed = 0
    var errors = 0
    while DispatchTime.now().uptimeNanoseconds < deadline && echoed < expectedPackets {
        do {
            guard let received = try receiveDatagramIfAvailable(
                socket: socket,
                byteCount: expectedByteCount
            ) else {
                try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)
                continue
            }
            guard received.count == expectedByteCount else {
                debug.record(
                    event: "non-pcm-datagram-ignored",
                    fields: ["bytes": "\(received.count)"]
                )
                continue
            }
            do {
                _ = try UdpPcmPacket.decode(received)
            } catch {
                debug.record(
                    event: "non-pcm-datagram-ignored",
                    fields: ["bytes": "\(received.count)", "error": String(describing: error)]
                )
                continue
            }
            try sendConnectedDatagram(received, socket: socket)
            echoed += 1
            debug.record(event: "packet-looped", fields: ["bytes": "\(received.count)"])
        } catch UdpPcmRouteProbeError.receiveFailed(let error)
            where error == EAGAIN || error == EWOULDBLOCK {
            try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)
        } catch {
            errors += 1
        }
    }
    return UdpPcmLoopbackLooperResult(packetsEchoed: echoed, receiveErrors: errors)
}

struct UdpPcmLoopbackSenderResult {
    let metrics: UdpPcmLoopbackMetrics
    let averageRttMicroseconds: Double
}

struct UdpPcmLoopbackLooperResult {
    let packetsEchoed: Int
    let receiveErrors: Int
}

func runSender(
    configuration: UdpPcmLoopbackRunConfiguration,
    debug: inout DebugTrace
) throws -> UdpPcmLoopbackReport {
    debug.record(event: "socket-create-attempt", fields: ["role": configuration.role.rawValue])
    let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { close(socket) }
    debug.record(
        event: "socket-created",
        fields: ["role": configuration.role.rawValue, "receiveTimeoutSeconds": "1"]
    )
    if let dscp = configuration.dscp {
        debug.record(event: "socket-dscp-attempt", fields: ["dscp": "\(dscp)"])
        try setDscp(dscp, socket: socket)
        debug.record(event: "socket-dscp-set", fields: ["dscp": "\(dscp)"])
    }
    debug.record(
        event: "socket-bind-attempt",
        fields: ["bindHost": configuration.bindHost, "bindPort": "0"]
    )
    try bindIPv4(socket, host: configuration.bindHost, port: 0)
    debug.record(
        event: "socket-bound",
        fields: ["bindHost": configuration.bindHost, "bindPort": "0"]
    )
    debug.record(event: "socket-nonblocking-attempt")
    try setNonBlocking(socket)
    debug.record(event: "socket-nonblocking-set")
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
        notes: "UDP PCM loopback sender measured byte-exact echo RTT. RTT/2 is only an estimate, not proven one-way audio latency."
    )
}

func runLooper(
    configuration: UdpPcmLoopbackRunConfiguration,
    debug: inout DebugTrace
) throws -> UdpPcmLoopbackReport {
    debug.record(event: "socket-create-attempt", fields: ["role": configuration.role.rawValue])
    let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { close(socket) }
    debug.record(
        event: "socket-created",
        fields: ["role": configuration.role.rawValue, "receiveTimeoutSeconds": "1"]
    )
    debug.record(
        event: "socket-bind-attempt",
        fields: ["bindHost": configuration.bindHost, "bindPort": "\(configuration.port)"]
    )
    try bindIPv4(socket, host: configuration.bindHost, port: configuration.port.bigEndian)
    debug.record(
        event: "socket-bound",
        fields: ["bindHost": configuration.bindHost, "bindPort": "\(configuration.port)"]
    )
    debug.record(event: "socket-nonblocking-attempt")
    try setNonBlocking(socket)
    debug.record(event: "socket-nonblocking-set")
    let result = try runLooperLoop(
        socket: socket,
        expectedByteCount: expectedByteCount(configuration.packetMode),
        expectedPackets: configuration.packetCount,
        durationSeconds: configuration.durationSeconds,
        debug: &debug
    )
    let metrics = UdpPcmLoopbackMetrics(
        packetsSent: 0,
        packetsEchoed: result.packetsEchoed,
        lostPackets: 0,
        byteExactEcho: true,
        rtt: LoopbackTimingMetrics(
            p50Microseconds: 0,
            p95Microseconds: 0,
            p99Microseconds: 0,
            maxMicroseconds: 0
        ),
        oneWayEstimateMicroseconds: 0,
        jitterP99Microseconds: 0,
        duplicatePackets: 0,
        outOfOrderPackets: 0
    )
    return makeLooperReport(
        configuration: configuration,
        metrics: metrics,
        notes: "Looper echoed received datagrams unchanged. Sender report carries RTT evidence."
    )
}

func runSenderLoop(
    socket: Int32,
    configuration: UdpPcmLoopbackRunConfiguration,
    debug: inout DebugTrace
) throws -> UdpPcmLoopbackSenderResult {
    var sentBytesBySequence: [UInt64: Data] = [:]
    var seenEchoes = Set<UInt64>()
    var expectedSequence: UInt64?
    var rtts: [Double] = []
    var packetsEchoed = 0
    var byteExactEcho = true
    var duplicatePackets = 0
    var outOfOrderPackets = 0
    let intervalNanoseconds = packetIntervalNanoseconds(configuration.packetMode)
    let start = DispatchTime.now().uptimeNanoseconds
    let expectedBytes = expectedByteCount(configuration.packetMode)

    for index in 0..<configuration.packetCount {
        let sequence = UInt64(index)
        let packet = makeProbePacket(
            sequenceNumber: sequence,
            senderFrameIndex: UInt64(index * configuration.packetMode.framesPerPacket),
            packetMode: configuration.packetMode
        )
        let data = try packet.encoded()
        sentBytesBySequence[sequence] = data
        let sentAt = DispatchTime.now().uptimeNanoseconds
        try sendConnectedDatagram(data, socket: socket)
        debug.record(
            event: "packet-sent",
            fields: ["sequence": "\(sequence)", "bytes": "\(data.count)"]
        )

        if let echo = try waitForConnectedEcho(
            socket: socket,
            byteCount: expectedBytes,
            timeoutMicroseconds: connectedEchoTimeoutMicroseconds(packetIntervalNanoseconds: intervalNanoseconds)
        ) {
            let receivedAt = DispatchTime.now().uptimeNanoseconds
            let decoded = try? UdpPcmPacket.decode(echo)
            if let decoded {
                let echoedSequence = decoded.header.sequenceNumber
                if seenEchoes.contains(echoedSequence) {
                    duplicatePackets += 1
                }
                if let expectedSequence, echoedSequence < expectedSequence {
                    outOfOrderPackets += 1
                }
                expectedSequence = echoedSequence + 1
                seenEchoes.insert(echoedSequence)
                if sentBytesBySequence[echoedSequence] != echo {
                    byteExactEcho = false
                }
            } else {
                byteExactEcho = false
            }
            packetsEchoed += 1
            rtts.append(Double(receivedAt - sentAt) / 1_000)
            debug.record(
                event: "packet-echoed",
                fields: ["sequence": "\(decoded?.header.sequenceNumber ?? sequence)", "bytes": "\(echo.count)"]
            )
        }

        let nextDeadline = start + (UInt64(index + 1) * intervalNanoseconds)
        sleepUntilUptimeNanoseconds(nextDeadline)
    }

    let metrics = UdpPcmLoopbackMetrics(
        packetsSent: configuration.packetCount,
        packetsEchoed: packetsEchoed,
        lostPackets: max(0, configuration.packetCount - packetsEchoed),
        byteExactEcho: byteExactEcho,
        rtt: loopbackTimingMetrics(for: rtts),
        oneWayEstimateMicroseconds: percentile(rtts, rank: 0.50) / 2,
        jitterP99Microseconds: jitterP99Microseconds(for: rtts),
        duplicatePackets: duplicatePackets,
        outOfOrderPackets: outOfOrderPackets
    )
    return UdpPcmLoopbackSenderResult(
        metrics: metrics,
        averageRttMicroseconds: average(rtts)
    )
}

func runLooperLoop(
    socket: Int32,
    expectedByteCount: Int,
    expectedPackets: Int,
    durationSeconds: Int,
    debug: inout DebugTrace
) throws -> UdpPcmLoopbackLooperResult {
    let deadline = try routeDeadlineNanoseconds(durationSeconds: durationSeconds)
    var echoed = 0
    var errors = 0
    while DispatchTime.now().uptimeNanoseconds < deadline && echoed < expectedPackets {
        do {
            guard let received = try receiveDatagramFromIfAvailable(
                socket: socket,
                byteCount: expectedByteCount
            ) else {
                try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)
                continue
            }
            guard received.data.count == expectedByteCount,
                  (try? UdpPcmPacket.decode(received.data)) != nil else {
                debug.record(
                    event: "non-pcm-datagram-ignored",
                    fields: ["bytes": "\(received.data.count)"]
                )
                continue
            }
            try sendDatagram(received.data, socket: socket, address: received.address)
            echoed += 1
            debug.record(event: "packet-looped", fields: ["bytes": "\(received.data.count)"])
        } catch UdpPcmRouteProbeError.receiveFailed(let error)
            where error == EAGAIN || error == EWOULDBLOCK {
            try waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)
        } catch {
            errors += 1
        }
    }
    return UdpPcmLoopbackLooperResult(packetsEchoed: echoed, receiveErrors: errors)
}

private func waitForConnectedEcho(
    socket: Int32,
    byteCount: Int,
    timeoutMicroseconds: UInt64
) throws -> Data? {
    let deadline = try routeDeadlineNanoseconds(timeoutMicroseconds: timeoutMicroseconds)
    while DispatchTime.now().uptimeNanoseconds < deadline {
        do {
            if let data = try receiveDatagramIfAvailable(socket: socket, byteCount: byteCount) {
                guard data.count == byteCount,
                      (try? UdpPcmPacket.decode(data)) != nil else {
                    continue
                }
                return data
            }
        } catch UdpPcmRouteProbeError.receiveFailed(let error)
            where isFatalConnectedUdpReceiveError(error) {
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

private func connectedEchoTimeoutMicroseconds(packetIntervalNanoseconds: UInt64) -> UInt64 {
    max((packetIntervalNanoseconds / 1_000) * 3, 50_000)
}

private func isFatalConnectedUdpReceiveError(_ error: Int32) -> Bool {
    error == ECONNREFUSED || error == EHOSTUNREACH || error == ENETUNREACH
}

private struct ReceivedDatagram {
    let data: Data
    let address: sockaddr_in
}

private func receiveDatagramFromIfAvailable(
    socket: Int32,
    byteCount: Int
) throws -> ReceivedDatagram? {
    var buffer = [UInt8](repeating: 0, count: byteCount)
    var address = sockaddr_in()
    var addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let received = buffer.withUnsafeMutableBytes { bytes in
        withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                recvfrom(socket, bytes.baseAddress, byteCount, 0, socketAddress, &addressLength)
            }
        }
    }
    if received < 0 {
        if errno == EAGAIN || errno == EWOULDBLOCK {
            return nil
        }
        throw UdpPcmRouteProbeError.receiveFailed(errno)
    }
    guard addressLength == socklen_t(MemoryLayout<sockaddr_in>.size) else {
        throw UdpPcmRouteProbeError.receiveFailed(EINVAL)
    }
    return ReceivedDatagram(data: Data(buffer.prefix(received)), address: address)
}

private func sendDatagram(_ data: Data, socket: Int32, address: sockaddr_in) throws {
    var mutableAddress = address
    let (sent, savedErrno) = data.withUnsafeBytes { bytes in
        withUnsafePointer(to: &mutableAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                let result = sendto(
                    socket,
                    bytes.baseAddress,
                    data.count,
                    0,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
                return (result, errno)
            }
        }
    }
    if sent < 0 {
        throw UdpPcmRouteProbeError.sendFailed(savedErrno)
    }
    if sent != data.count {
        throw UdpPcmRouteProbeError.shortSend(expected: data.count, actual: sent)
    }
}
