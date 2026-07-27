// Shared network aoip certification fixtures helpers keep related tests deterministic and focused on their contract.
import Foundation
import Testing
@testable import OpenLolaCore

func loadNetworkAoipCertificationFixture(named name: String) throws -> NetworkAoipCertificationReport {
    let url = try networkAoipCertificationFixtureURL(named: name)
    return try NetworkAoipCertificationReport.decode(from: Data(contentsOf: url))
}

func makeNetworkAoipCertificationPassCandidate() throws -> NetworkAoipCertificationReport {
    let routeReport = networkAoipRouteReport()
    let routeCertification = networkAoipRouteCertification(routeReport: routeReport)
    let driftCertification = try networkAoipDriftCertification(
        routeReport: routeReport,
        routeCertification: routeCertification
    )

    let metadata = NetworkAoipCertificationReport.Metadata(
        id: "g06-network-aoip-certification-measured",
        title: "G06 measured network AoIP certification",
        capturedAt: "2026-05-02T00:00:00Z",
        runMode: .measured
    )
    let reports = NetworkAoipCertificationReport.Reports(
        routeCertification: routeCertification,
        driftPlcCertification: driftCertification,
        aoipEvaluation: networkAoipEvaluationReport(routeReport: routeReport)
    )
    let artifacts = NetworkAoipCertificationReport.Artifacts(
        ptpPath: "private/reports/ptp/g06-avb-ptp-lock.md",
        stressPath: "private/reports/stress/g06-avb-wcrt.md",
        profilePath: "private/reports/profiles/g06-avb-profile.md",
        notTestedReason: nil
    )
    return NetworkAoipCertificationReport(
        .init(
            metadata: metadata,
            reports: reports,
            artifacts: artifacts,
            outcome: .init(
                verdict: .pass,
                notes: "Measured G06 network timing certification over the accepted direct-link baseline."
            )
        )
    )
}

private func networkAoipDriftCertification(
    routeReport: UdpPcmRouteReport,
    routeCertification: MacToMacRouteCertificationReport
) throws -> DriftPlcFixedTargetCertificationReport {
    let driftReport = try DriftPlcFixedTargetRunner.makeReport(
        routeReport: routeReport,
        configuration: DriftPlcRunConfiguration(
            routeReportPath: "private/reports/g04-direct-link-route.json",
            durationSeconds: 3_600,
            policy: .silence,
            artifactAssessmentCompleted: true,
            artifactNotes: "No audible artifacts during measured silence baseline.",
            outputPath: "private/reports/g05-direct-link-drift-plc.json"
        )
    )
    return DriftPlcFixedTargetCertificationReport(
        identity: .init(
            id: "g05-direct-link-fixed-target-certification",
            title: "G05 direct-link fixed-target drift PLC certification",
            capturedAt: "2026-05-02T00:00:00Z"
        ),
        supportingReports: .init(
            routeCertificationReport: routeCertification,
            driftPlcReport: driftReport,
            sourceRealtimeEngineReport: try networkAoipRealtimeReport(routeCertification: routeCertification),
            lolaBaselineComparison: networkAoipLolaBaseline(route: routeReport.route)
        ),
        outcome: .init(
            runMode: .measured,
            runArtifactPath: "private/reports/g05-direct-link-drift-plc.json",
            notTestedReason: nil,
            verdict: .pass,
            notes: "Measured G05 fixed-target certification for the accepted direct-link baseline."
        )
    )
}

private func networkAoipCertificationFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "NetworkAoipCertificationReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "NetworkAoipCertificationReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )
    return try #require(validURL ?? invalidURL ?? rootURL)
}

private func networkAoipRouteCertification(routeReport: UdpPcmRouteReport) -> MacToMacRouteCertificationReport {
    MacToMacRouteCertificationReport(
        identity: .init(id: "g04-direct-link-certification-measured", title: "Measured G04 direct-link route certification", capturedAt: "2026-05-02T00:00:00Z"),
        configuration: .init(runMode: .measured, packetMode: networkAoipPacketMode(), sourceRealtimeEngineReportId: "g03-rme-engine-measured"),
        outcome: .init(routes: networkAoipRouteCertificationCandidates(routeReport), verdict: .pass, notes: "Measured direct-link certification for G06 baseline input.")
    )
}

