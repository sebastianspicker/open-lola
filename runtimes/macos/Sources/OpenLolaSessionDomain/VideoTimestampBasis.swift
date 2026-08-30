/// Identifies the clock that produced a video frame timestamp.
public enum VideoTimestampBasis: String, Codable, Equatable, Sendable {
    case syntheticMonotonicNanoseconds
    case hostUptimeNanoseconds
    case avFoundationPresentationTimeNanoseconds
    case remoteRTP90kNanoseconds
}
