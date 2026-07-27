// Binds UltraGrid media transport, coordinates paired transmit and receive, and records runtime outcomes.
import Foundation

final class UltraGridGeneratedDatagramLedger: @unchecked Sendable {
    private let lock = NSLock()
    private let evidenceLimit = 256
    private let observer: UltraGridIncrementalReceiveObserver
    private var attemptedDatagramCount = 0
    private var evidence: [UltraGridCompatibilityDatagram] = []

    init(encryptionConfiguration: UltraGridEncryptionConfiguration?) {
        observer = UltraGridIncrementalReceiveObserver(
            encryptionConfiguration: encryptionConfiguration
        )
    }

    func record(_ datagram: UltraGridCompatibilityDatagram) {
        lock.lock()
        attemptedDatagramCount += 1
        observer.record(datagram)
        if evidence.count < evidenceLimit { evidence.append(datagram) }
        lock.unlock()
    }

    func observationSummary() -> UltraGridIncrementalReceiveSummary {
        observer.finish()
    }

    func snapshot() -> (attempted: Int, evidence: [UltraGridCompatibilityDatagram]) {
        lock.lock()
        defer { lock.unlock() }
        return (attemptedDatagramCount, evidence)
    }
}

extension UltraGridCompatibilityRunner {
    struct RuntimeMediaAnalysis {
        var lost: Int
        var duplicates: Int
        var outOfOrder: Int
        var ssrcChanges: Int
        var timestampRegressions: Int
        var jitterLikeArrivalDeltaChanges: Int
        var videoFrameReassemblyFailures: Int
        var videoFrameRecoveryFailed: Bool
    }

    struct RuntimeSequenceAnalysis {
        var lost: Int
        var duplicates: Int
        var outOfOrder: Int
        var ssrcChanges: Int
        var timestampRegressions: Int
        var jitterLikeArrivalDeltaChanges: Int
    }

    struct RuntimeSequenceTimingAnalysis {
        var outOfOrder: Int
        var timestampRegressions: Int
        var jitterLikeArrivalDeltaChanges: Int
    }

    struct VideoFrameReassemblyAnalysis {
        var failureCount: Int
        var recoveryFailed: Bool
    }

    struct RuntimeMediaExchange {
        var expectedReceiveCount: Int
        var transmittedDatagramCount: Int
        var receivedDatagrams: [UltraGridCompatibilityDatagram]
        var receivedDatagramCount: Int
        var reportDatagrams: [UltraGridCompatibilityDatagram]
        var incrementalAnalysis: RuntimeMediaAnalysis?
        var incrementalSink: ExternalConnectorMediaSinkReport?
    }

    struct RuntimeEvidenceSummary {
        var observed: [ExternalConnectorEvidenceClass]
        var missingForPass: [ExternalConnectorEvidenceClass]
    }

    struct RuntimeMediaReportContext {
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

    struct RuntimeMediaExchangeRequest {
        var configuration: ExternalConnectorSessionConfiguration
        var transmitter: any UltraGridCompatibilityMediaTransmitting
        var receiver: any UltraGridCompatibilityMediaReceiving
        var mediaProvider: any UltraGridMediaProviding
        var payloadRegistry: UltraGridRTPPayloadRegistry
        var fullDuplexLifecycleLease: UltraGridProviderLifecycleLease?
    }

    static func mediaProviderLifecycle(
        configuration: ExternalConnectorSessionConfiguration,
        mediaProvider: any UltraGridMediaProviding
    ) -> (any UltraGridMediaProviderLifecycle)? {
        configuration.role.transmits
            ? mediaProvider as? any UltraGridMediaProviderLifecycle
            : nil
    }

    static func runtimeEvidenceSummary(
        provider: ExternalConnectorMediaProviderReport
    ) -> RuntimeEvidenceSummary {
        RuntimeEvidenceSummary(
            observed: provider.observedEvidenceClasses,
            missingForPass: ExternalConnectorEvidenceClass.missingRuntimePassEvidence(
                observed: provider.observedEvidenceClasses
            )
        )
    }

