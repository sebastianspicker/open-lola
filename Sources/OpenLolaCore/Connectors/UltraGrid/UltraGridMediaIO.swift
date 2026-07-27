// Implements UltraGrid UDP media I/O, isolating socket lifetime and datagram handling from compatibility policy.
import Darwin
import Dispatch
import Foundation

final class UltraGridRuntimeDeadline: @unchecked Sendable {
    let deadlineNanoseconds: UInt64

    init(timeoutSeconds: Int, nowNanoseconds: UInt64 = DispatchTime.now().uptimeNanoseconds) {
        deadlineNanoseconds = ultraGridReceiveDeadlineNanoseconds(
            nowNanoseconds: nowNanoseconds,
            timeoutSeconds: timeoutSeconds
        )
    }

    var hasExpired: Bool { DispatchTime.now().uptimeNanoseconds >= deadlineNanoseconds }

    func check() throws {
        guard !hasExpired else {
            throw UltraGridCompatibilityError.receiveTimeout(expected: 0, actual: 0)
        }
    }

}
/// Defines transmission routines that return the count of emitted compatibility datagrams.
public protocol UltraGridCompatibilityMediaTransmitting {
    func transmit(_ datagrams: [UltraGridCompatibilityDatagram], localHost: String, peer: String) throws -> Int

    func transmitGenerated(
        localHost: String,
        peer: String,
        generate: (_ emit: (UltraGridCompatibilityDatagram) throws -> Void) throws -> Void
    ) throws -> Int
}

public extension UltraGridCompatibilityMediaTransmitting {
    func transmitGenerated(
        localHost: String,
        peer: String,
        generate: (_ emit: (UltraGridCompatibilityDatagram) throws -> Void) throws -> Void
    ) throws -> Int {
        var datagrams: [UltraGridCompatibilityDatagram] = []
        try generate { datagrams.append($0) }
        return try transmit(datagrams, localHost: localHost, peer: peer)
    }
}
/// Bundles peer routing, media ports, codec settings, and timeout for one receive attempt.
public struct UltraGridMediaReceiveRequest: Sendable {
    public var expectedDatagrams: Int
    public var localHost: String
    public var peer: String
    public var audioPort: UInt16
    public var videoPort: UInt16
    public var payloadRegistry: UltraGridRTPPayloadRegistry
    public var encryptionConfiguration: UltraGridEncryptionConfiguration?
    public var timeoutSeconds: Int

    public init(
        expectedDatagrams: Int,
        localHost: String,
        peer: String,
        audioPort: UInt16,
        videoPort: UInt16,
        payloadRegistry: UltraGridRTPPayloadRegistry,
        encryptionConfiguration: UltraGridEncryptionConfiguration?,
        timeoutSeconds: Int
    ) {
        self.expectedDatagrams = expectedDatagrams
        self.localHost = localHost
        self.peer = peer
        self.audioPort = audioPort
        self.videoPort = videoPort
        self.payloadRegistry = payloadRegistry
        self.encryptionConfiguration = encryptionConfiguration
        self.timeoutSeconds = timeoutSeconds
    }
}
/// Returns accepted datagrams and the total count observed during a receive attempt.
public struct UltraGridCompatibilityReceiveResult: Sendable {
    public var datagrams: [UltraGridCompatibilityDatagram]
    public var receivedDatagramCount: Int
    var incrementalSummary: UltraGridIncrementalReceiveSummary?

    public init(
        datagrams: [UltraGridCompatibilityDatagram],
        receivedDatagramCount: Int? = nil
    ) {
        self.datagrams = datagrams
        self.receivedDatagramCount = receivedDatagramCount ?? datagrams.count
        self.incrementalSummary = nil
    }

