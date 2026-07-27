// Shared Drift PLC fixed target certification fixtures builders keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaCore

func makeDriftPlcFixedTargetCertificationPassCandidate() throws
-> DriftPlcFixedTargetCertificationReport {
    let routeReport = makeCertificationRouteReport()
    let routeCertification = makeRouteCertificationReport(routeReport: routeReport)
    let driftReport = try makeDriftPlcFixedTargetReport(routeReport: routeReport)

    return DriftPlcFixedTargetCertificationReport(
        identity: .init(
            id: "g05-direct-link-fixed-target-certification",
            title: "G05 direct-link fixed-target drift PLC certification",
            capturedAt: "2026-05-02T00:00:00Z"
        ),
        supportingReports: .init(
            routeCertificationReport: routeCertification,
            driftPlcReport: driftReport,
            sourceRealtimeEngineReport: try makeRealtimeEngineReport(routeCertification: routeCertification),
            lolaBaselineComparison: makeLolaBaselineComparison(route: routeReport.route)
        ),
        outcome: .init(
            runMode: .measured,
            runArtifactPath: "private/reports/g05-direct-link-drift-plc.json",
            notTestedReason: nil,
            verdict: .pass,
            notes: "Measured G05 fixed-target certification accepted direct-link baseline."
        )
    )
}

func makeRouteCertificationReport(routeReport: UdpPcmRouteReport) -> MacToMacRouteCertificationReport {
    MacToMacRouteCertificationReport(
        identity: .init(id: "g04-direct-link-certification-measured", title: "Measured G04 direct-link route certification", capturedAt: "2026-05-02T00:00:00Z"),
        configuration: .init(runMode: .measured, packetMode: driftCertificationRoutePacketMode(), sourceRealtimeEngineReportId: "g03-rme-engine-measured"),
        outcome: .init(routes: [
            MacToMacRouteCertificationCandidate(
                routeKind: .directLink,
                label: "direct-link-reference",
                routeReport: routeReport,
                packetCaptureArtifact: "private/reports/captures/direct-link-en5-2026-05-02.pcapng",
                notTestedReason: nil,
                notes: "Measured direct-link route receiver capture."
            ),
            MacToMacRouteCertificationCandidate(
                routeKind: .dedicatedSwitch,
                label: "dedicated-switch-reference",
                routeReport: nil,
                packetCaptureArtifact: nil,
                notTestedReason: "Dedicated switch route not part G05 direct-link baseline.",
                notes: "Deferred until direct-link G05 baseline accepted."
            ),
            MacToMacRouteCertificationCandidate(
                routeKind: .campusPath,
                label: "campus-path-reference",
                routeReport: nil,
                packetCaptureArtifact: nil,
                notTestedReason: "Campus path awaits approved capture point.",
                notes: "Deferred by campus capture question."
            )
        ], verdict: .pass, notes: "Measured direct-link certification G05 baseline input.")
    )
}

