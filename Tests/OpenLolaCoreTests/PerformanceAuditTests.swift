// Verifies that real-time packet handoff publishes the M12 performance counters.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func realtimePacketHandoffPublishesM12PerformanceCounters() throws {
    var handoff = try RealtimeAudioPacketHandoff(configuration: performanceAuditHandoffConfiguration())

    #expect(handoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 100) == .stored)
    let capturedPacket = try handoff.sendNextPacket()
    let packet = try #require(capturedPacket)
    #expect(try handoff.receive(packet) == .queued)
    _ = handoff.renderCallback()
    _ = handoff.renderCallback()

    #expect(handoff.metrics.maximumCaptureRingOccupancyBlocks >= 1)
    #expect(handoff.metrics.maximumPlayoutQueueDepthBlocks >= 1)
    #expect(handoff.metrics.packetizationDuration.sampleCount == 1)
    #expect(handoff.metrics.depacketizationDuration.sampleCount == 1)
}

@Test
func performanceCounterRecordComputesPercentilesFromSamples() throws {
    var counter = PerformanceCounterSummary.empty

    counter.record(1)
    counter.record(100)
    counter.record(2)

    #expect(counter.sampleCount == 3)
    #expect(counter.p50Microseconds == 2)
    #expect(counter.p95Microseconds == 100)
    #expect(counter.p99Microseconds == 100)
    #expect(counter.maxMicroseconds == 100)
    #expect(counter.rawSamplesMicroseconds == [1, 100, 2])

    let encoded = try JSONEncoder().encode(counter)
    let encodedObject = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    #expect(encodedObject["recordedSamplesMicroseconds"] == nil)
}

@Test
func performanceCounterReportsInvalidSamplesWithoutClampingThemIntoPercentiles() {
    let counter = PerformanceCounterSummary.fromSamples([-10, 1, .nan, 100, 2])

    #expect(counter.sampleCount == 3)
    #expect(counter.invalidSampleCount == 2)
    #expect(counter.p50Microseconds == 2)
    #expect(counter.p95Microseconds == 100)
    #expect(counter.p99Microseconds == 100)
    #expect(counter.maxMicroseconds == 100)
}

@Test
func performanceAuditRejectsInvalidCounterSamples() throws {
    var report = try performanceAuditPassCandidate()
    report.counters.packetizationDuration = .fromSamples([1, -1, 2])

    #expect(throws: PerformanceAuditValidationError.invalidCounterSamples(
        field: "counters.packetizationDuration",
        count: 1
    )) {
        try report.validate()
    }
}

@Test
func performanceAuditRejectsInvalidPassEvidence() throws {
    try expectPerformanceAuditError(.passWithRealtimeViolation(
        surface: .audioCallback,
        field: "allocationWarnings"
    )) {
        let index = try #require($0.hotPaths.firstIndex { $0.surface == .audioCallback })
        $0.hotPaths[index].allocationWarnings = 1
    }
    try expectPerformanceAuditError(.passWithUndocumentedCopy("audio-packet-boundary-copy")) {
        let index = try #require($0.copyAudit.firstIndex { $0.id == "audio-packet-boundary-copy" })
        $0.copyAudit[index].documentation = ""
    }
    try expectPerformanceAuditError(.passWithAudioBlockingWorker(.videoCapture)) {
        let index = try #require($0.workerAssignments.firstIndex { $0.role == .videoCapture })
        $0.workerAssignments[index].canBlockAudioCriticalQueue = true
    }
    try expectPerformanceAuditError(.passWithAppleSiliconPolicyViolation("rosettaTranslated")) {
        $0.appleSiliconPolicy.rosettaTranslated = true
    }
    try expectPerformanceAuditError(.passWithAppleSiliconPolicyViolation("powerMode")) {
        $0.processContext.powerMode = "Low Power Mode"
    }
    try expectPerformanceAuditError(.passWithoutRawBaseline(.videoToolbox)) {
        let index = try #require($0.accelerationDecisions.firstIndex { $0.option == .videoToolbox })
        $0.accelerationDecisions[index].rawBaselineReportId = nil
    }
    try expectPerformanceAuditError(.passWithoutSettingsTier(.experimental)) {
        $0.profileReports.removeAll { $0.settingsTier == .experimental }
    }
}

