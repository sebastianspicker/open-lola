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
        mutateOption(
            .fastestAudio,
            in: &report,
            sourceReportId: fastestAudio.id,
            costReportId: fastestAudio.id,
            latencyCostMicroseconds: 0,
            verdict: fastestAudio.verdict,
            notes: "Fastest-audio profile derived from supplied latency benchmark report."
        )
    }
    if let integratedAv = evidence.integratedAv {
        mutateOption(
            .audioVideo,
            in: &report,
            sourceReportId: integratedAv.id,
            costReportId: integratedAv.id,
            latencyCostMicroseconds: max(
                0,
                integratedAv.audio.integratedCallbackP99Microseconds
                    - integratedAv.audio.baselineCallbackP99Microseconds
            ),
            verdict: integratedAv.verdict,
            notes: "Audio-video profile derived from supplied integrated A/V report."
        )
    }
    if let lightingControl = evidence.lightingControl {
        mutateOption(
            .audioLighting,
            in: &report,
            sourceReportId: lightingControl.id,
            costReportId: lightingControl.id,
            latencyCostMicroseconds: max(
                0,
                lightingControl.audioImpact.lightingCallbackP99Microseconds
                    - lightingControl.audioImpact.baselineCallbackP99Microseconds
            ),
            verdict: lightingControl.verdict,
            notes: "Audio-lighting profile derived from supplied lighting fixture gate report."
        )
    }
    if let integratedAv = evidence.integratedAv,
       let lightingControl = evidence.lightingControl {
        mutateOption(
            .audioVideoLighting,
            in: &report,
            sourceReportId: configuration.matrixReportIds[.audioVideoControl]
                ?? "m12-full-matrix-required",
            costReportId: configuration.matrixReportIds[.audioVideoControl]
                ?? "m12-full-matrix-required",
            latencyCostMicroseconds: max(
                0,
                integratedAv.audio.integratedCallbackP99Microseconds
                    - integratedAv.audio.baselineCallbackP99Microseconds
            ) + max(
                0,
                lightingControl.audioImpact.lightingCallbackP99Microseconds
                    - lightingControl.audioImpact.baselineCallbackP99Microseconds
            ),
            verdict: aggregateIntegratedProfileRuntimeVerdicts([
                integratedAv.verdict,
                lightingControl.verdict,
            ]),
            notes: "Full optional profile derived from supplied integrated A/V and lighting reports."
        )
    }
}

private func applySubordinateEvidence(
    to report: inout IntegratedProfileReport,
    evidence: IntegratedProfileRuntimeEvidence
) {
    if let fastestAudio = evidence.fastestAudio {
        mutateEvidence(
            .fastestAudio,
            in: &report,
            reportId: fastestAudio.id,
            verdict: fastestAudio.verdict,
            measured: fastestAudio.runMode == .measured,
            physicalPassEvidence: fastestAudio.verdict == .pass
                && fastestAudio.runMode == .measured
                && fastestAudio.evidenceKind == .physicalReferenceRig,
            notes: "Derived from supplied latency benchmark report."
        )
        mutateEvidence(
            .audioRoute,
            in: &report,
            reportId: fastestAudio.id,
            verdict: fastestAudio.verdict,
            measured: fastestAudio.runMode == .measured,
            physicalPassEvidence: fastestAudio.verdict == .pass
                && fastestAudio.runMode == .measured
                && fastestAudio.evidenceKind == .physicalReferenceRig,
            notes: "Audio route evidence derived from supplied latency benchmark route."
        )
    }
    if let integratedAv = evidence.integratedAv {
        let measured = integratedAv.runMode == .measured
        mutateEvidence(
            .integratedAv,
            in: &report,
            reportId: integratedAv.id,
            verdict: integratedAv.verdict,
            measured: measured,
            physicalPassEvidence: integratedAv.verdict == .pass && measured,
            notes: "Derived from supplied integrated A/V report."
        )
        if let videoCaptureReportId = integratedAv.proof?.videoCaptureReportId {
            mutateEvidence(
                .videoCapture,
                in: &report,
                reportId: videoCaptureReportId,
                verdict: integratedAv.verdict,
                measured: measured,
                physicalPassEvidence: integratedAv.verdict == .pass && measured,
                notes: "Video capture evidence referenced by supplied integrated A/V report."
            )
        }
        if let videoTransportReportId = integratedAv.proof?.videoTransportReportId {
            mutateEvidence(
                .videoTransport,
                in: &report,
                reportId: videoTransportReportId,
                verdict: integratedAv.verdict,
                measured: measured,
                physicalPassEvidence: integratedAv.verdict == .pass && measured,
                notes: "Video transport evidence referenced by supplied integrated A/V report."
            )
        }
    }
    if let lightingControl = evidence.lightingControl {
        mutateEvidence(
            .lightingControl,
            in: &report,
            reportId: lightingControl.id,
            verdict: lightingControl.verdict,
            measured: integratedProfileLightingEvidenceIsMeasured(lightingControl),
            physicalPassEvidence: lightingControl.verdict == .pass
                && integratedProfileLightingEvidenceIsMeasured(lightingControl),
            notes: "Derived from supplied lighting fixture gate report."
        )
    }
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
        .audioOnly,
        in: &report,
        reportId: fastestAudio.id,
        verdict: fastestAudio.verdict,
        measured: fastestAudio.runMode == .measured,
        physicalEvidence: fastestAudio.verdict == .pass
            && fastestAudio.runMode == .measured
            && fastestAudio.evidenceKind == .physicalReferenceRig,
        metrics: integratedProfileMetrics(from: fastestAudio),
        notes: "Audio-only matrix row derived from supplied latency benchmark."
    )
}

