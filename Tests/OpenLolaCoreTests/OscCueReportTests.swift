import Foundation
import Testing

@testable import OpenLolaCore

@Test
func oscCueMessageRoundTripsAndRejectsMalformedPackets() throws {
    let message = OscCueMessage(
        cueId: "cue-000",
        senderTimestampNanoseconds: 123_456_789
    )

    let packet = try message.packetData()
    let decoded = try OscCueMessage.decodePacket(packet)

    #expect(decoded == message)
    #expect(packet.prefix(16) == Data([47, 111, 112, 101, 110, 45, 108, 111, 108, 97, 47, 99, 117, 101, 0, 0]))

    var truncatedPacket = packet
    truncatedPacket.removeLast()

    #expect(throws: OscCuePacketError.missingNullTerminator) {
        _ = try OscCueMessage.decodePacket(truncatedPacket)
    }

    var invalidTimestampPacket = Data()
    invalidTimestampPacket.append(oscString(OscCueMessage.address))
    invalidTimestampPacket.append(oscString(OscCueMessage.typeTags))
    invalidTimestampPacket.append(oscString("cue-000"))
    invalidTimestampPacket.append(oscString("not-a-number"))

    #expect(throws: OscCuePacketError.invalidTimestamp("not-a-number")) {
        _ = try OscCueMessage.decodePacket(invalidTimestampPacket)
    }
}

@Test
func oscCueUdpSocketBoundariesRejectUnsafeDescriptorsTimeoutsAndLargeDatagrams() throws {
    #expect(oscCueSocketDescriptorFitsFDSet(0))
    #expect(oscCueSocketDescriptorFitsFDSet(Int32(FD_SETSIZE - 1)))
    #expect(!oscCueSocketDescriptorFitsFDSet(-1))
    #expect(!oscCueSocketDescriptorFitsFDSet(Int32(FD_SETSIZE)))

    let descriptor = try makeUdpSocket(receiveTimeoutSeconds: 10)
    defer { close(descriptor) }
    try bindLoopback(descriptor, port: 0)

    #expect(throws: OscCueError.receiveFailed(ETIMEDOUT)) {
        _ = try receiveUdpOscMessage(socket: descriptor, timeoutMilliseconds: 1)
    }

    let largeDatagramDescriptor = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { close(largeDatagramDescriptor) }
    try bindLoopback(largeDatagramDescriptor, port: 0)
    let port = try boundUdpPort(for: largeDatagramDescriptor)
    let cueId = String(repeating: "a", count: 5_000)
    let message = OscCueMessage(cueId: cueId, senderTimestampNanoseconds: 123)

    try sendUdpPacket(try message.packetData(), socket: largeDatagramDescriptor, port: port)
    let received = try receiveUdpOscMessage(socket: largeDatagramDescriptor, timeoutMilliseconds: 1_000)

    #expect(received == message)
}

@Test
func oscCueLoopbackReportsCoverSyntheticAndLiveUdpEvidence() throws {
    let syntheticReport = OscCueSyntheticLoopback.run()

    try syntheticReport.validate()

    #expect(syntheticReport.cues.map(\.cueId) == ["cue-000", "cue-001", "cue-002"])
    #expect(syntheticReport.jitter.p50Microseconds == 1_100)
    #expect(syntheticReport.jitter.maxMicroseconds == 1_200)

    let liveReport = try OscCueUdpLoopbackRunner.run(count: 3)

    try liveReport.validate()

    #expect(liveReport.peer.kind == .localLoopback)
    #expect(liveReport.transport?.protocolName == "udp")
    #expect(liveReport.transport?.liveUdpLoopback == true)
    #expect(liveReport.transport?.sentPackets == 3)
    #expect(liveReport.transport?.receivedPackets == 3)
    #expect(liveReport.verdict == .partial)
}

