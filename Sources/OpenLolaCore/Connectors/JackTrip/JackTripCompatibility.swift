import Darwin
import Foundation

public struct JackTripCompatibilityDatagram: Codable, Equatable, Sendable {
    public var sourceHost: String?
    public var sourcePort: UInt16?
    public var destinationPort: UInt16
    public var headerMode: JackTripPacketHeaderMode
    public var packets: [JackTripAudioPacket]

    public init(
        sourceHost: String? = nil,
        sourcePort: UInt16? = nil,
        destinationPort: UInt16,
        headerMode: JackTripPacketHeaderMode = .default,
        packet: JackTripAudioPacket
    ) {
        self.init(
            sourceHost: sourceHost,
            sourcePort: sourcePort,
            destinationPort: destinationPort,
            headerMode: headerMode,
            packets: [packet]
        )
    }

    public init(
        sourceHost: String? = nil,
        sourcePort: UInt16? = nil,
        destinationPort: UInt16,
        headerMode: JackTripPacketHeaderMode = .default,
        packets: [JackTripAudioPacket]
    ) {
        self.sourceHost = sourceHost
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.headerMode = headerMode
        self.packets = packets
    }

    public var packet: JackTripAudioPacket {
        packets[0]
    }
}

public struct JackTripCompatibilityMediaReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var role: ExternalConnectorSessionRole
    public var datagrams: [JackTripCompatibilityDatagram]
    public var transmittedDatagramCount: Int
    public var receivedDatagramCount: Int
    public var stopControlDatagramCount: Int
    public var redundancyRecoveredPacketCount: Int
    public var packetLossCount: Int
    public var duplicatePacketCount: Int
    public var outOfOrderPacketCount: Int
    public var learnedPeerHost: String?
    public var learnedPeerPort: UInt16?
    public var networkServiceClassStatus: String
    public var unsupportedModes: [String]
    public var topology: JackTripTopologyReport
    public var tcpHandshake: JackTripTCPHandshakeReport
    public var provider: ExternalConnectorMediaProviderReport
    public var sink: ExternalConnectorMediaSinkReport
    public var observedEvidenceClasses: [ExternalConnectorEvidenceClass]
    public var missingEvidenceClassesForPass: [ExternalConnectorEvidenceClass]
    public var realLinkTransmitted: Bool
    public var verdict: MeasurementVerdict
    public var runtimeError: String?
    public var runtimeErrorFree: Bool?
    public var evidenceBoundary: String
    public var notes: String

    public init(fields: JackTripCompatibilityMediaReportFields) {
        id = fields.id
        capturedAt = fields.capturedAt
        role = fields.role
        datagrams = fields.datagrams
        transmittedDatagramCount = fields.transmittedDatagramCount
        receivedDatagramCount = fields.receivedDatagramCount
        stopControlDatagramCount = fields.stopControlDatagramCount
        redundancyRecoveredPacketCount = fields.redundancyRecoveredPacketCount
        packetLossCount = fields.packetLossCount
        duplicatePacketCount = fields.duplicatePacketCount
        outOfOrderPacketCount = fields.outOfOrderPacketCount
        learnedPeerHost = fields.learnedPeerHost
        learnedPeerPort = fields.learnedPeerPort
        networkServiceClassStatus = fields.networkServiceClassStatus
        unsupportedModes = fields.unsupportedModes
        topology = fields.topology
        tcpHandshake = fields.tcpHandshake
        provider = fields.provider
        sink = fields.sink
        observedEvidenceClasses = fields.observedEvidenceClasses
        missingEvidenceClassesForPass = fields.missingEvidenceClassesForPass
        realLinkTransmitted = fields.realLinkTransmitted
        verdict = fields.verdict
        runtimeError = fields.runtimeError
        runtimeErrorFree = fields.runtimeErrorFree ?? (fields.runtimeError == nil)
        evidenceBoundary = fields.evidenceBoundary
        notes = fields.notes
    }

    public func validate() throws {
        try requireExternalConnectorSessionNonEmpty(id, "jackTripMedia.id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "jackTripMedia.capturedAt")
        try topology.validate(fieldPrefix: "jackTripMedia.topology")
        try tcpHandshake.validate(fieldPrefix: "jackTripMedia.tcpHandshake")
        try provider.validate(fieldPrefix: "jackTripMedia.provider")
        try sink.validate(fieldPrefix: "jackTripMedia.sink")
        try requireExternalConnectorSessionNonEmptyEvidenceClasses(
            observedEvidenceClasses,
            "jackTripMedia.observedEvidenceClasses"
        )
        try requireExternalConnectorSessionNonEmpty(evidenceBoundary, "jackTripMedia.evidenceBoundary")
        try requireExternalConnectorSessionNonEmpty(notes, "jackTripMedia.notes")
        if verdict == .pass {
            try validatePassEvidence()
        } else {
            try requireExternalConnectorSessionNonEmptyEvidenceClasses(
                missingEvidenceClassesForPass,
                "jackTripMedia.missingEvidenceClassesForPass"
            )
        }
        if verdict == .fail {
            try requireExternalConnectorSessionNonEmpty(runtimeError ?? "", "jackTripMedia.runtimeError")
        }
        try validateNonNegativeCounts()
        try requireExternalConnectorSessionNonEmpty(
            networkServiceClassStatus,
            "jackTripMedia.networkServiceClassStatus"
        )
    }

    private func validateNonNegativeCounts() throws {
        guard transmittedDatagramCount >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "jackTripMedia.transmittedDatagramCount",
                String(transmittedDatagramCount)
            )
        }
        guard receivedDatagramCount >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "jackTripMedia.receivedDatagramCount",
                String(receivedDatagramCount)
            )
        }
        guard stopControlDatagramCount >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "jackTripMedia.stopControlDatagramCount",
                String(stopControlDatagramCount)
            )
        }
        guard redundancyRecoveredPacketCount >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "jackTripMedia.redundancyRecoveredPacketCount",
                String(redundancyRecoveredPacketCount)
            )
        }
    }

}

