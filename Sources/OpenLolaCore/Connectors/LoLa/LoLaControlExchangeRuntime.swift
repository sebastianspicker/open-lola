import Darwin
import Dispatch
import Foundation

let lolaControlDatagramByteCount = 1024
private let maxLoLaStatusRetryMessages = 8

public struct LoLaControlRetryResponderReport: Codable, Equatable, Sendable {
    public var started: Bool
    public var localHost: String
    public var controlPort: UInt16
    public var timeoutSeconds: Int
    public var runtimeError: String?

    public init(
        started: Bool,
        localHost: String,
        controlPort: UInt16,
        timeoutSeconds: Int,
        runtimeError: String? = nil
    ) {
        self.started = started
        self.localHost = localHost
        self.controlPort = controlPort
        self.timeoutSeconds = timeoutSeconds
        self.runtimeError = runtimeError
    }

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(localHost, "lolaControlRetryResponder.localHost")
        guard timeoutSeconds > 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "lolaControlRetryResponder.timeoutSeconds",
                String(timeoutSeconds)
            )
        }
        if !started {
            try requireExternalConnectorSessionNonEmpty(
                runtimeError ?? "",
                "lolaControlRetryResponder.runtimeError"
            )
        }
    }
}

func runLoLaControlExchange(
    configuration: ExternalConnectorSessionConfiguration
) throws -> LoLaControlExchange {
    let attempt = try runLoLaControlExchangeAttempt(configuration: configuration)
    if let runtimeError = attempt.runtimeError {
        throw ExternalConnectorSessionError.processLaunchFailed(runtimeError)
    }
    return attempt.exchange
}

struct LoLaControlExchangeAttempt {
    var exchange: LoLaControlExchange
    var runtimeError: String?
    var isTimeout: Bool = false
}

func runLoLaControlExchangeAttempt(
    configuration: ExternalConnectorSessionConfiguration,
    onReceiveReady: (@Sendable () -> Void)? = nil
) throws -> LoLaControlExchangeAttempt {
    if configuration.controlTransport == .tcp {
        return try runLoLaTcpControlExchangeAttempt(configuration: configuration)
    }
    switch configuration.role {
    case .tx, .txRx:
        return try sendLoLaControlAttempt(configuration: configuration)
    case .rx:
        return try receiveLoLaControlAttempt(configuration: configuration, onReady: onReceiveReady)
    }
}

