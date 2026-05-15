import Foundation
#if canImport(CoreMedia)
import CoreMedia
#endif
import Testing

@testable import OpenLolaCore

#if canImport(CoreMedia)
@Test
func avFoundationSampleBufferTimestampPrefersPresentationTimeOverCallbackArrival() {
    let presentationTime = CMTime(value: 123, timescale: 1_000)
    let timestamp = avFoundationPresentationTimestampNanoseconds(
        presentationTime: presentationTime,
        fallbackNanoseconds: 9_000_000_000
    )

    #expect(timestamp == 123_000_000)
}

@Test
func avFoundationSampleBufferTimestampFallsBackForNegativePresentationTime() {
    let presentationTime = CMTime(value: -1, timescale: 1)
    let timestamp = avFoundationPresentationTimestampNanoseconds(
        presentationTime: presentationTime,
        fallbackNanoseconds: 9_000_000_000
    )

    #expect(timestamp == 9_000_000_000)
}
#endif

@Test
func videoCaptureReportFixtureDecodesAndValidates() throws {
    let report = try loadVideoCaptureFixture(named: "video-capture-partial")

    try report.validate()

    #expect(report.source.kind == .testPattern)
    #expect(report.verdict == .partial)
    #expect(report.queue.droppedFrames == 2)
    #expect(report.framesRetained == 1)
    #expect(report.frameInterval?.maxMicroseconds == 33_333.333)
}

@Test
func testPatternCameraSourceEmitsDeterministicFrames() throws {
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
}

@Test
func latestFrameQueueDropsStaleFrames() throws {
    let source = TestPatternCameraSource(width: 640, height: 480, frameIntervalNanoseconds: 1)
    var queue = LatestFrameQueue(maxDepth: 1)

    queue.enqueue(try #require(source.nextFrame()))
    queue.enqueue(try #require(source.nextFrame()))
    queue.enqueue(try #require(source.nextFrame()))

    #expect(queue.droppedFrames == 2)
    #expect(queue.observedMaxDepth == 1)
    #expect(queue.frames.map(\.sequenceNumber) == [2])
}

@Test
func videoCaptureReportRejectsPassWithAudioP99Increase() throws {
    var report = try passCandidateReport()
    report.audioImpact.videoCallbackP99Microseconds = 81

    #expect(throws: VideoCaptureValidationError.passIncreasesAudioP99(
        baseline: 80,
        video: 81
    )) {
        try report.validate()
    }
}

@Test
func videoCaptureReportRejectsPassWithPlayoutTargetChange() throws {
    var report = try passCandidateReport()
    report.audioImpact.videoPlayoutTargetFrames = 48

    #expect(throws: VideoCaptureValidationError.passChangesAudioPlayoutTarget(
        baseline: 32,
        video: 48
    )) {
        try report.validate()
    }
}

@Test
func videoCaptureReportRejectsPassWithoutAVFoundationSource() throws {
    var report = try passCandidateReport()
    report.source.kind = .testPattern
    report.source.permissionStatus = "notRequired"
    report.source.deviceUniqueId = nil

    #expect(throws: VideoCaptureValidationError.passWithoutAVFoundationCapture) {
        try report.validate()
    }
}

@Test
func videoCaptureReportRejectsPassWithoutProductionCaptureEvidence() throws {
    var report = try passCandidateReport()
    report.productionCaptureEvidence = nil

    #expect(throws: VideoCaptureValidationError.passWithoutProductionCaptureEvidence) {
        try report.validate()
    }
}

@Test
func videoCaptureReportRejectsPassWithNonBlackmagicProductionTarget() throws {
    var report = try passCandidateReport()
    report.productionCaptureEvidence?.hardwareKind = .genericCamera

    #expect(throws: VideoCaptureValidationError.passWithoutBlackmagicProductionTarget(.genericCamera)) {
        try report.validate()
    }
}

