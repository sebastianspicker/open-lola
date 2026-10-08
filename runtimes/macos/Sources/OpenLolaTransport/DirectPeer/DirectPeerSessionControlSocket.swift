import OpenLolaEvidenceModels
import OpenLolaSessionDomain
import OpenLolaContracts
// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Dispatch
import Foundation

private let directPeerControlDatagramByteCount = 16_384
private let directPeerControlPollDatagramLimit = 64

package final class DirectPeerSessionControlSocket: @unchecked Sendable {
    package let endpoint: SessionNetworkEndpoint
    package let readinessDescriptor: Int32
    private var descriptor: Int32 { readinessDescriptor }
    private let receiveTimeoutNanoseconds: UInt64
    private let stateLock = NSLock()
    /// Serialises use of `pollScratch` so the non-blocking poll reuses one receive buffer.
    private let pollLock = NSLock()
    private var pollScratch = [UInt8](repeating: 0, count: directPeerControlDatagramByteCount)
    private var sentDatagramsStorage = 0
    private var receivedDatagramsStorage = 0
    private var droppedDatagramsStorage = 0
    private var isClosed = false

    package var sentDatagrams: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return sentDatagramsStorage
    }

    package var receivedDatagrams: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return receivedDatagramsStorage
    }

    /// Control datagrams from the expected peer that failed to decode during non-blocking polls.
    package var droppedDatagrams: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return droppedDatagramsStorage
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
        readinessDescriptor = descriptor
        receiveTimeoutNanoseconds = UInt64(receiveTimeoutSeconds) * 1_000_000_000
    }

    deinit {
        close()
    }

    package static func bindLoopback() throws -> DirectPeerSessionControlSocket {
        let descriptor = try makeUdpSocket(receiveTimeoutSeconds: 1)
        var succeeded = false
        defer {
            if !succeeded {
                closeUdpSocket(descriptor)
            }
        }
        try OpenLolaTransport.bindLoopback(descriptor, port: 0)
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

    package static func bindIPv4(
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
        try OpenLolaTransport.bindIPv4(descriptor, host: host, port: port.bigEndian)
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

    package func send(_ message: SessionControlMessage, to endpoint: SessionNetworkEndpoint) throws {
        try sendDatagram(
            try SessionControlCodec.encode(message),
            socket: descriptor,
            host: endpoint.host,
            port: endpoint.port.bigEndian
        )
        incrementSentDatagrams()
    }

    package func receiveMessages(
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

    package func receiveMessage(
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

    /// Polls at most `directPeerControlPollDatagramLimit` datagrams without blocking. Foreign-source
    /// datagrams are skipped and undecodable ones are counted as dropped instead of failing the caller.
    package func receiveMessageIfAvailable(
        expectedSource: SessionNetworkEndpoint
    ) throws -> SessionControlMessage? {
        pollLock.lock()
        defer { pollLock.unlock() }
        for _ in 0..<directPeerControlPollDatagramLimit {
            guard let datagram = try receiveDatagramWithSourceIfAvailable(
                socket: descriptor,
                byteCount: directPeerControlDatagramByteCount,
                buffer: &pollScratch
            ) else {
                return nil
            }
            guard controlSourceMatches(datagram, expectedSource: expectedSource) else {
                continue
            }
            incrementReceivedDatagrams()
            do {
                return try SessionControlCodec.decode(datagram.data)
            } catch {
                incrementDroppedDatagrams()
            }
        }
        return nil
    }

    package func close() {
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

    private func incrementDroppedDatagrams() {
        stateLock.lock()
        droppedDatagramsStorage += 1
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
