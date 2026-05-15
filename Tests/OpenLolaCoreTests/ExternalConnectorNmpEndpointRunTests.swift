import Foundation
import Testing

@testable import OpenLolaCore

@Test
func externalConnectorNmpEndpointRunExecutesSelectedSideAsDryRun() throws {
    let plan = try ExternalConnectorNmpPlanRunner.run(configuration: ExternalConnectorNmpPlanConfiguration(
        localHost: "198.51.100.20",
        remoteHost: "198.51.100.10",
        outputPath: "/tmp/nmp-plan.json",
        connectors: [.lola, .mvtpUltraGrid, .jackTrip],
        ultraGridExecutable: "/opt/ug/bin/uv",
        jackTripExecutable: "/opt/jacktrip/bin/jacktrip"
    ))

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
func externalConnectorNmpEndpointRunExecutesBothSidesAsDryRun() throws {
    let plan = try ExternalConnectorNmpPlanRunner.run(configuration: ExternalConnectorNmpPlanConfiguration(
        localHost: "198.51.100.20",
        remoteHost: "198.51.100.10",
        outputPath: "/tmp/nmp-plan.json",
        connectors: [.lola, .mvtpUltraGrid, .jackTrip],
        ultraGridExecutable: "/opt/ug/bin/uv",
        jackTripExecutable: "/opt/jacktrip/bin/jacktrip"
    ))

    let report = try ExternalConnectorNmpEndpointRunRunner.run(
        configuration: ExternalConnectorNmpEndpointRunConfiguration(
            planPath: "/tmp/nmp-plan.json",
            outputPath: "/tmp/nmp-both-run.json",
            side: .both,
            dryRunOverride: true
        ),
        plan: plan
    )

    try report.validate()
    #expect(report.verdict == .partial)
    #expect(report.side == .both)
    #expect(report.results.count == 6)
    #expect(Set(report.results.map(\.side)) == [.local, .remote])
    #expect(Set(report.results.map(\.direction)) == [.bidirectional])
    #expect(Set(report.results.map(\.role)) == [.txRx, .rx, .tx])
    #expect(report.results.allSatisfy { $0.report.dryRun })
}

@Test
func externalConnectorNmpEndpointRunUsesSuppliedPreflightDiscoveredExecutables() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("open-lola-nmp-endpoint-run-discovery-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let pythonUv = try makeNmpEndpointProbeExecutable(
        directory: directory,
        name: "uv",
        output: "An extremely fast Python package manager."
    )
    let ultraGridAlias = try makeNmpEndpointProbeExecutable(
        directory: directory,
        name: "uv-ug",
        output: "UltraGrid - A High Definition Collaboratory -t capture -d display -s audio -r playback"
    )
    let jackTrip = try makeNmpEndpointProbeExecutable(
        directory: directory,
        name: "jacktrip",
        output: "JackTrip VERSION: 2.7.0"
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let planPath = "/tmp/nmp-plan.json"
    let plan = try ExternalConnectorNmpPlanRunner.run(configuration: ExternalConnectorNmpPlanConfiguration(
        localHost: "198.51.100.20",
        remoteHost: "198.51.100.10",
        outputPath: planPath,
        connectors: [.mvtpUltraGrid, .jackTrip],
        ultraGridExecutable: pythonUv,
        jackTripExecutable: jackTrip
    ))
    let preflight = try ExternalConnectorNmpPreflightRunner.run(
        configuration: ExternalConnectorNmpPreflightConfiguration(
            planPath: planPath,
            outputPath: "/tmp/nmp-preflight.json"
        ),
        plan: plan
    )

    #expect(preflight.verdict == .pass)
    for side in [ExternalConnectorConnectionSide.local, .remote] {
        let report = try ExternalConnectorNmpEndpointRunRunner.run(
            configuration: ExternalConnectorNmpEndpointRunConfiguration(
                planPath: planPath,
                outputPath: "/tmp/nmp-\(side.rawValue)-run.json",
                side: side,
                dryRunOverride: true,
                preflightPath: "/tmp/nmp-preflight.json"
            ),
            plan: plan,
            preflight: preflight
        )

        try report.validate()
        #expect(report.side == side)
        #expect(report.results.allSatisfy { $0.side == side })
        #expect(Set(report.results.map(\.direction)) == [.bidirectional])
        let expectedRoles: Set<ExternalConnectorSessionRole> = side == .local ? [.txRx, .rx] : [.txRx, .tx]
        #expect(Set(report.results.map(\.role)) == expectedRoles)
        let ultraGridCommands = report.results
            .filter { $0.connector == .mvtpUltraGrid }
            .map(\.command)
        let jackTripCommands = report.results
            .filter { $0.connector == .jackTrip }
            .map(\.command)
        #expect(ultraGridCommands.allSatisfy { nmpEndpointOptionValue("--executable", in: $0) == ultraGridAlias })
        #expect(jackTripCommands.allSatisfy { nmpEndpointOptionValue("--executable", in: $0) == jackTrip })
        #expect(jackTripCommands.allSatisfy { nmpEndpointOptionValue("--video-executable", in: $0) == ultraGridAlias })
        #expect(report.notes.contains("preflight evidence"))
    }
}

@Test
func externalConnectorNmpEndpointRunCanReportRealFailureFromPlanCommand() throws {
    let plan = try ExternalConnectorNmpPlanRunner.run(configuration: ExternalConnectorNmpPlanConfiguration(
        localHost: "127.0.0.1",
        remoteHost: "127.0.0.1",
        outputPath: "/tmp/nmp-plan.json",
        connectors: [.mvtpUltraGrid],
        ultraGridExecutable: "/tmp/open-lola-missing-uv-\(UUID().uuidString)",
        durationSeconds: 1
    ))

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
    let probeDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("open-lola-nmp-endpoint-overlap-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: probeDirectory, withIntermediateDirectories: true)
    let executable = try makeNmpEndpointOverlapProbeExecutable(probeDirectory: probeDirectory)
    defer { try? FileManager.default.removeItem(at: probeDirectory) }
    let plan = try ExternalConnectorNmpPlanRunner.run(configuration: ExternalConnectorNmpPlanConfiguration(
        localHost: "127.0.0.1",
        remoteHost: "127.0.0.1",
        outputPath: "/tmp/nmp-plan.json",
        connectors: [.mvtpUltraGrid],
        ultraGridExecutable: executable,
        durationSeconds: 2
    ))

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
    #expect(report.results.allSatisfy { $0.report.process?.terminatedAfterDuration == true })
}

@Test
func externalConnectorNmpEndpointRunParserRejectsUnknownArguments() {
    #expect(throws: ExternalConnectorSessionError.unknownArgument("--bad")) {
        _ = try ExternalConnectorNmpEndpointRunConfiguration.parse([
            "--plan", "/tmp/nmp-plan.json",
            "--output", "/tmp/nmp-run.json",
            "--side", "local",
            "--bad", "value",
        ])
    }
}

@Test
func externalConnectorNmpEndpointRunParserRejectsInvalidSideAsInvalidSide() {
    #expect(throws: ExternalConnectorSessionError.invalidConnectionSide("sideways")) {
        _ = try ExternalConnectorNmpEndpointRunConfiguration.parse([
            "--plan", "/tmp/nmp-plan.json",
            "--output", "/tmp/nmp-run.json",
            "--side", "sideways",
        ])
    }
}

