// Validates RecordingSessionArtifactValidationError acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

/// Describes failures that prevent recording-session artifact inputs or evidence from satisfying the required validation invariants.
public enum RecordingSessionArtifactValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError,
    ValidationNonPositiveFieldError,
    ValidationNegativeFieldError,
    ValidationNonFiniteFieldError {
    case emptyField(String)
    case emptyList(String)
    case nonPositiveField(String)
    case negativeField(String)
    case nonFiniteField(String)
    case unorderedAudioCallbackMetrics(String)
    case passWithoutMeasuredRun
    case passAllowsRealtimeFileIO
    case passWithoutCopiedMediaSideLane
    case passWithoutAsyncWriter
    case passWithoutDropOnPressure
    case passWithoutSlowWriterPressure
    case passWithoutRecordingDropOrGap
    case passIncreasesAudioP99(baseline: Double, recording: Double)
    case passIncreasesAudioMax(baseline: Double, recording: Double)
    case passChangesAudioPlayoutTarget(baseline: Int, recording: Int)
    case passWithAudioUnderruns(Int)
    case passWithHiddenPlayoutGrowth
    case passWithoutConfigurationMetadata
    case passWithoutVerdictMetadata
    case recordedMediaWithoutOptIn(RecordingArtifactKind)
    case mediaOptInWithoutRecordedOrUnavailable(RecordingArtifactKind)
    case unavailableMediaWithoutBlocker(RecordingArtifactKind)
    case mediaOffWithArtifact(RecordingArtifactKind)
    case recordedMediaMissingManifestEntry(RecordingArtifactKind, String)
    case recordedMediaByteCountMismatch(RecordingArtifactKind)
    case recordedMediaChecksumMismatch(RecordingArtifactKind)
}
