import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Coordinates release-readiness execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation
import Dispatch
import COpenLolaAtomics
import OpenLolaIntegrations
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
        let stop = DispatchSemaphore(value: 0)
        let capturesMedia = configuration.capture.audio.mode == .on || configuration.capture.video.mode == .on
        // The first SIGINT/SIGTERM ends both capture waits so the take so far is still written; a second one exits.
        let stopMonitor = capturesMedia ? ManagedProcessStopMonitor { number, isRepeat in
            if isRepeat {
                _exit(128 + number)
            }
            stop.signal()
            stop.signal()
        } : nil
        defer { stopMonitor?.invalidate() }
        let startedAt = Date()
        if configuration.capture.audio.mode == .on {
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                do {
                    result.audio = try CoreAudioRawInputRecorder.run(
                        selection: configuration.capture.audio,
                        durationSeconds: configuration.durationSeconds,
                        stop: stop
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
                        durationSeconds: configuration.durationSeconds,
                        stop: stop
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
            videoBlockers: result.videoBlockers,
            startedAt: startedAt,
            endedAt: Date(),
            stopSignalName: stopMonitor?.receivedSignalName
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

/// shortcut: a take is held in RAM until it ends, so audio and video are each capped at 4 GiB; streaming to disk lifts it.
let recordingTakeMemoryBudgetBytes = 4 << 30

/// Rejects an audio take that would not fit the memory budget before anything is captured.
func requireRecordingAudioTakeFitsMemory(_ configuration: RecordingSessionRunConfiguration) throws {
    let audio = configuration.capture.audio
    guard audio.mode == .on,
          let sampleRate = audio.sampleRateHertz,
          let frames = audio.framesPerBuffer,
          let channelCount = audio.channelCount else {
        return
    }
    _ = try recordingAudioTakeSize(
        framesPerBuffer: frames,
        channelCount: channelCount,
        bytesPerSample: audio.sampleFormat.bytesPerSample,
        durationSeconds: configuration.durationSeconds,
        sampleRateHertz: sampleRate
    )
}

/// Frames to keep for a whole video take, with one second of headroom so start and stop jitter does not trim it.
func recordingVideoFrameLimit(frameBytes: Int, frameRate: Double, durationSeconds: Int) throws -> Int {
    let frames = (Double(durationSeconds) + 1) * frameRate
    let byteCount = frames.rounded(.up) * Double(frameBytes)
    guard frames.isFinite, byteCount <= Double(recordingTakeMemoryBudgetBytes) else {
        throw RecordingLiveCaptureError.takeExceedsMemoryBudget(
            media: "video",
            byteCount: byteCount.isFinite && byteCount < Double(Int.max) ? Int(byteCount) : Int.max
        )
    }
    return max(1, Int(frames.rounded(.up)))
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
    case audioSampleRateMismatch(deviceHertz: Double?, requestedHertz: Int)
    case takeExceedsMemoryBudget(media: String, byteCount: Int)
}
