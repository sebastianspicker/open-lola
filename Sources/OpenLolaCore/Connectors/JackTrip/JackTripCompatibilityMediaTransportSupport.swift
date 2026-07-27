// Holds private JackTrip socket ownership and receive-loop mechanics outside the transport boundary API.
import Foundation

final class JackTripConcurrentTransmitTask: @unchecked Sendable {
    private let transmit: () throws -> Int
    private let lock = NSLock()
    private let readinessSignal = DirectPeerCaptureReadinessSignal()
    private let workerLifecycle = ConnectorConcurrentWorkerLifecycle()
    private var result: Result<Int, Error>?
    private var completionNanoseconds: UInt64?

    init(transmit: @escaping () throws -> Int) {
        self.transmit = transmit
    }

    func start() {
        workerLifecycle.start { [self] in
            run()
        }
    }

    func wait(untilNanoseconds deadlineNanoseconds: UInt64) -> DispatchTimeoutResult {
        workerLifecycle.wait(untilNanoseconds: deadlineNanoseconds)
    }

    func run() {
        let result = Result { try transmit() }
        lock.lock()
        self.result = result
        completionNanoseconds = DispatchTime.now().uptimeNanoseconds
        lock.unlock()
        readinessSignal?.signal()
    }

    var readinessDescriptor: Int32? { readinessSignal?.readDescriptor }

    func snapshot() -> Result<Int, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return result
    }

    var completedAtNanoseconds: UInt64? {
        lock.lock()
        defer { lock.unlock() }
        return completionNanoseconds
    }

    func consumeReadiness() {
        readinessSignal?.drain()
    }
}

final class JackTripBoundSocketLease: @unchecked Sendable {
    private let lock = NSLock()
    private var socket: Int32?

    init(socket: Int32) {
        self.socket = socket
    }

    var descriptor: Int32 {
        lock.lock()
        defer { lock.unlock() }
        precondition(socket != nil, "JackTrip socket lease used after close")
        return socket!
    }

    func releaseOwner() {
        lock.lock()
        defer { lock.unlock() }
        guard let socket else { return }
        self.socket = nil
        closeUdpSocket(socket)
    }
}

private struct JackTripSocketReceiveLoopState {
    let deadlineNanoseconds: UInt64
    var received: [JackTripCompatibilityDatagram] = []
    var buffer: [UInt8] = []
    var stopControlDatagramCount = 0
    var receivedDatagramCount = 0

    mutating func retain(_ datagram: JackTripCompatibilityDatagram) {
        guard received.count < JackTripMediaReceiveRequest.maximumRetainedReceiveEvidenceDatagrams else {
            return
        }
        received.append(datagram)
    }

    var result: JackTripCompatibilityReceiveResult {
        JackTripCompatibilityReceiveResult(
            datagrams: received,
            stopControlDatagramCount: stopControlDatagramCount,
            receivedDatagramCount: receivedDatagramCount
        )
    }
}

private struct JackTripIncomingDatagram {
    let data: Data
    let host: String
    let port: UInt16
}

enum JackTripSocketReceiveLoop {
    static func receive(
        _ request: JackTripMediaReceiveRequest,
        socket: Int32,
        concurrentTransmit: JackTripConcurrentTransmitTask?
    ) throws -> JackTripCompatibilityReceiveResult {
        var state = JackTripSocketReceiveLoopState(
            deadlineNanoseconds: request.exchangeDeadlineNanoseconds
                ?? jackTripExchangeDeadlineNanoseconds(timeoutSeconds: request.timeoutSeconds)
        )
        while DispatchTime.now().uptimeNanoseconds < state.deadlineNanoseconds {
            let transmitSnapshot = concurrentTransmit?.snapshot()
            if transmitSnapshot != nil {
                concurrentTransmit?.consumeReadiness()
            }
            guard shouldContinue(
                request: request,
                state: state,
                concurrentTransmit: concurrentTransmit,
                transmitSnapshot: transmitSnapshot
            ) else { break }
            try drainAvailableDatagrams(request, socket: socket, state: &state)
            try waitForNextDatagram(
                request: request,
                socket: socket,
                state: state,
                concurrentTransmit: concurrentTransmit,
                transmitSnapshot: transmitSnapshot
            )
        }
        return state.result
    }

