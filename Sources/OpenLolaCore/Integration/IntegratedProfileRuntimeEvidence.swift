import Foundation

public struct IntegratedProfileRuntimeEvidence: Sendable {
    public var fastestAudio: LatencyBenchmarkReport?
    public var integratedAv: IntegratedAvReport?
    public var lightingControl: LightingFixtureGateReport?

    public init(
        fastestAudio: LatencyBenchmarkReport? = nil,
        integratedAv: IntegratedAvReport? = nil,
        lightingControl: LightingFixtureGateReport? = nil
    ) {
        self.fastestAudio = fastestAudio
        self.integratedAv = integratedAv
        self.lightingControl = lightingControl
    }
}

func integratedProfileReportApplyingRuntimeEvidence(
    _ report: IntegratedProfileReport,
    configuration: IntegratedProfileRunConfiguration,
    evidence: IntegratedProfileRuntimeEvidence
) -> IntegratedProfileReport {
    var report = report
    guard evidence.fastestAudio != nil
        || evidence.integratedAv != nil
        || evidence.lightingControl != nil else {
        return report
    }

    if integratedProfileRuntimeEvidenceIsMeasured(evidence) {
        report.runMode = .measured
    }
    applyProfileOptions(to: &report, configuration: configuration, evidence: evidence)
    applySubordinateEvidence(to: &report, evidence: evidence)
    applyBenchmarkRows(to: &report, configuration: configuration, evidence: evidence)
    report.notes = "Measured partial M12 aggregate from supplied runtime reports. Physical PASS still requires accepted audio, video, lighting/control, and benchmark evidence."
    return report
}

private func applyProfileOptions(
    to report: inout IntegratedProfileReport,
    configuration: IntegratedProfileRunConfiguration,
    evidence: IntegratedProfileRuntimeEvidence
) {
    if let fastestAudio = evidence.fastestAudio {
        applyFastestAudioProfileOption(to: &report, fastestAudio: fastestAudio)
    }
    if let integratedAv = evidence.integratedAv {
        applyIntegratedAvProfileOption(to: &report, integratedAv: integratedAv)
    }
    if let lightingControl = evidence.lightingControl {
        applyLightingControlProfileOption(to: &report, lightingControl: lightingControl)
    }
    if let integratedAv = evidence.integratedAv,
       let lightingControl = evidence.lightingControl {
        applyFullMatrixProfileOption(
            to: &report,
            configuration: configuration,
            integratedAv: integratedAv,
            lightingControl: lightingControl
        )
    }
}

private func applyFastestAudioProfileOption(
    to report: inout IntegratedProfileReport,
    fastestAudio: LatencyBenchmarkReport
) {
    mutateOption(
        IntegratedProfileOptionMutation(
            label: .fastestAudio,
            sourceReportId: fastestAudio.id,
            costReportId: fastestAudio.id,
            latencyCostMicroseconds: 0,
            verdict: fastestAudio.verdict,
            notes: "Fastest-audio profile derived from supplied latency benchmark report."
        ),
        in: &report
    )
}

private func applyIntegratedAvProfileOption(
    to report: inout IntegratedProfileReport,
    integratedAv: IntegratedAvReport
) {
    mutateOption(
        IntegratedProfileOptionMutation(
            label: .audioVideo,
            sourceReportId: integratedAv.id,
            costReportId: integratedAv.id,
            latencyCostMicroseconds: integratedAvProfileLatencyCost(integratedAv),
            verdict: integratedAv.verdict,
            notes: "Audio-video profile derived from supplied integrated A/V report."
        ),
        in: &report
    )
}

private func applyLightingControlProfileOption(
    to report: inout IntegratedProfileReport,
    lightingControl: LightingFixtureGateReport
) {
    mutateOption(
        IntegratedProfileOptionMutation(
            label: .audioLighting,
            sourceReportId: lightingControl.id,
            costReportId: lightingControl.id,
            latencyCostMicroseconds: lightingControlProfileLatencyCost(lightingControl),
            verdict: lightingControl.verdict,
            notes: "Audio-lighting profile derived from supplied lighting fixture gate report."
        ),
        in: &report
    )
}

