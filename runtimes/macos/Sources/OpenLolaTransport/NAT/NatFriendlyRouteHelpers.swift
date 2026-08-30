import OpenLolaSessionDomain
import OpenLolaContracts
// Provides NAT route validation and socket helpers for typed configurations.
import Darwin
import Foundation
import OpenLolaEvidenceModels

func requireNatNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw NatFriendlyRouteValidationError.emptyField(field)
    }
}

func requireNatPositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw NatFriendlyRouteValidationError.nonPositiveField(field)
    }
}

func requireNatNonNegative(_ value: Int, _ field: String) throws {
    if value < 0 {
        throw NatFriendlyRouteValidationError.negativeField(field)
    }
}

func requireNatNonNegative(_ value: Double, _ field: String) throws {
    if value < 0 {
        throw NatFriendlyRouteValidationError.negativeField(field)
    }
}

func currentNatTimestamp() -> String {
    ISO8601DateFormatter().string(from: Date())
}

func endpointDescription(_ endpoint: NatEndpoint) -> String {
    "\(endpoint.host):\(endpoint.port)"
}

func makeNatLoopbackConfiguration(
    configuration: NatFriendlyRouteRunConfiguration,
    localEndpoint: NatEndpoint,
    peerEndpoint: NatEndpoint
) -> UdpPcmLoopbackRunConfiguration {
    UdpPcmLoopbackRunConfiguration(
        connection: .init(
            sessionID: configuration.sessionID,
            role: UdpPcmLoopbackRole(rawValue: configuration.role.rawValue) ?? .sender,
            bindHost: localEndpoint.host,
            peer: peerEndpoint.host,
            port: peerEndpoint.port
        ),
        run: .init(
            packetMode: UdpPcmPacketMode(
                // NAT loopback sends one synthetic frame per keepalive packet; this field is
                // packet cadence for the probe, not an audio hardware sample-rate claim.
                sampleRateHertz: 5,
                framesPerPacket: 1,
                channelCount: 2,
                sampleFormat: .int16LittleEndian
            ),
            durationSeconds: max(1, configuration.durationSeconds),
            outputPath: configuration.outputPath,
            dscp: nil,
            diagnostics: .off,
            debugOutputPath: configuration.debugOutputPath
        )
    )
}

func addedLatencyMicroseconds(
    directTraversalRtt: Double?,
    rawRouteRtt: Double?
) -> Double {
    guard let directTraversalRtt, let rawRouteRtt else {
        return 0
    }
    return max(0, directTraversalRtt - rawRouteRtt)
}

func receiveNatTraversalDatagramIfAvailable(socket: Int32) throws -> Data? {
    do {
        return try receiveDatagramIfAvailable(socket: socket, byteCount: 512)
    } catch UdpPcmRouteProbeError.receiveFailed(let error)
        where error == ECONNREFUSED || error == EHOSTUNREACH || error == ENETUNREACH {
        return nil
    }
}

func drainNatTraversalKeepalives(socket: Int32, debug: inout DebugTrace) throws {
    var drained = 0
    while let received = try receiveDatagramIfAvailable(socket: socket, byteCount: 512) {
        if (try? JSONDecoder().decode(NatTraversalKeepaliveMessage.self, from: received)) != nil {
            drained += 1
        } else {
            break
        }
    }
    if drained > 0 {
        debug.record(event: "nat-keepalive-drained", fields: ["count": "\(drained)"])
    }
}

func availableNatRendezvousPort() throws -> UInt16 {
    let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { close(socket) }
    try bindLoopback(socket, port: 0)
    return UInt16(bigEndian: try boundPort(socket))
}

func availableNatRendezvousPorts(count: Int) throws -> [UInt16] {
    var sockets: [Int32] = []
    defer {
        for socket in sockets {
            close(socket)
        }
    }
    var ports: [UInt16] = []
    for _ in 0..<count {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        try bindLoopback(socket, port: 0)
        sockets.append(socket)
        ports.append(UInt16(bigEndian: try boundPort(socket)))
    }
    return ports
}

func endpoint(from address: sockaddr_in) -> NatEndpoint {
    var mutableAddress = address.sin_addr
    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    let host = inet_ntop(
        AF_INET,
        &mutableAddress,
        &buffer,
        socklen_t(INET_ADDRSTRLEN)
    ).map { String(cString: $0) } ?? numericIPv4AddressFallback(address.sin_addr)
    return NatEndpoint(host: host, port: UInt16(bigEndian: address.sin_port))
}

func numericIPv4AddressFallback(_ address: in_addr) -> String {
    let value = UInt32(bigEndian: address.s_addr)
    return [
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF
    ].map(String.init).joined(separator: ".")
}

func relayEndpoint(from configuration: NatFriendlyRouteRunConfiguration) -> NatEndpoint? {
    guard let relayHost = configuration.relayHost,
          let relayPort = configuration.relayPort else {
        return nil
    }
    return NatEndpoint(host: relayHost, port: relayPort)
}

func receiveRendezvousDatagram(
    socket: Int32,
    byteCount: Int = 2_048
) throws -> (data: Data, source: sockaddr_in)? {
    var buffer = [UInt8](repeating: 0, count: byteCount)
    return try receiveRendezvousDatagram(
        socket: socket,
        byteCount: byteCount,
        buffer: &buffer
    )
}

func receiveRendezvousDatagram(
    socket: Int32,
    byteCount: Int,
    buffer: inout [UInt8]
) throws -> (data: Data, source: sockaddr_in)? {
    if buffer.count < byteCount {
        buffer = [UInt8](repeating: 0, count: byteCount)
    }
    var source = sockaddr_in()
    var sourceLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let received = buffer.withUnsafeMutableBytes { bytes in
        withUnsafeMutablePointer(to: &source) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sourceAddress in
                recvfrom(
                    socket,
                    bytes.baseAddress,
                    byteCount,
                    0,
                    sourceAddress,
                    &sourceLength
                )
            }
        }
    }
    if received < 0 {
        if errno == EAGAIN || errno == EWOULDBLOCK {
            return nil
        }
        throw UdpPcmRouteProbeError.receiveFailed(errno)
    }
    return (Data(buffer.prefix(received)), source)
}

func receiveRendezvousResponse(socket: Int32, byteCount: Int = 2_048) throws -> Data? {
    guard let datagram = try receiveRendezvousDatagram(socket: socket, byteCount: byteCount) else {
        return nil
    }
    return datagram.data
}

func sendRendezvousDatagram(
    _ data: Data,
    socket: Int32,
    destination: sockaddr_in
) throws {
    let (sent, savedErrno) = sendUdpDatagram(data, socket: socket, destination: destination)
    if sent < 0 {
        throw UdpPcmRouteProbeError.sendFailed(savedErrno)
    }
    if sent != data.count {
        throw UdpPcmRouteProbeError.shortSend(expected: data.count, actual: sent)
    }
}