    init(
        datagrams: [UltraGridCompatibilityDatagram],
        receivedDatagramCount: Int,
        incrementalSummary: UltraGridIncrementalReceiveSummary?
    ) {
        self.datagrams = datagrams
        self.receivedDatagramCount = receivedDatagramCount
        self.incrementalSummary = incrementalSummary
    }
}
/// Distinguishes attempted datagrams from those successfully emitted by a transmit attempt.
public struct UltraGridCompatibilityTransmitResult: Sendable {
    public var successfulDatagramCount: Int
    public var attemptedDatagramCount: Int

    public init(successfulDatagramCount: Int, attemptedDatagramCount: Int) {
        self.successfulDatagramCount = successfulDatagramCount
        self.attemptedDatagramCount = attemptedDatagramCount
    }
}
/// Defines receive routines that can keep sockets bound while a paired transmit runs.
public protocol UltraGridCompatibilityMediaReceiving {
    func receive(_ request: UltraGridMediaReceiveRequest) throws -> [UltraGridCompatibilityDatagram]

    func receiveResult(_ request: UltraGridMediaReceiveRequest) throws -> UltraGridCompatibilityReceiveResult

    func receiveWhileBound(
        _ request: UltraGridMediaReceiveRequest,
        transmit: @escaping () throws -> UltraGridCompatibilityTransmitResult
    ) throws -> (transmitted: Int, received: UltraGridCompatibilityReceiveResult)
}

public extension UltraGridCompatibilityMediaReceiving {
    func receiveResult(_ request: UltraGridMediaReceiveRequest) throws -> UltraGridCompatibilityReceiveResult {
        UltraGridCompatibilityReceiveResult(datagrams: try receive(request))
    }

    func receiveWhileBound(
        _ request: UltraGridMediaReceiveRequest,
        transmit: @escaping () throws -> UltraGridCompatibilityTransmitResult
    ) throws -> (transmitted: Int, received: UltraGridCompatibilityReceiveResult) {
        let transmitResult = try transmit()
        return (transmitResult.successfulDatagramCount, try receiveResult(request))
    }
}
/// Retains emitted datagrams in memory so callers can inspect a transmit attempt.
public final class UltraGridMemoryMediaTransmitter: UltraGridCompatibilityMediaTransmitting {
    public private(set) var transmittedDatagrams: [UltraGridCompatibilityDatagram] = []

    public init() {}

    public func transmit(
        _ datagrams: [UltraGridCompatibilityDatagram],
        localHost _: String,
        peer _: String
    ) throws -> Int {
        transmittedDatagrams.append(contentsOf: datagrams)
        return datagrams.count
    }
}
/// Serves preloaded datagrams filtered by the request peer and media ports.
public struct UltraGridMemoryMediaReceiver: UltraGridCompatibilityMediaReceiving {
    public var datagrams: [UltraGridCompatibilityDatagram]

    public init(datagrams: [UltraGridCompatibilityDatagram]) {
        self.datagrams = datagrams
    }

    public func receive(_ request: UltraGridMediaReceiveRequest) throws -> [UltraGridCompatibilityDatagram] {
        let matching = datagrams.filter {
            ($0.sourceHost == nil || $0.sourceHost == request.peer || request.peer == "0.0.0.0")
                && ($0.destinationPort == request.audioPort || $0.destinationPort == request.videoPort)
        }
        let limit = request.expectedDatagrams > 0 ? request.expectedDatagrams : matching.count
        let received = Array(matching.prefix(limit))
        return received
    }
}
/// Sends generated audio and video datagrams through UDP sockets bound to the local host.
public struct UltraGridSocketMediaTransmitter: UltraGridCompatibilityMediaTransmitting {
    public init() {}

    public func transmit(
        _ datagrams: [UltraGridCompatibilityDatagram],
        localHost: String,
        peer: String
    ) throws -> Int {
        try transmitExternalConnectorDatagrams(
            datagrams, localHost: localHost, peer: peer, transmitGenerated: transmitGenerated
        )
    }