private func applyFullMatrixProfileOption(
    to report: inout IntegratedProfileReport,
    configuration: IntegratedProfileRunConfiguration,
    integratedAv: IntegratedAvReport,
    lightingControl: LightingFixtureGateReport
) {
    let matrixReportId = configuration.matrixReportIds[.audioVideoControl]
        ?? "m12-full-matrix-required"
    mutateOption(
        IntegratedProfileOptionMutation(
            label: .audioVideoLighting,
            sourceReportId: matrixReportId,
            costReportId: matrixReportId,
            latencyCostMicroseconds: integratedAvProfileLatencyCost(integratedAv)
                + lightingControlProfileLatencyCost(lightingControl),
            verdict: aggregateIntegratedProfileRuntimeVerdicts([
                integratedAv.verdict,
                lightingControl.verdict,
            ]),
            notes: "Full optional profile derived from supplied integrated A/V and lighting reports."
        ),
        in: &report
    )
}

private func integratedAvProfileLatencyCost(_ report: IntegratedAvReport) -> Double {
    max(0, report.audio.integratedCallbackP99Microseconds - report.audio.baselineCallbackP99Microseconds)
}

private func lightingControlProfileLatencyCost(_ report: LightingFixtureGateReport) -> Double {
    max(0, report.audioImpact.lightingCallbackP99Microseconds - report.audioImpact.baselineCallbackP99Microseconds)
}

private func applySubordinateEvidence(
    to report: inout IntegratedProfileReport,
    evidence: IntegratedProfileRuntimeEvidence
) {
    if let fastestAudio = evidence.fastestAudio {
        applyFastestAudioSubordinateEvidence(to: &report, fastestAudio: fastestAudio)
    }
    if let integratedAv = evidence.integratedAv {
        applyIntegratedAvSubordinateEvidence(to: &report, integratedAv: integratedAv)
    }
    if let lightingControl = evidence.lightingControl {
        applyLightingControlSubordinateEvidence(to: &report, lightingControl: lightingControl)
    }
}

private func applyFastestAudioSubordinateEvidence(
    to report: inout IntegratedProfileReport,
    fastestAudio: LatencyBenchmarkReport
) {
    let physicalPassEvidence = fastestAudioPhysicalPassEvidence(fastestAudio)
    mutateEvidence(
        IntegratedProfileEvidenceMutation(
            lane: .fastestAudio,
            reportId: fastestAudio.id,
            verdict: fastestAudio.verdict,
            measured: fastestAudio.runMode == .measured,
            physicalPassEvidence: physicalPassEvidence,
            notes: "Derived from supplied latency benchmark report."
        ),
        in: &report
    )
    mutateEvidence(
        IntegratedProfileEvidenceMutation(
            lane: .audioRoute,
            reportId: fastestAudio.id,
            verdict: fastestAudio.verdict,
            measured: fastestAudio.runMode == .measured,
            physicalPassEvidence: physicalPassEvidence,
            notes: "Audio route evidence derived from supplied latency benchmark route."
        ),
        in: &report
    )
}

private func applyIntegratedAvSubordinateEvidence(
    to report: inout IntegratedProfileReport,
    integratedAv: IntegratedAvReport
) {
    let measured = integratedAv.runMode == .measured
    let physicalPassEvidence = integratedAv.verdict == .pass && measured
    mutateEvidence(
        IntegratedProfileEvidenceMutation(
            lane: .integratedAv,
            reportId: integratedAv.id,
            verdict: integratedAv.verdict,
            measured: measured,
            physicalPassEvidence: physicalPassEvidence,
            notes: "Derived from supplied integrated A/V report."
        ),
        in: &report
    )
    applyVideoCaptureSubordinateEvidence(
        to: &report,
        integratedAv: integratedAv,
        measured: measured,
        physicalPassEvidence: physicalPassEvidence
    )
    applyVideoTransportSubordinateEvidence(
        to: &report,
        integratedAv: integratedAv,
        measured: measured,
        physicalPassEvidence: physicalPassEvidence
    )
}

