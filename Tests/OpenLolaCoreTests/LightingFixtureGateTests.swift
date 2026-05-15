import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lightingFixtureGateFixtureDecodesAndValidates() throws {
    let report = try loadLightingGateFixture(named: "lighting-gate-partial")

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.standards.contains { $0.protocolName == .sacn && $0.document.contains("E1.31-2025") })
    #expect(report.standards.contains { $0.protocolName == .artNet && $0.document.contains("Art-Net 4") })
    #expect(report.probe.interopTarget == .qlcPlus)
    #expect(report.policy.allowedUniverses.map(\.universe) == [1])
}

@Test
func lightingFixtureGateBlocksOutputUntilExplicitlyArmed() throws {
    var policy = try LightingFixtureGateSyntheticSmoke.run().policy
    policy.isolatedNetworkVerified = true
    policy.explicitlyArmed = false

    let decision = policy.decision(for: sacnLoopbackRequest())

    #expect(decision.canTransmit == false)
    #expect(decision.state == .hold)
    #expect(decision.reason == .outputNotArmed)
}

@Test
func lightingFixtureGateBlocksOutputUntilFailurePolicyIsComplete() throws {
    var policy = try LightingFixtureGateSyntheticSmoke.run().policy
    policy.isolatedNetworkVerified = true
    policy.explicitlyArmed = true
    policy.failurePolicy.blackoutOnOperatorTrigger = false

    let decision = policy.decision(for: sacnLoopbackRequest())

    #expect(decision.canTransmit == false)
    #expect(decision.state == .blackout)
    #expect(decision.reason == .failurePolicyIncomplete)
}

@Test
func lightingFixtureGateBlocksSharedCampusNetworkEvenWhenArmed() throws {
    var policy = try LightingFixtureGateSyntheticSmoke.run().policy
    policy.isolatedNetworkVerified = true
    policy.explicitlyArmed = true
    policy.allowedUniverses = [
        LightingUniversePolicy(
            protocolName: .sacn,
            universe: 1,
            networkMode: .campusNetwork,
            destinationAddress: "192.0.2.40",
            port: LightingControlProtocol.sacn.defaultPort,
            maxRefreshRateHertz: 40,
            fullUniverseOutput: true
        )
    ]

    let decision = policy.decision(for: LightingOutputRequest(
        protocolName: .sacn,
        universe: 1,
        networkMode: .campusNetwork,
        destinationAddress: "192.0.2.40",
        port: LightingControlProtocol.sacn.defaultPort
    ))

    #expect(decision.canTransmit == false)
    #expect(decision.state == .drop)
    #expect(decision.reason == .networkNotIsolated)
}

@Test
func lightingFixtureGateReportsAllSimultaneousBlockingReasons() throws {
    var policy = try LightingFixtureGateSyntheticSmoke.run().policy
    policy.isolatedNetworkVerified = false
    policy.explicitlyArmed = true
    policy.failurePolicy.blackoutOnOperatorTrigger = false

    let decision = policy.decision(for: sacnLoopbackRequest())

    #expect(decision.canTransmit == false)
    #expect(decision.reason == .networkNotIsolated)
    #expect(decision.reasons.contains(.networkNotIsolated))
    #expect(decision.reasons.contains(.failurePolicyIncomplete))
}

@Test
func lightingFixtureGateAllowsOnlyArmedIsolatedAllowedUniverse() throws {
    var policy = try LightingFixtureGateSyntheticSmoke.run().policy
    policy.isolatedNetworkVerified = true
    policy.explicitlyArmed = true

    let allowed = policy.decision(for: sacnLoopbackRequest())
    let blocked = policy.decision(for: LightingOutputRequest(
        protocolName: .sacn,
        universe: 2,
        networkMode: .loopbackUnicast,
        destinationAddress: "127.0.0.1",
        port: LightingControlProtocol.sacn.defaultPort
    ))

    #expect(allowed.canTransmit)
    #expect(allowed.state == .output)
    #expect(blocked.canTransmit == false)
    #expect(blocked.reason == .universeNotAllowed)
}

@Test
func lightingFixtureGateRejectsPassWithoutReviewedStandards() throws {
    var report = try passCandidateReport()
    report.standards[0].status = .pending

    #expect(throws: LightingFixtureGateValidationError.passWithoutReviewedStandards(.sacn)) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsPassWithoutPacketCapture() throws {
    var report = try passCandidateReport()
    report.probe.packetCapture.captured = false
    report.probe.packetCapture.packetCount = 0
    report.probe.packetCapture.universesObserved = []

    #expect(throws: LightingFixtureGateValidationError.passWithoutPacketCapture) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateAllowsObservedUniverseSetWithoutOrderSensitivity() throws {
    var report = try passCandidateReport()
    report.workflow?.notes = "OSC cue handoff completed by the local QLC+ owner."
    report.probe.packetCapture.universesObserved = [1, 1]

    try report.validate()

    #expect(Set(report.probe.packetCapture.universesObserved) == [1])
    #expect(report.verdict == .pass)
}

