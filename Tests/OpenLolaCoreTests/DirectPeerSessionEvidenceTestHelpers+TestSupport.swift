// Shared Direct peer session evidence test helpers helpers keep multi-file test scenarios deterministic.
@testable import OpenLolaCore

func directPeerSessionPacketCaptureArtifact(
    _ path: String = "reports/captures/direct-p2p-av-mac-b.pcapng"
) -> DirectPeerSessionEvidenceArtifact {
    DirectPeerSessionEvidenceArtifact(path: path, captured: true, sha256: directPeerSessionTestSHA256("packet"))
}

func directPeerSessionDSCPEvidence() -> DirectPeerSessionDSCPEvidence {
    DirectPeerSessionDSCPEvidence(
        requested: 46,
        observed: 46,
        classification: .honored,
        capturePoint: "receiver ingress en6",
        artifact: DirectPeerSessionEvidenceArtifact(
            path: "reports/evidence/dscp-observation.json",
            captured: true,
            sha256: directPeerSessionTestSHA256("dscp")
        )
    )
}

func directPeerSessionClockEvidence() -> DirectPeerSessionClockEvidence {
    DirectPeerSessionClockEvidence(
        clockSource: "PTP grandmaster gm-lab",
        method: "ptp4l offset summary",
        maxOffsetMicroseconds: 750,
        artifact: DirectPeerSessionEvidenceArtifact(
            path: "reports/evidence/clock-sync.json",
            captured: true,
            sha256: directPeerSessionTestSHA256("clock")
        )
    )
}

func directPeerSessionMeasuredEvidence(
    sourcePeerLabel: String,
    receiverPeerLabel: String,
    routeLabel: String,
    packetCapturePath: String = "reports/captures/direct-p2p-av-mac-b.pcapng",
    dscpObservation: String = "EF preserved at receiver ingress",
    clockSummary: String = "PTP offset below one millisecond",
    rawVideoReceiveEvidence: String,
    durationSeconds: Int = 30
) -> DirectPeerSessionMeasuredEvidence {
    DirectPeerSessionMeasuredEvidence(
        identity: .init(
            kind: .physicalTwoPeerMacs,
            sourcePeerLabel: sourcePeerLabel,
            receiverPeerLabel: receiverPeerLabel,
            routeLabel: routeLabel
        ),
        packetCapture: .init(
            path: packetCapturePath,
            artifact: directPeerSessionPacketCaptureArtifact(packetCapturePath)
        ),
        dscp: .init(observation: dscpObservation, evidence: directPeerSessionDSCPEvidence()),
        clock: .init(summary: clockSummary, evidence: directPeerSessionClockEvidence()),
        media: .init(
            rawVideoReceiveEvidence: rawVideoReceiveEvidence,
            durationSeconds: Double(durationSeconds)
        )
    )
}

func directPeerSessionAudioFixture(
    deviceUID: String,
    inputDeviceUID: String? = nil,
    outputDeviceUID: String? = nil,
    latencyProfile: SessionLatencyProfile,
    rxBufferProfile: RxBufferProfile
) -> DirectPeerSessionAVRuntimeMetadata.Audio {
    DirectPeerSessionAVRuntimeMetadata.Audio(
        deviceUID: deviceUID,
        inputDeviceUID: inputDeviceUID,
        outputDeviceUID: outputDeviceUID,
        sampleRateHertz: 48_000,
        selectedBufferFrameSize: 32,
        latencyProfile: latencyProfile,
        rxBufferProfile: rxBufferProfile
    )
}

func directPeerSessionRawTransportFixture() -> DirectPeerSessionAVRuntimeMetadata.Transport {
    DirectPeerSessionAVRuntimeMetadata.Transport()
}

func directPeerSessionRawVideoFixture(
    deviceID: String,
    frameRate: Int = 30,
    streamID: Int = 100
) -> DirectPeerSessionAVRuntimeMetadata.Video {
    DirectPeerSessionAVRuntimeMetadata.Video(
        deviceID: deviceID,
        frameRate: frameRate,
        streamID: streamID
    )
}

func directPeerSessionUsePhysicalEndpointHosts(
    _ report: inout DirectPeerSessionReport,
    firstHost: String = "192.0.2.10",
    secondHost: String = "192.0.2.20"
) {
    report.configuration.controlEndpoint.host = firstHost
    report.configuration.audioEndpoint.host = firstHost
    report.configuration.videoEndpoint.host = firstHost
    report.configuration.metricsEndpoint.host = firstHost
    guard var endpoints = report.configuration.peerMediaEndpoints else {
        return
    }
    for index in endpoints.indices {
        let host = index == endpoints.startIndex ? firstHost : secondHost
        endpoints[index].controlEndpoint.host = host
        endpoints[index].audioEndpoint.host = host
        endpoints[index].videoEndpoint.host = host
        endpoints[index].metricsEndpoint.host = host
    }
    report.configuration.peerMediaEndpoints = endpoints
}

private func directPeerSessionTestSHA256(_ seed: String) -> String {
    let scalar = UInt8(seed.utf8.reduce(0) { ($0 &+ $1) % 16 })
    let digit = String(scalar, radix: 16)
    return String(repeating: digit, count: 64)
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
