// Enumerates the accepted proof levels for preserving audio priority during multi-video runs so reports cannot imply unmeasured isolation.
import Foundation

/// Distinguishes an observed audio-priority result from a model-only run.
/// When `measured`, `audioPriorityProtected` carries the measured pass/fail
/// result. A `notMeasured` run must leave that Boolean unset.
public enum VideoAudioPriorityEvidence: String, Codable, Equatable, Sendable {
    case measured
    case notMeasured
}
