// Verifies that JackTrip hub virtual studio topology reports server without peer.
import Testing

@testable import OpenLolaCore

@Test
func jackTripHubVirtualStudioTopologyReportsServerWithoutPeer() throws {
    let report = try JackTripCompatibilityRunner.run(
        configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .rx,
  peer: "",
  outputPath: "/tmp/jacktrip-hub-server.json"
) { input in
  input.dryRun = true
  input.mediaMode = .audio
  input.jackTrip = JackTripRunConfiguration {
   $0.topologyMode = .hubVirtualStudio
   $0.topologyRole = .hubServer
   $0.hubPatchMode = .fullMix
  }
})
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
  let configuration = ExternalConnectorSessionConfiguration(.init(
 connector: .jackTrip,
 role: .tx,
 peer: "",
 outputPath: "/tmp/jacktrip-hub-client.json"
) { input in
  input.mediaMode = .audio
  input.jackTrip = JackTripRunConfiguration {
   $0.topologyMode = .hubVirtualStudio
 $0.topologyRole = .hubClient
 }
})
  _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
 }
}

@Test
func jackTripHubVirtualStudioLaunchPlanUsesReferenceModeFlags() throws {
 let configuration = ExternalConnectorSessionConfiguration(.init(
 connector: .jackTrip,
 role: .rx,
 peer: "",
 outputPath: "/tmp/jacktrip-hub-server-plan.json"
) { input in
  input.mediaMode = .audio
  input.jackTrip = JackTripRunConfiguration {
   $0.topologyMode = .hubVirtualStudio
   $0.topologyRole = .hubServer
 $0.hubPatchMode = .fullMix
 }
})
 let plan = try ExternalConnectorLaunchPlan.build(configuration: configuration)

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
        "--jacktrip-hub-patch", "full-mix"
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
