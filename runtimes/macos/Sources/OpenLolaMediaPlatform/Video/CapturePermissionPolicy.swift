// Maps capture authorization states to proceed-or-block decisions with operator-readable messages and resolves microphone access.
import Foundation
import Dispatch
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
#endif

/// Names the capture device class that an authorization state applies to.
public enum CapturePermissionSubject: String, Equatable, Sendable {
    case camera
    case microphone

    var settingsPane: String {
        switch self {
        case .camera: "Camera"
        case .microphone: "Microphone"
        }
    }
}

/// Says whether capture may start, and why not when it may not.
public enum CapturePermissionDecision: Equatable, Sendable {
    case proceed
    case blocked(String)
}

/// Pure mapping from an authorization status to a start decision; it never touches the real TCC APIs.
public enum CapturePermissionPolicy {
    /// Seconds to wait for the operator to answer a system permission prompt.
    public static let defaultRequestTimeoutSeconds: TimeInterval = 30

    /// Allows capture only when authorized; every other state yields a message that names the next step.
    public static func decision(
        for status: AVFoundationPermissionStatus,
        subject: CapturePermissionSubject,
        timeoutSeconds: TimeInterval = defaultRequestTimeoutSeconds
    ) -> CapturePermissionDecision {
        let name = subject.rawValue
        let pane = "System Settings > Privacy & Security > \(subject.settingsPane)"
        switch status {
        case .authorized:
            return .proceed
        case .denied:
            return .blocked("\(name.capitalized) access is denied. Allow Open LoLa in \(pane), then start again.")
        case .restricted:
            return .blocked("\(name.capitalized) access is restricted by a system policy (for example parental controls or device management).")
        case .notDetermined:
            return .blocked("\(name.capitalized) access has not been decided. Answer the system prompt, or allow Open LoLa in \(pane), then start again.")
        case .requestTimedOut:
            return .blocked("The \(name) permission prompt was not answered within \(Int(timeoutSeconds)) seconds. Answer the prompt, or allow Open LoLa in \(pane), then start again.")
        case .unknown:
            return .blocked("The \(name) authorization state is unknown. Check \(pane), then start again.")
        }
    }
}

#if canImport(AVFoundation)
/// Resolves microphone authorization, asking the system once when it is undecided and waiting up to `timeoutSeconds`.
public func resolveAVFoundationAudioPermission(
    timeoutSeconds: TimeInterval = CapturePermissionPolicy.defaultRequestTimeoutSeconds
) -> AVFoundationPermissionStatus {
    resolveAVFoundationPermission(mediaType: .audio, timeoutSeconds: timeoutSeconds)
}

func resolveAVFoundationPermission(
    mediaType: AVMediaType,
    timeoutSeconds: TimeInterval
) -> AVFoundationPermissionStatus {
    let current = AVCaptureDevice.authorizationStatus(for: mediaType)
    guard current == .notDetermined else {
        return AVFoundationPermissionStatus(authorizationStatus: current)
    }
    let semaphore = DispatchSemaphore(value: 0)
    AVCaptureDevice.requestAccess(for: mediaType) { _ in
        semaphore.signal()
    }
    guard semaphore.wait(timeout: .now() + timeoutSeconds) == .success else {
        return .requestTimedOut
    }
    return AVFoundationPermissionStatus(authorizationStatus: AVCaptureDevice.authorizationStatus(for: mediaType))
}
#else
/// Resolves microphone authorization; always unknown where AVFoundation is unavailable.
public func resolveAVFoundationAudioPermission(
    timeoutSeconds: TimeInterval = CapturePermissionPolicy.defaultRequestTimeoutSeconds
) -> AVFoundationPermissionStatus {
    .unknown
}
#endif
