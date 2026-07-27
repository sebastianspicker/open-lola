// Implements AVFoundationSampleBufferCollector bounded buffering, isolating real-time ownership rules from audio and network loops.
import Foundation
import Dispatch

#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo

private let rawFrameDataCompactionThresholdBytes = 8 * 1024 * 1024
typealias AVFoundationRawFrameExtractor = (CVPixelBuffer) throws -> Data

struct AVFoundationSampleBufferStreamConfiguration: Sendable {
    let queueDepth: Int
    let streamID: UInt32
    let frameRate: VideoFrameRate
    init(queueDepth: Int, streamID: UInt32, frameRate: VideoFrameRate) { self.queueDepth = queueDepth; self.streamID = streamID; self.frameRate = frameRate }
}

struct AVFoundationSampleBufferRawCaptureConfiguration: @unchecked Sendable {
    let captureRawFrames: Bool
    let retainRawFrameArtifact: Bool
    let maxTimestampSampleCount: Int
    let maxRetainedRawFrameCount: Int
    let rawFrameExtractor: AVFoundationRawFrameExtractor
    let onFrameReady: (@Sendable () -> Void)?
    init(captureRawFrames: Bool = false, retainRawFrameArtifact: Bool = true, maxTimestampSampleCount: Int = 4_096, maxRetainedRawFrameCount: Int = 120, rawFrameExtractor: @escaping AVFoundationRawFrameExtractor = { try rawFrameBytes(from: $0) }, onFrameReady: (@Sendable () -> Void)? = nil) { self.captureRawFrames = captureRawFrames; self.retainRawFrameArtifact = retainRawFrameArtifact; self.maxTimestampSampleCount = maxTimestampSampleCount; self.maxRetainedRawFrameCount = maxRetainedRawFrameCount; self.rawFrameExtractor = rawFrameExtractor; self.onFrameReady = onFrameReady }
}

final class AVFoundationSampleBufferCollector: NSObject,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    @unchecked Sendable {
    let captureQueue = DispatchQueue(label: "open-lola.video-capture.avfoundation", qos: .userInitiated)
    private let stateLock = NSLock()
    // Lock coverage for @unchecked Sendable:
    // latestFrameQueue, capturedTimestampsNanoseconds,
    // callbackArrivalTimestampsNanoseconds, framesCapturedCount,
    // rawFrameData, rawFrameDataBaseOffset, rawFrameIndex,
    // latestRawCapturedFrame, raw extraction counters/errors, and
    // nextSequenceNumber are
    // read or written only while stateLock is held. The remaining stored
    // properties are immutable after init.
    private var latestFrameQueue: LatestFrameQueue
    private var capturedTimestampsNanoseconds: [UInt64] = []
    private var callbackArrivalTimestampsNanoseconds: [UInt64] = []
    private var framesCapturedCount = 0
    private var rawFrameData = Data()
    private var rawFrameDataBaseOffset = 0
    private var rawFrameIndex: [RecordingVideoFrameIndexEntry] = []
    private var latestRawCapturedFrame: RawCapturedVideoFrame?
    private var rawExtractionAttempts = 0
    private var rawExtractionFailures = 0
    private var rawPayloadsCaptured = 0
    private var lastRawExtractionError: String?
    private var nextSequenceNumber: UInt64 = 0
    private let streamID: UInt32
    private let frameRate: VideoFrameRate
    private let captureRawFrames: Bool
    private let retainRawFrameArtifact: Bool
    private let maxTimestampSampleCount: Int
    private let maxRetainedRawFrameCount: Int
    private let rawFrameExtractor: AVFoundationRawFrameExtractor
    private let onFrameReady: (@Sendable () -> Void)?

    init(stream: AVFoundationSampleBufferStreamConfiguration, rawCapture: AVFoundationSampleBufferRawCaptureConfiguration = .init()) {
        self.latestFrameQueue = LatestFrameQueue(maxDepth: stream.queueDepth)
        self.streamID = stream.streamID
        self.frameRate = stream.frameRate
        self.captureRawFrames = rawCapture.captureRawFrames
        self.retainRawFrameArtifact = rawCapture.retainRawFrameArtifact
        self.maxTimestampSampleCount = max(2, rawCapture.maxTimestampSampleCount)
        self.maxRetainedRawFrameCount = max(1, rawCapture.maxRetainedRawFrameCount)
        self.rawFrameExtractor = rawCapture.rawFrameExtractor
        self.onFrameReady = rawCapture.onFrameReady
    }
}

