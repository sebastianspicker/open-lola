// Shared video capture report tests helpers keep related tests deterministic and focused on their contract.
import Foundation
#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreVideo
#endif
#if canImport(CoreMedia)
import CoreMedia
#endif
import Testing

@testable import OpenLolaCore

#if canImport(CoreMedia)

@Test
func avFoundationSampleBufferTimestampPrefersPresentationTimeAndFallsBackWhenInvalid() {
    let presentationTime = CMTime(value: 123, timescale: 1_000)
    let timestamp = avFoundationPresentationTimestampNanoseconds(
        presentationTime: presentationTime,
        fallbackNanoseconds: 9_000_000_000
    )

    #expect(timestamp == 123_000_000)

    let fallbackTimestamp = avFoundationPresentationTimestampNanoseconds(
        presentationTime: CMTime(value: -1, timescale: 1),
        fallbackNanoseconds: 9_000_000_000
    )

    #expect(fallbackTimestamp == 9_000_000_000)
}
#endif

#if canImport(AVFoundation)
@Test
func avFoundationRawFrameExtractionReportsLockAndFormatFailures() throws {
    let bgraBuffer = try makeVideoCaptureTestPixelBuffer(
        width: 2,
        height: 2,
        pixelFormat: kCVPixelFormatType_32BGRA
    )
    #expect(throws: VideoCaptureProbeError.pixelBufferLockFailed(kCVReturnInvalidArgument)) {
        _ = try rawFrameBytes(
            from: bgraBuffer,
            lockBaseAddress: { _, _ in kCVReturnInvalidArgument },
            unlockBaseAddress: { _, _ in kCVReturnSuccess }
        )
    }

    let unsupportedBuffer = try makeVideoCaptureTestPixelBuffer(
        width: 2,
        height: 2,
        pixelFormat: kCVPixelFormatType_32ARGB
    )
    #expect(throws: VideoCaptureProbeError.unsupportedPixelBufferFormat(
        videoCaptureFourCCString(kCVPixelFormatType_32ARGB)
    )) {
        _ = try rawFrameBytes(from: unsupportedBuffer)
    }
}

@Test
func avFoundationRawCaptureMetricsDistinguishDisabledSuccessAndFailure() throws {
    let inputs = try makeVideoCaptureTestInputs()
    let disabledCollector = AVFoundationSampleBufferCollector(
        stream: AVFoundationSampleBufferStreamConfiguration(queueDepth: 1, streamID: 100, frameRate: VideoFrameRate(numerator: 30, denominator: 1)),
        rawCapture: AVFoundationSampleBufferRawCaptureConfiguration(captureRawFrames: false)
    )
    disabledCollector.record(sampleBuffer: inputs.sampleBuffer)
    let disabledSnapshot = disabledCollector.snapshot(source: inputs.source, format: inputs.format)
    #expect(disabledSnapshot.framesCaptured == 1)
    #expect(disabledSnapshot.rawCapture == .disabled)
    #expect(disabledCollector.latestRawFrame() == nil)

    let successCollector = AVFoundationSampleBufferCollector(
        stream: AVFoundationSampleBufferStreamConfiguration(queueDepth: 1, streamID: 100, frameRate: VideoFrameRate(numerator: 30, denominator: 1)),
        rawCapture: AVFoundationSampleBufferRawCaptureConfiguration(captureRawFrames: true, rawFrameExtractor: { _ in Data([1, 2, 3, 4]) })
    )
    successCollector.record(sampleBuffer: inputs.sampleBuffer)
    let successSnapshot = successCollector.snapshot(source: inputs.source, format: inputs.format)
    #expect(successSnapshot.rawCapture == RawVideoCaptureMetrics(
        mode: .requested,
        extractionAttempts: 1,
        extractionFailures: 0,
        payloadsCaptured: 1,
        artifactFramesRetained: 1
    ))
    #expect(successCollector.latestRawFrame()?.payload == Data([1, 2, 3, 4]))

    expectRawCaptureFailure(
        source: inputs.source,
        format: inputs.format,
        sampleBuffer: inputs.sampleBuffer
    )
}

private struct VideoCaptureTestInputs {
    let source: VideoSourceDescription
    let format: VideoCaptureFormat
    let sampleBuffer: CMSampleBuffer
}

