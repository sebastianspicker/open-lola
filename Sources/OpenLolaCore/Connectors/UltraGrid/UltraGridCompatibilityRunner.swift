import Foundation

public enum UltraGridCompatibilityRunner {
    private struct RuntimeMediaAnalysis {
        var lost: Int
        var duplicates: Int
        var outOfOrder: Int
        var ssrcChanges: Int
        var timestampRegressions: Int
        var jitterLikeArrivalDeltaChanges: Int
        var videoFrameReassemblyFailures: Int
        var videoFrameRecoveryFailed: Bool
    }

    private struct RuntimeSequenceAnalysis {
        var lost: Int
        var duplicates: Int
        var outOfOrder: Int
        var ssrcChanges: Int
        var timestampRegressions: Int
        var jitterLikeArrivalDeltaChanges: Int
    }

    private struct RuntimeSequenceTimingAnalysis {
        var outOfOrder: Int
        var timestampRegressions: Int
        var jitterLikeArrivalDeltaChanges: Int
    }

    private struct VideoFrameReassemblyAnalysis {
        var failureCount: Int
        var recoveryFailed: Bool
    }

    private struct RuntimeMediaExchange {
        var expectedReceiveCount: Int
        var transmittedDatagramCount: Int
        var receivedDatagrams: [UltraGridCompatibilityDatagram]
        var reportDatagrams: [UltraGridCompatibilityDatagram]
    }