@Test
func lightingFixtureGateRejectsPassWithBroadcastWhenPolicyDisallowsIt() throws {
    var report = try passCandidateReport()
    report.probe.request.networkMode = .directedBroadcast
    report.probe.request.destinationAddress = "192.168.10.255"
    report.probe.packetCapture.broadcastPackets = 12

    #expect(throws: LightingFixtureGateValidationError.passWithBlockedGate(.broadcastNotAllowed)) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsPassWithoutDmxOutputActivity() throws {
    var report = try passCandidateReport()
    report.probe.dmx.maxLevel = 0

    #expect(throws: LightingFixtureGateValidationError.passWithoutDmxOutputActivity) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsInvertedDmxLevelRange() throws {
    var report = try passCandidateReport()
    report.probe.dmx.minLevel = 200
    report.probe.dmx.maxLevel = 100

    #expect(throws: LightingFixtureGateValidationError.invalidDmxLevelRange(minLevel: 200, maxLevel: 100)) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsPassWithRealtimeFixtureLookup() throws {
    var report = try passCandidateReport()
    report.fixtureMetadata.realtimeLookupAllowed = true

    #expect(throws: LightingFixtureGateValidationError.passAllowsRealtimeFixtureLookup) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsPassWithAudioP99Increase() throws {
    var report = try passCandidateReport()
    report.audioImpact.lightingCallbackP99Microseconds = 81

    #expect(throws: LightingFixtureGateValidationError.passIncreasesAudioP99(
        baseline: 80,
        lighting: 81
    )) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsUnorderedBaselineAudioCallbackMetrics() throws {
    var report = try passCandidateReport()
    report.audioImpact.baselineCallbackP99Microseconds = 96

    #expect(throws: LightingFixtureGateValidationError.unorderedAudioCallbackMetrics("baseline")) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsUnorderedLightingAudioCallbackMetrics() throws {
    var report = try passCandidateReport()
    report.audioImpact.lightingCallbackP99Microseconds = 96

    #expect(throws: LightingFixtureGateValidationError.unorderedAudioCallbackMetrics("lighting")) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsPassWithPlayoutTargetChange() throws {
    var report = try passCandidateReport()
    report.audioImpact.lightingPlayoutTargetFrames = 48

    #expect(throws: LightingFixtureGateValidationError.passChangesAudioPlayoutTarget(
        baseline: 32,
        lighting: 48
    )) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateSyntheticSmokeEmitsPartialReport() throws {
    let report = try LightingFixtureGateSyntheticSmoke.run()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.runMode == .synthetic)
    #expect(report.policy.explicitlyArmed == false)
    #expect(report.probe.packetCapture.captured == false)
}

@Test
func lightingGateRunConfigurationParsesRequiredArguments() throws {
    let configuration = try LightingGateRunConfiguration.parse([
        "--audio-baseline", "m05-route-baseline-required",
        "--osc-cue-report", "m11-osc-cue-required",
        "--protocol", "sacn",
        "--interop-target", "qlcPlus",
        "--universe", "1",
        "--network-mode", "loopbackUnicast",
        "--destination", "127.0.0.1",
        "--port", "5568",
        "--isolated-network", "true",
        "--explicitly-armed", "false",
        "--capture-tool", "not-run",
        "--capture-point", "not-run",
        "--duration-seconds", "0",
        "--output", "reports/m12-lighting-gate-run.json",
    ])

    #expect(configuration.audioBaselineReportId == "m05-route-baseline-required")
    #expect(configuration.oscCueReportId == "m11-osc-cue-required")
    #expect(configuration.protocolName == .sacn)
    #expect(configuration.interopTarget == .qlcPlus)
    #expect(configuration.universe == 1)
    #expect(configuration.networkMode == .loopbackUnicast)
    #expect(configuration.destinationAddress == "127.0.0.1")
    #expect(configuration.port == 5_568)
    #expect(configuration.isolatedNetworkVerified == true)
    #expect(configuration.explicitlyArmed == false)
    #expect(configuration.captureTool == "not-run")
    #expect(configuration.capturePoint == "not-run")
    #expect(configuration.durationSeconds == 0)
    #expect(configuration.outputPath == "reports/m12-lighting-gate-run.json")
}

