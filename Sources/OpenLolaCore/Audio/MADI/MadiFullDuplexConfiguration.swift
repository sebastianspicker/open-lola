// Computes RX buffering and validates source-level, device, channel, and timing choices required by a full-duplex MADI session.
import Foundation
import OpenLolaContracts

func audioTransportRxBufferPolicy(for mode: AudioTransportMode) throws -> RxBufferPolicy {
    switch mode.rxBufferProfile {
    case .direct:
        try RxBufferPolicy.direct(
            framesPerPacket: mode.framesPerPacket,
            sampleRateHertz: mode.sampleRateHertz
        )
    case .small:
        try RxBufferPolicy.small(
            framesPerPacket: mode.framesPerPacket,
            sampleRateHertz: mode.sampleRateHertz
        )
    case .adaptive:
        try RxBufferPolicy.adaptive(
            framesPerPacket: mode.framesPerPacket,
            sampleRateHertz: mode.sampleRateHertz
        )
    case .stableWan:
        try RxBufferPolicy.stableWan(
            framesPerPacket: mode.framesPerPacket,
            sampleRateHertz: mode.sampleRateHertz
        )
    }
}

struct MadiFullDuplexTransportModes {
    let local: AudioTransportMode
    let remote: AudioTransportMode
}

func madiFullDuplexTransportModes(
    for configuration: MadiFullDuplexSessionConfiguration
) throws -> MadiFullDuplexTransportModes {
    let local = try configuration.audioPair.localSendMode(
        maxTransmissionUnitBytes: configuration.maxTransmissionUnitBytes,
        maxFragmentsPerDeadline: configuration.maxFragmentsPerDeadline,
        metadataRevision: configuration.metadataRevision
    )
    let remote = try configuration.audioPair.remoteReceiveMode(
        maxTransmissionUnitBytes: configuration.maxTransmissionUnitBytes,
        maxFragmentsPerDeadline: configuration.maxFragmentsPerDeadline,
        metadataRevision: configuration.metadataRevision,
        rxBufferProfile: configuration.rxBufferProfile
    )
    return MadiFullDuplexTransportModes(local: local, remote: remote)
}

/// Carries `sessionID`, `localPeerID`, `remotePeerID`, and `localEndpoint` selected by the caller for a planned MADI full-duplex transport operation.
public struct MadiFullDuplexSourceLevelRequest: Sendable {
    public struct Session: Sendable {
        public var sessionID: String
        public var localPeerID: String
        public var remotePeerID: String
        public var localEndpoint: SessionNetworkEndpoint
        public var remoteEndpoint: SessionNetworkEndpoint

        public init(
            sessionID: String,
            localPeerID: String,
            remotePeerID: String,
            localEndpoint: SessionNetworkEndpoint,
            remoteEndpoint: SessionNetworkEndpoint
        ) {
            self.sessionID = sessionID
            self.localPeerID = localPeerID
            self.remotePeerID = remotePeerID
            self.localEndpoint = localEndpoint
            self.remoteEndpoint = remoteEndpoint
        }
    }

    public struct Devices: Sendable {
        public var inputUID: String
        public var outputUID: String

        public init(inputUID: String, outputUID: String) {
            self.inputUID = inputUID
            self.outputUID = outputUID
        }
    }

    public struct Audio: Sendable {
        public var packetCount: Int
        public var channelCount: Int
        public var sampleRateHertz: Int
        public var framesPerPacket: Int
        public var sampleFormat: UdpPcmSampleFormat

        public init(
            packetCount: Int,
            channelCount: Int,
            sampleRateHertz: Int = 48_000,
            framesPerPacket: Int = 32,
            sampleFormat: UdpPcmSampleFormat = .float32LittleEndian
        ) {
            self.packetCount = packetCount
            self.channelCount = channelCount
            self.sampleRateHertz = sampleRateHertz
            self.framesPerPacket = framesPerPacket
            self.sampleFormat = sampleFormat
        }
    }

    public struct Streams: Sendable {
        public var localID: Int
        public var remoteID: Int

        public init(localID: Int = 1, remoteID: Int = 2) {
            self.localID = localID
            self.remoteID = remoteID
        }
    }

    public struct ReceiverMix: Sendable {
        public var rxBufferProfile: RxBufferProfile
        public var snapshot: ReceiverMixSnapshot?
        public var policy: String

