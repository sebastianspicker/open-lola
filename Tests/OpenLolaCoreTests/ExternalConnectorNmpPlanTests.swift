// Verifies that external connector NMP plan builds every AV connector plan.
import Testing

@testable import OpenLolaCore

@Test
func externalConnectorNmpPlanBuildsEveryAvConnectorPlan() throws {
    let configuration = try ExternalConnectorNmpPlanConfiguration.parse([
        "--local-host", "198.51.100.20",
        "--remote-host", "198.51.100.10",
        "--output", "/tmp/open-lola-nmp/nmp-plan.json",
        "--ultragrid-executable", "/opt/ug/bin/uv",
        "--jacktrip-executable", "/opt/jacktrip/bin/jacktrip",
        "--jacktrip-video-executable", "/opt/ug-video/bin/uv",
        "--connectors", "lola,mvtp-ultragrid,jacktrip",
        "--audio-capture", "coreaudio:input-uid",
        "--audio-playback", "coreaudio:output-uid",
        "--video-capture", "decklink:0",
        "--video-display", "decklink:1",
        "--local-raw-link-interface", "en10",
        "--remote-raw-link-interface", "en11",
        "--local-mac", "02:00:00:00:00:0a",
        "--remote-mac", "02:00:00:00:00:0b"
    ])

    let report = try ExternalConnectorNmpPlanRunner.run(configuration: configuration)
    let plans = try requireNmpConnectorPlans(report)

    try report.validate()
    #expect(report.plans.map(\.connector) == [.lola, .mvtpUltraGrid, .jackTrip])
    #expect(report.plans.allSatisfy { $0.mediaMode == .audioVideo })
    #expect(report.plans.allSatisfy { $0.endpoints.count == 2 })
    assertLoLaNmpPlan(plans)
    assertUltraGridNmpPlan(plans.ultraGrid)
    assertJackTripNmpPlan(plans)
}

@Test
func externalConnectorNmpPlanValidationRejectsMissingConnector() throws {
    var report = try ExternalConnectorNmpPlanRunner.run(configuration: makeExternalConnectorNmpPlanConfiguration {
        $0.connectors = [.lola, .mvtpUltraGrid, .jackTrip]
    })
    report.plans.removeAll { $0.connector == .jackTrip }

    #expect(throws: ExternalConnectorSessionError.emptyField("plans")) {
        try report.validate()
    }
}

@Test
func externalConnectorNmpPlanParserRejectsMtvpTypoAliasForCompatibilityNaming() {
    #expect(throws: ExternalConnectorSessionError.invalidConnector("mtvp-ultragrid")) {
        try ExternalConnectorNmpPlanConfiguration.parse([
            "--local-host", "198.51.100.20",
            "--remote-host", "198.51.100.10",
            "--output", "/tmp/nmp-plan.json",
            "--connectors", "lola,mtvp-ultragrid,jacktrip"
        ])
    }
}

@Test
func externalConnectorNmpPlanDefaultsToLoLaOnlyWhenConnectorsAreOmitted() throws {
    let configuration = try ExternalConnectorNmpPlanConfiguration.parse([
        "--local-host", "198.51.100.20",
        "--remote-host", "198.51.100.10",
        "--output", "/tmp/nmp-plan.json"
    ])

    #expect(configuration.connectors == [.lola])
}

@Test
func externalConnectorNmpPlanRejectsRawLinkInputsWithoutLoLaConnector() throws {
    let configuration = try ExternalConnectorNmpPlanConfiguration.parse([
        "--local-host", "198.51.100.20",
        "--remote-host", "198.51.100.10",
        "--output", "/tmp/nmp-ultragrid-only.json",
        "--connectors", "mvtp-ultragrid,jacktrip",
        "--local-raw-link-interface", "en10",
        "--remote-raw-link-interface", "en11",
        "--local-mac", "02:00:00:00:00:0a",
        "--remote-mac", "02:00:00:00:00:0b"
    ])

    #expect(throws: ExternalConnectorSessionError.rawLinkRequiresLoLaConnector) {
        _ = try ExternalConnectorNmpPlanRunner.run(configuration: configuration)
    }
}