public struct JackTripCompatibilityMediaReportFields: Sendable {
    public var id = ""
    public var capturedAt = ""
    public var role = ExternalConnectorSessionRole.tx
    public var datagrams: [JackTripCompatibilityDatagram] = []
    public var transmittedDatagramCount = 0
    public var receivedDatagramCount = 0
    public var stopControlDatagramCount = 0
    public var redundancyRecoveredPacketCount = 0
    public var packetLossCount = 0
    public var duplicatePacketCount = 0
    public var outOfOrderPacketCount = 0
    public var learnedPeerHost: String?
    public var learnedPeerPort: UInt16?
    public var networkServiceClassStatus = JackTripCompatibility.networkServiceClassStatus
    public var unsupportedModes = JackTripCompatibility.unsupportedModes
    public var topology = JackTripTopologyReport(
        mode: .directPeer,
        role: .direct,
        state: .directPeerReady,
        peerRequired: false,
        peerConfigured: false,
        localHost: "0.0.0.0",
        peer: "",
        hubPatchMode: .serverToClients,
        notes: "Direct JackTrip peer topology."
    )
    public var tcpHandshake = JackTripTCPHandshakeReport(
        mode: .none,
        state: .notApplicable,
        clientUDPPort: 0,
        serverUDPPort: 0,
        remoteClientName: nil,
        clientRequestByteCount: 0,
        serverResponseByteCount: 0,
        credentialFrameByteCount: 0,
        notes: "TCP hub handshake is not applicable for direct-peer JackTrip."
    )
    public var provider = ExternalConnectorMediaProviderReport(
        audioSource: "synthetic",
        videoSource: "not-applicable",
        observedEvidenceClasses: [.synthetic],
        notes: "Synthetic JackTrip audio provider."
    )
    public var sink = ExternalConnectorMediaSinkReport(
        notes: "No JackTrip RX sink media was decoded for this role."
    )
    public var observedEvidenceClasses = [ExternalConnectorEvidenceClass.synthetic]
    public var missingEvidenceClassesForPass = ExternalConnectorEvidenceClass.runtimePassRequiredEvidence
    public var realLinkTransmitted = false
    public var verdict = MeasurementVerdict.partial
    public var runtimeError: String?
    public var runtimeErrorFree: Bool?
    public var evidenceBoundary = JackTripCompatibility.evidenceBoundary
    public var notes = ""