@Test
func lightingGateRunConfigurationRejectsUnknownInteropTarget() {
    #expect(throws: LightingGateRunConfigurationError.invalidInteropTarget("maLighting")) {
        _ = try LightingGateRunConfiguration.parse([
            "--audio-baseline", "m05-route-baseline-required",
            "--osc-cue-report", "m11-osc-cue-required",
            "--protocol", "sacn",
            "--interop-target", "maLighting",
            "--universe", "1",
            "--network-mode", "loopbackUnicast",
            "--destination", "127.0.0.1",
            "--port", "5568",
            "--isolated-network", "true",
            "--explicitly-armed", "false",
            "--capture-tool", "not-run",
            "--capture-point", "not-run",
            "--duration-seconds", "0",
            "--output", "reports/m12-lighting-gate-run.json",
        ])
    }
}

@Test
func lightingGateRunConfigurationRejectsUnknownCaptureTool() {
    #expect(throws: LightingGateRunConfigurationError.invalidCaptureTool("tcpdmp")) {
        _ = try LightingGateRunConfiguration.parse([
            "--audio-baseline", "m05-route-baseline-required",
            "--osc-cue-report", "m11-osc-cue-required",
            "--protocol", "sacn",
            "--interop-target", "qlcPlus",
            "--universe", "1",
            "--network-mode", "loopbackUnicast",
            "--destination", "127.0.0.1",
            "--port", "5568",
            "--isolated-network", "true",
            "--explicitly-armed", "false",
            "--capture-tool", "tcpdmp",
            "--capture-point", "en0",
            "--duration-seconds", "0",
            "--output", "reports/m12-lighting-gate-run.json",
        ])
    }
}

@Test
func lightingGateRunConfigurationRejectsZeroUniverse() {
    #expect(throws: LightingGateRunConfigurationError.nonPositiveArgument("--universe")) {
        _ = try LightingGateRunConfiguration.parse([
            "--audio-baseline", "m05-route-baseline-required",
            "--osc-cue-report", "m11-osc-cue-required",
            "--protocol", "sacn",
            "--interop-target", "qlcPlus",
            "--universe", "0",
            "--network-mode", "loopbackUnicast",
            "--destination", "127.0.0.1",
            "--port", "5568",
            "--isolated-network", "true",
            "--explicitly-armed", "false",
            "--capture-tool", "not-run",
            "--capture-point", "not-run",
            "--duration-seconds", "0",
            "--output", "reports/m12-lighting-gate-run.json",
        ])
    }
}

@Test
func lightingGateRunnerThrowsForInvalidDirectCaptureToolConfiguration() {
    let configuration = LightingGateRunConfiguration(
        audioBaselineReportId: "m05-route-baseline-required",
        oscCueReportId: "m11-osc-cue-required",
        protocolName: .sacn,
        interopTarget: .qlcPlus,
        universe: 1,
        networkMode: .loopbackUnicast,
        destinationAddress: "127.0.0.1",
        port: LightingControlProtocol.sacn.defaultPort,
        isolatedNetworkVerified: true,
        explicitlyArmed: false,
        captureTool: "tcpdmp",
        capturePoint: "en0",
        durationSeconds: 1,
        outputPath: "reports/m12-lighting-gate-run.json"
    )

    #expect(throws: LightingGateRunError.invalidCaptureTool("tcpdmp")) {
        _ = try LightingGateRunner.run(configuration: configuration)
    }
}

@Test
func lightingGateRunnerBuildsPartialSafetyHandoffReport() throws {
    let configuration = LightingGateRunConfiguration(
        audioBaselineReportId: "m05-route-baseline-required",
        oscCueReportId: "m11-osc-cue-required",
        protocolName: .sacn,
        interopTarget: .qlcPlus,
        universe: 1,
        networkMode: .loopbackUnicast,
        destinationAddress: "127.0.0.1",
        port: LightingControlProtocol.sacn.defaultPort,
        isolatedNetworkVerified: true,
        explicitlyArmed: false,
        captureTool: "not-run",
        capturePoint: "not-run",
        durationSeconds: 0,
        outputPath: "reports/m12-lighting-gate-run.json"
    )

    let report = try LightingGateRunner.run(configuration: configuration)

    try report.validate()

    let decision = report.policy.decision(for: report.probe.request)
    #expect(report.id == "m12-lighting-gate-run")
    #expect(report.runMode == .measured)
    #expect(report.verdict == .partial)
    #expect(report.audioImpact.baselineReportId == "m05-route-baseline-required")
    #expect(report.workflow?.cueTransport == .oscPeerToPeer)
    #expect(report.workflow?.oscCueReportId == "m11-osc-cue-required")
    #expect(report.workflow?.localFixtureOwner == .qlcPlus)
    #expect(report.workflow?.directFixtureStreamingOnPerformanceLink == false)
    #expect(report.probe.interopTarget == .qlcPlus)
    #expect(report.policy.isolatedNetworkVerified == true)
    #expect(report.policy.explicitlyArmed == false)
    #expect(report.probe.packetCapture.captured == false)
    #expect(decision.canTransmit == false)
    #expect(decision.reason == .outputNotArmed)
}