private func applyVideoCaptureSubordinateEvidence(
    to report: inout IntegratedProfileReport,
    integratedAv: IntegratedAvReport,
    measured: Bool,
    physicalPassEvidence: Bool
) {
    guard let reportId = integratedAv.proof?.videoCaptureReportId else {
        return
    }
    mutateEvidence(
        IntegratedProfileEvidenceMutation(
            lane: .videoCapture,
            reportId: reportId,
            verdict: integratedAv.verdict,
            measured: measured,
            physicalPassEvidence: physicalPassEvidence,
            notes: "Video capture evidence referenced by supplied integrated A/V report."
        ),
        in: &report
    )
}

private func applyVideoTransportSubordinateEvidence(
    to report: inout IntegratedProfileReport,
    integratedAv: IntegratedAvReport,
    measured: Bool,
    physicalPassEvidence: Bool
) {
    guard let reportId = integratedAv.proof?.videoTransportReportId else {
        return
    }
    mutateEvidence(
        IntegratedProfileEvidenceMutation(
            lane: .videoTransport,
            reportId: reportId,
            verdict: integratedAv.verdict,
            measured: measured,
            physicalPassEvidence: physicalPassEvidence,
            notes: "Video transport evidence referenced by supplied integrated A/V report."
        ),
        in: &report
    )
}

private func applyLightingControlSubordinateEvidence(
    to report: inout IntegratedProfileReport,
    lightingControl: LightingFixtureGateReport
) {
    let measured = integratedProfileLightingEvidenceIsMeasured(lightingControl)
    mutateEvidence(
        IntegratedProfileEvidenceMutation(
            lane: .lightingControl,
            reportId: lightingControl.id,
            verdict: lightingControl.verdict,
            measured: measured,
            physicalPassEvidence: lightingControl.verdict == .pass && measured,
            notes: "Derived from supplied lighting fixture gate report."
        ),
        in: &report
    )
}

private func fastestAudioPhysicalPassEvidence(_ report: LatencyBenchmarkReport) -> Bool {
    report.verdict == .pass
        && report.runMode == .measured
        && report.evidenceKind == .physicalReferenceRig
}

private func applyBenchmarkRows(
    to report: inout IntegratedProfileReport,
    configuration: IntegratedProfileRunConfiguration,
    evidence: IntegratedProfileRuntimeEvidence
) {
    if let fastestAudio = evidence.fastestAudio {
        applyFastestAudioBenchmarkRow(to: &report, fastestAudio: fastestAudio)
    }
    if let integratedAv = evidence.integratedAv {
        applyIntegratedAvBenchmarkRow(to: &report, integratedAv: integratedAv)
    }
    if let lightingControl = evidence.lightingControl {
        applyLightingControlBenchmarkRow(to: &report, lightingControl: lightingControl)
    }
    if let integratedAv = evidence.integratedAv,
       let lightingControl = evidence.lightingControl {
        applyFullMatrixBenchmarkRow(
            to: &report,
            configuration: configuration,
            integratedAv: integratedAv,
            lightingControl: lightingControl
        )
    }
}

private func applyFastestAudioBenchmarkRow(
    to report: inout IntegratedProfileReport,
    fastestAudio: LatencyBenchmarkReport
) {
    mutateBenchmarkRow(
        IntegratedProfileBenchmarkMutation(
            scenario: .audioOnly,
            reportId: fastestAudio.id,
            verdict: fastestAudio.verdict,
            measured: fastestAudio.runMode == .measured,
            physicalEvidence: fastestAudioPhysicalPassEvidence(fastestAudio),
            metrics: integratedProfileMetrics(from: fastestAudio),
            notes: "Audio-only matrix row derived from supplied latency benchmark."
        ),
        in: &report
    )
}

