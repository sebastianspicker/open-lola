import Foundation
import Darwin
import Dispatch
import Testing

@testable import OpenLolaCore

@Test
func madiFullDuplexSyntheticSmokeStartsTxAndRx() throws {
    let report = try MadiFullDuplexSyntheticSmoke.run(
        packetCount: 4,
        channelCount: 8
    )

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.runMode == .sourceLevel)
    #expect(report.metrics.transmittedBlocks == 4)
    #expect(report.metrics.completedReceiveBlocks == 4)
    #expect(report.metrics.renderedReceiveBlocks == 4)
    #expect(report.metrics.transmittedFragments > 0)
    #expect(report.metrics.receivedFragments == report.metrics.transmittedFragments)
    #expect(report.metrics.txSenderFrameEnd == 128)
    #expect(report.metrics.videoStreamsEnabled == 0)
    #expect(!report.metrics.hiddenPlayoutGrowthDetected)
    #expect(report.receiverMix?.configured == false)
    #expect(report.receiverMix?.policy == "identity-default")
    #expect(report.receiverMix?.renderedBlocks == 4)
}

@Test
func madiFullDuplexSocketRunnerExchangesUdpV2PacketsBetweenTwoPeers() throws {
    let (portA, portB) = try freeLoopbackPortPair()
    let configurationA = try MadiFullDuplexSessionConfiguration.sourceLevel(
        sessionID: "m05-network-runtime-test",
        localPeerID: "mac-a",
        remotePeerID: "mac-b",
        localEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: portA),
        remoteEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: portB),
        inputDeviceUID: "test-rme-a-input",
        outputDeviceUID: "test-rme-a-output",
        packetCount: 4,
        channelCount: 2,
        sampleRateHertz: 320,
        localStreamID: 1,
        remoteStreamID: 2
    )
    let configurationB = try MadiFullDuplexSessionConfiguration.sourceLevel(
        sessionID: "m05-network-runtime-test",
        localPeerID: "mac-b",
        remotePeerID: "mac-a",
        localEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: portB),
        remoteEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: portA),
        inputDeviceUID: "test-rme-b-input",
        outputDeviceUID: "test-rme-b-output",
        packetCount: 4,
        channelCount: 2,
        sampleRateHertz: 320,
        localStreamID: 2,
        remoteStreamID: 1
    )

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

    #expect(reportA.runMode == .networkRuntime)
    #expect(reportB.runMode == .networkRuntime)
    #expect(reportA.verdict == .partial)
    #expect(reportB.verdict == .partial)
    #expect(reportA.metrics.transmittedBlocks == 4)
    #expect(reportB.metrics.transmittedBlocks == 4)
    #expect(reportA.metrics.completedReceiveBlocks == 4)
    #expect(reportB.metrics.completedReceiveBlocks == 4)
    #expect(reportA.metrics.renderedReceiveBlocks == 4)
    #expect(reportB.metrics.renderedReceiveBlocks == 4)
}

@Test
func madiFullDuplexSocketRunnerUsesConfigurablePeerBindWait() throws {
    let runtimeSource = try readMadiFullDuplexSource("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexRuntime.swift")
    let socketSource = try readMadiFullDuplexSource("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift")
    let configuration = try MadiFullDuplexSessionConfiguration.synthetic(packetCount: 1, channelCount: 2)

    try configuration.validate()
    #expect(configuration.peerBindTimeoutSeconds == 1)
    #expect(runtimeSource.contains("peerBindTimeoutSeconds: Double = 1"))
    #expect(socketSource.contains("waitForPeerBindWindow(timeoutSeconds: configuration.peerBindTimeoutSeconds)"))
    #expect(socketSource.contains("drainPollIntervalNanoseconds"))
    #expect(!socketSource.contains("usleep(1_000_000)"))
}

