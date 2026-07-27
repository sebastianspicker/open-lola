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
    static func capture(configuration: RecordingSessionRunConfiguration) -> RecordingCapturedMedia {
        var media = RecordingCapturedMedia()
        if configuration.capture.audio.mode == .on {
            do {
                media.audio = try CoreAudioRawInputRecorder.run(
                    selection: configuration.capture.audio,
                    durationSeconds: configuration.durationSeconds
                )
            } catch {
                media.audioBlockers = ["Core Audio input capture unavailable: \(error)"]
            }
        }
        if configuration.capture.video.mode == .on {
            do {
                media.video = try AVFoundationRawVideoRecorder.run(
                    selection: configuration.capture.video,
                    durationSeconds: configuration.durationSeconds
                )
            } catch {
                media.videoBlockers = ["AVFoundation video capture unavailable: \(error)"]
            }
        }
        return media
    }
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
}