    public init() {}
}

public extension JackTripCompatibilityMediaReport {
    var runtimeEvidenceState: ExternalConnectorRuntimeEvidenceState {
        externalConnectorRuntimeEvidenceState(
            verdict: verdict,
            runtimeError: runtimeError,
            runtimeErrorFree: runtimeErrorFree
        )
    }
}

public struct JackTripCompatibilityReceiveResult: Codable, Equatable, Sendable {
    public var datagrams: [JackTripCompatibilityDatagram]
    public var stopControlDatagramCount: Int

    public init(datagrams: [JackTripCompatibilityDatagram], stopControlDatagramCount: Int = 0) {
        self.datagrams = datagrams
        self.stopControlDatagramCount = stopControlDatagramCount
    }
}

private struct JackTripRunMediaResult: Sendable {
    var generated: [JackTripCompatibilityDatagram]
    var transmitted: Int
    var received: [JackTripCompatibilityDatagram]
    var stopControlDatagramCount: Int
    var expectedReceiveCount: Int
}

public protocol JackTripAudioFrameProviding {
    var providerReport: ExternalConnectorMediaProviderReport { get }

    func interleavedInt16PCM(sequenceNumber: Int, channels: Int, frames: Int) throws -> Data
}

public extension JackTripAudioFrameProviding {
    var providerReport: ExternalConnectorMediaProviderReport {
        ExternalConnectorMediaProviderReport(
            audioSource: "injected-fixture",
            videoSource: "not-applicable",
            observedEvidenceClasses: [.synthetic],
            notes: "Injected deterministic JackTrip audio provider."
        )
    }
}

public struct JackTripSyntheticAudioFrameProvider: JackTripAudioFrameProviding {
    public init() {}

    public var providerReport: ExternalConnectorMediaProviderReport {
        ExternalConnectorMediaProviderReport(
            audioSource: "synthetic",
            videoSource: "not-applicable",
            observedEvidenceClasses: [.synthetic],
            notes: "Generated interleaved Int16 PCM for JackTrip DEFAULT packetization."
        )
    }

    public func interleavedInt16PCM(sequenceNumber: Int, channels: Int, frames: Int) throws -> Data {
        var data = Data()
        data.reserveCapacity(channels * frames * MemoryLayout<Int16>.size)
        for frame in 0..<frames {
            for channel in 0..<channels {
                let sample = Int16(clamping: ((sequenceNumber + frame + channel) % 127) - 63)
                data.append(UInt8(truncatingIfNeeded: sample))
                data.append(UInt8(truncatingIfNeeded: sample >> 8))
            }
        }
        return data
    }
}

protocol JackTripAudioProviderLifecycle {
    func start() throws
    func stop()
}

final class JackTripSessionAudioFrameProvider: JackTripAudioFrameProviding, JackTripAudioProviderLifecycle {
    private enum Source {
        case synthetic
        case fixture(Data)
        case coreAudio
        case jackGraph
    }

    private let configuration: ExternalConnectorSessionConfiguration
    private let source: Source
    private let report: ExternalConnectorMediaProviderReport
    private var audioBridge: LoLaCoreAudioLiveBridge?

    init(configuration: ExternalConnectorSessionConfiguration) throws {
        self.configuration = configuration
        self.source = try Self.source(configuration)
        self.report = Self.providerReport(source)
    }

    var providerReport: ExternalConnectorMediaProviderReport { report }

