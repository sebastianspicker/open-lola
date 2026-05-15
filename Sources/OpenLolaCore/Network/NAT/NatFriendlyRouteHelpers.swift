import Darwin
import Foundation

private let natPositiveIntegerBounds: [String: Int] = [
    "--duration-seconds": 86_400,
    "--timeout-seconds": 86_400,
    "--keepalive-interval-ms": 60_000,
    "--expected-peers": 1_024,
]

func parseNatArguments(
    _ arguments: [String],
    allowed: Set<String>
) throws -> [String: String] {
    try KeyValueArgumentParser.parseValues(
        arguments,
        allowed: allowed,
        unknown: NatFriendlyRouteRunConfigurationError.unknownArgument,
        duplicate: NatFriendlyRouteRunConfigurationError.duplicateArgument,
        missingValue: NatFriendlyRouteRunConfigurationError.missingValue
    )
}

func requiredNatString(_ argument: String, _ values: [String: String]) throws -> String {
    try KeyValueArgumentParser.requiredString(
        argument,
        values,
        missing: NatFriendlyRouteRunConfigurationError.missingRequiredArgument
    )
}

func requiredNatPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let number = try KeyValueArgumentParser.requiredPositiveInteger(
        argument,
        values,
        missing: NatFriendlyRouteRunConfigurationError.missingRequiredArgument,
        invalid: { NatFriendlyRouteRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        nonPositive: NatFriendlyRouteRunConfigurationError.nonPositiveArgument
    )
    try validateNatPositiveIntegerBound(number, argument: argument)
    return number
}

func optionalNatPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int? {
    let number = try KeyValueArgumentParser.optionalPositiveInteger(
        argument,
        values,
        invalid: { NatFriendlyRouteRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        nonPositive: NatFriendlyRouteRunConfigurationError.nonPositiveArgument
    )
    if let number {
        try validateNatPositiveIntegerBound(number, argument: argument)
    }
    return number
}

private func validateNatPositiveIntegerBound(_ number: Int, argument: String) throws {
    guard let maximum = natPositiveIntegerBounds[argument] else {
        return
    }
    guard number <= maximum else {
        throw NatFriendlyRouteRunConfigurationError.invalidInteger(
            argument: argument,
            value: String(number)
        )
    }
}

func optionalNatNonNegativeDouble(
    _ argument: String,
    _ values: [String: String]
) throws -> Double? {
    try KeyValueArgumentParser.optionalNonNegativeDouble(
        argument,
        values,
        invalid: { NatFriendlyRouteRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        negative: NatFriendlyRouteRunConfigurationError.nonPositiveArgument
    )
}

func optionalNatRelayHost(_ values: [String: String]) throws -> String? {
    guard let relayHost = values["--relay-host"] else {
        if values["--relay-port"] != nil {
            throw NatFriendlyRouteRunConfigurationError.missingRequiredArgument("--relay-host")
        }
        return nil
    }
    guard !relayHost.isEmpty else {
        throw NatFriendlyRouteRunConfigurationError.missingRequiredArgument("--relay-host")
    }
    guard values["--relay-port"] != nil else {
        throw NatFriendlyRouteRunConfigurationError.missingRequiredArgument("--relay-port")
    }
    return relayHost
}

func optionalNatRelayPort(_ values: [String: String]) throws -> UInt16? {
    guard values["--relay-host"] != nil || values["--relay-port"] != nil else {
        return nil
    }
    return try requiredNatPort("--relay-port", values)
}

func requiredNatPort(_ argument: String, _ values: [String: String]) throws -> UInt16 {
    let port = try requiredNatPositiveInteger(argument, values)
    guard port <= Int(UInt16.max) else {
        throw NatFriendlyRouteRunConfigurationError.invalidPort(port)
    }
    return UInt16(port)
}

func requiredNatLocalUdpPort(_ argument: String, _ values: [String: String]) throws -> UInt16 {
    let value = try requiredNatString(argument, values)
    guard let port = Int(value) else {
        throw NatFriendlyRouteRunConfigurationError.invalidInteger(
            argument: argument,
            value: value
        )
    }
    guard port >= 0, port <= Int(UInt16.max) else {
        throw NatFriendlyRouteRunConfigurationError.invalidPort(port)
    }
    return UInt16(port)
}

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
        sessionID: configuration.sessionID,
        role: UdpPcmLoopbackRole(rawValue: configuration.role.rawValue) ?? .sender,
        bindHost: localEndpoint.host,
        peer: peerEndpoint.host,
        port: peerEndpoint.port,
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
        value & 0xFF,
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
    var source = sockaddr_in()
    var sourceLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    var buffer = [UInt8](repeating: 0, count: byteCount)
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
    var destination = destination
    let (sent, savedErrno) = data.withUnsafeBytes { bytes in
        withUnsafePointer(to: &destination) { pointer in
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