private func networkAoipRouteCertificationCandidates(
    _ routeReport: UdpPcmRouteReport
) -> [MacToMacRouteCertificationCandidate] {
    [
            MacToMacRouteCertificationCandidate(
                routeKind: .directLink,
                label: "direct-link-reference",
                routeReport: routeReport,
                packetCaptureArtifact: "private/reports/captures/direct-link-en5-2026-05-02.pcapng",
                notTestedReason: nil,
                notes: "Measured direct-link route with receiver capture."
            ),
            MacToMacRouteCertificationCandidate(
                routeKind: .dedicatedSwitch,
                label: "dedicated-switch-reference",
                routeReport: nil,
                packetCaptureArtifact: nil,
                notTestedReason: "Dedicated switch route was not part of this direct-link baseline.",
                notes: "Deferred until direct-link baseline is accepted."
            ),
            MacToMacRouteCertificationCandidate(
                routeKind: .campusPath,
                label: "campus-path-reference",
                routeReport: nil,
                packetCaptureArtifact: nil,
                notTestedReason: "Campus path awaits approved capture point.",
                notes: "Deferred by the campus capture question."
            )
    ]
}

private func networkAoipRouteReport() -> UdpPcmRouteReport {
    UdpPcmRouteReport(
        identity: .init(
            id: "m05-direct-link-measured-route",
            title: "Measured direct-link UDP PCM route",
            capturedAt: "2026-05-02T00:00:00Z",
            route: networkAoipDirectLinkRoute(),
            routeKind: .directLink
        ),
        endpoints: .init(
            sender: networkAoipRouteEndpoint(
                label: "sender-mac",
                hostName: "sender-mini-a",
                ipAddress: "10.10.20.10"
            ),
            receiver: networkAoipRouteEndpoint(
                label: "receiver-mac",
                hostName: "receiver-mini-b",
                ipAddress: "10.10.20.11"
            )
        ),
        measurement: .init(
            packetMode: networkAoipPacketMode(),
            measuredDurationSeconds: 2,
            network: networkAoipNetworkProfile(),
            metrics: networkAoipRouteMetrics()
        ),
        outcome: .init(
            verdict: .pass,
            notes: "Measured route report with fixed playout target and capture correlation."
        )
    )
}
private func networkAoipDirectLinkRoute() -> RouteIdentity {
    RouteIdentity(label: "direct-link-reference", topology: "mac-to-mac-direct-cable")
}

private func networkAoipRouteEndpoint(label: String, hostName: String, ipAddress: String) -> UdpPcmRouteEndpoint {
    UdpPcmRouteEndpoint(label: label, hostName: hostName, interfaceName: "en5", ipAddress: ipAddress)
}

private func networkAoipNetworkProfile() -> UdpPcmNetworkProfile {
    UdpPcmNetworkProfile(
        linkRateMbps: 1_000,
        vlan: "untagged",
        multicastPolicy: "unicast-only",
        dscp: UdpPcmDscpObservation(
            requested: 46,
            observed: 46,
            classification: .honored,
            notTestedReason: nil
        ),
        packetCapture: UdpPcmPacketCapture(
            point: "receiver en5 tcpdump capture",
            receiverCorrelation: true,
            notes: "Receiver capture matched expected packet count timestamp window."
        )
    )
}

private func networkAoipRouteMetrics() -> UdpPcmRouteMetrics {
    standardMeasuredRouteMetrics()
}

