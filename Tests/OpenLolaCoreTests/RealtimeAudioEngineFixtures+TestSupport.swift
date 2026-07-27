// Shared realtime audio engine fixtures helpers keep related tests deterministic and focused on their contract.
import Foundation
import Testing

@testable import OpenLolaCore

func realtimeAudioEnginePassCandidateReport() throws -> RealtimeAudioEngineReport {
    var report = try loadRealtimeAudioEngineFixture(named: "realtime-audio-engine-partial")
    try configureRealtimeAudioEnginePassCandidateBase(&report)
    configureRealtimeAudioEnginePassCandidateRuntime(&report)
    report.sourceRmeFastestAudioReport = makeRealtimeAudioEngineRmeFastestAudioReport()
    report.sourceRouteCertificationReport = makeRealtimeAudioEngineRouteCertificationReport(
        sourceRealtimeEngineReportId: report.id
    )
    report.runArtifactPath = "private/reports/g03-rme-realtime-engine-measured.json"
    report.verdict = .pass
    report.notes = "Measured RME MADI realtime engine pass candidate."
    return report
}
func configureRealtimeAudioEnginePassCandidateBase(_ report: inout RealtimeAudioEngineReport) throws {
    report.runMode = .measured
    report.hardwarePath = .rmeMadi
    report.hardware = HardwareIdentity(
        referenceMac: "reference-mac-mini-m2",
        audioInterface: "RME MADIface USB",
        osVersion: "macOS 15.5",
        driverVersion: "RME driver 4.16"
    )
    report.configuration.inputDeviceUID = "rme-madi-uid"
    report.configuration.outputDeviceUID = "rme-madi-uid"
    report.configuration.rxBufferPolicy = try .direct(
        framesPerPacket: report.configuration.framesPerBuffer,
        sampleRateHertz: report.configuration.sampleRateHertz,
        targetPackets: 1
    )
}
func configureRealtimeAudioEnginePassCandidateRuntime(_ report: inout RealtimeAudioEngineReport) {
    report.runtime.callback = EndpointCallbackMetrics(latency: .init(p50Microseconds: 50, p95Microseconds: 90, p99Microseconds: 120, maxMicroseconds: 200), events: .init(missedDeadlines: 0, underruns: 0, overruns: 0))
    report.runtime.callbackOwner = .audioDeviceIOProc
    report.runtime.handoff = standardRealtimeAudioHandoffMetrics(
        rxBufferPolicy: report.configuration.rxBufferPolicy!
    )
    report.runtime.udpSocketsPreparedBeforeStart = true
    report.runtime.reportWrittenAfterStop = true
}
func makeRealtimeAudioEngineRmeFastestAudioReport() -> RmeFastestAudioPathReport {
    let selectedMode = AudioMode(
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: "int16"
    )
    return measuredRmeFastestAudioReport(
        capturedAt: "2026-05-03T00:00:00Z",
        device: realtimeAudioEngineRmeMadiDevice(uid: "rme-madi-uid"),
        loopback: realtimeAudioEngineRmeEndpointLoopbackReport(selectedMode: selectedMode),
        notes: "Measured RME fastest-audio source report for F02 validator tests."
    )
}
func realtimeAudioEngineRmeEndpointLoopbackReport(selectedMode: AudioMode) -> EndpointLoopbackReport {
    EndpointLoopbackReport(identity: .init(id: "m03-rme-loopback-pass-candidate", title: "Measured RME MADI loopback report", capturedAt: "2026-05-03T00:00:00Z"), context: .init(hardware: realtimeAudioEngineRmeLoopbackHardware(), route: realtimeAudioEngineRmeLoopbackRoute(), device: realtimeAudioEngineRmeLoopbackDevice(), selectedMode: selectedMode, sampleRates: realtimeAudioEngineRmeLoopbackSampleRates(), stabilityRun: realtimeAudioEngineRmeLoopbackStabilityRun(selectedMode: selectedMode)), outcome: .init(verdict: .pass, notes: "Measured RME loopback source report F02 validator tests."))
}
func realtimeAudioEngineRmeLoopbackHardware() -> HardwareIdentity {
    HardwareIdentity(
        referenceMac: "reference-mac",
        audioInterface: "RME Fireface UFX+ MADI Thunderbolt",
        osVersion: "macOS 15.5 24F74",
        driverVersion: "RME Thunderbolt Driver 4.08"
    )
}
func realtimeAudioEngineRmeLoopbackRoute() -> RouteIdentity {
    RouteIdentity(
        label: "rme-madi-loopback",
        topology: "single-mac-rme-madi-output-to-input"
    )
}
func realtimeAudioEngineRmeLoopbackDevice() -> EndpointLoopbackDevice {
    EndpointLoopbackDevice(
        name: "RME Fireface UFX+ MADI Thunderbolt",
        uid: "rme-madi-uid",
        transportType: "thun",
        clockDomain: 1
    )
}
func realtimeAudioEngineRmeLoopbackSampleRates() -> [SampleRateLoopbackResult] {
    [
        SampleRateLoopbackResult(
            sampleRateHertz: 48_000,
            supported: true,
            unsupportedReason: nil,
            modeResults: realtimeAudioEngineRmeLoopback48kModes()
        ),
        SampleRateLoopbackResult(
            sampleRateHertz: 96_000,
            supported: true,
            unsupportedReason: nil,
            modeResults: realtimeAudioEngineRmeLoopback96kModes()
        ),
        SampleRateLoopbackResult(
            sampleRateHertz: 192_000,
            supported: false,
            unsupportedReason: "device did not report 192 kHz support",
            modeResults: []
        )
    ]
}
func realtimeAudioEngineRmeLoopback48kModes() -> [EndpointModeResult] {
    [
        realtimeAudioEngineRejectedMode(
            48_000,
            8,
            reason: "experimental 8-frame mode requires separate long-run evidence"
        ),
        realtimeAudioEngineAcceptedMode(
            .init(sampleRate: 48_000, frames: 16, stable: false, oneWayMilliseconds: 2.1, p99: 420, max: 900, missed: 3, underruns: 1)
        ),
        realtimeAudioEngineAcceptedMode(.init(sampleRate: 48_000, frames: 32, stable: true, oneWayMilliseconds: 2.55, p99: 240, max: 380)),
        realtimeAudioEngineAcceptedMode(.init(sampleRate: 48_000, frames: 64, stable: true, oneWayMilliseconds: 3.2, p99: 210, max: 320)),
        realtimeAudioEngineAcceptedMode(.init(sampleRate: 48_000, frames: 128, stable: true, oneWayMilliseconds: 4.0, p99: 190, max: 260))
    ]
}
func realtimeAudioEngineRmeLoopback96kModes() -> [EndpointModeResult] {
    [
        realtimeAudioEngineRejectedMode(
            96_000,
            8,
            reason: "experimental 8-frame mode requires separate long-run evidence"
        ),
        realtimeAudioEngineRejectedMode(96_000, 16, reason: "device rejected 16-frame mode at 96 kHz"),
        realtimeAudioEngineAcceptedMode(
            .init(sampleRate: 96_000, frames: 32, stable: false, oneWayMilliseconds: 2.35, p99: 500, max: 1_100, missed: 2, underruns: 1)
        ),
        realtimeAudioEngineAcceptedMode(.init(sampleRate: 96_000, frames: 64, stable: true, oneWayMilliseconds: 2.8, p99: 220, max: 340)),
        realtimeAudioEngineAcceptedMode(.init(sampleRate: 96_000, frames: 128, stable: true, oneWayMilliseconds: 3.55, p99: 200, max: 290))
    ]
}
func realtimeAudioEngineRmeLoopbackStabilityRun(selectedMode: AudioMode) -> EndpointStabilityRun {
    measuredFixtureEndpointStabilityRun(
        selectedMode: selectedMode,
        notes: "30-minute fixed-target run"
    )
}

