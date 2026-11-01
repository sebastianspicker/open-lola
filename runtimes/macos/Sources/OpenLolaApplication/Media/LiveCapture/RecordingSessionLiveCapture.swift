import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Coordinates release-readiness execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation
import Dispatch
import COpenLolaAtomics
import os
#if canImport(CoreAudio)
import CoreAudio
import Darwin
#endif
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
#endif

enum RecordingSessionLiveMediaCapture {
    /// Records audio and video at the same time so both cover the same window.
    static func capture(configuration: RecordingSessionRunConfiguration) -> RecordingCapturedMedia {
        let result = RecordingConcurrentCaptureResult()
        let group = DispatchGroup()
        if configuration.capture.audio.mode == .on {
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                do {
                    result.audio = try CoreAudioRawInputRecorder.run(
                        selection: configuration.capture.audio,
                        durationSeconds: configuration.durationSeconds
                    )
                } catch {
                    result.audioBlockers = ["Core Audio input capture unavailable: \(error)"]
                }
            }
        }
        if configuration.capture.video.mode == .on {
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                do {
                    result.video = try AVFoundationRawVideoRecorder.run(
                        selection: configuration.capture.video,
                        durationSeconds: configuration.durationSeconds
                    )
                } catch {
                    result.videoBlockers = ["AVFoundation video capture unavailable: \(error)"]
                }
            }
        }
        group.wait()
        return RecordingCapturedMedia(
            audio: result.audio,
            audioBlockers: result.audioBlockers,
            video: result.video,
            videoBlockers: result.videoBlockers
        )
    }
}

// The audio and video tasks write disjoint stored properties; group.wait() orders the final read after both.
private final class RecordingConcurrentCaptureResult: @unchecked Sendable {
    var audio: RecordingCapturedAudio?
    var audioBlockers: [String] = []
    var video: RecordingCapturedVideo?
    var videoBlockers: [String] = []
}

enum RecordingLiveCaptureWait {
    @discardableResult
    static func wait(
        durationSeconds: Int,
        cancellation: DispatchSemaphore = DispatchSemaphore(value: 0)
    ) -> DispatchTimeoutResult {
        cancellation.wait(timeout: .now() + .seconds(max(0, durationSeconds)))
    }
}

/// Defines the finite media-capture state values recorded by recording-session artifact artifacts for deterministic validation and report interpretation.
public enum RecordingLiveCaptureError: Error, Equatable, Sendable {
    case coreAudioUnavailable
    case coreAudioStatus(OSStatus, String)
    case audioInputNotFound(String)
    case audioInputHasNoChannels(String)
    case audioConfigurationIncomplete
    case audioChannelOutOfRange
    case audioDeviceNotRunnable
    case audioCapturedNoBytes
    case audioBufferSizingOverflow
    case audioInputFormatUnsupported(String)
}
