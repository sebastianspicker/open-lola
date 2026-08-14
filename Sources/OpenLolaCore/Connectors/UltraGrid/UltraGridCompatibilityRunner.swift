// Executes UltraGrid compatibility transport and composes topology, control, media, and verdict evidence.
import Foundation

typealias UltraGridProviderLifecycleLease = ExternalConnectorLifecycleLease

/// Runs an UltraGrid compatibility exchange and assembles topology, control, media, and verdict evidence.
public enum UltraGridCompatibilityRunner {
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
            ? try UltraGridSessionMediaProvider(configuration: transmitProviderConfiguration(for: configuration))
            : UltraGridSyntheticMediaProvider()
        let previewSink: (any RawBGRAPreviewSink)? = !configuration.dryRun
            && configuration.role.receives
            && configuration.mediaMode.hasVideo
            && configuration.videoDisplay == "appkit"
            ? RawBGRAAppKitPreviewWindow()
            : nil
        return try run(
            configuration: configuration,
            transmitter: transmitter,
            receiver: receiver,
            mediaProvider: mediaProvider,
            previewSink: previewSink
        )
    }

    static func transmitProviderConfiguration(
        for configuration: ExternalConnectorSessionConfiguration
    ) -> ExternalConnectorSessionConfiguration {
        guard configuration.role == .txRx else { return configuration }
        var providerConfiguration = configuration
        providerConfiguration.role = .tx
        providerConfiguration.audioPlayback = nil
        return providerConfiguration
    }

    public static func run(
        configuration: ExternalConnectorSessionConfiguration,
        transmitter: any UltraGridCompatibilityMediaTransmitting,
        receiver: any UltraGridCompatibilityMediaReceiving,
        previewSink: (any RawBGRAPreviewSink)? = nil
    ) throws -> UltraGridCompatibilityMediaReport {
        try run(
            configuration: configuration,
            transmitter: transmitter,
            receiver: receiver,
            mediaProvider: UltraGridSyntheticMediaProvider(),
            previewSink: previewSink
        )
    }

    public static func run(
        configuration: ExternalConnectorSessionConfiguration,
        transmitter: any UltraGridCompatibilityMediaTransmitting,
        receiver: any UltraGridCompatibilityMediaReceiving,
        mediaProvider: any UltraGridMediaProviding,
        previewSink: (any RawBGRAPreviewSink)? = nil,
        audioPlayout: (any UltraGridReceiveAudioPlayout)? = nil
    ) throws -> UltraGridCompatibilityMediaReport {
        let previewAdapter = previewSink.map(UltraGridRawVideoPreviewAdapter.init)
        defer { previewAdapter?.close() }
        let topology = try topologyReport(configuration)
        let control = try UltraGridControlReportBuilder.report(configuration)
        let audioPlayout = try liveAudioPlayout(
            configuration: configuration,
            receiver: receiver,
            injected: audioPlayout
        )
        defer { audioPlayout?.stop() }
        try audioPlayout?.start()
        let lifecycle = mediaProviderLifecycle(configuration: configuration, mediaProvider: mediaProvider)
        try lifecycle?.start()
        let lifecycleLease = UltraGridProviderLifecycleLease(lifecycle)
        let fullDuplex = configuration.role.transmits && configuration.role.receives
        defer {
            if !fullDuplex { lifecycleLease.finish() }
        }
        let payloadRegistry = try UltraGridCompatibilityRuntimeConfiguration.payloadRegistry(configuration)
        let exchange = try runMediaExchange(RuntimeMediaExchangeRequest(
            configuration: configuration,
            transmitter: transmitter,
            receiver: receiver,
            mediaProvider: mediaProvider,
            payloadRegistry: payloadRegistry,
            fullDuplexLifecycleLease: fullDuplex ? lifecycleLease : nil,
            previewAdapter: previewAdapter,
            audioPlayout: audioPlayout,
            durationDeadline: nil,
            clock: nil
        ))
        return try runtimeMediaReport(
            configuration: configuration,
            exchange: exchange,
            topology: topology,
            control: control,
            mediaProvider: mediaProvider,
            previewAdapter: previewAdapter,
            audioPlayout: audioPlayout
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

    private static func runtimeMediaReport(
        configuration: ExternalConnectorSessionConfiguration,
        exchange: RuntimeMediaExchange,
        topology: UltraGridTopologyReport,
        control: UltraGridControlReport,
        mediaProvider: any UltraGridMediaProviding,
        previewAdapter: UltraGridRawVideoPreviewAdapter?,
        audioPlayout: (any UltraGridReceiveAudioPlayout)?
    ) throws -> UltraGridCompatibilityMediaReport {
        let analysis = exchange.incrementalAnalysis ?? analyze(exchange.reportDatagrams)
        let sink = try exchange.incrementalSink ?? UltraGridCompatibilityMediaSinkDecoder.consumeReceivedMedia(
            configuration.role.receives ? exchange.receivedDatagrams : [],
            encryptionConfiguration: try UltraGridCompatibilityRuntimeConfiguration.encryptionConfiguration(configuration),
            previewAdapter: previewAdapter,
            audioPlayout: audioPlayout
        )
        let evidence = runtimeEvidenceSummary(provider: mediaProvider.providerReport)
        return mediaReport(RuntimeMediaReportContext(
            configuration: configuration,
            datagrams: exchange.reportDatagrams,
            transmittedDatagramCount: exchange.transmittedDatagramCount,
            receivedDatagramCount: exchange.receivedDatagramCount,
            analysis: analysis,
            topology: topology,
            control: control,
            provider: mediaProvider.providerReport,
            sink: sink,
            observedEvidenceClasses: evidence.observed,
            missingEvidenceClassesForPass: evidence.missingForPass,
            runtimeError: runtimeError(
                configuration: configuration,
                expectedReceiveCount: exchange.expectedReceiveCount,
                receivedDatagramCount: exchange.receivedDatagramCount,
                analysis: analysis,
                sink: sink
            )
        ))
    }

}
