import Darwin
import Foundation

public enum UltraGridCompatibilityError: Error, Equatable, Sendable {
    case unsupportedPayloadType(UInt8)
    case unsupportedMode(String)
    case truncatedPayload(byteCount: Int)
    case invalidFragment(index: UInt16, count: UInt16)
    case invalidPayloadLength(expected: Int, actual: Int)
    case invalidField(String, Int)
    case reassemblyIncomplete(missing: [UInt16])
    case receiveTimeout(expected: Int, actual: Int)
}

private let ultraGridRGB24FourCC = UltraGridFourCC(rawValue: 0x5247_4233)
private let ultraGridRGBAFourCC = UltraGridFourCC(rawValue: 0x5247_4241)

private func ultraGridRawVideoFourCC(bitsPerPixel: Int) throws -> UltraGridFourCC {
    switch bitsPerPixel {
    case 8, 24:
        return ultraGridRGB24FourCC
    case 32:
        return ultraGridRGBAFourCC
    default:
        throw UltraGridCompatibilityError.unsupportedMode("raw-video-\(bitsPerPixel)bpp")
    }
}

public struct UltraGridCompatibilityDatagram: Codable, Equatable, Sendable {
    public var stream: LoLaCompatibilityMediaStream
    public var sourceHost: String?
    public var sourcePort: UInt16?
    public var destinationPort: UInt16
    public var rtp: RTPPacket

    public init(
        stream: LoLaCompatibilityMediaStream,
        sourceHost: String? = nil,
        sourcePort: UInt16? = nil,
        destinationPort: UInt16,
        rtp: RTPPacket
    ) {
        self.stream = stream
        self.sourceHost = sourceHost
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.rtp = rtp
    }
}

public struct UltraGridVideoFragmentRequest: Equatable, Sendable {
    public var framePayload: Data
    public var frameID: UInt32
    public var sequenceStart: UInt16
    public var timestamp: UInt32
    public var ssrc: UInt32
    public var width: Int
    public var height: Int
    public var frameRate: Int
    public var bitsPerPixel: Int
    public var payloadType: UInt8
    public var maxPayloadBytes: Int

    public init(
        framePayload: Data,
        frameID: UInt32,
        sequenceStart: UInt16,
        timestamp: UInt32,
        ssrc: UInt32,
        width: Int,
        height: Int,
        frameRate: Int,
        bitsPerPixel: Int,
        payloadType: UInt8 = UltraGridCompatibility.videoPayloadType,
        maxPayloadBytes: Int = 1_200
    ) {
        self.framePayload = framePayload
        self.frameID = frameID
        self.sequenceStart = sequenceStart
        self.timestamp = timestamp
        self.ssrc = ssrc
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.bitsPerPixel = bitsPerPixel
        self.payloadType = payloadType
        self.maxPayloadBytes = maxPayloadBytes
    }
}

public struct UltraGridAudioPacketRequest: Equatable, Sendable {
    public var sequenceNumber: UInt16
    public var timestamp: UInt32
    public var ssrc: UInt32
    public var channels: Int
    public var sampleRateHertz: Int
    public var framesPerPacket: Int
    public var pcmPayload: Data
    public var payloadType: UInt8

    public init(
        sequenceNumber: UInt16,
        timestamp: UInt32,
        ssrc: UInt32,
        channels: Int,
        sampleRateHertz: Int,
        framesPerPacket: Int,
        pcmPayload: Data,
        payloadType: UInt8 = UltraGridCompatibility.audioPayloadType
    ) {
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.ssrc = ssrc
        self.channels = channels
        self.sampleRateHertz = sampleRateHertz
        self.framesPerPacket = framesPerPacket
        self.pcmPayload = pcmPayload
        self.payloadType = payloadType
    }
}

public enum UltraGridTopologyState: String, Codable, Equatable, Sendable {
    case directPeerReady = "direct-peer-ready"
    case serverListening = "server-listening"
    case clientReady = "client-ready"
}

public struct UltraGridTopologyReport: Codable, Equatable, Sendable {
    public var mode: UltraGridTopologyMode
    public var role: UltraGridTopologyRole
    public var state: UltraGridTopologyState
    public var peerRequired: Bool
    public var peerConfigured: Bool
    public var localHost: String
    public var peer: String
    public var notes: String