@Test
func oscCueExternalRunConfigurationAndRunnerBuildExternalPartialReport() throws {
    let configuration = try OscCueExternalRunConfiguration.parse([
        "--audio-baseline", "m05-route-baseline-required",
        "--port", "0",
        "--count", "3",
        "--first-external-peer", "chataigne",
        "--external-host", "192.0.2.20",
        "--external-port", "8000",
        "--external-available", "false",
        "--external-unavailable-reason", "Chataigne not running",
        "--output", "reports/m11-osc-cue-external.json",
    ])

    #expect(configuration.audioBaselineReportId == "m05-route-baseline-required")
    #expect(configuration.port == 0)
    #expect(configuration.count == 3)
    #expect(configuration.firstExternalPeerKind == .chataigne)
    #expect(configuration.externalHost == "192.0.2.20")
    #expect(configuration.externalPort == 8_000)
    #expect(configuration.externalAvailable == false)
    #expect(configuration.externalUnavailableReason == "Chataigne not running")
    #expect(configuration.outputPath == "reports/m11-osc-cue-external.json")

    #expect(throws: OscCueExternalRunConfigurationError.invalidExternalPeerKind("localLoopback")) {
        _ = try OscCueExternalRunConfiguration.parse([
            "--audio-baseline", "m05-route-baseline-required",
            "--port", "0",
            "--count", "3",
            "--first-external-peer", "localLoopback",
            "--external-host", "127.0.0.1",
            "--external-port", "8000",
            "--external-available", "true",
            "--output", "reports/m11-osc-cue-external.json",
        ])
    }

    let report = try OscCueExternalRunner.run(configuration: configuration)

    try report.validate()

    #expect(report.id == "m11-osc-cue-external-run")
    #expect(report.peer.kind == .localLoopback)
    #expect(report.transport?.liveUdpLoopback == true)
    #expect(report.transport?.sentPackets == 3)
    #expect(report.transport?.receivedPackets == 3)
    #expect(report.firstExternalPeer?.kind == .chataigne)
    #expect(report.firstExternalPeer?.host == "192.0.2.20")
    #expect(report.firstExternalPeer?.port == 8_000)
    #expect(report.firstExternalPeer?.available == false)
    #expect(report.audioImpact.baselineReportId == "m05-route-baseline-required")
    #expect(report.verdict == .partial)
}

@Test
func oscCueReportValidatesCountsJitterAndRejectsInvalidPassEvidence() throws {
    var report = try loadOscCueFixture(named: "osc-cue-partial")
    report.message.cueCount = 4

    #expect(throws: OscCueValidationError.cueCountMismatch(expected: 3, actual: 4)) {
        try report.validate()
    }

    var roundingReport = try loadOscCueFixture(named: "osc-cue-partial")
    roundingReport.cues[0].jitterMicroseconds += 0.00005

    try roundingReport.validate()
    #expect(roundingReport.verdict == .partial)

    try expectOscCueError(.passWithoutLiveUdpLoopback) {
        $0.transport = nil
    }
    try expectOscCueError(.passWithoutFirstExternalPeer) {
        $0.firstExternalPeer = nil
    }
    try expectOscCueError(.passWithoutFirstExternalPeer) {
        $0.firstExternalPeer?.available = false
        $0.firstExternalPeer?.unavailableReason = "Chataigne not running"
    }
    try expectOscCueError(.passIncreasesAudioP99(baseline: 80, cueLoop: 81)) {
        $0.audioImpact.cueLoopCallbackP99Microseconds = 81
    }
    try expectOscCueError(.passChangesAudioPlayoutTarget(baseline: 32, cueLoop: 48)) {
        $0.audioImpact.cueLoopPlayoutTargetFrames = 48
    }
    try expectOscCueError(.passWithoutAvailablePeer) {
        $0.peer.available = false
        $0.peer.unavailableReason = "external peer missing"
    }
    try expectOscCueError(.passWithSyntheticAudioImpact) {
        $0.audioImpact.synthetic = true
    }
    try expectOscCueError(.passWithoutMeasuredLoopback) {
        $0.peer.kind = .openStageControl
    }
}

