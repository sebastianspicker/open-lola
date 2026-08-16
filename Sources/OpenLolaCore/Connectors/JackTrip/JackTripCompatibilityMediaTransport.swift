// Defines shared JackTrip compatibility media transport contracts and requests.
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
    /// When set, the socket receive loop remains active through its deadline rather than a packet count.
    public var runUntilDeadline: Bool
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
        exchangeDeadlineNanoseconds: UInt64? = nil,
        runUntilDeadline: Bool = false
    ) {
        self.expectedDatagrams = expectedDatagrams
        self.localHost = localHost
        self.peer = peer
        self.audioPort = audioPort
        self.headerMode = headerMode
        self.emptyHeaderTemplate = emptyHeaderTemplate
        self.timeoutSeconds = timeoutSeconds
        self.exchangeDeadlineNanoseconds = exchangeDeadlineNanoseconds
        self.runUntilDeadline = runUntilDeadline
        audioSink = nil
    }

    func attaching(audioSink: JackTripReceiveAudioSink?) -> Self {
        var request = self
        request.audioSink = audioSink
        return request
    }
}
