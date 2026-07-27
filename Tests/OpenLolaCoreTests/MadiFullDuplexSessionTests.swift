// Verifies that MADI real-time schedule drops expired slots without bursting or stretching the horizon.
import Foundation
import Darwin
import Dispatch
import Testing

@testable import OpenLolaCore

@Test
func madiRealtimeScheduleDropsExpiredSlotsWithoutBurstingOrStretchingHorizon() {
    let expired = madiRealtimeSlotTiming(
        nowNanoseconds: 4_500,
        scheduledStartNanoseconds: 1_000,
        intervalNanoseconds: 1_000
    )
    #expect(!expired.shouldTransmit)
    #expect(expired.sendNotBeforeNanoseconds == 4_500)
    #expect(expired.nextSlotStartNanoseconds == 2_000)

    let stillExpired = madiRealtimeSlotTiming(
        nowNanoseconds: 4_500,
        scheduledStartNanoseconds: expired.nextSlotStartNanoseconds,
        intervalNanoseconds: 1_000
    )
    #expect(!stillExpired.shouldTransmit)
    #expect(stillExpired.nextSlotStartNanoseconds == 3_000)

    let current = madiRealtimeSlotTiming(
        nowNanoseconds: 4_500,
        scheduledStartNanoseconds: 4_000,
        intervalNanoseconds: 1_000
    )
    #expect(current.shouldTransmit)
    #expect(current.sendNotBeforeNanoseconds == 4_000)
    #expect(current.nextSlotStartNanoseconds == 5_000)
}

@Test
func madiFullDuplexTransportSelectsTheLowestLatencyProfileForEightFramePackets() throws {
    let configuration = try MadiFullDuplexSessionConfiguration.sourceLevel(
        madiEightFrameSourceLevelRequest()
    )

    let mode = try configuration.audioPair.localSendMode(
        maxTransmissionUnitBytes: configuration.maxTransmissionUnitBytes,
        maxFragmentsPerDeadline: configuration.maxFragmentsPerDeadline,
        metadataRevision: configuration.metadataRevision
    )

    #expect(mode.framesPerPacket == 8)
    #expect(mode.latencyProfile == .extremeLowLatency8)
}

private func madiEightFrameSourceLevelRequest() -> MadiFullDuplexSourceLevelRequest {
    let session = MadiFullDuplexSourceLevelRequest.Session(
        sessionID: "madi-eight-frame-profile",
        localPeerID: "local",
        remotePeerID: "remote",
        localEndpoint: .init(host: "127.0.0.1", port: 41_001),
        remoteEndpoint: .init(host: "127.0.0.1", port: 41_101)
    )
    return .init(
        session: session,
        devices: .init(inputUID: "rme-madi-input", outputUID: "rme-madi-output"),
        audio: .init(packetCount: 1, channelCount: 64, framesPerPacket: 8)
    )
}

@Test
func madiSocketBackpressureDropsTheRemainderOfOneAudioDeadline() throws {
    let packets = try m05Packets(
        mode: m05Mode(channelCount: 64),
        sequenceNumber: 1,
        senderFrameIndex: 0
    )
    #expect(packets.count > 2)
    var attempts = 0
    let result = try sendMadiAudioBlock(packets) { _ in
        attempts += 1
        return attempts == 2 ? .wouldBlock : .sent
    }

    #expect(attempts == 2)
    #expect(result.sentFragments == 1)
    #expect(result.droppedForBackpressure)
}

@Test
func madiFullDuplexSocketRunnerExchangesUdpV2PacketsBetweenTwoPeers() throws {
    let (configurationA, configurationB) = try makeMadiFullDuplexUdpV2PeerConfigurations()
    let (reportA, reportB) = try runMadiFullDuplexSocketRunners(
        configurationA: configurationA,
        configurationB: configurationB
    )

    assertMadiFullDuplexUdpV2ExchangeReports(reportA, reportB)
}

