// Verifies that video transport report rejects invalid pass evidence.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func videoTransportReportRejectsInvalidPassEvidence() throws {
    try expectAudioImpactEvidenceRejections()
    try expectVideoPipelineEvidenceRejections()
}

private func expectAudioImpactEvidenceRejections() throws {
    try expectVideoTransportError(.passIncreasesAudioP99(baseline: 80, video: 81)) {
        $0.audioImpact.videoCallbackP99Microseconds = 81
    }
    try expectVideoTransportError(.passIncreasesAudioMax(baseline: 95, video: 96)) {
        $0.audioImpact.videoCallbackMaxMicroseconds = 96
    }
    try expectVideoTransportError(.passChangesAudioPlayoutTarget(baseline: 32, video: 64)) {
        $0.audioImpact.videoPlayoutTargetFrames = 64
    }
    try expectVideoTransportError(.passWithHiddenAudioImpact) {
        $0.audioImpact.hiddenAudioImpactDetected = true
    }
    try expectVideoTransportError(.passWithoutAVSyncTimingMetrics) {
        $0.avSync = nil
    }
    try expectVideoTransportError(.passUsesReliableRetransmission) {
        $0.transport.reliableRetransmission = true
    }
    try expectVideoTransportError(.passWithoutPreAudioDegradation) {
        $0.degradation.triggeredBeforeAudioTargetChange = false
    }
    try expectVideoTransportError(.passWithoutPhysicalRouteEvidence) {
        $0.routeEvidence = nil
    }
    try expectVideoTransportError(.passWithoutFragmentationMetrics) {
        $0.fragmentation = nil
    }
    try expectVideoTransportError(.passWithTransportDrops(frames: 1, packets: 0)) {
        $0.transmitted.framesDroppedBeforeSend = 1
    }
    try expectVideoTransportError(.passWithoutReassemblyMetrics) {
        $0.reassembly = nil
    }
    try expectVideoTransportError(.passWithoutMeasuredAudioPriorityProtection) {
        $0.multiVideo?.audioPriorityProtected = nil
        $0.multiVideo?.audioPriorityEvidence = .notMeasured
    }
    try expectVideoTransportError(.passWithUnprotectedAudioPriority) {
        $0.multiVideo?.audioPriorityProtected = false
    }
}

private func expectVideoPipelineEvidenceRejections() throws {
    try expectVideoTransportError(.passWithOversizedFragmentPayload(
        payloadBytes: 9_001,
        maxPacketBytes: 9_000
    )) {
        $0.fragmentation?.maxPayloadBytesPerFragment = 9_001
    }
    try expectVideoTransportError(.passWithIncompleteReassembly) {
        $0.reassembly?.framesDroppedIncomplete = 1
    }
    try expectVideoTransportError(.passWithoutPhysicalRouteEvidence) {
        $0.routeEvidence?.routeKind = .localhost
    }
    try expectVideoTransportError(.passWithoutPreAudioOrRouteDegradation) {
        $0.degradation.triggeredBeforeAudioOrRouteImpact = false
    }
    try expectVideoTransportError(.passChangesAudioRouteVerdict(
        baseline: .pass,
        videoActive: .partial
    )) {
        $0.routeEvidence?.videoActiveAudioRouteVerdict = .partial
    }
    try expectVideoTransportError(.passAllowsVideoToolboxFrameReordering) {
        $0.transport.mode = .videoToolboxH264
        $0.transport.videoToolboxAvailable = true
        $0.transport.videoToolboxRealtimeMode = true
        $0.transport.frameReorderingAllowed = true
    }
    try expectVideoTransportError(.passWithoutRawOrIntraFrameRouteBaseline) {
        $0.transport.mode = .videoToolboxH264
        $0.transport.videoToolboxAvailable = true
        $0.transport.videoToolboxRealtimeMode = true
        $0.routeEvidence?.rawOrIntraFrameBaselineReportId = nil
        $0.routeEvidence?.rawOrIntraFrameBaselineMode = nil
    }
}

private func passCandidateReport() throws -> VideoTransportReport {
    var report = try loadJSONFixture(
        named: "video-transport-partial",
        fixtureDirectory: "VideoTransportReports",
        decode: VideoTransportReport.decode(from:)
    )
    report.verdict = .pass
    applyPassCandidateTransportEvidence(to: &report)
    applyPassCandidateOutputEvidence(to: &report)
    report.degradation.triggeredBeforeAudioOrRouteImpact = true
    return report
}

private func applyPassCandidateTransportEvidence(to report: inout VideoTransportReport) {
    applyPassCandidateRouteEvidence(to: &report)
    applyPassCandidateFragmentationEvidence(to: &report)
    applyPassCandidateReassemblyEvidence(to: &report)
    report.multiVideo?.audioPriorityProtected = true
    report.multiVideo?.audioPriorityEvidence = .measured
}

private func applyPassCandidateRouteEvidence(to report: inout VideoTransportReport) {
    report.routeEvidence = VideoTransportRouteEvidence(
        routeKind: .directWired,
        routeLabel: "m09-direct-wired-raw-baseline",
        packetCapturePoint: "receiver-en0",
        rawOrIntraFrameBaselineReportId: "m09-direct-wired-raw-pass",
        rawOrIntraFrameBaselineMode: .raw,
        baselineAudioRouteVerdict: .pass,
        videoActiveAudioRouteVerdict: .pass
    )
}

private func applyPassCandidateFragmentationEvidence(to report: inout VideoTransportReport) {
    report.fragmentation = VideoFragmentationMetrics(
        framesFragmented: 3,
        fragmentsSent: 3,
        maxFragmentsPerFrame: 1,
        maxPayloadBytesPerFragment: 9_000
    )
}

private func applyPassCandidateReassemblyEvidence(to report: inout VideoTransportReport) {
    report.reassembly = VideoReassemblyMetrics(
        framesReassembled: 3,
        framesDroppedIncomplete: 0,
        missingFragments: 0,
        lateFragments: 0
    )
}

private func applyPassCandidateOutputEvidence(to report: inout VideoTransportReport) {
    report.receiver.displayedFrames = max(
        0,
        report.receiver.receivedFrames - report.receiver.droppedFrames
    )
    report.renderOutput = passCandidateRenderOutput()
    report.blackmagicOutput = BlackmagicOutputBoundaryReport(
        backend: .blackmagicDeckLink,
        desktopVideoSDK: .linkedDeviceAvailable,
        compileTimeAvailable: true,
        runtimeAvailable: true,
        hardwareDetected: true,
        notes: "Synthetic pass-candidate Blackmagic output evidence for validation tests."
    )
}

private func passCandidatePacketAgeMetrics() -> UdpPcmPacketAgeMetrics {
    UdpPcmPacketAgeMetrics(
        p50Microseconds: 100,
        p95Microseconds: 100,
        p99Microseconds: 100,
        maxMicroseconds: 100
    )
}

private func expectVideoTransportError(
    _ expected: VideoTransportValidationError,
    mutate: (inout VideoTransportReport) throws -> Void
) throws {
    var report = try passCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}
