// Captures runtime evidence for fastest-audio, integrated AV, and lighting-control profile lanes.
import Foundation

/// Records the evidence and outcome for integrated profile runtime evidence.
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
    report.notes = "Measured partial M12 aggregate from supplied runtime reports. " +
"Physical PASS still requires accepted audio, video, lighting/control, " +
"and benchmark evidence."
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
                lightingControl.verdict
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

struct IntegratedProfileEvidenceMutation {
    let lane: IntegratedProfileSubordinateLane
    let reportId: String
    let verdict: MeasurementVerdict
    let measured: Bool
    let physicalPassEvidence: Bool
    let notes: String
}

func mutateEvidence(
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

struct IntegratedProfileBenchmarkMutation {
    let scenario: IntegratedProfileBenchmarkScenario
    let reportId: String
    let verdict: MeasurementVerdict
    let measured: Bool
    let physicalEvidence: Bool
    let metrics: IntegratedProfileBenchmarkMetrics
    let notes: String
}

func mutateBenchmarkRow(
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

func integratedProfileRuntimeEvidenceIsMeasured(
    _ evidence: IntegratedProfileRuntimeEvidence
) -> Bool {
    evidence.fastestAudio?.runMode == .measured
        || evidence.integratedAv?.runMode == .measured
        || evidence.lightingControl.map(integratedProfileLightingEvidenceIsMeasured) == true
}
