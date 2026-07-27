// Keeps the shared-deadline UltraGrid exchange orchestration separate from report composition.
import Foundation

struct UltraGridRuntimeMediaExchangeContext {
    let configuration: ExternalConnectorSessionConfiguration
    let transmitter: any UltraGridCompatibilityMediaTransmitting
    let receiver: any UltraGridCompatibilityMediaReceiving
    let mediaProvider: any UltraGridMediaProviding
    let payloadRegistry: UltraGridRTPPayloadRegistry
    let fullDuplexLifecycleLease: UltraGridProviderLifecycleLease?
    let deadline: UltraGridRuntimeDeadline?
    let ledger: UltraGridGeneratedDatagramLedger

    init(
        configuration: ExternalConnectorSessionConfiguration,
        transmitter: any UltraGridCompatibilityMediaTransmitting,
        receiver: any UltraGridCompatibilityMediaReceiving,
        mediaProvider: any UltraGridMediaProviding,
        payloadRegistry: UltraGridRTPPayloadRegistry,
        fullDuplexLifecycleLease: UltraGridProviderLifecycleLease?
    ) throws {
        self.configuration = configuration
        self.transmitter = transmitter
        self.receiver = receiver
        self.mediaProvider = mediaProvider
        self.payloadRegistry = payloadRegistry
        self.fullDuplexLifecycleLease = fullDuplexLifecycleLease
        deadline = configuration.role.transmits && configuration.role.receives
            ? UltraGridRuntimeDeadline(timeoutSeconds: configuration.durationSeconds)
            : nil
        ledger = UltraGridGeneratedDatagramLedger(
            encryptionConfiguration: try UltraGridCompatibilityRuntimeConfiguration.encryptionConfiguration(configuration)
        )
    }

    func run() throws -> UltraGridCompatibilityRunner.RuntimeMediaExchange {
        let exchange = try exchangeResult()
        return try makeExchange(transmitted: exchange.transmitted, receiveResult: exchange.receiveResult)
    }

    private func exchangeResult() throws -> (transmitted: Int, receiveResult: UltraGridCompatibilityReceiveResult) {
        if configuration.role.transmits && configuration.role.receives { return try fullDuplexExchange() }
        if configuration.role.transmits { return try transmitOnlyExchange() }
        return try receiveOnlyExchange()
    }

    private func fullDuplexExchange() throws -> (transmitted: Int, receiveResult: UltraGridCompatibilityReceiveResult) {
        let result = try receiver.receiveWhileBound(
            try UltraGridCompatibilityRunner.receiveRequest(
                configuration: configuration, expectedReceiveCount: 0, payloadRegistry: payloadRegistry
            ),
            transmit: transmit
        )
        return (result.transmitted, result.received)
    }

    private func transmitOnlyExchange() throws -> (transmitted: Int, receiveResult: UltraGridCompatibilityReceiveResult) {
        (try transmit().successfulDatagramCount, UltraGridCompatibilityReceiveResult(datagrams: []))
    }

    private func receiveOnlyExchange() throws -> (transmitted: Int, receiveResult: UltraGridCompatibilityReceiveResult) {
        let expected = try UltraGridCompatibilityRunner.expectedReceiveDatagramCount(configuration)
        let result = try receiver.receiveResult(try UltraGridCompatibilityRunner.receiveRequest(
            configuration: configuration, expectedReceiveCount: expected, payloadRegistry: payloadRegistry
        ))
        return (0, result)
    }

    private func transmit() throws -> UltraGridCompatibilityTransmitResult {
        defer { fullDuplexLifecycleLease?.finish() }
        let successful = try transmitter.transmitGenerated(localHost: configuration.localHost, peer: configuration.peer) { emit in
            try UltraGridCompatibilityDatagramBuilder.forEachDatagram(
                configuration: configuration,
                mediaProvider: mediaProvider,
                deadline: deadline,
                clock: transmitter is UltraGridSocketMediaTransmitter ? UltraGridSystemMonotonicClock() : nil
            ) { datagram in
                ledger.record(datagram)
                try emit(datagram)
            }
        }
        return UltraGridCompatibilityTransmitResult(
            successfulDatagramCount: successful,
            attemptedDatagramCount: ledger.snapshot().attempted
        )
    }

    private func makeExchange(
        transmitted: Int,
        receiveResult: UltraGridCompatibilityReceiveResult
    ) throws -> UltraGridCompatibilityRunner.RuntimeMediaExchange {
        let generated = ledger.snapshot()
        let expected = try expectedReceiveCount(generated: generated)
        let generatedSummary = ledger.observationSummary()
        return UltraGridCompatibilityRunner.RuntimeMediaExchange(
            expectedReceiveCount: expected,
            transmittedDatagramCount: transmitted,
            receivedDatagrams: receiveResult.datagrams,
            receivedDatagramCount: receiveResult.receivedDatagramCount,
            reportDatagrams: configuration.role.receives ? receiveResult.datagrams : generated.evidence,
            incrementalAnalysis: receiveResult.incrementalSummary?.analysis
                ?? (configuration.role.receives ? nil : generatedSummary.analysis),
            incrementalSink: receiveResult.incrementalSummary?.sink
        )
    }

    private func expectedReceiveCount(generated: (attempted: Int, evidence: [UltraGridCompatibilityDatagram])) throws -> Int {
        guard configuration.role.receives else { return 0 }
        if configuration.role.transmits { return generated.attempted }
        return try UltraGridCompatibilityRunner.expectedReceiveDatagramCount(configuration)
    }
}