    func start() throws {
        if case .coreAudio = source {
            audioBridge = try LoLaCoreAudioLiveBridge.makeIfRequested(configuration: configuration)
            guard let audioBridge else {
                throw ExternalConnectorSessionError.missingRequiredArgument("--audio-capture coreaudio:<device-uid>")
            }
            try audioBridge.start()
        }
        if case .jackGraph = source {
            if !configuration.dryRun {
                throw ExternalConnectorSessionError.processLaunchFailed(
                    "jack-graph-backend requires a measured JACK graph capture provider in this environment"
                )
            }
        }
    }

    func stop() {
        audioBridge?.stop()
        audioBridge = nil
    }

    func interleavedInt16PCM(sequenceNumber: Int, channels: Int, frames: Int) throws -> Data {
        switch source {
        case .synthetic:
            return try JackTripSyntheticAudioFrameProvider().interleavedInt16PCM(
                sequenceNumber: sequenceNumber,
                channels: channels,
                frames: frames
            )
        case let .fixture(data):
            return repeatedFixtureData(
                data,
                byteCount: max(1, channels * frames * MemoryLayout<Int16>.size)
            )
        case .coreAudio:
            guard let audioBridge else {
                throw ExternalConnectorSessionError.socketFailed("Core Audio JackTrip provider was not started")
            }
            let deadline = Date().addingTimeInterval(1)
            while Date() < deadline {
                if let payload = try audioBridge.nextLoLaAudioPayload() {
                    return payload
                }
                Thread.sleep(forTimeInterval: 0.001)
            }
            throw ExternalConnectorSessionError.socketFailed(
                "Core Audio capture produced no JackTrip audio payload before timeout"
            )
        case .jackGraph:
            return try JackTripSyntheticAudioFrameProvider().interleavedInt16PCM(
                sequenceNumber: sequenceNumber,
                channels: channels,
                frames: frames
            )
        }
    }

    private static func source(_ configuration: ExternalConnectorSessionConfiguration) throws -> Source {
        if configuration.jackTrip.audioBackend == .jackGraph {
            return .jackGraph
        }
        guard let value = configuration.audioCapture else {
            return .synthetic
        }
        if value.hasPrefix("fixture:") {
            return .fixture(try parseFixtureBytes(value, field: "audioCapture"))
        }
        if value.hasPrefix("coreaudio:") {
            return .coreAudio
        }
        return .synthetic
    }

    private static func providerReport(_ source: Source) -> ExternalConnectorMediaProviderReport {
        let audioSource: String
        let evidence: [ExternalConnectorEvidenceClass]
        switch source {
        case .synthetic:
            audioSource = "synthetic"
            evidence = [.synthetic]
        case .fixture:
            audioSource = "fixture"
            evidence = [.synthetic]
        case .coreAudio:
            audioSource = "coreaudio-live"
            evidence = [.liveDevice]
        case .jackGraph:
            audioSource = "jack-graph-backend"
            evidence = [.synthetic]
        }
        let notes = switch source {
        case .jackGraph:
            "JACK graph backend selected. Dry runs use deterministic local frames; "
                + "measured runs require local JACK graph capture evidence."
        default:
            "JackTrip public session audio provider selection for DEFAULT UDP packetization."
        }
        return ExternalConnectorMediaProviderReport(
            audioSource: audioSource,
            videoSource: "not-applicable",
            observedEvidenceClasses: evidence,
            notes: notes
        )
    }
}

public protocol JackTripCompatibilityMediaTransmitting {
    func transmit(_ datagrams: [JackTripCompatibilityDatagram], localHost: String, peer: String) throws -> Int
}

public protocol JackTripCompatibilityMediaReceiving {
    func receive(_ request: JackTripMediaReceiveRequest) throws -> JackTripCompatibilityReceiveResult
}

public struct JackTripMediaReceiveRequest: Sendable {
    public var expectedDatagrams: Int
    public var localHost: String
    public var peer: String
    public var audioPort: UInt16
    public var headerMode: JackTripPacketHeaderMode
    public var emptyHeaderTemplate: JackTripDefaultHeader?
    public var timeoutSeconds: Int

