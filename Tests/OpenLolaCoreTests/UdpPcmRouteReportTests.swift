import Darwin
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func udpPcmRouteReportFixtureDecodesAndValidates() throws {
    let report = try loadRouteFixture(named: "direct-link-pass")

    try report.validate()

    #expect(report.routeKind == .directLink)
    #expect(report.verdict == .pass)
    #expect(report.network.dscp.classification == .honored)
    #expect(report.measuredDurationSeconds == 2)
    #expect(report.metrics.packetsSent == 3_000)
    #expect(report.metrics.packetsReceived == 3_000)
}

@Test
func udpPcmRouteReportRequiresDscpNotTestedReason() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.verdict = .partial
    report.network.dscp.classification = .notTested
    report.network.dscp.observed = nil
    report.network.dscp.notTestedReason = ""

    #expect(throws: UdpPcmRouteValidationError.missingDscpNotTestedReason) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsNilDscpNotTestedReason() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.verdict = .partial
    report.network.dscp.classification = .notTested
    report.network.dscp.observed = nil
    report.network.dscp.notTestedReason = nil

    #expect(throws: UdpPcmRouteValidationError.missingDscpNotTestedReason) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsPassWithoutDscpClassification() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.network.dscp.classification = .notTested
    report.network.dscp.observed = nil
    report.network.dscp.notTestedReason = "packet capture did not classify DSCP"

    #expect(throws: UdpPcmRouteValidationError.passWithoutDscpClassification) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsPassWithoutPacketCaptureCorrelation() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.network.packetCapture.receiverCorrelation = false

    #expect(throws: UdpPcmRouteValidationError.passWithoutPacketCaptureCorrelation) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsPassWithoutMeasuredDuration() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.measuredDurationSeconds = nil

    #expect(throws: UdpPcmRouteValidationError.passWithoutMeasuredDuration) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsPassWithDurationPacketCountMismatch() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.metrics.packetsSent = 2_999
    report.metrics.lostPackets = 0

    #expect(throws: UdpPcmRouteValidationError.passWithDurationPacketCountMismatch(
        expected: 3_000,
        actual: 2_999
    )) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsPassWithNonPhysicalRoute() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.routeKind = .localhostSmoke

    #expect(throws: UdpPcmRouteValidationError.passWithNonPhysicalRoute(.localhostSmoke)) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsPassWithDocumentationIPAddress() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.sender.ipAddress = "192.0.2.10"

    #expect(throws: UdpPcmRouteValidationError.passWithDocumentationIPAddress(
        "sender.ipAddress"
    )) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsPassPacketAgeOverTarget() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.metrics.packetAge.maxMicroseconds = 700

    #expect(throws: UdpPcmRouteValidationError.passPacketAgeExceedsTarget(
        maxMicroseconds: 700,
        targetMicroseconds: 666
    )) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsPassWithBufferedPlayoutTarget() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.metrics.playoutTargetMicroseconds = 1_000

    #expect(throws: UdpPcmRouteValidationError.passWithBufferedPlayoutTarget(
        actualMicroseconds: 1_000,
        expectedMicroseconds: 666.6666666666666
    )) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsPassWithHiddenPlayoutGrowth() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.metrics.hiddenPlayoutGrowthDetected = true

    #expect(throws: UdpPcmRouteValidationError.passWithHiddenPlayoutGrowth) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsPassWithDuplicateOrReorderedPackets() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.metrics.duplicatePackets = 1

    #expect(throws: UdpPcmRouteValidationError.passWithDuplicateOrReorderedPackets) {
        try report.validate()
    }

    report.metrics.duplicatePackets = 0
    report.metrics.reorderedPackets = 1

    #expect(throws: UdpPcmRouteValidationError.passWithDuplicateOrReorderedPackets) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsPassWithPlaceholderEvidence() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.network.packetCapture.point = "fixture capture point"

    #expect(throws: UdpPcmRouteValidationError.passWithPlaceholderField(
        "network.packetCapture.point"
    )) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportRejectsPacketAccountingMismatch() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.metrics.packetsReceived = 2_999

    #expect(throws: UdpPcmRouteValidationError.packetAccountingMismatch(
        expectedLost: 1,
        actualLost: 0
    )) {
        try report.validate()
    }
}