private func applyIntegratedAvBenchmarkRow(
    to report: inout IntegratedProfileReport,
    integratedAv: IntegratedAvReport
) {
    mutateBenchmarkRow(
        .audioVideo,
        in: &report,
        reportId: integratedAv.id,
        verdict: integratedAv.verdict,
        measured: integratedAv.runMode == .measured,
        physicalEvidence: integratedAv.verdict == .pass && integratedAv.runMode == .measured,
        metrics: integratedProfileMetrics(from: integratedAv),
        notes: "Audio-video matrix row derived from supplied integrated A/V report."
    )
}

private func applyLightingControlBenchmarkRow(
    to report: inout IntegratedProfileReport,
    lightingControl: LightingFixtureGateReport
) {
    mutateBenchmarkRow(
        .audioControl,
        in: &report,
        reportId: lightingControl.id,
        verdict: lightingControl.verdict,
        measured: integratedProfileLightingEvidenceIsMeasured(lightingControl),
        physicalEvidence: lightingControl.verdict == .pass
            && integratedProfileLightingEvidenceIsMeasured(lightingControl),
        metrics: integratedProfileMetrics(from: lightingControl),
        notes: "Audio-control matrix row derived from supplied lighting fixture gate report."
    )
}

private func applyFullMatrixBenchmarkRow(
    to report: inout IntegratedProfileReport,
    configuration: IntegratedProfileRunConfiguration,
    integratedAv: IntegratedAvReport,
    lightingControl: LightingFixtureGateReport
) {
    mutateBenchmarkRow(
        .audioVideoControl,
        in: &report,
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

private func mutateOption(
    _ label: IntegratedProfileLabel,
    in report: inout IntegratedProfileReport,
    sourceReportId: String,
    costReportId: String,
    latencyCostMicroseconds: Double,
    verdict: MeasurementVerdict,
    notes: String
) {
    guard let index = report.profileOptions.firstIndex(where: { $0.label == label }) else {
        return
    }
    report.profileOptions[index].sourceReportId = sourceReportId
    report.profileOptions[index].costReportId = costReportId
    report.profileOptions[index].latencyCostMicroseconds = latencyCostMicroseconds
    report.profileOptions[index].verdict = verdict
    report.profileOptions[index].notes = notes
}

private func mutateEvidence(
    _ lane: IntegratedProfileSubordinateLane,
    in report: inout IntegratedProfileReport,
    reportId: String,
    verdict: MeasurementVerdict,
    measured: Bool,
    physicalPassEvidence: Bool,
    notes: String
) {
    guard let index = report.subordinateEvidence.firstIndex(where: { $0.lane == lane }) else {
        return
    }
    report.subordinateEvidence[index].reportId = reportId
    report.subordinateEvidence[index].verdict = verdict
    report.subordinateEvidence[index].measured = measured
    report.subordinateEvidence[index].physicalPassEvidence = physicalPassEvidence
    report.subordinateEvidence[index].notes = notes
}

private func mutateBenchmarkRow(
    _ scenario: IntegratedProfileBenchmarkScenario,
    in report: inout IntegratedProfileReport,
    reportId: String,
    verdict: MeasurementVerdict,
    measured: Bool,
    physicalEvidence: Bool,
    metrics: IntegratedProfileBenchmarkMetrics,
    notes: String
) {
    guard let index = report.benchmarkMatrix.firstIndex(where: { $0.scenario == scenario }) else {
        return
    }
    report.benchmarkMatrix[index].reportId = reportId
    report.benchmarkMatrix[index].verdict = verdict
    report.benchmarkMatrix[index].measured = measured
    report.benchmarkMatrix[index].physicalEvidence = physicalEvidence
    report.benchmarkMatrix[index].metrics = metrics
    report.benchmarkMatrix[index].notes = notes
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
