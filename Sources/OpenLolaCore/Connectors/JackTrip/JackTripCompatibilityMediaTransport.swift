// Implements JackTripCompatibilityMediaTransport media transport boundary, separating packet I/O from session policy.
import Dispatch
import Foundation

/// Defines the validated fields for JackTrip compatibility receive result.
public struct JackTripCompatibilityReceiveResult: Codable, Equatable, Sendable {
    public var datagrams: [JackTripCompatibilityDatagram]
    public var stopControlDatagramCount: Int
    public var receivedDatagramCount: Int

    public init(
        datagrams: [JackTripCompatibilityDatagram],
        stopControlDatagramCount: Int = 0,
        receivedDatagramCount: Int? = nil
    ) {
        self.datagrams = datagrams
        self.stopControlDatagramCount = stopControlDatagramCount
        self.receivedDatagramCount = receivedDatagramCount ?? datagrams.count
    }
}

struct JackTripRunMediaResult: Sendable {
    var generated: [JackTripCompatibilityDatagram]
    var transmitted: Int
    var received: [JackTripCompatibilityDatagram]
    var receivedDatagramCount: Int
    var stopControlDatagramCount: Int
    var expectedReceiveCount: Int
    var sink: ExternalConnectorMediaSinkReport?
}

/// Requires conformers to interleavedInt16PCM operations for JackTrip audio frame providing.
public protocol JackTripAudioFrameProviding {
    var providerReport: ExternalConnectorMediaProviderReport { get }

    func interleavedInt16PCM(sequenceNumber: Int, channels: Int, frames: Int) throws -> Data

    func interleavedInt16PCM(
        sequenceNumber: Int,
        channels: Int,
        frames: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data
}

public extension JackTripAudioFrameProviding {
    var providerReport: ExternalConnectorMediaProviderReport {
        ExternalConnectorMediaProviderReport(
            audioSource: "injected-fixture",
            videoSource: "not-applicable",
            observedEvidenceClasses: [.synthetic],
            notes: "Injected deterministic JackTrip audio provider."
        )
    }

    func interleavedInt16PCM(
        sequenceNumber: Int,
        channels: Int,
        frames: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        guard deadlineNanoseconds == nil else {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "jacktrip-full-duplex-provider-without-deadline"
            )
        }
        return try interleavedInt16PCM(sequenceNumber: sequenceNumber, channels: channels, frames: frames)
    }
}

/// Defines the validated fields for JackTrip synthetic audio frame provider.
public struct JackTripSyntheticAudioFrameProvider: JackTripAudioFrameProviding {
    public init() {}

    public var providerReport: ExternalConnectorMediaProviderReport {
        ExternalConnectorMediaProviderReport(
            audioSource: "synthetic",
            videoSource: "not-applicable",
            observedEvidenceClasses: [.synthetic],
            notes: "Generated interleaved Int16 PCM for JackTrip DEFAULT packetization."
        )
    }

    public func interleavedInt16PCM(sequenceNumber: Int, channels: Int, frames: Int) throws -> Data {
        var data = Data()
        data.reserveCapacity(channels * frames * MemoryLayout<Int16>.size)
        for frame in 0..<frames {
            for channel in 0..<channels {
                let sample = Int16(clamping: ((sequenceNumber + frame + channel) % 127) - 63)
                data.append(UInt8(truncatingIfNeeded: sample))
                data.append(UInt8(truncatingIfNeeded: sample >> 8))
            }
        }
        return data
    }

    public func interleavedInt16PCM(
        sequenceNumber: Int,
        channels: Int,
        frames: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        if let deadlineNanoseconds,
           DispatchTime.now().uptimeNanoseconds >= deadlineNanoseconds {
            throw ExternalConnectorSessionError.socketFailed(
                "JackTrip exchange deadline expired before audio capture"
            )
        }
        return try interleavedInt16PCM(
            sequenceNumber: sequenceNumber,
            channels: channels,
            frames: frames
        )
    }
}

protocol JackTripAudioProviderLifecycle: ExternalConnectorLifecycle {
    func start() throws
}

final class JackTripSessionAudioFrameProvider: JackTripAudioFrameProviding, JackTripAudioProviderLifecycle {
    private enum Source {
        case synthetic
        case fixture(Data)
        case coreAudio
        case jackGraph
    }

    private let configuration: ExternalConnectorSessionConfiguration
    private let source: Source
    private let report: ExternalConnectorMediaProviderReport
    private var audioBridge: LoLaCoreAudioLiveBridge?

    init(configuration: ExternalConnectorSessionConfiguration) throws {
        self.configuration = configuration
        self.source = try Self.source(configuration)
        self.report = Self.providerReport(source)
    }

