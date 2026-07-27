// Executes JackTrip compatibility transport and composes media, topology, handshake, and verdict evidence.
import Foundation

private struct JackTripMediaRunContext {
    let configuration: ExternalConnectorSessionConfiguration
    let transmitter: any JackTripCompatibilityMediaTransmitting
    let receiver: any JackTripCompatibilityMediaReceiving
    let audioProvider: any JackTripAudioFrameProviding
    let fullDuplexLifecycleLease: JackTripProviderLifecycleLease?
}

private struct JackTripMediaReportContext {
    let configuration: ExternalConnectorSessionConfiguration
    let media: JackTripRunMediaResult
    let topology: JackTripTopologyReport
    let tcpHandshake: JackTripTCPHandshakeReport
    let provider: ExternalConnectorMediaProviderReport
    let analysis: JackTripReceiveAnalysis
    let runtimeError: String?
    let zeroSuccessfulTransmission: Bool
    let sink: ExternalConnectorMediaSinkReport
    let observedEvidenceClasses: [ExternalConnectorEvidenceClass]
    let missingEvidenceClassesForPass: [ExternalConnectorEvidenceClass]
}

/// Runs a JackTrip compatibility exchange and assembles transport, media, and verdict evidence.
public enum JackTripCompatibilityRunner {
    private static let jackTripMediaReportNotes =
        "Swift-native JackTrip audio packetization was exercised for the bounded session. "
        + "Provider selection, topology state, header mode, transport mode, plugin mode, "
        + "payload encoding, and TCP hub handshake modeling are recorded separately; "
        + "redundancy and stop-control evidence remain visible."

