// Preserves UltraGrid socket receive ordering while isolating bounded drain and completion policy.
import Dispatch
import Foundation

struct UltraGridBoundReceiveExchange {
    let request: UltraGridMediaReceiveRequest
    let audioSocket: Int32
    let videoSocket: Int32
    let state: UltraGridConcurrentReceiveState
    let transmitTask: UltraGridConcurrentTransmitTask
    let receiver: UltraGridSocketMediaReceiver

    func run() throws -> (transmitted: Int, received: UltraGridCompatibilityReceiveResult) {
        let outcome = try receiveOutcome()
        try waitForTransmit(outcome: outcome)
        return (transmittedCount(outcome: outcome), receiveResult(outcome: outcome))
    }

    private func receiveOutcome() throws -> UltraGridConcurrentReceiveOutcome {
        do {
            return try UltraGridFullDuplexReceiveLoop(
                request: request, audioSocket: audioSocket, videoSocket: videoSocket, state: state, receiver: receiver
            ).run()
        } catch {
            _ = transmitTask.wait(untilNanoseconds: state.snapshot().deadlineNanoseconds)
            throw error
        }
    }

    private func waitForTransmit(outcome: UltraGridConcurrentReceiveOutcome) throws {
        let deadline = state.snapshot().deadlineNanoseconds
        guard transmitTask.wait(untilNanoseconds: deadline) == .success else {
            throw UltraGridCompatibilityError.receiveTimeout(
                expected: request.expectedDatagrams, actual: outcome.ledger.receivedDatagramCount
            )
        }
        if case let .failure(error)? = transmitResult(outcome: outcome) { throw error }
    }

    private func transmittedCount(outcome: UltraGridConcurrentReceiveOutcome) -> Int {
        guard case let .success(value)? = transmitResult(outcome: outcome) else { return 0 }
        return value.successfulDatagramCount
    }

    private func transmitResult(
        outcome: UltraGridConcurrentReceiveOutcome
    ) -> Result<UltraGridCompatibilityTransmitResult, Error>? {
        state.snapshot().transmitResult ?? outcome.transmitResult
    }

    private func receiveResult(outcome: UltraGridConcurrentReceiveOutcome) -> UltraGridCompatibilityReceiveResult {
        UltraGridCompatibilityReceiveResult(
            datagrams: outcome.ledger.evidence,
            receivedDatagramCount: outcome.ledger.receivedDatagramCount,
            incrementalSummary: outcome.ledger.observationSummary()
        )
    }
}

struct UltraGridFullDuplexReceiveLoop {
    let request: UltraGridMediaReceiveRequest
    let audioSocket: Int32
    let videoSocket: Int32
    let state: UltraGridConcurrentReceiveState
    let receiver: UltraGridSocketMediaReceiver

    func run() throws -> UltraGridConcurrentReceiveOutcome {
        var ledger = makeLedger()
        var buffers = UltraGridReceiveBuffers()
        while true {
            let status = try checkedStatus()
            if let outcome = completedOutcome(status: status, ledger: ledger) { return outcome }
            try ultraGridReceiveAvailable(
                endpoints: UltraGridReceiveEndpoints(
                    receiver: receiver,
                    request: request,
                    audioSocket: audioSocket,
                    videoSocket: videoSocket
                ),
                ledger: &ledger, buffers: &buffers, packetLimit: packetLimit(ledger)
            )
            let afterDrain = state.snapshot()
            if let outcome = completedOutcome(status: afterDrain, ledger: ledger) { return outcome }
            try wait(status: afterDrain)
        }
    }

    private func makeLedger() -> UltraGridSocketReceiveEvidenceLedger {
        UltraGridSocketReceiveEvidenceLedger(
            evidenceLimit: ultraGridSocketConcurrentReceiveEvidenceLimit,
            observer: UltraGridIncrementalReceiveObserver(encryptionConfiguration: request.encryptionConfiguration)
        )
    }

    private func checkedStatus() throws -> UltraGridConcurrentReceiveState.Snapshot {
        let status = state.snapshot()
        if status.finished { state.consumeReadiness() }
        if case let .failure(error)? = status.transmitResult { throw error }
        return status
    }

    private func completedOutcome(
        status: UltraGridConcurrentReceiveState.Snapshot,
        ledger: UltraGridSocketReceiveEvidenceLedger
    ) -> UltraGridConcurrentReceiveOutcome? {
        if DispatchTime.now().uptimeNanoseconds >= status.deadlineNanoseconds { return outcome(status: status, ledger: ledger) }
        let expected = ultraGridExpectedFullDuplexReceiveCount(
            requestedDatagrams: request.expectedDatagrams, transmitResult: status.transmitResult
        )
        return ultraGridFullDuplexReceiveIsComplete(
            transmissionFinished: status.finished, expectedDatagrams: expected,
            receivedDatagramCount: ledger.receivedDatagramCount
        ) ? outcome(status: status, ledger: ledger) : nil
    }