@Test
func udpPcmRouteReportJSONRoundTripPreservesReport() throws {
    let report = try loadRouteFixture(named: "direct-link-pass")
    let jsonData = try report.prettyJSONData()
    let decoded = try UdpPcmRouteReport.decode(from: jsonData)

    #expect(decoded == report)
}

@Test
func transportErrorHandlingPolicyDocumentsThrowNilAndPartialConventions() throws {
    let policy = try readUdpPcmRouteSource("docs/architecture/transport-error-handling.md")

    #expect(policy.contains("Configuration, socket setup, protocol validation, and malformed packet handling throw typed errors."))
    #expect(policy.contains("Nonblocking receive helpers may return `nil` only when no packet is currently available."))
    #expect(policy.contains("Socket, decode, validation, and background task failures must propagate to the caller."))
    #expect(policy.contains("Partial reports represent missing external evidence or environmental limitations, not swallowed runtime failures."))
}

@Test
func udpPcmRoutePacketAgeMetricsSortsSamplesOncePerEpoch() throws {
    let metrics = packetAgeMetrics(for: [30, 10, 50, 20, 40])
    let source = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmRouteHelpers.swift")
    let metricsBody = try #require(source.range(
        of: #"func packetAgeMetrics\(for ages: \[Double\]\) -> UdpPcmPacketAgeMetrics \{[\s\S]*?\n\}"#,
        options: .regularExpression
    ).map { String(source[$0]) })

    #expect(metrics.p50Microseconds == 30)
    #expect(metrics.p95Microseconds == 50)
    #expect(metrics.p99Microseconds == 50)
    #expect(metrics.maxMicroseconds == 50)
    #expect(metricsBody.contains("let sortedAges = ages.sorted()"))
    #expect(metricsBody.contains("percentile(sortedValues: sortedAges, rank: 0.50)"))
    #expect(metricsBody.contains("percentile(sortedValues: sortedAges, rank: 0.95)"))
    #expect(metricsBody.contains("percentile(sortedValues: sortedAges, rank: 0.99)"))
    #expect(metricsBody.components(separatedBy: ".sorted()").count - 1 == 1)
}

@Test
func udpPcmRouteRunConfigurationParsesSenderArguments() throws {
    let configuration = try UdpPcmRouteRunConfiguration.parse([
        "--role", "sender",
        "--peer", "192.0.2.11",
        "--port", "5004",
        "--sample-rate", "48000",
        "--frames", "32",
        "--channels", "2",
        "--duration-seconds", "2",
        "--output", "reports/m05-sender.json",
        "--dscp", "46"
    ])

    #expect(configuration.role == .sender)
    #expect(configuration.peer == "192.0.2.11")
    #expect(configuration.port == 5_004)
    #expect(configuration.packetMode.sampleRateHertz == 48_000)
    #expect(configuration.packetMode.framesPerPacket == 32)
    #expect(configuration.packetMode.channelCount == 2)
    #expect(configuration.durationSeconds == 2)
    #expect(configuration.outputPath == "reports/m05-sender.json")
    #expect(configuration.dscp == 46)
}

@Test
func udpPcmRouteRunConfigurationParsesPhysicalEvidenceArguments() throws {
    let configuration = try UdpPcmRouteRunConfiguration.parse([
        "--role", "receiver",
        "--bind-host", "10.10.20.11",
        "--peer", "10.10.20.10",
        "--port", "5004",
        "--sample-rate", "48000",
        "--frames", "32",
        "--channels", "2",
        "--duration-seconds", "2",
        "--output", "reports/m05-direct-receiver.json",
        "--dscp", "46",
        "--route-kind", "directLink",
        "--route-label", "direct-link-reference",
        "--route-topology", "mac-to-mac-direct-cable",
        "--sender-label", "sender-mac",
        "--sender-host", "sender-mini-a",
        "--sender-interface", "en5",
        "--sender-ip", "10.10.20.10",
        "--receiver-label", "receiver-mac",
        "--receiver-host", "receiver-mini-b",
        "--receiver-interface", "en5",
        "--receiver-ip", "10.10.20.11",
        "--link-rate-mbps", "1000",
        "--vlan", "none",
        "--multicast-policy", "unicast-only",
        "--dscp-observed", "46",
        "--dscp-classification", "honored",
        "--capture-point", "receiver en5 tcpdump capture",
        "--capture-correlated", "true",
        "--capture-notes", "Receiver capture matched expected packet count and timestamp window.",
        "--title", "Measured direct-link UDP PCM route report",
        "--notes", "Measured direct-link route with fixed playout target.",
        "--verdict", "pass"
    ])

    #expect(configuration.role == .receiver)
    #expect(configuration.routeKind == .directLink)
    #expect(configuration.routeLabel == "direct-link-reference")
    #expect(configuration.sender.interfaceName == "en5")
    #expect(configuration.receiver.ipAddress == "10.10.20.11")
    #expect(configuration.linkRateMbps == 1_000)
    #expect(configuration.dscpObserved == 46)
    #expect(configuration.dscpClassification == .honored)
    #expect(configuration.packetCapture.receiverCorrelation == true)
    #expect(configuration.verdict == .pass)
}

