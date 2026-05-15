@testable import OpenLolaCore

func directPeerSessionPacketCaptureArtifact(
    _ path: String = "reports/captures/direct-p2p-av-mac-b.pcapng"
) -> DirectPeerSessionEvidenceArtifact {
    DirectPeerSessionEvidenceArtifact(path: path, captured: true)
}

func directPeerSessionDSCPEvidence() -> DirectPeerSessionDSCPEvidence {
    DirectPeerSessionDSCPEvidence(
        requested: 46,
        observed: 46,
        classification: .honored,
        capturePoint: "receiver ingress en6",
        artifact: DirectPeerSessionEvidenceArtifact(path: "reports/evidence/dscp-observation.json", captured: true)
    )
}

func directPeerSessionClockEvidence() -> DirectPeerSessionClockEvidence {
    DirectPeerSessionClockEvidence(
        clockSource: "PTP grandmaster gm-lab",
        method: "ptp4l offset summary",
        maxOffsetMicroseconds: 750,
        artifact: DirectPeerSessionEvidenceArtifact(path: "reports/evidence/clock-sync.json", captured: true)
    )
}

func directPeerSessionFastestAVBaselineComparison() -> DirectPeerSessionFastestAVBaselineComparison {
    DirectPeerSessionFastestAVBaselineComparison(
        audioOnlyBaselineReportID: "m03-fastest-audio-baseline",
        audioOnlyBaselineReportPath: "reports/baselines/m03-fastest-audio-baseline.json",
        comparisonArtifactPath: "reports/evidence/fastest-av-baseline-comparison.json",
        audioOnlyLatencyP99Microseconds: 1_200,
        fastestAVAudioLatencyP99Microseconds: 1_200,
        audioLatencyEqualToBaseline: true,
        rxBufferEqualToBaseline: true,
        lossJitterEqualToBaseline: true
    )
}