private func receiveLoLaControlAttempt(
    configuration: ExternalConnectorSessionConfiguration,
    onReady: (@Sendable () -> Void)? = nil
) throws -> LoLaControlExchangeAttempt {
    let descriptor = try makeExternalConnectorUdpSocket()
    defer { close(descriptor) }
    try bindExternalConnectorUdp(socket: descriptor, host: configuration.localHost, port: configuration.controlPort)
    try setExternalConnectorReceiveTimeout(socket: descriptor, seconds: configuration.durationSeconds)
    onReady?()

    var sentMessages: [String] = []
    var receivedMessages: [String] = []
    var opaqueControlDatagrams: [LoLaOpaqueControlDatagram] = []
    var bytesTransferred = 0

    let first = receiveLoLaControlMessage(
        socket: descriptor, sentMessages: sentMessages, receivedMessages: receivedMessages,
        bytesTransferred: bytesTransferred, destinationPort: configuration.controlPort
    )
    if let failure = first.failure { return failure }
    var parsed = parseReceivedLoLaControlMessage(
        first, sentMessages: sentMessages,
        receivedMessages: &receivedMessages,
        bytesTransferred: &bytesTransferred,
        opaqueControlDatagrams: &opaqueControlDatagrams
    )
    if let failure = parsed.failure { return failure }
    var current = first
    var statusRetryCount = 0
    while parsed.parsed.name == "/MESG_CHECKLOLASTATUS" {
        statusRetryCount += 1
        guard statusRetryCount <= maxLoLaStatusRetryMessages else {
            return lolaControlAttemptFailure(
                sentMessages: sentMessages,
                receivedMessages: receivedMessages,
                bytesTransferred: bytesTransferred,
                opaqueControlDatagrams: opaqueControlDatagrams,
                parsedMessageName: parsed.parsed.name,
                fields: parsed.parsed.fields,
                runtimeError: ExternalConnectorSessionError.socketFailed("too many LoLa status retries")
            )
        }
        if let failure = lolaIncomingHandshakeFailure(
            sentMessages: sentMessages, receivedMessages: receivedMessages,
            opaqueControlDatagrams: opaqueControlDatagrams, bytesTransferred: bytesTransferred,
            parsedMessageName: parsed.parsed.name, fields: parsed.parsed.fields, message: current.message,
            expectedName: "/MESG_CHECKLOLASTATUS", localHost: configuration.localHost, requiresMediaFields: false
        ) { return failure }
        let ack = try lolaCheckStatusAck(
            configuration: configuration,
            receivedFields: parsed.parsed.fields,
            senderHost: current.senderHost
        )
        bytesTransferred += try sendExternalConnectorUdp(ack, socket: descriptor, host: current.senderHost, port: current.senderPort)
        sentMessages.append(ack)
        current = receiveLoLaControlMessage(
            socket: descriptor,
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            bytesTransferred: bytesTransferred,
            destinationPort: configuration.controlPort,
            parsedMessageName: parsed.parsed.name,
            fields: parsed.parsed.fields
        )
        if let failure = current.failure { return failure }
        parsed = parseReceivedLoLaControlMessage(
            current,
            sentMessages: sentMessages,
            receivedMessages: &receivedMessages,
            bytesTransferred: &bytesTransferred,
            opaqueControlDatagrams: &opaqueControlDatagrams,
            parsedMessageName: parsed.parsed.name,
            fields: parsed.parsed.fields
        )
        if let failure = parsed.failure { return failure }
    }

    if let failure = lolaIncomingHandshakeFailure(
        sentMessages: sentMessages, receivedMessages: receivedMessages,
        opaqueControlDatagrams: opaqueControlDatagrams, bytesTransferred: bytesTransferred,
        parsedMessageName: parsed.parsed.name, fields: parsed.parsed.fields, message: current.message,
        expectedName: "/MESG_QUICKCONN", localHost: configuration.localHost, requiresMediaFields: true
    ) { return failure }
    let ack = try lolaQuickConnectAck(configuration: configuration, receivedFields: parsed.parsed.fields, senderHost: current.senderHost)
    bytesTransferred += try sendExternalConnectorUdp(ack, socket: descriptor, host: current.senderHost, port: current.senderPort)
    sentMessages.append(ack)

    return lolaControlAttemptSuccess(
        sentMessages: sentMessages,
        receivedMessages: receivedMessages,
        opaqueControlDatagrams: opaqueControlDatagrams,
        bytesTransferred: bytesTransferred,
        parsedMessageName: parsed.parsed.name,
        fields: parsed.parsed.fields
    )
}

