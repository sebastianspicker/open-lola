import Testing

@testable import OpenLolaCore

@Test
func jackTripHubVirtualStudioTopologyReportsServerWithoutPeer() throws {
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .rx,
            peer: "",
            outputPath: "/tmp/jacktrip-hub-server.json",
            dryRun: true,
            mediaMode: .audio,
            jackTrip: JackTripRunConfiguration(
                topologyMode: .hubVirtualStudio,
                topologyRole: .hubServer,
                hubPatchMode: .fullMix
            )
        )
    )

    try report.validate()
    #expect(report.topology.mode == .hubVirtualStudio)
    #expect(report.topology.role == .hubServer)
    #expect(report.topology.state == .hubServerListening)
    #expect(report.topology.peerRequired == false)
    #expect(report.topology.peerConfigured == false)
    #expect(report.topology.hubPatchMode == .fullMix)
    #expect(!report.unsupportedModes.contains("hub-virtual-studio"))
    #expect(report.verdict == .fail)
}

@Test
func jackTripHubVirtualStudioClientRequiresPeer() {
    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument("--peer")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "",
            outputPath: "/tmp/jacktrip-hub-client.json",
            mediaMode: .audio,
            jackTrip: JackTripRunConfiguration(topologyMode: .hubVirtualStudio, topologyRole: .hubClient)
        ))
    }
}

@Test
func jackTripHubVirtualStudioLaunchPlanUsesReferenceModeFlags() throws {
    let plan = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .rx,
        peer: "",
        outputPath: "/tmp/jacktrip-hub-server-plan.json",
        mediaMode: .audio,
        jackTrip: JackTripRunConfiguration(
            topologyMode: .hubVirtualStudio,
            topologyRole: .hubServer,
            hubPatchMode: .fullMix
        )
    ))

    #expect(plan.arguments.contains("-S"))
    #expect(commandValue(plan.arguments, "-p") == "4")
    #expect(commandValue(plan.arguments, "--topology") == "hub-virtual-studio")
    #expect(commandValue(plan.arguments, "--topology-role") == "hub-server")
    #expect(commandValue(plan.arguments, "--hub-patch") == "full-mix")
}

@Test
func jackTripConnectionPlanCarriesHubServerAndClientTopology() throws {
    let configuration = try ExternalConnectorConnectionPlanConfiguration.parse([
        "--connector", "jacktrip",
        "--local-host", "203.0.113.10",
        "--remote-host", "203.0.113.20",
        "--output", "/tmp/jacktrip-hub-plan.json",
        "--run-dir", "/tmp/open-lola-jacktrip-hub",
        "--media", "audio",
        "--audio-port", "4464",
        "--jacktrip-topology", "hub-virtual-studio",
        "--jacktrip-topology-role", "hub-server",
        "--jacktrip-hub-patch", "full-mix",
    ])

    let report = try ExternalConnectorConnectionPlanRunner.run(configuration: configuration)
    let server = try #require(report.endpoints.first { $0.side == .local && $0.role == .rx })
    let client = try #require(report.endpoints.first { $0.side == .remote && $0.role == .tx })

    try report.validate()
    #expect(commandValue(server.command, "--peer") == nil)
    #expect(commandValue(server.command, "--jacktrip-topology") == "hub-virtual-studio")
    #expect(commandValue(server.command, "--jacktrip-topology-role") == "hub-server")
    #expect(commandValue(server.command, "--jacktrip-hub-patch") == "full-mix")
    #expect(server.plan.arguments.contains("-S"))
    #expect(commandValue(server.plan.arguments, "-p") == "4")
    #expect(commandValue(client.command, "--peer") == "203.0.113.10")
    #expect(commandValue(client.command, "--jacktrip-topology-role") == "hub-client")
    #expect(client.plan.arguments.contains("-C"))
}

private func commandValue(_ command: [String], _ flag: String) -> String? {
    guard let index = command.firstIndex(of: flag), command.indices.contains(index + 1) else {
        return nil
    }
    return command[index + 1]
}
