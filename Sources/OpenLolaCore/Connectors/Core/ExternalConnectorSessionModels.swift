import Foundation

public enum ExternalConnectorSessionRole: String, Codable, Equatable, Sendable {
    case tx, rx
    case txRx = "tx-rx"

    public var transmits: Bool {
        self == .tx || self == .txRx
    }

    public var receives: Bool {
        self == .rx || self == .txRx
    }
}

public enum ExternalConnectorLaunchKind: String, Codable, Equatable, Sendable {
    case internalLoLaControl
    case internalLoLaControlUdp
    case internalUltraGridMvtp
    case internalJackTripAudio
    case externalProcess
}

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

public enum ExternalConnectorControlTransport: String, Codable, Equatable, Sendable {
    case udp
    case tcp
}

public enum LoLaVideoPayloadKind: String, Codable, Equatable, Sendable {
    case generated
    case avFoundationMjpeg = "avfoundation-mjpeg"
    case avFoundationRaw8 = "avfoundation-raw8"
    case avFoundationJpegXS = "avfoundation-jpeg-xs"
}

public enum UltraGridFECMode: String, Codable, Equatable, Sendable {
    case none
    case singleParity = "single-parity"
}

public enum UltraGridEncryptionMode: String, Codable, Equatable, Sendable {
    case none
    case aes128GCM = "aes-128-gcm"
}

public enum UltraGridControlMode: String, Codable, Equatable, Sendable {
    case disabled
    case localTCP = "local-tcp"
}