private func makeMadiFullDuplexUdpV2PeerConfigurations() throws -> (
    MadiFullDuplexSessionConfiguration,
    MadiFullDuplexSessionConfiguration
) {
    let (portA, portB) = try freeLoopbackPortPair()
    let configurationA = try madiFullDuplexPeerConfiguration(.init(
        localPeerID: "mac-a", remotePeerID: "mac-b", localPort: portA, remotePort: portB,
        inputUID: "test-rme-a-input", outputUID: "test-rme-a-output"
    ))
    let configurationB = try madiFullDuplexPeerConfiguration(.init(
        localPeerID: "mac-b", remotePeerID: "mac-a", localPort: portB, remotePort: portA,
        inputUID: "test-rme-b-input", outputUID: "test-rme-b-output", streams: .init(localID: 2, remoteID: 1)
    ))

    return (configurationA, configurationB)
}

private struct MadiFullDuplexPeerFixture {
    let localPeerID: String
    let remotePeerID: String
    let localPort: UInt16
    let remotePort: UInt16
    let inputUID: String
    let outputUID: String
    var streams: MadiFullDuplexSourceLevelRequest.Streams? = nil
}

private func madiFullDuplexPeerConfiguration(
    _ fixture: MadiFullDuplexPeerFixture
) throws -> MadiFullDuplexSessionConfiguration {
    try MadiFullDuplexSessionConfiguration.sourceLevel(MadiFullDuplexSourceLevelRequest(
        session: .init(sessionID: "m05-network-runtime-test", localPeerID: fixture.localPeerID, remotePeerID: fixture.remotePeerID, localEndpoint: .init(host: "127.0.0.1", port: fixture.localPort), remoteEndpoint: .init(host: "127.0.0.1", port: fixture.remotePort)),
        devices: .init(inputUID: fixture.inputUID, outputUID: fixture.outputUID),
        audio: .init(packetCount: 4, channelCount: 2, sampleRateHertz: 320),
        streams: fixture.streams ?? .init()
    ))
}

private func runMadiFullDuplexSocketRunners(
    configurationA: MadiFullDuplexSessionConfiguration,
    configurationB: MadiFullDuplexSessionConfiguration
) throws -> (MadiFullDuplexReport, MadiFullDuplexReport) {
    let resultA = MadiFullDuplexReportResultBox()
    let resultB = MadiFullDuplexReportResultBox()
    let done = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .userInitiated).async {
        resultA.store(Result {
            try MadiFullDuplexSocketRunner.run(configuration: configurationA)
        })
        done.signal()
    }
    DispatchQueue.global(qos: .userInitiated).async {
        resultB.store(Result {
            try MadiFullDuplexSocketRunner.run(configuration: configurationB)
        })
        done.signal()
    }

    #expect(done.wait(timeout: .now() + 3) == .success)
    #expect(done.wait(timeout: .now() + 3) == .success)
    let reportA = try resultA.result().get()
    let reportB = try resultB.result().get()

    return (reportA, reportB)
}

private func assertMadiFullDuplexUdpV2ExchangeReports(
    _ reportA: MadiFullDuplexReport,
    _ reportB: MadiFullDuplexReport
) {
    #expect(reportA.runMode == .networkRuntime)
    #expect(reportB.runMode == .networkRuntime)
    #expect(reportA.verdict == .partial)
    #expect(reportB.verdict == .partial)
    #expect(reportA.metrics.transmittedBlocks == 4)
    #expect(reportB.metrics.transmittedBlocks == 4)
    #expect(reportA.metrics.socketTransmittedFragments == reportA.metrics.transmittedFragments)
    #expect(reportB.metrics.socketTransmittedFragments == reportB.metrics.transmittedFragments)
    #expect(reportA.metrics.socketBackpressureDroppedBlocks == 0)
    #expect(reportB.metrics.socketBackpressureDroppedBlocks == 0)
    #expect(reportA.metrics.completedReceiveBlocks == 4)
    #expect(reportB.metrics.completedReceiveBlocks == 4)
    #expect(reportA.metrics.renderedReceiveBlocks == 4)
    #expect(reportB.metrics.renderedReceiveBlocks == 4)
}

