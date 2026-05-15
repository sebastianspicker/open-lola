import Foundation
import Testing

@testable import OpenLolaCore

@Test
func pingParserExtractsMacOSSummary() throws {
    let output = """
    PING 127.0.0.1 (127.0.0.1): 56 data bytes
    64 bytes from 127.0.0.1: icmp_seq=0 ttl=64 time=0.063 ms
    64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.097 ms

    --- 127.0.0.1 ping statistics ---
    2 packets transmitted, 2 packets received, 0.0% packet loss
    round-trip min/avg/max/stddev = 0.063/0.080/0.097/0.017 ms
    """

    let result = try NetworkDiagnosticsParser.parsePing(output)

    #expect(result.transmitted == 2)
    #expect(result.received == 2)
    #expect(result.packetLossPercent == 0)
    #expect(result.minRttMilliseconds == 0.063)
    #expect(result.averageRttMilliseconds == 0.080)
    #expect(result.maxRttMilliseconds == 0.097)
    #expect(result.standardDeviationMilliseconds == 0.017)
}

@Test
func pingParserDoesNotCrashWhenPacketTokenStartsSummary() throws {
    let output = """
    PING 127.0.0.1 (127.0.0.1): 56 data bytes

    --- 127.0.0.1 ping statistics ---
    packet packets transmitted
    round-trip min/avg/max/stddev = 0.063/0.080/0.097/0.017 ms
    """

    let result = try NetworkDiagnosticsParser.parsePing(output)

    #expect(result.packetLossPercent == 100)
}

@Test
func tracerouteParserExtractsHopCountAndTimings() throws {
    let output = """
    traceroute to 127.0.0.1 (127.0.0.1), 4 hops max, 40 byte packets
     1  127.0.0.1  0.347 ms  0.032 ms  0.029 ms
    """

    let result = try NetworkDiagnosticsParser.parseTraceroute(output)

    #expect(result.hops.count == 1)
    #expect(result.hops[0].index == 1)
    #expect(result.hops[0].address == "127.0.0.1")
    #expect(result.hops[0].timingsMilliseconds == [0.347, 0.032, 0.029])
    #expect(result.blocked == false)
}

@Test
func tracerouteParserStripsBracketedIPv6Address() throws {
    let output = """
    traceroute to 2001:db8::1, 4 hops max, 40 byte packets
     1  [2001:db8::1]  0.347 ms  0.032 ms  0.029 ms
    """

    let result = try NetworkDiagnosticsParser.parseTraceroute(output)

    #expect(result.hops.count == 1)
    #expect(result.hops[0].address == "2001:db8::1")
}

@Test
func networkDiagnosticsReportRejectsPassWhenTracerouteBlocked() throws {
    var report = NetworkDiagnosticsSyntheticSmoke.run()
    report.verdict = .pass
    report.traceroute.blocked = true
    report.traceroute.blockedReason = "operation not permitted"

    #expect(throws: NetworkDiagnosticsValidationError.passWithBlockedTraceroute) {
        try report.validate()
    }
}

@Test
func networkDiagnosticsReportRejectsPassWhenPingExceedsAoipThresholds() throws {
    var report = NetworkDiagnosticsSyntheticSmoke.run()
    report.verdict = .pass
    report.ping?.averageRttMilliseconds = NetworkDiagnosticsPassThresholds
        .maximumAverageRttMilliseconds + 0.1

    #expect(throws: NetworkDiagnosticsValidationError.passExceedsThreshold(
        field: "ping.averageRttMilliseconds",
        actual: 2.1,
        maximum: NetworkDiagnosticsPassThresholds.maximumAverageRttMilliseconds
    )) {
        try report.validate()
    }
}

@Test
func networkDiagnosticsVerdictPassesOnlyCleanProbeResults() {
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
}

@Test
func networkDiagnosticsReportRoundTrips() throws {
    let report = NetworkDiagnosticsSyntheticSmoke.run()
    let data = try report.prettyJSONData()
    let decoded = try NetworkDiagnosticsReport.decode(from: data)

    try decoded.validate()

    #expect(decoded == report)
}

@Test
func networkDiagnosticsProcessDrainsVerboseOutputWithoutPipeDeadlock() {
    let result = runNetworkDiagnosticsProcess(
        executable: "/usr/bin/python3",
        arguments: [
            "-c",
            "import sys; sys.stdout.write('x' * 1048576); sys.stdout.flush()",
        ],
        timeoutSeconds: 3
    )

    #expect(!result.timedOut)
    #expect(result.exitCode == 0)
    #expect(result.spawnError == nil)
    #expect(result.output.hasPrefix("x"))
    #expect(result.output.count <= 65_536)
}

@Test
func networkDiagnosticsProcessTimeoutKillsSigtermIgnoringChild() {
    let result = runNetworkDiagnosticsProcess(
        executable: "/usr/bin/python3",
        arguments: [
            "-c",
            "import signal, time; signal.signal(signal.SIGTERM, signal.SIG_IGN); print('started', flush=True); time.sleep(30)",
        ],
        timeoutSeconds: 1
    )

    #expect(result.timedOut)
    #expect(result.output.contains("started"))
}