    public init(
        expectedDatagrams: Int,
        localHost: String,
        peer: String,
        audioPort: UInt16,
        headerMode: JackTripPacketHeaderMode,
        emptyHeaderTemplate: JackTripDefaultHeader?,
        timeoutSeconds: Int
    ) {
        self.expectedDatagrams = expectedDatagrams
        self.localHost = localHost
        self.peer = peer
        self.audioPort = audioPort
        self.headerMode = headerMode
        self.emptyHeaderTemplate = emptyHeaderTemplate
        self.timeoutSeconds = timeoutSeconds
    }
}

public final class JackTripMemoryMediaTransmitter: JackTripCompatibilityMediaTransmitting {
    public private(set) var transmittedDatagrams: [JackTripCompatibilityDatagram] = []

    public init() {}

    public func transmit(
        _ datagrams: [JackTripCompatibilityDatagram],
        localHost _: String,
        peer _: String
    ) throws -> Int {
        transmittedDatagrams.append(contentsOf: datagrams)
        return datagrams.count
    }
}

public struct JackTripMemoryMediaReceiver: JackTripCompatibilityMediaReceiving {
    public var datagrams: [JackTripCompatibilityDatagram]

    public init(datagrams: [JackTripCompatibilityDatagram]) {
        self.datagrams = datagrams
    }

    public func receive(_ request: JackTripMediaReceiveRequest) throws -> JackTripCompatibilityReceiveResult {
        JackTripCompatibilityReceiveResult(datagrams: Array(datagrams.filter {
            ($0.sourceHost == nil || $0.sourceHost == request.peer || request.peer == "0.0.0.0")
                && $0.destinationPort == request.audioPort
        }.prefix(request.expectedDatagrams)))
    }
}

public struct JackTripSocketMediaTransmitter: JackTripCompatibilityMediaTransmitting {
    public init() {}

    public func transmit(_ datagrams: [JackTripCompatibilityDatagram], localHost: String, peer: String) throws -> Int {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: 1)
        defer { closeUdpSocket(socket) }
        if localHost != "0.0.0.0" {
            try bindIPv4(socket, host: localHost, port: 0)
        }
        for datagram in datagrams {
            try sendDatagram(
                try JackTripAudioPayloadCodec.encodeDatagram(
                    datagram.packets,
                    headerMode: datagram.headerMode
                ),
                socket: socket,
                host: peer,
                port: datagram.destinationPort.bigEndian
            )
        }
        return datagrams.count
    }
}

public struct JackTripSocketMediaReceiver: JackTripCompatibilityMediaReceiving {
    public init() {}

    public func receive(_ request: JackTripMediaReceiveRequest) throws -> JackTripCompatibilityReceiveResult {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: request.timeoutSeconds)
        defer { closeUdpSocket(socket) }
        try bindIPv4(socket, host: request.localHost, port: request.audioPort.bigEndian)
        try setNonBlocking(socket)
        var received: [JackTripCompatibilityDatagram] = []
        let deadline = Date().addingTimeInterval(TimeInterval(max(1, request.timeoutSeconds)))
        var buffer: [UInt8] = []
        var stopControlDatagramCount = 0
        while received.count < request.expectedDatagrams, Date() < deadline {
            while let datagram = try receiveDatagramWithSourceIfAvailable(
                socket: socket,
                byteCount: 65_535,
                buffer: &buffer
            ) {
                guard request.peer == "0.0.0.0" || datagram.host == request.peer else {
                    continue
                }
                if datagram.data.count == JackTripCompatibility.stopControlDatagramByteCount,
                   datagram.data.allSatisfy({ $0 == 0xff }) {
                    stopControlDatagramCount += 1
                    continue
                }
                received.append(JackTripCompatibilityDatagram(
                    sourceHost: datagram.host,
                    sourcePort: datagram.port,
                    destinationPort: request.audioPort,
                    headerMode: request.headerMode,
                    packets: try JackTripAudioPayloadCodec.decodeDatagram(
                        datagram.data,
                        headerMode: request.headerMode,
                        emptyHeaderTemplate: request.emptyHeaderTemplate
                    )
                ))
            }
            if received.count < request.expectedDatagrams {
                usleep(1_000)
            }
        }
        return JackTripCompatibilityReceiveResult(
            datagrams: received,
            stopControlDatagramCount: stopControlDatagramCount
        )
    }
}

