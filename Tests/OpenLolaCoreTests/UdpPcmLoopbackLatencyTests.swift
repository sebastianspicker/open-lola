import Foundation
import Testing

@testable import OpenLolaCore

@Test
func udpPcmLoopbackRunConfigurationParsesSenderArguments() throws {
    let configuration = try UdpPcmLoopbackRunConfiguration.parse([
        "--session-id", "duo-1",
        "--role", "sender",
        "--bind-host", "127.0.0.1",
        "--peer", "127.0.0.1",
        "--port", "5004",
        "--sample-rate", "48000",
        "--frames", "32",
        "--channels", "2",
        "--duration-seconds", "2",
        "--output", "reports/loopback.json",
        "--dscp", "46",
        "--diagnostics", "on",
        "--debug-output", "reports/loopback-debug.jsonl"
    ])

    #expect(configuration.sessionID == "duo-1")
    #expect(configuration.role == .sender)
    #expect(configuration.bindHost == "127.0.0.1")
    #expect(configuration.peer == "127.0.0.1")
    #expect(configuration.port == 5_004)
    #expect(configuration.packetMode.sampleRateHertz == 48_000)
    #expect(configuration.packetMode.framesPerPacket == 32)
    #expect(configuration.packetMode.channelCount == 2)
    #expect(configuration.durationSeconds == 2)
    #expect(configuration.outputPath == "reports/loopback.json")
    #expect(configuration.dscp == 46)
    #expect(configuration.diagnostics == .on)
    #expect(configuration.debugOutputPath == "reports/loopback-debug.jsonl")
    #expect(
        configuration.reciprocalCommand()
            == "open-lola udp-pcm-loopback-run --session-id duo-1 --role looper --bind-host 127.0.0.1 --peer 127.0.0.1 --port 5004 --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 2 --output reports/udp-pcm-loopback-duo-1-looper.json --dscp 46 --diagnostics on"
    )
}

@Test
func udpPcmLoopbackReportRejectsPassWhenEchoBytesWereModified() throws {
    var report = UdpPcmLoopbackSyntheticSmoke.run()
    report.verdict = .pass
    report.metrics.byteExactEcho = false

    #expect(throws: UdpPcmLoopbackValidationError.passWithoutByteExactEcho) {
        try report.validate()
    }
}

@Test
func udpPcmLoopbackSyntheticSmokeUsesSharedDefaultMode() throws {
    let report = UdpPcmLoopbackSyntheticSmoke.run()
    let defaultsSource = try readUdpPcmLoopbackSource(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackDefaults.swift"
    )
    let smokeSource = try readUdpPcmLoopbackSource(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSmokes.swift"
    )

    #expect(report.session.port == 5_004)
    #expect(report.packetMode.sampleRateHertz == 48_000)
    #expect(report.packetMode.framesPerPacket == 32)
    #expect(report.packetMode.channelCount == 2)
    #expect(defaultsSource.contains("enum UdpPcmLoopbackDefaults"))
    #expect(defaultsSource.contains("static let port: UInt16 = 5_004"))
    #expect(defaultsSource.contains("static let sampleRateHertz = 48_000"))
    #expect(defaultsSource.contains("static let framesPerPacket = 32"))
    #expect(smokeSource.contains("port: UdpPcmLoopbackDefaults.port"))
    #expect(smokeSource.contains("packetMode: UdpPcmLoopbackDefaults.packetMode"))
}

@Test
func udpPcmLoopbackReportKeepsIcmpComparisonDiagnosticOnly() throws {
    let report = UdpPcmLoopbackReport(
        id: "loopback-test",
        capturedAt: "2026-05-03T00:00:00Z",
        route: RouteIdentity(label: "localhost", topology: "local-echo"),
        session: UdpPcmLoopbackSessionAgreement(
            sessionID: "session-a",
            localEndpoint: "127.0.0.1",
            peerEndpoint: "127.0.0.1",
            port: 5_004,
            localRole: .sender,
            peerRole: .looper,
            packetMode: UdpPcmPacketMode(
                sampleRateHertz: 48_000,
                framesPerPacket: 32,
                channelCount: 2,
                sampleFormat: .int16LittleEndian
            ),
            durationSeconds: 1
        ),
        role: .sender,
        peer: "127.0.0.1",
        packetMode: UdpPcmPacketMode(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        ),
        metrics: UdpPcmLoopbackMetrics(
            packetsSent: 3,
            packetsEchoed: 3,
            lostPackets: 0,
            byteExactEcho: true,
            rtt: LoopbackTimingMetrics(
                p50Microseconds: 110,
                p95Microseconds: 130,
                p99Microseconds: 150,
                maxMicroseconds: 150
            ),
            oneWayEstimateMicroseconds: 55,
            jitterP99Microseconds: 20,
            duplicatePackets: 0,
            outOfOrderPackets: 0
        ),
        diagnostics: UdpPcmLoopbackDiagnosticsComparison(
            icmpAverageRttMicroseconds: 80,
            udpAverageRttMicroseconds: 120,
            deltaMicroseconds: 40,
            percentDelta: 50,
            classification: .udpHigher
        ),
        verdict: .partial,
        notes: "ICMP comparison is diagnostic only."
    )

    try report.validate()

    #expect(report.diagnostics?.classification == .udpHigher)
    #expect(report.verdict == .partial)
}

