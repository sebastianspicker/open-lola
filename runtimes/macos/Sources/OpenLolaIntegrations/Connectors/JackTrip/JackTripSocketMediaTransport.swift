import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Defines UDP socket-backed JackTrip compatibility media transports and exchange deadlines.
import Dispatch
import Foundation

/// Sends JackTrip socket media transmitter through sockets bound for the requested peer.
public struct JackTripSocketMediaTransmitter: JackTripCompatibilityMediaTransmitting {
    public init() {}

    public func transmit(_ datagrams: [JackTripCompatibilityDatagram], localHost: String, peer: String) throws -> Int {
        let generated = transmitGenerated
        return try transmitExternalConnectorDatagrams(
            datagrams, localHost: localHost, peer: peer, transmitGenerated: generated
        )
    }

    public func transmitGenerated(
        localHost: String,
        peer: String,
        generate: (_ emit: (JackTripCompatibilityDatagram) throws -> Void) throws -> Void
    ) throws -> Int {
        let socket = try makeUdpSocket(
            receiveTimeoutSeconds: 1,
            bufferProfile: .realtimeAudio
        )
        defer { closeUdpSocket(socket) }
        if localHost != "0.0.0.0" {
            try bindIPv4(socket, host: localHost, port: 0)
        }
        var transmitted = 0
        try generate { datagram in
            let result = try trySendDatagram(
                try JackTripAudioPayloadCodec.encodeDatagram(
                    datagram.packets,
                    headerMode: datagram.headerMode
                ),
                socket: socket,
                host: peer,
                port: datagram.destinationPort.bigEndian,
                nonBlocking: true
            )
            if result == .sent {
                transmitted += 1
            }
        }
        return transmitted
    }
}

/// Receives JackTrip socket media receiver from bound sockets until its request completes.
public struct JackTripSocketMediaReceiver: JackTripCompatibilityMediaReceiving {
    public init() {}

    public func receive(_ request: JackTripMediaReceiveRequest) throws -> JackTripCompatibilityReceiveResult {
        let socketLease = try boundSocket(request)
        defer { socketLease.releaseOwner() }
        return try receive(request, socket: socketLease.descriptor)
    }

    public func receiveWhileBound(
        _ request: JackTripMediaReceiveRequest,
        transmit: @escaping () throws -> Int
    ) throws -> (transmitted: Int, received: JackTripCompatibilityReceiveResult) {
        let socketLease = try boundSocket(request)
        defer { socketLease.releaseOwner() }
        let task = JackTripConcurrentTransmitTask(transmit: transmit)
        task.start()
        let receiveResult = Result {
            try receive(request, socket: socketLease.descriptor, concurrentTransmit: task)
        }
        let deadlineNanoseconds = exchangeDeadlineNanoseconds(for: request)
        let completionDeadline = request.runUntilDeadline
            ? jackTripExchangeDeadlineNanoseconds(
                from: deadlineNanoseconds,
                addingSeconds: 1
            )
            : deadlineNanoseconds
        guard task.wait(untilNanoseconds: completionDeadline) == .success else {
            throw ExternalConnectorSessionError.socketFailed(
                "JackTrip transmit did not complete before the exchange deadline"
            )
        }
        guard let transmitResult = task.snapshot() else {
            throw ExternalConnectorSessionError.socketFailed("JackTrip transmit completed without a result")
        }
        if let completedAtNanoseconds = task.completedAtNanoseconds,
           completedAtNanoseconds > completionDeadline {
            throw ExternalConnectorSessionError.socketFailed(
                "JackTrip transmit did not complete before the exchange deadline"
            )
        }
        return (try transmitResult.get(), try receiveResult.get())
    }

    private func boundSocket(_ request: JackTripMediaReceiveRequest) throws -> JackTripBoundSocketLease {
        let socket = try makeUdpSocket(
            receiveTimeoutSeconds: request.timeoutSeconds,
            bufferProfile: .realtimeAudio
        )
        do {
            try bindIPv4(socket, host: request.localHost, port: request.audioPort.bigEndian)
            try setNonBlocking(socket)
            return JackTripBoundSocketLease(socket: socket)
        } catch {
            closeUdpSocket(socket)
            throw error
        }
    }

    private func receive(
        _ request: JackTripMediaReceiveRequest,
        socket: Int32,
        concurrentTransmit: JackTripConcurrentTransmitTask? = nil
    ) throws -> JackTripCompatibilityReceiveResult {
        try JackTripSocketReceiveLoop.receive(
            request,
            socket: socket,
            concurrentTransmit: concurrentTransmit
        )
    }
}

private func exchangeDeadlineNanoseconds(for request: JackTripMediaReceiveRequest) -> UInt64 {
    if let deadline = request.exchangeDeadlineNanoseconds {
        return deadline
    }
    return jackTripExchangeDeadlineNanoseconds(timeoutSeconds: request.timeoutSeconds)
}

func jackTripExchangeDeadlineNanoseconds(timeoutSeconds: Int) -> UInt64 {
    let timeout = UInt64(max(1, timeoutSeconds)).multipliedReportingOverflow(by: 1_000_000_000)
    let timeoutNanoseconds = timeout.overflow ? UInt64.max : timeout.partialValue
    let deadline = DispatchTime.now().uptimeNanoseconds.addingReportingOverflow(timeoutNanoseconds)
    return deadline.overflow ? UInt64.max : deadline.partialValue
}

private func jackTripExchangeDeadlineNanoseconds(
    from deadlineNanoseconds: UInt64,
    addingSeconds seconds: UInt64
) -> UInt64 {
    let duration = seconds.multipliedReportingOverflow(by: 1_000_000_000)
    let result = deadlineNanoseconds.addingReportingOverflow(duration.overflow ? UInt64.max : duration.partialValue)
    return result.overflow ? UInt64.max : result.partialValue
}

private extension Result where Success == Int, Failure == Error {
    var successValue: Int? {
        guard case .success(let value) = self else {
            return nil
        }
        return value
    }
}
