// Converts subordinate lane reports into normalized integrated-profile runtime evidence.
import Foundation

func applySubordinateEvidence(
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