@Test
func videoCaptureReportRejectsPassWithMismatchedProductionDevice() throws {
    var report = try passCandidateReport()
    report.productionCaptureEvidence?.avFoundationDeviceUniqueId = "different-capture-device"

    #expect(throws: VideoCaptureValidationError.passWithProductionDeviceMismatch(
        expected: "atem-mini-pro-iso-uvc-serial-1234",
        actual: "different-capture-device"
    )) {
        try report.validate()
    }
}

@Test
func videoCaptureReportRejectsPassWhenDesktopVideoSdkIsRequired() throws {
    var report = try passCandidateReport()
    report.productionCaptureEvidence?.desktopVideoSdkStatus = .requiredAfterMeasurement

    #expect(throws: VideoCaptureValidationError.passWithRequiredDesktopVideoSdk) {
        try report.validate()
    }
}

@Test
func videoCaptureReportRejectsPassWithoutFrameIntervalMetrics() throws {
    var report = try passCandidateReport()
    report.frameInterval = nil

    #expect(throws: VideoCaptureValidationError.passWithoutFrameIntervalMetrics) {
        try report.validate()
    }
}

@Test
func videoCaptureReportRejectsPassWithoutProcessCpuMetrics() throws {
    var report = try passCandidateReport()
    report.processCpu = nil

    #expect(throws: VideoCaptureValidationError.passWithoutProcessCpuMetrics) {
        try report.validate()
    }
}

@Test
func videoCaptureReportRejectsPassWithoutProcessMemoryMetrics() throws {
    var report = try passCandidateReport()
    report.processMemory = nil

    #expect(throws: VideoCaptureValidationError.passWithoutProcessMemoryMetrics) {
        try report.validate()
    }
}

@Test
func videoCaptureReportRejectsPassWithoutDeviceUniqueId() throws {
    var report = try passCandidateReport()
    report.source.deviceUniqueId = nil

    #expect(throws: VideoCaptureValidationError.passWithoutDeviceUniqueId) {
        try report.validate()
    }
}

@Test
func avFoundationInventoryReportRoundTripsAndValidates() throws {
    let report = AVFoundationVideoDeviceInventoryReport(
        id: "m08-avfoundation-inventory-test",
        title: "M08 AVFoundation inventory test",
        capturedAt: "2026-05-02T00:00:00Z",
        permissionStatus: .authorized,
        devices: [
            AVFoundationVideoDeviceDescription(
                label: "Blackmagic Design ATEM Mini",
                uniqueId: "atem-mini-uvc",
                modelId: "uvc-model",
                manufacturer: "Blackmagic Design",
                transport: "external",
                sourcePolicy: .blackmagicFirstAvFoundationFallback,
                formats: [
                    AVFoundationVideoFormatDescription(
                        width: 1920,
                        height: 1080,
                        maxFrameRate: 59.94,
                        pixelFormat: "420v"
                    )
                ]
            )
        ],
        blackmagicSdkStatus: .notLinkedOptionalBoundary,
        verdict: .partial,
        notes: "Inventory-only report for test coverage."
    )

    try report.validate()
    let decoded = try AVFoundationVideoDeviceInventoryReport.decode(from: report.prettyJSONData())

    #expect(decoded == report)
    #expect(decoded.devices[0].sourceKind == .avFoundation)
    #expect(decoded.devices[0].isExternalCaptureCandidate)
}

