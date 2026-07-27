// Verifies that video capture frame sources emit deterministic frames and drop stale queue entries.
import Foundation
import Testing

@testable import OpenLolaCore

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
func videoCaptureSessionStartDispatchesOffCallerQueueAndSerializesStop() {
    let workQueue = VideoCaptureSessionWorkQueue(label: "open-lola.video-capture.session.test")
    let workEntered = DispatchSemaphore(value: 0)
    let releaseWork = DispatchSemaphore(value: 0)
    let startReturned = DispatchSemaphore(value: 0)

    DispatchQueue.global(qos: .userInitiated).async {
        workQueue.start {
            workEntered.signal()
            _ = releaseWork.wait(timeout: .now() + .seconds(2))
        }
        startReturned.signal()
    }

    #expect(workEntered.wait(timeout: .now() + .seconds(2)) == .success)
    #expect(startReturned.wait(timeout: .now() + .milliseconds(100)) == .success)

    releaseWork.signal()
    var stopRan = false
    workQueue.stop {
        stopRan = true
    }
    #expect(stopRan)
}

@Test
func videoCaptureReportRejectsInvalidPassEvidence() throws {
    try expectVideoCaptureError(.passIncreasesAudioP99(baseline: 80, video: 81)) {
        $0.audioImpact.videoCallbackP99Microseconds = 81
    }
    try expectVideoCaptureError(.passIncreasesAudioMax(baseline: 95, video: 96)) {
        $0.audioImpact.videoCallbackMaxMicroseconds = 96
    }
    try expectVideoCaptureError(.passChangesAudioPlayoutTarget(baseline: 32, video: 48)) {
        $0.audioImpact.videoPlayoutTargetFrames = 48
    }
    try expectVideoCaptureError(.passWithUnderruns(1)) {
        $0.audioImpact.underruns = 1
    }
    try expectVideoCaptureError(.passWithHiddenAudioImpact) {
        $0.audioImpact.hiddenAudioImpactDetected = true
    }
    try expectVideoCaptureError(.passWithoutAudioImpactProvenance) {
        $0.audioImpact.baselineReportId = nil
    }
    try expectVideoCaptureError(.passWithSyntheticAudioImpact) {
        $0.audioImpact.synthetic = true
    }
    try expectVideoCaptureReportRejectsInvalidProductionPassEvidence()
    try expectVideoCaptureReportRejectsInvalidRawCapturePassEvidence()
}

private func expectVideoCaptureReportRejectsInvalidProductionPassEvidence() throws {
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
}

private func expectVideoCaptureReportRejectsInvalidRawCapturePassEvidence() throws {
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

// swiftlint:disable function_body_length
@Test
func videoCaptureRunConfigurationAcceptsAudioImpactProvenanceAndBoundsCaptureInputs() throws {
    let arguments = [
        "--device-id", "auto",
        "--duration-seconds", "60",
        "--frame-rate", "59.94",
        "--baseline-callback-p99-us", "80",
        "--video-callback-p99-us", "80",
        "--baseline-callback-max-us", "95",
        "--video-callback-max-us", "95",
        "--baseline-playout-target-frames", "32",
        "--video-playout-target-frames", "32",
        "--audio-underruns", "0",
        "--hidden-audio-impact", "false",
        "--audio-baseline-report-id", "m05-route-baseline-required",
        "--output", "/tmp/video-capture.json"
    ]
    let configuration = try VideoCaptureRunConfiguration.parse(arguments)

    #expect(configuration.audioImpact?.baselineReportId == "m05-route-baseline-required")
    #expect(configuration.audioImpact?.synthetic == false)

    #expect(throws: VideoCaptureRunConfigurationError.missingValue("--device-id")) {
        _ = try VideoCaptureRunConfiguration.parse([
            "--device-id", "--duration-seconds",
            "60", "--output", "/tmp/video-capture.json"
        ])
    }
    #expect(throws: VideoCaptureRunConfigurationError.duplicateArgument("--output")) {
        _ = try VideoCaptureRunConfiguration.parse([
            "--device-id", "auto",
            "--duration-seconds", "60",
            "--output", "/tmp/video-a.json",
            "--output", "/tmp/video-b.json"
        ])
    }
    #expect(throws: VideoCaptureRunConfigurationError.argumentExceedsMaximum(
        argument: "--duration-seconds",
        maximum: String(VideoCaptureRunConfiguration.maximumDurationSeconds)
    )) {
        _ = try VideoCaptureRunConfiguration.parse([
            "--device-id", "auto",
            "--duration-seconds", "\(VideoCaptureRunConfiguration.maximumDurationSeconds + 1)",
            "--output", "/tmp/video-capture.json"
        ])
    }
    #expect(throws: VideoCaptureRunConfigurationError.argumentExceedsMaximum(
        argument: "--frame-rate",
        maximum: String(VideoCaptureRunConfiguration.maximumRequestedFrameRate)
    )) {
        _ = try VideoCaptureRunConfiguration.parse([
            "--device-id", "auto",
            "--duration-seconds", "60",
            "--frame-rate", "\(VideoCaptureRunConfiguration.maximumRequestedFrameRate + 1)",
            "--output", "/tmp/video-capture.json"
        ])
    }
}
// swiftlint:enable function_body_length

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

