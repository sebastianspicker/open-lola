// Runs a deterministic capture probe that proves frame generation without camera hardware.
/// Exercises a deterministic video capture and frame transport path so regressions remain reproducible without hardware.
public enum VideoCaptureSyntheticSmoke {
    public static func run() -> VideoCaptureReport {
        let capture = syntheticCapture()
        return syntheticReport(
            queue: capture.queue,
            capturedTimestampsNanoseconds: capture.capturedTimestampsNanoseconds
        )
    }

    private static func syntheticCapture() -> (
        queue: LatestFrameQueue,
        capturedTimestampsNanoseconds: [UInt64]
    ) {
        var queue = LatestFrameQueue(maxDepth: 1)
        var capturedTimestampsNanoseconds: [UInt64] = []
        let source = TestPatternCameraSource(
            width: 1_280,
            height: 720,
            frameIntervalNanoseconds: 33_333_333,
            streamID: VideoCaptureStreamMetadata.syntheticTestPattern.streamID,
            sourceRole: .testPattern,
            frameRate: VideoFrameRate(numerator: 30, denominator: 1)
        )
        for _ in 0..<3 {
            if let frame = source.nextFrame() {
                capturedTimestampsNanoseconds.append(frame.timestampNanoseconds)
                queue.enqueue(frame)
            }
        }
        return (queue, capturedTimestampsNanoseconds)
    }

    private static func syntheticReport(
        queue: LatestFrameQueue,
        capturedTimestampsNanoseconds: [UInt64]
    ) -> VideoCaptureReport {
        VideoCaptureReport(
            identity: .init(
                id: "m08-video-capture-synthetic-smoke",
                title: "Synthetic M08 video capture smoke",
                capturedAt: "2026-05-02T00:00:00Z",
                stream: VideoCaptureStreamMetadata.syntheticTestPattern
            ),
            capture: .init(
                source: VideoSourceDescription(
                    kind: .testPattern,
                    label: "synthetic-test-pattern",
                    deviceUniqueId: nil,
                    permissionStatus: "notRequired"
                ),
                format: VideoCaptureFormat(
                    width: 1_280,
                    height: 720,
                    nominalFrameRate: 30,
                    pixelFormat: "synthetic-rgb"
                ),
                durationSeconds: 1,
                queue: VideoQueueMetrics(
                    policy: .latestFrame,
                    maxDepth: queue.maxDepth,
                    observedMaxDepth: queue.observedMaxDepth,
                    droppedFrames: queue.droppedFrames
                )
            ),
            frameMetrics: .init(
                framesCaptured: 3,
                framesRetained: queue.frames.count,
                frameAge: SourceValidationMetrics.videoFrameAge,
                frameInterval: videoCapturePacketAge(
                    from: videoCaptureIntervalsMicroseconds(from: capturedTimestampsNanoseconds)
                )
            ),
            runtimeEvidence: .init(
                audioImpact: defaultVideoCaptureAudioImpact(),
                rawCapture: .disabled
            ),
            outcome: .init(
                verdict: .partial,
                notes: "Synthetic source-validation report; no AVFoundation camera or audio stress run."
            )
        )
    }
}