private struct RequiredNmpConnectorPlans {
    var lola: ExternalConnectorConnectionPlanReport
    var lolaLocalTxRx: ExternalConnectorConnectionEndpoint
    var lolaRemoteTxRx: ExternalConnectorConnectionEndpoint
    var ultraGrid: ExternalConnectorConnectionPlanReport
    var jackTrip: ExternalConnectorConnectionPlanReport
    var jackTripLocalServer: ExternalConnectorConnectionEndpoint
    var jackTripRemoteClient: ExternalConnectorConnectionEndpoint
}

private func requireNmpConnectorPlans(_ report: ExternalConnectorNmpPlanReport) throws -> RequiredNmpConnectorPlans {
    let lolaPlan = try #require(report.plans.first { $0.connector == .lola })
    let jackTripPlan = try #require(report.plans.first { $0.connector == .jackTrip })
    return try RequiredNmpConnectorPlans(
        lola: lolaPlan,
        lolaLocalTxRx: requireNmpEndpoint(lolaPlan, side: .local, role: .txRx),
        lolaRemoteTxRx: requireNmpEndpoint(lolaPlan, side: .remote, role: .txRx),
        ultraGrid: #require(report.plans.first { $0.connector == .mvtpUltraGrid }),
        jackTrip: jackTripPlan,
        jackTripLocalServer: requireNmpEndpoint(jackTripPlan, side: .local, role: .rx),
        jackTripRemoteClient: requireNmpEndpoint(jackTripPlan, side: .remote, role: .tx)
    )
}

private func requireNmpEndpoint(
    _ plan: ExternalConnectorConnectionPlanReport,
    side: ExternalConnectorConnectionSide,
    role: ExternalConnectorSessionRole
) throws -> ExternalConnectorConnectionEndpoint {
    try #require(plan.endpoints.first {
        $0.side == side && $0.direction == .bidirectional && $0.role == role
    })
}

private func assertLoLaNmpPlan(_ plans: RequiredNmpConnectorPlans) {
    #expect(plans.lola.endpoints.allSatisfy { $0.role == .txRx })
    #expect(plans.lola.preflightCommand == nil)
    #expect(commandValue(plans.lolaLocalTxRx.command, "--raw-link-interface") == "en10")
    #expect(commandValue(plans.lolaLocalTxRx.command, "--source-mac") == "02:00:00:00:00:0a")
    #expect(commandValue(plans.lolaLocalTxRx.command, "--destination-mac") == "02:00:00:00:00:0b")
    #expect(commandValue(plans.lolaRemoteTxRx.command, "--raw-link-interface") == "en11")
    #expect(commandValue(plans.lolaRemoteTxRx.command, "--source-mac") == "02:00:00:00:00:0b")
    #expect(commandValue(plans.lolaRemoteTxRx.command, "--destination-mac") == "02:00:00:00:00:0a")
}

private func assertUltraGridNmpPlan(_ plan: ExternalConnectorConnectionPlanReport) {
    #expect(plan.preflightCommand == nil)
    #expect(plan.endpoints.allSatisfy { $0.role == .txRx })
    #expect(plan.endpoints.allSatisfy { commandValue($0.command, "--raw-link-interface") == nil })
    #expect(plan.endpoints.allSatisfy { commandValue($0.command, "--executable") == nil })
}

private func assertJackTripNmpPlan(_ plans: RequiredNmpConnectorPlans) {
    #expect(Set(plans.jackTrip.endpoints.map(\.role)) == Set([.rx, .tx]))
    #expect(plans.jackTrip.preflightCommand?.contains("/opt/jacktrip/bin/jacktrip") == true)
    #expect(plans.jackTrip.preflightCommand?.contains("/opt/ug-video/bin/uv") == true)
    #expect(plans.jackTrip.endpoints.allSatisfy { commandValue($0.command, "--raw-link-interface") == nil })
    #expect(commandValue(plans.jackTripLocalServer.plan.arguments, "-B") == "4464")
    #expect(commandValue(plans.jackTripLocalServer.plan.arguments, "-P") == nil)
    #expect(commandValue(plans.jackTripRemoteClient.plan.arguments, "-B") == "4465")
    #expect(commandValue(plans.jackTripRemoteClient.plan.arguments, "-P") == "4464")
}