    public init(
        mode: UltraGridTopologyMode,
        role: UltraGridTopologyRole,
        state: UltraGridTopologyState,
        peerRequired: Bool,
        peerConfigured: Bool,
        localHost: String,
        peer: String,
        notes: String
    ) {
        self.mode = mode
        self.role = role
        self.state = state
        self.peerRequired = peerRequired
        self.peerConfigured = peerConfigured
        self.localHost = localHost
        self.peer = peer
        self.notes = notes
    }

    public func validate(fieldPrefix: String) throws {
        try requireExternalConnectorSessionNonEmpty(localHost, "\(fieldPrefix).localHost")
        try requireExternalConnectorSessionNonEmpty(notes, "\(fieldPrefix).notes")
        if peerRequired {
            try requireExternalConnectorSessionNonEmpty(peer, "\(fieldPrefix).peer")
        }
        if mode == .directPeer, role != .direct {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("ultragrid-topology-role-\(role.rawValue)")
        }
        if mode == .serverClient, role == .direct {
            throw ExternalConnectorSessionError.unsupportedRuntimeMode("ultragrid-topology-role-direct")
        }
    }
}

public struct UltraGridCompatibilityMediaReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var capturedAt: String
    public var role: ExternalConnectorSessionRole
    public var mediaMode: ExternalConnectorMediaMode
    public var datagrams: [UltraGridCompatibilityDatagram]
    public var audioDatagramCount: Int
    public var videoDatagramCount: Int
    public var audioPayloadByteCount: Int
    public var videoFramePayloadByteCount: Int
    public var rtpPayloadByteCount: Int
    public var transmittedDatagramCount: Int
    public var receivedDatagramCount: Int
    public var rtpPacketsLost: Int
    public var rtpDuplicatePacketCount: Int
    public var rtpOutOfOrderPacketCount: Int
    public var rtpSsrcChangeCount: Int
    public var rtpTimestampRegressionCount: Int
    public var rtpJitterLikeArrivalDeltaCount: Int
    public var videoFrameReassemblyFailureCount: Int
    public var unsupportedModes: [String]
    public var topology: UltraGridTopologyReport
    public var control: UltraGridControlReport
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
        mediaMode: ExternalConnectorMediaMode,
        datagrams: [UltraGridCompatibilityDatagram],
        transmittedDatagramCount: Int,
        receivedDatagramCount: Int,
        rtpPacketsLost: Int = 0,
        rtpDuplicatePacketCount: Int = 0,
        rtpOutOfOrderPacketCount: Int = 0,
        rtpSsrcChangeCount: Int = 0,
        rtpTimestampRegressionCount: Int = 0,
        rtpJitterLikeArrivalDeltaCount: Int = 0,
        videoFrameReassemblyFailureCount: Int = 0,
        unsupportedModes: [String] = UltraGridCompatibility.unsupportedModes,
        topology: UltraGridTopologyReport = UltraGridTopologyReport(
            mode: .directPeer,
            role: .direct,
            state: .directPeerReady,
            peerRequired: false,
            peerConfigured: false,
            localHost: "0.0.0.0",
            peer: "",
            notes: "Direct peer UltraGrid topology."
        ),
        control: UltraGridControlReport = UltraGridControlReport(
            mode: .disabled,
            port: 5054,
            state: .disabled,
            commands: [],
            notes: "UltraGrid control socket modeling is disabled for this run."
        ),
        provider: ExternalConnectorMediaProviderReport = ExternalConnectorMediaProviderReport(
            audioSource: "synthetic",
            videoSource: "synthetic",
            observedEvidenceClasses: [.synthetic],
            notes: "Synthetic UltraGrid media provider."
        ),
        sink: ExternalConnectorMediaSinkReport = ExternalConnectorMediaSinkReport(
            notes: "No UltraGrid RX sink media was decoded for this role."
        ),
        observedEvidenceClasses: [ExternalConnectorEvidenceClass] = [.synthetic],
        missingEvidenceClassesForPass: [ExternalConnectorEvidenceClass] =
            ExternalConnectorEvidenceClass.runtimePassRequiredEvidence,
        realLinkTransmitted: Bool,
        verdict: MeasurementVerdict,
        runtimeError: String? = nil,
        runtimeErrorFree: Bool? = nil,
        evidenceBoundary: String = UltraGridCompatibility.evidenceBoundary,
        notes: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.role = role
        self.mediaMode = mediaMode
        self.datagrams = datagrams
        self.audioDatagramCount = datagrams.filter { $0.stream == .audio }.count
        self.videoDatagramCount = datagrams.filter { $0.stream == .video }.count
        self.audioPayloadByteCount = Self.audioPayloadByteCount(datagrams)
        self.videoFramePayloadByteCount = Self.videoFramePayloadByteCount(datagrams)
        self.rtpPayloadByteCount = datagrams.reduce(0) { $0 + $1.rtp.payload.count }
        self.transmittedDatagramCount = transmittedDatagramCount
        self.receivedDatagramCount = receivedDatagramCount
        self.rtpPacketsLost = rtpPacketsLost
        self.rtpDuplicatePacketCount = rtpDuplicatePacketCount
        self.rtpOutOfOrderPacketCount = rtpOutOfOrderPacketCount
        self.rtpSsrcChangeCount = rtpSsrcChangeCount
        self.rtpTimestampRegressionCount = rtpTimestampRegressionCount
        self.rtpJitterLikeArrivalDeltaCount = rtpJitterLikeArrivalDeltaCount
        self.videoFrameReassemblyFailureCount = videoFrameReassemblyFailureCount
        self.unsupportedModes = unsupportedModes
        self.topology = topology
        self.control = control
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
        try requireExternalConnectorSessionNonEmpty(id, "ultraGridMedia.id")
        try requireExternalConnectorSessionNonEmpty(capturedAt, "ultraGridMedia.capturedAt")
        try topology.validate(fieldPrefix: "ultraGridMedia.topology")
        try control.validate(fieldPrefix: "ultraGridMedia.control")
        try provider.validate(fieldPrefix: "ultraGridMedia.provider")
        try sink.validate(fieldPrefix: "ultraGridMedia.sink")
        try requireExternalConnectorSessionNonEmptyEvidenceClasses(
            observedEvidenceClasses,
            "ultraGridMedia.observedEvidenceClasses"
        )
        try requireExternalConnectorSessionNonEmpty(evidenceBoundary, "ultraGridMedia.evidenceBoundary")
        try requireExternalConnectorSessionNonEmpty(notes, "ultraGridMedia.notes")
        if verdict == .pass {
            try validatePassEvidence()
        } else {
            try requireExternalConnectorSessionNonEmptyEvidenceClasses(
                missingEvidenceClassesForPass,
                "ultraGridMedia.missingEvidenceClassesForPass"
            )
        }
        if verdict == .fail {
            try requireExternalConnectorSessionNonEmpty(runtimeError ?? "", "ultraGridMedia.runtimeError")
        }
        guard audioDatagramCount == datagrams.filter({ $0.stream == .audio }).count else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("ultraGridMedia.audioDatagramCount", String(audioDatagramCount))
        }
        guard videoDatagramCount == datagrams.filter({ $0.stream == .video }).count else {
            throw ExternalConnectorSessionError.invalidPositiveInteger("ultraGridMedia.videoDatagramCount", String(videoDatagramCount))
        }
        for (field, value) in [
            ("ultraGridMedia.audioPayloadByteCount", audioPayloadByteCount),
            ("ultraGridMedia.videoFramePayloadByteCount", videoFramePayloadByteCount),
            ("ultraGridMedia.rtpPayloadByteCount", rtpPayloadByteCount),
            ("ultraGridMedia.rtpPacketsLost", rtpPacketsLost),
            ("ultraGridMedia.rtpDuplicatePacketCount", rtpDuplicatePacketCount),
            ("ultraGridMedia.rtpOutOfOrderPacketCount", rtpOutOfOrderPacketCount),
            ("ultraGridMedia.rtpSsrcChangeCount", rtpSsrcChangeCount),
            ("ultraGridMedia.rtpTimestampRegressionCount", rtpTimestampRegressionCount),
            ("ultraGridMedia.rtpJitterLikeArrivalDeltaCount", rtpJitterLikeArrivalDeltaCount),
            ("ultraGridMedia.videoFrameReassemblyFailureCount", videoFrameReassemblyFailureCount),
        ] {
            guard value >= 0 else {
                throw ExternalConnectorSessionError.invalidPositiveInteger(field, String(value))
            }
        }
    }

    private static func audioPayloadByteCount(_ datagrams: [UltraGridCompatibilityDatagram]) -> Int {
        datagrams.reduce(0) { total, datagram in
            guard datagram.stream == .audio,
                  let audio = try? UltraGridAudioPayload.decode(datagram.rtp.payload) else {
                return total
            }
            return total + audio.pcmPayload.count
        }
    }

    private static func videoFramePayloadByteCount(_ datagrams: [UltraGridCompatibilityDatagram]) -> Int {
        let fragments = datagrams.compactMap { datagram -> UltraGridVideoRawFragmentPayload? in
            guard datagram.stream == .video else {
                return nil
            }
            return try? UltraGridVideoRawFragmentPayload.decode(datagram.rtp.payload)
        }
        let byFrame = Dictionary(grouping: fragments, by: \.frameID)
        return byFrame.values.reduce(0) { total, frameFragments in
            total + Int(frameFragments.first?.framePayloadByteCount ?? 0)
        }
    }
}