private func applyIntegratedAvBenchmarkRow(
    to report: inout IntegratedProfileReport,
    integratedAv: IntegratedAvReport
) {
    mutateBenchmarkRow(
        IntegratedProfileBenchmarkMutation(
            scenario: .audioVideo,
            reportId: integratedAv.id,
            verdict: integratedAv.verdict,
            measured: integratedAv.runMode == .measured,
            physicalEvidence: integratedAv.verdict == .pass && integratedAv.runMode == .measured,
            metrics: integratedProfileMetrics(from: integratedAv),
            notes: "Audio-video matrix row derived from supplied integrated A/V report."
        ),
        in: &report
    )
}

private func applyLightingControlBenchmarkRow(
    to report: inout IntegratedProfileReport,
    lightingControl: LightingFixtureGateReport
) {
    mutateBenchmarkRow(
        IntegratedProfileBenchmarkMutation(
            scenario: .audioControl,
            reportId: lightingControl.id,
            verdict: lightingControl.verdict,
            measured: integratedProfileLightingEvidenceIsMeasured(lightingControl),
            physicalEvidence: lightingControl.verdict == .pass
                && integratedProfileLightingEvidenceIsMeasured(lightingControl),
            metrics: integratedProfileMetrics(from: lightingControl),
            notes: "Audio-control matrix row derived from supplied lighting fixture gate report."
        ),
        in: &report
    )
}

private func applyFullMatrixBenchmarkRow(
    to report: inout IntegratedProfileReport,
    configuration: IntegratedProfileRunConfiguration,
    integratedAv: IntegratedAvReport,
    lightingControl: LightingFixtureGateReport
) {
    mutateBenchmarkRow(
        IntegratedProfileBenchmarkMutation(
            scenario: .audioVideoControl,
            reportId: configuration.matrixReportIds[.audioVideoControl]
                ?? "m12-audio-video-control-required",
            verdict: aggregateIntegratedProfileRuntimeVerdicts([
                integratedAv.verdict,
                lightingControl.verdict,
            ]),
            measured: integratedAv.runMode == .measured
                && integratedProfileLightingEvidenceIsMeasured(lightingControl),
            physicalEvidence: integratedAv.verdict == .pass
                && integratedAv.runMode == .measured
                && lightingControl.verdict == .pass
                && integratedProfileLightingEvidenceIsMeasured(lightingControl),
            metrics: integratedProfileCombinedMetrics(
                integratedProfileMetrics(from: integratedAv),
                integratedProfileMetrics(from: lightingControl)
            ),
            notes: "Full matrix row derived from supplied integrated A/V and lighting reports."
        ),
        in: &report
    )
}

private func integratedProfileMetrics(from report: LatencyBenchmarkReport) -> IntegratedProfileBenchmarkMetrics {
    IntegratedProfileBenchmarkMetrics(
        // LatencyBenchmarkReport exposes a documented one-way estimate; integrated profile rows retain that
        // estimate as the audio latency metric instead of treating it as an independent synchronized measurement.
        audioLatencyP99Microseconds: report.timing.oneWayEstimateMicroseconds,
        audioJitterP99Microseconds: report.timing.jitter.p99Microseconds,
        lostPackets: report.loss.lostPackets,
        latePackets: report.loss.latePackets,
        underruns: report.faults.underruns,
        droppedVideoFrames: report.faults.droppedFrames,
        cueTimingP99Microseconds: 0,
        cpuP99Percent: report.resources.cpuP99Percent,
        residentMemoryMegabytes: report.resources.residentMemoryMegabytes,
        measurementDurationSeconds: nil,
        callbackDeadlineWarnings: report.faults.missedDeadlines,
        allocationWarnings: report.resources.allocationWarnings.count,
        threadSchedulingWarnings: report.resources.threadWarnings.count
    )
}