    public func transmitGenerated(
        localHost: String,
        peer: String,
        generate: (_ emit: (UltraGridCompatibilityDatagram) throws -> Void) throws -> Void
    ) throws -> Int {
        let sockets = try boundTransmitSockets(localHost: localHost)
        defer {
            closeUdpSocket(sockets.audio)
            closeUdpSocket(sockets.video)
        }
        var transmitted = 0
        var dropState = UltraGridSocketTransmitDropState()
        try generate { datagram in
            guard dropState.shouldAttempt(datagram) else {
                return
            }
            let result = try trySendDatagram(
                try datagram.rtp.encoded(),
                socket: datagram.stream == .audio ? sockets.audio : sockets.video,
                host: peer,
                port: datagram.destinationPort.bigEndian,
                nonBlocking: true
            )
            guard result == .sent else {
                dropState.recordWouldBlock(datagram)
                return
            }
            transmitted += 1
        }
        return transmitted
    }

    private func boundTransmitSockets(localHost: String) throws -> (audio: Int32, video: Int32) {
        let audioSocket = try makeUdpSocket(
            receiveTimeoutSeconds: 1,
            bufferProfile: .realtimeAudio
        )
        do {
            let videoSocket = try makeUdpSocket(
                receiveTimeoutSeconds: 1,
                bufferProfile: .realtimeVideo
            )
            do {
                if localHost != "0.0.0.0" {
                    try bindIPv4(audioSocket, host: localHost, port: 0)
                    try bindIPv4(videoSocket, host: localHost, port: 0)
                }
                return (audioSocket, videoSocket)
            } catch {
                closeUdpSocket(videoSocket)
                throw error
            }
        } catch {
            closeUdpSocket(audioSocket)
            throw error
        }
    }
}

struct UltraGridSocketTransmitDropState {
    private var droppingVideoFrame = false
    private var awaitingOptionalFEC = false

    mutating func shouldAttempt(_ datagram: UltraGridCompatibilityDatagram) -> Bool {
        guard datagram.stream == .video else {
            return true
        }
        if awaitingOptionalFEC {
            awaitingOptionalFEC = false
            if datagram.rtp.header.payloadType == UltraGridCompatibility.fecPayloadType {
                return false
            }
        }
        guard droppingVideoFrame else {
            return true
        }
        if datagram.rtp.header.marker {
            droppingVideoFrame = false
            awaitingOptionalFEC = true
        }
        return false
    }

    mutating func recordWouldBlock(_ datagram: UltraGridCompatibilityDatagram) {
        guard datagram.stream == .video,
              datagram.rtp.header.payloadType != UltraGridCompatibility.fecPayloadType else {
            return
        }
        if datagram.rtp.header.marker {
            awaitingOptionalFEC = true
        } else {
            droppingVideoFrame = true
        }
    }
}

struct UltraGridSocketReceiveAvailableRequest {
    var socket: Int32
    var port: UInt16
    var stream: LoLaCompatibilityMediaStream
    var peer: String
    var payloadRegistry: UltraGridRTPPayloadRegistry
    var encryptionConfiguration: UltraGridEncryptionConfiguration?
}

let ultraGridSocketPerStreamDrainPacketLimit = 32
let ultraGridSocketConcurrentReceiveEvidenceLimit = 256

func ultraGridSocketReceiveEvidencePacketLimit(receivedCount: Int) -> Int {
    _ = receivedCount
    return ultraGridSocketPerStreamDrainPacketLimit
}

struct UltraGridSocketReceiveEvidenceLedger {
    let evidenceLimit: Int
    private let observer: UltraGridIncrementalReceiveObserver?
    private(set) var receivedDatagramCount = 0
    private(set) var evidence: [UltraGridCompatibilityDatagram] = []

    init(
        evidenceLimit: Int,
        observer: UltraGridIncrementalReceiveObserver? = nil
    ) {
        self.evidenceLimit = max(0, evidenceLimit)
        self.observer = observer
    }

    mutating func record(_ datagram: UltraGridCompatibilityDatagram) {
        receivedDatagramCount += 1
        observer?.record(datagram)
        if evidence.count < evidenceLimit {
            evidence.append(datagram)
        }
    }