private func networkAoipEvaluationReport(routeReport: UdpPcmRouteReport) -> AoipEvaluationReport {
    let metadata = AoipEvaluationReport.Metadata(
        id: "m07-avb-measured-evaluation",
        title: "Measured M07 AVB network evaluation",
        capturedAt: "2026-05-02T00:00:00Z",
        mode: .avb,
        usage: .optionalFastestLocalMode
    )
    let path = AoipEvaluationReport.Path(
        route: routeReport.route,
        ptp: networkAoipPtpProfile(),
        switchProfile: networkAoipSwitchProfile(),
        endpoint: AoipEndpointPair(
            sender: networkAoipEndpointProfile("sender"),
            receiver: networkAoipEndpointProfile("receiver")
        )
    )
    let evidence = AoipEvaluationReport.Evidence(
        profile: networkAoipProfileEvidence(),
        baselineComparison: networkAoipBaselineComparison(routeReport: routeReport),
        stress: networkAoipStressReport()
    )
    return AoipEvaluationReport(
        .init(
            metadata: metadata,
            path: path,
            evidence: evidence,
            outcome: .init(
                verdict: .pass,
                notes: "Measured AVB mode kept lower p99 than the direct UDP PCM baseline."
            )
        )
    )
}
private func networkAoipPtpProfile() -> AoipPtpProfile {
    AoipPtpProfile(
        version: "IEEE 1588-2008",
        profile: "802.1AS AVB media profile",
        domain: "0",
        masterClockId: "rme-avb-master-clock-001",
        lockState: "locked"
    )
}

private func networkAoipSwitchProfile() -> AoipSwitchProfile {
    AoipSwitchProfile(
        model: "Netgear M4250-10G2F-PoE",
        firmwareVersion: "13.0.4.13",
        linkRateMbps: 1_000,
        trafficClass: "SR class A",
        streamReservation: "enabled",
        schedule: "credit-based shaper"
    )
}

private func networkAoipProfileEvidence() -> AoipProfileEvidence {
    AoipProfileEvidence(
        standardsRead: ["IEEE 802.1AS 802.1Qav AVB profile notes"],
        vendorProfilesRead: ["RME AVB endpoint media profile"]
    )
}

private func networkAoipBaselineComparison(routeReport: UdpPcmRouteReport) -> AoipBaselineComparison {
    AoipBaselineComparison(
        directUdpPcmRouteReportId: routeReport.id,
        directUdpPcmVerdict: .pass,
        measuredOnSamePath: true,
        directUdpPcmP99Microseconds: 240,
        evaluatedModeP99Microseconds: 180,
        notes: "AVB endpoint p99 was measured on same direct-link path."
    )
}

private func networkAoipStressReport() -> AoipStressReport {
    AoipStressReport(
        measured: true,
        competingTrafficProfile: "iperf3 bidirectional 70 percent link load",
        packetAge: UdpPcmPacketAgeMetrics(
            p50Microseconds: 90,
            p95Microseconds: 140,
            p99Microseconds: 180,
            maxMicroseconds: 220
        ),
        packetLoss: 0,
        recoveryBehavior: "stream recovered within one packet period",
        notes: "Measured WCRT-style stress run retained audio timing."
    )
}

private func networkAoipRealtimeReport(
    routeCertification: MacToMacRouteCertificationReport
) throws -> RealtimeAudioEngineReport {
    RealtimeAudioEngineReport(
        id: "g03-rme-engine-measured",
        title: "Measured G03 RME realtime engine",
        capturedAt: "2026-05-02T00:00:00Z",
        runMode: .measured,
        hardwarePath: .rmeMadi,
        hardware: HardwareIdentity(
            referenceMac: "reference-mac-mini-m2",
            audioInterface: "RME Fireface UFX+ MADI Thunderbolt",
            osVersion: "macOS 15.5 24F74",
            driverVersion: "RME Thunderbolt Driver 4.08"
        ),
        configuration: try networkAoipRealtimeConfiguration(),
        safety: RealtimeAudioCallbackSafetyChecklist(
            noAllocationInCallback: true,
            noLoggingInCallback: true,
            noFileIOInCallback: true,
            noLocksOrUnboundedWaitsInCallback: true,
            noNetworkSetupInCallback: true,
            noReportWritingInCallback: true,
            countersOnlyInCallback: true
        ),
        runtime: try networkAoipRealtimeRuntime(),
        sourceRmeFastestAudioReport: networkAoipRmeFastestReport(),
        sourceRouteCertificationReport: routeCertification,
        runArtifactPath: "private/reports/g03-rme-realtime-engine-measured.json",
        verdict: .pass,
        notes: "Measured RME MADI realtime engine source report for G06 tests."
    )
}