@Test
func lightingGateRunnerDoesNotMarkCaptureWithoutPackets() throws {
    let configuration = LightingGateRunConfiguration(
        audioBaselineReportId: "m05-route-baseline-required",
        oscCueReportId: "m11-osc-cue-required",
        protocolName: .sacn,
        interopTarget: .qlcPlus,
        universe: 1,
        networkMode: .loopbackUnicast,
        destinationAddress: "127.0.0.1",
        port: LightingControlProtocol.sacn.defaultPort,
        isolatedNetworkVerified: true,
        explicitlyArmed: false,
        captureTool: "tcpdump",
        capturePoint: "en0",
        durationSeconds: 1,
        outputPath: "reports/m12-lighting-gate-run.json"
    )

    let report = try LightingGateRunner.run(configuration: configuration)

    try report.validate()

    #expect(report.probe.packetCapture.captured == false)
    #expect(report.probe.packetCapture.packetCount == 0)
}

@Test
func lightingFixtureGateRejectsPassWithoutCueWorkflow() throws {
    var report = try passCandidateReport()
    report.workflow = nil

    #expect(throws: LightingFixtureGateValidationError.passWithoutCueWorkflow) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsPassWithoutOscCueReport() throws {
    var report = try passCandidateReport()
    report.workflow?.oscCueReportId = ""

    #expect(throws: LightingFixtureGateValidationError.passWithoutOscCueReport) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateAllowsPartialWorkflowWithoutOscCueReport() throws {
    var report = try loadLightingGateFixture(named: "lighting-gate-partial")
    report.workflow = LightingCueWorkflowEvidence(
        cueTransport: .oscPeerToPeer,
        oscCueReportId: "",
        firstPeerKind: .qlcPlus,
        localFixtureOwner: .qlcPlus,
        directFixtureStreamingOnPerformanceLink: false,
        notes: "Partial run records the intended workflow before OSC peer evidence exists."
    )

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.workflow?.oscCueReportId == "")
}

@Test
func lightingFixtureGateRejectsPassWithNoLocalFixtureOwner() throws {
    var report = try passCandidateReport()
    report.workflow?.localFixtureOwner = .none

    #expect(throws: LightingFixtureGateValidationError.passWithoutLocalFixtureOwner) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsPassWithFixtureOwnerMismatch() throws {
    var report = try passCandidateReport()
    report.workflow?.localFixtureOwner = .ola

    #expect(throws: LightingFixtureGateValidationError.passWithFixtureOwnerMismatch(
        expected: .qlcPlus,
        actual: .ola
    )) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsPassWithDirectFixtureStreamingOnPerformanceLink() throws {
    var report = try passCandidateReport()
    report.workflow?.directFixtureStreamingOnPerformanceLink = true

    #expect(throws: LightingFixtureGateValidationError.passWithDirectFixtureStreamingOnPerformanceLink) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsPassWithPlaceholderWorkflowField() throws {
    var report = try passCandidateReport()
    report.workflow?.oscCueReportId = "m11-osc-cue-required"

    #expect(throws: LightingFixtureGateValidationError.passWithPlaceholderWorkflowField(
        "workflow.oscCueReportId"
    )) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateRejectsPassWithEmptyWorkflowNotesAsEmptyField() throws {
    var report = try passCandidateReport()
    report.workflow?.notes = ""

    #expect(throws: LightingFixtureGateValidationError.emptyField("workflow.notes")) {
        try report.validate()
    }
}

@Test
func lightingFixtureGateJSONRoundTripPreservesReport() throws {
    let report = try loadLightingGateFixture(named: "lighting-gate-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try LightingFixtureGateReport.decode(from: jsonData)

    #expect(decoded == report)
}

private func passCandidateReport() throws -> LightingFixtureGateReport {
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
        captured: true,
        tool: "tcpdump",
        capturePoint: "lo0",
        packetCount: 12,
        universesObserved: [1],
        broadcastPackets: 0,
        multicastPackets: 0,
        captureArtifact: "docs/mac-port/reports/m12-loopback.pcapng",
        notes: "Synthetic PASS candidate used by unit tests only."
    )
    report.probe.durationSeconds = 1
    report.probe.dmx.maxLevel = 255
    return report
}

private func sacnLoopbackRequest() -> LightingOutputRequest {
    LightingOutputRequest(
        protocolName: .sacn,
        universe: 1,
        networkMode: .loopbackUnicast,
        destinationAddress: "127.0.0.1",
        port: LightingControlProtocol.sacn.defaultPort
    )
}

private func loadLightingGateFixture(named name: String) throws -> LightingFixtureGateReport {
    let url = try lightingGateFixtureURL(named: name)
    return try LightingFixtureGateReport.decode(from: Data(contentsOf: url))
}

private func lightingGateFixtureURL(named name: String) throws -> URL {
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