extension AVFoundationSampleBufferCollector {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        _ = output
        _ = connection
        record(sampleBuffer: sampleBuffer)
    }

    func record(sampleBuffer: CMSampleBuffer) {
        autoreleasepool {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }

            let callbackArrivalNanoseconds = DispatchTime.now().uptimeNanoseconds
            let timestampNanoseconds = avFoundationPresentationTimestampNanoseconds(
                sampleBuffer: sampleBuffer,
                fallbackNanoseconds: callbackArrivalNanoseconds
            )
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            let pixelFormat = videoCaptureFourCCString(CVPixelBufferGetPixelFormatType(imageBuffer))
            let rawExtractionResult: Result<Data, Error>? = captureRawFrames
                ? Result { try rawFrameExtractor(imageBuffer) }
                : nil

            stateLock.lock()
            let sequenceNumber = nextSequenceNumber
            nextSequenceNumber += 1
            if framesCapturedCount < Int.max {
                framesCapturedCount += 1
            }
            let frame = CapturedVideoFrame(
                streamID: streamID,
                sequenceNumber: sequenceNumber,
                timestampNanoseconds: timestampNanoseconds,
                timestampBasis: .avFoundationPresentationTimeNanoseconds,
                sourceRole: .avFoundationDevice,
                width: width,
                height: height,
                pixelFormat: pixelFormat,
                frameRate: frameRate,
                fingerprint: "avfoundation-\(sequenceNumber)-\(width)x\(height)-\(pixelFormat)"
            )
            capturedTimestampsNanoseconds.append(timestampNanoseconds)
            callbackArrivalTimestampsNanoseconds.append(callbackArrivalNanoseconds)
            trimTimestampSamplesIfNeeded()
            latestFrameQueue.enqueue(frame)
            recordRawFrameExtractionResult(rawExtractionResult, metadata: frame)
            stateLock.unlock()
            onFrameReady?()
        }
    }

    private func recordRawFrameExtractionResult(
        _ rawExtractionResult: Result<Data, Error>?,
        metadata frame: CapturedVideoFrame
    ) {
        guard let rawExtractionResult else {
            return
        }
        rawExtractionAttempts += 1
        switch rawExtractionResult {
        case .success(let rawBytes) where !rawBytes.isEmpty:
            rawPayloadsCaptured += 1
            saveRawFrame(rawBytes, metadata: frame)
        case .success:
            recordRawFrameExtractionFailure(VideoCaptureProbeError.emptyRawFramePayload)
        case .failure(let error):
            recordRawFrameExtractionFailure(error)
        }
    }

}

extension AVFoundationSampleBufferCollector {
    func snapshot(
        source: VideoSourceDescription,
        format: VideoCaptureFormat
    ) -> AVFoundationCameraSourceSnapshot {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        let queue = latestFrameQueue
        let captured = capturedTimestampsNanoseconds
        let callbackArrivals = callbackArrivalTimestampsNanoseconds
        let rawCapture = rawCaptureMetricsLocked()

        return AVFoundationCameraSourceSnapshot(
            sourceDescription: AVFoundationCameraSourceDescription(
                source: source,
                stream: VideoCaptureStreamMetadata(streamID: streamID, sourceRole: .avFoundationDevice, timestampBasis: .avFoundationPresentationTimeNanoseconds),
                format: format,
                queue: VideoQueueMetrics(policy: .latestFrame, maxDepth: queue.maxDepth, observedMaxDepth: queue.observedMaxDepth, droppedFrames: queue.droppedFrames)
            ),
            captureEvidence: AVFoundationCameraCaptureEvidence(framesCaptured: framesCapturedCount, framesRetained: queue.frames.count, capturedFrameTimestampsNanoseconds: captured, callbackArrivalTimestampsNanoseconds: callbackArrivals, retainedFrameTimestampsNanoseconds: queue.frames.map(\.timestampNanoseconds), rawCapture: rawCapture)
        )
    }

    func rawCaptureMetrics() -> RawVideoCaptureMetrics {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        return rawCaptureMetricsLocked()
    }

    func rawVideoArtifact() -> RecordingCapturedVideo? {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        guard !rawFrameData.isEmpty, !rawFrameIndex.isEmpty else {
            return nil
        }
        let retainedDataStart = min(rawFrameDataBaseOffset, rawFrameData.count)
        return RecordingCapturedVideo(
            rawFrameData: rawFrameData.subdata(in: retainedDataStart..<rawFrameData.count),
            frameIndex: rawFrameIndex.map(normalizedRawFrameIndexEntry)
        )
    }