func startLoLaControlRetryResponder(
    configuration: ExternalConnectorSessionConfiguration
) -> LoLaControlRetryResponderReport {
    let keepAliveDescriptor: Int32
    do {
        keepAliveDescriptor = try makeExternalConnectorUdpSocket()
        try bindExternalConnectorUdp(socket: keepAliveDescriptor, host: configuration.localHost, port: configuration.controlPort)
        try setExternalConnectorReceiveTimeout(socket: keepAliveDescriptor, seconds: 1)
    } catch {
        return LoLaControlRetryResponderReport(
            started: false,
            localHost: configuration.localHost,
            controlPort: configuration.controlPort,
            timeoutSeconds: configuration.durationSeconds,
            runtimeError: String(describing: error)
        )
    }
    DispatchQueue.global(qos: .userInitiated).async {
        defer { close(keepAliveDescriptor) }
        let deadline = MonotonicDeadline(seconds: TimeInterval(max(1, configuration.durationSeconds)))
        while deadline.hasTimeRemaining {
            do {
                let received = try receiveExternalConnectorUdp(socket: keepAliveDescriptor, bufferSize: 4096)
                let parsed = try LoLaCompatibilityControlMessage.parse(received.message)
                if let ack = try lolaRetryResponderAck(
                    configuration: configuration,
                    message: received.message,
                    parsed: parsed,
                    senderHost: received.senderHost
                ) {
                    _ = try sendExternalConnectorUdp(
                        ack,
                        socket: keepAliveDescriptor,
                        host: received.senderHost,
                        port: configuration.controlPort
                    )
                }
            } catch {
                continue
            }
        }
    }
    return LoLaControlRetryResponderReport(
        started: true,
        localHost: configuration.localHost,
        controlPort: configuration.controlPort,
        timeoutSeconds: configuration.durationSeconds
    )
}

func receiveLoLaControlMessage(
    socket: Int32,
    sentMessages: [String],
    receivedMessages: [String],
    bytesTransferred: Int,
    destinationPort: UInt16,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaReceivedControlMessage {
    do {
        let received = try receiveExternalConnectorUdp(socket: socket, bufferSize: 4096)
        let opaqueDatagram = received.message.hasPrefix("/MESG_") ? nil : LoLaOpaqueControlDatagram.classify(
            payload: received.payload,
            sourceHost: received.senderHost,
            sourcePort: received.senderPort,
            destinationPort: destinationPort
        )
        return (
            received.message,
            received.senderHost,
            received.senderPort,
            received.bytesTransferred,
            opaqueDatagram,
            nil
        )
    } catch {
        return ("", "", 0, 0, nil, lolaControlAttemptFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            bytesTransferred: bytesTransferred,
            parsedMessageName: parsedMessageName,
            fields: fields,
            runtimeError: error
        ))
    }
}

func parseReceivedLoLaControlMessage(
    _ received: LoLaReceivedControlMessage,
    sentMessages: [String],
    receivedMessages: inout [String],
    bytesTransferred: inout Int,
    opaqueControlDatagrams: inout [LoLaOpaqueControlDatagram],
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> LoLaParsedControlMessage {
    receivedMessages.append(received.message)
    bytesTransferred += received.bytesTransferred
    do {
        return (try LoLaCompatibilityControlMessage.parse(received.message), nil)
    } catch {
        if let opaqueDatagram = received.opaqueDatagram {
            opaqueControlDatagrams.append(opaqueDatagram)
        }
        return (("", [:]), lolaControlAttemptFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            bytesTransferred: bytesTransferred,
            opaqueControlDatagrams: opaqueControlDatagrams,
            parsedMessageName: parsedMessageName,
            fields: fields,
            runtimeError: error
        ))
    }
}

func parseLoLaControlMessage(
    _ message: String,
    sentMessages: [String],
    receivedMessages: inout [String],
    bytesTransferred: inout Int,
    transferredBytes: Int,
    parsedMessageName: String? = nil,
    fields: [String: String] = [:]
) -> (
    parsed: (name: String, fields: [String: String]),
    failure: LoLaControlExchangeAttempt?
) {
    receivedMessages.append(message)
    bytesTransferred += transferredBytes
    do {
        return (try LoLaCompatibilityControlMessage.parse(message), nil)
    } catch {
        return (("", [:]), lolaControlAttemptFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            bytesTransferred: bytesTransferred,
            parsedMessageName: parsedMessageName,
            fields: fields,
            runtimeError: error
        ))
    }
}

