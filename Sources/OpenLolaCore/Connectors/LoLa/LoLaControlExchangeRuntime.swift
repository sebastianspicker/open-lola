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

private struct LoLaReceiveControlState {
    var sentMessages: [String] = []
    var receivedMessages: [String] = []
    var opaqueControlDatagrams: [LoLaOpaqueControlDatagram] = []
    var bytesTransferred = 0

    mutating func recordSent(_ message: String, byteCount: Int) {
        sentMessages.append(message)
        bytesTransferred += byteCount
    }

    func failure(
        parsedMessageName: String?,
        fields: [String: String],
        runtimeError: Error
    ) -> LoLaControlExchangeAttempt {
        lolaControlAttemptFailure(
            sentMessages: sentMessages,
            receivedMessages: receivedMessages,
            bytesTransferred: bytesTransferred,
            opaqueControlDatagrams: opaqueControlDatagrams,
            parsedMessageName: parsedMessageName,
            fields: fields,
            runtimeError: runtimeError
        )
    }
}

private func receiveLoLaControlAttempt(
    configuration: ExternalConnectorSessionConfiguration,
    onReady: (@Sendable () -> Void)? = nil
) throws -> LoLaControlExchangeAttempt {
    let descriptor = try makeExternalConnectorUdpSocket()
    defer { close(descriptor) }
    try prepareLoLaReceiveControlSocket(descriptor, configuration: configuration)
    onReady?()

    var state = LoLaReceiveControlState()
    var current = receiveLoLaReceiveControlMessage(
        socket: descriptor,
        state: state,
        configuration: configuration
    )
    if let failure = current.failure { return failure }
    var parsed = parseLoLaReceiveControlMessage(current, state: &state)
    if let failure = parsed.failure { return failure }

    let retryResult = try answerLoLaStatusRetries(
        socket: descriptor,
        configuration: configuration,
        state: &state,
        current: &current,
        parsed: &parsed
    )
    if let failure = retryResult { return failure }

    return try answerLoLaQuickConnect(
        socket: descriptor,
        configuration: configuration,
        state: &state,
        current: current,
        parsed: parsed
    )
}

private func prepareLoLaReceiveControlSocket(
    _ descriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration
) throws {
    try bindExternalConnectorUdp(
        socket: descriptor,
        host: configuration.localHost,
        port: configuration.controlPort
    )
    try setExternalConnectorReceiveTimeout(socket: descriptor, seconds: configuration.durationSeconds)
}

private func receiveLoLaReceiveControlMessage(
    socket descriptor: Int32,
    state: LoLaReceiveControlState,
    configuration: ExternalConnectorSessionConfiguration,
    parsed: LoLaParsedControlMessage? = nil
) -> LoLaReceivedControlMessage {
    receiveLoLaControlMessage(
        socket: descriptor,
        sentMessages: state.sentMessages,
        receivedMessages: state.receivedMessages,
        bytesTransferred: state.bytesTransferred,
        destinationPort: configuration.controlPort,
        parsedMessageName: parsed?.parsed.name,
        fields: parsed?.parsed.fields ?? [:]
    )
}

private func parseLoLaReceiveControlMessage(
    _ received: LoLaReceivedControlMessage,
    state: inout LoLaReceiveControlState,
    previous: LoLaParsedControlMessage? = nil
) -> LoLaParsedControlMessage {
    parseReceivedLoLaControlMessage(
        received,
        sentMessages: state.sentMessages,
        receivedMessages: &state.receivedMessages,
        bytesTransferred: &state.bytesTransferred,
        opaqueControlDatagrams: &state.opaqueControlDatagrams,
        parsedMessageName: previous?.parsed.name,
        fields: previous?.parsed.fields ?? [:]
    )
}