    var providerReport: ExternalConnectorMediaProviderReport { report }

    func start() throws {
        if case .coreAudio = source {
            audioBridge = try LoLaCoreAudioLiveBridge.makeIfRequested(configuration: configuration)
            guard let audioBridge else {
                throw ExternalConnectorSessionError.missingRequiredArgument("--audio-capture coreaudio:<device-uid>")
            }
            try audioBridge.start()
        }
        if case .jackGraph = source {
            if !configuration.dryRun {
                throw ExternalConnectorSessionError.processLaunchFailed(
                    "jack-graph-backend requires a measured JACK graph capture provider in this environment"
                )
            }
        }
    }

    func stop() {
        audioBridge?.stop()
        audioBridge = nil
    }

    func interleavedInt16PCM(sequenceNumber: Int, channels: Int, frames: Int) throws -> Data {
        try interleavedInt16PCM(
            sequenceNumber: sequenceNumber,
            channels: channels,
            frames: frames,
            deadlineNanoseconds: nil
        )
    }

    func interleavedInt16PCM(
        sequenceNumber: Int,
        channels: Int,
        frames: Int,
        deadlineNanoseconds: UInt64?
    ) throws -> Data {
        switch source {
        case .synthetic:
            return try JackTripSyntheticAudioFrameProvider().interleavedInt16PCM(
                sequenceNumber: sequenceNumber,
                channels: channels,
                frames: frames
            )
        case let .fixture(data):
            return repeatedFixtureData(
                data,
                byteCount: max(1, channels * frames * MemoryLayout<Int16>.size)
            )
        case .coreAudio:
            guard let audioBridge else {
                throw ExternalConnectorSessionError.socketFailed("Core Audio JackTrip provider was not started")
            }
            let captureDeadline = deadlineNanoseconds.map(DispatchTime.init(uptimeNanoseconds:))
                ?? (.now() + .seconds(1))
            guard DispatchTime.now() < captureDeadline else {
                throw ExternalConnectorSessionError.socketFailed(
                    "JackTrip exchange deadline expired before Core Audio capture"
                )
            }
            if let payload = try audioBridge.nextLoLaAudioPayload(
                until: captureDeadline
            ) {
                return payload
            }
            throw ExternalConnectorSessionError.socketFailed(
                "Core Audio capture produced no JackTrip audio payload before timeout"
            )
        case .jackGraph:
            return try JackTripSyntheticAudioFrameProvider().interleavedInt16PCM(
                sequenceNumber: sequenceNumber,
                channels: channels,
                frames: frames
            )
        }
    }

    private static func source(_ configuration: ExternalConnectorSessionConfiguration) throws -> Source {
        if configuration.jackTrip.audioBackend == .jackGraph {
            return .jackGraph
        }
        switch try parseExternalConnectorAudioCaptureSource(configuration) {
        case .synthetic:
            return .synthetic
        case let .fixture(data):
            return .fixture(data)
        case .coreAudio:
            return .coreAudio
        }
    }

    private static func providerReport(_ source: Source) -> ExternalConnectorMediaProviderReport {
        let audioSource: String
        let evidence: [ExternalConnectorEvidenceClass]
        switch source {
        case .synthetic:
            audioSource = "synthetic"
            evidence = [.synthetic]
        case .fixture:
            audioSource = "fixture"
            evidence = [.synthetic]
        case .coreAudio:
            audioSource = "coreaudio-live"
            evidence = [.liveDevice]
        case .jackGraph:
            audioSource = "jack-graph-backend"
            evidence = [.synthetic]
        }
        let notes = switch source {
        case .jackGraph:
            "JACK graph backend selected. Dry runs use deterministic local frames; "
                + "measured runs require local JACK graph capture evidence."
        default:
            "JackTrip public session audio provider selection for DEFAULT UDP packetization."
        }
        return ExternalConnectorMediaProviderReport(
            audioSource: audioSource,
            videoSource: "not-applicable",
            observedEvidenceClasses: evidence,
            notes: notes
        )
    }
}

/// Requires conformers to transmit, transmitGenerated, receive operations for JackTrip compatibility media transmitting.
public protocol JackTripCompatibilityMediaTransmitting {
    func transmit(_ datagrams: [JackTripCompatibilityDatagram], localHost: String, peer: String) throws -> Int

    func transmitGenerated(
        localHost: String,
        peer: String,
        generate: (_ emit: (JackTripCompatibilityDatagram) throws -> Void) throws -> Void
    ) throws -> Int
}