private func integratedProfileMetrics(from report: IntegratedAvReport) -> IntegratedProfileBenchmarkMetrics {
    IntegratedProfileBenchmarkMetrics(
        audioLatencyP99Microseconds: max(
            report.audio.integratedCallbackP99Microseconds,
            report.audio.packetAge.p99Microseconds
        ),
        audioJitterP99Microseconds: report.audio.packetAge.p99Microseconds,
        lostPackets: report.audio.lostPackets,
        latePackets: report.audio.latePackets,
        underruns: report.audio.underruns,
        droppedVideoFrames: report.video.receiverDroppedFrames,
        cueTimingP99Microseconds: 0,
        cpuP99Percent: report.systemLoad.cpuP99Percent,
        residentMemoryMegabytes: 0,
        measurementDurationSeconds: report.durationSeconds,
        callbackDeadlineWarnings: report.audio.hiddenPlayoutGrowthDetected ? 1 : 0,
        allocationWarnings: 0,
        threadSchedulingWarnings: 0
    )
}

private func integratedProfileMetrics(from report: LightingFixtureGateReport) -> IntegratedProfileBenchmarkMetrics {
    IntegratedProfileBenchmarkMetrics(
        audioLatencyP99Microseconds: report.audioImpact.lightingCallbackP99Microseconds,
        audioJitterP99Microseconds: max(
            0,
            report.audioImpact.lightingCallbackMaxMicroseconds
                - report.audioImpact.lightingCallbackP99Microseconds
        ),
        lostPackets: 0,
        latePackets: 0,
        underruns: report.audioImpact.underruns,
        droppedVideoFrames: 0,
        cueTimingP99Microseconds: 0,
        cpuP99Percent: 0,
        residentMemoryMegabytes: 0,
        measurementDurationSeconds: report.probe.durationSeconds,
        callbackDeadlineWarnings: report.audioImpact.hiddenAudioImpactDetected ? 1 : 0,
        allocationWarnings: 0,
        threadSchedulingWarnings: 0
    )
}

private func integratedProfileCombinedMetrics(
    _ first: IntegratedProfileBenchmarkMetrics,
    _ second: IntegratedProfileBenchmarkMetrics
) -> IntegratedProfileBenchmarkMetrics {
    let combinedDuration = integratedProfileMatchedDuration(first.measurementDurationSeconds, second.measurementDurationSeconds)
    return IntegratedProfileBenchmarkMetrics(
        audioLatencyP99Microseconds: integratedProfileWorstCaseMetric(
            first.audioLatencyP99Microseconds,
            second.audioLatencyP99Microseconds
        ),
        audioJitterP99Microseconds: integratedProfileWorstCaseMetric(
            first.audioJitterP99Microseconds,
            second.audioJitterP99Microseconds
        ),
        lostPackets: integratedProfileEventCount(first.lostPackets, second.lostPackets),
        latePackets: integratedProfileEventCount(first.latePackets, second.latePackets),
        underruns: integratedProfileEventCount(first.underruns, second.underruns),
        droppedVideoFrames: integratedProfileEventCount(first.droppedVideoFrames, second.droppedVideoFrames),
        cueTimingP99Microseconds: integratedProfileWorstCaseMetric(
            first.cueTimingP99Microseconds,
            second.cueTimingP99Microseconds
        ),
        cpuP99Percent: integratedProfileWorstCaseMetric(first.cpuP99Percent, second.cpuP99Percent),
        residentMemoryMegabytes: integratedProfileWorstCaseMetric(
            first.residentMemoryMegabytes,
            second.residentMemoryMegabytes
        ),
        measurementDurationSeconds: combinedDuration.duration,
        durationMismatch: combinedDuration.mismatch,
        callbackDeadlineWarnings: integratedProfileEventCount(
            first.callbackDeadlineWarnings,
            second.callbackDeadlineWarnings
        ),
        allocationWarnings: integratedProfileEventCount(first.allocationWarnings, second.allocationWarnings),
        threadSchedulingWarnings: integratedProfileEventCount(
            first.threadSchedulingWarnings,
            second.threadSchedulingWarnings
        )
    )
}

private func integratedProfileWorstCaseMetric(_ first: Double, _ second: Double) -> Double {
    max(first, second)
}