    private struct RuntimeEvidenceSummary {
        var observed: [ExternalConnectorEvidenceClass]
        var missingForPass: [ExternalConnectorEvidenceClass]
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
        let lifecycle = mediaProviderLifecycle(configuration: configuration, mediaProvider: mediaProvider)
        let topology = try topologyReport(configuration)
        let control = try UltraGridControlReportBuilder.report(configuration)
        try lifecycle?.start()
        defer { lifecycle?.stop() }
        let payloadRegistry = try UltraGridCompatibilityRuntimeConfiguration.payloadRegistry(configuration)
        let exchange = try runMediaExchange(
            configuration: configuration,
            transmitter: transmitter,
            receiver: receiver,
            mediaProvider: mediaProvider,
            payloadRegistry: payloadRegistry
        )
        let analysis = analyze(exchange.reportDatagrams)
        let sink = try UltraGridCompatibilityMediaSinkDecoder.consumeReceivedMedia(
            configuration.role.receives ? exchange.receivedDatagrams : [],
            encryptionConfiguration: try UltraGridCompatibilityRuntimeConfiguration.encryptionConfiguration(configuration)
        )
        let runtimeError = runtimeError(
            configuration: configuration,
            expectedReceiveCount: exchange.expectedReceiveCount,
            receivedDatagramCount: exchange.receivedDatagrams.count,
            analysis: analysis,
            sink: sink
        )
        let evidence = runtimeEvidenceSummary(provider: mediaProvider.providerReport)
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
            observedEvidenceClasses: evidence.observed,
            missingEvidenceClassesForPass: evidence.missingForPass,
            runtimeError: runtimeError
        ))
    }

    private static func mediaProviderLifecycle(
        configuration: ExternalConnectorSessionConfiguration,
        mediaProvider: any UltraGridMediaProviding
    ) -> (any UltraGridMediaProviderLifecycle)? {
        configuration.role.transmits
            ? mediaProvider as? any UltraGridMediaProviderLifecycle
            : nil
    }

    private static func runtimeEvidenceSummary(
        provider: ExternalConnectorMediaProviderReport
    ) -> RuntimeEvidenceSummary {
        RuntimeEvidenceSummary(
            observed: provider.observedEvidenceClasses,
            missingForPass: ExternalConnectorEvidenceClass.missingRuntimePassEvidence(
                observed: provider.observedEvidenceClasses
            )
        )
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
        return try receiver.receive(UltraGridMediaReceiveRequest(
            expectedDatagrams: expectedReceiveCount,
            localHost: configuration.localHost,
            peer: receivePeer(configuration),
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            payloadRegistry: payloadRegistry,
            encryptionConfiguration: try UltraGridCompatibilityRuntimeConfiguration.encryptionConfiguration(configuration),
            timeoutSeconds: configuration.durationSeconds
        ))
    }

    private static func runtimeError(
        configuration: ExternalConnectorSessionConfiguration,
        expectedReceiveCount: Int,
        receivedDatagramCount: Int,
        analysis: RuntimeMediaAnalysis,
        sink: ExternalConnectorMediaSinkReport
    ) -> String? {
        let errors = [
            receiveCountError(
                configuration: configuration,
                expectedReceiveCount: expectedReceiveCount,
                receivedDatagramCount: receivedDatagramCount,
                sink: sink
            ),
            videoRecoveryError(analysis),
            videoReassemblyError(analysis),
        ].compactMap { $0 }
        return errors.isEmpty ? nil : errors.joined(separator: "; ")
    }

    private static func receiveCountError(
        configuration: ExternalConnectorSessionConfiguration,
        expectedReceiveCount: Int,
        receivedDatagramCount: Int,
        sink: ExternalConnectorMediaSinkReport
    ) -> String? {
        guard configuration.role.receives,
              receivedDatagramCount < expectedReceiveCount,
              !fecRecoveredVideo(configuration: configuration, sink: sink) else {
            return nil
        }
        return "received \(receivedDatagramCount) of \(expectedReceiveCount) expected UltraGrid RTP/MVTP datagrams"
    }

    private static func fecRecoveredVideo(
        configuration: ExternalConnectorSessionConfiguration,
        sink: ExternalConnectorMediaSinkReport
    ) -> Bool {
        configuration.ultraGridFECMode != .none
            && configuration.mediaMode == .video
            && sink.videoFrameCount > 0
    }

    private static func videoRecoveryError(_ analysis: RuntimeMediaAnalysis) -> String? {
        analysis.videoFrameRecoveryFailed
            ? "UltraGrid video fragment recovery failed before frame reassembly"
            : nil
    }

    private static func videoReassemblyError(_ analysis: RuntimeMediaAnalysis) -> String? {
        guard !analysis.videoFrameRecoveryFailed,
              analysis.videoFrameReassemblyFailures > 0 else {
            return nil
        }
        return "UltraGrid video frame reassembly failed for \(analysis.videoFrameReassemblyFailures) frame(s)"
    }

    private static func mediaReport(_ context: RuntimeMediaReportContext) -> UltraGridCompatibilityMediaReport {
        UltraGridCompatibilityMediaReport(UltraGridCompatibilityMediaReportInput(
            identity: UltraGridCompatibilityMediaIdentity(
                id: "ultragrid-mvtp-\(context.configuration.role.rawValue)-media",
                capturedAt: ISO8601DateFormatter().string(from: Date()),
                role: context.configuration.role,
                mediaMode: context.configuration.mediaMode
            ),
            packets: UltraGridCompatibilityPacketSummary(
                datagrams: context.datagrams,
                transmittedDatagramCount: context.transmittedDatagramCount,
                receivedDatagramCount: context.receivedDatagramCount
            ),
            quality: UltraGridCompatibilityQualityCounters(
                rtpPacketsLost: context.analysis.lost,
                rtpDuplicatePacketCount: context.analysis.duplicates,
                rtpOutOfOrderPacketCount: context.analysis.outOfOrder,
                rtpSsrcChangeCount: context.analysis.ssrcChanges,
                rtpTimestampRegressionCount: context.analysis.timestampRegressions,
                rtpJitterLikeArrivalDeltaCount: context.analysis.jitterLikeArrivalDeltaChanges,
                videoFrameReassemblyFailureCount: context.analysis.videoFrameReassemblyFailures
            ),
            reports: UltraGridCompatibilityNestedReports(
                topology: context.topology,
                control: context.control,
                provider: context.provider,
                sink: context.sink
            ),
            evidence: UltraGridCompatibilityEvidenceState(
                observedEvidenceClasses: context.observedEvidenceClasses,
                missingEvidenceClassesForPass: context.missingEvidenceClassesForPass,
                realLinkTransmitted: !context.configuration.dryRun,
                verdict: context.runtimeError == nil ? .partial : .fail,
                runtimeError: context.runtimeError,
                notes: "Swift-native UltraGrid RTP/MVTP \(context.configuration.role.rawValue) run for PT20 raw video, optional RTP/JPEG and RTP/H.264 dynamic payloads, optional PT24/PT25 AES-GCM encryption, optional PT22 single-parity FEC, PT21 PCM audio, and modeled TCP control commands. Provider selection is recorded separately; reference-peer evidence remains required for PASS."
            )
        ))
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
        try UltraGridCompatibilityDatagramBuilder.buildDatagrams(configuration: configuration)
    }

    public static func buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration,
        mediaProvider: any UltraGridMediaProviding
    ) throws -> [UltraGridCompatibilityDatagram] {
        try UltraGridCompatibilityDatagramBuilder.buildDatagrams(
            configuration: configuration,
            mediaProvider: mediaProvider
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
        return RuntimeMediaAnalysis(
            lost: lost,
            duplicates: duplicates,
            outOfOrder: outOfOrder,
            ssrcChanges: ssrcChanges,
            timestampRegressions: timestampRegressions,
            jitterLikeArrivalDeltaChanges: jitterLikeArrivalDeltaChanges,
            videoFrameReassemblyFailures: videoReassembly.failureCount,
            videoFrameRecoveryFailed: videoReassembly.recoveryFailed
        )
    }

    private static func analyzeSequence(
        _ datagrams: [UltraGridCompatibilityDatagram]
    ) -> RuntimeSequenceAnalysis {
        guard let first = datagrams.first else {
            return RuntimeSequenceAnalysis(
                lost: 0,
                duplicates: 0,
                outOfOrder: 0,
                ssrcChanges: 0,
                timestampRegressions: 0,
                jitterLikeArrivalDeltaChanges: 0
            )
        }
        let sequences = datagrams.map(\.rtp.header.sequenceNumber)
        let uniqueSequences = Set(sequences)
        let timing = analyzeSequenceTiming(datagrams, first: first)
        return RuntimeSequenceAnalysis(
            lost: lostSequenceCount(uniqueSequences),
            duplicates: max(0, sequences.count - uniqueSequences.count),
            outOfOrder: timing.outOfOrder,
            ssrcChanges: max(0, Set(datagrams.map(\.rtp.header.ssrc)).count - 1),
            timestampRegressions: timing.timestampRegressions,
            jitterLikeArrivalDeltaChanges: timing.jitterLikeArrivalDeltaChanges
        )
    }

    private static func analyzeSequenceTiming(
        _ datagrams: [UltraGridCompatibilityDatagram],
        first: UltraGridCompatibilityDatagram
    ) -> RuntimeSequenceTimingAnalysis {
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
        return RuntimeSequenceTimingAnalysis(
            outOfOrder: outOfOrder,
            timestampRegressions: timestampRegressions,
            jitterLikeArrivalDeltaChanges: jitterLikeDeltaChanges
        )
    }

    private static func lostSequenceCount(_ uniqueSequences: Set<UInt16>) -> Int {
        let expected = Set((uniqueSequences.min() ?? 0)...(uniqueSequences.max() ?? 0))
        return expected.subtracting(uniqueSequences).count
    }

    private static func countVideoFrameReassemblyFailures(
        _ datagrams: [UltraGridCompatibilityDatagram]
    ) -> VideoFrameReassemblyAnalysis {
        let videoPackets = datagrams
            .filter { $0.stream == .video && $0.rtp.header.payloadType != UltraGridCompatibility.encryptedVideoPayloadType }
            .map(\.rtp)
        let videoFragments: [UltraGridVideoRawFragmentPayload]
        do {
            videoFragments = try UltraGridCompatibility.recoverVideoFragments(from: videoPackets)
        } catch {
            return VideoFrameReassemblyAnalysis(
                failureCount: videoPackets.isEmpty ? 0 : 1,
                recoveryFailed: true
            )
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
        return VideoFrameReassemblyAnalysis(failureCount: failureCount, recoveryFailed: false)
    }

}
