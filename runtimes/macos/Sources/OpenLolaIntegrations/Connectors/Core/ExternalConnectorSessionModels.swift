import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
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

/// How a live connector session ended. The verdict stays PARTIAL until measured
/// evidence exists, so this is the field that tells a tester the run worked.
public enum ExternalConnectorSessionOutcomeKind: String, Codable, Equatable, Sendable {
    /// The session ran for its whole duration without a runtime error.
    case completed
    /// The session hit a runtime error; `reason` carries it.
    case failed
    /// The session ended early without an error, for example on a peer DISCONNECT.
    case stopped
}

/// Machine-readable end state of a live connector session, next to the evidence verdict.
public struct ExternalConnectorSessionOutcome: Codable, Equatable, Sendable {
    public var kind: ExternalConnectorSessionOutcomeKind
    public var reason: String?

    public init(kind: ExternalConnectorSessionOutcomeKind, reason: String? = nil) {
        self.kind = kind
        self.reason = reason
    }

    /// Derives the outcome from the session's runtime error and early-stop reason;
    /// an error always wins over a stop.
    public static func from(runtimeError: String?, stopReason: String?) -> Self {
        if let runtimeError { return .init(kind: .failed, reason: runtimeError) }
        if let stopReason { return .init(kind: .stopped, reason: stopReason) }
        return .init(kind: .completed)
    }
}

/// Selects whether the LoLa connector sends the control handshake or waits for
/// it. Media direction comes from the role; the two are independent in LoLa.
public enum LoLaControlSide: String, Codable, Equatable, Sendable {
    /// Sends CHECKLOLASTATUS and QUICKCONN to `--peer`, like the Rust `connect` command.
    case initiator
    /// Waits for a validated QUICKCONN and ACKs it, like the Rust `listen` command.
    case responder

    /// The side used when none is given: TX and TX-RX initiate, RX responds.
    public static func defaultSide(for role: ExternalConnectorSessionRole) -> Self {
        role == .rx ? .responder : .initiator
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

/// Selects generated audio or the operator-selected Core Audio devices for LoLa.
public enum LoLaAudioDeviceMode: String, Codable, Equatable, Sendable {
    case generated
    case coreAudio = "coreaudio"
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