    private func outcome(
        status: UltraGridConcurrentReceiveState.Snapshot,
        ledger: UltraGridSocketReceiveEvidenceLedger
    ) -> UltraGridConcurrentReceiveOutcome {
        UltraGridConcurrentReceiveOutcome(ledger: ledger, transmitResult: status.transmitResult)
    }

    private func packetLimit(_ ledger: UltraGridSocketReceiveEvidenceLedger) -> Int {
        ultraGridSocketReceiveEvidencePacketLimit(receivedCount: ledger.receivedDatagramCount)
    }

    private func wait(status: UltraGridConcurrentReceiveState.Snapshot) throws {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < status.deadlineNanoseconds else { return }
        var descriptors = [audioSocket, videoSocket]
        if !status.finished, let completion = state.readinessDescriptor { descriptors.append(completion) }
        _ = try waitForReadableSockets(
            sockets: descriptors, timeoutMicroseconds: max(1, (status.deadlineNanoseconds - now) / 1_000)
        )
    }
}

struct UltraGridStandaloneReceiveLoop {
    let request: UltraGridMediaReceiveRequest
    let audioSocket: Int32
    let videoSocket: Int32
    let receiver: UltraGridSocketMediaReceiver

    func run() throws -> UltraGridCompatibilityReceiveResult {
        var ledger = makeLedger()
        let deadline = ultraGridReceiveDeadlineNanoseconds(
            nowNanoseconds: DispatchTime.now().uptimeNanoseconds, timeoutSeconds: request.timeoutSeconds
        )
        var buffers = UltraGridReceiveBuffers()
        while ledger.receivedDatagramCount < request.expectedDatagrams, DispatchTime.now().uptimeNanoseconds < deadline {
            try ultraGridReceiveAvailable(
                endpoints: UltraGridReceiveEndpoints(
                    receiver: receiver,
                    request: request,
                    audioSocket: audioSocket,
                    videoSocket: videoSocket
                ),
                ledger: &ledger, buffers: &buffers, packetLimit: packetLimit(ledger)
            )
            try waitIfNeeded(ledger: ledger, deadline: deadline)
        }
        return UltraGridCompatibilityReceiveResult(
            datagrams: ledger.evidence, receivedDatagramCount: ledger.receivedDatagramCount,
            incrementalSummary: ledger.observationSummary()
        )
    }

    private func makeLedger() -> UltraGridSocketReceiveEvidenceLedger {
        UltraGridSocketReceiveEvidenceLedger(
            evidenceLimit: min(max(0, request.expectedDatagrams), ultraGridSocketConcurrentReceiveEvidenceLimit),
            observer: UltraGridIncrementalReceiveObserver(encryptionConfiguration: request.encryptionConfiguration)
        )
    }

    private func packetLimit(_ ledger: UltraGridSocketReceiveEvidenceLedger) -> Int {
        min(ultraGridSocketPerStreamDrainPacketLimit, max(0, request.expectedDatagrams - ledger.receivedDatagramCount))
    }

    private func waitIfNeeded(ledger: UltraGridSocketReceiveEvidenceLedger, deadline: UInt64) throws {
        guard ledger.receivedDatagramCount < request.expectedDatagrams else { return }
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < deadline else { return }
        _ = try waitForReadableSockets(
            sockets: [audioSocket, videoSocket], timeoutMicroseconds: max(1, (deadline - now) / 1_000)
        )
    }
}

private struct UltraGridReceiveBuffers {
    var audio: [UInt8] = []
    var video: [UInt8] = []
}

private struct UltraGridReceiveEndpoints {
    let receiver: UltraGridSocketMediaReceiver
    let request: UltraGridMediaReceiveRequest
    let audioSocket: Int32
    let videoSocket: Int32
}

private func ultraGridReceiveAvailable(
    endpoints: UltraGridReceiveEndpoints,
    ledger: inout UltraGridSocketReceiveEvidenceLedger,
    buffers: inout UltraGridReceiveBuffers,
    packetLimit: Int
) throws {
    try endpoints.receiver.receiveAvailable(
        ultraGridSocketReceiveRequest(
            endpoints.request,
            socket: endpoints.audioSocket,
            port: endpoints.request.audioPort,
            stream: .audio
        ),
        into: &ledger, buffer: &buffers.audio, packetLimit: packetLimit
    )
    try endpoints.receiver.receiveAvailable(
        ultraGridSocketReceiveRequest(
            endpoints.request,
            socket: endpoints.videoSocket,
            port: endpoints.request.videoPort,
            stream: .video
        ),
        into: &ledger, buffer: &buffers.video, packetLimit: packetLimit
    )
}

private func ultraGridSocketReceiveRequest(
    _ request: UltraGridMediaReceiveRequest,
    socket: Int32,
    port: UInt16,
    stream: LoLaCompatibilityMediaStream
) -> UltraGridSocketReceiveAvailableRequest {
    UltraGridSocketReceiveAvailableRequest(
        socket: socket, port: port, stream: stream, peer: request.peer,
        payloadRegistry: request.payloadRegistry, encryptionConfiguration: request.encryptionConfiguration
    )
}
