import Foundation

public enum UltraGridCompatibilityRunner {
    private typealias RuntimeMediaAnalysis = (
        lost: Int,
        duplicates: Int,
        outOfOrder: Int,
        ssrcChanges: Int,
        timestampRegressions: Int,
        jitterLikeArrivalDeltaChanges: Int,
        videoFrameReassemblyFailures: Int,
        videoFrameRecoveryFailed: Bool
    )

    private struct RuntimeMediaExchange {
        var expectedReceiveCount: Int
        var transmittedDatagramCount: Int
        var receivedDatagrams: [UltraGridCompatibilityDatagram]
        var reportDatagrams: [UltraGridCompatibilityDatagram]
    }

    private struct RuntimeMediaReportContext {
        var configuration: ExternalConnectorSessionConfiguration
        var datagrams: [UltraGridCompatibilityDatagram]
        var transmittedDatagramCount: Int
        var receivedDatagramCount: Int
        var analysis: RuntimeMediaAnalysis
        var topology: UltraGridTopologyReport
        var control: UltraGridControlReport
        var provider: ExternalConnectorMediaProviderReport
        var sink: ExternalConnectorMediaSinkReport
        var observedEvidenceClasses: [ExternalConnectorEvidenceClass]
        var missingEvidenceClassesForPass: [ExternalConnectorEvidenceClass]
        var runtimeError: String?
    }