@Test
func udpPcmRouteHelpListsPhysicalEvidenceArguments() throws {
    let helpSource = try String(
        contentsOfFile: "Sources/open-lola/main.swift",
        encoding: .utf8
    )
    for flag in [
        "--route-label",
        "--route-topology",
        "--sender-label",
        "--sender-host",
        "--sender-ip",
        "--receiver-label",
        "--receiver-host",
        "--receiver-ip",
        "--link-rate-mbps",
        "--vlan",
        "--multicast-policy",
        "--capture-notes",
        "--dscp-not-tested-reason",
        "--report-id",
        "--title",
        "--notes"
    ] {
        #expect(helpSource.contains(flag))
    }
}

@Test
func udpPcmRouteRunConfigurationRejectsInvalidRole() {
    #expect(throws: UdpPcmRouteRunConfigurationError.invalidRole("monitor")) {
        _ = try UdpPcmRouteRunConfiguration.parse([
            "--role", "monitor",
            "--peer", "192.0.2.11",
            "--port", "5004",
            "--sample-rate", "48000",
            "--frames", "32",
            "--channels", "2",
            "--duration-seconds", "2",
            "--output", "reports/m05-sender.json"
        ])
    }
}

@Test
func udpPcmRouteRunConfigurationRejectsInvalidPacketModeDuringParse() throws {
    let source = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift")

    #expect(throws: UdpPcmRouteRunConfigurationError.nonPositiveArgument("--frames")) {
        _ = try UdpPcmRouteRunConfiguration.parse([
            "--role", "receiver",
            "--peer", "127.0.0.1",
            "--port", "5004",
            "--sample-rate", "48000",
            "--frames", "0",
            "--channels", "2",
            "--duration-seconds", "2",
            "--output", "reports/route.json"
        ])
    }
    #expect(source.contains("try configuration.validate()"))
}

@Test
func udpPcmRouteRunConfigurationValidatesProgrammaticInitializers() throws {
    let invalid = UdpPcmRouteRunConfiguration(
        role: .receiver,
        peer: "127.0.0.1",
        port: 5_004,
        packetMode: UdpPcmPacketMode(
            sampleRateHertz: 48_000,
            framesPerPacket: 0,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        ),
        durationSeconds: 1,
        outputPath: "stdout",
        dscp: nil
    )
    let source = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift")

    #expect(throws: UdpPcmRouteRunConfigurationError.nonPositiveArgument("framesPerPacket")) {
        try invalid.validate()
    }
    #expect(!source.contains("precondition(durationSeconds > 0"))
    #expect(!source.contains("precondition(packetMode.sampleRateHertz > 0"))
    #expect(!source.contains("precondition(packetMode.framesPerPacket > 0"))
}

@Test
func udpPcmRouteRunConfigurationComputesBoundedPacketCount() throws {
    let configuration = UdpPcmRouteRunConfiguration(
        role: .sender,
        peer: "127.0.0.1",
        port: 5_004,
        packetMode: UdpPcmPacketMode(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        ),
        durationSeconds: 2,
        outputPath: "reports/m05-sender.json",
        dscp: nil
    )

    #expect(configuration.packetCount == 3_000)
}

