// Verifies that lighting fixture gate blocks unsafe states and allows only armed isolated universe.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lightingFixtureGateBlocksUnsafeStatesAndAllowsOnlyArmedIsolatedUniverse() throws {
try expectLightingGateBlocksUnarmedAndIncompletePolicy()
try expectLightingGateRejectsCampusNetwork()
try expectLightingGateAllowsOnlyArmedIsolatedUniverse()
}
private func expectLightingGateBlocksUnarmedAndIncompletePolicy() throws {
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
}

private func expectLightingGateRejectsCampusNetwork() throws {
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
}

private func expectLightingGateAllowsOnlyArmedIsolatedUniverse() throws {
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
    var report = try lightingFixtureGatePassCandidateReport()
    report.workflow?.notes = "OSC cue handoff completed by the local QLC+ owner."
    report.probe.packetCapture.universesObserved = [1, 1]

    try report.validate()

    #expect(Set(report.probe.packetCapture.universesObserved) == [1])
    #expect(report.verdict == .pass)
}

@Test
func lightingFixtureGateRejectsInvalidPassEvidence() throws {
try expectLightingFixtureGateRejectsStandardsAndCaptureProblems()
try expectLightingFixtureGateRejectsDmxAndFixtureProblems()
try expectLightingFixtureGateRejectsAudioImpactProblems()
try expectLightingFixtureGateRejectsWorkflowProblems()
}

private func expectLightingFixtureGateRejectsStandardsAndCaptureProblems() throws {
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
}

private func expectLightingFixtureGateRejectsDmxAndFixtureProblems() throws {
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
}

private func expectLightingFixtureGateRejectsAudioImpactProblems() throws {
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
}

private func expectLightingFixtureGateRejectsWorkflowProblems() throws {
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
// swiftlint:disable function_body_length
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
        "--output", "reports/m12-lighting-gate-run.json"
    ])

    assertLightingGateConfiguration(configuration)
    assertLightingGateParserRejections()
    try assertLightingGateRunnerSafetyHandoff()
}

private func assertLightingGateConfiguration(_ configuration: LightingGateRunConfiguration) {
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

private func assertLightingGateParserRejections() {
    #expect(throws: LightingGateRunConfigurationError.missingValue("--capture-point")) {
        _ = try LightingGateRunConfiguration.parse(lightingGateArguments(
            capturePoint: "--duration-seconds"
        ))
    }
    #expect(throws: LightingGateRunConfigurationError.duplicateArgument("--output")) {
        _ = try LightingGateRunConfiguration.parse(
            lightingGateArguments() + ["--output", "reports/other.json"]
        )
    }
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

}

private func assertLightingGateRunnerSafetyHandoff() throws {
    let invalidCaptureConfiguration = lightingGateRunConfiguration(
        capture: .init(tool: "tcpdmp", point: "en0", durationSeconds: 1)
    )

    #expect(throws: LightingGateRunError.invalidCaptureTool("tcpdmp")) {
        _ = try LightingGateRunner.run(configuration: invalidCaptureConfiguration)
    }

    let partialConfiguration = lightingGateRunConfiguration(
        capture: .init(tool: "not-run", point: "not-run", durationSeconds: 0)
    )

    let report = try LightingGateRunner.run(configuration: partialConfiguration)
    try assertPartialLightingGateRunReport(report)

    let noPacketsConfiguration = lightingGateRunConfiguration(
        capture: .init(tool: "tcpdump", point: "en0", durationSeconds: 1)
    )

    let noPacketsReport = try LightingGateRunner.run(configuration: noPacketsConfiguration)

    try assertNoPacketsLightingGateRunReport(noPacketsReport)
}

private func assertPartialLightingGateRunReport(_ report: LightingFixtureGateReport) throws {
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

private func assertNoPacketsLightingGateRunReport(_ report: LightingFixtureGateReport) throws {
    try report.validate()
    #expect(report.probe.packetCapture.captured == false)
    #expect(report.probe.packetCapture.packetCount == 0)
}
private func lightingGateRunConfiguration(
    capture: LightingGateRunCapture
) -> LightingGateRunConfiguration {
    LightingGateRunConfiguration(
        artifacts: LightingGateRunArtifacts(
            audioBaselineReportId: "m05-route-baseline-required",
            oscCueReportId: "m11-osc-cue-required",
            outputPath: "reports/m12-lighting-gate-run.json"
        ),
        output: LightingGateRunOutput(
            protocolName: .sacn,
            interopTarget: .qlcPlus,
            universe: 1,
            networkMode: .loopbackUnicast,
            destinationAddress: "127.0.0.1",
            port: LightingControlProtocol.sacn.defaultPort
        ),
        safety: LightingGateRunSafety(isolatedNetworkVerified: true, explicitlyArmed: false),
        capture: capture
    )
}

// swiftlint:enable function_body_length

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