func lolaControlAttemptSuccess(
    sentMessages: [String],
    receivedMessages: [String],
    opaqueControlDatagrams: [LoLaOpaqueControlDatagram] = [],
    bytesTransferred: Int,
    parsedMessageName: String?,
    fields: [String: String]
) -> LoLaControlExchangeAttempt {
    LoLaControlExchangeAttempt(
        exchange: LoLaControlExchange(
            sentMessage: sentMessages.last,
            receivedMessage: receivedMessages.last,
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            opaqueControlDatagrams: opaqueControlDatagrams,
            parsedMessageName: parsedMessageName,
            fields: fields,
            bytesTransferred: bytesTransferred
        ),
        runtimeError: nil,
        isTimeout: false
    )
}

func lolaControlAttemptFailure(
    sentMessages: [String],
    receivedMessages: [String],
    bytesTransferred: Int,
    opaqueControlDatagrams: [LoLaOpaqueControlDatagram] = [],
    parsedMessageName: String? = nil,
    fields: [String: String] = [:],
    runtimeError: Error
) -> LoLaControlExchangeAttempt {
    LoLaControlExchangeAttempt(
        exchange: LoLaControlExchange(
            sentMessage: sentMessages.last,
            receivedMessage: receivedMessages.last,
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            opaqueControlDatagrams: opaqueControlDatagrams,
            parsedMessageName: parsedMessageName,
            fields: fields,
            bytesTransferred: bytesTransferred
        ),
        runtimeError: String(describing: runtimeError),
        isTimeout: isLoLaTimeoutError(runtimeError)
    )
}

func lolaCheckStatusAck(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String],
    senderHost: String
) throws -> String {
    LoLaCompatibilityControlMessage.checkStatusAck(
        sourceIP: lolaAckSourceIP(configuration: configuration, receivedFields: receivedFields, senderHost: senderHost),
        destinationIP: receivedFields["SRCIP"] ?? senderHost,
        sessionID: try lolaControlSessionID(receivedFields["SID"] ?? configuration.sessionID)
    )
}

func lolaQuickConnectAck(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String],
    senderHost: String
) throws -> String {
    LoLaCompatibilityControlMessage.quickConnectAck(
        sourceIP: lolaAckSourceIP(configuration: configuration, receivedFields: receivedFields, senderHost: senderHost),
        destinationIP: receivedFields["SRCIP"] ?? senderHost,
        sessionID: try lolaControlSessionID(receivedFields["SID"] ?? configuration.sessionID),
        sampleRateHertz: lolaControlIntegerField(receivedFields, key: "SR", fallback: configuration.sampleRateHertz),
        bitsPerSample: lolaControlIntegerField(receivedFields, key: "BPS", fallback: 16),
        channels: lolaControlIntegerField(receivedFields, key: "CHNLS", fallback: configuration.channels),
        videoFrameRate: lolaControlIntegerField(receivedFields, key: "FPS", fallback: configuration.mediaMode.hasVideo ? configuration.videoFrameRate : 0),
        videoBitsPerPixel: lolaControlIntegerField(receivedFields, key: "BPP", fallback: configuration.mediaMode.hasVideo ? configuration.videoBitsPerPixel : 0),
        videoWidth: lolaControlIntegerField(receivedFields, key: "X", fallback: configuration.mediaMode.hasVideo ? configuration.videoWidth : 0),
        videoHeight: lolaControlIntegerField(receivedFields, key: "Y", fallback: configuration.mediaMode.hasVideo ? configuration.videoHeight : 0),
        videoCompression: lolaControlIntegerField(receivedFields, key: "COMP", fallback: configuration.videoCompression),
        videoBayer: lolaControlIntegerField(receivedFields, key: "BAYER", fallback: configuration.videoBayer)
    )
}