    func latestRawFrame() -> RawCapturedVideoFrame? {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        if let latestRawCapturedFrame {
            return latestRawCapturedFrame
        }
        guard let entry = rawFrameIndex.last else {
            return nil
        }
        let byteOffset = entry.byteOffset
        guard byteOffset >= 0 else {
            return nil
        }
        let endOffset = byteOffset + entry.byteCount
        guard endOffset <= rawFrameData.count else {
            return nil
        }
        return RawCapturedVideoFrame(
            metadata: CapturedVideoFrame(
                streamID: streamID,
                sequenceNumber: entry.sequenceNumber,
                timestampNanoseconds: entry.timestampNanoseconds,
                timestampBasis: .avFoundationPresentationTimeNanoseconds,
                sourceRole: .avFoundationDevice,
                width: entry.width,
                height: entry.height,
                pixelFormat: entry.pixelFormat,
                frameRate: frameRate,
                fingerprint: "avfoundation-\(entry.sequenceNumber)-\(entry.width)x\(entry.height)-\(entry.pixelFormat)"
            ),
            payload: rawFrameData.subdata(in: byteOffset..<endOffset)
        )
    }

}

extension AVFoundationSampleBufferCollector {
    private func saveRawFrame(_ rawBytes: Data, metadata frame: CapturedVideoFrame) {
        latestRawCapturedFrame = RawCapturedVideoFrame(metadata: frame, payload: rawBytes)
        guard retainRawFrameArtifact else {
            return
        }
        let rawIndexEntry = RecordingVideoFrameIndexEntry(
            sequenceNumber: frame.sequenceNumber,
            timestampNanoseconds: frame.timestampNanoseconds,
            byteOffset: rawFrameData.count,
            byteCount: rawBytes.count,
            width: frame.width,
            height: frame.height,
            pixelFormat: frame.pixelFormat
        )
        rawFrameData.append(rawBytes)
        rawFrameIndex.append(rawIndexEntry)
        trimRawFrameArtifactIfNeeded()
    }

    private func recordRawFrameExtractionFailure(_ error: Error) {
        rawExtractionFailures += 1
        lastRawExtractionError = String(describing: error)
    }

    private func rawCaptureMetricsLocked() -> RawVideoCaptureMetrics {
        guard captureRawFrames else {
            return .disabled
        }
        return RawVideoCaptureMetrics(
            mode: .requested,
            extractionAttempts: rawExtractionAttempts,
            extractionFailures: rawExtractionFailures,
            payloadsCaptured: rawPayloadsCaptured,
            artifactFramesRetained: rawFrameIndex.count,
            lastExtractionError: lastRawExtractionError
        )
    }

    private func trimRawFrameArtifactIfNeeded() {
        var trimmed = false
        while rawFrameIndex.count > maxRetainedRawFrameCount,
              let removed = rawFrameIndex.first {
            rawFrameIndex.removeFirst()
            rawFrameDataBaseOffset = removed.byteOffset + removed.byteCount
            trimmed = true
        }
        if trimmed {
            compactRawFrameDataIfNeeded()
        }
    }

    private func trimTimestampSamplesIfNeeded() {
        let overflow = capturedTimestampsNanoseconds.count - maxTimestampSampleCount
        guard overflow > 0 else {
            return
        }
        capturedTimestampsNanoseconds.removeFirst(overflow)
        callbackArrivalTimestampsNanoseconds.removeFirst(
            min(overflow, callbackArrivalTimestampsNanoseconds.count)
        )
    }

    private func compactRawFrameDataIfNeeded() {
        guard rawFrameDataBaseOffset > 0 else {
            return
        }
        let retainedDataStart = min(rawFrameDataBaseOffset, rawFrameData.count)
        let retainedByteCount = rawFrameData.count - retainedDataStart
        guard rawFrameDataBaseOffset >= rawFrameDataCompactionThresholdBytes
            || rawFrameDataBaseOffset > retainedByteCount else {
            return
        }
        rawFrameData = rawFrameData.subdata(in: retainedDataStart..<rawFrameData.count)
        rawFrameIndex = rawFrameIndex.map { entry in
            RecordingVideoFrameIndexEntry(
                sequenceNumber: entry.sequenceNumber,
                timestampNanoseconds: entry.timestampNanoseconds,
                byteOffset: entry.byteOffset - retainedDataStart,
                byteCount: entry.byteCount,
                width: entry.width,
                height: entry.height,
                pixelFormat: entry.pixelFormat
            )
        }
        rawFrameDataBaseOffset = 0
    }

    private func normalizedRawFrameIndexEntry(
        _ entry: RecordingVideoFrameIndexEntry
    ) -> RecordingVideoFrameIndexEntry {
        RecordingVideoFrameIndexEntry(
            sequenceNumber: entry.sequenceNumber,
            timestampNanoseconds: entry.timestampNanoseconds,
            byteOffset: entry.byteOffset - rawFrameDataBaseOffset,
            byteCount: entry.byteCount,
            width: entry.width,
            height: entry.height,
            pixelFormat: entry.pixelFormat
        )
    }
}
#endif