public extension JackTripCompatibilityMediaTransmitting {
    func transmitGenerated(
        localHost: String,
        peer: String,
        generate: (_ emit: (JackTripCompatibilityDatagram) throws -> Void) throws -> Void
    ) throws -> Int {
        var datagrams: [JackTripCompatibilityDatagram] = []
        try generate { datagrams.append($0) }
        return try transmit(datagrams, localHost: localHost, peer: peer)
    }
}

/// Requires conformers to receive, receiveWhileBound operations for JackTrip compatibility media receiving.
public protocol JackTripCompatibilityMediaReceiving {
    func receive(_ request: JackTripMediaReceiveRequest) throws -> JackTripCompatibilityReceiveResult

    func receiveWhileBound(
        _ request: JackTripMediaReceiveRequest,
        transmit: @escaping () throws -> Int
    ) throws -> (transmitted: Int, received: JackTripCompatibilityReceiveResult)
}

public extension JackTripCompatibilityMediaReceiving {
    func receiveWhileBound(
        _ request: JackTripMediaReceiveRequest,
        transmit: @escaping () throws -> Int
    ) throws -> (transmitted: Int, received: JackTripCompatibilityReceiveResult) {
        let transmitted = try transmit()
        return (transmitted, try receive(request))
    }
}

/// Defines the validated fields for JackTrip media receive request.
public struct JackTripMediaReceiveRequest: Sendable {
    public static let maximumRetainedReceiveEvidenceDatagrams = 256
    public static let maximumRetainedGeneratedEvidenceDatagrams = 256

    public var expectedDatagrams: Int
    public var localHost: String
    public var peer: String
    public var audioPort: UInt16
    public var headerMode: JackTripPacketHeaderMode
    public var emptyHeaderTemplate: JackTripDefaultHeader?
    public var timeoutSeconds: Int
    public var exchangeDeadlineNanoseconds: UInt64?
    var audioSink: JackTripReceiveAudioSink?

    public init(
        expectedDatagrams: Int,
        localHost: String,
        peer: String,
        audioPort: UInt16,
        headerMode: JackTripPacketHeaderMode,
        emptyHeaderTemplate: JackTripDefaultHeader?,
        timeoutSeconds: Int,
        exchangeDeadlineNanoseconds: UInt64? = nil
    ) {
        self.expectedDatagrams = expectedDatagrams
        self.localHost = localHost
        self.peer = peer
        self.audioPort = audioPort
        self.headerMode = headerMode
        self.emptyHeaderTemplate = emptyHeaderTemplate
        self.timeoutSeconds = timeoutSeconds
        self.exchangeDeadlineNanoseconds = exchangeDeadlineNanoseconds
        audioSink = nil
    }

    func attaching(audioSink: JackTripReceiveAudioSink?) -> Self {
        var request = self
        request.audioSink = audioSink
        return request
    }
}

/// Retains emitted datagrams in memory so callers can inspect JackTrip memory media transmitter.
public final class JackTripMemoryMediaTransmitter: JackTripCompatibilityMediaTransmitting {
    public private(set) var transmittedDatagrams: [JackTripCompatibilityDatagram] = []

    public init() {}

    public func transmit(
        _ datagrams: [JackTripCompatibilityDatagram],
        localHost _: String,
        peer _: String
    ) throws -> Int {
        transmittedDatagrams.append(contentsOf: datagrams)
        return datagrams.count
    }
}

/// Returns preloaded datagrams that match the requested route for JackTrip memory media receiver.
public struct JackTripMemoryMediaReceiver: JackTripCompatibilityMediaReceiving {
    public var datagrams: [JackTripCompatibilityDatagram]

    public init(datagrams: [JackTripCompatibilityDatagram]) {
        self.datagrams = datagrams
    }

    public func receive(_ request: JackTripMediaReceiveRequest) throws -> JackTripCompatibilityReceiveResult {
        JackTripCompatibilityReceiveResult(datagrams: Array(datagrams.filter {
            ($0.sourceHost == nil || $0.sourceHost == request.peer || request.peer == "0.0.0.0")
                && $0.destinationPort == request.audioPort
        }.prefix(request.expectedDatagrams)))
    }
}

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
        guard task.wait(untilNanoseconds: deadlineNanoseconds) == .success else {
            throw ExternalConnectorSessionError.socketFailed(
                "JackTrip transmit did not complete before the exchange deadline"
            )
        }
        guard let transmitResult = task.snapshot() else {
            throw ExternalConnectorSessionError.socketFailed("JackTrip transmit completed without a result")
        }
        if let completedAtNanoseconds = task.completedAtNanoseconds,
           completedAtNanoseconds > deadlineNanoseconds {
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

private extension Result where Success == Int, Failure == Error {
    var successValue: Int? {
        guard case .success(let value) = self else {
            return nil
        }
        return value
    }
}