    private static func shouldContinue(
        request: JackTripMediaReceiveRequest,
        state: JackTripSocketReceiveLoopState,
        concurrentTransmit: JackTripConcurrentTransmitTask?,
        transmitSnapshot: Result<Int, Error>?
    ) -> Bool {
        if let transmitSnapshot, case .failure = transmitSnapshot {
            return false
        }
        if concurrentTransmit == nil || transmitSnapshot != nil {
            return state.receivedDatagramCount < request.expectedDatagrams
        }
        return true
    }

    private static func drainAvailableDatagrams(
        _ request: JackTripMediaReceiveRequest,
        socket: Int32,
        state: inout JackTripSocketReceiveLoopState
    ) throws {
        var processed = 0
        while processed < 32, let datagram = try receiveDatagramWithSourceIfAvailable(
            socket: socket,
            byteCount: 65_535,
            buffer: &state.buffer
        ) {
            processed += 1
            try process(
                JackTripIncomingDatagram(data: datagram.data, host: datagram.host, port: datagram.port),
                request: request,
                state: &state
            )
        }
    }

    private static func process(
        _ datagram: JackTripIncomingDatagram,
        request: JackTripMediaReceiveRequest,
        state: inout JackTripSocketReceiveLoopState
    ) throws {
        guard request.peer == "0.0.0.0" || datagram.host == request.peer else {
            return
        }
        guard !isStopControlDatagram(datagram.data) else {
            state.stopControlDatagramCount += 1
            return
        }
        let decoded = JackTripCompatibilityDatagram(
            sourceHost: datagram.host,
            sourcePort: datagram.port,
            destinationPort: request.audioPort,
            headerMode: request.headerMode,
            packets: try JackTripAudioPayloadCodec.decodeDatagram(
                datagram.data,
                headerMode: request.headerMode,
                emptyHeaderTemplate: request.emptyHeaderTemplate
            )
        )
        state.receivedDatagramCount += 1
        request.audioSink?.consume(decoded)
        state.retain(decoded)
    }

    private static func isStopControlDatagram(_ data: Data) -> Bool {
        data.count == JackTripCompatibility.stopControlDatagramByteCount
            && data.allSatisfy { $0 == 0xff }
    }

    private static func waitForNextDatagram(
        request: JackTripMediaReceiveRequest,
        socket: Int32,
        state: JackTripSocketReceiveLoopState,
        concurrentTransmit: JackTripConcurrentTransmitTask?,
        transmitSnapshot: Result<Int, Error>?
    ) throws {
        guard shouldWait(
            request: request,
            state: state,
            concurrentTransmit: concurrentTransmit
        ) else { return }
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < state.deadlineNanoseconds else { return }
        let descriptors = readableDescriptors(
            socket: socket,
            concurrentTransmit: concurrentTransmit,
            transmitSnapshot: transmitSnapshot
        )
        _ = try waitForReadableSockets(
            sockets: descriptors,
            timeoutMicroseconds: waitMicroseconds(
                now: now,
                deadlineNanoseconds: state.deadlineNanoseconds,
                concurrentTransmit: concurrentTransmit,
                transmitSnapshot: transmitSnapshot
            )
        )
    }

    private static func shouldWait(
        request: JackTripMediaReceiveRequest,
        state: JackTripSocketReceiveLoopState,
        concurrentTransmit: JackTripConcurrentTransmitTask?
    ) -> Bool {
        concurrentTransmit?.snapshot() == nil || state.receivedDatagramCount < request.expectedDatagrams
    }

    private static func readableDescriptors(
        socket: Int32,
        concurrentTransmit: JackTripConcurrentTransmitTask?,
        transmitSnapshot: Result<Int, Error>?
    ) -> [Int32] {
        guard transmitSnapshot == nil,
              let completionDescriptor = concurrentTransmit?.readinessDescriptor else {
            return [socket]
        }
        return [socket, completionDescriptor]
    }

    private static func waitMicroseconds(
        now: UInt64,
        deadlineNanoseconds: UInt64,
        concurrentTransmit: JackTripConcurrentTransmitTask?,
        transmitSnapshot: Result<Int, Error>?
    ) -> UInt64 {
        let remainingMicroseconds = max(1, (deadlineNanoseconds - now) / 1_000)
        let usesPollingWait = concurrentTransmit != nil
            && transmitSnapshot == nil
            && concurrentTransmit?.readinessDescriptor == nil
        return usesPollingWait ? min(1_000, remainingMicroseconds) : remainingMicroseconds
    }
}