    public static func run(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> UltraGridCompatibilityMediaReport {
        let transmitter: any UltraGridCompatibilityMediaTransmitting = configuration.dryRun
            ? UltraGridMemoryMediaTransmitter()
            : UltraGridSocketMediaTransmitter()
        let receiver: any UltraGridCompatibilityMediaReceiving = configuration.dryRun
            ? UltraGridMemoryMediaReceiver(datagrams: [])
            : UltraGridSocketMediaReceiver()
        let mediaProvider: any UltraGridMediaProviding = configuration.role.transmits
            ? try UltraGridSessionMediaProvider(configuration: configuration)
            : UltraGridSyntheticMediaProvider()
        return try run(
            configuration: configuration,
            transmitter: transmitter,
            receiver: receiver,
            mediaProvider: mediaProvider
        )
    }

    public static func run(
        configuration: ExternalConnectorSessionConfiguration,
        transmitter: any UltraGridCompatibilityMediaTransmitting,
        receiver: any UltraGridCompatibilityMediaReceiving
    ) throws -> UltraGridCompatibilityMediaReport {
        try run(
            configuration: configuration,
            transmitter: transmitter,
            receiver: receiver,
            mediaProvider: UltraGridSyntheticMediaProvider()
        )
    }

    public static func run(
        configuration: ExternalConnectorSessionConfiguration,
        transmitter: any UltraGridCompatibilityMediaTransmitting,
        receiver: any UltraGridCompatibilityMediaReceiving,
        mediaProvider: any UltraGridMediaProviding
    ) throws -> UltraGridCompatibilityMediaReport {
        let lifecycle = configuration.role.transmits
            ? mediaProvider as? any UltraGridMediaProviderLifecycle
            : nil
        let topology = try topologyReport(configuration)
        let control = try UltraGridControlReportBuilder.report(configuration)
        try lifecycle?.start()
        defer { lifecycle?.stop() }
        let payloadRegistry = try payloadRegistry(configuration)
        let exchange = try runMediaExchange(
            configuration: configuration,
            transmitter: transmitter,
            receiver: receiver,
            mediaProvider: mediaProvider,
            payloadRegistry: payloadRegistry
        )
        let analysis = analyze(exchange.reportDatagrams)
        let sink = try consumeReceivedMedia(
            configuration.role.receives ? exchange.receivedDatagrams : [],
            encryptionConfiguration: try encryptionConfiguration(configuration)
        )
        let runtimeError = runtimeError(
            configuration: configuration,
            expectedReceiveCount: exchange.expectedReceiveCount,
            receivedDatagramCount: exchange.receivedDatagrams.count,
            analysis: analysis,
            sink: sink
        )
        let observedEvidenceClasses = mediaProvider.providerReport.observedEvidenceClasses
        let missingEvidenceClassesForPass = ExternalConnectorEvidenceClass.missingRuntimePassEvidence(
            observed: observedEvidenceClasses
        )
        return mediaReport(RuntimeMediaReportContext(
            configuration: configuration,
            datagrams: exchange.reportDatagrams,
            transmittedDatagramCount: exchange.transmittedDatagramCount,
            receivedDatagramCount: exchange.receivedDatagrams.count,
            analysis: analysis,
            topology: topology,
            control: control,
            provider: mediaProvider.providerReport,
            sink: sink,
            observedEvidenceClasses: observedEvidenceClasses,
            missingEvidenceClassesForPass: missingEvidenceClassesForPass,
            runtimeError: runtimeError
        ))
    }

    private static func runMediaExchange(
        configuration: ExternalConnectorSessionConfiguration,
        transmitter: any UltraGridCompatibilityMediaTransmitting,
        receiver: any UltraGridCompatibilityMediaReceiving,
        mediaProvider: any UltraGridMediaProviding,
        payloadRegistry: UltraGridRTPPayloadRegistry
    ) throws -> RuntimeMediaExchange {
        let generated = try buildDatagrams(configuration: configuration, mediaProvider: mediaProvider)
        let expectedReceiveCount = configuration.role.receives ? generated.count : 0
        let transmitted = configuration.role.transmits
            ? try transmitter.transmit(generated, localHost: configuration.localHost, peer: configuration.peer)
            : 0
        let received = try receiveRuntimeDatagrams(
            configuration: configuration,
            receiver: receiver,
            expectedReceiveCount: expectedReceiveCount,
            payloadRegistry: payloadRegistry
        )
        return RuntimeMediaExchange(
            expectedReceiveCount: expectedReceiveCount,
            transmittedDatagramCount: transmitted,
            receivedDatagrams: received,
            reportDatagrams: configuration.role.receives ? received : generated
        )
    }

    private static func receiveRuntimeDatagrams(
        configuration: ExternalConnectorSessionConfiguration,
        receiver: any UltraGridCompatibilityMediaReceiving,
        expectedReceiveCount: Int,
        payloadRegistry: UltraGridRTPPayloadRegistry
    ) throws -> [UltraGridCompatibilityDatagram] {
        guard configuration.role.receives else {
            return []
        }
        return try receiver.receive(
            expectedDatagrams: expectedReceiveCount,
            localHost: configuration.localHost,
            peer: receivePeer(configuration),
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            payloadRegistry: payloadRegistry,
            encryptionConfiguration: try encryptionConfiguration(configuration),
            timeoutSeconds: configuration.durationSeconds
        )
    }

    private static func runtimeError(
        configuration: ExternalConnectorSessionConfiguration,
        expectedReceiveCount: Int,
        receivedDatagramCount: Int,
        analysis: RuntimeMediaAnalysis,
        sink: ExternalConnectorMediaSinkReport
    ) -> String? {
        let fecRecoveredVideo = configuration.ultraGridFECMode != .none
            && configuration.mediaMode == .video
            && sink.videoFrameCount > 0
        let errors = [
            configuration.role.receives && receivedDatagramCount < expectedReceiveCount && !fecRecoveredVideo
                ? "received \(receivedDatagramCount) of \(expectedReceiveCount) expected UltraGrid RTP/MVTP datagrams"
                : nil,
            analysis.videoFrameRecoveryFailed
                ? "UltraGrid video fragment recovery failed before frame reassembly"
                : nil,
            !analysis.videoFrameRecoveryFailed && analysis.videoFrameReassemblyFailures > 0
                ? "UltraGrid video frame reassembly failed for \(analysis.videoFrameReassemblyFailures) frame(s)"
                : nil,
        ].compactMap { $0 }
        return errors.isEmpty ? nil : errors.joined(separator: "; ")
    }

    private static func mediaReport(_ context: RuntimeMediaReportContext) -> UltraGridCompatibilityMediaReport {
        UltraGridCompatibilityMediaReport(
            id: "ultragrid-mvtp-\(context.configuration.role.rawValue)-media",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            role: context.configuration.role,
            mediaMode: context.configuration.mediaMode,
            datagrams: context.datagrams,
            transmittedDatagramCount: context.transmittedDatagramCount,
            receivedDatagramCount: context.receivedDatagramCount,
            rtpPacketsLost: context.analysis.lost,
            rtpDuplicatePacketCount: context.analysis.duplicates,
            rtpOutOfOrderPacketCount: context.analysis.outOfOrder,
            rtpSsrcChangeCount: context.analysis.ssrcChanges,
            rtpTimestampRegressionCount: context.analysis.timestampRegressions,
            rtpJitterLikeArrivalDeltaCount: context.analysis.jitterLikeArrivalDeltaChanges,
            videoFrameReassemblyFailureCount: context.analysis.videoFrameReassemblyFailures,
            topology: context.topology,
            control: context.control,
            provider: context.provider,
            sink: context.sink,
            observedEvidenceClasses: context.observedEvidenceClasses,
            missingEvidenceClassesForPass: context.missingEvidenceClassesForPass,
            realLinkTransmitted: !context.configuration.dryRun,
            verdict: context.runtimeError == nil ? .partial : .fail,
            runtimeError: context.runtimeError,
            notes: "Swift-native UltraGrid RTP/MVTP \(context.configuration.role.rawValue) run for PT20 raw video, optional RTP/JPEG and RTP/H.264 dynamic payloads, optional PT24/PT25 AES-GCM encryption, optional PT22 single-parity FEC, PT21 PCM audio, and modeled TCP control commands. Provider selection is recorded separately; reference-peer evidence remains required for PASS."
        )
    }

    private static func receivePeer(_ configuration: ExternalConnectorSessionConfiguration) -> String {
        if configuration.ultraGridTopologyMode == .serverClient,
           configuration.ultraGridTopologyRole == .server {
            return "0.0.0.0"
        }
        return configuration.peer.isEmpty ? "0.0.0.0" : configuration.peer
    }

    private static func topologyReport(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws -> UltraGridTopologyReport {
        let peerRequired = ultraGridPeerRequired(configuration)
        guard !peerRequired || !configuration.peer.isEmpty else {
            throw ExternalConnectorSessionError.connectorRequiresPeerForTx(.mvtpUltraGrid)
        }
        let state: UltraGridTopologyState
        let notes: String
        switch (configuration.ultraGridTopologyMode, configuration.ultraGridTopologyRole) {
        case (.directPeer, .direct):
            state = .directPeerReady
            notes = "Direct UltraGrid peer topology; bounded runtime evidence remains PARTIAL until measured peer route evidence exists."
        case (.serverClient, .server):
            state = .serverListening
            notes = "Server-client UltraGrid topology; server endpoint listens for a client source and does not claim NAT traversal evidence."
        case (.serverClient, .client):
            state = .clientReady
            notes = "Server-client UltraGrid topology; client endpoint requires a configured server peer and remains PARTIAL without field route evidence."
        default:
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "ultragrid-topology-\(configuration.ultraGridTopologyMode.rawValue)-\(configuration.ultraGridTopologyRole.rawValue)"
            )
        }
        return UltraGridTopologyReport(
            mode: configuration.ultraGridTopologyMode,
            role: configuration.ultraGridTopologyRole,
            state: state,
            peerRequired: peerRequired,
            peerConfigured: !configuration.peer.isEmpty,
            localHost: configuration.localHost,
            peer: configuration.peer,
            notes: notes
        )
    }

    public static func buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> [UltraGridCompatibilityDatagram] {
        try buildDatagrams(
            configuration: configuration,
            mediaProvider: UltraGridSyntheticMediaProvider()
        )
    }

    public static func buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration,
        mediaProvider: any UltraGridMediaProviding
    ) throws -> [UltraGridCompatibilityDatagram] {
        let profile = try ExternalConnectorMediaProfile.build(configuration: configuration)
        let encryption = try encryptionConfiguration(configuration)
        var datagrams: [UltraGridCompatibilityDatagram] = []
        for packetIndex in 0..<configuration.mediaPacketCount {
            if profile.audioEnabled {
                let audioPayload = try mediaProvider.audioPCM(
                    sequenceNumber: packetIndex,
                    channels: configuration.channels,
                    framesPerPacket: configuration.framesPerPacket
                )
                let rtp = try UltraGridCompatibility.audioPacket(UltraGridAudioPacketRequest(
                    sequenceNumber: UInt16(packetIndex),
                    timestamp: UInt32(packetIndex * configuration.framesPerPacket),
                    ssrc: 0x4F4C_5541,
                    channels: configuration.channels,
                    sampleRateHertz: configuration.sampleRateHertz,
                    framesPerPacket: configuration.framesPerPacket,
                    pcmPayload: audioPayload,
                    payloadType: configuration.ultraGridAudioPayloadType
                ))
                let transmittedRTP = try encryption.map {
                    try UltraGridCompatibility.encryptedAudioPacket(rtp, configuration: $0)
                } ?? rtp
                datagrams.append(UltraGridCompatibilityDatagram(
                    stream: .audio,
                    destinationPort: configuration.audioPort,
                    rtp: transmittedRTP
                ))
            }
            if profile.videoEnabled {
                let videoPayload = try mediaProvider.videoFrame(
                    frameID: packetIndex,
                    width: configuration.videoWidth,
                    height: configuration.videoHeight,
                    bitsPerPixel: configuration.videoBitsPerPixel
                )
                let packets = try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
                    framePayload: videoPayload,
                    frameID: UInt32(packetIndex),
                    sequenceStart: UInt16(packetIndex * 8),
                    timestamp: UInt32(
                        packetIndex * UltraGridCompatibility.videoClockRateHertz / max(1, configuration.videoFrameRate)
                    ),
                    ssrc: 0x4F4C_5556,
                    width: configuration.videoWidth,
                    height: configuration.videoHeight,
                    frameRate: configuration.videoFrameRate,
                    bitsPerPixel: configuration.videoBitsPerPixel,
                    payloadType: configuration.ultraGridVideoPayloadType
                ))
                let transmittedPackets = try packets.map { packet in
                    try encryption.map {
                        try UltraGridCompatibility.encryptedVideoPacket(packet, configuration: $0)
                    } ?? packet
                }
                datagrams.append(contentsOf: transmittedPackets.map {
                    UltraGridCompatibilityDatagram(stream: .video, destinationPort: configuration.videoPort, rtp: $0)
                })
                if configuration.ultraGridFECMode == .singleParity {
                    let fec = try UltraGridCompatibility.fecParityPacket(
                        protecting: packets,
                        sequenceNumber: UInt16(packetIndex * 8 + packets.count),
                        timestamp: UInt32(
                            packetIndex * UltraGridCompatibility.videoClockRateHertz / max(1, configuration.videoFrameRate)
                        ),
                        ssrc: 0x4F4C_5556
                    )
                    datagrams.append(UltraGridCompatibilityDatagram(
                        stream: .video,
                        destinationPort: configuration.videoPort,
                        rtp: fec
                    ))
                }
            }
        }
        return datagrams
    }

    private static func payloadRegistry(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws -> UltraGridRTPPayloadRegistry {
        var dynamicPayloads: [UInt8: UltraGridNegotiatedCodec] = [:]
        if configuration.ultraGridAudioPayloadType != UltraGridCompatibility.audioPayloadType {
            dynamicPayloads[configuration.ultraGridAudioPayloadType] = .pcmAudio
        }
        if configuration.ultraGridVideoPayloadType != UltraGridCompatibility.videoPayloadType {
            dynamicPayloads[configuration.ultraGridVideoPayloadType] = .rawVideo
        }
        return try UltraGridRTPPayloadRegistry(dynamicPayloads: dynamicPayloads)
    }

    private static func encryptionConfiguration(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws -> UltraGridEncryptionConfiguration? {
        guard configuration.ultraGridEncryptionMode != .none else {
            return nil
        }
        if configuration.ultraGridFECMode != .none {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("ultragrid-encryption-with-fec")
        }
        guard let passphrase = configuration.ultraGridEncryptionPassphrase, !passphrase.isEmpty else {
            throw ExternalConnectorSessionError.missingRequiredArgument("--ultragrid-encryption-passphrase")
        }
        return try UltraGridEncryptionConfiguration(
            mode: configuration.ultraGridEncryptionMode,
            passphrase: passphrase
        )
    }

    private static func analyze(
        _ datagrams: [UltraGridCompatibilityDatagram]
    ) -> RuntimeMediaAnalysis {
        var lost = 0
        var duplicates = 0
        var outOfOrder = 0
        var ssrcChanges = 0
        var timestampRegressions = 0
        var jitterLikeArrivalDeltaChanges = 0
        for streamDatagrams in Dictionary(grouping: datagrams, by: \.stream).values {
            let stream = analyzeSequence(streamDatagrams)
            lost += stream.lost
            duplicates += stream.duplicates
            outOfOrder += stream.outOfOrder
            ssrcChanges += stream.ssrcChanges
            timestampRegressions += stream.timestampRegressions
            jitterLikeArrivalDeltaChanges += stream.jitterLikeArrivalDeltaChanges
        }
        let videoReassembly = countVideoFrameReassemblyFailures(datagrams)
        return (
            lost,
            duplicates,
            outOfOrder,
            ssrcChanges,
            timestampRegressions,
            jitterLikeArrivalDeltaChanges,
            videoReassembly.failureCount,
            videoReassembly.recoveryFailed
        )
    }

    private static func analyzeSequence(
        _ datagrams: [UltraGridCompatibilityDatagram]
    ) -> (
        lost: Int,
        duplicates: Int,
        outOfOrder: Int,
        ssrcChanges: Int,
        timestampRegressions: Int,
        jitterLikeArrivalDeltaChanges: Int
    ) {
        guard let first = datagrams.first else {
            return (0, 0, 0, 0, 0, 0)
        }
        let sequences = datagrams.map(\.rtp.header.sequenceNumber)
        let uniqueSequences = Set(sequences)
        let expected = Set((uniqueSequences.min() ?? 0)...(uniqueSequences.max() ?? 0))
        var outOfOrder = 0
        var timestampRegressions = 0
        var jitterLikeDeltaChanges = 0
        var previousSequence = first.rtp.header.sequenceNumber
        var previousTimestamp = first.rtp.header.timestamp
        var expectedTimestampDelta: UInt32?
        for datagram in datagrams.dropFirst() {
            let sequence = datagram.rtp.header.sequenceNumber
            let timestamp = datagram.rtp.header.timestamp
            if sequence < previousSequence {
                outOfOrder += 1
            }
            if timestamp < previousTimestamp {
                timestampRegressions += 1
            } else {
                let delta = timestamp - previousTimestamp
                if delta > 0 {
                    if let expectedTimestampDelta, delta != expectedTimestampDelta {
                        jitterLikeDeltaChanges += 1
                    } else if expectedTimestampDelta == nil {
                        expectedTimestampDelta = delta
                    }
                }
            }
            previousSequence = sequence
            previousTimestamp = timestamp
        }
        return (
            expected.subtracting(uniqueSequences).count,
            max(0, sequences.count - uniqueSequences.count),
            outOfOrder,
            max(0, Set(datagrams.map(\.rtp.header.ssrc)).count - 1),
            timestampRegressions,
            jitterLikeDeltaChanges
        )
    }

    private static func countVideoFrameReassemblyFailures(
        _ datagrams: [UltraGridCompatibilityDatagram]
    ) -> (failureCount: Int, recoveryFailed: Bool) {
        let videoPackets = datagrams
            .filter { $0.stream == .video && $0.rtp.header.payloadType != UltraGridCompatibility.encryptedVideoPayloadType }
            .map(\.rtp)
        let videoFragments: [UltraGridVideoRawFragmentPayload]
        do {
            videoFragments = try UltraGridCompatibility.recoverVideoFragments(from: videoPackets)
        } catch {
            return (videoPackets.isEmpty ? 0 : 1, true)
        }
        let byFrame = Dictionary(grouping: videoFragments, by: \.frameID)
        let failureCount = byFrame.values.reduce(0) { count, fragments in
            do {
                _ = try UltraGridCompatibility.reassembleVideoFrame(fragments)
                return count
            } catch {
                return count + 1
            }
        }
        return (failureCount, false)
    }

    private static func consumeReceivedMedia(
        _ datagrams: [UltraGridCompatibilityDatagram],
        encryptionConfiguration: UltraGridEncryptionConfiguration?
    ) throws -> ExternalConnectorMediaSinkReport {
        var audioPacketCount = 0
        var audioPayloadByteCount = 0
        var rejectedMediaCount = 0
        var videoFrameCount = 0
        var videoPayloadByteCount = 0
        var videoPackets: [RTPPacket] = []

        for datagram in datagrams {
            switch datagram.stream {
            case .audio:
                do {
                    let audioRTP = datagram.rtp.header.payloadType == UltraGridCompatibility.encryptedAudioPayloadType
                        ? try UltraGridRTPPacketCodec.decode(
                            datagram.rtp,
                            encryptionConfiguration: encryptionConfiguration
                        ).rtp
                        : datagram.rtp
                    let audio = try UltraGridAudioPayload.decode(audioRTP.payload)
                    audioPacketCount += 1
                    audioPayloadByteCount += audio.pcmPayload.count
                } catch {
                    rejectedMediaCount += 1
                }
            case .video:
                if datagram.rtp.header.payloadType == UltraGridCompatibility.encryptedVideoPayloadType {
                    do {
                        videoPackets.append(try UltraGridRTPPacketCodec.decode(
                            datagram.rtp,
                            encryptionConfiguration: encryptionConfiguration
                        ).rtp)
                    } catch {
                        rejectedMediaCount += 1
                    }
                } else {
                    videoPackets.append(datagram.rtp)
                }
            }
        }

        let videoFragments: [UltraGridVideoRawFragmentPayload]
        do {
            videoFragments = try UltraGridCompatibility.recoverVideoFragments(from: videoPackets)
        } catch {
            videoFragments = []
            rejectedMediaCount += videoPackets.isEmpty ? 0 : 1
        }
        for fragments in Dictionary(grouping: videoFragments, by: \.frameID).values {
            do {
                let frame = try UltraGridCompatibility.reassembleVideoFrame(fragments)
                videoFrameCount += 1
                videoPayloadByteCount += frame.count
            } catch {
                rejectedMediaCount += 1
            }
        }

        return ExternalConnectorMediaSinkReport(
            audioPacketCount: audioPacketCount,
            audioPayloadByteCount: audioPayloadByteCount,
            videoFrameCount: videoFrameCount,
            videoPayloadByteCount: videoPayloadByteCount,
            rejectedMediaCount: rejectedMediaCount,
            notes: "Decoded UltraGrid PT21 PCM, optional PT22 single-parity FEC, and reassembled PT20 raw-video frames into bounded artifact sink counters."
        )
    }
}