public extension UltraGridCompatibilityMediaReport {
    var runtimeEvidenceState: ExternalConnectorRuntimeEvidenceState {
        externalConnectorRuntimeEvidenceState(
            verdict: verdict,
            runtimeError: runtimeError,
            runtimeErrorFree: runtimeErrorFree
        )
    }
}

public enum UltraGridCompatibility {
    public static let audioPayloadType = UltraGridCompatibilityPayloadType.audio.rawValue
    public static let videoPayloadType = UltraGridCompatibilityPayloadType.video.rawValue
    public static let encryptedVideoPayloadType: UInt8 = 24
    public static let encryptedAudioPayloadType: UInt8 = 25
    public static let fecPayloadType: UInt8 = 22
    public static let jpegPayloadType: UInt8 = 26
    public static let videoClockRateHertz = 90_000
    public static let evidenceBoundary = "Swift-native clean-room RTP/MVTP packetization from public UltraGrid packet type and RTP payload references. Real UltraGrid interoperability remains PARTIAL until measured peer capture evidence exists."
    public static let unsupportedModes: [String] = []

    public static func audioPacket(_ request: UltraGridAudioPacketRequest) throws -> RTPPacket {
        try validateUltraGridPositive(request.channels, "audio.channels")
        try validateUltraGridPositive(request.framesPerPacket, "audio.framesPerPacket")
        let payload = try UltraGridAudioPayload(
            header: UltraGridAudioPayloadHeader(
                substreamID: try uint16(request.channels, "audio.channels"),
                bufferNumber: UInt32(request.sequenceNumber),
                payloadOffset: 0,
                payloadByteCount: UInt32(request.pcmPayload.count),
                quantizationBits: 16,
                sampleRateHertz: try uint32(request.sampleRateHertz, "audio.sampleRateHertz")
            ),
            pcmPayload: request.pcmPayload
        ).encoded()
        return RTPPacket(
            header: RTPPacketHeader(
                payloadType: request.payloadType,
                marker: false,
                sequenceNumber: request.sequenceNumber,
                timestamp: request.timestamp,
                ssrc: request.ssrc
            ),
            payload: payload
        )
    }

