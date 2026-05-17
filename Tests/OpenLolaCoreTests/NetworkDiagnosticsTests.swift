import Foundation
import Testing

@testable import OpenLolaCore

@Test
func pingParserExtractsMacOSAndLinuxSummariesAndRejectsMalformedPacketSummary() throws {
    let validOutput = """
    PING 127.0.0.1 (127.0.0.1): 56 data bytes
    64 bytes from 127.0.0.1: icmp_seq=0 ttl=64 time=0.063 ms
    64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.097 ms

    --- 127.0.0.1 ping statistics ---
    2 packets transmitted, 2 packets received, 0.0% packet loss
    round-trip min/avg/max/stddev = 0.063/0.080/0.097/0.017 ms
    """

    let result = try NetworkDiagnosticsParser.parsePing(validOutput)

    #expect(result.transmitted == 2)
    #expect(result.received == 2)
    #expect(result.packetLossPercent == 0)
    #expect(result.minRttMilliseconds == 0.063)
    #expect(result.averageRttMilliseconds == 0.080)
    #expect(result.maxRttMilliseconds == 0.097)
    #expect(result.standardDeviationMilliseconds == 0.017)

    let linuxOutput = """
    PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.
    64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.046 ms

    --- 127.0.0.1 ping statistics ---
    2 packets transmitted, 1 received, 50% packet loss, time 1004ms
    rtt min/avg/max/mdev = 0.046/0.046/0.046/0.000 ms
    """

    let linuxResult = try NetworkDiagnosticsParser.parsePing(linuxOutput)

    #expect(linuxResult.transmitted == 2)
    #expect(linuxResult.received == 1)
    #expect(linuxResult.packetLossPercent == 50)
    #expect(linuxResult.averageRttMilliseconds == 0.046)

    let malformedSummaryOutput = """
    PING 127.0.0.1 (127.0.0.1): 56 data bytes

    --- 127.0.0.1 ping statistics ---
    packet packets transmitted
    round-trip min/avg/max/stddev = 0.063/0.080/0.097/0.017 ms
    """

    #expect(throws: NetworkDiagnosticsParseError.malformedPingSummary("packet packets transmitted")) {
        try NetworkDiagnosticsParser.parsePing(malformedSummaryOutput)
    }
}

@Test
func tracerouteParserExtractsHopTimingsAndNormalizesBracketedIPv6() throws {
    let ipv4Output = """
    traceroute to 127.0.0.1 (127.0.0.1), 4 hops max, 40 byte packets
     1  127.0.0.1  0.347 ms  0.032 ms  0.029 ms
    """

    let ipv4Result = try NetworkDiagnosticsParser.parseTraceroute(ipv4Output)

    #expect(ipv4Result.hops.count == 1)
    #expect(ipv4Result.hops[0].index == 1)
    #expect(ipv4Result.hops[0].address == "127.0.0.1")
    #expect(ipv4Result.hops[0].timingsMilliseconds == [0.347, 0.032, 0.029])
    #expect(ipv4Result.blocked == false)

    let ipv6Output = """
    traceroute to 2001:db8::1, 4 hops max, 40 byte packets
     1  [2001:db8::1]  0.347 ms  0.032 ms  0.029 ms
    """

    let ipv6Result = try NetworkDiagnosticsParser.parseTraceroute(ipv6Output)

    #expect(ipv6Result.hops.count == 1)
    #expect(ipv6Result.hops[0].address == "2001:db8::1")
}

