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
        "--remote-mac", "02:00:00:00:00:0b",
    ])

    let report = try ExternalConnectorNmpPlanRunner.run(configuration: configuration)
    let lolaPlan = try #require(report.plans.first { $0.connector == .lola })
    let lolaLocalTxRx = try #require(lolaPlan.endpoints.first {
        $0.side == .local && $0.direction == .bidirectional && $0.role == .txRx
    })
    let lolaRemoteTxRx = try #require(lolaPlan.endpoints.first {
        $0.side == .remote && $0.direction == .bidirectional && $0.role == .txRx
    })
    let ultraGridPlan = try #require(report.plans.first { $0.connector == .mvtpUltraGrid })
    let jackTripPlan = try #require(report.plans.first { $0.connector == .jackTrip })
    let jackTripLocalServer = try #require(jackTripPlan.endpoints.first {
        $0.side == .local && $0.direction == .bidirectional && $0.role == .rx
    })
    let jackTripRemoteClient = try #require(jackTripPlan.endpoints.first {
        $0.side == .remote && $0.direction == .bidirectional && $0.role == .tx
    })

    try report.validate()
    #expect(report.plans.map(\.connector) == [.lola, .mvtpUltraGrid, .jackTrip])
    #expect(report.plans.allSatisfy { $0.mediaMode == .audioVideo })
    #expect(report.plans.allSatisfy { $0.endpoints.count == 2 })
    #expect(lolaPlan.endpoints.allSatisfy { $0.role == .txRx })
    #expect(ultraGridPlan.endpoints.allSatisfy { $0.role == .txRx })
    #expect(Set(jackTripPlan.endpoints.map(\.role)) == Set([.rx, .tx]))
    #expect(lolaPlan.preflightCommand == nil)
    #expect(commandValue(lolaLocalTxRx.command, "--raw-link-interface") == "en10")
    #expect(commandValue(lolaLocalTxRx.command, "--source-mac") == "02:00:00:00:00:0a")
    #expect(commandValue(lolaLocalTxRx.command, "--destination-mac") == "02:00:00:00:00:0b")
    #expect(commandValue(lolaRemoteTxRx.command, "--raw-link-interface") == "en11")
    #expect(commandValue(lolaRemoteTxRx.command, "--source-mac") == "02:00:00:00:00:0b")
    #expect(commandValue(lolaRemoteTxRx.command, "--destination-mac") == "02:00:00:00:00:0a")
    #expect(ultraGridPlan.preflightCommand?.contains("/opt/ug/bin/uv") == true)
    #expect(ultraGridPlan.endpoints.allSatisfy { commandValue($0.command, "--raw-link-interface") == nil })
    #expect(jackTripPlan.preflightCommand?.contains("/opt/jacktrip/bin/jacktrip") == true)
    #expect(jackTripPlan.preflightCommand?.contains("/opt/ug-video/bin/uv") == true)
    #expect(jackTripPlan.endpoints.allSatisfy { commandValue($0.command, "--raw-link-interface") == nil })
    #expect(commandValue(jackTripLocalServer.plan.arguments, "-B") == "4464")
    #expect(commandValue(jackTripLocalServer.plan.arguments, "-P") == nil)
    #expect(commandValue(jackTripRemoteClient.plan.arguments, "-B") == "4465")
    #expect(commandValue(jackTripRemoteClient.plan.arguments, "-P") == "4464")
}

@Test
func externalConnectorNmpPlanValidationRejectsMissingConnector() throws {
    var report = try ExternalConnectorNmpPlanRunner.run(configuration: ExternalConnectorNmpPlanConfiguration(
        localHost: "198.51.100.20",
        remoteHost: "198.51.100.10",
        outputPath: "/tmp/nmp-plan.json",
        connectors: [.lola, .mvtpUltraGrid, .jackTrip]
    ))
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
            "--connectors", "lola,mtvp-ultragrid,jacktrip",
        ])
    }
}

@Test
func externalConnectorNmpPlanDefaultsToLoLaOnlyWhenConnectorsAreOmitted() throws {
    let configuration = try ExternalConnectorNmpPlanConfiguration.parse([
        "--local-host", "198.51.100.20",
        "--remote-host", "198.51.100.10",
        "--output", "/tmp/nmp-plan.json",
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
        "--remote-mac", "02:00:00:00:00:0b",
    ])

    #expect(throws: ExternalConnectorSessionError.rawLinkRequiresLoLaConnector) {
        _ = try ExternalConnectorNmpPlanRunner.run(configuration: configuration)
    }
}

private func commandValue(_ command: [String], _ flag: String) -> String? {
    guard let index = command.firstIndex(of: flag), command.indices.contains(index + 1) else {
        return nil
    }
    return command[index + 1]
}