@Test
func udpPcmLoopbackDiagnosticsFloorsTinyIcmpPercentDeltaDenominator() {
    let comparison = UdpPcmLoopbackDiagnosticsComparison.compare(
        udpAverageRttMicroseconds: 100,
        ping: NetworkPingResult(
            transmitted: 1,
            received: 1,
            packetLossPercent: 0,
            minRttMilliseconds: 0,
            averageRttMilliseconds: 0.0000000005,
            maxRttMilliseconds: 0,
            standardDeviationMilliseconds: 0
        )
    )

    #expect(abs(comparison.icmpAverageRttMicroseconds - 0.0000005) < 0.00000001)
    #expect(abs(comparison.deltaMicroseconds - 99.9999995) < 0.00000001)
    #expect(comparison.percentDelta == 0)
    #expect(comparison.classification == .similar)
}

@Test
func udpPcmLoopbackReportsValidateSessionPair() throws {
    let (sender, looper) = makeLoopbackSessionPair()

    try sender.validateSessionPair(with: looper)
    try looper.validateSessionPair(with: sender)
}

@Test
func udpPcmLoopbackReportIDsUseUUIDsInsteadOfUnixSeconds() throws {
    let source = try readUdpPcmLoopbackHelperSource()

    #expect(source.contains("UUID().uuidString"))
    #expect(source.contains("\"udp-pcm-loopback-\\(role.rawValue)-\\(UUID().uuidString)\""))
    #expect(!source.contains("Int(Date().timeIntervalSince1970)"))
}

@Test
func udpPcmLoopbackSessionRejectsMismatchedRolePair() throws {
    let (sender, looper) = makeLoopbackSessionPair()
    var mismatched = looper
    mismatched.role = .sender
    mismatched.session.localRole = .sender
    mismatched.session.peerRole = .looper

    #expect(throws: UdpPcmLoopbackValidationError.sessionRolePairMismatch) {
        try sender.validateSessionPair(with: mismatched)
    }
}

@Test
func udpPcmLoopbackSessionRejectsMismatchedPacketMode() throws {
    let (sender, looper) = makeLoopbackSessionPair()
    var mismatched = looper
    mismatched.session.packetMode.framesPerPacket = 64
    mismatched.packetMode.framesPerPacket = 64

    #expect(throws: UdpPcmLoopbackValidationError.sessionPacketModeMismatch) {
        try sender.validateSessionPair(with: mismatched)
    }
}

@Test
func udpPcmLoopbackSessionRejectsMismatchedPort() throws {
    let (sender, looper) = makeLoopbackSessionPair()
    var mismatched = looper
    mismatched.session.port = 5_005

    #expect(throws: UdpPcmLoopbackValidationError.sessionPortMismatch) {
        try sender.validateSessionPair(with: mismatched)
    }
}

@Test
func udpPcmLoopbackSessionRejectsMismatchedPeer() throws {
    let (sender, looper) = makeLoopbackSessionPair()
    var mismatched = looper
    mismatched.session.localEndpoint = "192.0.2.10"

    #expect(throws: UdpPcmLoopbackValidationError.sessionEndpointMismatch) {
        try sender.validateSessionPair(with: mismatched)
    }
}

@Test
func udpPcmLoopbackSessionRejectsMismatchedDuration() throws {
    let (sender, looper) = makeLoopbackSessionPair()
    var mismatched = looper
    mismatched.session.durationSeconds = 3

    #expect(throws: UdpPcmLoopbackValidationError.sessionDurationMismatch) {
        try sender.validateSessionPair(with: mismatched)
    }
}