@Test
func udpPcmRouteRunConfigurationUsesCheckedPacketCountArithmetic() throws {
    let source = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift")

    #expect(source.contains("durationSeconds.multipliedReportingOverflow"))
    #expect(source.contains("precondition(!overflow"))
}

@Test
func udpRouteRuntimeDeadlinesUseCheckedNanosecondArithmetic() throws {
    let helperSource = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmRouteHelpers.swift")
    let continuousSource = try readUdpPcmRouteSource(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift"
    )
    let loopbackSource = try readUdpPcmRouteSource(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSocketRunners.swift"
    )
    let natSource = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift")

    #expect(helperSource.contains("func routeDeadlineNanoseconds(durationSeconds: Int) throws -> UInt64"))
    #expect(helperSource.contains("multipliedReportingOverflow(by: 1_000_000_000)"))
    #expect(helperSource.contains("addingReportingOverflow"))
    #expect(continuousSource.contains("try routeDeadlineNanoseconds(durationSeconds: configuration.durationSeconds)"))
    #expect(loopbackSource.contains("try routeDeadlineNanoseconds(durationSeconds: durationSeconds)"))
    #expect(natSource.contains("try routeDeadlineNanoseconds(durationSeconds: configuration.durationSeconds)"))
}

@Test
func udpAndNatCliPositiveIntegerInputsAreBounded() throws {
    let routeHelperSource = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmRouteHelpers.swift")
    let natHelperSource = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteHelpers.swift")

    #expect(routeHelperSource.contains("routeRunPositiveIntegerBounds"))
    #expect(routeHelperSource.contains("\"--duration-seconds\": 86_400"))
    #expect(routeHelperSource.contains("\"--sample-rate\": 384_000"))
    #expect(routeHelperSource.contains("validateRouteRunPositiveIntegerBound"))
    #expect(natHelperSource.contains("natPositiveIntegerBounds"))
    #expect(natHelperSource.contains("\"--duration-seconds\": 86_400"))
    #expect(natHelperSource.contains("\"--timeout-seconds\": 86_400"))
    #expect(natHelperSource.contains("validateNatPositiveIntegerBound"))
}

@Test
func udpPcmSocketOperationsVerifyRequestedBufferSizes() throws {
    let source = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift")

    #expect(source.contains("4 MiB absorbs short scheduler stalls"))
    #expect(source.contains("getsockopt("))
    #expect(source.contains("actualByteCount < byteCount"))
    #expect(source.contains("UDP socket buffer option"))
}

@Test
func udpPcmSocketOperationsUsePosixFcntlFailureSentinel() throws {
    let source = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift")

    #expect(source.contains("if flags == -1"))
    #expect(source.contains("if setFlagsResult == -1"))
    #expect(!source.contains("if flags < 0"))
}

@Test
func udpPcmSocketOperationsRejectInvalidReceiveByteCountsBeforeAllocation() throws {
    #expect(throws: UdpPcmRouteProbeError.receiveFailed(EINVAL)) {
        _ = try receiveDatagram(socket: -1, byteCount: 0)
    }
    #expect(throws: UdpPcmRouteProbeError.receiveFailed(EINVAL)) {
        _ = try receiveDatagramIfAvailable(socket: -1, byteCount: 65_536)
    }
}

@Test
func udpPcmSocketOperationsRejectZeroByteReceives() throws {
    let source = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift")

    #expect(source.contains("guard received > 0 else"))
    #expect(source.contains("throw UdpPcmRouteProbeError.receiveFailed(EINVAL)"))
}

@Test
func udpReceiveLoopsUseSocketReadinessInsteadOfDirectMicroSleeps() throws {
    let socketSource = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift")
    let continuousSource = try readUdpPcmRouteSource(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift"
    )
    let loopbackSource = try readUdpPcmRouteSource(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSocketRunners.swift"
    )
    let natSource = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift")
    let avSource = try readUdpPcmRouteSource(
        "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift"
    )

    #expect(socketSource.contains("func waitForReadableSocket"))
    #expect(socketSource.contains("poll(&descriptor"))
    #expect(continuousSource.contains("waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)"))
    #expect(loopbackSource.contains("waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)"))
    #expect(natSource.contains("waitForReadableSocket(socket: socket, timeoutMicroseconds: 1_000)"))
    #expect(avSource.contains("directPeerAVLoopWaitTimeoutMicroseconds("))
    #expect(avSource.contains("waitForIncomingMedia(timeoutMicroseconds: waitTimeoutMicroseconds)"))
    #expect(!continuousSource.contains("usleep("))
    #expect(!loopbackSource.contains("usleep("))
    #expect(!natSource.contains("usleep("))
    #expect(!avSource.contains("usleep("))
}