@Test
func atemReadOnlyControlReportParserProbeAndPassPolicyStayReadOnly() throws {
    let report = AtemReadOnlyControlReport(
        id: "m11-atem-readonly-test",
        title: "M11 ATEM read-only test",
        capturedAt: "2026-05-02T00:00:00Z",
        ipAddress: "192.0.2.10",
        model: "ATEM Mini Pro",
        firmware: "9.6",
        programSource: "Camera 1",
        previewSource: "Camera 2",
        tally: "program=1 preview=2",
        audioMixerState: "follow-video",
        health: .connected,
        armedCommandsAllowed: false,
        verdict: .partial,
        notes: "Read-only test report."
    )

    try report.validate()
    let decoded = try AtemReadOnlyControlReport.decode(from: report.prettyJSONData())

    #expect(decoded == report)

    var armedReport = AtemReadOnlyControlProbe.makeUnavailableReport(
        host: "192.0.2.10",
        capturedAt: "2026-05-02T00:00:00Z"
    )
    armedReport.armedCommandsAllowed = true

    #expect(throws: AtemReadOnlyControlValidationError.commandsArmed) {
        try armedReport.validate()
    }

    let unavailableReport = AtemReadOnlyControlProbe.makeUnavailableReport(
        host: "192.0.2.10",
        capturedAt: "2026-05-02T00:00:00Z"
    )

    try unavailableReport.validate()

    #expect(unavailableReport.ipAddress == "192.0.2.10")
    #expect(unavailableReport.health == .unavailable)
    #expect(unavailableReport.armedCommandsAllowed == false)
    #expect(unavailableReport.verdict == .partial)

    let configuration = AtemReadOnlyProbeConfiguration(
        host: "192.0.2.10",
        port: 9_910,
        timeoutMilliseconds: 150,
        pollIntervalMilliseconds: 500,
        networkInterface: "en5",
        sameNetworkAsAudio: false,
        outputPath: "reports/m11-atem-readonly.json"
    )
    let observation = AtemReadOnlyNetworkObservation(
        health: .timeout,
        durationMilliseconds: 150,
        errorMessage: "connect timed out"
    )

    let timeoutReport = AtemReadOnlyControlProbe.makeReport(
        configuration: configuration,
        observation: observation,
        capturedAt: "2026-05-02T00:00:00Z"
    )

    try timeoutReport.validate()

    #expect(timeoutReport.ipAddress == "192.0.2.10")
    #expect(timeoutReport.controlPort == 9_910)
    #expect(timeoutReport.protocolName == "tcp-reachability")
    #expect(timeoutReport.networkInterface == "en5")
    #expect(timeoutReport.sameNetworkAsAudio == false)
    #expect(timeoutReport.readOnlyPollIntervalMilliseconds == 500)
    #expect(timeoutReport.connectionAttemptMilliseconds == 150)
    #expect(timeoutReport.errorMessage == "connect timed out")
    #expect(timeoutReport.armedCommandsAllowed == false)
    #expect(timeoutReport.verdict == .partial)

    let connectedReport = AtemReadOnlyControlProbe.makeReport(
        configuration: configuration,
        observation: AtemReadOnlyNetworkObservation(
            health: .connected,
            durationMilliseconds: 5,
            errorMessage: nil
        ),
        capturedAt: "2026-05-02T00:00:00Z"
    )

    try connectedReport.validate()

    #expect(connectedReport.notes.contains("TCP handshake completed, not ATEM protocol verified"))

    let parsedConfiguration = try AtemReadOnlyProbeConfiguration.parse([
        "--host", "192.0.2.10",
        "--port", "9910",
        "--timeout-milliseconds", "150",
        "--poll-interval-milliseconds", "500",
        "--network-interface", "en5",
        "--same-network-as-audio", "false",
        "--output", "reports/m11-atem-readonly.json",
    ])

    #expect(parsedConfiguration.host == "192.0.2.10")
    #expect(parsedConfiguration.port == 9_910)
    #expect(parsedConfiguration.timeoutMilliseconds == 150)
    #expect(parsedConfiguration.pollIntervalMilliseconds == 500)
    #expect(parsedConfiguration.networkInterface == "en5")
    #expect(parsedConfiguration.sameNetworkAsAudio == false)
    #expect(parsedConfiguration.outputPath == "reports/m11-atem-readonly.json")

    let dashPrefixedInterface = try AtemReadOnlyProbeConfiguration.parse([
        "--host", "192.0.2.10",
        "--network-interface", "--en5",
        "--output", "reports/m11-atem-readonly.json",
    ])

    #expect(dashPrefixedInterface.networkInterface == "--en5")

    #expect(throws: AtemReadOnlyProbeConfigurationError.argumentExceedsMaximum(
        argument: "--timeout-milliseconds",
        value: 30_001,
        maximum: 30_000
    )) {
        _ = try AtemReadOnlyProbeConfiguration.parse([
            "--host", "192.0.2.10",
            "--timeout-milliseconds", "30001",
            "--output", "reports/m11-atem-readonly.json",
        ])
    }

    #expect(throws: AtemReadOnlyProbeConfigurationError.invalidPort("70000")) {
        _ = try AtemReadOnlyProbeConfiguration.parse([
            "--host", "192.0.2.10",
            "--port", "70000",
            "--output", "reports/m11-atem-readonly.json",
        ])
    }

    #expect(throws: AtemReadOnlyProbeConfigurationError.invalidIPv4Host("atem.local")) {
        _ = try AtemReadOnlyProbeConfiguration.parse([
            "--host", "atem.local",
            "--output", "reports/m11-atem-readonly.json",
        ])
    }

    try expectAtemReadOnlyError(.passWithPlaceholderField("model")) {
        $0.model = "TODO(human): record ATEM model"
    }
    try expectAtemReadOnlyError(.passWithoutNetworkEvidence) {
        $0.protocolName = nil
    }
    try expectAtemReadOnlyError(.passWithoutNetworkEvidence) {
        $0.networkInterface = nil
    }
}