    func observationSummary() -> UltraGridIncrementalReceiveSummary? {
        observer?.finish()
    }
}

func ultraGridFullDuplexReceiveIsComplete(
    transmissionFinished: Bool,
    expectedDatagrams: Int?,
    receivedDatagramCount: Int
) -> Bool {
    guard transmissionFinished, let expectedDatagrams else {
        return false
    }
    return receivedDatagramCount >= expectedDatagrams
}

struct UltraGridSocketReceiveDrainBudget {
    let limit: Int
    private(set) var processed = 0

    var hasCapacity: Bool { processed < max(0, limit) }

    mutating func recordProcessedDatagram() {
        if hasCapacity {
            processed += 1
        }
    }
}

final class UltraGridConcurrentReceiveState: @unchecked Sendable {
    private let lock = NSLock()
    private let readinessSignal = DirectPeerCaptureReadinessSignal()
    private var transmissionFinished = false
    private let receiveDeadlineNanoseconds: UInt64
    private var transmitResult: Result<UltraGridCompatibilityTransmitResult, Error>?

    init(timeoutSeconds: Int, nowNanoseconds: UInt64 = DispatchTime.now().uptimeNanoseconds) {
        receiveDeadlineNanoseconds = ultraGridReceiveDeadlineNanoseconds(
            nowNanoseconds: nowNanoseconds,
            timeoutSeconds: timeoutSeconds
        )
    }

    func finishTransmission(_ result: Result<UltraGridCompatibilityTransmitResult, Error>) {
        lock.lock()
        transmissionFinished = true
        transmitResult = result
        lock.unlock()
        readinessSignal?.signal()
    }

    var readinessDescriptor: Int32? { readinessSignal?.readDescriptor }

    struct Snapshot {
        var finished: Bool
        var deadlineNanoseconds: UInt64
        var transmitResult: Result<UltraGridCompatibilityTransmitResult, Error>?
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(
            finished: transmissionFinished,
            deadlineNanoseconds: receiveDeadlineNanoseconds,
            transmitResult: transmitResult
        )
    }

    func consumeReadiness() {
        readinessSignal?.drain()
    }

}

final class UltraGridConcurrentTransmitTask: @unchecked Sendable {
    private let transmit: () throws -> UltraGridCompatibilityTransmitResult
    private let state: UltraGridConcurrentReceiveState
    private let workerLifecycle = ConnectorConcurrentWorkerLifecycle()

    init(
        transmit: @escaping () throws -> UltraGridCompatibilityTransmitResult,
        state: UltraGridConcurrentReceiveState
    ) {
        self.transmit = transmit
        self.state = state
    }

    func run() {
        state.finishTransmission(Result { try transmit() })
    }

    func start() {
        workerLifecycle.start { [self] in
            run()
        }
    }

    func wait(untilNanoseconds deadlineNanoseconds: UInt64) -> DispatchTimeoutResult {
        workerLifecycle.wait(untilNanoseconds: deadlineNanoseconds)
    }
}

struct UltraGridConcurrentReceiveOutcome {
    var ledger: UltraGridSocketReceiveEvidenceLedger
    var transmitResult: Result<UltraGridCompatibilityTransmitResult, Error>?
}
/// Receives UltraGrid datagrams from bound UDP sockets until the request deadline expires.
public struct UltraGridSocketMediaReceiver: Sendable, UltraGridCompatibilityMediaReceiving {
    public init() {}

    public func receive(_ request: UltraGridMediaReceiveRequest) throws -> [UltraGridCompatibilityDatagram] {
        try receiveResult(request).datagrams
    }

    public func receiveResult(_ request: UltraGridMediaReceiveRequest) throws -> UltraGridCompatibilityReceiveResult {
        let sockets = try boundSockets(request)
        defer {
            closeUdpSocket(sockets.audio)
            closeUdpSocket(sockets.video)
        }
        return try receive(request, audioSocket: sockets.audio, videoSocket: sockets.video)
    }

