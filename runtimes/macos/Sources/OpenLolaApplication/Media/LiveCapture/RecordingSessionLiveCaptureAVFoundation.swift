import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Coordinates release-readiness execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Dispatch
import Foundation
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
#endif

#if canImport(AVFoundation)
enum AVFoundationRawVideoRecorder {
    static func run(
        selection: RecordingVideoCaptureSelection,
        durationSeconds: Int,
        stop: DispatchSemaphore
    ) throws -> RecordingCapturedVideo {
        let permission = resolveAVFoundationVideoPermission()
        guard permission == .authorized else {
            throw VideoCaptureProbeError.cameraNotAuthorized(permission)
        }
        let requested = selection.deviceID == "auto" ? nil : selection.deviceID
        let selected = try selectedAVFoundationDevice(
            from: currentAVCaptureVideoDevices(),
            requestedUniqueId: requested
        )
        guard let selected else {
            throw VideoCaptureProbeError.cameraNotFound(requested)
        }
        // Raw frames are 32-bit BGRA, so the active format's size gives the bytes per frame.
        let dimensions = CMVideoFormatDescriptionGetDimensions(selected.activeFormat.formatDescription)
        let maxFrames = try recordingVideoFrameLimit(
            frameBytes: Int(dimensions.width) * Int(dimensions.height) * 4,
            frameRate: selection.frameRate,
            durationSeconds: durationSeconds
        )
        let collector = AVFoundationSampleBufferCollector(
            stream: AVFoundationSampleBufferStreamConfiguration(queueDepth: selection.queueDepth, streamID: selection.streamID, frameRate: videoFrameRate(from: selection.frameRate)),
            rawCapture: AVFoundationSampleBufferRawCaptureConfiguration(captureRawFrames: true, maxRetainedRawFrameCount: maxFrames)
        )
        let captureSession = try makeAVFoundationCaptureSession(
            device: selected,
            collector: collector,
            requestedFrameRate: selection.frameRate
        )
        var didStartSession = false
        defer {
            if didStartSession {
                captureSession.session.stopRunning()
            }
            captureSession.restoreDevice(logger: AVFoundationVideoCaptureRunner.logger)
        }
        captureSession.session.startRunning()
        didStartSession = true
        RecordingLiveCaptureWait.wait(durationSeconds: durationSeconds, cancellation: stop)
        captureSession.session.stopRunning()
        didStartSession = false
        guard let artifact = collector.rawVideoArtifact() else {
            throw VideoCaptureProbeError.captureUnavailable
        }
        return artifact
    }
}
#else
enum AVFoundationRawVideoRecorder {
    static func run(selection: RecordingVideoCaptureSelection, durationSeconds: Int, stop: DispatchSemaphore) throws -> RecordingCapturedVideo {
        _ = (selection, durationSeconds, stop)
        throw VideoCaptureProbeError.captureUnavailable
    }
}
#endif
