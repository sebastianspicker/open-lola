// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Dispatch
import Foundation

final class DirectPeerSessionControlSocket: @unchecked Sendable {
    let endpoint: SessionNetworkEndpoint
    private let descriptor: Int32
    private let receiveTimeoutNanoseconds: UInt64
    private let stateLock = NSLock()
    private var sentDatagramsStorage = 0
    private var receivedDatagramsStorage = 0
    private var isClosed = false

    var sentDatagrams: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return sentDatagramsStorage
    }

    var receivedDatagrams: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return receivedDatagramsStorage
    }

    private init(
        endpoint: SessionNetworkEndpoint,
        descriptor: Int32,
        receiveTimeoutSeconds: Int
    ) {
        precondition(
            (1...directPeerMaximumTimeoutSeconds).contains(receiveTimeoutSeconds),
            "direct peer control receive timeout must be bounded"
        )
        self.endpoint = endpoint
        self.descriptor = descriptor
        receiveTimeoutNanoseconds = UInt64(receiveTimeoutSeconds) * 1_000_000_000
    }

    deinit {
        close()
    }

    static func bindLoopback() throws -> DirectPeerSessionControlSocket {
        let descriptor = try makeUdpSocket(receiveTimeoutSeconds: 1)
        var succeeded = false
        defer {
            if !succeeded {
                closeUdpSocket(descriptor)
            }
        }
        try OpenLolaCore.bindLoopback(descriptor, port: 0)
        try setNonBlocking(descriptor)
        let socket = DirectPeerSessionControlSocket(
            endpoint: SessionNetworkEndpoint(
                host: "127.0.0.1",
                port: UInt16(bigEndian: try boundPort(descriptor))
            ),
            descriptor: descriptor,
            receiveTimeoutSeconds: 2
        )
        succeeded = true
        return socket
    }

    static func bindIPv4(
        host: String,
        port: UInt16,
        receiveTimeoutSeconds: Int
    ) throws -> DirectPeerSessionControlSocket {
        guard (1...directPeerMaximumTimeoutSeconds).contains(receiveTimeoutSeconds) else {
            throw DirectPeerSessionSocketRunnerError.invalidTimeoutSeconds(receiveTimeoutSeconds)
        }
        let descriptor = try makeUdpSocket(receiveTimeoutSeconds: receiveTimeoutSeconds)
        var succeeded = false
        defer {
            if !succeeded {
                closeUdpSocket(descriptor)
            }
        }
        try OpenLolaCore.bindIPv4(descriptor, host: host, port: port.bigEndian)
        try setNonBlocking(descriptor)
        let socket = DirectPeerSessionControlSocket(
            endpoint: SessionNetworkEndpoint(
                host: host,
                port: UInt16(bigEndian: try boundPort(descriptor))
            ),
            descriptor: descriptor,
            receiveTimeoutSeconds: receiveTimeoutSeconds
        )
        succeeded = true
        return socket
    }

    func send(_ message: SessionControlMessage, to endpoint: SessionNetworkEndpoint) throws {
        try sendDatagram(
            try SessionControlCodec.encode(message),
            socket: descriptor,
            host: endpoint.host,
            port: endpoint.port.bigEndian
        )
        incrementSentDatagrams()
    }

    func receiveMessages(
        count: Int,
        label: String,
        expectedSource: SessionNetworkEndpoint
    ) throws -> [SessionControlMessage] {
        var messages: [SessionControlMessage] = []
        messages.reserveCapacity(count)
        for index in 0..<count {
            messages.append(try receiveMessage(
                label: "\(label)-\(index + 1)",
                expectedSource: expectedSource
            ))
        }
        return messages
    }

    func receiveMessage(
        label: String,
        expectedSource: SessionNetworkEndpoint
    ) throws -> SessionControlMessage {
        let deadline = DispatchTime.now().uptimeNanoseconds + receiveTimeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if let datagram = try receiveDatagramWithSourceIfAvailable(socket: descriptor, byteCount: 16_384) {
                guard controlSourceMatches(datagram, expectedSource: expectedSource) else {
                    continue
                }
                incrementReceivedDatagrams()
                return try SessionControlCodec.decode(datagram.data)
            }
            let now = DispatchTime.now().uptimeNanoseconds
            guard deadline > now else {
                break
            }
            try waitForReadableSocket(
                socket: descriptor,
                timeoutMicroseconds: min(1_000, max(1, (deadline - now) / 1_000))
            )
        }
        throw DirectPeerSessionSocketRunnerError.timedOutWaitingForControlMessage(label)
    }

    func receiveMessageIfAvailable(
        expectedSource: SessionNetworkEndpoint
    ) throws -> SessionControlMessage? {
        while let datagram = try receiveDatagramWithSourceIfAvailable(socket: descriptor, byteCount: 16_384) {
            guard controlSourceMatches(datagram, expectedSource: expectedSource) else {
                continue
            }
            incrementReceivedDatagrams()
            return try SessionControlCodec.decode(datagram.data)
        }
        return nil
    }

    func close() {
        guard markClosed() else {
            return
        }
        closeUdpSocket(descriptor)
    }

    private func incrementSentDatagrams() {
        stateLock.lock()
        sentDatagramsStorage += 1
        stateLock.unlock()
    }

    private func incrementReceivedDatagrams() {
        stateLock.lock()
        receivedDatagramsStorage += 1
        stateLock.unlock()
    }

    private func markClosed() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isClosed else {
            return false
        }
        isClosed = true
        return true
    }
}

private func controlSourceMatches(
    _ datagram: UdpDatagramWithSource,
    expectedSource: SessionNetworkEndpoint
) -> Bool {
    datagram.host == expectedSource.host && datagram.port == expectedSource.port
}