    public static func videoFragments(_ request: UltraGridVideoFragmentRequest) throws -> [RTPPacket] {
        try validateUltraGridPositive(request.maxPayloadBytes, "video.maxPayloadBytes")
        guard !request.framePayload.isEmpty else {
            throw UltraGridCompatibilityError.invalidField("video.framePayload", 0)
        }
        let headerBytes = UltraGridVideoRawFragmentPayload.headerByteCount
        guard request.maxPayloadBytes > headerBytes else {
            throw UltraGridCompatibilityError.invalidField("video.maxPayloadBytes", request.maxPayloadBytes)
        }
        let chunkSize = request.maxPayloadBytes - headerBytes
        let fragmentCount = UInt16((request.framePayload.count + chunkSize - 1) / chunkSize)
        var packets: [RTPPacket] = []
        for fragmentIndex in 0..<fragmentCount {
            let offset = Int(fragmentIndex) * chunkSize
            let end = min(request.framePayload.count, offset + chunkSize)
            let payload = try UltraGridVideoRawFragmentPayload(
                header: UltraGridVideoPayloadHeader(
                    bufferNumber: request.frameID,
                    payloadOffset: UInt32(offset),
                    payloadByteCount: UInt32(request.framePayload.count),
                    width: try uint16(request.width, "video.width"),
                    height: try uint16(request.height, "video.height"),
                    fourCC: try ultraGridRawVideoFourCC(bitsPerPixel: request.bitsPerPixel),
                    frameRateNumerator: try uint16(request.frameRate, "video.frameRate")
                ),
                fragmentPayload: Data(request.framePayload[offset..<end])
            ).encoded()
            packets.append(RTPPacket(
                header: RTPPacketHeader(
                    payloadType: request.payloadType,
                    marker: fragmentIndex == fragmentCount - 1,
                    sequenceNumber: request.sequenceStart &+ fragmentIndex,
                    timestamp: request.timestamp,
                    ssrc: request.ssrc
                ),
                payload: payload
            ))
        }
        return packets
    }