@Test
func madiFullDuplexSocketRunnerReportsConfiguredReceiverMix() throws {
    let (portA, portB) = try freeLoopbackPortPair()
    let configurationA = try MadiFullDuplexSessionConfiguration.sourceLevel(
        sessionID: "m05-network-runtime-mix-test",
        localPeerID: "mac-a",
        remotePeerID: "mac-b",
        localEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: portA),
        remoteEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: portB),
        inputDeviceUID: "test-rme-a-input",
        outputDeviceUID: "test-rme-a-output",
        packetCount: 4,
        channelCount: 2,
        sampleRateHertz: 320,
        localStreamID: 1,
        remoteStreamID: 2,
        receiverMix: m05SwapStereoReceiverMix(channelCount: 2),
        receiverMixPolicy: "swap-stereo"
    )
    let configurationB = try MadiFullDuplexSessionConfiguration.sourceLevel(
        sessionID: "m05-network-runtime-mix-test",
        localPeerID: "mac-b",
        remotePeerID: "mac-a",
        localEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: portB),
        remoteEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: portA),
        inputDeviceUID: "test-rme-b-input",
        outputDeviceUID: "test-rme-b-output",
        packetCount: 4,
        channelCount: 2,
        sampleRateHertz: 320,
        localStreamID: 2,
        remoteStreamID: 1
    )

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

    let mixA = try #require(reportA.receiverMix)
    #expect(mixA.configured)
    #expect(mixA.policy == "swap-stereo")
    #expect(mixA.routeCount == 2)
    #expect(mixA.outputChannelCount == 2)
    #expect(mixA.lastAppliedRevision == 1)
    #expect(mixA.renderedBlocks == 4)
    #expect(!mixA.requiresDestructiveDownmix)
    #expect(mixA.appliedOutsideAudioCallback)
    #expect(reportB.receiverMix?.configured == false)
    #expect(reportB.receiverMix?.renderedBlocks == 4)
}

@Test
func madiFullDuplexAudioPairRequiresSymmetricChannelsUnlessExplicit() throws {
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
}

@Test
func madiFullDuplexAudioPairRejectsSampleRateMismatch() throws {
    let local = m05AudioStream(sampleRateHertz: 48_000)
    let remote = m05AudioStream(id: 2, sampleRateHertz: 96_000)

    #expect(throws: MadiFullDuplexError.sampleRateMismatch(local: 48_000, remote: 96_000)) {
        _ = try MadiFullDuplexAudioPair(localToRemote: local, remoteToLocal: remote)
    }
}

@Test
func madiFullDuplexSessionConfigurationRejectsEnabledVideo() throws {
    let session = SessionConfiguration(
        sessionID: "m05-video-reject",
        peers: [m05Peer("local"), m05Peer("remote")],
        latencyProfile: .balancedAV,
        rxBufferProfile: .small,
        audioStreams: [m05AudioStream()],
        videoStreams: [m05VideoStream(enabled: true)],
        controlEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_000),
        audioEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_001),
        videoEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_002),
        metricsEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_003),
        mtuBytes: 1_200,
        metricIntervalMilliseconds: 1_000,
        reconnectDeadlineMilliseconds: 2_000
    )

    #expect(throws: MadiFullDuplexError.enabledVideoNotAllowed) {
        _ = try MadiFullDuplexSessionConfiguration.fromSessionConfiguration(
            session,
            localPeerID: "local",
            remotePeerID: "remote",
            inputDeviceUID: "rme-madi-uid",
            outputDeviceUID: "rme-madi-uid"
        )
    }
}

@Test
func madiFullDuplexSessionConfigurationCarriesRxBufferProfile() throws {
    let configuration = try MadiFullDuplexSessionConfiguration.sourceLevel(
        sessionID: "m05-rx-buffer-profile",
        localPeerID: "local",
        remotePeerID: "remote",
        localEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 41_001),
        remoteEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 41_101),
        inputDeviceUID: "rme-madi-input",
        outputDeviceUID: "rme-madi-output",
        packetCount: 1,
        channelCount: 2,
        rxBufferProfile: .stableWan
    )
    let remoteMode = try configuration.audioPair.remoteReceiveMode(
        maxTransmissionUnitBytes: configuration.maxTransmissionUnitBytes,
        maxFragmentsPerDeadline: configuration.maxFragmentsPerDeadline,
        metadataRevision: configuration.metadataRevision,
        rxBufferProfile: configuration.rxBufferProfile
    )
    let session = try MadiFullDuplexSession(configuration: configuration)

    #expect(configuration.rxBufferProfile == .stableWan)
    #expect(remoteMode.rxBufferProfile == .stableWan)
    #expect(session.metrics.rxBuffer.policy.profile == .stableWan)
}

@Test
func madiFullDuplexSessionConfigurationCopiesSessionRxBufferProfile() throws {
    let session = SessionConfiguration(
        sessionID: "m05-rx-buffer-from-session",
        peers: [m05Peer("local"), m05Peer("remote")],
        latencyProfile: .balancedAV,
        rxBufferProfile: .adaptive,
        audioStreams: [m05AudioStream()],
        videoStreams: [],
        controlEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_000),
        audioEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_001),
        videoEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_002),
        metricsEndpoint: SessionNetworkEndpoint(host: "192.0.2.10", port: 41_003),
        mtuBytes: 1_200,
        metricIntervalMilliseconds: 1_000,
        reconnectDeadlineMilliseconds: 2_000
    )

    let configuration = try MadiFullDuplexSessionConfiguration.fromSessionConfiguration(
        session,
        localPeerID: "local",
        remotePeerID: "remote",
        inputDeviceUID: "rme-madi-uid",
        outputDeviceUID: "rme-madi-uid"
    )

    #expect(configuration.rxBufferProfile == .adaptive)
}