@Test
func productionVideoCaptureEvidencePreservesCodableWireKeys() throws {
    let evidence = atemProductionCaptureEvidence()

    let encoded = try JSONEncoder().encode(evidence)
    let decoded = try JSONDecoder().decode(ProductionVideoCaptureEvidence.self, from: encoded)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

    #expect(decoded == evidence)
    #expect(object["hardwareKind"] as? String == ProductionVideoHardwareKind.atem.rawValue)
    #expect(object["avFoundationDeviceUniqueId"] as? String == "atem-mini-pro-iso-uvc-serial-1234")
    #expect(
        object["desktopVideoSdkStatus"] as? String
            == BlackmagicDesktopVideoSdkStatus.notLinkedOptionalBoundary.rawValue
    )
}

@Test
func videoCaptureReportPreservesCodableWireKeys() throws {
    let report = try passCandidateReport()
    let encoded = try JSONEncoder().encode(report)
    let decoded = try JSONDecoder().decode(VideoCaptureReport.self, from: encoded)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

    #expect(decoded == report)
    #expect(object["id"] as? String == "m08-video-capture-partial-fixture")
    #expect(object["framesCaptured"] as? Int == 90)
    #expect(object["audioImpact"] != nil)
    #expect(object["identity"] == nil)
    #expect(object["capture"] == nil)
    #expect(object["frameMetrics"] == nil)
    #expect(object["runtimeEvidence"] == nil)
    #expect(object["outcome"] == nil)
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
    report.productionCaptureEvidence = atemProductionCaptureEvidence()
    report.rawCapture = RawVideoCaptureMetrics(
        mode: .requested,
        extractionAttempts: 90,
        extractionFailures: 0,
        payloadsCaptured: 90,
        artifactFramesRetained: 1
    )
    report.audioImpact.baselineReportId = "m05-route-baseline-required"
    report.audioImpact.synthetic = false
    report.notes = "Measured ATEM Mini Pro ISO AVFoundation capture with audio baseline comparison."
    return report
}

private func atemProductionCaptureEvidence() -> ProductionVideoCaptureEvidence {
    ProductionVideoCaptureEvidence(
        hardware: .init(
            kind: .atem,
            modelName: "ATEM Mini Pro ISO",
            manufacturer: "Blackmagic Design",
            connectionMethod: .usbUvc
        ),
        discovery: .init(avFoundationVisible: true, deviceUniqueID: "atem-mini-pro-iso-uvc-serial-1234"),
        desktopSDK: .init(
            status: .notLinkedOptionalBoundary,
            decisionNotes: "AVFoundation exposes the ATEM UVC capture path for this measured run.",
            atemReadOnlyControlReport: nil
        )
    )
}

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
                    )
                ]
            )
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