@Test
func networkDiagnosticsRunConfigurationUsesSharedKeyValueParserSemantics() throws {
    let configuration = try NetworkDiagnosticsRunConfiguration.parse([
        "--peer", "-lab-peer",
        "--ping-count", "3",
        "--max-hops", "8",
        "--output", "reports/network-diagnostics.json",
    ])

    #expect(configuration.peer == "-lab-peer")
    #expect(configuration.pingCount == 3)
    #expect(configuration.maxHops == 8)
    #expect(configuration.outputPath == "reports/network-diagnostics.json")

    #expect(throws: NetworkDiagnosticsRunConfigurationError.unknownArgument("--unexpected")) {
        _ = try NetworkDiagnosticsRunConfiguration.parse([
            "--peer", "203.0.113.7",
            "--ping-count", "3",
            "--max-hops", "8",
            "--output", "reports/network-diagnostics.json",
            "--unexpected", "value",
        ])
    }
    #expect(throws: NetworkDiagnosticsRunConfigurationError.duplicateArgument("--peer")) {
        _ = try NetworkDiagnosticsRunConfiguration.parse([
            "--peer", "203.0.113.7",
            "--peer", "203.0.113.8",
            "--ping-count", "3",
            "--max-hops", "8",
            "--output", "reports/network-diagnostics.json",
        ])
    }
    #expect(throws: NetworkDiagnosticsRunConfigurationError.missingValue("--peer")) {
        _ = try NetworkDiagnosticsRunConfiguration.parse([
            "--peer", "--ping-count",
            "3",
            "--max-hops", "8",
            "--output", "reports/network-diagnostics.json",
        ])
    }
    #expect(throws: NetworkDiagnosticsRunConfigurationError.missingValue("--output")) {
        _ = try NetworkDiagnosticsRunConfiguration.parse([
            "--peer", "203.0.113.7",
            "--ping-count", "3",
            "--max-hops", "8",
            "--output",
        ])
    }
    #expect(throws: NetworkDiagnosticsRunConfigurationError.invalidInteger(
        argument: "--ping-count",
        value: "abc"
    )) {
        _ = try NetworkDiagnosticsRunConfiguration.parse([
            "--peer", "203.0.113.7",
            "--ping-count", "abc",
            "--max-hops", "8",
            "--output", "reports/network-diagnostics.json",
        ])
    }
    #expect(throws: NetworkDiagnosticsRunConfigurationError.nonPositiveArgument("--ping-count")) {
        _ = try NetworkDiagnosticsRunConfiguration.parse([
            "--peer", "203.0.113.7",
            "--ping-count", "-1",
            "--max-hops", "8",
            "--output", "reports/network-diagnostics.json",
        ])
    }
}

@Test
func networkDiagnosticsReportValidationVerdictAndRoundTripEnforcePassPolicy() throws {
    var blockedReport = NetworkDiagnosticsSyntheticSmoke.run()
    blockedReport.verdict = .pass
    blockedReport.traceroute.blocked = true
    blockedReport.traceroute.blockedReason = "operation not permitted"

    #expect(throws: NetworkDiagnosticsValidationError.passWithBlockedTraceroute) {
        try blockedReport.validate()
    }

    var slowReport = NetworkDiagnosticsSyntheticSmoke.run()
    slowReport.verdict = .pass
    slowReport.ping?.averageRttMilliseconds = NetworkDiagnosticsPassThresholds
        .maximumAverageRttMilliseconds + 0.1

    #expect(throws: NetworkDiagnosticsValidationError.passExceedsThreshold(
        field: "ping.averageRttMilliseconds",
        actual: 2.1,
        maximum: NetworkDiagnosticsPassThresholds.maximumAverageRttMilliseconds
    )) {
        try slowReport.validate()
    }

    let clean = NetworkDiagnosticsSyntheticSmoke.run()

    #expect(networkDiagnosticsVerdict(ping: clean.ping, traceroute: clean.traceroute) == .pass)

    var blockedTraceroute = clean.traceroute
    blockedTraceroute.blocked = true
    blockedTraceroute.blockedReason = "operation not permitted"
    #expect(networkDiagnosticsVerdict(ping: clean.ping, traceroute: blockedTraceroute) == .partial)

    var lossyPing = clean.ping
    lossyPing?.packetLossPercent = 50
    #expect(networkDiagnosticsVerdict(ping: lossyPing, traceroute: clean.traceroute) == .partial)

    var slowPing = clean.ping
    slowPing?.maxRttMilliseconds = NetworkDiagnosticsPassThresholds.maximumRttMilliseconds + 0.1
    #expect(networkDiagnosticsVerdict(ping: slowPing, traceroute: clean.traceroute) == .partial)

    let data = try clean.prettyJSONData()
    let decoded = try NetworkDiagnosticsReport.decode(from: data)

    try decoded.validate()

    #expect(decoded == clean)
}