@Test
func madiFullDuplexRenderSuppressesWarmupUnderrunWithoutNetworkWait() throws {
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
func madiFullDuplexRenderBeforeStartThrowsNotStarted() throws {
    var session = try MadiFullDuplexSession(
        configuration: .synthetic(
            packetCount: 1,
            channelCount: 2
        )
    )

    #expect(throws: MadiFullDuplexError.notStarted) {
        _ = try session.renderRemoteAudioCallback()
    }
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

@Test
func madiFullDuplexDriftSimulationRecordsBoundedCorrectionOutsideCallback() throws {
    let policy = MadiFullDuplexCorrectionPolicy(
        driftThresholdPartsPerMillion: 100,
        maxCorrectionFramesPerEvent: 1,
        maxEventsPerMinute: 60
    )
    let simulation = try MadiFullDuplexClockDriftSimulator.run(
        sampleCount: 4,
        senderFrameStep: 32,
        receiverFrameStep: 33,
        correctionPolicy: policy
    )

    try simulation.validate()

    #expect(simulation.estimate.sampleCount == 4)
    #expect(simulation.estimate.driftSlopePartsPerMillion > 31_000)
    #expect(simulation.estimate.driftSlopePartsPerMillion < 31_300)
    let event = try #require(simulation.correctionEvents.first)
    #expect(event.action == .insertFrame)
    #expect(event.correctionFrames == 1)
    #expect(!event.changedInsideAudioCallback)
}

@Test
func madiFullDuplexDriftEstimateRejectsNonMonotonicFrameSamples() {
    let samples = [
        MadiFullDuplexClockSample(
            senderFrameIndex: 32,
            receiverPlayoutFrameIndex: 64,
            localHostTimeNanoseconds: 1
        ),
        MadiFullDuplexClockSample(
            senderFrameIndex: 96,
            receiverPlayoutFrameIndex: 32,
            localHostTimeNanoseconds: 2
        ),
    ]

    #expect(throws: MadiFullDuplexError.negativeField("receiverFrameDelta")) {
        _ = try MadiFullDuplexClockDriftSimulator.estimate(from: samples)
    }
}

@Test
func madiFullDuplexSourceUsesUInt64BeforeSenderFrameMultiplication() throws {
    let source = try readMadiFullDuplexSource("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexRuntime.swift")

    #expect(source.contains("UInt64(metrics.transmittedBlocks)"))
    #expect(source.contains("UInt64(localSendMode.framesPerPacket)"))
    #expect(!source.contains("UInt64(metrics.transmittedBlocks * localSendMode.framesPerPacket)"))
}

@Test
func madiFullDuplexSocketRunnerPollsBelowThirtyTwoFramePacketPeriod() throws {
    let source = try readMadiFullDuplexSource("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift")

    #expect(source.contains("private static let drainPollIntervalNanoseconds: UInt64 = 100_000"))
    #expect(source.contains("poll(&descriptor, 1, timeoutMilliseconds)"))
    #expect(source.contains("receiveDatagramIfAvailable(\n                socket: socket,\n                byteCount: byteCount,\n                buffer: &receiveBuffer"))
    #expect(!source.contains("usleep(1_000)"))
    #expect(!source.contains("usleep(Self.drainPollIntervalMicroseconds)"))
}

@Test
func madiFullDuplexCommandRequiredFieldsCarryConstructionContext() throws {
    let source = try readMadiFullDuplexSource("Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift")

    #expect(source.contains(#"fdRequired("--local-peer", values, label: "localPeerID")"#))
    #expect(source.contains(#"fdRequired("--remote-peer", values, label: "remotePeerID")"#))
    #expect(source.contains(#"fdRequired("--local-host", values, label: "localEndpoint.host")"#))
    #expect(source.contains(#"fdRequired("--remote-host", values, label: "remoteEndpoint.host")"#))
    #expect(source.contains(#"fdRequired("--output", values, label: "outputPath")"#))
    #expect(source.contains(#"let field = label.map { "\($0) (\(key))" } ?? key"#))
}

private func m05AudioStream(
    id: Int = 1,
    sampleRateHertz: Int = 48_000,
    sampleFormat: UdpPcmSampleFormat = .float32LittleEndian,
    channelCount: Int = 64,
    framesPerPacket: Int = 32
) -> AudioStreamDescription {
    AudioStreamDescription(
        id: id,
        direction: .bidirectional,
        sampleRateHertz: sampleRateHertz,
        sampleFormat: sampleFormat,
        channelCount: channelCount,
        channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
        clockDomain: "core-audio-device:rme-madi",
        framesPerPacket: framesPerPacket,
        payloadType: .audioPcmV2
    )
}

