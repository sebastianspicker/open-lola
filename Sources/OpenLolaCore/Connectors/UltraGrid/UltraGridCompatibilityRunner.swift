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
            fullDuplexLifecycleLease: fullDuplex ? lifecycleLease : nil
        ))
        return try runtimeMediaReport(
            configuration: configuration,
            exchange: exchange,
            topology: topology,
            control: control,
            mediaProvider: mediaProvider
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
        mediaProvider: any UltraGridMediaProviding
    ) throws -> UltraGridCompatibilityMediaReport {
        let analysis = exchange.incrementalAnalysis ?? analyze(exchange.reportDatagrams)
        let sink = try exchange.incrementalSink ?? UltraGridCompatibilityMediaSinkDecoder.consumeReceivedMedia(
            configuration.role.receives ? exchange.receivedDatagrams : [],
            encryptionConfiguration: try UltraGridCompatibilityRuntimeConfiguration.encryptionConfiguration(configuration)
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