private func answerLoLaStatusRetries(
    socket descriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration,
    state: inout LoLaReceiveControlState,
    current: inout LoLaReceivedControlMessage,
    parsed: inout LoLaParsedControlMessage
) throws -> LoLaControlExchangeAttempt? {
    var statusRetryCount = 0
    while parsed.parsed.name == "/MESG_CHECKLOLASTATUS" {
        statusRetryCount += 1
        guard statusRetryCount <= maxLoLaStatusRetryMessages else {
            return state.failure(
                parsedMessageName: parsed.parsed.name,
                fields: parsed.parsed.fields,
                runtimeError: ExternalConnectorSessionError.socketFailed("too many LoLa status retries")
            )
        }
        if let failure = validateLoLaStatusCheck(
            current,
            parsed: parsed,
            state: state,
            configuration: configuration
        ) {
            return failure
        }
        try sendLoLaStatusAck(
            socket: descriptor,
            configuration: configuration,
            state: &state,
            current: current,
            parsed: parsed
        )
        current = receiveLoLaReceiveControlMessage(
            socket: descriptor,
            state: state,
            configuration: configuration,
            parsed: parsed
        )
        if let failure = current.failure { return failure }
        parsed = parseLoLaReceiveControlMessage(current, state: &state, previous: parsed)
        if let failure = parsed.failure { return failure }
    }
    return nil
}

private func validateLoLaStatusCheck(
    _ current: LoLaReceivedControlMessage,
    parsed: LoLaParsedControlMessage,
    state: LoLaReceiveControlState,
    configuration: ExternalConnectorSessionConfiguration
) -> LoLaControlExchangeAttempt? {
    lolaIncomingHandshakeFailure(
        context: LoLaHandshakeValidationFailureContext(
            sentMessages: state.sentMessages,
            receivedMessages: state.receivedMessages,
            opaqueControlDatagrams: state.opaqueControlDatagrams,
            bytesTransferred: state.bytesTransferred,
            parsedMessageName: parsed.parsed.name,
            fields: parsed.parsed.fields,
            message: current.message
        ),
        expectedName: "/MESG_CHECKLOLASTATUS",
        localHost: configuration.localHost,
        requiresMediaFields: false
    )
}

private func sendLoLaStatusAck(
    socket descriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration,
    state: inout LoLaReceiveControlState,
    current: LoLaReceivedControlMessage,
    parsed: LoLaParsedControlMessage
) throws {
    let ack = try lolaCheckStatusAck(
        configuration: configuration,
        receivedFields: parsed.parsed.fields,
        senderHost: current.senderHost
    )
    try sendLoLaReceiveAck(ack, socket: descriptor, state: &state, current: current)
}

private func sendLoLaReceiveAck(
    _ ack: String,
    socket descriptor: Int32,
    state: inout LoLaReceiveControlState,
    current: LoLaReceivedControlMessage
) throws {
    let byteCount = try sendExternalConnectorUdp(
        ack,
        socket: descriptor,
        host: current.senderHost,
        port: current.senderPort
    )
    state.recordSent(ack, byteCount: byteCount)
}

private func answerLoLaQuickConnect(
    socket descriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration,
    state: inout LoLaReceiveControlState,
    current: LoLaReceivedControlMessage,
    parsed: LoLaParsedControlMessage
) throws -> LoLaControlExchangeAttempt {
    if let failure = lolaIncomingHandshakeFailure(
        context: LoLaHandshakeValidationFailureContext(
            sentMessages: state.sentMessages,
            receivedMessages: state.receivedMessages,
            opaqueControlDatagrams: state.opaqueControlDatagrams,
            bytesTransferred: state.bytesTransferred,
            parsedMessageName: parsed.parsed.name,
            fields: parsed.parsed.fields,
            message: current.message
        ),
        expectedName: "/MESG_QUICKCONN", localHost: configuration.localHost, requiresMediaFields: true
    ) { return failure }
    let ack = try lolaQuickConnectAck(
        configuration: configuration,
        receivedFields: parsed.parsed.fields,
        senderHost: current.senderHost
    )
    try sendLoLaReceiveAck(ack, socket: descriptor, state: &state, current: current)

    return lolaControlAttemptSuccess(
        sentMessages: state.sentMessages,
        receivedMessages: state.receivedMessages,
        opaqueControlDatagrams: state.opaqueControlDatagrams,
        bytesTransferred: state.bytesTransferred,
        parsedMessageName: parsed.parsed.name,
        fields: parsed.parsed.fields
    )
}