func realtimeAudioEngineAcceptedMode(
    _ fixture: MeasuredFixtureAcceptedMode
) -> EndpointModeResult {
    var measuredFixture = fixture
    measuredFixture.unstableNotes = "accepted unstable measured row"
    return measuredFixtureAcceptedMode(measuredFixture)
}
func realtimeAudioEngineRejectedMode(_ sampleRate: Int, _ frames: Int, reason: String) -> EndpointModeResult {
    measuredFixtureRejectedMode(sampleRate, frames, reason: reason)
}
func makeRealtimeAudioEngineRouteCertificationReport(
    sourceRealtimeEngineReportId: String
) -> MacToMacRouteCertificationReport {
    let routeReport = makeRealtimeAudioEngineRouteReport()
    return MacToMacRouteCertificationReport(
        identity: .init(
            id: "g04-direct-link-certification-measured",
            title: "Measured G04 direct-link route certification",
            capturedAt: "2026-05-03T00:00:00Z"
        ),
        configuration: .init(
            runMode: .measured,
            packetMode: realtimeAudioEngineRoutePacketMode(),
            sourceRealtimeEngineReportId: sourceRealtimeEngineReportId
        ),
        outcome: .init(
            routes: realtimeAudioEngineRouteCertificationCandidates(routeReport: routeReport),
            verdict: .pass,
            notes: "Measured direct-link certification for F02 baseline input."
        )
    )
}