private func performanceAuditPassCandidate() throws -> PerformanceAuditReport {
    var report = try PerformanceAuditSyntheticSmoke.run()
    applyPerformanceAuditPassIdentity(to: &report)
    applyPerformanceAuditRealtimePassEvidence(to: &report)
    applyPerformanceAuditPassAccelerationEvidence(to: &report)
    applyPerformanceAuditPassProfileEvidence(to: &report)
    report.verdict = .pass
    report.notes = "Measured pass candidate for Apple Silicon performance validator behavior."
    try report.validate()
    return report
}

private func applyPerformanceAuditPassIdentity(to report: inout PerformanceAuditReport) {
    report.id = "m12-apple-silicon-performance-pass-candidate"
    report.title = "M12 Apple Silicon performance pass candidate"
    report.runMode = .measured
    report.evidenceKind = .physicalAppleSiliconRig
    report.hardware = HardwareIdentity(
        referenceMac: "Mac16,12 Apple Silicon reference host",
        audioInterface: "RME MADIface USB",
        osVersion: "macOS 15.5",
        driverVersion: "RME 4.17"
    )
    report.processContext = PerformanceProcessContext(
        machineModel: "Mac16,12",
        chipName: "Apple M4",
        osVersion: "macOS 15.5",
        processName: "open-lola",
        thermalState: "nominal",
        powerMode: "AC power"
    )
}

private func applyPerformanceAuditRealtimePassEvidence(to report: inout PerformanceAuditReport) {
    for index in report.hotPaths.indices {
        report.hotPaths[index].allocationWarnings = 0
        report.hotPaths[index].blockingIOWarnings = 0
        report.hotPaths[index].loggingWarnings = 0
        report.hotPaths[index].lockWarnings = 0
        report.hotPaths[index].dynamicConfigurationAfterStart = false
        report.hotPaths[index].usesMonotonicClock = true
    }
    for index in report.copyAudit.indices {
        report.copyAudit[index].measuredCostMicroseconds = 12
        report.copyAudit[index].documentation = "Measured and documented pass-candidate copy boundary."
        if report.copyAudit[index].avoidable {
            report.copyAudit[index].removed = true
        }
    }
    for index in report.workerAssignments.indices {
        report.workerAssignments[index].canBlockAudioCriticalQueue = false
        report.workerAssignments[index].isolatedFromAudioCallback =
            report.workerAssignments[index].role != .audioCallback
    }
    report.counters.ringDropCount = 0
    report.counters.audioDropCount = 0
    report.counters.allocationWarningCount = 0
}

private func applyPerformanceAuditPassAccelerationEvidence(to report: inout PerformanceAuditReport) {
    report.accelerationDecisions = [
        PerformanceAccelerationDecision(
            option: .rawLowCopyBaseline,
            benchmarked: true,
            rawBaselineReportId: "m12-raw-low-copy-baseline-pass",
            measuredCostMicroseconds: 80,
            verdict: .pass,
            notes: "Measured raw/low-copy baseline."
        ),
        PerformanceAccelerationDecision(
            option: .metal,
            benchmarked: true,
            rawBaselineReportId: "m12-raw-low-copy-baseline-pass",
            measuredCostMicroseconds: 70,
            verdict: .pass,
            notes: "Measured after raw baseline."
        ),
        PerformanceAccelerationDecision(
            option: .videoToolbox,
            benchmarked: true,
            rawBaselineReportId: "m12-raw-low-copy-baseline-pass",
            measuredCostMicroseconds: 65,
            verdict: .pass,
            notes: "Measured after raw baseline with realtime settings."
        )
    ]
}

private func applyPerformanceAuditPassProfileEvidence(to report: inout PerformanceAuditReport) {
    for index in report.profileReports.indices {
        report.profileReports[index].reportId = "m12-\(report.profileReports[index].settingsTier.rawValue)-profile-pass"
        report.profileReports[index].verdict = .pass
        report.profileReports[index].measured = true
        report.profileReports[index].physicalEvidence = true
    }
}

private func expectPerformanceAuditError(
    _ expected: PerformanceAuditValidationError,
    mutate: (inout PerformanceAuditReport) throws -> Void
) throws {
    var report = try performanceAuditPassCandidate()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func performanceAuditHandoffConfiguration() -> RealtimeAudioEngineConfiguration {
    standardRealtimeAudioEngineConfiguration(
        inputDeviceUID: "synthetic-input",
        outputDeviceUID: "synthetic-output"
    )
}
