// Defines external-connector packet, frame, or monitor values and conversion helpers so producers and consumers agree on their exchanged representation.
import Foundation

/// Defines the validated fields for LoLa opaque control datagram.
public struct LoLaOpaqueControlDatagram: Codable, Equatable, Sendable {
    public var classification: String
    public var sourceHost: String
    public var sourcePort: UInt16
    public var destinationPort: UInt16
    public var payloadLength: Int
    public var firstByte: UInt8?
    public var hexPrefix: String

    public init(
        classification: String = "opaque-control-datagram",
        sourceHost: String,
        sourcePort: UInt16,
        destinationPort: UInt16,
        payloadLength: Int,
        firstByte: UInt8?,
        hexPrefix: String
    ) {
        self.classification = classification
        self.sourceHost = sourceHost
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.payloadLength = payloadLength
        self.firstByte = firstByte
        self.hexPrefix = hexPrefix
    }

    public static func classify(
        payload: [UInt8],
        sourceHost: String,
        sourcePort: UInt16,
        destinationPort: UInt16,
        prefixByteCount: Int = 16
    ) -> LoLaOpaqueControlDatagram {
        LoLaOpaqueControlDatagram(
            sourceHost: sourceHost,
            sourcePort: sourcePort,
            destinationPort: destinationPort,
            payloadLength: payload.count,
            firstByte: payload.first,
            hexPrefix: payload.prefix(max(0, prefixByteCount)).map {
                String(format: "%02x", $0)
            }.joined()
        )
    }
}