private func passCandidateReport() throws -> OscCueReport {
    var report = try loadOscCueFixture(named: "osc-cue-partial")
    report.verdict = .pass
    report.transport = OscCueTransportEvidence(
        protocolName: "udp",
        localBindHost: "127.0.0.1",
        peerHost: "127.0.0.1",
        peerPort: 49_000,
        liveUdpLoopback: true,
        sentPackets: report.cues.count,
        receivedPackets: report.cues.count
    )
    report.firstExternalPeer = OscCueExternalPeerEvidence(
        kind: .chataigne,
        host: "192.0.2.20",
        port: 8_000,
        available: true,
        unavailableReason: nil
    )
    report.audioImpact.synthetic = false
    return report
}

private func expectOscCueError(
    _ expected: OscCueValidationError,
    mutate: (inout OscCueReport) throws -> Void
) throws {
    var report = try passCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func expectAtemReadOnlyError(
    _ expected: AtemReadOnlyControlValidationError,
    mutate: (inout AtemReadOnlyControlReport) throws -> Void
) throws {
    var report = atemReadOnlyPassCandidateReport()
    try mutate(&report)

    #expect(throws: expected) {
        try report.validate()
    }
}

private func atemReadOnlyPassCandidateReport() -> AtemReadOnlyControlReport {
    var report = AtemReadOnlyControlProbe.makeUnavailableReport(
        host: "192.0.2.10",
        capturedAt: "2026-05-02T00:00:00Z"
    )
    report.health = .connected
    report.verdict = .pass
    report.model = "ATEM Mini Pro"
    report.firmware = "9.6"
    report.programSource = "Camera 1"
    report.previewSource = "Camera 2"
    report.tally = "program=1 preview=2"
    report.audioMixerState = "follow-video"
    report.controlPort = 9_910
    report.protocolName = "tcp-reachability"
    report.networkInterface = "en5"
    report.connectionAttemptMilliseconds = 50
    return report
}

private func loadOscCueFixture(named name: String) throws -> OscCueReport {
    let url = try oscCueFixtureURL(named: name)
    return try OscCueReport.decode(from: Data(contentsOf: url))
}

private func oscCueFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "OscCueReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "OscCueReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}
