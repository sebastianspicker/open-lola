// Shared Lighting fixture gate tests builders keep multi-file test scenarios deterministic.
import Foundation
import Testing

@testable import OpenLolaCore

func lightingFixtureGatePassCandidateReport() throws -> LightingFixtureGateReport {
    var report = try loadLightingGateFixture(named: "lighting-gate-partial")
    report.verdict = .pass
    report.workflow = LightingCueWorkflowEvidence(
        cueTransport: .oscPeerToPeer,
        oscCueReportId: "m11-osc-cue-pass",
        firstPeerKind: .qlcPlus,
        localFixtureOwner: .qlcPlus,
        directFixtureStreamingOnPerformanceLink: false,
        notes: "PASS candidate keeps fixture output owned by QLC+ after OSC cue handoff."
    )
    report.policy.isolatedNetworkVerified = true
    report.policy.explicitlyArmed = true
    report.probe.packetCapture = LightingPacketCaptureReport(
        summary: LightingPacketCaptureSummary(captured: true, packetCount: 12, universesObserved: [1], broadcastPackets: 0, multicastPackets: 0),
        provenance: LightingPacketCaptureProvenance(tool: "tcpdump", capturePoint: "lo0", captureArtifact: "private/reports/m12-loopback.pcapng", notes: "Synthetic PASS candidate used by unit tests only.")
    )
    report.probe.durationSeconds = 1
    report.probe.dmx.maxLevel = 255
    return report
}

func expectLightingFixtureGateError(
    _ expected: LightingFixtureGateValidationError,
    mutate: (inout LightingFixtureGateReport) throws -> Void
) throws {
    var report = try lightingFixtureGatePassCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

func sacnLoopbackRequest() -> LightingOutputRequest {
    LightingOutputRequest(
        protocolName: .sacn,
        universe: 1,
        networkMode: .loopbackUnicast,
        destinationAddress: "127.0.0.1",
        port: LightingControlProtocol.sacn.defaultPort
    )
}

func lightingGateArguments(
    interopTarget: String = "qlcPlus",
    universe: String = "1",
    captureTool: String = "not-run",
    capturePoint: String = "not-run"
) -> [String] {
    [
        "--audio-baseline", "m05-route-baseline-required",
        "--osc-cue-report", "m11-osc-cue-required",
        "--protocol", "sacn",
        "--interop-target", interopTarget,
        "--universe", universe,
        "--network-mode", "loopbackUnicast",
        "--destination", "127.0.0.1",
        "--port", "5568",
        "--isolated-network", "true",
        "--explicitly-armed", "false",
        "--capture-tool", captureTool,
        "--capture-point", capturePoint,
        "--duration-seconds", "0",
        "--output", "reports/m12-lighting-gate-run.json"
    ]
}

func loadLightingGateFixture(named name: String) throws -> LightingFixtureGateReport {
    let url = try lightingGateFixtureURL(named: name)
    return try LightingFixtureGateReport.decode(from: Data(contentsOf: url))
}

func lightingGateFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "LightingFixtureGateReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "LightingFixtureGateReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}
