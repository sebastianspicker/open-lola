// Defines session-owned audio transport choices without binding negotiation to a concrete UDP runtime.
public enum DirectPeerSessionAudioCompression: String, Codable, Equatable, Sendable {
    case raw
    case opusCELTLowDelay = "opus-celt-ld"

    public var audioTransport: DirectPeerSessionAudioTransport {
        switch self {
        case .raw:
            .openLolaRaw
        case .opusCELTLowDelay:
            .openLolaOpusCeltLowDelay
        }
    }

    public var payloadType: SessionPayloadType {
        audioTransport.payloadType
    }
}

public enum DirectPeerSessionAudioTransport: String, Codable, Equatable, Sendable {
    case openLolaRaw = "openlola-raw"
    case openLolaOpusCeltLowDelay = "openlola-opus-celt-ld"
    case aes67ST2110L24 = "aes67-st2110-l24"

    public var payloadType: SessionPayloadType {
        switch self {
        case .openLolaRaw:
            .audioPcmV2
        case .openLolaOpusCeltLowDelay:
            .audioOpusCeltLowDelayFrame
        case .aes67ST2110L24:
            .audioRtpL24
        }
    }

    public var legacyAudioCompression: DirectPeerSessionAudioCompression? {
        switch self {
        case .openLolaRaw:
            .raw
        case .openLolaOpusCeltLowDelay:
            .opusCELTLowDelay
        case .aes67ST2110L24:
            nil
        }
    }
}