public enum JackTripCompatibilityRunner {
    private static let jackTripMediaReportNotes =
        "Swift-native JackTrip audio packetization was exercised for the bounded session. "
        + "Provider selection, topology state, header mode, transport mode, plugin mode, "
        + "payload encoding, and TCP hub handshake modeling are recorded separately; "
        + "redundancy and stop-control evidence remain visible."

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
        let lifecycle = configuration.role.transmits
            ? audioProvider as? any JackTripAudioProviderLifecycle
            : nil
        let topology = try topologyReport(configuration)
        let tcpHandshake = try tcpHandshakeReport(configuration)
        try lifecycle?.start()
        defer { lifecycle?.stop() }
        let media = try runMedia(
            configuration: configuration,
            transmitter: transmitter,
            receiver: receiver,
            audioProvider: audioProvider
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
        audioProvider: any JackTripAudioFrameProviding
    ) throws -> JackTripRunMediaResult {
        let generated = try buildDatagrams(configuration: configuration, audioProvider: audioProvider)
        let transmitted = try transmittedDatagramCount(
            configuration: configuration,
            transmitter: transmitter,
            generated: generated
        )
        let expectedReceiveCount = configuration.role.receives ? generated.count : 0
        let receiveResult = try receiveRuntimeDatagrams(
            configuration: configuration,
            receiver: receiver,
            expectedReceiveCount: expectedReceiveCount
        )
        return JackTripRunMediaResult(
            generated: generated,
            transmitted: transmitted,
            received: receiveResult.datagrams,
            stopControlDatagramCount: receiveResult.stopControlDatagramCount,
            expectedReceiveCount: expectedReceiveCount
        )
    }

    private static func transmittedDatagramCount(
        configuration: ExternalConnectorSessionConfiguration,
        transmitter: any JackTripCompatibilityMediaTransmitting,
        generated: [JackTripCompatibilityDatagram]
    ) throws -> Int {
        guard configuration.role.transmits else {
            return 0
        }
        return try transmitter.transmit(
            generated,
            localHost: configuration.localHost,
            peer: transmitPeer(configuration)
        )
    }

    private static func receiveRuntimeDatagrams(
        configuration: ExternalConnectorSessionConfiguration,
        receiver: any JackTripCompatibilityMediaReceiving,
        expectedReceiveCount: Int
    ) throws -> JackTripCompatibilityReceiveResult {
        guard configuration.role.receives else {
            return JackTripCompatibilityReceiveResult(datagrams: [])
        }
        return try receiver.receive(JackTripMediaReceiveRequest(
            expectedDatagrams: expectedReceiveCount,
            localHost: configuration.localHost,
            peer: receivePeer(configuration),
            audioPort: configuration.audioPort,
            headerMode: configuration.jackTrip.packetHeaderMode,
            emptyHeaderTemplate: try emptyHeaderTemplate(configuration),
            timeoutSeconds: configuration.durationSeconds
        ))
    }