func lolaQuickConnectMessage(configuration: ExternalConnectorSessionConfiguration, sourceIP: String) throws -> String {
    LoLaCompatibilityControlMessage.quickConnect(
        sourceIP: sourceIP,
        destinationIP: configuration.peer,
        sessionID: try lolaControlSessionID(configuration.sessionID),
        sampleRateHertz: configuration.sampleRateHertz,
        bitsPerSample: 16,
        channels: configuration.channels,
        videoFrameRate: configuration.mediaMode.hasVideo ? configuration.videoFrameRate : 0,
        videoBitsPerPixel: configuration.mediaMode.hasVideo ? configuration.videoBitsPerPixel : 0,
        videoWidth: configuration.mediaMode.hasVideo ? configuration.videoWidth : 0,
        videoHeight: configuration.mediaMode.hasVideo ? configuration.videoHeight : 0,
        videoCompression: configuration.mediaMode.hasVideo ? configuration.videoCompression : 0,
        videoBayer: configuration.mediaMode.hasVideo ? configuration.videoBayer : 0
    )
}

func isLoLaReceiveTimedOutFailure(_ attempt: LoLaControlExchangeAttempt) -> Bool {
    attempt.isTimeout
}

private func isLoLaTimeoutError(_ error: Error) -> Bool {
    if case ExternalConnectorSessionError.receiveTimedOut = error {
        return true
    }
    return false
}

private func lolaAckSourceIP(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String],
    senderHost: String
) -> String {
    if configuration.localHost != "0.0.0.0" {
        return configuration.localHost
    }
    return receivedFields["DSTIP"] ?? senderHost
}

func lolaControlAdvertisedSourceIP(_ configuration: ExternalConnectorSessionConfiguration) throws -> String {
    guard configuration.localHost == "0.0.0.0", !configuration.peer.isEmpty else {
        return configuration.localHost
    }
    let descriptor = try makeExternalConnectorUdpSocket()
    defer { close(descriptor) }
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = configuration.controlPort.bigEndian
    guard inet_pton(AF_INET, configuration.peer, &address.sin_addr) == 1 else {
        throw ExternalConnectorSessionError.socketFailed("inet_pton \(configuration.peer)")
    }
    let connectStatus = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            connect(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard connectStatus == 0 else {
        throw ExternalConnectorSessionError.socketFailed("connect \(configuration.peer):\(configuration.controlPort) errno \(errno)")
    }
    var localAddress = sockaddr_in()
    var localAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let nameStatus = withUnsafeMutablePointer(to: &localAddress) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            getsockname(descriptor, socketAddress, &localAddressLength)
        }
    }
    guard nameStatus == 0 else {
        throw ExternalConnectorSessionError.socketFailed("getsockname errno \(errno)")
    }
    return try externalConnectorHostString(localAddress.sin_addr)
}

private func lolaControlIntegerField(_ fields: [String: String], key: String, fallback: Int) -> Int {
    guard let value = fields[key], let parsed = Int(value) else {
        return fallback
    }
    return parsed
}

func makeExternalConnectorUdpSocket() throws -> Int32 {
    let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
        throw ExternalConnectorSessionError.socketFailed("socket")
    }
    var reuse: Int32 = 1
    guard setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("udp setsockopt SO_REUSEADDR errno \(errno)")
    }
    #if os(macOS)
    guard setsockopt(descriptor, SOL_SOCKET, SO_REUSEPORT, &reuse, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
        throw ExternalConnectorSessionError.socketFailed("udp setsockopt SO_REUSEPORT errno \(errno)")
    }
    #endif
    return descriptor
}

func sendExternalConnectorUdp(
    _ message: String,
    socket: Int32,
    host: String,
    port: UInt16
) throws -> Int {
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
        throw ExternalConnectorSessionError.socketFailed("inet_pton \(host)")
    }
    let bytes = lolaControlDatagramBytes(message)
    let sent = try withUnsafePointer(to: &address) { pointer in
        try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            try bytes.withUnsafeBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else {
                    throw ExternalConnectorSessionError.socketFailed("empty send buffer")
                }
                let result = retryLoLaControlUdpSend {
                    sendto(socket, baseAddress, rawBuffer.count, 0, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
                guard result >= 0 else {
                    throw ExternalConnectorSessionError.socketFailed("sendto errno \(errno)")
                }
                return result
            }
        }
    }
    return sent
}

