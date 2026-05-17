import Darwin
import Foundation
import Testing

@testable import OpenLolaCore


@Test
func udpPcmRouteReportRejectsInvalidEvidence() throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    report.verdict = .partial
    report.network.dscp.classification = .notTested
    report.network.dscp.observed = nil
    report.network.dscp.notTestedReason = ""

    #expect(throws: UdpPcmRouteValidationError.missingDscpNotTestedReason) {
        try report.validate()
    }

    var nilReasonReport = try loadRouteFixture(named: "direct-link-pass")
    nilReasonReport.verdict = .partial
    nilReasonReport.network.dscp.classification = .notTested
    nilReasonReport.network.dscp.observed = nil
    nilReasonReport.network.dscp.notTestedReason = nil

    #expect(throws: UdpPcmRouteValidationError.missingDscpNotTestedReason) {
        try nilReasonReport.validate()
    }

    try expectUdpPcmRouteError(.passWithoutDscpClassification) {
        $0.network.dscp.classification = .notTested
        $0.network.dscp.observed = nil
        $0.network.dscp.notTestedReason = "packet capture did not classify DSCP"
    }
    try expectUdpPcmRouteError(.passWithoutPacketCaptureCorrelation) {
        $0.network.packetCapture.receiverCorrelation = false
    }
    try expectUdpPcmRouteError(.passWithoutMeasuredDuration) {
        $0.measuredDurationSeconds = nil
    }
    try expectUdpPcmRouteError(.passWithDurationPacketCountMismatch(
        expected: 3_000,
        actual: 2_999
    )) {
        $0.metrics.packetsSent = 2_999
        $0.metrics.lostPackets = 0
    }
    try expectUdpPcmRouteError(.passWithNonPhysicalRoute(.localhostSmoke)) {
        $0.routeKind = .localhostSmoke
    }
    try expectUdpPcmRouteError(.passWithDocumentationIPAddress(
        "sender.ipAddress"
    )) {
        $0.sender.ipAddress = "192.0.2.10"
    }
    try expectUdpPcmRouteError(.passPacketAgeExceedsTarget(
        maxMicroseconds: 700,
        targetMicroseconds: 666
    )) {
        $0.metrics.packetAge.maxMicroseconds = 700
    }
    try expectUdpPcmRouteError(.passWithoutReceivedPackets) {
        $0.metrics.packetsReceived = 0
        $0.metrics.lostPackets = $0.metrics.packetsSent
        $0.metrics.packetAge = UdpPcmPacketAgeMetrics(
            p50Microseconds: 0,
            p95Microseconds: 0,
            p99Microseconds: 0,
            maxMicroseconds: 0
        )
    }
    try expectUdpPcmRouteError(.passWithReceiveErrors) {
        $0.metrics.receiveErrors = 1
    }
    try expectUdpPcmRouteError(.passWithBufferedPlayoutTarget(
        actualMicroseconds: 1_000,
        expectedMicroseconds: 666.6666666666666
    )) {
        $0.metrics.playoutTargetMicroseconds = 1_000
    }
    try expectUdpPcmRouteError(.passWithHiddenPlayoutGrowth) {
        $0.metrics.hiddenPlayoutGrowthDetected = true
    }
    try expectUdpPcmRouteError(.passWithLossOrLatePackets) {
        $0.metrics.duplicatePackets = 1
        $0.metrics.lostPackets = 1
    }
    try expectUdpPcmRouteError(.passWithDuplicateOrReorderedPackets) {
        $0.metrics.reorderedPackets = 1
    }
    try expectUdpPcmRouteError(.passWithPlaceholderField(
        "network.packetCapture.point"
    )) {
        $0.network.packetCapture.point = "fixture capture point"
    }

    var accountingReport = try loadRouteFixture(named: "direct-link-pass")
    accountingReport.metrics.packetsReceived = 2_999

    #expect(throws: UdpPcmRouteValidationError.packetAccountingMismatch(
        expectedLost: 1,
        actualLost: 0
    )) {
        try accountingReport.validate()
    }
}