@Test
func madiFullDuplexSocketRunnerRequiresPeerReadinessBeforeStreaming() throws {
    let (portA, portB) = try freeLoopbackPortPair()
    var configuration = try MadiFullDuplexSessionConfiguration.sourceLevel(MadiFullDuplexSourceLevelRequest(
        session: .init(sessionID: "m05-readiness-timeout-test", localPeerID: "mac-a", remotePeerID: "mac-b", localEndpoint: .init(host: "127.0.0.1", port: portA), remoteEndpoint: .init(host: "127.0.0.1", port: portB)),
        devices: .init(inputUID: "test-rme-a-input", outputUID: "test-rme-a-output"),
        audio: .init(packetCount: 1, channelCount: 2, sampleRateHertz: 320)
    ))
    configuration.peerBindTimeoutSeconds = 0.02

    #expect(throws: MadiFullDuplexError.peerReadinessTimeout(
        peerID: "mac-b",
        timeoutSeconds: configuration.peerBindTimeoutSeconds
    )) {
        try MadiFullDuplexSocketRunner.run(configuration: configuration)
    }
}

@Test
// swiftlint:disable:next function_body_length
func madiFullDuplexConfigurationRejectsInvalidShapesAndCarriesRxBufferProfile() throws {
    let local = m05AudioStream(channelCount: 64)
    let remote = m05AudioStream(id: 2, channelCount: 32)

    #expect(throws: MadiFullDuplexError.asymmetricChannelCount(local: 64, remote: 32)) {
        _ = try MadiFullDuplexAudioPair(localToRemote: local, remoteToLocal: remote)
    }

    let explicit = try MadiFullDuplexAudioPair(
        localToRemote: local,
        remoteToLocal: remote,
        allowsAsymmetricChannelCounts: true
    )

    #expect(explicit.localToRemote.channelCount == 64)
    #expect(explicit.remoteToLocal.channelCount == 32)
    #expect(explicit.allowsAsymmetricChannelCounts)

    let rateLocal = m05AudioStream(sampleRateHertz: 48_000)
    let rateRemote = m05AudioStream(id: 2, sampleRateHertz: 96_000)

    #expect(throws: MadiFullDuplexError.sampleRateMismatch(local: 48_000, remote: 96_000)) {
        _ = try MadiFullDuplexAudioPair(localToRemote: rateLocal, remoteToLocal: rateRemote)
    }

    let videoRejectSession = madiSessionConfiguration(videoEnabled: true, rxBufferProfile: .small)

    #expect(throws: MadiFullDuplexError.enabledVideoNotAllowed) {
        _ = try MadiFullDuplexSessionConfiguration.fromSessionConfiguration(
            videoRejectSession,
            localPeerID: "local",
            remotePeerID: "remote",
            inputDeviceUID: "rme-madi-uid",
            outputDeviceUID: "rme-madi-uid"
        )
    }

    let configuration = try MadiFullDuplexSessionConfiguration.sourceLevel(MadiFullDuplexSourceLevelRequest(
        session: .init(sessionID: "m05-rx-buffer-profile", localPeerID: "local", remotePeerID: "remote", localEndpoint: .init(host: "127.0.0.1", port: 41_001), remoteEndpoint: .init(host: "127.0.0.1", port: 41_101)),
        devices: .init(inputUID: "rme-madi-input", outputUID: "rme-madi-output"),
        audio: .init(packetCount: 1, channelCount: 2),
        receiverMix: .init(rxBufferProfile: .stableWan)
    ))
    let remoteMode = try configuration.audioPair.remoteReceiveMode(
        maxTransmissionUnitBytes: configuration.maxTransmissionUnitBytes,
        maxFragmentsPerDeadline: configuration.maxFragmentsPerDeadline,
        metadataRevision: configuration.metadataRevision,
        rxBufferProfile: configuration.rxBufferProfile
    )
    let runtimeSession = try MadiFullDuplexSession(configuration: configuration)

    #expect(configuration.rxBufferProfile == .stableWan)
    #expect(remoteMode.rxBufferProfile == .stableWan)
    #expect(runtimeSession.metrics.rxBuffer.policy.profile == .stableWan)

    let negotiatedSession = madiSessionConfiguration(videoEnabled: false, rxBufferProfile: .adaptive)

    let copiedConfiguration = try MadiFullDuplexSessionConfiguration.fromSessionConfiguration(
        negotiatedSession,
        localPeerID: "local",
        remotePeerID: "remote",
        inputDeviceUID: "rme-madi-uid",
        outputDeviceUID: "rme-madi-uid"
    )

    #expect(copiedConfiguration.rxBufferProfile == .adaptive)
}