    public static func decode(
        _ packet: RTPPacket,
        registry: UltraGridRTPPayloadRegistry = .default,
        encryptionConfiguration: UltraGridEncryptionConfiguration? = nil
    ) throws -> UltraGridCompatibilityDatagram {
        try UltraGridRTPPacketCodec.decode(
            packet,
            registry: registry,
            encryptionConfiguration: encryptionConfiguration
        )
    }

    public static func encryptedAudioPacket(
        _ packet: RTPPacket,
        configuration: UltraGridEncryptionConfiguration,
        iv: Data? = nil
    ) throws -> RTPPacket {
        try encryptedPacket(
            packet,
            encryptedPayloadType: encryptedAudioPayloadType,
            mediaHeaderByteCount: UltraGridAudioPayloadHeader.byteCount,
            configuration: configuration,
            iv: iv
        )
    }

    public static func encryptedVideoPacket(
        _ packet: RTPPacket,
        configuration: UltraGridEncryptionConfiguration,
        iv: Data? = nil
    ) throws -> RTPPacket {
        try encryptedPacket(
            packet,
            encryptedPayloadType: encryptedVideoPayloadType,
            mediaHeaderByteCount: UltraGridVideoPayloadHeader.byteCount,
            configuration: configuration,
            iv: iv
        )
    }

    private static func encryptedPacket(
        _ packet: RTPPacket,
        encryptedPayloadType: UInt8,
        mediaHeaderByteCount: Int,
        configuration: UltraGridEncryptionConfiguration,
        iv: Data?
    ) throws -> RTPPacket {
        guard packet.payload.count >= mediaHeaderByteCount else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: packet.payload.count)
        }
        let mediaHeader = packet.payload[..<mediaHeaderByteCount]
        let plaintext = packet.payload[mediaHeaderByteCount..<packet.payload.count]
        let ciphertext = try UltraGridOpenSSLEncryption.encrypt(
            plaintext: plaintext,
            aad: mediaHeader,
            configuration: configuration,
            iv: iv
        )
        var payload = Data(mediaHeader)
        payload.append(UltraGridCryptoPayloadHeader().encoded())
        payload.append(ciphertext)
        return RTPPacket(
            header: RTPPacketHeader(
                payloadType: encryptedPayloadType,
                marker: packet.header.marker,
                sequenceNumber: packet.header.sequenceNumber,
                timestamp: packet.header.timestamp,
                ssrc: packet.header.ssrc
            ),
            payload: payload
        )
    }

    public static func fecParityPacket(
        protecting packets: [RTPPacket],
        sequenceNumber: UInt16,
        timestamp: UInt32,
        ssrc: UInt32
    ) throws -> RTPPacket {
        try UltraGridFECRecovery.parityPacket(
            protecting: packets,
            sequenceNumber: sequenceNumber,
            timestamp: timestamp,
            ssrc: ssrc
        )
    }

    public static func recoverVideoFragments(from packets: [RTPPacket]) throws -> [UltraGridVideoRawFragmentPayload] {
        try UltraGridFECRecovery.recoverVideoFragments(from: packets)
    }

    public static func reassembleVideoFrame(_ fragments: [UltraGridVideoRawFragmentPayload]) throws -> Data {
        guard let first = fragments.first else {
            throw UltraGridCompatibilityError.reassemblyIncomplete(missing: [0])
        }
        let frameByteCount = Int(first.framePayloadByteCount)
        var byOffset: [Int: UltraGridVideoRawFragmentPayload] = [:]
        for fragment in fragments {
            guard fragment.frameID == first.frameID,
                  fragment.framePayloadByteCount == first.framePayloadByteCount else {
                throw UltraGridCompatibilityError.unsupportedMode("mixed-video-fragments")
            }
            byOffset[Int(fragment.payloadOffset)] = fragment
        }
        var output = Data(count: frameByteCount)
        var cursor = 0
        for start in byOffset.keys.sorted() {
            guard start == cursor, let fragment = byOffset[start] else {
                throw UltraGridCompatibilityError.reassemblyIncomplete(missing: [UInt16(clamping: cursor)])
            }
            output.replaceSubrange(start..<start + fragment.fragmentPayload.count, with: fragment.fragmentPayload)
            cursor += fragment.fragmentPayload.count
        }
        guard cursor == frameByteCount else {
            throw UltraGridCompatibilityError.reassemblyIncomplete(missing: [UInt16(clamping: cursor)])
        }
        return output
    }
}
