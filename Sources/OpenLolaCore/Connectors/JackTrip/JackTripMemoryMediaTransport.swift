// Defines in-memory JackTrip compatibility media transports for deterministic sessions and tests.
import Foundation

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