func realtimeAudioEngineRouteCertificationCandidates(
    routeReport: UdpPcmRouteReport
) -> [MacToMacRouteCertificationCandidate] {
    [
        MacToMacRouteCertificationCandidate(
            routeKind: .directLink,
            label: "direct-link-reference",
            routeReport: routeReport,
            packetCaptureArtifact: "private/reports/captures/direct-link-en5-2026-05-03.pcapng",
            notTestedReason: nil,
            notes: "Measured direct-link route with receiver capture."
        ),
        MacToMacRouteCertificationCandidate(
            routeKind: .dedicatedSwitch,
            label: "dedicated-switch-reference",
            routeReport: nil,
            packetCaptureArtifact: nil,
            notTestedReason: "Dedicated switch route was not part of this F02 direct-link baseline.",
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
func makeRealtimeAudioEngineRouteReport() -> UdpPcmRouteReport {
    UdpPcmRouteReport(
        identity: .init(
            id: "m05-direct-link-measured-route",
            title: "Measured direct-link UDP PCM route",
            capturedAt: "2026-05-03T00:00:00Z",
            route: RouteIdentity(
                label: "direct-link-reference",
                topology: "mac-to-mac-direct-cable"
            ),
            routeKind: .directLink
        ),
        endpoints: .init(
            sender: realtimeAudioEngineRouteSender(),
            receiver: realtimeAudioEngineRouteReceiver()
        ),
        measurement: .init(
            packetMode: realtimeAudioEngineRoutePacketMode(),
            measuredDurationSeconds: 2,
            network: realtimeAudioEngineRouteNetwork(),
            metrics: realtimeAudioEngineRouteMetrics()
        ),
        outcome: .init(
            verdict: .pass,
            notes: "Measured direct-link route for F02 validator tests."
        )
    )
}
func realtimeAudioEngineRouteSender() -> UdpPcmRouteEndpoint {
    UdpPcmRouteEndpoint(
        label: "sender-mac",
        hostName: "sender-mini-a",
        interfaceName: "en5",
        ipAddress: "10.10.20.10"
    )
}
func realtimeAudioEngineRouteReceiver() -> UdpPcmRouteEndpoint {
    UdpPcmRouteEndpoint(
        label: "receiver-mac",
        hostName: "receiver-mini-b",
        interfaceName: "en5",
        ipAddress: "10.10.20.11"
    )
}
func realtimeAudioEngineRouteNetwork() -> UdpPcmNetworkProfile {
    UdpPcmNetworkProfile(
        linkRateMbps: 1_000,
        vlan: "none",
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
func realtimeAudioEngineRouteMetrics() -> UdpPcmRouteMetrics {
    var metrics = standardMeasuredRouteMetrics()
    metrics.packetAge.maxMicroseconds = 320
    metrics.callbackP99Microseconds = nil
    metrics.callbackMaxMicroseconds = nil
    metrics.jitterP99Microseconds = 70
    return metrics
}
func realtimeAudioEngineRoutePacketMode() -> UdpPcmPacketMode {
    measuredFixturePacketMode()
}
func realtimeAudioEngineRmeMadiDevice(uid: String) -> CoreAudioDeviceInventory {
    measuredFixtureRmeMadiDevice(
        uid: uid,
        transportType: "thun",
        diagnosticNotes: ["test fixture"]
    )
}
func loadRealtimeAudioEngineFixture(named name: String) throws -> RealtimeAudioEngineReport {
    let url = try realtimeAudioEngineFixtureURL(named: name)
    return try RealtimeAudioEngineReport.decode(from: Data(contentsOf: url))
}
func realtimeAudioEngineFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "RealtimeAudioEngineReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "RealtimeAudioEngineReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}
