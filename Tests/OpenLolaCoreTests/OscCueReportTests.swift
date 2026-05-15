import Foundation
import Testing

@testable import OpenLolaCore

@Test
func oscCueReportFixtureDecodesAndValidates() throws {
    let report = try loadOscCueFixture(named: "osc-cue-partial")

    try report.validate()

    #expect(report.peer.kind == .localLoopback)
    #expect(report.message.address == "/open-lola/cue")
    #expect(report.jitter.p99Microseconds == 1_200)
    #expect(report.verdict == .partial)
}

@Test
func oscCueMessageRoundTripsThroughOscPacket() throws {
    let message = OscCueMessage(
        cueId: "cue-000",
        senderTimestampNanoseconds: 123_456_789
    )

    let packet = try message.packetData()
    let decoded = try OscCueMessage.decodePacket(packet)

    #expect(decoded == message)
    #expect(packet.prefix(16) == Data([47, 111, 112, 101, 110, 45, 108, 111, 108, 97, 47, 99, 117, 101, 0, 0]))
}

@Test
func oscCueMessageDecodeRejectsMissingFinalPadding() throws {
    let message = OscCueMessage(
        cueId: "cue-000",
        senderTimestampNanoseconds: 123_456_789
    )
    var packet = try message.packetData()
    packet.removeLast()

    #expect(throws: OscCuePacketError.missingNullTerminator) {
        _ = try OscCueMessage.decodePacket(packet)
    }
}

@Test
func oscCueMessageDecodeRejectsInvalidTimestampString() throws {
    var packet = Data()
    packet.append(oscString(OscCueMessage.address))
    packet.append(oscString(OscCueMessage.typeTags))
    packet.append(oscString("cue-000"))
    packet.append(oscString("not-a-number"))

    #expect(throws: OscCuePacketError.invalidTimestamp("not-a-number")) {
        _ = try OscCueMessage.decodePacket(packet)
    }
}

@Test
func oscCueFdSetDescriptorGuardRejectsOutOfRangeDescriptors() {
    #expect(oscCueSocketDescriptorFitsFDSet(0))
    #expect(oscCueSocketDescriptorFitsFDSet(Int32(FD_SETSIZE - 1)))
    #expect(!oscCueSocketDescriptorFitsFDSet(-1))
    #expect(!oscCueSocketDescriptorFitsFDSet(Int32(FD_SETSIZE)))
}

@Test
func oscCueStringReaderDocumentsAbsoluteCursorAlignment() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Control/OscCueHelpers.swift")

    #expect(source.contains("/// cursor must be absolute offset from byte 0 of the OSC message"))
    #expect(source.contains("precondition(cursor >= 0)"))
}

@Test
func oscCueLoopbackSyntheticProbeRecordsDeterministicJitter() throws {
    let report = OscCueSyntheticLoopback.run()

    try report.validate()

    #expect(report.cues.map(\.cueId) == ["cue-000", "cue-001", "cue-002"])
    #expect(report.jitter.p50Microseconds == 1_100)
    #expect(report.jitter.maxMicroseconds == 1_200)
}

@Test
func oscCueLiveUdpLoopbackRunnerEmitsPartialReport() throws {
    let report = try OscCueUdpLoopbackRunner.run(count: 3)

    try report.validate()

    #expect(report.peer.kind == .localLoopback)
    #expect(report.transport?.protocolName == "udp")
    #expect(report.transport?.liveUdpLoopback == true)
    #expect(report.transport?.sentPackets == 3)
    #expect(report.transport?.receivedPackets == 3)
    #expect(report.verdict == .partial)
}

@Test
func oscCueUdpLoopbackUsesActualReceiveTimestampWithoutJitterFloor() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Control/OscCueRunners.swift")

    #expect(source.contains("let receivedAt = DispatchTime.now().uptimeNanoseconds"))
    #expect(!source.contains("received.senderTimestampNanoseconds + 1_000"))
}

@Test
func oscCueUdpReceiveTimesOutBeforeBlockingRead() throws {
    let descriptor = try makeUdpSocket(receiveTimeoutSeconds: 10)
    defer { close(descriptor) }
    try bindLoopback(descriptor, port: 0)

    #expect(throws: OscCueError.receiveFailed(ETIMEDOUT)) {
        _ = try receiveUdpOscMessage(socket: descriptor, timeoutMilliseconds: 1)
    }
}

@Test
func oscCueUdpReceiveAcceptsDatagramLargerThanLegacyFourKilobyteBuffer() throws {
    let descriptor = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer { close(descriptor) }
    try bindLoopback(descriptor, port: 0)
    let port = try boundUdpPort(for: descriptor)
    let cueId = String(repeating: "a", count: 5_000)
    let message = OscCueMessage(cueId: cueId, senderTimestampNanoseconds: 123)

    try sendUdpPacket(try message.packetData(), socket: descriptor, port: port)
    let received = try receiveUdpOscMessage(socket: descriptor, timeoutMilliseconds: 1_000)

    #expect(received == message)
}

@Test
func oscCueExternalRunConfigurationParsesRequiredArguments() throws {
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
}