        public init(
            rxBufferProfile: RxBufferProfile = .direct,
            snapshot: ReceiverMixSnapshot? = nil,
            policy: String = "identity-default"
        ) {
            self.rxBufferProfile = rxBufferProfile
            self.snapshot = snapshot
            self.policy = policy
        }
    }
    public var sessionID: String
    public var localPeerID: String
    public var remotePeerID: String
    public var localEndpoint: SessionNetworkEndpoint
    public var remoteEndpoint: SessionNetworkEndpoint
    public var inputDeviceUID: String
    public var outputDeviceUID: String
    public var packetCount: Int
    public var channelCount: Int
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var sampleFormat: UdpPcmSampleFormat
    public var localStreamID: Int
    public var remoteStreamID: Int
    public var rxBufferProfile: RxBufferProfile
    public var receiverMix: ReceiverMixSnapshot?
    public var receiverMixPolicy: String

    public init(
        session: Session,
        devices: Devices,
        audio: Audio,
        streams: Streams = Streams(),
        receiverMix: ReceiverMix = ReceiverMix()
    ) {
        self.sessionID = session.sessionID
        self.localPeerID = session.localPeerID
        self.remotePeerID = session.remotePeerID
        self.localEndpoint = session.localEndpoint
        self.remoteEndpoint = session.remoteEndpoint
        self.inputDeviceUID = devices.inputUID
        self.outputDeviceUID = devices.outputUID
        self.packetCount = audio.packetCount
        self.channelCount = audio.channelCount
        self.sampleRateHertz = audio.sampleRateHertz
        self.framesPerPacket = audio.framesPerPacket
        self.sampleFormat = audio.sampleFormat
        self.localStreamID = streams.localID
        self.remoteStreamID = streams.remoteID
        self.rxBufferProfile = receiverMix.rxBufferProfile
        self.receiverMix = receiverMix.snapshot
        self.receiverMixPolicy = receiverMix.policy
    }
}

/// Binds `sessionID`, `localPeerID`, `remotePeerID`, and `localEndpoint` before MADI full-duplex transport starts, preventing implicit runtime defaults.
public struct MadiFullDuplexSessionConfiguration: Codable, Equatable, Sendable {
    public struct Session: Sendable {
        public let id: String
        public let localPeerID: String
        public let remotePeerID: String
        public let localEndpoint: SessionNetworkEndpoint
        public let remoteEndpoint: SessionNetworkEndpoint

        public init(
            id: String,
            localPeerID: String,
            remotePeerID: String,
            localEndpoint: SessionNetworkEndpoint,
            remoteEndpoint: SessionNetworkEndpoint
        ) {
            self.id = id
            self.localPeerID = localPeerID
            self.remotePeerID = remotePeerID
            self.localEndpoint = localEndpoint
            self.remoteEndpoint = remoteEndpoint
        }
    }

    public struct Devices: Sendable {
        public let inputUID: String
        public let outputUID: String

        public init(inputUID: String, outputUID: String) {
            self.inputUID = inputUID
            self.outputUID = outputUID
        }
    }

    public struct Media: Sendable {
        public let audioPair: MadiFullDuplexAudioPair
        public let packetCount: Int

        public init(audioPair: MadiFullDuplexAudioPair, packetCount: Int) {
            self.audioPair = audioPair
            self.packetCount = packetCount
        }
    }

    public struct Transport: Sendable {
        public let maxTransmissionUnitBytes: Int
        public let maxFragmentsPerDeadline: Int
        public let metadataRevision: Int
        public let preallocatedBlockCount: Int
        public let overrunPolicy: MadiReceiveOverrunPolicy
        public let rxBufferProfile: RxBufferProfile
        public let peerBindTimeoutSeconds: Double

        public init(
            maxTransmissionUnitBytes: Int = 1_200,
            maxFragmentsPerDeadline: Int = 16,
            metadataRevision: Int = 5,
            preallocatedBlockCount: Int = 8,
            overrunPolicy: MadiReceiveOverrunPolicy = .dropNewest,
            rxBufferProfile: RxBufferProfile = .direct,
            peerBindTimeoutSeconds: Double = 1
        ) {
            self.maxTransmissionUnitBytes = maxTransmissionUnitBytes
            self.maxFragmentsPerDeadline = maxFragmentsPerDeadline
            self.metadataRevision = metadataRevision
            self.preallocatedBlockCount = preallocatedBlockCount
            self.overrunPolicy = overrunPolicy
            self.rxBufferProfile = rxBufferProfile
            self.peerBindTimeoutSeconds = peerBindTimeoutSeconds
        }
    }