    private static func makeMediaReport(
        configuration: ExternalConnectorSessionConfiguration,
        media: JackTripRunMediaResult,
        topology: JackTripTopologyReport,
        tcpHandshake: JackTripTCPHandshakeReport,
        audioProvider: any JackTripAudioFrameProviding
    ) -> JackTripCompatibilityMediaReport {
        let analysis = analyze(media.received)
        let runtimeError = runtimeError(
            role: configuration.role,
            receivedCount: media.received.count,
            expectedReceiveCount: media.expectedReceiveCount
        )
        let learnedPeer = learnedPeer(from: media.received)
        let sink = consumeReceivedAudio(configuration.role.receives ? media.received : [])
        let observedEvidenceClasses = audioProvider.providerReport.observedEvidenceClasses
        let missingEvidenceClassesForPass = ExternalConnectorEvidenceClass.missingRuntimePassEvidence(
            observed: observedEvidenceClasses
        )
        var fields = JackTripCompatibilityMediaReportFields()
        fields.id = "jacktrip-\(configuration.role.rawValue)-media"
        fields.capturedAt = ISO8601DateFormatter().string(from: Date())
        fields.role = configuration.role
        fields.datagrams = configuration.role.receives ? media.received : media.generated
        fields.transmittedDatagramCount = media.transmitted
        fields.receivedDatagramCount = media.received.count
        fields.stopControlDatagramCount = media.stopControlDatagramCount
        fields.redundancyRecoveredPacketCount = analysis.redundancyRecovered
        fields.packetLossCount = runtimeError == nil
            ? analysis.missing
            : max(0, media.expectedReceiveCount - media.received.count)
        fields.duplicatePacketCount = analysis.duplicates
        fields.outOfOrderPacketCount = analysis.outOfOrder
        fields.learnedPeerHost = learnedPeer.host
        fields.learnedPeerPort = learnedPeer.port
        fields.topology = topology
        fields.tcpHandshake = tcpHandshake
        fields.provider = audioProvider.providerReport
        fields.sink = sink
        fields.observedEvidenceClasses = observedEvidenceClasses
        fields.missingEvidenceClassesForPass = missingEvidenceClassesForPass
        fields.realLinkTransmitted = !configuration.dryRun
        fields.verdict = runtimeError == nil ? .partial : .fail
        fields.runtimeError = runtimeError
        fields.notes = jackTripMediaReportNotes
        return JackTripCompatibilityMediaReport(fields: fields)
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
        if configuration.jackTrip.packetHeaderMode == .empty,
           configuration.jackTrip.redundancy != 1 {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("jacktrip-empty-header-redundancy")
        }
        _ = try ExternalConnectorMediaProfile.build(configuration: configuration)
        let sampleRate = try JackTripSampleRate(hertz: configuration.sampleRateHertz)
        let bitResolution = configuration.jackTrip.payloadEncoding == .opusCELTLowDelay
            ? JackTripBitResolution.bit32
            : try JackTripBitResolution(bits: configuration.jackTrip.bitResolutionBits)
        let channels = try uint8(configuration.channels, "channels")
        let frames = try uint16(configuration.framesPerPacket, "framesPerPacket")
        let redundancy = max(1, configuration.jackTrip.redundancy)
        var datagrams: [JackTripCompatibilityDatagram] = []
        var packets: [JackTripAudioPacket] = []
        for packetIndex in 0..<configuration.mediaPacketCount {
            let planar = try jackTripPayload(
                configuration: configuration,
                audioProvider: audioProvider,
                packetIndex: packetIndex,
                bitResolution: bitResolution
            )
            let packet = try JackTripAudioPacket(
                header: JackTripDefaultHeader(
                    timestampMicroseconds: UInt64(1_700_000_000_000_000 + packetIndex * configuration.framesPerPacket),
                    sequenceNumber: UInt16(packetIndex & 0xffff),
                    bufferSizeSamples: frames,
                    sampleRate: sampleRate,
                    bitResolution: bitResolution,
                    incomingChannelsFromNetwork: channels,
                    outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
                ),
                planarAudioPayload: planar
            )
            packets.append(packet)
            let redundantPackets = Array(packets[max(0, packets.count - redundancy)..<packets.count].reversed())
            datagrams.append(JackTripCompatibilityDatagram(
                destinationPort: configuration.peerAudioPort ?? configuration.audioPort,
                headerMode: configuration.jackTrip.packetHeaderMode,
                packets: redundantPackets
            ))
        }
        return datagrams
    }

}
