import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lightingFixtureGateBlocksUnsafeStatesAndAllowsOnlyArmedIsolatedUniverse() throws {
    var unarmedPolicy = try LightingFixtureGateSyntheticSmoke.run().policy
    unarmedPolicy.isolatedNetworkVerified = true
    unarmedPolicy.explicitlyArmed = false

    let unarmed = unarmedPolicy.decision(for: sacnLoopbackRequest())

    #expect(unarmed.canTransmit == false)
    #expect(unarmed.state == .hold)
    #expect(unarmed.reason == .outputNotArmed)

    var incompleteFailurePolicy = try LightingFixtureGateSyntheticSmoke.run().policy
    incompleteFailurePolicy.isolatedNetworkVerified = true
    incompleteFailurePolicy.explicitlyArmed = true
    incompleteFailurePolicy.failurePolicy.blackoutOnOperatorTrigger = false

    let incompleteFailure = incompleteFailurePolicy.decision(for: sacnLoopbackRequest())

    #expect(incompleteFailure.canTransmit == false)
    #expect(incompleteFailure.state == .blackout)
    #expect(incompleteFailure.reason == .failurePolicyIncomplete)

    var campusPolicy = try LightingFixtureGateSyntheticSmoke.run().policy
    campusPolicy.isolatedNetworkVerified = true
    campusPolicy.explicitlyArmed = true
    campusPolicy.allowedUniverses = [
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

    let campus = campusPolicy.decision(for: LightingOutputRequest(
        protocolName: .sacn,
        universe: 1,
        networkMode: .campusNetwork,
        destinationAddress: "192.0.2.40",
        port: LightingControlProtocol.sacn.defaultPort
    ))

    #expect(campus.canTransmit == false)
    #expect(campus.state == .drop)
    #expect(campus.reason == .networkNotIsolated)

    var simultaneousPolicy = try LightingFixtureGateSyntheticSmoke.run().policy
    simultaneousPolicy.isolatedNetworkVerified = false
    simultaneousPolicy.explicitlyArmed = true
    simultaneousPolicy.failurePolicy.blackoutOnOperatorTrigger = false

    let simultaneous = simultaneousPolicy.decision(for: sacnLoopbackRequest())

    #expect(simultaneous.canTransmit == false)
    #expect(simultaneous.reason == .networkNotIsolated)
    #expect(simultaneous.reasons.contains(.networkNotIsolated))
    #expect(simultaneous.reasons.contains(.failurePolicyIncomplete))

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
func lightingFixtureGateAllowsObservedUniverseSetWithoutOrderSensitivity() throws {
    var report = try passCandidateReport()
    report.workflow?.notes = "OSC cue handoff completed by the local QLC+ owner."
    report.probe.packetCapture.universesObserved = [1, 1]

    try report.validate()

    #expect(Set(report.probe.packetCapture.universesObserved) == [1])
    #expect(report.verdict == .pass)
}

@Test
func lightingFixtureGateRejectsInvalidPassEvidence() throws {
    try expectLightingFixtureGateError(.passWithoutReviewedStandards(.sacn)) {
        $0.standards[0].status = .pending
    }
    try expectLightingFixtureGateError(.passWithoutPacketCapture) {
        $0.probe.packetCapture.captured = false
        $0.probe.packetCapture.packetCount = 0
        $0.probe.packetCapture.universesObserved = []
    }
    try expectLightingFixtureGateError(.passWithBlockedGate(.broadcastNotAllowed)) {
        $0.probe.request.networkMode = .directedBroadcast
        $0.probe.request.destinationAddress = "192.168.10.255"
        $0.probe.packetCapture.broadcastPackets = 12
    }
    try expectLightingFixtureGateError(.passWithoutDmxOutputActivity) {
        $0.probe.dmx.maxLevel = 0
    }
    try expectLightingFixtureGateError(.invalidDmxLevelRange(minLevel: 200, maxLevel: 100)) {
        $0.probe.dmx.minLevel = 200
        $0.probe.dmx.maxLevel = 100
    }
    try expectLightingFixtureGateError(.passAllowsRealtimeFixtureLookup) {
        $0.fixtureMetadata.realtimeLookupAllowed = true
    }
    try expectLightingFixtureGateError(.passIncreasesAudioP99(baseline: 80, lighting: 81)) {
        $0.audioImpact.lightingCallbackP99Microseconds = 81
    }
    try expectLightingFixtureGateError(.unorderedAudioCallbackMetrics("baseline")) {
        $0.audioImpact.baselineCallbackP99Microseconds = 96
    }
    try expectLightingFixtureGateError(.unorderedAudioCallbackMetrics("lighting")) {
        $0.audioImpact.lightingCallbackP99Microseconds = 96
    }
    try expectLightingFixtureGateError(.passChangesAudioPlayoutTarget(baseline: 32, lighting: 48)) {
        $0.audioImpact.lightingPlayoutTargetFrames = 48
    }
    try expectLightingFixtureGateError(.passWithoutCueWorkflow) {
        $0.workflow = nil
    }
    try expectLightingFixtureGateError(.passWithoutOscCueReport) {
        $0.workflow?.oscCueReportId = ""
    }
    try expectLightingFixtureGateError(.passWithoutLocalFixtureOwner) {
        $0.workflow?.localFixtureOwner = .none
    }
    try expectLightingFixtureGateError(.passWithFixtureOwnerMismatch(expected: .qlcPlus, actual: .ola)) {
        $0.workflow?.localFixtureOwner = .ola
    }
    try expectLightingFixtureGateError(.passWithDirectFixtureStreamingOnPerformanceLink) {
        $0.workflow?.directFixtureStreamingOnPerformanceLink = true
    }
    try expectLightingFixtureGateError(.passWithPlaceholderWorkflowField("workflow.oscCueReportId")) {
        $0.workflow?.oscCueReportId = "m11-osc-cue-required"
    }
    try expectLightingFixtureGateError(.emptyField("workflow.notes")) {
        $0.workflow?.notes = ""
    }
}

@Test
func lightingGateRunConfigurationAndRunnerPreservePartialSafetyHandoffTruthfulness() throws {
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

    #expect(throws: LightingGateRunConfigurationError.invalidInteropTarget("maLighting")) {
        _ = try LightingGateRunConfiguration.parse(lightingGateArguments(
            interopTarget: "maLighting"
        ))
    }
    #expect(throws: LightingGateRunConfigurationError.invalidCaptureTool("tcpdmp")) {
        _ = try LightingGateRunConfiguration.parse(lightingGateArguments(
            captureTool: "tcpdmp",
            capturePoint: "en0"
        ))
    }
    #expect(throws: LightingGateRunConfigurationError.nonPositiveArgument("--universe")) {
        _ = try LightingGateRunConfiguration.parse(lightingGateArguments(universe: "0"))
    }

    let invalidCaptureConfiguration = LightingGateRunConfiguration(
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
        _ = try LightingGateRunner.run(configuration: invalidCaptureConfiguration)
    }

    let partialConfiguration = LightingGateRunConfiguration(
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

    let report = try LightingGateRunner.run(configuration: partialConfiguration)

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

    let noPacketsConfiguration = LightingGateRunConfiguration(
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

    let noPacketsReport = try LightingGateRunner.run(configuration: noPacketsConfiguration)

    try noPacketsReport.validate()

    #expect(noPacketsReport.probe.packetCapture.captured == false)
    #expect(noPacketsReport.probe.packetCapture.packetCount == 0)
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
        captureArtifact: "private/reports/m12-loopback.pcapng",
        notes: "Synthetic PASS candidate used by unit tests only."
    )
    report.probe.durationSeconds = 1
    report.probe.dmx.maxLevel = 255
    return report
}

private func expectLightingFixtureGateError(
    _ expected: LightingFixtureGateValidationError,
    mutate: (inout LightingFixtureGateReport) throws -> Void
) throws {
    var report = try passCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
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

private func lightingGateArguments(
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
        "--output", "reports/m12-lighting-gate-run.json",
    ]
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