private func expectUdpPcmRouteError(
    _ expected: UdpPcmRouteValidationError,
    mutate: (inout UdpPcmRouteReport) throws -> Void
) throws {
    var report = try loadRouteFixture(named: "direct-link-pass")
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

@Test
func udpPcmRouteRunConfigurationParsesAndRejectsInvalidShapes() throws {
    let senderConfiguration = try UdpPcmRouteRunConfiguration.parse([
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

    #expect(senderConfiguration.role == .sender)
    #expect(senderConfiguration.peer == "192.0.2.11")
    #expect(senderConfiguration.port == 5_004)
    #expect(senderConfiguration.packetMode.sampleRateHertz == 48_000)
    #expect(senderConfiguration.packetMode.framesPerPacket == 32)
    #expect(senderConfiguration.packetMode.channelCount == 2)
    #expect(senderConfiguration.durationSeconds == 2)
    #expect(senderConfiguration.outputPath == "reports/m05-sender.json")
    #expect(senderConfiguration.dscp == 46)

    let physicalConfiguration = try UdpPcmRouteRunConfiguration.parse([
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

    #expect(physicalConfiguration.role == .receiver)
    #expect(physicalConfiguration.routeKind == .directLink)
    #expect(physicalConfiguration.routeLabel == "direct-link-reference")
    #expect(physicalConfiguration.sender.interfaceName == "en5")
    #expect(physicalConfiguration.receiver.ipAddress == "10.10.20.11")
    #expect(physicalConfiguration.linkRateMbps == 1_000)
    #expect(physicalConfiguration.dscpObserved == 46)
    #expect(physicalConfiguration.dscpClassification == .honored)
    #expect(physicalConfiguration.packetCapture.receiverCorrelation == true)
    #expect(physicalConfiguration.verdict == .pass)

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

    let invalidFrames = routeConfiguration(
        packetMode: UdpPcmPacketMode(
            sampleRateHertz: 48_000,
            framesPerPacket: 0,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        )
    )
    let invalidSampleRate = routeConfiguration(
        packetMode: UdpPcmPacketMode(
            sampleRateHertz: 0,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        )
    )
    let invalidChannels = routeConfiguration(
        packetMode: UdpPcmPacketMode(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 0,
            sampleFormat: .int16LittleEndian
        )
    )
    let invalidDuration = routeConfiguration(durationSeconds: 0)

    #expect(throws: UdpPcmRouteRunConfigurationError.nonPositiveArgument("framesPerPacket")) {
        try invalidFrames.validate()
    }
    #expect(throws: UdpPcmRouteRunConfigurationError.nonPositiveArgument("sampleRateHertz")) {
        try invalidSampleRate.validate()
    }
    #expect(throws: UdpPcmRouteRunConfigurationError.nonPositiveArgument("channelCount")) {
        try invalidChannels.validate()
    }
    #expect(throws: UdpPcmRouteRunConfigurationError.nonPositiveArgument("durationSeconds")) {
        try invalidDuration.validate()
    }

    let boundedConfiguration = UdpPcmRouteRunConfiguration(
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

    #expect(boundedConfiguration.packetCount == 3_000)

    let overflowing = routeConfiguration(
        packetMode: UdpPcmPacketMode(
            sampleRateHertz: Int.max,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        ),
        durationSeconds: 2
    )

    #expect(throws: UdpPcmRouteRunConfigurationError.packetCountOverflow) {
        try overflowing.validate()
    }
}

@Test
func udpRouteRuntimeDeadlinesUseCheckedNanosecondArithmetic() throws {
    let now = DispatchTime.now().uptimeNanoseconds

    #expect(try routeDeadlineNanoseconds(durationSeconds: 1) > now)
    #expect(try routeDeadlineNanoseconds(timeoutMicroseconds: 1_000) > now)
    #expect(throws: UdpPcmRouteProbeError.receiveFailed(EINVAL)) {
        _ = try routeDeadlineNanoseconds(durationSeconds: 0)
    }
    #expect(throws: UdpPcmRouteProbeError.receiveFailed(EOVERFLOW)) {
        _ = try routeDeadlineNanoseconds(durationSeconds: Int.max)
    }
    #expect(throws: UdpPcmRouteProbeError.receiveFailed(EOVERFLOW)) {
        _ = try routeDeadlineNanoseconds(timeoutMicroseconds: UInt64.max)
    }
}

@Test
func udpPcmSocketOperationsRejectInvalidNonblockingAndReceiveInputs() throws {
    #expect(throws: UdpPcmRouteProbeError.fcntlFailed(EBADF)) {
        try setNonBlocking(-1)
    }

    #expect(throws: UdpPcmRouteProbeError.receiveFailed(EINVAL)) {
        _ = try receiveDatagram(socket: -1, byteCount: 0)
    }
    #expect(throws: UdpPcmRouteProbeError.receiveFailed(EINVAL)) {
        _ = try receiveDatagramIfAvailable(socket: -1, byteCount: 65_536)
    }

    let receiver = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { closeUdpSocket(receiver) }
    try bindLoopback(receiver, port: 0)

    let sender = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { closeUdpSocket(sender) }
    try sendDatagram(Data(), socket: sender, host: "127.0.0.1", port: try boundPort(receiver))

    #expect(throws: UdpPcmRouteProbeError.receiveFailed(EINVAL)) {
        _ = try receiveDatagram(socket: receiver, byteCount: 1)
    }
}

@Test
func udpPcmLocalhostRouteSmokesEmitPartialReports() throws {
    let continuousReport = try UdpPcmContinuousRouteLocalhostSmoke.run(packetCount: 5)

    try continuousReport.validate()

    #expect(continuousReport.routeKind == .localhostSmoke)
    #expect(continuousReport.verdict == .partial)
    #expect(continuousReport.metrics.packetsSent == 5)
    #expect(continuousReport.metrics.packetsReceived == 5)
    #expect(continuousReport.metrics.hiddenPlayoutGrowthDetected == false)

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

private func routeConfiguration(
    packetMode: UdpPcmPacketMode = UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    ),
    durationSeconds: Int = 1
) -> UdpPcmRouteRunConfiguration {
    UdpPcmRouteRunConfiguration(
        role: .receiver,
        peer: "127.0.0.1",
        port: 5_004,
        packetMode: packetMode,
        durationSeconds: durationSeconds,
        outputPath: "stdout",
        dscp: nil
    )
}

private func socketBufferByteCount(option: Int32, socket: Int32) throws -> Int32 {
    var byteCount: Int32 = 0
    var byteCountSize = socklen_t(MemoryLayout<Int32>.size)
    let result = getsockopt(
        socket,
        SOL_SOCKET,
        option,
        &byteCount,
        &byteCountSize
    )
    #expect(result == 0)
    return byteCount
}
