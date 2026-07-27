// Defines connector roles, launch modes, control transports, video sources, FEC, encryption, and control modes.
import Foundation

/// Selects whether an external connector transmits, receives, or does both.
public enum ExternalConnectorSessionRole: String, Codable, Equatable, Sendable {
    // swiftlint:disable:next identifier_name
    case tx, rx
    case txRx = "tx-rx"

    public var transmits: Bool {
        self == .tx || self == .txRx
    }

    public var receives: Bool {
        self == .rx || self == .txRx
    }
}

/// Defines the supported choices for external connector launch kind.
public enum ExternalConnectorLaunchKind: String, Codable, Equatable, Sendable {
    case internalLoLaControl
    case internalLoLaControlUdp
    case internalUltraGridMvtp
    case internalJackTripAudio
    case externalProcess
}

/// Enumerates the supported operating modes for external connector media.
public enum ExternalConnectorMediaMode: String, Codable, Equatable, Sendable {
    case audio
    case video
    case audioVideo

    public var hasAudio: Bool {
        self == .audio || self == .audioVideo
    }

    public var hasVideo: Bool {
        self == .video || self == .audioVideo
    }
}

/// Selects UDP or TCP for the external connector control exchange.
public enum ExternalConnectorControlTransport: String, Codable, Equatable, Sendable {
    case udp
    case tcp
}

/// Defines the supported choices for LoLa video payload kind.
public enum LoLaVideoPayloadKind: String, Codable, Equatable, Sendable {
    case generated
    case avFoundationMjpeg = "avfoundation-mjpeg"
    case avFoundationRaw8 = "avfoundation-raw8"
    case avFoundationJpegXS = "avfoundation-jpeg-xs"
}

/// Selects whether UltraGrid FEC is disabled or uses a single parity packet.
public enum UltraGridFECMode: String, Codable, Equatable, Sendable {
    case none
    case singleParity = "single-parity"
}

/// Enumerates the supported operating modes for UltraGrid encryption.
public enum UltraGridEncryptionMode: String, Codable, Equatable, Sendable {
    case none
    case aes128GCM = "aes-128-gcm"
}

/// Enumerates the supported operating modes for UltraGrid control.
public enum UltraGridControlMode: String, Codable, Equatable, Sendable {
    case disabled
    case localTCP = "local-tcp"
}