    public struct Runtime: Sendable {
        public let correctionPolicy: MadiFullDuplexCorrectionPolicy
        public let videoStreamsEnabled: Int
        public let receiverMix: ReceiverMixSnapshot?
        public let receiverMixPolicy: String

        public init(
            correctionPolicy: MadiFullDuplexCorrectionPolicy = MadiFullDuplexCorrectionPolicy(),
            videoStreamsEnabled: Int = 0,
            receiverMix: ReceiverMixSnapshot? = nil,
            receiverMixPolicy: String = "identity-default"
        ) {
            self.correctionPolicy = correctionPolicy
            self.videoStreamsEnabled = videoStreamsEnabled
            self.receiverMix = receiverMix
            self.receiverMixPolicy = receiverMixPolicy
        }
    }

    public var sessionID: String
    public var localPeerID: String
    public var remotePeerID: String
    public var localEndpoint: SessionNetworkEndpoint
    public var remoteEndpoint: SessionNetworkEndpoint
    public var inputDeviceUID: String
    public var outputDeviceUID: String
    public var audioPair: MadiFullDuplexAudioPair
    public var packetCount: Int
    public var maxTransmissionUnitBytes: Int
    public var maxFragmentsPerDeadline: Int
    public var metadataRevision: Int
    public var preallocatedBlockCount: Int
    public var overrunPolicy: MadiReceiveOverrunPolicy
    public var rxBufferProfile: RxBufferProfile
    public var correctionPolicy: MadiFullDuplexCorrectionPolicy
    public var peerBindTimeoutSeconds: Double
    public var videoStreamsEnabled: Int
    public var receiverMix: ReceiverMixSnapshot?
    public var receiverMixPolicy: String

    public init(
        session: Session,
        devices: Devices,
        media: Media,
        transport: Transport = Transport(),
        runtime: Runtime = Runtime()
    ) {
        self.sessionID = session.id
        self.localPeerID = session.localPeerID
        self.remotePeerID = session.remotePeerID
        self.localEndpoint = session.localEndpoint
        self.remoteEndpoint = session.remoteEndpoint
        self.inputDeviceUID = devices.inputUID
        self.outputDeviceUID = devices.outputUID
        self.audioPair = media.audioPair
        self.packetCount = media.packetCount
        self.maxTransmissionUnitBytes = transport.maxTransmissionUnitBytes
        self.maxFragmentsPerDeadline = transport.maxFragmentsPerDeadline
        self.metadataRevision = transport.metadataRevision
        self.preallocatedBlockCount = transport.preallocatedBlockCount
        self.overrunPolicy = transport.overrunPolicy
        self.rxBufferProfile = transport.rxBufferProfile
        self.correctionPolicy = runtime.correctionPolicy
        self.peerBindTimeoutSeconds = transport.peerBindTimeoutSeconds
        self.videoStreamsEnabled = runtime.videoStreamsEnabled
        self.receiverMix = runtime.receiverMix
        self.receiverMixPolicy = runtime.receiverMixPolicy
    }