private func madiSessionConfiguration(
    videoEnabled: Bool,
    rxBufferProfile: RxBufferProfile
) -> SessionConfiguration {
    let audioStreams = [m05AudioStream()]
    let videoStreams = videoEnabled ? [m05VideoStream(enabled: true)] : []
    return SessionConfiguration(
        identity: .init(sessionID: "m05-session-configuration", peers: [m05Peer("local"), m05Peer("remote")]),
        profile: .init(latencyProfile: .balancedAV, rxBufferProfile: rxBufferProfile),
        streams: .init(audioStreams: audioStreams, videoStreams: videoStreams),
        endpoints: .init(control: .init(host: "192.0.2.10", port: 41_000), audio: .init(host: "192.0.2.10", port: 41_001), video: .init(host: "192.0.2.10", port: 41_002), metrics: .init(host: "192.0.2.10", port: 41_003)),
        transport: .init(mtuBytes: 1_200, metricIntervalMilliseconds: 1_000, reconnectDeadlineMilliseconds: 2_000)
    )
}

@Test
func madiFullDuplexHandoffConfigurationPreservesSplitDeviceUIDs() throws {
    let mode = try m05Mode(channelCount: 2)
    let configuration = MadiFullDuplexSession.handoffConfiguration(
        mode: mode,
        inputDeviceUID: "rme-madi-input",
        outputDeviceUID: "rme-madi-output",
        preallocatedBlockCount: 8
    )

    #expect(configuration.inputDeviceUID == "rme-madi-input")
    #expect(configuration.outputDeviceUID == "rme-madi-output")
}

@Test
func madiFullDuplexRenderRejectsBeforeStartAndSuppressesWarmupUnderrun() throws {
    var notStarted = try MadiFullDuplexSession(
        configuration: .synthetic(
            packetCount: 1,
            channelCount: 2
        )
    )

    #expect(throws: MadiFullDuplexError.notStarted) {
        _ = try notStarted.renderRemoteAudioCallback()
    }

    var session = try MadiFullDuplexSession(
        configuration: .synthetic(
            packetCount: 1,
            channelCount: 2
        )
    )

    try session.start()
    let rendered = try session.renderRemoteAudioCallback()

    #expect(rendered == .silence(startFrame: 0, frameCount: 32))
    #expect(session.metrics.underruns == 0)
    #expect(session.metrics.renderedReceiveBlocks == 0)
}

@Test
func madiReceiveOverrunPolicyDropsNewestOrOldest() throws {
    let mode = try m05Mode(channelCount: 2)
    let first = try m05Packets(mode: mode, sequenceNumber: 0, senderFrameIndex: 0)
    let second = try m05Packets(mode: mode, sequenceNumber: 1, senderFrameIndex: 32)
    var newest = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(
            mode: mode,
            preallocatedBlockCount: 1,
            overrunPolicy: .dropNewest
        )
    )
    var oldest = try MadiReceiveEngine(
        configuration: MadiReceiveConfiguration(
            mode: mode,
            preallocatedBlockCount: 1,
            overrunPolicy: .dropOldest
        )
    )

    #expect(try newest.receive(first[0]) == .queued)
    #expect(try newest.receive(second[0]) == .droppedFull)
    #expect(newest.metrics.overruns == 1)
    #expect(newest.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    guard case .played(let newestBlock) = newest.renderCallback() else {
        Issue.record("expected newest policy to keep first block")
        return
    }
    #expect(newestBlock.sequenceNumber == 0)

    #expect(try oldest.receive(first[0]) == .queued)
    #expect(try oldest.receive(second[0]) == .queued)
    #expect(oldest.metrics.overruns == 1)
    #expect(oldest.renderCallback() == .silence(startFrame: 0, frameCount: 32))
    guard case .sameDeadlineRecovery(let recovery) = oldest.renderCallback() else {
        Issue.record("expected oldest policy to drop first block")
        return
    }
    #expect(recovery.sequenceNumber == 0)
    guard case .played(let oldestBlock) = oldest.renderCallback() else {
        Issue.record("expected oldest policy to keep second block")
        return
    }
    #expect(oldestBlock.sequenceNumber == 1)
}