@Test
func oscCueExternalRunConfigurationRejectsLocalLoopbackAsExternalPeer() {
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
}

@Test
func oscCueExternalRunnerBuildsPartialReportWithAudioBaselineAndExternalPeer() throws {
    let configuration = OscCueExternalRunConfiguration(
        audioBaselineReportId: "m05-route-baseline-required",
        port: 0,
        count: 3,
        firstExternalPeerKind: .chataigne,
        externalHost: "192.0.2.20",
        externalPort: 8_000,
        externalAvailable: false,
        externalUnavailableReason: "Chataigne not running",
        outputPath: "reports/m11-osc-cue-external.json"
    )

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
func oscCueReportRejectsCueCountMismatch() throws {
    var report = try loadOscCueFixture(named: "osc-cue-partial")
    report.message.cueCount = 4

    #expect(throws: OscCueValidationError.cueCountMismatch(expected: 3, actual: 4)) {
        try report.validate()
    }
}

@Test
func oscCueReportAllowsTinyCueJitterRoundingDifference() throws {
    var report = try loadOscCueFixture(named: "osc-cue-partial")
    report.cues[0].jitterMicroseconds += 0.00005

    try report.validate()
    #expect(report.verdict == .partial)
}

@Test
func oscCueReportRejectsPassWithoutLiveUdpLoopbackEvidence() throws {
    var report = try passCandidateReport()
    report.transport = nil

    #expect(throws: OscCueValidationError.passWithoutLiveUdpLoopback) {
        try report.validate()
    }
}

@Test
func oscCueReportRejectsPassWithoutFirstExternalPeerEvidence() throws {
    var report = try passCandidateReport()
    report.firstExternalPeer = nil

    #expect(throws: OscCueValidationError.passWithoutFirstExternalPeer) {
        try report.validate()
    }
}

@Test
func oscCueReportRejectsPassWithUnavailableFirstExternalPeer() throws {
    var report = try passCandidateReport()
    report.firstExternalPeer?.available = false
    report.firstExternalPeer?.unavailableReason = "Chataigne not running"

    #expect(throws: OscCueValidationError.passWithoutFirstExternalPeer) {
        try report.validate()
    }
}

@Test
func oscCueReportRejectsPassWithAudioP99Increase() throws {
    var report = try passCandidateReport()
    report.audioImpact.cueLoopCallbackP99Microseconds = 81

    #expect(throws: OscCueValidationError.passIncreasesAudioP99(
        baseline: 80,
        cueLoop: 81
    )) {
        try report.validate()
    }
}

@Test
func oscCueReportRejectsPassWithPlayoutTargetChange() throws {
    var report = try passCandidateReport()
    report.audioImpact.cueLoopPlayoutTargetFrames = 48

    #expect(throws: OscCueValidationError.passChangesAudioPlayoutTarget(
        baseline: 32,
        cueLoop: 48
    )) {
        try report.validate()
    }
}

@Test
func oscCueReportRejectsPassWithUnavailablePeer() throws {
    var report = try passCandidateReport()
    report.peer.available = false
    report.peer.unavailableReason = "external peer missing"

    #expect(throws: OscCueValidationError.passWithoutAvailablePeer) {
        try report.validate()
    }
}

@Test
func oscCueReportRejectsPassWithSyntheticAudioImpact() throws {
    var report = try passCandidateReport()
    report.audioImpact.synthetic = true

    #expect(throws: OscCueValidationError.passWithSyntheticAudioImpact) {
        try report.validate()
    }
}

@Test
func oscCueReportRejectsPassWithNonLoopbackPeerKind() throws {
    var report = try passCandidateReport()
    report.peer.kind = .openStageControl

    #expect(throws: OscCueValidationError.passWithoutMeasuredLoopback) {
        try report.validate()
    }
}

@Test
func oscCueReportJSONRoundTripPreservesReport() throws {
    let report = try loadOscCueFixture(named: "osc-cue-partial")
    let jsonData = try report.prettyJSONData()
    let decoded = try OscCueReport.decode(from: jsonData)

    #expect(decoded == report)
}

@Test
func atemReadOnlyControlReportRoundTripsAndValidates() throws {
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
}

@Test
func atemReadOnlyControlReportRejectsArmedCommands() throws {
    var report = AtemReadOnlyControlProbe.makeUnavailableReport(
        host: "192.0.2.10",
        capturedAt: "2026-05-02T00:00:00Z"
    )
    report.armedCommandsAllowed = true

    #expect(throws: AtemReadOnlyControlValidationError.commandsArmed) {
        try report.validate()
    }
}

@Test
func atemReadOnlyControlProbeRecordsCommandsDisarmed() throws {
    let report = AtemReadOnlyControlProbe.makeUnavailableReport(
        host: "192.0.2.10",
        capturedAt: "2026-05-02T00:00:00Z"
    )

    try report.validate()

    #expect(report.ipAddress == "192.0.2.10")
    #expect(report.health == .unavailable)
    #expect(report.armedCommandsAllowed == false)
    #expect(report.verdict == .partial)
}

