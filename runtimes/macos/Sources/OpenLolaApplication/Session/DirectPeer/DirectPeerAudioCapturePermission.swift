import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Blocks direct-peer audio capture until microphone access is authorized, with a message that names the next step.
import Foundation

/// Reports a microphone authorization state that prevents direct-peer audio capture from starting.
public enum DirectPeerAudioCapturePermissionError: Error, Equatable, LocalizedError {
    case microphoneBlocked(AVFoundationPermissionStatus, message: String)

    public var errorDescription: String? {
        switch self {
        case .microphoneBlocked(_, let message): message
        }
    }
}

/// Checks microphone authorization before the Core Audio input graph starts.
public enum DirectPeerAudioCapturePermission {
    /// Throws when microphone access is not authorized; `resolve` is injectable so tests never call the real TCC API.
    public static func require(
        resolve: () -> AVFoundationPermissionStatus = { resolveAVFoundationAudioPermission() }
    ) throws {
        let status = resolve()
        if case .blocked(let message) = CapturePermissionPolicy.decision(for: status, subject: .microphone) {
            throw DirectPeerAudioCapturePermissionError.microphoneBlocked(status, message: message)
        }
    }
}