@Test
func networkDiagnosticsReportPreservesPingAndTracerouteFailureReasons() throws {
    let configuration = NetworkDiagnosticsRunConfiguration(
        peer: "203.0.113.7",
        pingCount: 2,
        maxHops: 4,
        outputPath: "/tmp/network-diagnostics.json"
    )
    let malformedPing = """
    PING 203.0.113.7 (203.0.113.7): 56 data bytes

    --- 203.0.113.7 ping statistics ---
    packets transmitted without counts
    round-trip min/avg/max/stddev = 0.063/0.080/0.097/0.017 ms
    """
    let unsupportedTraceroute = """
    traceroute localized summary without numbered hops
    """

    let report = NetworkDiagnosticsRunner.makeReport(
        configuration: configuration,
        pingProcess: ProcessResult(
            output: malformedPing,
            exitCode: 0,
            timedOut: false,
            spawnError: nil
        ),
        tracerouteProcess: ProcessResult(
            output: unsupportedTraceroute,
            exitCode: 0,
            timedOut: false,
            spawnError: nil
        )
    )

    #expect(report.ping == nil)
    #expect(report.pingError?.contains("ping parse failed") == true)
    #expect(report.pingError?.contains("malformedPingSummary") == true)
    #expect(report.traceroute.hops.isEmpty)
    #expect(report.traceroute.blocked)
    #expect(report.traceroute.blockedReason?.contains("traceroute parse failed") == true)
    #expect(report.tracerouteError == report.traceroute.blockedReason)
    #expect(report.verdict == .partial)

    try report.validate()

    let processFailureReport = NetworkDiagnosticsRunner.makeReport(
        configuration: configuration,
        pingProcess: ProcessResult(
            output: "",
            exitCode: -1,
            timedOut: false,
            spawnError: "No such file or directory"
        ),
        tracerouteProcess: ProcessResult(
            output: "traceroute: sendto: Operation not permitted",
            exitCode: 1,
            timedOut: false,
            spawnError: nil
        )
    )

    #expect(processFailureReport.pingError == "ping process failed: No such file or directory")
    #expect(processFailureReport.traceroute.blocked)
    #expect(processFailureReport.traceroute.blockedReason == "traceroute: sendto: Operation not permitted")
    #expect(processFailureReport.tracerouteError == "traceroute exited with status 1")
    #expect(processFailureReport.verdict == .partial)
}

@Test
func networkDiagnosticsProcessDrainsVerboseOutputAndTimesOutSigtermIgnoringChild() {
    let verboseResult = runNetworkDiagnosticsProcess(
        executable: "/usr/bin/python3",
        arguments: [
            "-c",
            "import sys; sys.stdout.write('x' * 1048576); sys.stdout.flush()",
        ],
        timeoutSeconds: 3
    )

    #expect(!verboseResult.timedOut)
    #expect(verboseResult.exitCode == 0)
    #expect(verboseResult.spawnError == nil)
    #expect(verboseResult.output.hasPrefix("x"))
    #expect(verboseResult.output.count <= 65_536)

    let timeoutResult = runNetworkDiagnosticsProcess(
        executable: "/usr/bin/python3",
        arguments: [
            "-c",
            "import signal, time; signal.signal(signal.SIGTERM, signal.SIG_IGN); print('started', flush=True); time.sleep(30)",
        ],
        timeoutSeconds: 1
    )

    #expect(timeoutResult.timedOut)
    #expect(timeoutResult.output.contains("started"))
}
