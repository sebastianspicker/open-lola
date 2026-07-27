// Builds LoLa media-session frames from provider payloads and received compatibility datagrams.
import Foundation

extension LoLaCompatibilityMediaSession {
    struct LoLaCompatibilityMediaFrameContext {
        var sequenceNumber: Int
        var configuration: ExternalConnectorSessionConfiguration
        var port: UInt16
        var sourceMAC: LoLaEthernetAddress?
        var destinationMAC: LoLaEthernetAddress?
    }

    struct LoLaCompatibilityMediaFrameDraft {
        var stream: LoLaCompatibilityMediaStream
        var sequenceNumber: Int
        var configuration: ExternalConnectorSessionConfiguration
        var payload: Data
        var port: UInt16
        var sourceMAC: LoLaEthernetAddress?
        var destinationMAC: LoLaEthernetAddress?
        var packetKind: LoLaCompatibilityMediaPacketKind
        var frameID: UInt32?
        var fragmentIndex: Int?
        var fragmentCount: Int?
        var fragmentPayloadLength: Int?
        var serializedMediaPayloadLength: Int?
        var finalFragment: Bool?
        var payloadConfidence: String
    }

    static func payloadConfidence(for kind: LoLaCompatibilityMediaPacketKind) -> String {
        switch kind {
        case .audioFragment:
            "source-level recovered audio fragment: one normal fragment per 64-frame int16 block"
        case .videoPrelude:
            "source-level recovered video prelude before normal video fragments"
        case .videoFragment:
            "source-level recovered video fragment carrying generated raw/JPEG-compatible bytes"
        case .malformedFragment:
            "malformed recovered LoLa media fragment"
        case .unknown:
            "unknown LoLa media payload"
        }
    }

    static func makeFrame(
        _ draft: LoLaCompatibilityMediaFrameDraft
    ) throws -> LoLaCompatibilityMediaFrame {
        let frame = try LoLaCompatibilityWireFrame(
            destinationMAC: draft.destinationMAC ?? LoLaEthernetAddress(octets: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
            sourceMAC: draft.sourceMAC ?? LoLaEthernetAddress(octets: [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00]),
            sourceIP: try lolaIPv4(draft.configuration.localHost),
            destinationIP: try lolaIPv4(draft.configuration.peer.isEmpty ? "127.0.0.1" : draft.configuration.peer),
            sourcePort: draft.port,
            destinationPort: draft.port,
            payload: draft.payload
        )
        let encoded = try frame.encoded()
        _ = try LoLaCompatibilityWireFrame.decode(encoded)
        let endpoints = LoLaCompatibilityMediaFrame.Endpoints(
            sourceHost: lolaIPv4HostString(frame.sourceIP),
            destinationHost: lolaIPv4HostString(frame.destinationIP),
            sourcePort: draft.port,
            destinationPort: draft.port
        )
        let payload = LoLaCompatibilityMediaFrame.Payload(
            byteCount: draft.payload.count,
            wireByteCount: encoded.count,
            confidence: draft.payloadConfidence,
            encodedFrame: encoded
        )
        let fragment = LoLaCompatibilityMediaFrame.Fragment(
            packetKind: draft.packetKind,
            frameID: draft.frameID,
            index: draft.fragmentIndex,
            count: draft.fragmentCount,
            payloadLength: draft.fragmentPayloadLength,
            serializedMediaPayloadLength: draft.serializedMediaPayloadLength,
            isFinal: draft.finalFragment
        )
        let input = LoLaCompatibilityMediaFrame.Input(
            stream: draft.stream,
            sequenceNumber: draft.sequenceNumber,
            endpoints: endpoints,
            payload: payload,
            envelopeValidated: true,
            fragment: fragment
        )
        return LoLaCompatibilityMediaFrame(input: input)
    }

    static func decodeFrame(
        _ data: Data,
        sequenceNumber: Int,
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> LoLaCompatibilityMediaFrame {
        let decoded = try LoLaCompatibilityWireFrame.decode(data)
        let decodedMedia = try? LoLaCompatibilityMediaCodec.decode(decoded.payload)
        let packetKind = decodedMedia?.kind ?? .malformedFragment
        let normal = decodedMedia?.normalFragment
        let prelude = decodedMedia?.videoPrelude
        let ports = Set([decoded.sourcePort, decoded.destinationPort])
        let stream: LoLaCompatibilityMediaStream = packetKind == .videoPrelude
            || ports.contains(configuration.videoPort)
            ? .video
            : .audio
        let reportedPacketKind = stream == .audio && packetKind == .videoFragment ? .audioFragment : packetKind
        let endpoints = LoLaCompatibilityMediaFrame.Endpoints(
            sourceHost: lolaIPv4HostString(decoded.sourceIP),
            destinationHost: lolaIPv4HostString(decoded.destinationIP),
            sourcePort: decoded.sourcePort,
            destinationPort: decoded.destinationPort
        )
        let payload = LoLaCompatibilityMediaFrame.Payload(
            byteCount: decoded.payload.count,
            wireByteCount: data.count,
            confidence: payloadConfidence(for: reportedPacketKind),
            encodedFrame: data
        )
        let fragment = LoLaCompatibilityMediaFrame.Fragment(
            packetKind: reportedPacketKind,
            frameID: normal?.header.frameID ?? prelude?.frameID,
            index: normal?.header.fragmentIndex,
            count: normal?.header.fragmentCount ?? prelude?.fragmentCount,
            payloadLength: normal?.header.fragmentPayloadLength,
            serializedMediaPayloadLength: prelude?.serializedSize,
            isFinal: normal?.header.finalFlag
        )
        let input = LoLaCompatibilityMediaFrame.Input(
            stream: stream,
            sequenceNumber: sequenceNumber,
            endpoints: endpoints,
            payload: payload,
            envelopeValidated: true,
            fragment: fragment
        )
        return LoLaCompatibilityMediaFrame(input: input)
    }
}

private func lolaIPv4(_ value: String) throws -> LoLaIPv4Address {
    try parseLoLaUdpIPv4(value)
}

private func lolaIPv4HostString(_ address: LoLaIPv4Address) -> String {
    address.octets.map(String.init).joined(separator: ".")
}