func makeDriftPlcFixedTargetReport(
    routeReport: UdpPcmRouteReport
) throws -> DriftPlcReport {
    try DriftPlcFixedTargetRunner.makeReport(
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
}

func makeCertificationRouteReport() -> UdpPcmRouteReport {
    UdpPcmRouteReport(
        identity: .init(
            id: "m05-direct-link-measured-route",
            title: "Measured direct-link UDP PCM route",
            capturedAt: "2026-05-02T00:00:00Z",
            route: driftCertificationRouteIdentity(),
            routeKind: .directLink
        ),
        endpoints: .init(
            sender: driftCertificationRouteEndpoint(
                label: "sender-mac",
                hostName: "sender-mini-a",
                ipAddress: "10.10.20.10"
            ),
            receiver: driftCertificationRouteEndpoint(
                label: "receiver-mac",
                hostName: "receiver-mini-b",
                ipAddress: "10.10.20.11"
            )
        ),
        measurement: .init(
            packetMode: driftCertificationRoutePacketMode(),
            measuredDurationSeconds: 2,
            network: driftCertificationNetworkProfile(),
            metrics: driftCertificationRouteMetrics()
        ),
        outcome: .init(
            verdict: .pass,
            notes: "Measured route report with fixed playout target and capture correlation."
        )
    )
}

func driftCertificationRouteIdentity() -> RouteIdentity {
    RouteIdentity(
        label: "direct-link-reference",
        topology: "mac-to-mac-direct-cable"
    )
}

func driftCertificationRouteEndpoint(
    label: String,
    hostName: String,
    ipAddress: String
) -> UdpPcmRouteEndpoint {
    UdpPcmRouteEndpoint(
        label: label,
        hostName: hostName,
        interfaceName: "en5",
        ipAddress: ipAddress
    )
}

func driftCertificationNetworkProfile() -> UdpPcmNetworkProfile {
    realtimeAudioEngineRouteNetwork()
}

func driftCertificationRouteMetrics() -> UdpPcmRouteMetrics {
    standardMeasuredRouteMetrics()
}

func makeRealtimeEngineReport(
    routeCertification: MacToMacRouteCertificationReport
) throws -> RealtimeAudioEngineReport {
    let rxPolicy = try RxBufferPolicy.direct(
        framesPerPacket: 32,
        sampleRateHertz: 48_000,
        targetPackets: 1
    )
    return RealtimeAudioEngineReport(
        id: "g03-rme-engine-measured",
        title: "Measured G03 RME realtime engine",
        capturedAt: "2026-05-02T00:00:00Z",
        runMode: .measured,
        hardwarePath: .rmeMadi,
        hardware: driftCertificationHardwareIdentity(),
        configuration: driftCertificationRealtimeConfiguration(rxPolicy: rxPolicy),
        safety: driftCertificationCallbackSafety(),
        runtime: driftCertificationRuntimeEvidence(rxPolicy: rxPolicy),
        sourceRmeFastestAudioReport: makeDriftCertificationRmeFastestAudioReport(),
        sourceRouteCertificationReport: routeCertification,
        runArtifactPath: "private/reports/g03-rme-realtime-engine-measured.json",
        verdict: .pass,
        notes: "Measured F02 realtime engine source report for F04 validator tests."
    )
}

func driftCertificationHardwareIdentity() -> HardwareIdentity {
    HardwareIdentity(
        referenceMac: "reference-mac-mini-m2",
        audioInterface: "RME Fireface UFX+ MADI Thunderbolt",
        osVersion: "macOS 15.5 24F74",
        driverVersion: "RME Thunderbolt Driver 4.08"
    )
}

func driftCertificationRealtimeConfiguration(
    rxPolicy: RxBufferPolicy
) -> RealtimeAudioEngineConfiguration {
    standardRealtimeAudioEngineConfiguration(rxBufferPolicy: rxPolicy)
}

func driftCertificationCallbackSafety() -> RealtimeAudioCallbackSafetyChecklist {
    RealtimeAudioCallbackSafetyChecklist(
        noAllocationInCallback: true,
        noLoggingInCallback: true,
        noFileIOInCallback: true,
        noLocksOrUnboundedWaitsInCallback: true,
        noNetworkSetupInCallback: true,
        noReportWritingInCallback: true,
        countersOnlyInCallback: true
    )
}

func driftCertificationRuntimeEvidence(rxPolicy: RxBufferPolicy) -> RealtimeAudioRuntimeEvidence {
    standardRealtimeAudioRuntimeEvidence(rxBufferPolicy: rxPolicy)
}

func driftCertificationRealtimeHandoff(rxPolicy: RxBufferPolicy) -> RealtimeAudioHandoffMetrics {
    standardRealtimeAudioHandoffMetrics(rxBufferPolicy: rxPolicy)
}

func makeLolaBaselineComparison(route: RouteIdentity) -> LolaBaselineComparison {
    measuredFixtureLolaBaseline(route: route, packetMode: driftCertificationRoutePacketMode())
}

func makeDriftCertificationRmeFastestAudioReport() -> RmeFastestAudioPathReport {
    let selectedMode = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: "int16"
    )
    return measuredRmeFastestAudioReport(
        capturedAt: "2026-05-02T00:00:00Z",
        device: driftCertificationRmeMadiDevice(uid: "rme-madi-uid"),
        loopback: driftCertificationRmeEndpointLoopbackReport(selectedMode: selectedMode),
        notes: "Measured RME fastest-audio source report for F04 validator tests."
    )
}

func driftCertificationRmeEndpointLoopbackReport(selectedMode: AudioMode) -> EndpointLoopbackReport {
    EndpointLoopbackReport(identity: .init(id: "m03-rme-loopback-pass-candidate", title: "Measured RME MADI loopback report", capturedAt: "2026-05-02T00:00:00Z"), context: .init(hardware: HardwareIdentity(
            referenceMac: "reference-mac",
            audioInterface: "RME Fireface UFX+ MADI Thunderbolt",
            osVersion: "macOS 15.5 24F74",
            driverVersion: "RME Thunderbolt Driver 4.08"
        ), route: RouteIdentity(
            label: "rme-madi-loopback",
            topology: "single-mac-rme-madi-output-to-input"
        ), device: EndpointLoopbackDevice(
            name: "RME Fireface UFX+ MADI Thunderbolt",
            uid: "rme-madi-uid",
            transportType: "thun",
            clockDomain: 1
        ), selectedMode: selectedMode, sampleRates: driftCertificationSampleRateLoopbackResults(), stabilityRun: driftCertificationEndpointStabilityRun(selectedMode: selectedMode)), outcome: .init(verdict: .pass, notes: "Measured RME loopback source report for F04 validator tests."))
}

func driftCertificationSampleRateLoopbackResults() -> [SampleRateLoopbackResult] {
[
driftCertification48kLoopbackResult(),
driftCertification96kLoopbackResult(),
SampleRateLoopbackResult(
sampleRateHertz: 192_000,
supported: false,
unsupportedReason: "device did not report 192 kHz support",
modeResults: []
)
]
}

func driftCertification48kLoopbackResult() -> SampleRateLoopbackResult {
SampleRateLoopbackResult(
sampleRateHertz: 48_000,
supported: true,
unsupportedReason: nil,
modeResults: [
driftCertificationRejectedMode(
48_000, 8,
reason: "experimental 8-frame mode requires separate long-run evidence"
),
driftCertificationAcceptedMode(.init(
48_000,
16,
stable: false,
oneWayMilliseconds: 2.1,
p99: 420,
max: 900,
missed: 3,
underruns: 1
)),
driftCertificationAcceptedMode(.init(48_000, 32, stable: true, oneWayMilliseconds: 2.55, p99: 240, max: 380)),
driftCertificationAcceptedMode(.init(48_000, 64, stable: true, oneWayMilliseconds: 3.2, p99: 210, max: 320)),
driftCertificationAcceptedMode(.init(48_000, 128, stable: true, oneWayMilliseconds: 4.0, p99: 190, max: 260))
]
)
}
