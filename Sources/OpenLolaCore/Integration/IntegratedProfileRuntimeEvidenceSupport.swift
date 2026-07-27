// Validates and combines subordinate runtime evidence before profile report assembly.
import Foundation

func fastestAudioPhysicalPassEvidence(_ report: LatencyBenchmarkReport) -> Bool {
    report.verdict == .pass
        && report.runMode == .measured
        && report.evidenceKind == .physicalReferenceRig
}

func integratedProfileLightingEvidenceIsMeasured(_ report: LightingFixtureGateReport) -> Bool {
    report.runMode == .measured
}

func aggregateIntegratedProfileRuntimeVerdicts(_ verdicts: [MeasurementVerdict]) -> MeasurementVerdict {
    if verdicts.contains(.fail) {
        return .fail
    }
    if verdicts.allSatisfy({ $0 == .pass }) {
        return .pass
    }
    return .partial
}