@Test
func atemReadOnlyProbeConfigurationParsesRequiredArguments() throws {
    let configuration = try AtemReadOnlyProbeConfiguration.parse([
        "--host", "192.0.2.10",
        "--port", "9910",
        "--timeout-milliseconds", "150",
        "--poll-interval-milliseconds", "500",
        "--network-interface", "en5",
        "--same-network-as-audio", "false",
        "--output", "reports/m11-atem-readonly.json",
    ])

    #expect(configuration.host == "192.0.2.10")
    #expect(configuration.port == 9_910)
    #expect(configuration.timeoutMilliseconds == 150)
    #expect(configuration.pollIntervalMilliseconds == 500)
    #expect(configuration.networkInterface == "en5")
    #expect(configuration.sameNetworkAsAudio == false)
    #expect(configuration.outputPath == "reports/m11-atem-readonly.json")
}

@Test
func atemReadOnlyProbeConfigurationRejectsExcessiveTimeoutMilliseconds() {
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
}

@Test
func atemReadOnlyProbeConfigurationRejectsInvalidPort() {
    #expect(throws: AtemReadOnlyProbeConfigurationError.invalidPort("70000")) {
        _ = try AtemReadOnlyProbeConfiguration.parse([
            "--host", "192.0.2.10",
            "--port", "70000",
            "--output", "reports/m11-atem-readonly.json",
        ])
    }
}

@Test
func atemReadOnlyProbeConfigurationRejectsNonIPv4Hostnames() {
    #expect(throws: AtemReadOnlyProbeConfigurationError.invalidIPv4Host("atem.local")) {
        _ = try AtemReadOnlyProbeConfiguration.parse([
            "--host", "atem.local",
            "--output", "reports/m11-atem-readonly.json",
        ])
    }
}

@Test
func atemDarwinSocketHelpersStayPrivateAndDocumented() throws {
    let source = try readRepositoryText("Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift")

    #expect(source.contains("private func sockaddrIn(host: String, port: UInt16) -> sockaddr_in?"))
    #expect(source.contains("private func atemSocketDescriptorFitsFDSet(_ descriptor: Int32) -> Bool"))
    #expect(source.contains("Darwin-only because they depend on Darwin socket layout and fd_set storage"))
}

@Test
func atemReadOnlyControlProbeBuildsPartialNetworkReport() throws {
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

    let report = AtemReadOnlyControlProbe.makeReport(
        configuration: configuration,
        observation: observation,
        capturedAt: "2026-05-02T00:00:00Z"
    )

    try report.validate()

    #expect(report.ipAddress == "192.0.2.10")
    #expect(report.controlPort == 9_910)
    #expect(report.protocolName == "tcp-reachability")
    #expect(report.networkInterface == "en5")
    #expect(report.sameNetworkAsAudio == false)
    #expect(report.readOnlyPollIntervalMilliseconds == 500)
    #expect(report.connectionAttemptMilliseconds == 150)
    #expect(report.errorMessage == "connect timed out")
    #expect(report.armedCommandsAllowed == false)
    #expect(report.verdict == .partial)
}

@Test
func atemConnectedHealthNotesTCPHandshakeOnly() throws {
    let configuration = AtemReadOnlyProbeConfiguration(
        host: "192.0.2.10",
        outputPath: "reports/m11-atem-readonly.json"
    )
    let report = AtemReadOnlyControlProbe.makeReport(
        configuration: configuration,
        observation: AtemReadOnlyNetworkObservation(
            health: .connected,
            durationMilliseconds: 5,
            errorMessage: nil
        ),
        capturedAt: "2026-05-02T00:00:00Z"
    )

    try report.validate()

    #expect(report.notes.contains("TCP handshake completed, not ATEM protocol verified"))
}

@Test
func atemReadOnlyControlReportRejectsPassWithPlaceholderEvidence() throws {
    var report = AtemReadOnlyControlProbe.makeUnavailableReport(
        host: "192.0.2.10",
        capturedAt: "2026-05-02T00:00:00Z"
    )
    report.health = .connected
    report.verdict = .pass
    report.controlPort = 9_910
    report.protocolName = "tcp-reachability"
    report.networkInterface = "en5"
    report.connectionAttemptMilliseconds = 50

    #expect(throws: AtemReadOnlyControlValidationError.passWithPlaceholderField("model")) {
        try report.validate()
    }
}

@Test
func atemReadOnlyControlReportRejectsPassWithoutProtocolNameEvidence() throws {
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
    report.protocolName = nil
    report.connectionAttemptMilliseconds = 50

    #expect(throws: AtemReadOnlyControlValidationError.passWithoutNetworkEvidence) {
        try report.validate()
    }
}

@Test
func atemReadOnlyControlReportRejectsPassWithoutNetworkInterfaceEvidence() throws {
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
    report.networkInterface = nil
    report.connectionAttemptMilliseconds = 50

    #expect(throws: AtemReadOnlyControlValidationError.passWithoutNetworkEvidence) {
        try report.validate()
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

private func readRepositoryText(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