private func readMadiFullDuplexSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

private func m05Peer(_ id: String) -> PeerIdentity {
    PeerIdentity(
        peerID: id,
        displayName: "M05 \(id)",
        implementationName: "open-lola",
        implementationVersion: "0.0.0-m05"
    )
}

private func m05VideoStream(enabled: Bool) -> VideoStreamDescription {
    VideoStreamDescription(
        id: 100,
        direction: enabled ? .send : .disabled,
        role: enabled ? .blackmagicInput : .disabled,
        resolution: VideoResolution(width: 1_920, height: 1_080),
        frameRate: VideoFrameRate(numerator: 60, denominator: 1),
        pixelFormat: enabled ? .bgra8 : .disabled,
        transportFormat: enabled ? .rawFrameFragment : .disabled,
        sourceLabel: enabled ? "Blackmagic input" : "video-disabled",
        payloadType: enabled ? .videoRawFrameFragment : .videoRawFrameFragment
    )
}

private func m05Mode(channelCount: Int) throws -> AudioTransportMode {
    let fragments = try UdpPcmV2FragmentPlanner.plan(
        UdpPcmV2FragmentPlanRequest(
            streamID: 1,
            totalChannelCount: channelCount,
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            sampleFormat: .float32LittleEndian,
            maxTransmissionUnitBytes: 1_200,
            maxFragmentsPerDeadline: 16,
            metadataRevision: 5,
            packingMode: .interleavedChannelRange
        )
    )
    return AudioTransportMode(
        protocolVersion: .udpPcmV2,
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: channelCount,
        sampleFormat: .float32LittleEndian,
        latencyProfile: .safeLowLatency,
        rxBufferProfile: .direct,
        maxTransmissionUnitBytes: 1_200,
        channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex,
        fragments: fragments
    )
}

private func m05Packets(
    mode: AudioTransportMode,
    sequenceNumber: UInt64,
    senderFrameIndex: UInt64
) throws -> [UdpPcmV2Packet] {
    try UdpPcmV2Packetizer.packetize(
        Data(repeating: UInt8(sequenceNumber), count: mode.framesPerPacket * mode.channelCount * mode.sampleFormat.bytesPerSample),
        sequenceNumber: sequenceNumber,
        senderFrameIndex: senderFrameIndex,
        senderHostTimeNanoseconds: sequenceNumber + 1,
        mode: mode
    )
}

private func m05SwapStereoReceiverMix(channelCount: Int) -> ReceiverMixSnapshot {
    let swapped = [
        ReceiverMixRoute(
            sourceChannelIndex: 0,
            destinationChannelIndex: 1,
            gainDb: 0,
            muted: false,
            pan: 0
        ),
        ReceiverMixRoute(
            sourceChannelIndex: 1,
            destinationChannelIndex: 0,
            gainDb: 0,
            muted: false,
            pan: 0
        ),
    ]
    let remaining = (2..<channelCount).map { index in
        ReceiverMixRoute(
            sourceChannelIndex: index,
            destinationChannelIndex: index,
            gainDb: 0,
            muted: false,
            pan: 0
        )
    }
    return ReceiverMixSnapshot(
        routes: swapped + remaining,
        requiresDestructiveDownmix: false
    )
}

private final class MadiFullDuplexReportResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedResult: Result<MadiFullDuplexReport, Error>?

    func store(_ result: Result<MadiFullDuplexReport, Error>) {
        lock.lock()
        storedResult = result
        lock.unlock()
    }

    func result() throws -> Result<MadiFullDuplexReport, Error> {
        lock.lock()
        defer { lock.unlock() }
        guard let storedResult else {
            throw UdpPcmRouteProbeError.receiveFailed(ETIMEDOUT)
        }
        return storedResult
    }
}

private func freeLoopbackPortPair() throws -> (UInt16, UInt16) {
    let first = try makeUdpSocket(receiveTimeoutSeconds: 1)
    let second = try makeUdpSocket(receiveTimeoutSeconds: 1)
    defer {
        close(first)
        close(second)
    }
    try bindLoopback(first, port: 0)
    try bindLoopback(second, port: 0)
    let firstPort = UInt16(bigEndian: try boundPort(first))
    let secondPort = UInt16(bigEndian: try boundPort(second))
    if firstPort == secondPort {
        throw UdpPcmRouteProbeError.bindFailed(EADDRINUSE)
    }
    return (firstPort, secondPort)
}