    public func receiveWhileBound(
        _ request: UltraGridMediaReceiveRequest,
        transmit: @escaping () throws -> UltraGridCompatibilityTransmitResult
    ) throws -> (transmitted: Int, received: UltraGridCompatibilityReceiveResult) {
        // This deadline starts before socket setup and TX so neither can extend the RX window.
        let state = UltraGridConcurrentReceiveState(timeoutSeconds: request.timeoutSeconds)
        let sockets = try boundSockets(request)
        defer {
            closeUdpSocket(sockets.audio)
            closeUdpSocket(sockets.video)
        }
        let transmitTask = UltraGridConcurrentTransmitTask(
            transmit: transmit,
            state: state
        )
        transmitTask.start()
        return try UltraGridBoundReceiveExchange(
            request: request,
            audioSocket: sockets.audio,
            videoSocket: sockets.video,
            state: state,
            transmitTask: transmitTask,
            receiver: self
        ).run()
    }

    private func receiveUntilTransmissionCompletes(
        _ request: UltraGridMediaReceiveRequest,
        audioSocket: Int32,
        videoSocket: Int32,
        state: UltraGridConcurrentReceiveState
    ) throws -> UltraGridConcurrentReceiveOutcome {
        try UltraGridFullDuplexReceiveLoop(
            request: request,
            audioSocket: audioSocket,
            videoSocket: videoSocket,
            state: state,
            receiver: self
        ).run()
    }

    private func boundSockets(_ request: UltraGridMediaReceiveRequest) throws -> (audio: Int32, video: Int32) {
        let audioSocket = try makeUdpSocket(
            receiveTimeoutSeconds: request.timeoutSeconds,
            bufferProfile: .realtimeAudio
        )
        do {
            let videoSocket = try makeUdpSocket(
                receiveTimeoutSeconds: request.timeoutSeconds,
                bufferProfile: .realtimeVideo
            )
            do {
                try bindIPv4(audioSocket, host: request.localHost, port: request.audioPort.bigEndian)
                try bindIPv4(videoSocket, host: request.localHost, port: request.videoPort.bigEndian)
                try setNonBlocking(audioSocket)
                try setNonBlocking(videoSocket)
                return (audioSocket, videoSocket)
            } catch {
                closeUdpSocket(videoSocket)
                throw error
            }
        } catch {
            closeUdpSocket(audioSocket)
            throw error
        }
    }

    private func receive(
        _ request: UltraGridMediaReceiveRequest,
        audioSocket: Int32,
        videoSocket: Int32
    ) throws -> UltraGridCompatibilityReceiveResult {
        try UltraGridStandaloneReceiveLoop(
            request: request,
            audioSocket: audioSocket,
            videoSocket: videoSocket,
            receiver: self
        ).run()
    }

    func receiveAvailable(
        _ request: UltraGridSocketReceiveAvailableRequest,
        into ledger: inout UltraGridSocketReceiveEvidenceLedger,
        buffer: inout [UInt8],
        packetLimit: Int
    ) throws {
        var budget = UltraGridSocketReceiveDrainBudget(limit: packetLimit)
        while budget.hasCapacity, let datagram = try receiveDatagramWithSourceIfAvailable(
            socket: request.socket,
            byteCount: 65_535,
            buffer: &buffer
        ) {
            budget.recordProcessedDatagram()
            guard request.peer == "0.0.0.0" || datagram.host == request.peer else {
                continue
            }
            let rtp = try RTPPacket.decode(datagram.data)
            _ = try UltraGridCompatibility.decode(
                rtp,
                registry: request.payloadRegistry,
                encryptionConfiguration: request.encryptionConfiguration
            )
            ledger.record(UltraGridCompatibilityDatagram(
                stream: request.stream,
                sourceHost: datagram.host,
                sourcePort: datagram.port,
                destinationPort: request.port,
                rtp: rtp
            ))
        }
    }
}
