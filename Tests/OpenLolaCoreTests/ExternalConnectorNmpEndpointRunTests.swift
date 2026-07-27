// Verifies that external connector NMP endpoint run executes selected side as dry run.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func externalConnectorNmpEndpointRunExecutesSelectedSideAsDryRun() throws {
    let plan = try ExternalConnectorNmpPlanRunner.run(configuration: makeExternalConnectorNmpPlanConfiguration {
        $0.connectors = [.lola, .mvtpUltraGrid, .jackTrip]
        $0.ultraGridExecutable = "/opt/ug/bin/uv"
        $0.jackTripExecutable = "/opt/jacktrip/bin/jacktrip"
    })

    let report = try ExternalConnectorNmpEndpointRunRunner.run(
        configuration: ExternalConnectorNmpEndpointRunConfiguration(
            planPath: "/tmp/nmp-plan.json",
            outputPath: "/tmp/nmp-local-run.json",
            side: .local,
            dryRunOverride: true
        ),
        plan: plan
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.side == .local)
    #expect(report.results.count == 3)
    #expect(report.results.map(\.connector) == [.lola, .mvtpUltraGrid, .jackTrip])
    #expect(report.results.allSatisfy { $0.report.dryRun })
    #expect(Set(report.results.map(\.direction)) == [.bidirectional])
    #expect(Set(report.results.map(\.role)) == [.txRx, .rx])
}

@Test
func externalConnectorNmpEndpointRunCanReportRealFailureFromPlanCommand() throws {
    let plan = try ExternalConnectorNmpPlanRunner.run(configuration: makeExternalConnectorNmpPlanConfiguration(
        localHost: "127.0.0.1",
        remoteHost: "127.0.0.1"
    ) {
        $0.connectors = [.jackTrip]
        $0.jackTripExecutable = "/tmp/open-lola-missing-jacktrip-\(UUID().uuidString)"
        $0.durationSeconds = 1
    })

    let report = try ExternalConnectorNmpEndpointRunRunner.run(
        configuration: ExternalConnectorNmpEndpointRunConfiguration(
            planPath: "/tmp/nmp-plan.json",
            outputPath: "/tmp/nmp-local-run.json",
            side: .local
        ),
        plan: plan
    )

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.results.count == 1)
    #expect(report.results.allSatisfy { $0.report.verdict == .fail })
    #expect(report.results.allSatisfy { $0.report.runtimeError?.isEmpty == false })
}

@Test
func externalConnectorNmpEndpointRunStartsSelectedSideTxRxEndpoint() throws {
    let plan = try ExternalConnectorNmpPlanRunner.run(configuration: makeExternalConnectorNmpPlanConfiguration(
        localHost: "127.0.0.1",
        remoteHost: "127.0.0.1"
    ) {
        $0.connectors = [.mvtpUltraGrid]
        $0.durationSeconds = 2
        $0.framesPerPacket = 4_800
        $0.videoWidth = 16
        $0.videoHeight = 16
        $0.videoFrameRate = 1
        $0.videoBitsPerPixel = 8
    })

    let report = try ExternalConnectorNmpEndpointRunRunner.run(
        configuration: ExternalConnectorNmpEndpointRunConfiguration(
            planPath: "/tmp/nmp-plan.json",
            outputPath: "/tmp/nmp-local-run.json",
            side: .local
        ),
        plan: plan
    )

    try report.validate()
    #expect(report.results.count == 1)
    #expect(Set(report.results.map(\.role)) == [.txRx])
    #expect(Set(report.results.map(\.direction)) == [.bidirectional])
    let media = try #require(report.results.first?.report.ultraGridMedia)
    #expect(report.results.first?.report.runtimeError == nil)
    #expect(media.transmittedDatagramCount > 0)
    #expect(report.results.allSatisfy { $0.report.process == nil })
}

@Test
func externalConnectorNmpEndpointRunParserRejectsInvalidSideAsInvalidSide() {
    #expect(throws: ExternalConnectorSessionError.invalidConnectionSide("sideways")) {
        _ = try ExternalConnectorNmpEndpointRunConfiguration.parse([
            "--plan", "/tmp/nmp-plan.json",
            "--output", "/tmp/nmp-run.json",
            "--side", "sideways"
        ])
    }
}

private func makeNmpEndpointProbeExecutable(
    directory: URL,
    name: String,
    output: String
) throws -> String {
    try makeExternalConnectorProbeExecutable(
        path: directory.appendingPathComponent(name),
        output: output
    )
}