    static func runMediaExchange(_ request: RuntimeMediaExchangeRequest) throws -> RuntimeMediaExchange {
        try UltraGridRuntimeMediaExchangeContext(
            configuration: request.configuration,
            transmitter: request.transmitter,
            receiver: request.receiver,
            mediaProvider: request.mediaProvider,
            payloadRegistry: request.payloadRegistry,
            fullDuplexLifecycleLease: request.fullDuplexLifecycleLease
        ).run()
    }

    static func expectedReceiveDatagramCount(_ configuration: ExternalConnectorSessionConfiguration) throws -> Int {
        let profile = try ExternalConnectorMediaProfile.build(configuration: configuration)
        var perPacket = 0
        if profile.audioEnabled { perPacket += 1 }
        if profile.videoEnabled {
            let bytesPerPixel = max(1, configuration.videoBitsPerPixel / 8)
            let frameBytes = max(1, configuration.videoWidth * configuration.videoHeight * bytesPerPixel)
            let fragmentBytes = 1_200 - UltraGridVideoRawFragmentPayload.headerByteCount
            let fragments = (frameBytes + fragmentBytes - 1) / fragmentBytes
            perPacket += fragments + (configuration.ultraGridFECMode == .singleParity ? 1 : 0)
        }
        return perPacket * configuration.mediaPacketCount
    }

    static func receiveRequest(
        configuration: ExternalConnectorSessionConfiguration,
        expectedReceiveCount: Int,
        payloadRegistry: UltraGridRTPPayloadRegistry
    ) throws -> UltraGridMediaReceiveRequest {
        let encryptionConfiguration = try UltraGridCompatibilityRuntimeConfiguration
            .encryptionConfiguration(configuration)
        return UltraGridMediaReceiveRequest(
            expectedDatagrams: expectedReceiveCount,
            localHost: configuration.localHost,
            peer: receivePeer(configuration),
            audioPort: configuration.audioPort,
            videoPort: configuration.videoPort,
            payloadRegistry: payloadRegistry,
            encryptionConfiguration: encryptionConfiguration,
            timeoutSeconds: configuration.durationSeconds
        )
    }

    static func runtimeError(
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
            videoReassemblyError(analysis)
        ].compactMap { $0 }
        return errors.isEmpty ? nil : errors.joined(separator: "; ")
    }

    static func receiveCountError(
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

    static func fecRecoveredVideo(
        configuration: ExternalConnectorSessionConfiguration,
        sink: ExternalConnectorMediaSinkReport
    ) -> Bool {
        configuration.ultraGridFECMode != .none
            && configuration.mediaMode == .video
            && sink.videoFrameCount > 0
    }

    static func videoRecoveryError(_ analysis: RuntimeMediaAnalysis) -> String? {
        analysis.videoFrameRecoveryFailed
            ? "UltraGrid video fragment recovery failed before frame reassembly"
            : nil
    }

    static func videoReassemblyError(_ analysis: RuntimeMediaAnalysis) -> String? {
        guard !analysis.videoFrameRecoveryFailed,
              analysis.videoFrameReassemblyFailures > 0 else {
            return nil
        }
        return "UltraGrid video frame reassembly failed for \(analysis.videoFrameReassemblyFailures) frame(s)"
    }

    static func mediaReport(_ context: RuntimeMediaReportContext) -> UltraGridCompatibilityMediaReport {
        UltraGridRuntimeMediaReportBuilder(context: context).report()
    }

    static func receivePeer(_ configuration: ExternalConnectorSessionConfiguration) -> String {
        if configuration.ultraGridTopologyMode == .serverClient,
           configuration.ultraGridTopologyRole == .server {
            return "0.0.0.0"
        }
        return configuration.peer.isEmpty ? "0.0.0.0" : configuration.peer
    }

    static func topologyReport(
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
            notes = "Direct UltraGrid peer topology; bounded runtime evidence remains PARTIAL " +
                "until measured peer route evidence exists."
        case (.serverClient, .server):
            state = .serverListening
            notes = "Server-client UltraGrid topology; server endpoint listens for a client " +
                "source and does not claim NAT traversal evidence."
        case (.serverClient, .client):
            state = .clientReady
            notes = "Server-client UltraGrid topology; client endpoint requires a configured " +
                "server peer and remains PARTIAL without field route evidence."
        default:
            throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                "ultragrid-topology-\(configuration.ultraGridTopologyMode.rawValue)-" +
                    "\(configuration.ultraGridTopologyRole.rawValue)"
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
}
