// Derives integrated-profile benchmark rows and metrics from runtime lane evidence.
import Foundation

func applyBenchmarkRows(
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
                lightingControl.verdict
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
        audio: IntegratedProfileBenchmarkMetrics.Audio(
            latencyP99Microseconds: report.timing.oneWayEstimateMicroseconds,
            jitterP99Microseconds: report.timing.jitter.p99Microseconds,
            lostPackets: report.loss.lostPackets,
            latePackets: report.loss.latePackets,
            underruns: report.faults.underruns
        ),
        videoControl: IntegratedProfileBenchmarkMetrics.VideoControl(
            droppedVideoFrames: report.faults.droppedFrames,
            cueTimingP99Microseconds: 0
        ),
        resources: IntegratedProfileBenchmarkMetrics.Resources(
            cpuP99Percent: report.resources.cpuP99Percent,
            residentMemoryMegabytes: report.resources.residentMemoryMegabytes
        ),
        warnings: IntegratedProfileBenchmarkMetrics.Warnings(
            callbackDeadlines: report.faults.missedDeadlines,
            allocations: report.resources.allocationWarnings.count,
            threadScheduling: report.resources.threadWarnings.count
        )
    )
}

private func integratedProfileMetrics(from report: IntegratedAvReport) -> IntegratedProfileBenchmarkMetrics {
    IntegratedProfileBenchmarkMetrics(
        audio: IntegratedProfileBenchmarkMetrics.Audio(
            latencyP99Microseconds: max(
                report.audio.integratedCallbackP99Microseconds,
                report.audio.packetAge.p99Microseconds
            ),
            jitterP99Microseconds: report.audio.packetAge.p99Microseconds,
            lostPackets: report.audio.lostPackets,
            latePackets: report.audio.latePackets,
            underruns: report.audio.underruns
        ),
        videoControl: IntegratedProfileBenchmarkMetrics.VideoControl(
            droppedVideoFrames: report.video.receiverDroppedFrames,
            cueTimingP99Microseconds: 0
        ),
        resources: IntegratedProfileBenchmarkMetrics.Resources(
            cpuP99Percent: report.systemLoad.cpuP99Percent,
            residentMemoryMegabytes: 0,
            measurementDurationSeconds: report.durationSeconds
        ),
        warnings: IntegratedProfileBenchmarkMetrics.Warnings(
            callbackDeadlines: report.audio.hiddenPlayoutGrowthDetected ? 1 : 0,
            allocations: 0,
            threadScheduling: 0
        )
    )
}

private func integratedProfileMetrics(from report: LightingFixtureGateReport) -> IntegratedProfileBenchmarkMetrics {
    IntegratedProfileBenchmarkMetrics(
        audio: IntegratedProfileBenchmarkMetrics.Audio(
            latencyP99Microseconds: report.audioImpact.lightingCallbackP99Microseconds,
            jitterP99Microseconds: max(
                0,
                report.audioImpact.lightingCallbackMaxMicroseconds
                    - report.audioImpact.lightingCallbackP99Microseconds
            ),
            lostPackets: 0,
            latePackets: 0,
            underruns: report.audioImpact.underruns
        ),
        videoControl: IntegratedProfileBenchmarkMetrics.VideoControl(
            droppedVideoFrames: 0,
            cueTimingP99Microseconds: 0
        ),
        resources: IntegratedProfileBenchmarkMetrics.Resources(
            cpuP99Percent: 0,
            residentMemoryMegabytes: 0,
            measurementDurationSeconds: report.probe.durationSeconds
        ),
        warnings: IntegratedProfileBenchmarkMetrics.Warnings(
            callbackDeadlines: report.audioImpact.hiddenAudioImpactDetected ? 1 : 0,
            allocations: 0,
            threadScheduling: 0
        )
    )
}

private func integratedProfileCombinedMetrics(
    _ first: IntegratedProfileBenchmarkMetrics,
    _ second: IntegratedProfileBenchmarkMetrics
) -> IntegratedProfileBenchmarkMetrics {
    let combinedDuration = integratedProfileMatchedDuration(
        first.measurementDurationSeconds,
        second.measurementDurationSeconds
    )
    return IntegratedProfileBenchmarkMetrics(
        audio: IntegratedProfileBenchmarkMetrics.Audio(
            latencyP99Microseconds: integratedProfileWorstCaseMetric(
                first.audioLatencyP99Microseconds,
                second.audioLatencyP99Microseconds
            ),
            jitterP99Microseconds: integratedProfileWorstCaseMetric(
                first.audioJitterP99Microseconds,
                second.audioJitterP99Microseconds
            ),
            lostPackets: integratedProfileEventCount(first.lostPackets, second.lostPackets),
            latePackets: integratedProfileEventCount(first.latePackets, second.latePackets),
            underruns: integratedProfileEventCount(first.underruns, second.underruns)
        ),
        videoControl: IntegratedProfileBenchmarkMetrics.VideoControl(
            droppedVideoFrames: integratedProfileEventCount(
                first.droppedVideoFrames,
                second.droppedVideoFrames
            ),
            cueTimingP99Microseconds: integratedProfileWorstCaseMetric(
                first.cueTimingP99Microseconds,
                second.cueTimingP99Microseconds
            )
        ),
        resources: IntegratedProfileBenchmarkMetrics.Resources(
            cpuP99Percent: integratedProfileWorstCaseMetric(first.cpuP99Percent, second.cpuP99Percent),
            residentMemoryMegabytes: integratedProfileWorstCaseMetric(
                first.residentMemoryMegabytes,
                second.residentMemoryMegabytes
            ),
            measurementDurationSeconds: combinedDuration.duration,
            durationMismatch: combinedDuration.mismatch
        ),
        warnings: integratedProfileCombinedWarnings(first, second)
    )
}

private func integratedProfileCombinedWarnings(
    _ first: IntegratedProfileBenchmarkMetrics,
    _ second: IntegratedProfileBenchmarkMetrics
) -> IntegratedProfileBenchmarkMetrics.Warnings {
    IntegratedProfileBenchmarkMetrics.Warnings(
        callbackDeadlines: integratedProfileEventCount(
            first.callbackDeadlineWarnings,
            second.callbackDeadlineWarnings
        ),
        allocations: integratedProfileEventCount(first.allocationWarnings, second.allocationWarnings),
        threadScheduling: integratedProfileEventCount(
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
