// Keeps the partial app-shell direct-peer report fixture reusable without obscuring report assertions.
@testable import OpenLolaCore

func appPartialAVRuntime(
    latencyMicroseconds: Double
) -> DirectPeerSessionAVRuntimeMetadata {
    DirectPeerSessionAVRuntimeMetadata(
        session: .init(
            avProfile: .fastest,
            previewMode: .off,
            mediaSourceMode: .syntheticFixture,
            usefulMediaProof: .unknown
        ),
        audio: directPeerSessionAudioFixture(
            deviceUID: "local-rme",
            latencyProfile: .directAudioFirst,
            rxBufferProfile: .direct
        ),
        transport: directPeerSessionRawTransportFixture(),
        video: directPeerSessionRawVideoFixture(deviceID: "local-atem"),
        evidence: .init(
            fastestPassBlockedReason: "unit test partial",
            runtimeMetrics: .empty,
            fastestAVBaselineComparison: DirectPeerSessionFastestAVBaselineComparison(
                audioOnlyBaselineReportID: "audio-only",
                audioOnlyBaselineReportPath: "reports/audio-only.json",
                comparisonArtifactPath: "reports/comparison.json",
                audioOnlyLatencyP99Microseconds: latencyMicroseconds,
                fastestAVAudioLatencyP99Microseconds: latencyMicroseconds,
                audioLatencyEqualToBaseline: true,
                rxBufferEqualToBaseline: true,
                lossJitterEqualToBaseline: true
            )
        )
    )
}