private func integratedProfileEventCount(_ first: Int, _ second: Int) -> Int {
    first + second
}

private func integratedProfileMatchedDuration(
    _ first: Double?,
    _ second: Double?
) -> (duration: Double?, mismatch: Bool) {
    guard let first, let second else {
        return (first ?? second, false)
    }
    guard first == second else {
        return (nil, true)
    }
    return (first, false)
}

private struct IntegratedProfileOptionMutation {
    let label: IntegratedProfileLabel
    let sourceReportId: String
    let costReportId: String
    let latencyCostMicroseconds: Double
    let verdict: MeasurementVerdict
    let notes: String
}

private func mutateOption(
    _ mutation: IntegratedProfileOptionMutation,
    in report: inout IntegratedProfileReport
) {
    guard let index = report.profileOptions.firstIndex(where: { $0.label == mutation.label }) else {
        return
    }
    report.profileOptions[index].sourceReportId = mutation.sourceReportId
    report.profileOptions[index].costReportId = mutation.costReportId
    report.profileOptions[index].latencyCostMicroseconds = mutation.latencyCostMicroseconds
    report.profileOptions[index].verdict = mutation.verdict
    report.profileOptions[index].notes = mutation.notes
}

private struct IntegratedProfileEvidenceMutation {
    let lane: IntegratedProfileSubordinateLane
    let reportId: String
    let verdict: MeasurementVerdict
    let measured: Bool
    let physicalPassEvidence: Bool
    let notes: String
}

private func mutateEvidence(
    _ mutation: IntegratedProfileEvidenceMutation,
    in report: inout IntegratedProfileReport
) {
    guard let index = report.subordinateEvidence.firstIndex(where: { $0.lane == mutation.lane }) else {
        return
    }
    report.subordinateEvidence[index].reportId = mutation.reportId
    report.subordinateEvidence[index].verdict = mutation.verdict
    report.subordinateEvidence[index].measured = mutation.measured
    report.subordinateEvidence[index].physicalPassEvidence = mutation.physicalPassEvidence
    report.subordinateEvidence[index].notes = mutation.notes
}

private struct IntegratedProfileBenchmarkMutation {
    let scenario: IntegratedProfileBenchmarkScenario
    let reportId: String
    let verdict: MeasurementVerdict
    let measured: Bool
    let physicalEvidence: Bool
    let metrics: IntegratedProfileBenchmarkMetrics
    let notes: String
}

private func mutateBenchmarkRow(
    _ mutation: IntegratedProfileBenchmarkMutation,
    in report: inout IntegratedProfileReport
) {
    guard let index = report.benchmarkMatrix.firstIndex(where: { $0.scenario == mutation.scenario }) else {
        return
    }
    report.benchmarkMatrix[index].reportId = mutation.reportId
    report.benchmarkMatrix[index].verdict = mutation.verdict
    report.benchmarkMatrix[index].measured = mutation.measured
    report.benchmarkMatrix[index].physicalEvidence = mutation.physicalEvidence
    report.benchmarkMatrix[index].metrics = mutation.metrics
    report.benchmarkMatrix[index].notes = mutation.notes
}

private func integratedProfileRuntimeEvidenceIsMeasured(
    _ evidence: IntegratedProfileRuntimeEvidence
) -> Bool {
    evidence.fastestAudio?.runMode == .measured
        || evidence.integratedAv?.runMode == .measured
        || evidence.lightingControl.map(integratedProfileLightingEvidenceIsMeasured) == true
}

private func integratedProfileLightingEvidenceIsMeasured(_ report: LightingFixtureGateReport) -> Bool {
    report.runMode == .measured
}

private func aggregateIntegratedProfileRuntimeVerdicts(_ verdicts: [MeasurementVerdict]) -> MeasurementVerdict {
    if verdicts.contains(.fail) {
        return .fail
    }
    if verdicts.allSatisfy({ $0 == .pass }) {
        return .pass
    }
    return .partial
}
