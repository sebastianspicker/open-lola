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

    public init(
        id: String,
        capturedAt: String,
        role: ExternalConnectorSessionRole,
        datagrams: [JackTripCompatibilityDatagram],
        transmittedDatagramCount: Int,
        receivedDatagramCount: Int,
        stopControlDatagramCount: Int = 0,
        redundancyRecoveredPacketCount: Int = 0,
        packetLossCount: Int = 0,
        duplicatePacketCount: Int = 0,
        outOfOrderPacketCount: Int = 0,
        learnedPeerHost: String? = nil,
        learnedPeerPort: UInt16? = nil,
        networkServiceClassStatus: String = JackTripCompatibility.networkServiceClassStatus,
        unsupportedModes: [String] = JackTripCompatibility.unsupportedModes,
        topology: JackTripTopologyReport = JackTripTopologyReport(
            mode: .directPeer,
            role: .direct,
            state: .directPeerReady,
            peerRequired: false,
            peerConfigured: false,
            localHost: "0.0.0.0",
            peer: "",
            hubPatchMode: .serverToClients,
            notes: "Direct JackTrip peer topology."
        ),
        tcpHandshake: JackTripTCPHandshakeReport = JackTripTCPHandshakeReport(
            mode: .none,
            state: .notApplicable,
            clientUDPPort: 0,
            serverUDPPort: 0,
            remoteClientName: nil,
            clientRequestByteCount: 0,
            serverResponseByteCount: 0,
            credentialFrameByteCount: 0,
            notes: "TCP hub handshake is not applicable for direct-peer JackTrip."
        ),
        provider: ExternalConnectorMediaProviderReport = ExternalConnectorMediaProviderReport(
            audioSource: "synthetic",
            videoSource: "not-applicable",
            observedEvidenceClasses: [.synthetic],
            notes: "Synthetic JackTrip audio provider."
        ),
        sink: ExternalConnectorMediaSinkReport = ExternalConnectorMediaSinkReport(
            notes: "No JackTrip RX sink media was decoded for this role."
        ),
        observedEvidenceClasses: [ExternalConnectorEvidenceClass] = [.synthetic],
        missingEvidenceClassesForPass: [ExternalConnectorEvidenceClass] =
            ExternalConnectorEvidenceClass.runtimePassRequiredEvidence,
        realLinkTransmitted: Bool,
        verdict: MeasurementVerdict,
        runtimeError: String? = nil,
        runtimeErrorFree: Bool? = nil,
        evidenceBoundary: String = JackTripCompatibility.evidenceBoundary,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.role = role
        self.datagrams = datagrams
        self.transmittedDatagramCount = transmittedDatagramCount
        self.receivedDatagramCount = receivedDatagramCount
        self.stopControlDatagramCount = stopControlDatagramCount
        self.redundancyRecoveredPacketCount = redundancyRecoveredPacketCount
        self.packetLossCount = packetLossCount
        self.duplicatePacketCount = duplicatePacketCount
        self.outOfOrderPacketCount = outOfOrderPacketCount
        self.learnedPeerHost = learnedPeerHost
        self.learnedPeerPort = learnedPeerPort
        self.networkServiceClassStatus = networkServiceClassStatus
        self.unsupportedModes = unsupportedModes
        self.topology = topology
        self.tcpHandshake = tcpHandshake
        self.provider = provider
        self.sink = sink
        self.observedEvidenceClasses = observedEvidenceClasses
        self.missingEvidenceClassesForPass = missingEvidenceClassesForPass
        self.realLinkTransmitted = realLinkTransmitted
        self.verdict = verdict
        self.runtimeError = runtimeError
        self.runtimeErrorFree = runtimeErrorFree ?? (runtimeError == nil)
        self.evidenceBoundary = evidenceBoundary
        self.notes = notes
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
        guard transmittedDatagramCount >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("jackTripMedia.transmittedDatagramCount", String(transmittedDatagramCount))
        }
        guard receivedDatagramCount >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("jackTripMedia.receivedDatagramCount", String(receivedDatagramCount))
        }
        guard stopControlDatagramCount >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("jackTripMedia.stopControlDatagramCount", String(stopControlDatagramCount))
        }
        guard redundancyRecoveredPacketCount >= 0 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("jackTripMedia.redundancyRecoveredPacketCount", String(redundancyRecoveredPacketCount))
        }
        try requireExternalConnectorSessionNonEmpty(networkServiceClassStatus, "jackTripMedia.networkServiceClassStatus")
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
            throw ExternalConnectorSessionError.socketFailed("Core Audio capture produced no JackTrip audio payload before timeout")
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
            "JACK graph backend selected. Dry runs use deterministic local frames; measured runs require local JACK graph capture evidence."
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
    func receive(
        expectedDatagrams: Int,
        localHost: String,
        peer: String,
        audioPort: UInt16,
        headerMode: JackTripPacketHeaderMode,
        emptyHeaderTemplate: JackTripDefaultHeader?,
        timeoutSeconds: Int
    ) throws -> JackTripCompatibilityReceiveResult
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

    public func receive(
        expectedDatagrams: Int,
        localHost _: String,
        peer: String,
        audioPort: UInt16,
        headerMode _: JackTripPacketHeaderMode,
        emptyHeaderTemplate _: JackTripDefaultHeader?,
        timeoutSeconds _: Int
    ) throws -> JackTripCompatibilityReceiveResult {
        JackTripCompatibilityReceiveResult(datagrams: Array(datagrams.filter {
            ($0.sourceHost == nil || $0.sourceHost == peer || peer == "0.0.0.0")
                && $0.destinationPort == audioPort
        }.prefix(expectedDatagrams)))
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

    public func receive(
        expectedDatagrams: Int,
        localHost: String,
        peer: String,
        audioPort: UInt16,
        headerMode: JackTripPacketHeaderMode,
        emptyHeaderTemplate: JackTripDefaultHeader?,
        timeoutSeconds: Int
    ) throws -> JackTripCompatibilityReceiveResult {
        let socket = try makeUdpSocket(receiveTimeoutSeconds: timeoutSeconds)
        defer { closeUdpSocket(socket) }
        try bindIPv4(socket, host: localHost, port: audioPort.bigEndian)
        try setNonBlocking(socket)
        var received: [JackTripCompatibilityDatagram] = []
        let deadline = Date().addingTimeInterval(TimeInterval(max(1, timeoutSeconds)))
        var buffer: [UInt8] = []
        var stopControlDatagramCount = 0
        while received.count < expectedDatagrams, Date() < deadline {
            while let datagram = try receiveDatagramWithSourceIfAvailable(
                socket: socket,
                byteCount: 65_535,
                buffer: &buffer
            ) {
                guard peer == "0.0.0.0" || datagram.host == peer else {
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
                    destinationPort: audioPort,
                    headerMode: headerMode,
                    packets: try JackTripAudioPayloadCodec.decodeDatagram(
                        datagram.data,
                        headerMode: headerMode,
                        emptyHeaderTemplate: emptyHeaderTemplate
                    )
                ))
            }
            if received.count < expectedDatagrams {
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
        let generated = try buildDatagrams(configuration: configuration, audioProvider: audioProvider)
        let expectedReceiveCount = configuration.role.receives ? generated.count : 0
        var transmitted = 0
        var received: [JackTripCompatibilityDatagram] = []
        var stopControlDatagramCount = 0
        if configuration.role.transmits {
            transmitted = try transmitter.transmit(
                generated,
                localHost: configuration.localHost,
                peer: transmitPeer(configuration)
            )
        }
        if configuration.role.receives {
            let result = try receiver.receive(
                expectedDatagrams: expectedReceiveCount,
                localHost: configuration.localHost,
                peer: receivePeer(configuration),
                audioPort: configuration.audioPort,
                headerMode: configuration.jackTrip.packetHeaderMode,
                emptyHeaderTemplate: try emptyHeaderTemplate(configuration),
                timeoutSeconds: configuration.durationSeconds
            )
            received = result.datagrams
            stopControlDatagramCount = result.stopControlDatagramCount
        }
        let reportDatagrams = configuration.role.receives ? received : generated
        let analysis = analyze(received)
        let runtimeError = configuration.role.receives && received.count < expectedReceiveCount
            ? "received \(received.count) of \(expectedReceiveCount) expected JackTrip UDP audio datagrams"
            : nil
        let learnedPeer = learnedPeer(from: received)
        let sink = consumeReceivedAudio(configuration.role.receives ? received : [])
        let observedEvidenceClasses = audioProvider.providerReport.observedEvidenceClasses
        let missingEvidenceClassesForPass = ExternalConnectorEvidenceClass.missingRuntimePassEvidence(
            observed: observedEvidenceClasses
        )
        return JackTripCompatibilityMediaReport(
            id: "jacktrip-\(configuration.role.rawValue)-media",
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            role: configuration.role,
            datagrams: reportDatagrams,
            transmittedDatagramCount: transmitted,
            receivedDatagramCount: received.count,
            stopControlDatagramCount: stopControlDatagramCount,
            redundancyRecoveredPacketCount: analysis.redundancyRecovered,
            packetLossCount: runtimeError == nil ? analysis.missing : max(0, expectedReceiveCount - received.count),
            duplicatePacketCount: analysis.duplicates,
            outOfOrderPacketCount: analysis.outOfOrder,
            learnedPeerHost: learnedPeer.host,
            learnedPeerPort: learnedPeer.port,
            topology: topology,
            tcpHandshake: tcpHandshake,
            provider: audioProvider.providerReport,
            sink: sink,
            observedEvidenceClasses: observedEvidenceClasses,
            missingEvidenceClassesForPass: missingEvidenceClassesForPass,
            realLinkTransmitted: !configuration.dryRun,
            verdict: runtimeError == nil ? .partial : .fail,
            runtimeError: runtimeError,
            notes: "Swift-native JackTrip audio packetization was exercised for the bounded session. Provider selection, topology state, header mode, transport mode, plugin mode, payload encoding, and TCP hub handshake modeling are recorded separately; redundancy and stop-control evidence remain visible."
        )
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