@Test
func avFoundationCaptureDeviceConfigurationUnlocksBeforeSessionOutputGuards() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/VideoCaptureRunner.swift")

    #expect(source.contains("try device.lockForConfiguration()"))
    #expect(source.contains("defer {\n        device.unlockForConfiguration()\n    }"))
    #expect(source.contains("guard session.canAddOutput(output) else"))
    #expect(source.contains("var restoreOnFailure: AVFoundationVideoDeviceRestorePoint?"))
    #expect(source.contains("restoreOnFailure?.restore(logger: AVFoundationVideoCaptureRunner.logger)"))
    #expect(source.contains("captureSession.restoreDevice(logger: Self.logger)"))
    #expect(!source.contains("""
    try device.lockForConfiguration()
    guard session.canAddOutput(output) else
    """))
}

@Test
func avFoundationCaptureWaitUsesThreadSleepInsteadOfCurrentRunLoop() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/VideoCaptureRunner.swift")

    #expect(source.contains("Thread.sleep(forTimeInterval: Double(seconds))"))
    #expect(!source.contains("RunLoop.current.run"))
}

@Test
func avFoundationSampleBufferCollectorDocumentsLockCoverageAndTSANGate() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift")
    let workflow = try readRepositoryText(".github/workflows/release-readiness.yml")
    let lockedProperties = [
        "latestFrameQueue",
        "capturedTimestampsNanoseconds",
        "rawFrameData",
        "rawFrameDataBaseOffset",
        "rawFrameIndex",
        "latestRawCapturedFrame",
        "nextSequenceNumber",
    ]

    #expect(source.contains("@unchecked Sendable"))
    #expect(source.contains("read or written only while stateLock is held"))
    for property in lockedProperties {
        #expect(source.contains(property))
    }
    #expect(workflow.contains("AVFoundation collector thread sanitizer"))
    #expect(workflow.contains("--sanitize=thread"))
    #expect(workflow.contains("VideoCaptureReport"))
}

@Test
func avFoundationRawFrameRetentionAvoidsFrontRemovingDataBlob() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift")

    #expect(!source.contains("rawFrameData.removeSubrange"))
    #expect(source.contains("rawFrameDataBaseOffset = removed.byteOffset + removed.byteCount"))
    #expect(source.contains("rawFrameData.subdata(in: retainedDataStart..<rawFrameData.count)"))
    #expect(source.contains("rawFrameDataCompactionThresholdBytes"))
    #expect(source.contains("compactRawFrameDataIfNeeded"))
    #expect(source.contains("rawFrameDataBaseOffset > retainedByteCount"))
    #expect(source.contains("rawFrameDataBaseOffset = 0"))
}

@Test
func avFoundationRawFrameBytesRejectsInvalidPixelBufferGeometryBeforePointerReads() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift")
    let errorSource = try readRepositoryText("Sources/OpenLolaCore/Video/VideoCaptureRunner.swift")

    #expect(errorSource.contains("invalidPixelBufferLayout(widthBytes: Int, bytesPerRow: Int, height: Int)"))
    #expect(source.contains("guard widthBytes > 0,"))
    #expect(source.contains("bytesPerRow >= widthBytes"))
    #expect(source.contains("height > 0"))
    #expect(source.contains("multipliedReportingOverflow"))
    #expect(source.range(of: "invalidPixelBufferLayout")?.lowerBound ?? source.endIndex
        < source.range(of: "let source = base.assumingMemoryBound(to: UInt8.self)")?.lowerBound ?? source.startIndex)
}

@Test
func avFoundationInventoryClassifiesExternalCaptureNamesAsBlackmagicFirstWithAVFoundationFallback() {
    let atem = AVFoundationVideoDeviceDescription.make(
        label: "ATEM Mini Pro",
        uniqueId: "atem-001",
        formats: []
    )
    let uvc = AVFoundationVideoDeviceDescription.make(
        label: "USB UVC Capture",
        uniqueId: "uvc-001",
        formats: []
    )
    let deckLink = AVFoundationVideoDeviceDescription.make(
        label: "DeckLink Quad HDMI Recorder",
        uniqueId: "decklink-001",
        formats: []
    )

    #expect(atem.sourceKind == .avFoundation)
    #expect(uvc.sourceKind == .avFoundation)
    #expect(deckLink.sourceKind == .avFoundation)
    #expect(atem.sourcePolicy == .blackmagicFirstAvFoundationFallback)
    #expect(uvc.sourcePolicy == .blackmagicFirstAvFoundationFallback)
    #expect(deckLink.sourcePolicy == .blackmagicFirstAvFoundationFallback)
    #expect(atem.isExternalCaptureCandidate)
    #expect(uvc.isExternalCaptureCandidate)
    #expect(deckLink.isExternalCaptureCandidate)
}

@Test
func avFoundationInventoryPrefersBlackmagicCandidateForAutoSelection() throws {
    let generic = AVFoundationVideoDeviceDescription.make(
        label: "FaceTime HD Camera",
        uniqueId: "builtin-001",
        formats: []
    )
    let atem = AVFoundationVideoDeviceDescription.make(
        label: "Blackmagic Design ATEM Mini Pro",
        uniqueId: "atem-001",
        formats: []
    )

    let selected = try #require(preferredAVFoundationVideoDevice(from: [generic, atem]))

    #expect(selected.uniqueId == "atem-001")
    #expect(selected.sourcePolicy == .blackmagicFirstAvFoundationFallback)
}

@Test
func productionVideoCaptureEvidenceDerivesBlackmagicHardwareFromInventory() throws {
    let atem = AVFoundationVideoDeviceDescription.make(
        label: "Blackmagic Design ATEM Mini Pro",
        uniqueId: "atem-001",
        modelId: "uvc-model",
        manufacturer: "unknown",
        transport: "USB",
        formats: []
    )

    let evidence = try #require(productionVideoCaptureEvidence(for: atem))

    #expect(evidence.hardwareKind == .atem)
    #expect(evidence.connectionMethod == .usbUvc)
    #expect(evidence.avFoundationVisible)
    #expect(evidence.avFoundationDeviceUniqueId == "atem-001")
    #expect(evidence.desktopVideoSdkStatus == .notLinkedOptionalBoundary)
}

@Test
func genericCameraDoesNotCreateProductionVideoCaptureEvidence() {
    let generic = AVFoundationVideoDeviceDescription.make(
        label: "FaceTime HD Camera",
        uniqueId: "builtin-001",
        formats: []
    )

    #expect(productionVideoCaptureEvidence(for: generic) == nil)
}

@Test
func videoCaptureReportJSONRoundTripPreservesReport() throws {
    let report = try loadVideoCaptureFixture(named: "video-capture-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try VideoCaptureReport.decode(from: jsonData)

    #expect(decoded == report)
}

@Test
func videoCaptureSyntheticSmokeEmitsPartialReport() throws {
    let report = VideoCaptureSyntheticSmoke.run()

    try report.validate()

    #expect(report.source.kind == .testPattern)
    #expect(report.verdict == .partial)
    #expect(report.queue.policy == .latestFrame)
}

@Test
func videoCaptureRunConfigurationParsesRequiredArguments() throws {
    let configuration = try VideoCaptureRunConfiguration.parse([
        "--device-id", "auto",
        "--duration-seconds", "2",
        "--output", "reports/m08-avfoundation-capture.json",
    ])

    #expect(configuration.deviceUniqueId == nil)
    #expect(configuration.streamID == 100)
    #expect(configuration.durationSeconds == 2)
    #expect(configuration.queueDepth == 1)
    #expect(configuration.requestedFrameRate == 30)
    #expect(configuration.outputPath == "reports/m08-avfoundation-capture.json")
    #expect(configuration.requestedVerdict == .partial)
    #expect(configuration.audioImpact == nil)
    #expect(configuration.productionEvidence == nil)
}

@Test
func videoCaptureRunConfigurationRejectsNonPositiveQueueDepth() {
    #expect(throws: VideoCaptureRunConfigurationError.nonPositiveArgument("--queue-depth")) {
        _ = try VideoCaptureRunConfiguration.parse([
            "--device-id", "camera-uid",
            "--duration-seconds", "2",
            "--queue-depth", "0",
            "--output", "reports/m08-avfoundation-capture.json",
        ])
    }
}

@Test
func videoCaptureRunConfigurationParsesMeasuredAudioImpactAndProductionEvidence() throws {
    let configuration = try VideoCaptureRunConfiguration.parse([
        "--device-id", "auto",
        "--stream-id", "200",
        "--duration-seconds", "3",
        "--queue-depth", "2",
        "--frame-rate", "60",
        "--baseline-callback-p99-us", "80",
        "--video-callback-p99-us", "79",
        "--baseline-callback-max-us", "95",
        "--video-callback-max-us", "94",
        "--baseline-playout-target-frames", "32",
        "--video-playout-target-frames", "32",
        "--audio-underruns", "0",
        "--hidden-audio-impact", "false",
        "--production-hardware", "atem",
        "--production-model", "ATEM Mini Pro ISO",
        "--production-manufacturer", "Blackmagic Design",
        "--production-connection", "usb-uvc",
        "--desktop-video-sdk-status", "not-linked",
        "--desktop-video-sdk-notes", "AVFoundation exposes the UVC capture path.",
        "--verdict", "pass",
        "--output", "reports/m08-avfoundation-capture.json",
    ])

    let audioImpact = try #require(configuration.audioImpact)
    let production = try #require(configuration.productionEvidence)

    #expect(configuration.streamID == 200)
    #expect(configuration.requestedVerdict == .pass)
    #expect(audioImpact.videoCallbackP99Microseconds == 79)
    #expect(audioImpact.videoPlayoutTargetFrames == 32)
    #expect(!audioImpact.hiddenAudioImpactDetected)
    #expect(production.hardwareKind == .atem)
    #expect(production.connectionMethod == .usbUvc)
    #expect(production.desktopVideoSdkStatus == .notLinkedOptionalBoundary)
}

@Test
func videoCaptureRunConfigurationRejectsPartialAudioImpactArguments() {
    #expect(throws: VideoCaptureRunConfigurationError.missingRequiredArgument(
        "--video-callback-p99-us"
    )) {
        _ = try VideoCaptureRunConfiguration.parse([
            "--device-id", "auto",
            "--duration-seconds", "3",
            "--baseline-callback-p99-us", "80",
            "--output", "reports/m08-avfoundation-capture.json",
        ])
    }
}

@Test
func avFoundationCaptureSnapshotBuildsPartialReport() throws {
    let configuration = VideoCaptureRunConfiguration(
        deviceUniqueId: "camera-uid",
        durationSeconds: 2,
        queueDepth: 1,
        requestedFrameRate: 30,
        outputPath: "reports/m08-avfoundation-capture.json"
    )
    let snapshot = AVFoundationCameraSourceSnapshot(
        source: VideoSourceDescription(
            kind: .avFoundation,
            label: "USB UVC Capture",
            deviceUniqueId: "camera-uid",
            permissionStatus: "authorized"
        ),
        format: VideoCaptureFormat(
            width: 1_920,
            height: 1_080,
            nominalFrameRate: 30,
            pixelFormat: "420v"
        ),
        queue: VideoQueueMetrics(
            policy: .latestFrame,
            maxDepth: 1,
            observedMaxDepth: 1,
            droppedFrames: 2
        ),
        framesCaptured: 3,
        framesRetained: 1,
        capturedFrameTimestampsNanoseconds: [
            1_000_000_000,
            1_033_333_333,
            1_066_666_666,
        ],
        retainedFrameTimestampsNanoseconds: [1_000_000_000]
    )

    let report = try AVFoundationVideoCaptureRunner.makeReport(
        snapshot: snapshot,
        configuration: configuration,
        capturedAt: "2026-05-02T00:00:00Z",
        nowNanoseconds: 1_010_000_000,
        processCpu: VideoProcessCpuMetrics(userSeconds: 0.02, systemSeconds: 0.01),
        processMemory: VideoProcessMemoryMetrics(residentPeakBytes: 123_456),
        productionCaptureEvidence: nil
    )

    try report.validate()

    #expect(report.source.kind == .avFoundation)
    #expect(report.verdict == .partial)
    #expect(report.frameAge.maxMicroseconds == 10_000)
    #expect(abs((report.frameInterval?.p50Microseconds ?? 0) - 33_333.333) < 0.001)
    #expect(report.processCpu == VideoProcessCpuMetrics(userSeconds: 0.02, systemSeconds: 0.01))
    #expect(report.processMemory == VideoProcessMemoryMetrics(residentPeakBytes: 123_456))
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
    report.notes = "Measured ATEM Mini Pro ISO AVFoundation capture with audio baseline comparison."
    return report
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

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
