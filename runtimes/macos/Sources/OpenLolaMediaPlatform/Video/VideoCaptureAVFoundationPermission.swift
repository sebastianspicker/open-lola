// Reports the AVFoundation authorization state that permits or blocks camera capture.
/// Reports the AVFoundation authorization state that permits or blocks camera capture.
public enum AVFoundationPermissionStatus: String, Codable, Equatable, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined
    case requestTimedOut
    case unknown
}