func startLoLaControlRetryResponder(
    configuration: ExternalConnectorSessionConfiguration
) -> LoLaControlRetryResponderReport {
    do {
        let keepAliveDescriptor = try prepareLoLaControlRetryResponderSocket(configuration: configuration)
        startLoLaControlRetryResponderLoop(descriptor: keepAliveDescriptor, configuration: configuration)
        return LoLaControlRetryResponderReport(
            started: true,
            localHost: configuration.localHost,
            controlPort: configuration.controlPort,
            timeoutSeconds: configuration.durationSeconds
        )
    } catch {
        return LoLaControlRetryResponderReport(
            started: false,
            localHost: configuration.localHost,
            controlPort: configuration.controlPort,
            timeoutSeconds: configuration.durationSeconds,
            runtimeError: String(describing: error)
        )
    }
}

private func prepareLoLaControlRetryResponderSocket(
    configuration: ExternalConnectorSessionConfiguration
) throws -> Int32 {
    let descriptor = try makeExternalConnectorUdpSocket()
    try bindExternalConnectorUdp(
        socket: descriptor,
        host: configuration.localHost,
        port: configuration.controlPort
    )
    try setExternalConnectorReceiveTimeout(socket: descriptor, seconds: 1)
    return descriptor
}

private func startLoLaControlRetryResponderLoop(
    descriptor keepAliveDescriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration
) {
    DispatchQueue.global(qos: .userInitiated).async {
        defer { close(keepAliveDescriptor) }
        let deadline = MonotonicDeadline(seconds: TimeInterval(max(1, configuration.durationSeconds)))
        while deadline.hasTimeRemaining {
            answerLoLaControlRetryMessageIfAvailable(
                socket: keepAliveDescriptor,
                configuration: configuration
            )
        }
    }
}