@Test
func udpPcmLoopbackLocalhostSmokeEchoesBytesExactly() throws {
    let report = try UdpPcmLoopbackLocalhostSmoke.run(packetCount: 4)

    try report.validate()

    #expect(report.metrics.packetsSent == 4)
    #expect(report.metrics.packetsEchoed == 4)
    #expect(report.metrics.byteExactEcho == true)
    #expect(report.verdict == .partial)
}

@Test
func udpPcmLoopbackLocalhostSmokeUsesHostOrderBoundPortForConfiguration() throws {
    let socketOperations = try readUdpPcmLoopbackSource(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift"
    )
    let smokeSource = try readUdpPcmLoopbackSource(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSmokes.swift"
    )

    #expect(socketOperations.contains("func boundHostPort(_ socket: Int32) throws -> UInt16"))
    #expect(socketOperations.contains("UInt16(bigEndian: try boundPort(socket))"))
    #expect(smokeSource.contains("let port = try boundHostPort(looperSocket)"))
    #expect(!smokeSource.contains("UInt16(bigEndian: try boundPort(looperSocket))"))
    #expect(smokeSource.contains("connectUdpSocket(senderSocket, host: configuration.peer, port: configuration.port.bigEndian)"))
}

@Test
func udpPcmRouteRunConfigurationParsesBindHost() throws {
    let configuration = try UdpPcmRouteRunConfiguration.parse([
        "--role", "receiver",
        "--bind-host", "127.0.0.1",
        "--peer", "127.0.0.1",
        "--port", "5004",
        "--sample-rate", "48000",
        "--frames", "32",
        "--channels", "2",
        "--duration-seconds", "2",
        "--output", "reports/route.json"
    ])

    #expect(configuration.bindHost == "127.0.0.1")
}

private func readUdpPcmLoopbackHelperSource() throws -> String {
    try readUdpPcmLoopbackSource("Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackHelpers.swift")
}

private func readUdpPcmLoopbackSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: root.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

private func makeLoopbackSessionPair() -> (
    sender: UdpPcmLoopbackReport,
    looper: UdpPcmLoopbackReport
) {
    let packetMode = UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
    let metrics = UdpPcmLoopbackMetrics(
        packetsSent: 2,
        packetsEchoed: 2,
        lostPackets: 0,
        byteExactEcho: true,
        rtt: LoopbackTimingMetrics(
            p50Microseconds: 100,
            p95Microseconds: 110,
            p99Microseconds: 120,
            maxMicroseconds: 120
        ),
        oneWayEstimateMicroseconds: 50,
        jitterP99Microseconds: 20,
        duplicatePackets: 0,
        outOfOrderPackets: 0
    )
    let sender = UdpPcmLoopbackReport(
        id: "sender",
        capturedAt: "2026-05-03T00:00:00Z",
        route: RouteIdentity(label: "direct", topology: "byte-exact-echo"),
        session: UdpPcmLoopbackSessionAgreement(
            sessionID: "duo-1",
            localEndpoint: "10.10.10.1",
            peerEndpoint: "10.10.10.2",
            port: 5_004,
            localRole: .sender,
            peerRole: .looper,
            packetMode: packetMode,
            durationSeconds: 2
        ),
        role: .sender,
        peer: "10.10.10.2",
        packetMode: packetMode,
        metrics: metrics,
        diagnostics: nil,
        verdict: .partial,
        notes: "sender"
    )
    let looper = UdpPcmLoopbackReport(
        id: "looper",
        capturedAt: "2026-05-03T00:00:00Z",
        route: RouteIdentity(label: "direct", topology: "byte-exact-echo"),
        session: UdpPcmLoopbackSessionAgreement(
            sessionID: "duo-1",
            localEndpoint: "10.10.10.2",
            peerEndpoint: "10.10.10.1",
            port: 5_004,
            localRole: .looper,
            peerRole: .sender,
            packetMode: packetMode,
            durationSeconds: 2
        ),
        role: .looper,
        peer: "10.10.10.1",
        packetMode: packetMode,
        metrics: UdpPcmLoopbackMetrics(
            packetsSent: 0,
            packetsEchoed: 2,
            lostPackets: 0,
            byteExactEcho: true,
            rtt: LoopbackTimingMetrics(
                p50Microseconds: 0,
                p95Microseconds: 0,
                p99Microseconds: 0,
                maxMicroseconds: 0
            ),
            oneWayEstimateMicroseconds: 0,
            jitterP99Microseconds: 0,
            duplicatePackets: 0,
            outOfOrderPackets: 0
        ),
        diagnostics: nil,
        verdict: .partial,
        notes: "looper"
    )
    return (sender, looper)
}