    /// The native runner owns only the UDP socket path.  The other selections
    /// remain available for deterministic dry-run protocol-model tests.
    private static func validateNativeSocketModes(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws {
        try JackTripNativeSocketModeValidator.validate(configuration)
    }

    public static func run(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> JackTripCompatibilityMediaReport {
        let transmitter: any JackTripCompatibilityMediaTransmitting = configuration.dryRun
            ? JackTripMemoryMediaTransmitter()
            : JackTripSocketMediaTransmitter()
        let receiver: any JackTripCompatibilityMediaReceiving = configuration.dryRun
            ? JackTripMemoryMediaReceiver(datagrams: [])
            : JackTripSocketMediaReceiver()
        let audioProvider: any JackTripAudioFrameProviding = configuration.role.transmits
            ? try JackTripSessionAudioFrameProvider(configuration: configuration)
            : JackTripSyntheticAudioFrameProvider()
        return try run(
            configuration: configuration,
            transmitter: transmitter,
            receiver: receiver,
            audioProvider: audioProvider
        )
    }

    public static func run(
        configuration: ExternalConnectorSessionConfiguration,
        transmitter: any JackTripCompatibilityMediaTransmitting,
        receiver: any JackTripCompatibilityMediaReceiving
    ) throws -> JackTripCompatibilityMediaReport {
        try run(
            configuration: configuration,
            transmitter: transmitter,
            receiver: receiver,
            audioProvider: JackTripSyntheticAudioFrameProvider()
        )
    }

    public static func run(
        configuration: ExternalConnectorSessionConfiguration,
        transmitter: any JackTripCompatibilityMediaTransmitting,
        receiver: any JackTripCompatibilityMediaReceiving,
        audioProvider: any JackTripAudioFrameProviding
    ) throws -> JackTripCompatibilityMediaReport {
        try validateNativeSocketModes(configuration)
        let lifecycle = configuration.role.transmits
            ? audioProvider as? any JackTripAudioProviderLifecycle
            : nil
        let topology = try topologyReport(configuration)
        let tcpHandshake = try tcpHandshakeReport(configuration)
        try lifecycle?.start()
        let lifecycleLease = JackTripProviderLifecycleLease(lifecycle)
        let fullDuplex = configuration.role.transmits && configuration.role.receives
        defer {
            if !fullDuplex { lifecycleLease.finish() }
        }
        let media = try runMedia(
            configuration: configuration,
            transmitter: transmitter,
            receiver: receiver,
            audioProvider: audioProvider,
            fullDuplexLifecycleLease: fullDuplex ? lifecycleLease : nil
        )
        return makeMediaReport(
            configuration: configuration,
            media: media,
            topology: topology,
            tcpHandshake: tcpHandshake,
            audioProvider: audioProvider
        )
    }

    private static func runMedia(
        configuration: ExternalConnectorSessionConfiguration,
        transmitter: any JackTripCompatibilityMediaTransmitting,
        receiver: any JackTripCompatibilityMediaReceiving,
        audioProvider: any JackTripAudioFrameProviding,
        fullDuplexLifecycleLease: JackTripProviderLifecycleLease?
    ) throws -> JackTripRunMediaResult {
        let receiveAudioSink = configuration.role.receives
            ? try JackTripReceiveAudioSink(configuration: configuration)
            : nil
        let context = JackTripMediaRunContext(
            configuration: configuration,
            transmitter: transmitter,
            receiver: receiver,
            audioProvider: audioProvider,
            fullDuplexLifecycleLease: fullDuplexLifecycleLease
        )
        if configuration.role.transmits, configuration.role.receives {
            return try runFullDuplexMedia(context, receiveAudioSink: receiveAudioSink)
        }
        if configuration.role.transmits {
            return try runTransmittingMedia(context)
        }
        return try runReceivingMedia(context, receiveAudioSink: receiveAudioSink)
    }

    private static func runFullDuplexMedia(
        _ context: JackTripMediaRunContext,
        receiveAudioSink: JackTripReceiveAudioSink?
    ) throws -> JackTripRunMediaResult {
        var generated: [JackTripCompatibilityDatagram] = []
        let expectedReceiveCount = expectedDatagramCount(context.configuration)
        let deadlineNanoseconds = jackTripExchangeDeadlineNanoseconds(
            timeoutSeconds: context.configuration.durationSeconds
        )
        let exchange = try context.receiver.receiveWhileBound(
            try receiveRequest(
                configuration: context.configuration,
                expectedReceiveCount: expectedReceiveCount,
                exchangeDeadlineNanoseconds: deadlineNanoseconds,
                audioSink: receiveAudioSink
            ),
            transmit: {
                defer { context.fullDuplexLifecycleLease?.finish() }
                return try transmitGeneratedMedia(
                    context,
                    deadlineNanoseconds: deadlineNanoseconds,
                    generated: &generated
                )
            }
        )
        return makeRunMediaResult(
            generated: generated,
            transmitted: exchange.transmitted,
            receiveResult: exchange.received,
            expectedReceiveCount: expectedReceiveCount,
            receiveAudioSink: receiveAudioSink
        )
    }

    private static func runTransmittingMedia(
        _ context: JackTripMediaRunContext
    ) throws -> JackTripRunMediaResult {
        var generated: [JackTripCompatibilityDatagram] = []
        let transmitted = try transmitGeneratedMedia(context, generated: &generated)
        return makeRunMediaResult(
            generated: generated,
            transmitted: transmitted,
            receiveResult: JackTripCompatibilityReceiveResult(datagrams: []),
            expectedReceiveCount: 0,
            receiveAudioSink: nil
        )
    }

    private static func runReceivingMedia(
        _ context: JackTripMediaRunContext,
        receiveAudioSink: JackTripReceiveAudioSink?
    ) throws -> JackTripRunMediaResult {
        let expectedReceiveCount = expectedDatagramCount(context.configuration)
        let receiveResult = try context.receiver.receive(
            try receiveRequest(
                configuration: context.configuration,
                expectedReceiveCount: expectedReceiveCount,
                audioSink: receiveAudioSink
            )
        )
        return makeRunMediaResult(
            generated: [],
            transmitted: 0,
            receiveResult: receiveResult,
            expectedReceiveCount: expectedReceiveCount,
            receiveAudioSink: receiveAudioSink
        )
    }

    private static func transmitGeneratedMedia(
        _ context: JackTripMediaRunContext,
        deadlineNanoseconds: UInt64? = nil,
        generated: inout [JackTripCompatibilityDatagram]
    ) throws -> Int {
        try context.transmitter.transmitGenerated(
            localHost: context.configuration.localHost,
            peer: transmitPeer(context.configuration)
        ) { emit in
            try forEachDatagram(
                configuration: context.configuration,
                audioProvider: context.audioProvider,
                deadlineNanoseconds: deadlineNanoseconds,
                clock: context.transmitter is JackTripSocketMediaTransmitter
                    ? JackTripSystemMonotonicClock()
                    : nil
            ) { datagram in
                retainGeneratedEvidence(datagram, in: &generated)
                try emit(datagram)
            }
        }
    }

    private static func makeRunMediaResult(
        generated: [JackTripCompatibilityDatagram],
        transmitted: Int,
        receiveResult: JackTripCompatibilityReceiveResult,
        expectedReceiveCount: Int,
        receiveAudioSink: JackTripReceiveAudioSink?
    ) -> JackTripRunMediaResult {
        return JackTripRunMediaResult(
            generated: generated,
            transmitted: transmitted,
            received: receiveResult.datagrams,
            receivedDatagramCount: receiveResult.receivedDatagramCount,
            stopControlDatagramCount: receiveResult.stopControlDatagramCount,
            expectedReceiveCount: expectedReceiveCount,
            sink: receiveAudioSink?.didConsumeDatagrams == true ? receiveAudioSink?.report() : nil
        )
    }

    private static func receiveRequest(
        configuration: ExternalConnectorSessionConfiguration,
        expectedReceiveCount: Int,
        exchangeDeadlineNanoseconds: UInt64? = nil,
        audioSink: JackTripReceiveAudioSink? = nil
    ) throws -> JackTripMediaReceiveRequest {
        let headerTemplate = try emptyHeaderTemplate(configuration)
        return JackTripMediaReceiveRequest(
            expectedDatagrams: expectedReceiveCount,
            localHost: configuration.localHost,
            peer: receivePeer(configuration),
            audioPort: configuration.audioPort,
            headerMode: configuration.jackTrip.packetHeaderMode,
            emptyHeaderTemplate: headerTemplate,
            timeoutSeconds: configuration.durationSeconds,
            exchangeDeadlineNanoseconds: exchangeDeadlineNanoseconds
        ).attaching(audioSink: audioSink)
    }

    private static func makeMediaReport(
        configuration: ExternalConnectorSessionConfiguration,
        media: JackTripRunMediaResult,
        topology: JackTripTopologyReport,
        tcpHandshake: JackTripTCPHandshakeReport,
        audioProvider: any JackTripAudioFrameProviding
    ) -> JackTripCompatibilityMediaReport {
        let analysis = analyze(media.received)
        let zeroSuccessfulTransmission = configuration.role.transmits
            && configuration.mediaPacketCount > 0
            && media.transmitted == 0
        let runtimeError = runtimeError(
            role: configuration.role,
            receivedCount: media.receivedDatagramCount,
            expectedReceiveCount: media.expectedReceiveCount
        ) ?? (zeroSuccessfulTransmission
            ? "no JackTrip UDP audio datagrams were successfully transmitted"
            : nil)
        let sink = media.sink ?? consumeReceivedAudio(
            configuration.role.receives ? media.received : [],
            payloadEncoding: configuration.jackTrip.payloadEncoding,
            channels: configuration.channels
        )
        let observedEvidenceClasses = audioProvider.providerReport.observedEvidenceClasses
        let missingEvidenceClassesForPass = ExternalConnectorEvidenceClass.missingRuntimePassEvidence(
            observed: observedEvidenceClasses
        )
        let context = JackTripMediaReportContext(
            configuration: configuration,
            media: media,
            topology: topology,
            tcpHandshake: tcpHandshake,
            provider: audioProvider.providerReport,
            analysis: analysis,
            runtimeError: runtimeError,
            zeroSuccessfulTransmission: zeroSuccessfulTransmission,
            sink: sink,
            observedEvidenceClasses: observedEvidenceClasses,
            missingEvidenceClassesForPass: missingEvidenceClassesForPass
        )
        return JackTripCompatibilityMediaReport(fields: makeMediaReportFields(context))
    }

    private static func makeMediaReportFields(
        _ context: JackTripMediaReportContext
    ) -> JackTripCompatibilityMediaReportFields {
        let learnedPeer = learnedPeer(from: context.media.received)
        var fields = JackTripCompatibilityMediaReportFields()
        fields.id = "jacktrip-\(context.configuration.role.rawValue)-media"
        fields.capturedAt = ISO8601DateFormatter().string(from: Date())
        fields.role = context.configuration.role
        fields.datagrams = context.configuration.role.receives ? context.media.received : context.media.generated
        fields.transmittedDatagramCount = context.media.transmitted
        fields.receivedDatagramCount = context.media.receivedDatagramCount
        fields.stopControlDatagramCount = context.media.stopControlDatagramCount
        fields.redundancyRecoveredPacketCount = context.analysis.redundancyRecovered
        fields.packetLossCount = context.runtimeError == nil
            ? context.analysis.missing
            : max(0, context.media.expectedReceiveCount - context.media.receivedDatagramCount)
        fields.duplicatePacketCount = context.analysis.duplicates
        fields.outOfOrderPacketCount = context.analysis.outOfOrder
        fields.learnedPeerHost = learnedPeer.host
        fields.learnedPeerPort = learnedPeer.port
        fields.topology = context.topology
        fields.tcpHandshake = context.tcpHandshake
        fields.provider = context.provider
        fields.sink = context.sink
        fields.observedEvidenceClasses = context.observedEvidenceClasses
        fields.missingEvidenceClassesForPass = context.missingEvidenceClassesForPass
        fields.realLinkTransmitted = !context.configuration.dryRun && context.media.transmitted > 0
        fields.verdict = context.runtimeError == nil ? .partial : .fail
        fields.runtimeError = context.runtimeError
        fields.notes = jackTripMediaReportNotes
            + (context.zeroSuccessfulTransmission
                ? " No UDP audio datagram was successfully sent, so the runtime verdict is FAIL."
                : "")
        return fields
    }

    private static func runtimeError(
        role: ExternalConnectorSessionRole,
        receivedCount: Int,
        expectedReceiveCount: Int
    ) -> String? {
        guard role.receives, receivedCount < expectedReceiveCount else {
            return nil
        }
        return "received \(receivedCount) of \(expectedReceiveCount) expected JackTrip UDP audio datagrams"
    }

    private static func emptyHeaderTemplate(
        _ configuration: ExternalConnectorSessionConfiguration
    ) throws -> JackTripDefaultHeader? {
        guard configuration.jackTrip.packetHeaderMode == .empty else {
            return nil
        }
        return try JackTripDefaultHeader(
            timestampMicroseconds: 1,
            sequenceNumber: 0,
            bufferSizeSamples: try uint16(configuration.framesPerPacket, "framesPerPacket"),
            sampleRate: try JackTripSampleRate(hertz: configuration.sampleRateHertz),
            bitResolution: try JackTripBitResolution(bits: configuration.jackTrip.bitResolutionBits),
            incomingChannelsFromNetwork: try uint8(configuration.channels, "channels"),
            outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
        )
    }

    private static func expectedDatagramCount(
        _ configuration: ExternalConnectorSessionConfiguration
    ) -> Int {
        // Each media packet produces one UDP datagram; redundancy is carried in that datagram's packet list.
        configuration.mediaPacketCount
    }

    public static func buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration
    ) throws -> [JackTripCompatibilityDatagram] {
        try buildDatagrams(
            configuration: configuration,
            audioProvider: JackTripSyntheticAudioFrameProvider()
        )
    }

    public static func buildDatagrams(
        configuration: ExternalConnectorSessionConfiguration,
        audioProvider: any JackTripAudioFrameProviding
    ) throws -> [JackTripCompatibilityDatagram] {
        var datagrams: [JackTripCompatibilityDatagram] = []
        try forEachDatagram(configuration: configuration, audioProvider: audioProvider) {
            datagrams.append($0)
        }
        return datagrams
    }

    static func forEachDatagram(
        configuration: ExternalConnectorSessionConfiguration,
        audioProvider: any JackTripAudioFrameProviding,
        deadlineNanoseconds: UInt64? = nil,
        opusEncoderFactory: @escaping (Int) throws -> OpusCELTLowDelayEncoder = { try OpusCELTLowDelayEncoder(channelCount: $0) },
        clock: (any JackTripMonotonicClock)? = nil,
        emit: (JackTripCompatibilityDatagram) throws -> Void
    ) throws {
        try JackTripDatagramGenerator.forEachDatagram(
            JackTripDatagramGenerationRequest(
            configuration: configuration,
            audioProvider: audioProvider,
            deadlineNanoseconds: deadlineNanoseconds,
            opusEncoderFactory: opusEncoderFactory,
            clock: clock
            ),
            emit: emit
        )
    }

    private static func retainGeneratedEvidence(
        _ datagram: JackTripCompatibilityDatagram,
        in generated: inout [JackTripCompatibilityDatagram]
    ) {
        guard generated.count < JackTripMediaReceiveRequest.maximumRetainedGeneratedEvidenceDatagrams else {
            return
        }
        generated.append(datagram)
    }

}