    public static func synthetic(
        packetCount: Int,
        channelCount: Int
    ) throws -> MadiFullDuplexSessionConfiguration {
        try sourceLevel(MadiFullDuplexSourceLevelRequest(
            session: .init(
                sessionID: "m05-full-duplex-source",
                localPeerID: "local-open-lola",
                remotePeerID: "remote-open-lola",
                localEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 41_001),
                remoteEndpoint: SessionNetworkEndpoint(host: "127.0.0.1", port: 41_101)
            ),
            devices: .init(inputUID: "synthetic-rme-madi", outputUID: "synthetic-rme-madi"),
            audio: .init(packetCount: packetCount, channelCount: channelCount)
        ))
    }

    public static func sourceLevel(
        _ request: MadiFullDuplexSourceLevelRequest
    ) throws -> MadiFullDuplexSessionConfiguration {
        let pair = try MadiFullDuplexAudioPair(
            localToRemote: audioStream(
                id: request.localStreamID,
                channelCount: request.channelCount,
                sampleRateHertz: request.sampleRateHertz,
                framesPerPacket: request.framesPerPacket,
                sampleFormat: request.sampleFormat
            ),
            remoteToLocal: audioStream(
                id: request.remoteStreamID,
                channelCount: request.channelCount,
                sampleRateHertz: request.sampleRateHertz,
                framesPerPacket: request.framesPerPacket,
                sampleFormat: request.sampleFormat
            )
        )
        return MadiFullDuplexSessionConfiguration(
            session: Session(
                id: request.sessionID,
                localPeerID: request.localPeerID,
                remotePeerID: request.remotePeerID,
                localEndpoint: request.localEndpoint,
                remoteEndpoint: request.remoteEndpoint
            ),
            devices: Devices(inputUID: request.inputDeviceUID, outputUID: request.outputDeviceUID),
            media: Media(audioPair: pair, packetCount: request.packetCount),
            transport: Transport(rxBufferProfile: request.rxBufferProfile),
            runtime: Runtime(
                receiverMix: request.receiverMix,
                receiverMixPolicy: request.receiverMixPolicy
            )
        )
    }

    public static func fromSessionConfiguration(
        _ session: SessionConfiguration,
        localPeerID: String,
        remotePeerID: String,
        inputDeviceUID: String,
        outputDeviceUID: String
    ) throws -> MadiFullDuplexSessionConfiguration {
        guard session.videoStreams.filter(\.isEnabled).isEmpty else {
            throw MadiFullDuplexError.enabledVideoNotAllowed
        }
        guard let audio = session.audioStreams.first(where: { $0.direction == .bidirectional }) else {
            throw MadiFullDuplexError.noBidirectionalAudioStream
        }
        let pair = try MadiFullDuplexAudioPair(localToRemote: audio, remoteToLocal: audio)
        return MadiFullDuplexSessionConfiguration(
            session: Session(
                id: session.sessionID,
                localPeerID: localPeerID,
                remotePeerID: remotePeerID,
                localEndpoint: SessionNetworkEndpoint(host: "0.0.0.0", port: session.audioEndpoint.port),
                remoteEndpoint: session.audioEndpoint
            ),
            devices: Devices(inputUID: inputDeviceUID, outputUID: outputDeviceUID),
            media: Media(audioPair: pair, packetCount: 1),
            transport: Transport(
                maxTransmissionUnitBytes: session.mtuBytes,
                rxBufferProfile: session.rxBufferProfile
            )
        )
    }

    public func validate() throws {
        try MadiFullDuplexValidator.requireNonEmpty(sessionID, "sessionID")
        try MadiFullDuplexValidator.requireNonEmpty(localPeerID, "localPeerID")
        try MadiFullDuplexValidator.requireNonEmpty(remotePeerID, "remotePeerID")
        try MadiFullDuplexValidator.requireNonEmpty(inputDeviceUID, "inputDeviceUID")
        try MadiFullDuplexValidator.requireNonEmpty(outputDeviceUID, "outputDeviceUID")
        try localEndpoint.validate(fieldPrefix: "localEndpoint")
        try remoteEndpoint.validate(fieldPrefix: "remoteEndpoint")
        try audioPair.validate()
        try MadiFullDuplexValidator.requirePositive(packetCount, "packetCount")
        try MadiFullDuplexValidator.requirePositive(maxTransmissionUnitBytes, "maxTransmissionUnitBytes")
        try MadiFullDuplexValidator.requirePositive(maxFragmentsPerDeadline, "maxFragmentsPerDeadline")
        try MadiFullDuplexValidator.requirePositive(metadataRevision, "metadataRevision")
        try MadiFullDuplexValidator.requirePositive(preallocatedBlockCount, "preallocatedBlockCount")
        try MadiFullDuplexValidator.requireNonNegative(peerBindTimeoutSeconds, "peerBindTimeoutSeconds")
        try MadiFullDuplexValidator.requireNonNegative(videoStreamsEnabled, "videoStreamsEnabled")
        try MadiFullDuplexValidator.requireNonEmpty(receiverMixPolicy, "receiverMixPolicy")
        guard videoStreamsEnabled == 0 else {
            throw MadiFullDuplexError.enabledVideoNotAllowed
        }
        try correctionPolicy.validate()
    }

    private static func audioStream(
        id: Int,
        channelCount: Int,
        sampleRateHertz: Int,
        framesPerPacket: Int,
        sampleFormat: UdpPcmSampleFormat
    ) -> AudioStreamDescription {
        AudioStreamDescription(
            identity: .init(id: id, direction: .bidirectional, clockDomain: "core-audio-device:madi-full-duplex"),
            format: .init(sampleRateHertz: sampleRateHertz, sampleFormat: sampleFormat, channelCount: channelCount, channelOrder: AudioChannelSet.defaultInput(count: channelCount).sortedByStableSourceIndex),
            packet: .init(framesPerPacket: framesPerPacket, payloadType: .audioPcmV2)
        )
    }
}