private func answerLoLaControlRetryMessageIfAvailable(
    socket keepAliveDescriptor: Int32,
    configuration: ExternalConnectorSessionConfiguration
) {
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
        return
    }
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
        return LoLaReceivedControlMessage(
            message: received.message,
            senderHost: received.senderHost,
            senderPort: received.senderPort,
            bytesTransferred: received.bytesTransferred,
            opaqueDatagram: opaqueDatagram,
            failure: nil
        )
    } catch {
        return LoLaReceivedControlMessage(
            message: "",
            senderHost: "",
            senderPort: 0,
            bytesTransferred: 0,
            failure: lolaControlAttemptFailure(
                sentMessages: sentMessages,
                receivedMessages: receivedMessages,
                bytesTransferred: bytesTransferred,
                parsedMessageName: parsedMessageName,
                fields: fields,
                runtimeError: error
            )
        )
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
        return LoLaParsedControlMessage(
            parsed: try LoLaCompatibilityControlMessage.parse(received.message),
            failure: nil
        )
    } catch {
        if let opaqueDatagram = received.opaqueDatagram {
            opaqueControlDatagrams.append(opaqueDatagram)
        }
        return LoLaParsedControlMessage(parsed: ("", [:]), failure: lolaControlAttemptFailure(
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
) -> LoLaParsedControlMessage {
    receivedMessages.append(message)
    bytesTransferred += transferredBytes
    do {
        return LoLaParsedControlMessage(parsed: try LoLaCompatibilityControlMessage.parse(message), failure: nil)
    } catch {
        return LoLaParsedControlMessage(parsed: ("", [:]), failure: lolaControlAttemptFailure(
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
    try LoLaCompatibilityControlMessage.quickConnectAck(
        lolaQuickConnectAckMediaFields(
            configuration: configuration,
            receivedFields: receivedFields,
            senderHost: senderHost
        )
    )
}

func lolaQuickConnectMessage(configuration: ExternalConnectorSessionConfiguration, sourceIP: String) throws -> String {
    try LoLaCompatibilityControlMessage.quickConnect(
        lolaQuickConnectMediaFields(configuration: configuration, sourceIP: sourceIP)
    )
}

private func lolaQuickConnectAckMediaFields(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String],
    senderHost: String
) throws -> LoLaCompatibilityMediaFields {
    LoLaCompatibilityMediaFields(
        session: LoLaControlSessionFields(
            sourceIP: lolaAckSourceIP(
                configuration: configuration,
                receivedFields: receivedFields,
                senderHost: senderHost
            ),
            destinationIP: receivedFields["SRCIP"] ?? senderHost,
            sessionID: try lolaControlSessionID(receivedFields["SID"] ?? configuration.sessionID)
        ),
        audio: LoLaCompatibilityAudioFields(
            sampleRateHertz: lolaControlIntegerField(
                receivedFields,
                key: "SR",
                fallback: configuration.sampleRateHertz
            ),
            bitsPerSample: lolaControlIntegerField(receivedFields, key: "BPS", fallback: 16),
            channels: lolaControlIntegerField(receivedFields, key: "CHNLS", fallback: configuration.channels)
        ),
        video: lolaQuickConnectAckVideoFields(configuration: configuration, receivedFields: receivedFields)
    )
}

private func lolaQuickConnectAckVideoFields(
    configuration: ExternalConnectorSessionConfiguration,
    receivedFields: [String: String]
) -> LoLaCompatibilityVideoFields {
    LoLaCompatibilityVideoFields(
        frameRate: lolaControlIntegerField(
            receivedFields,
            key: "FPS",
            fallback: configuration.mediaMode.hasVideo ? configuration.videoFrameRate : 0
        ),
        bitsPerPixel: lolaControlIntegerField(
            receivedFields,
            key: "BPP",
            fallback: configuration.mediaMode.hasVideo ? configuration.videoBitsPerPixel : 0
        ),
        dimensions: LoLaCompatibilityVideoDimensions(
            width: lolaControlIntegerField(
                receivedFields,
                key: "X",
                fallback: configuration.mediaMode.hasVideo ? configuration.videoWidth : 0
            ),
            height: lolaControlIntegerField(
                receivedFields,
                key: "Y",
                fallback: configuration.mediaMode.hasVideo ? configuration.videoHeight : 0
            )
        ),
        compression: lolaControlIntegerField(
            receivedFields,
            key: "COMP",
            fallback: configuration.videoCompression
        ),
        bayer: lolaControlIntegerField(receivedFields, key: "BAYER", fallback: configuration.videoBayer)
    )
}

private func lolaQuickConnectMediaFields(
    configuration: ExternalConnectorSessionConfiguration,
    sourceIP: String
) throws -> LoLaCompatibilityMediaFields {
    LoLaCompatibilityMediaFields(
        session: LoLaControlSessionFields(
            sourceIP: sourceIP,
            destinationIP: configuration.peer,
            sessionID: try lolaControlSessionID(configuration.sessionID)
        ),
        audio: LoLaCompatibilityAudioFields(
            sampleRateHertz: configuration.sampleRateHertz,
            bitsPerSample: 16,
            channels: configuration.channels
        ),
        video: lolaQuickConnectVideoFields(configuration: configuration)
    )
}

private func lolaQuickConnectVideoFields(
    configuration: ExternalConnectorSessionConfiguration
) -> LoLaCompatibilityVideoFields {
    LoLaCompatibilityVideoFields(
        frameRate: configuration.mediaMode.hasVideo ? configuration.videoFrameRate : 0,
        bitsPerPixel: configuration.mediaMode.hasVideo ? configuration.videoBitsPerPixel : 0,
        dimensions: LoLaCompatibilityVideoDimensions(
            width: configuration.mediaMode.hasVideo ? configuration.videoWidth : 0,
            height: configuration.mediaMode.hasVideo ? configuration.videoHeight : 0
        ),
        compression: configuration.mediaMode.hasVideo ? configuration.videoCompression : 0,
        bayer: configuration.mediaMode.hasVideo ? configuration.videoBayer : 0
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
        throw ExternalConnectorSessionError.socketFailed(
            "connect \(configuration.peer):\(configuration.controlPort) errno \(errno)"
        )
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
                    sendto(
                        socket,
                        baseAddress,
                        rawBuffer.count,
                        0,
                        socketAddress,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
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

private struct ExternalConnectorUdpReceiveResult {
    var message: String
    var senderHost: String
    var senderPort: UInt16
    var bytesTransferred: Int
    var payload: [UInt8]
}

private func receiveExternalConnectorUdp(
    socket: Int32,
    bufferSize: Int
) throws -> ExternalConnectorUdpReceiveResult {
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
    return ExternalConnectorUdpReceiveResult(
        message: String(bytes: messageBytes[..<messageEnd], encoding: .utf8) ?? "",
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
    return String(bytes: buffer[..<endIndex].map(UInt8.init), encoding: .utf8) ?? ""
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