func lolaControlDatagramBytes(_ message: String) -> [UInt8] {
    let bytes = [UInt8](message.utf8)
    if bytes.count > lolaControlDatagramByteCount {
        return Array(bytes.prefix(lolaControlDatagramByteCount))
    }
    return bytes + [UInt8](repeating: 0, count: lolaControlDatagramByteCount - bytes.count)
}

private func retryLoLaControlUdpSend(_ send: () -> Int) -> Int {
    var lastErrno: Int32 = 0
    for attempt in 0..<6 {
        let result = send()
        if result >= 0 {
            return result
        }
        lastErrno = errno
        guard lastErrno == EAGAIN || lastErrno == EWOULDBLOCK, attempt < 5 else {
            errno = lastErrno
            return result
        }
        usleep(5_000)
    }
    errno = lastErrno
    return -1
}

private func receiveExternalConnectorUdp(
    socket: Int32,
    bufferSize: Int
) throws -> (message: String, senderHost: String, senderPort: UInt16, bytesTransferred: Int, payload: [UInt8]) {
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    var sender = sockaddr_in()
    var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)
    let received = withUnsafeMutablePointer(to: &sender) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            recvfrom(socket, &buffer, buffer.count, 0, socketAddress, &senderLength)
        }
    }
    guard received > 0 else {
        let receiveErrno = errno
        if received == 0 || receiveErrno == EAGAIN || receiveErrno == EWOULDBLOCK {
            throw ExternalConnectorSessionError.receiveTimedOut
        }
        throw ExternalConnectorSessionError.socketFailed("recvfrom errno \(receiveErrno)")
    }
    let host = try externalConnectorHostString(sender.sin_addr)
    let messageBytes = buffer[0..<received]
    let messageEnd = messageBytes.firstIndex(of: 0) ?? messageBytes.endIndex
    let payload = Array(messageBytes)
    return (
        message: String(decoding: messageBytes[..<messageEnd], as: UTF8.self),
        senderHost: host,
        senderPort: UInt16(bigEndian: sender.sin_port),
        bytesTransferred: received,
        payload: payload
    )
}

private func externalConnectorHostString(_ address: in_addr) throws -> String {
    try lolaInetNtopString(address, failurePrefix: "inet_ntop")
}

func lolaInetNtopString(_ address: in_addr, failurePrefix: String) throws -> String {
    var mutableAddress = address
    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    guard inet_ntop(AF_INET, &mutableAddress, &buffer, socklen_t(buffer.count)) != nil else {
        throw ExternalConnectorSessionError.socketFailed(failurePrefix)
    }
    buffer[buffer.count - 1] = 0
    guard let endIndex = buffer.firstIndex(of: 0) else {
        throw ExternalConnectorSessionError.socketFailed("\(failurePrefix) missing null terminator")
    }
    return String(decoding: buffer[..<endIndex].map(UInt8.init), as: UTF8.self)
}

private func bindExternalConnectorUdp(socket: Int32, host: String, port: UInt16) throws {
    let bindErrno = try externalConnectorUdpBindErrno(socket: socket, host: host, port: port)
    guard bindErrno == 0 else {
        throw ExternalConnectorSessionError.socketFailed("bind \(host):\(port) errno \(bindErrno)")
    }
}

func setExternalConnectorReceiveTimeout(socket: Int32, seconds: Int) throws {
    var timeout = timeval(tv_sec: max(1, seconds), tv_usec: 0)
    let status = setsockopt(
        socket,
        SOL_SOCKET,
        SO_RCVTIMEO,
        &timeout,
        socklen_t(MemoryLayout<timeval>.size)
    )
    guard status == 0 else {
        throw ExternalConnectorSessionError.socketFailed("setsockopt")
    }
}