@Test
func udpLocalhostSmokesUseReadinessSignalsInsteadOfFixedStartupSleeps() throws {
    let continuousSource = try readUdpPcmRouteSource(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift"
    )
    let loopbackSmokeSource = try readUdpPcmRouteSource(
        "Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSmokes.swift"
    )
    let natSmokeSource = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift")
    let natRunnerSource = try readUdpPcmRouteSource(
        "Sources/OpenLolaCore/Network/NAT/NatRendezvousRelayRunners.swift"
    )

    #expect(continuousSource.contains("let ready = DispatchSemaphore(value: 0)"))
    #expect(loopbackSmokeSource.contains("let ready = DispatchSemaphore(value: 0)"))
    #expect(natSmokeSource.contains("serverReady"))
    #expect(natSmokeSource.contains("relayReady"))
    #expect(natRunnerSource.contains("onReady?()"))
    #expect(!continuousSource.contains("Thread.sleep"))
    #expect(!loopbackSmokeSource.contains("Thread.sleep"))
    #expect(!natSmokeSource.contains("Thread.sleep"))
}

@Test
func udpPcmLoopbackReceiveValidatesSourceAddressLength() throws {
    let source = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSocketRunners.swift")

    #expect(source.contains("recvfrom(socket, bytes.baseAddress, byteCount, 0, socketAddress, &addressLength)"))
    #expect(source.contains("guard addressLength == socklen_t(MemoryLayout<sockaddr_in>.size) else"))
    #expect(source.contains("throw UdpPcmRouteProbeError.receiveFailed(EINVAL)"))
}

@Test
func udpPcmContinuousReceiverValidatesModeBeforeCountingPacket() throws {
    let source = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift")
    let modeGuard = try #require(source.range(of: "guard packet.header.sampleRateHertz"))
    let receiveIncrement = try #require(source.range(of: "packetsReceived += 1"))

    #expect(modeGuard.upperBound < receiveIncrement.lowerBound)
    #expect(source.contains("receiveErrors += 1"))
}

@Test
func udpPcmContinuousReceiverComputesLossFromUniqueSequences() throws {
    let source = try readUdpPcmRouteSource("Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift")

    #expect(source.contains("uniquePacketsReceived"))
    #expect(source.contains("let lostPackets = max(0, configuration.packetCount - result.uniquePacketsReceived)"))
    #expect(source.contains("&& seenSequences.count < configuration.packetCount"))
    #expect(source.contains("duplicatePackets += 1"))
}

@Test
func udpPcmContinuousLocalhostRouteRunEmitsPartialReport() throws {
    let report = try UdpPcmContinuousRouteLocalhostSmoke.run(packetCount: 5)

    try report.validate()

    #expect(report.routeKind == .localhostSmoke)
    #expect(report.verdict == .partial)
    #expect(report.metrics.packetsSent == 5)
    #expect(report.metrics.packetsReceived == 5)
    #expect(report.metrics.hiddenPlayoutGrowthDetected == false)
}

@Test
func udpPcmLocalhostRouteProbeEmitsPartialReport() throws {
    let report = try UdpPcmRouteLocalhostSmoke.run(packetCount: 3)

    try report.validate()

    #expect(report.routeKind == .localhostSmoke)
    #expect(report.verdict == .partial)
    #expect(report.metrics.packetsSent == 3)
    #expect(report.metrics.packetsReceived == 3)
    #expect(report.network.dscp.classification == .notTested)
}

private func loadRouteFixture(named name: String) throws -> UdpPcmRouteReport {
    let url = try routeFixtureURL(named: name)
    return try UdpPcmRouteReport.decode(from: Data(contentsOf: url))
}

private func routeFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "UdpPcmRoutes/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "UdpPcmRoutes/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}

private func readUdpPcmRouteSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
