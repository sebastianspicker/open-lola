// Coordinates release-readiness execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
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
        durationSeconds: Int
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
        let collector = AVFoundationSampleBufferCollector(
            stream: AVFoundationSampleBufferStreamConfiguration(queueDepth: selection.queueDepth, streamID: selection.streamID, frameRate: videoFrameRate(from: selection.frameRate)),
            rawCapture: AVFoundationSampleBufferRawCaptureConfiguration(captureRawFrames: true)
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
        RecordingLiveCaptureWait.wait(durationSeconds: durationSeconds)
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
    static func run(selection: RecordingVideoCaptureSelection, durationSeconds: Int) throws -> RecordingCapturedVideo {
        _ = selection
        _ = durationSeconds
        throw VideoCaptureProbeError.captureUnavailable
    }
}
#endif
