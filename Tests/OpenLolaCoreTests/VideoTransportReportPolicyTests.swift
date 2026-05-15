import Foundation
import Testing

@testable import OpenLolaCore

@Test
func videoTransportReportRejectsPassWithAudioP99Increase() throws {
    var report = try passCandidateReport()
    report.audioImpact.videoCallbackP99Microseconds = 81

    #expect(throws: VideoTransportValidationError.passIncreasesAudioP99(
        baseline: 80,
        video: 81
    )) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithAudioMaxIncrease() throws {
    var report = try passCandidateReport()
    report.audioImpact.videoCallbackMaxMicroseconds = 96

    #expect(throws: VideoTransportValidationError.passIncreasesAudioMax(
        baseline: 95,
        video: 96
    )) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithAudioPlayoutTargetChange() throws {
    var report = try passCandidateReport()
    report.audioImpact.videoPlayoutTargetFrames = 64

    #expect(throws: VideoTransportValidationError.passChangesAudioPlayoutTarget(
        baseline: 32,
        video: 64
    )) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithHiddenAudioImpact() throws {
    var report = try passCandidateReport()
    report.audioImpact.hiddenAudioImpactDetected = true

    #expect(throws: VideoTransportValidationError.passWithHiddenAudioImpact) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithoutAVSyncTimingMetrics() throws {
    var report = try passCandidateReport()
    report.avSync = nil

    #expect(throws: VideoTransportValidationError.passWithoutAVSyncTimingMetrics) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithReliableRetransmission() throws {
    var report = try passCandidateReport()
    report.transport.reliableRetransmission = true

    #expect(throws: VideoTransportValidationError.passUsesReliableRetransmission) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithoutDegradationBeforeAudioChange() throws {
    var report = try passCandidateReport()
    report.degradation.triggeredBeforeAudioTargetChange = false

    #expect(throws: VideoTransportValidationError.passWithoutPreAudioDegradation) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithoutPhysicalRouteEvidence() throws {
    var report = try passCandidateReport()
    report.routeEvidence = nil

    #expect(throws: VideoTransportValidationError.passWithoutPhysicalRouteEvidence) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithoutFragmentationMetrics() throws {
    var report = try passCandidateReport()
    report.fragmentation = nil

    #expect(throws: VideoTransportValidationError.passWithoutFragmentationMetrics) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithoutReassemblyMetrics() throws {
    var report = try passCandidateReport()
    report.reassembly = nil

    #expect(throws: VideoTransportValidationError.passWithoutReassemblyMetrics) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithOversizedFragmentPayload() throws {
    var report = try passCandidateReport()
    report.fragmentation?.maxPayloadBytesPerFragment = 9_001

    #expect(throws: VideoTransportValidationError.passWithOversizedFragmentPayload(
        payloadBytes: 9_001,
        maxPacketBytes: 9_000
    )) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithIncompleteReassembly() throws {
    var report = try passCandidateReport()
    report.reassembly?.framesDroppedIncomplete = 1

    #expect(throws: VideoTransportValidationError.passWithIncompleteReassembly) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithLocalhostRouteEvidence() throws {
    var report = try passCandidateReport()
    report.routeEvidence?.routeKind = .localhost

    #expect(throws: VideoTransportValidationError.passWithoutPhysicalRouteEvidence) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithoutDegradationBeforeRouteOrAudioImpact() throws {
    var report = try passCandidateReport()
    report.degradation.triggeredBeforeAudioOrRouteImpact = false

    #expect(throws: VideoTransportValidationError.passWithoutPreAudioOrRouteDegradation) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsPassWithAudioRouteVerdictChange() throws {
    var report = try passCandidateReport()
    report.routeEvidence?.videoActiveAudioRouteVerdict = .partial

    #expect(throws: VideoTransportValidationError.passChangesAudioRouteVerdict(
        baseline: .pass,
        videoActive: .partial
    )) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsVideoToolboxPassWithFrameReordering() throws {
    var report = try passCandidateReport()
    report.transport.mode = .videoToolboxH264
    report.transport.videoToolboxAvailable = true
    report.transport.videoToolboxRealtimeMode = true
    report.transport.frameReorderingAllowed = true

    #expect(throws: VideoTransportValidationError.passAllowsVideoToolboxFrameReordering) {
        try report.validate()
    }
}