private func makeVideoCaptureTestInputs() throws -> VideoCaptureTestInputs {
    VideoCaptureTestInputs(
        source: VideoSourceDescription(
            kind: .avFoundation,
            label: "Unit Test Camera",
        deviceUniqueId: "unit-test-camera",
        permissionStatus: "authorized"
        ),
        format: VideoCaptureFormat(width: 2, height: 2, nominalFrameRate: 30, pixelFormat: "BGRA"),
        sampleBuffer: try makeVideoCaptureTestSampleBuffer(width: 2, height: 2)
    )
}

private func expectRawCaptureFailure(
source: VideoSourceDescription,
format: VideoCaptureFormat,
sampleBuffer: CMSampleBuffer
) {
let failureCollector = AVFoundationSampleBufferCollector(
stream: AVFoundationSampleBufferStreamConfiguration(queueDepth: 1, streamID: 100, frameRate: VideoFrameRate(numerator: 30, denominator: 1)),
rawCapture: AVFoundationSampleBufferRawCaptureConfiguration(captureRawFrames: true, rawFrameExtractor: { _ in
throw VideoCaptureProbeError.unsupportedPixelBufferFormat("TEST")
        })
    )
    failureCollector.record(sampleBuffer: sampleBuffer)
    let failureSnapshot = failureCollector.snapshot(source: source, format: format)
    #expect(failureSnapshot.framesCaptured == 1)
    #expect(failureSnapshot.rawCapture.extractionAttempts == 1)
    #expect(failureSnapshot.rawCapture.extractionFailures == 1)
    #expect(failureSnapshot.rawCapture.payloadsCaptured == 0)
#expect(failureSnapshot.rawCapture.artifactFramesRetained == 0)
#expect(failureSnapshot.rawCapture.lastExtractionError == "unsupportedPixelBufferFormat(\"TEST\")")
#expect(failureCollector.latestRawFrame() == nil)
}

@Test
func avFoundationSampleBufferCollectorBoundsTimestampSamplesWithoutLosingFrameCount() throws {
    let inputs = try makeVideoCaptureTestInputs()
    let collector = AVFoundationSampleBufferCollector(
        stream: AVFoundationSampleBufferStreamConfiguration(queueDepth: 1, streamID: 100, frameRate: VideoFrameRate(numerator: 30, denominator: 1)),
        rawCapture: AVFoundationSampleBufferRawCaptureConfiguration(maxTimestampSampleCount: 3)
    )

    for _ in 0..<5 {
        collector.record(sampleBuffer: inputs.sampleBuffer)
    }

    let snapshot = collector.snapshot(source: inputs.source, format: inputs.format)
    #expect(snapshot.framesCaptured == 5)
    #expect(snapshot.framesRetained == 1)
    #expect(snapshot.capturedFrameTimestampsNanoseconds.count == 3)
    #expect(snapshot.callbackArrivalTimestampsNanoseconds.count == 3)
}
#endif

#if canImport(AVFoundation)
private func makeVideoCaptureTestPixelBuffer(
    width: Int,
    height: Int,
    pixelFormat: OSType
) throws -> CVPixelBuffer {
    let attributes = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ] as CFDictionary
    var pixelBuffer: CVPixelBuffer?
    let pixelStatus = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        pixelFormat,
        attributes,
        &pixelBuffer
    )
    guard pixelStatus == kCVReturnSuccess, let pixelBuffer else {
        throw NSError(domain: "VideoCaptureReportTests", code: Int(pixelStatus))
    }
    return pixelBuffer
}

func makeVideoCaptureTestSampleBuffer(width: Int, height: Int) throws -> CMSampleBuffer {
    let pixelBuffer = try makeVideoCaptureTestPixelBuffer(
        width: width,
        height: height,
        pixelFormat: kCVPixelFormatType_32BGRA
    )

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
        memset(baseAddress, 0x7f, CVPixelBufferGetDataSize(pixelBuffer))
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

    var formatDescription: CMVideoFormatDescription?
    let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescriptionOut: &formatDescription
    )
    guard formatStatus == noErr, let formatDescription else {
        throw NSError(domain: "VideoCaptureReportTests", code: Int(formatStatus))
    }

    var timing = CMSampleTimingInfo(
        duration: CMTime(value: 1, timescale: 30),
        presentationTimeStamp: CMTime(value: 1, timescale: 30),
        decodeTimeStamp: .invalid
    )
    var sampleBuffer: CMSampleBuffer?
    let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescription: formatDescription,
        sampleTiming: &timing,
        sampleBufferOut: &sampleBuffer
    )
    guard sampleStatus == noErr, let sampleBuffer else {
        throw NSError(domain: "VideoCaptureReportTests", code: Int(sampleStatus))
    }
    return sampleBuffer
}
#endif