private func networkAoipRmeFastestReport() -> RmeFastestAudioPathReport {
    measuredRmeFastestAudioReport(
        capturedAt: "2026-05-02T00:00:00Z",
        device: networkAoipRmeDevice(),
        loopback: networkAoipEndpointLoopbackReport(),
        notes: "Measured RME fastest-audio source report for G06 tests."
    )
}

private func networkAoipEndpointLoopbackReport() -> EndpointLoopbackReport {
    let selectedMode = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: "int16"
    )
    var report = driftCertificationRmeEndpointLoopbackReport(selectedMode: selectedMode)
    report.device.transportType = "thunderbolt"
    report.sampleRates = networkAoipLoopbackSampleRates()
    report.stabilityRun = measuredFixtureEndpointStabilityRun(
        selectedMode: selectedMode,
        notes: "Thirty minute fixed-target measured run."
    )
    report.notes = "Measured RME loopback source report for G06 tests."
    return report
}

private func networkAoipLoopbackSampleRates() -> [SampleRateLoopbackResult] {
    [
        networkAoip48kLoopbackSampleRate(),
        networkAoip96kLoopbackSampleRate(),
        networkAoip192kLoopbackSampleRate()
    ]
}

// swiftlint:disable line_length
private func networkAoip48kLoopbackSampleRate() -> SampleRateLoopbackResult {
    SampleRateLoopbackResult(sampleRateHertz: 48_000, supported: true, unsupportedReason: nil, modeResults: [networkAoipRejectedMode(48_000, 8, reason: "experimental 8-frame mode separate long-run evidence"), networkAoipAcceptedMode(.init(sampleRate: 48_000, frames: 16, stable: false, oneWayMilliseconds: 2.1, p99: 420, max: 900, missed: 3, underruns: 1)), networkAoipAcceptedMode(.init(sampleRate: 48_000, frames: 32, stable: true, oneWayMilliseconds: 2.55, p99: 240, max: 380)), networkAoipAcceptedMode(.init(sampleRate: 48_000, frames: 64, stable: true, oneWayMilliseconds: 3.2, p99: 210, max: 320)), networkAoipAcceptedMode(.init(sampleRate: 48_000, frames: 128, stable: true, oneWayMilliseconds: 4.0, p99: 190, max: 260))])
}

private func networkAoip96kLoopbackSampleRate() -> SampleRateLoopbackResult {
    SampleRateLoopbackResult(sampleRateHertz: 96_000, supported: true, unsupportedReason: nil, modeResults: [networkAoipRejectedMode(96_000, 8, reason: "experimental 8-frame mode requires separate long-run evidence"), networkAoipRejectedMode(96_000, 16, reason: "device rejected 16-frame mode at 96 kHz"), networkAoipAcceptedMode(.init(sampleRate: 96_000, frames: 32, stable: false, oneWayMilliseconds: 2.35, p99: 500, max: 1_100, missed: 2, underruns: 1)), networkAoipAcceptedMode(.init(sampleRate: 96_000, frames: 64, stable: true, oneWayMilliseconds: 2.8, p99: 220, max: 340)), networkAoipAcceptedMode(.init(sampleRate: 96_000, frames: 128, stable: true, oneWayMilliseconds: 3.55, p99: 200, max: 290))])
}

private func networkAoip192kLoopbackSampleRate() -> SampleRateLoopbackResult {
    SampleRateLoopbackResult(sampleRateHertz: 192_000, supported: false, unsupportedReason: "measured device did not report 192 kHz support", modeResults: [])
}
// swiftlint:enable line_length