@Test
func externalConnectorNmpEndpointRunParserAcceptsPreflightPath() throws {
    let configuration = try ExternalConnectorNmpEndpointRunConfiguration.parse([
        "--plan", "/tmp/nmp-plan.json",
        "--output", "/tmp/nmp-run.json",
        "--side", "local",
        "--preflight", "/tmp/nmp-preflight.json",
    ])

    #expect(configuration.preflightPath == "/tmp/nmp-preflight.json")
}

private func makeNmpEndpointOverlapProbeExecutable(probeDirectory: URL) throws -> String {
    let path = probeDirectory.appendingPathComponent("probe.sh")
    let script = """
    #!/bin/sh
    probe_dir='\(probeDirectory.path)'
    pid_file="$probe_dir/$$.live"
    child=''
    cleanup() {
      rm -f "$pid_file"
      if [ -n "$child" ]; then kill "$child" 2>/dev/null || true; fi
      exit 0
    }
    trap cleanup TERM INT EXIT
    touch "$pid_file"
    i=0
    while [ "$i" -lt 80 ]; do
      live_count=$(find "$probe_dir" -name '*.live' -type f | wc -l | tr -d ' ')
      if [ "$live_count" -ge 2 ]; then
        touch "$probe_dir/overlap"
        break
      fi
      i=$((i + 1))
      sleep 0.05
    done
    while :; do
      sleep 1 &
      child=$!
      wait "$child"
    done
    """
    try script.write(to: path, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
    return path.path
}

private func makeNmpEndpointProbeExecutable(
    directory: URL,
    name: String,
    output: String
) throws -> String {
    let path = directory.appendingPathComponent(name)
    try "#!/bin/sh\necho '\(output)'\n".write(to: path, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
    return path.path
}

private func nmpEndpointOptionValue(_ option: String, in command: [String]) -> String? {
    guard let index = command.firstIndex(of: option), index + 1 < command.count else {
        return nil
    }
    return command[index + 1]
}