@Test
func videoTransportReportRejectsVideoToolboxPassWithoutRawRouteBaseline() throws {
    var report = try passCandidateReport()
    report.transport.mode = .videoToolboxH264
    report.transport.videoToolboxAvailable = true
    report.transport.videoToolboxRealtimeMode = true
    report.routeEvidence?.rawOrIntraFrameBaselineReportId = nil
    report.routeEvidence?.rawOrIntraFrameBaselineMode = nil

    #expect(throws: VideoTransportValidationError.passWithoutRawOrIntraFrameRouteBaseline) {
        try report.validate()
    }
}

@Test
func videoTransportReportJSONRoundTripPreservesReport() throws {
    let report = try loadVideoTransportFixture(named: "video-transport-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try VideoTransportReport.decode(from: jsonData)

    #expect(decoded == report)
}

private func passCandidateReport() throws -> VideoTransportReport {
    var report = try loadVideoTransportFixture(named: "video-transport-partial")
    report.verdict = .pass
    report.routeEvidence = VideoTransportRouteEvidence(
        routeKind: .directWired,
        routeLabel: "m09-direct-wired-raw-baseline",
        packetCapturePoint: "receiver-en0",
        rawOrIntraFrameBaselineReportId: "m09-direct-wired-raw-pass",
        rawOrIntraFrameBaselineMode: .raw,
        baselineAudioRouteVerdict: .pass,
        videoActiveAudioRouteVerdict: .pass
    )
    report.fragmentation = VideoFragmentationMetrics(
        framesFragmented: 3,
        fragmentsSent: 3,
        maxFragmentsPerFrame: 1,
        maxPayloadBytesPerFragment: 9_000
    )
    report.reassembly = VideoReassemblyMetrics(
        framesReassembled: 3,
        framesDroppedIncomplete: 0,
        missingFragments: 0,
        lateFragments: 0
    )
    report.renderOutput = VideoRenderOutputMetrics(
        backend: .blackmagicDeckLink,
        pacingPolicy: .latestOnly,
        framesSubmitted: 3,
        framesRendered: 3,
        framesOutput: 3,
        framesDroppedLate: 0,
        framesDroppedBackpressure: 0,
        framesDroppedContinuity: 0,
        observedQueueDepth: 1,
        receiveToReassembly: UdpPcmPacketAgeMetrics(
            p50Microseconds: 100,
            p95Microseconds: 100,
            p99Microseconds: 100,
            maxMicroseconds: 100
        ),
        reassemblyToRender: UdpPcmPacketAgeMetrics(
            p50Microseconds: 100,
            p95Microseconds: 100,
            p99Microseconds: 100,
            maxMicroseconds: 100
        ),
        renderToOutput: UdpPcmPacketAgeMetrics(
            p50Microseconds: 100,
            p95Microseconds: 100,
            p99Microseconds: 100,
            maxMicroseconds: 100
        )
    )
    report.blackmagicOutput = BlackmagicOutputBoundaryReport(
        backend: .blackmagicDeckLink,
        desktopVideoSDK: .linkedDeviceAvailable,
        compileTimeAvailable: true,
        runtimeAvailable: true,
        hardwareDetected: true,
        notes: "Synthetic pass-candidate Blackmagic output evidence for validation tests."
    )
    report.degradation.triggeredBeforeAudioOrRouteImpact = true
    return report
}

private func loadVideoTransportFixture(named name: String) throws -> VideoTransportReport {
    let url = try videoTransportFixtureURL(named: name)
    return try VideoTransportReport.decode(from: Data(contentsOf: url))
}

private func videoTransportFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "VideoTransportReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "VideoTransportReports/invalid"
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
