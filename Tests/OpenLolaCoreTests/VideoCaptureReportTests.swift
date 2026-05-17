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

@Test
func videoCaptureFrameSourcesEmitDeterministicFramesAndDropStaleQueueEntries() throws {
    let source = TestPatternCameraSource(
        width: 1280,
        height: 720,
        frameIntervalNanoseconds: 33_333_333
    )

    let first = try #require(source.nextFrame())
    let second = try #require(source.nextFrame())

    #expect(first.sequenceNumber == 0)
    #expect(second.sequenceNumber == 1)
    #expect(second.timestampNanoseconds - first.timestampNanoseconds == 33_333_333)
    #expect(first.fingerprint == "test-pattern-0-1280x720")

    let queueSource = TestPatternCameraSource(width: 640, height: 480, frameIntervalNanoseconds: 1)
    var queue = LatestFrameQueue(maxDepth: 1)

    queue.enqueue(try #require(queueSource.nextFrame()))
    queue.enqueue(try #require(queueSource.nextFrame()))
    queue.enqueue(try #require(queueSource.nextFrame()))

    #expect(queue.droppedFrames == 2)
    #expect(queue.observedMaxDepth == 1)
    #expect(queue.frames.map(\.sequenceNumber) == [2])
}

@Test
func videoCaptureReportRejectsInvalidPassEvidence() throws {
    try expectVideoCaptureError(.passIncreasesAudioP99(baseline: 80, video: 81)) {
        $0.audioImpact.videoCallbackP99Microseconds = 81
    }
    try expectVideoCaptureError(.passChangesAudioPlayoutTarget(baseline: 32, video: 48)) {
        $0.audioImpact.videoPlayoutTargetFrames = 48
    }
    try expectVideoCaptureError(.passWithoutAVFoundationCapture) {
        $0.source.kind = .testPattern
        $0.source.permissionStatus = "notRequired"
        $0.source.deviceUniqueId = nil
    }
    try expectVideoCaptureError(.passWithoutProductionCaptureEvidence) {
        $0.productionCaptureEvidence = nil
    }
    try expectVideoCaptureError(.passWithoutBlackmagicProductionTarget(.genericCamera)) {
        $0.productionCaptureEvidence?.hardwareKind = .genericCamera
    }
    try expectVideoCaptureError(.passWithProductionDeviceMismatch(
        expected: "atem-mini-pro-iso-uvc-serial-1234",
        actual: "different-capture-device"
    )) {
        $0.productionCaptureEvidence?.avFoundationDeviceUniqueId = "different-capture-device"
    }
    try expectVideoCaptureError(.passWithRequiredDesktopVideoSdk) {
        $0.productionCaptureEvidence?.desktopVideoSdkStatus = .requiredAfterMeasurement
    }
    try expectVideoCaptureError(.passWithoutFrameIntervalMetrics) {
        $0.frameInterval = nil
    }
    try expectVideoCaptureError(.passWithoutProcessCpuMetrics) {
        $0.processCpu = nil
    }
    try expectVideoCaptureError(.passWithoutProcessMemoryMetrics) {
        $0.processMemory = nil
    }
    try expectVideoCaptureError(.passWithoutDeviceUniqueId) {
        $0.source.deviceUniqueId = nil
    }
    try expectVideoCaptureError(.passWithoutRawCaptureEvidence) {
        $0.rawCapture = nil
    }
    try expectVideoCaptureError(.passWithoutRawCaptureEvidence) {
        $0.rawCapture = .disabled
    }
    try expectVideoCaptureError(.passWithRawCaptureFailures(1)) {
        $0.rawCapture = RawVideoCaptureMetrics(
            mode: .requested,
            extractionAttempts: 2,
            extractionFailures: 1,
            payloadsCaptured: 1,
            artifactFramesRetained: 1,
            lastExtractionError: "unsupportedPixelBufferFormat(TEST)"
        )
    }
    try expectVideoCaptureError(.passWithoutRawPayloadEvidence) {
        $0.rawCapture = RawVideoCaptureMetrics(
            mode: .requested,
            extractionAttempts: 1,
            extractionFailures: 0,
            payloadsCaptured: 0,
            artifactFramesRetained: 0
        )
    }
}

@Test
func videoCaptureReportRejectsPrimitiveValidationErrors() throws {
    try expectVideoCaptureError(.emptyField("id")) {
        $0.id = ""
    }
    try expectVideoCaptureError(.nonPositiveField("format.width")) {
        $0.format.width = 0
    }
    try expectVideoCaptureError(.nonFiniteField("durationSeconds")) {
        $0.durationSeconds = .nan
    }
    try expectVideoCaptureError(.negativeField("queue.droppedFrames")) {
        $0.queue.droppedFrames = -1
    }
    try expectVideoCaptureError(.unorderedPacketAge) {
        $0.frameAge = UdpPcmPacketAgeMetrics(
            p50Microseconds: 2,
            p95Microseconds: 1,
            p99Microseconds: 3,
            maxMicroseconds: 4
        )
    }
    try expectVideoCaptureError(.emptyField("productionCaptureEvidence.avFoundationDeviceUniqueId")) {
        $0.productionCaptureEvidence?.avFoundationDeviceUniqueId = ""
    }
    try expectVideoCaptureError(.invalidRawCaptureAccounting) {
        $0.rawCapture = RawVideoCaptureMetrics(
            mode: .requested,
            extractionAttempts: 1,
            extractionFailures: 1,
            payloadsCaptured: 1,
            artifactFramesRetained: 1,
            lastExtractionError: "unsupportedPixelBufferFormat(TEST)"
        )
    }
}

@Test
func videoCaptureAvFoundationInventoryRejectsPrimitiveValidationErrors() throws {
    try expectVideoCaptureInventoryError(.emptyField("devices[0].label")) {
        $0.devices[0].label = ""
    }
    try expectVideoCaptureInventoryError(.nonPositiveField("devices[0].formats[0].width")) {
        $0.devices[0].formats[0].width = 0
    }
    try expectVideoCaptureInventoryError(.nonFiniteField("devices[0].formats[0].maxFrameRate")) {
        $0.devices[0].formats[0].maxFrameRate = .nan
    }
}

private func passCandidateReport() throws -> VideoCaptureReport {
    var report = try loadVideoCaptureFixture(named: "video-capture-partial")
    report.verdict = .pass
    report.source.kind = .avFoundation
    report.source.permissionStatus = "authorized"
    report.source.label = "ATEM Mini Pro ISO USB capture"
    report.source.deviceUniqueId = "atem-mini-pro-iso-uvc-serial-1234"
    report.stream = VideoCaptureStreamMetadata(
        streamID: 100,
        sourceRole: .blackmagicInput,
        timestampBasis: .hostUptimeNanoseconds
    )
    report.framesCaptured = 90
    report.framesRetained = 1
    report.queue.droppedFrames = 89
    report.durationSeconds = 3
    report.processCpu = VideoProcessCpuMetrics(userSeconds: 0.03, systemSeconds: 0.02)
    report.processMemory = VideoProcessMemoryMetrics(residentPeakBytes: 10_000_000)
    report.productionCaptureEvidence = ProductionVideoCaptureEvidence(
        hardwareKind: .atem,
        modelName: "ATEM Mini Pro ISO",
        manufacturer: "Blackmagic Design",
        connectionMethod: .usbUvc,
        avFoundationVisible: true,
        avFoundationDeviceUniqueId: "atem-mini-pro-iso-uvc-serial-1234",
        desktopVideoSdkStatus: .notLinkedOptionalBoundary,
        desktopVideoSdkDecisionNotes: "AVFoundation exposes the ATEM UVC capture path for this measured run.",
        atemReadOnlyControlReport: nil
    )
    report.rawCapture = RawVideoCaptureMetrics(
        mode: .requested,
        extractionAttempts: 90,
        extractionFailures: 0,
        payloadsCaptured: 90,
        artifactFramesRetained: 1
    )
    report.notes = "Measured ATEM Mini Pro ISO AVFoundation capture with audio baseline comparison."
    return report
}

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
    let source = VideoSourceDescription(
        kind: .avFoundation,
        label: "Unit Test Camera",
        deviceUniqueId: "unit-test-camera",
        permissionStatus: "authorized"
    )
    let format = VideoCaptureFormat(width: 2, height: 2, nominalFrameRate: 30, pixelFormat: "BGRA")
    let sampleBuffer = try makeVideoCaptureTestSampleBuffer(width: 2, height: 2)

    let disabledCollector = AVFoundationSampleBufferCollector(
        queueDepth: 1,
        streamID: 100,
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        captureRawFrames: false
    )
    disabledCollector.record(sampleBuffer: sampleBuffer)
    let disabledSnapshot = disabledCollector.snapshot(source: source, format: format)
    #expect(disabledSnapshot.framesCaptured == 1)
    #expect(disabledSnapshot.rawCapture == .disabled)
    #expect(disabledCollector.latestRawFrame() == nil)

    let successCollector = AVFoundationSampleBufferCollector(
        queueDepth: 1,
        streamID: 100,
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        captureRawFrames: true,
        rawFrameExtractor: { _ in Data([1, 2, 3, 4]) }
    )
    successCollector.record(sampleBuffer: sampleBuffer)
    let successSnapshot = successCollector.snapshot(source: source, format: format)
    #expect(successSnapshot.rawCapture == RawVideoCaptureMetrics(
        mode: .requested,
        extractionAttempts: 1,
        extractionFailures: 0,
        payloadsCaptured: 1,
        artifactFramesRetained: 1
    ))
    #expect(successCollector.latestRawFrame()?.payload == Data([1, 2, 3, 4]))

    let failureCollector = AVFoundationSampleBufferCollector(
        queueDepth: 1,
        streamID: 100,
        frameRate: VideoFrameRate(numerator: 30, denominator: 1),
        captureRawFrames: true,
        rawFrameExtractor: { _ in
            throw VideoCaptureProbeError.unsupportedPixelBufferFormat("TEST")
        }
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
#endif

private func videoInventoryCandidateReport() -> AVFoundationVideoDeviceInventoryReport {
    AVFoundationVideoDeviceInventoryReport(
        id: "m08-avfoundation-video-device-inventory",
        title: "AVFoundation video device inventory",
        capturedAt: "2026-05-16T00:00:00Z",
        permissionStatus: .authorized,
        devices: [
            AVFoundationVideoDeviceDescription(
                label: "ATEM Mini Pro ISO",
                uniqueId: "atem-mini-pro-iso-uvc-serial-1234",
                modelId: "atem-mini-pro-iso",
                manufacturer: "Blackmagic Design",
                transport: "USB",
                sourcePolicy: .blackmagicFirstAvFoundationFallback,
                formats: [
                    AVFoundationVideoFormatDescription(
                        width: 1920,
                        height: 1080,
                        maxFrameRate: 59.94,
                        pixelFormat: "2vuy"
                    ),
                ]
            ),
        ],
        blackmagicSdkStatus: .notLinkedOptionalBoundary,
        verdict: .partial,
        notes: "Unit-test AVFoundation inventory report."
    )
}

private func expectVideoCaptureError(
    _ expected: VideoCaptureValidationError,
    mutate: (inout VideoCaptureReport) throws -> Void
) throws {
    var report = try passCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func expectVideoCaptureInventoryError(
    _ expected: VideoCaptureValidationError,
    mutate: (inout AVFoundationVideoDeviceInventoryReport) throws -> Void
) throws {
    var report = videoInventoryCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func loadVideoCaptureFixture(named name: String) throws -> VideoCaptureReport {
    let url = try videoCaptureFixtureURL(named: name)
    return try VideoCaptureReport.decode(from: Data(contentsOf: url))
}

private func videoCaptureFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "VideoCaptureReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "VideoCaptureReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}

#if canImport(AVFoundation)
private func makeVideoCaptureTestPixelBuffer(
    width: Int,
    height: Int,
    pixelFormat: OSType
) throws -> CVPixelBuffer {
    let attributes = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
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

private func makeVideoCaptureTestSampleBuffer(width: Int, height: Int) throws -> CMSampleBuffer {
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
