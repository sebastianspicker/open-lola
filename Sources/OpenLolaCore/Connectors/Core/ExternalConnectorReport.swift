import Foundation

public enum ExternalConnectorKind: String, CaseIterable, Codable, Equatable, Sendable {
    case lola
    case mvtpUltraGrid
    case jackTrip
}

public enum ExternalConnectorHandshakeKind: String, Codable, Equatable, Sendable {
    case descriptorOnly
    case externalProcessDescriptor
    case controlOnlyTxRx
    case protocolAwareTxRx
}

public enum ExternalConnectorEvidenceClass: String, CaseIterable, Codable, Equatable, Sendable {
    case synthetic
    case localLoopback = "local-loopback"
    case referencePeer = "reference-peer"
    case liveDevice = "live-device"
    case fieldRoute = "field-route"
    case packetCapture = "packet-capture"
    case timing
    case teardown
    case mediaQuality = "media-quality"
}

public extension ExternalConnectorEvidenceClass {
    static let runtimePassRequiredEvidence: [ExternalConnectorEvidenceClass] = [
        .referencePeer,
        .liveDevice,
        .fieldRoute,
        .packetCapture,
        .timing,
        .teardown,
        .mediaQuality,
    ]

    static func missingRuntimePassEvidence(
        observed: [ExternalConnectorEvidenceClass]
    ) -> [ExternalConnectorEvidenceClass] {
        runtimePassRequiredEvidence.filter { !observed.contains($0) }
    }
}

public struct ExternalConnectorMediaProviderReport: Codable, Equatable, Sendable {
    public var audioSource: String
    public var videoSource: String
    public var observedEvidenceClasses: [ExternalConnectorEvidenceClass]
    public var notes: String

    public init(
        audioSource: String,
        videoSource: String,
        observedEvidenceClasses: [ExternalConnectorEvidenceClass],
        notes: String
    ) {
        self.audioSource = audioSource
        self.videoSource = videoSource
        self.observedEvidenceClasses = observedEvidenceClasses
        self.notes = notes
    }

    public func validate(fieldPrefix: String) throws {
        try requireExternalConnectorSessionNonEmpty(audioSource, "\(fieldPrefix).audioSource")
        try requireExternalConnectorSessionNonEmpty(videoSource, "\(fieldPrefix).videoSource")
        try requireExternalConnectorSessionNonEmptyEvidenceClasses(
            observedEvidenceClasses,
            "\(fieldPrefix).observedEvidenceClasses"
        )
        try requireExternalConnectorSessionNonEmpty(notes, "\(fieldPrefix).notes")
    }
}

public struct ExternalConnectorMediaSinkReport: Codable, Equatable, Sendable {
    public var audioPacketCount: Int
    public var audioPayloadByteCount: Int
    public var videoFrameCount: Int
    public var videoPayloadByteCount: Int
    public var rejectedMediaCount: Int
    public var notes: String

    public init(
        audioPacketCount: Int = 0,
        audioPayloadByteCount: Int = 0,
        videoFrameCount: Int = 0,
        videoPayloadByteCount: Int = 0,
        rejectedMediaCount: Int = 0,
        notes: String
    ) {
        self.audioPacketCount = audioPacketCount
        self.audioPayloadByteCount = audioPayloadByteCount
        self.videoFrameCount = videoFrameCount
        self.videoPayloadByteCount = videoPayloadByteCount
        self.rejectedMediaCount = rejectedMediaCount
        self.notes = notes
    }

    public func validate(fieldPrefix: String) throws {
        for (field, value) in [
            ("audioPacketCount", audioPacketCount),
            ("audioPayloadByteCount", audioPayloadByteCount),
            ("videoFrameCount", videoFrameCount),
            ("videoPayloadByteCount", videoPayloadByteCount),
            ("rejectedMediaCount", rejectedMediaCount),
        ] {
            guard value >= 0 else {
                throw ExternalConnectorSessionError.invalidPositiveInteger(
                    "\(fieldPrefix).\(field)",
                    String(value)
                )
            }
        }
        try requireExternalConnectorSessionNonEmpty(notes, "\(fieldPrefix).notes")
    }
}

public struct ExternalConnectorContract: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var connector: ExternalConnectorKind
    public var supportedHandshake: ExternalConnectorHandshakeKind
    public var sourceContractImplemented: Bool
    public var realWorldInteroperabilityClaimed: Bool
    public var preservesDefaultAudioFirstPath: Bool
    public var defaultEnabled: Bool
    public var externalImplementationRequired: Bool
    public var publicReference: String
    public var cleanRoomBoundary: String
    public var requiredEvidenceForRealWorldPass: [String]
    public var notes: String

    public init(
        id: String,
        title: String,
        connector: ExternalConnectorKind,
        supportedHandshake: ExternalConnectorHandshakeKind,
        sourceContractImplemented: Bool,
        realWorldInteroperabilityClaimed: Bool,
        preservesDefaultAudioFirstPath: Bool,
        defaultEnabled: Bool,
        externalImplementationRequired: Bool,
        publicReference: String,
        cleanRoomBoundary: String,
        requiredEvidenceForRealWorldPass: [String],
        notes: String
    ) {
        self.id = id
        self.title = title
        self.connector = connector
        self.supportedHandshake = supportedHandshake
        self.sourceContractImplemented = sourceContractImplemented
        self.realWorldInteroperabilityClaimed = realWorldInteroperabilityClaimed
        self.preservesDefaultAudioFirstPath = preservesDefaultAudioFirstPath
        self.defaultEnabled = defaultEnabled
        self.externalImplementationRequired = externalImplementationRequired
        self.publicReference = publicReference
        self.cleanRoomBoundary = cleanRoomBoundary
        self.requiredEvidenceForRealWorldPass = requiredEvidenceForRealWorldPass
        self.notes = notes
    }
}

public enum ExternalConnectorValidationError: Error, Equatable, Sendable {
    case emptyField(String)
    case emptyList(String)
    case duplicateConnector(String)
    case missingConnector(String)
    case sourcePassWithoutImplementedContract(String)
    case realWorldPassNotAllowed
    case realWorldClaimWithoutEvidence(String)
    case audioFirstPathRisk(String)
    case defaultEnabled(String)
}

public struct ExternalConnectorReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var connectors: [ExternalConnectorContract]
    public var sourceLevelVerdict: MeasurementVerdict
    public var realWorldVerdict: MeasurementVerdict
    public var verdict: MeasurementVerdict
    public var observedEvidenceClasses: [ExternalConnectorEvidenceClass]
    public var missingEvidenceClassesForRealWorldPass: [ExternalConnectorEvidenceClass]
    public var assumptions: [String]
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        connectors: [ExternalConnectorContract],
        sourceLevelVerdict: MeasurementVerdict,
        realWorldVerdict: MeasurementVerdict,
        verdict: MeasurementVerdict,
        observedEvidenceClasses: [ExternalConnectorEvidenceClass],
        missingEvidenceClassesForRealWorldPass: [ExternalConnectorEvidenceClass],
        assumptions: [String],
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.connectors = connectors
        self.sourceLevelVerdict = sourceLevelVerdict
        self.realWorldVerdict = realWorldVerdict
        self.verdict = verdict
        self.observedEvidenceClasses = observedEvidenceClasses
        self.missingEvidenceClassesForRealWorldPass = missingEvidenceClassesForRealWorldPass
        self.assumptions = assumptions
        self.notes = notes
    }

    public func validate() throws {
        try requireExternalConnectorNonEmpty(id, "id")
        try requireExternalConnectorNonEmpty(title, "title")
        try requireExternalConnectorNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorNonEmpty(notes, "notes")
        try requireExternalConnectorNonEmptyList(assumptions, "assumptions")
        try requireExternalConnectorNonEmptyEvidenceClasses(observedEvidenceClasses, "observedEvidenceClasses")
        try validateConnectors()

        if realWorldVerdict == .pass {
            throw ExternalConnectorValidationError.realWorldPassNotAllowed
        }
        if realWorldVerdict != .pass {
            try requireExternalConnectorNonEmptyEvidenceClasses(
                missingEvidenceClassesForRealWorldPass,
                "missingEvidenceClassesForRealWorldPass"
            )
        }
        if sourceLevelVerdict == .pass {
            guard connectors.allSatisfy(\.sourceContractImplemented) else {
                throw ExternalConnectorValidationError.sourcePassWithoutImplementedContract("connectors")
            }
        }
        if verdict == .pass {
            guard sourceLevelVerdict == .pass else {
                throw ExternalConnectorValidationError.sourcePassWithoutImplementedContract("report")
            }
            guard realWorldVerdict == .pass else {
                throw ExternalConnectorValidationError.realWorldPassNotAllowed
            }
        }
    }

    private func validateConnectors() throws {
        guard !connectors.isEmpty else {
            throw ExternalConnectorValidationError.emptyList("connectors")
        }

        var seen = Set<ExternalConnectorKind>()
        for connector in connectors {
            try validate(connector)
            guard seen.insert(connector.connector).inserted else {
                throw ExternalConnectorValidationError.duplicateConnector(connector.connector.rawValue)
            }
        }
        for requiredConnector in ExternalConnectorKind.allCases where !seen.contains(requiredConnector) {
            throw ExternalConnectorValidationError.missingConnector(requiredConnector.rawValue)
        }
    }

    private func validate(_ connector: ExternalConnectorContract) throws {
        try requireExternalConnectorNonEmpty(connector.id, "connectors.id")
        try requireExternalConnectorNonEmpty(connector.title, "connectors.title")
        try requireExternalConnectorNonEmpty(connector.publicReference, "connectors.publicReference")
        try requireExternalConnectorNonEmpty(connector.cleanRoomBoundary, "connectors.cleanRoomBoundary")
        try requireExternalConnectorNonEmpty(connector.notes, "connectors.notes")
        try requireExternalConnectorNonEmptyList(
            connector.requiredEvidenceForRealWorldPass,
            "connectors.requiredEvidenceForRealWorldPass"
        )
        guard connector.preservesDefaultAudioFirstPath else {
            throw ExternalConnectorValidationError.audioFirstPathRisk(connector.connector.rawValue)
        }
        guard !connector.defaultEnabled else {
            throw ExternalConnectorValidationError.defaultEnabled(connector.connector.rawValue)
        }
        guard !connector.realWorldInteroperabilityClaimed else {
            throw ExternalConnectorValidationError.realWorldClaimWithoutEvidence(connector.connector.rawValue)
        }
    }
}

public enum ExternalConnectorSyntheticSmoke {
    public static func run() -> ExternalConnectorReport {
        ExternalConnectorReport(
            id: "external-connectors-source-contracts",
            title: "External connector source contracts",
            capturedAt: "2026-05-05T00:00:00Z",
            connectors: [
                lolaConnector(),
                mvtpUltraGridConnector(),
                jackTripConnector(),
            ],
            sourceLevelVerdict: .pass,
            realWorldVerdict: .partial,
            verdict: .partial,
            observedEvidenceClasses: [.synthetic],
            missingEvidenceClassesForRealWorldPass: [
                .localLoopback,
                .referencePeer,
                .liveDevice,
                .fieldRoute,
                .packetCapture,
                .timing,
                .teardown,
                .mediaQuality,
            ],
            assumptions: [
                "LoLa connector uses local reverse-engineering evidence for control message names, visible fields, numeric SID formatting, recovered template terminators, default ports, status-check and direct quick-connect control entry paths, explicit tx-rx role parsing, recovered media body serialization, normal audio/video fragments, video prelude packets, source-level synthetic packet fixtures, passive capture media classification, post-control UDP socket media TX/RX with peer-source receive filtering, opt-in raw-link media TX/RX session wiring, and peer-specific tx-rx connection-plan endpoints; real Windows LoLa interoperability remains unclaimed.",
                "MVTP/UltraGrid connector uses a Swift-native RTP/MVTP media runtime for PT 20 raw video fragments, PT 21 PCM audio, PT 22 local FEC recovery, PT 24/25 AES-GCM encryption, PT 26 RTP/JPEG, dynamic RTP/H.264 packet validation, and modeled TCP control commands over the default UDP video/audio ports; public uv helpers remain reference/parity tooling, not the primary runtime.",
                "JackTrip connector uses Swift-native UDP DEFAULT, JAMLINK, EMPTY-header, WebRTC data-channel, WebTransport datagram, JACK graph dry-run, plugin bridge, and Opus-extension packetization paths, keeps the public jacktrip command and Docker helpers as reference/parity tooling, maps configured queue, redundancy, channel, sample-rate, buffer-size, bind-port, peer-port, bit-resolution, audio-backend, packet-header, transport, plugin, and payload-encoding settings into native session reports, and keeps measured peer evidence separate from source-level support.",
                "Universal NMP planning emits one LoLa, MVTP/UltraGrid, and JackTrip A/V bundle; NMP preflight runs the embedded executable checks; NMP endpoint run consumes the same bundle to execute all selected local or remote side endpoint sessions through the existing connector runners; NMP workflow runs plan, preflight, and endpoint-run in one command, writes the subordinate reports, and passes preflight-discovered executable paths into endpoint commands.",
            ],
            notes: "Code-only connector TX/RX launch surface. Real-world interoperability remains PARTIAL until measured external endpoint evidence exists."
        )
    }
}

private func lolaConnector() -> ExternalConnectorContract {
    ExternalConnectorContract(
        id: "connector-lola-clean-room-source-contract",
        title: "LoLa compatibility connector",
        connector: .lola,
        supportedHandshake: .protocolAwareTxRx,
        sourceContractImplemented: true,
        realWorldInteroperabilityClaimed: false,
        preservesDefaultAudioFirstPath: true,
        defaultEnabled: false,
        externalImplementationRequired: false,
        publicReference: "Public compatibility boundary: docs/reverse-engineering-boundary.md and docs/compatibility-scope.md.",
        cleanRoomBoundary: "Implements visible control fields, numeric SID formatting, recovered template terminators, default ports, timing assumptions, outer Ethernet/IPv4/UDP wire framing, little-endian media bodies, normal fragments, audio block sizing, and video prelude-plus-fragment packetization from the local dossier; real Windows LoLa compatibility remains PARTIAL until packet captures validate interoperability.",
        requiredEvidenceForRealWorldPass: [
            "Windows LoLa peer selected by a maintainer",
            "captured control and audio/video packets",
            "packet grammar validation against capture",
            "measured isolated route report",
            "latency and artifact comparison",
        ],
        notes: "TX sends reconstructed status-check and quick-connect control over UDP/TCP, waiting for /MESG_CHECKLOLASTATUS_ACK and /MESG_QUICKCONN_ACK; if the status-check wait times out, TX falls back to direct /MESG_QUICKCONN because the local evidence describes both status and quick-connect message families. RX binds, parses either entry path, accepts NUL-padded 1024-byte control datagrams, tolerates truncated unescaped TXT tokens, and replies with the recovered ACK field sets. TX-RX is explicit and combines the initiator control path with source-level media TX frame generation plus RX envelope-validation evidence in one session report. The media codec emits little-endian serialized bodies, one normal audio fragment per 64-frame int16 block, one video prelude before normal video fragments, and byte-carrier support for raw generated video or JPEG payload bytes without bundling an encoder. The packet fixture runner generates source-level synthetic Ethernet/IPv4/UDP frames and optional pcap files, then round-trips them through the passive decoder. Passive capture decode labels audio fragments, video preludes, video fragments, MJPEG candidates, malformed fragments, and unknown payloads without treating those labels as compatibility proof. Connector sessions run post-control UDP socket media TX/RX for IP-routed LoLa attempts, filter received UDP media by the configured peer source host, and can opt into raw-link media TX/RX with explicit interface and MAC parameters. Real Windows LoLa interoperability remains unproven until a measured Windows media capture validates the source-level grammar."
    )
}

private func mvtpUltraGridConnector() -> ExternalConnectorContract {
    ExternalConnectorContract(
        id: "connector-mvtp-ultragrid-source-contract",
        title: "MVTP/UltraGrid connector",
        connector: .mvtpUltraGrid,
        supportedHandshake: .protocolAwareTxRx,
        sourceContractImplemented: true,
        realWorldInteroperabilityClaimed: false,
        preservesDefaultAudioFirstPath: true,
        defaultEnabled: false,
        externalImplementationRequired: false,
        publicReference: "UltraGrid GitHub repository and wiki: https://github.com/CESNET/UltraGrid and https://github.com/CESNET/UltraGrid/wiki.",
        cleanRoomBoundary: "Implements Swift-native RTP/MVTP packetization for PT 20 raw-video, PT 21 PCM-audio, PT 22 local FEC recovery, PT 24/25 AES-GCM encryption, PT 26 RTP/JPEG, dynamic RTP/H.264 packet validation, and modeled TCP control command frames from public UltraGrid and RFC references; no bundled UltraGrid code or private protocol logic.",
        requiredEvidenceForRealWorldPass: [
            "UltraGrid peer version and capture transcript",
            "Swift-native RTP/MVTP packet capture matched by a public UltraGrid peer",
            "RTP/UDP route report",
            "audio-first degradation comparison",
            "video/audio sync report",
        ],
        notes: "MVTP/UltraGrid TX/RX is implemented as a Swift-native RTP/MVTP media path using existing Open LoLa UDP, timing, CoreAudio/AVFoundation-compatible payload surfaces, and connector reports. Public uv helpers remain useful reference/parity tools, but are no longer the primary mvtp-ultragrid runtime. Real UltraGrid interoperability remains unproven until measured peer captures validate packet compatibility."
    )
}

private func jackTripConnector() -> ExternalConnectorContract {
    ExternalConnectorContract(
        id: "connector-jacktrip-source-contract",
        title: "JackTrip connector",
        connector: .jackTrip,
        supportedHandshake: .protocolAwareTxRx,
        sourceContractImplemented: true,
        realWorldInteroperabilityClaimed: false,
        preservesDefaultAudioFirstPath: true,
        defaultEnabled: false,
        externalImplementationRequired: false,
        publicReference: "JackTrip GitHub repository and documentation: https://github.com/jacktrip/jacktrip and https://jacktrip.github.io/jacktrip/.",
        cleanRoomBoundary: "Implements public JackTrip UDP DEFAULT header and planar PCM packetization from NetworkProtocol.md and PacketHeader.h without vendoring JackTrip. Audio-video mode keeps video on a separate public UltraGrid carrier instead of extending JackTrip's audio protocol.",
        requiredEvidenceForRealWorldPass: [
            "JackTrip peer version and launch transcript",
            "packet capture proving Swift-native DEFAULT UDP PCM packets are accepted by a public JackTrip peer",
            "auxiliary video carrier transcript when audio-video mode is used",
            "bidirectional audio route report",
            "channel-count and buffer report",
            "latency comparison against native direct-audio path",
        ],
        notes: "JackTrip TX-RX is implemented as a peer-known native audio plan for DEFAULT, JAMLINK, EMPTY, WebRTC data-channel, WebTransport datagram, PCM, and Opus-extension payload models. AV mode adds an auxiliary UltraGrid video launch plan with configurable capture/display modules and a required remote peer host for the video leg. Generated bidirectional connection plans retain explicit queue, redundancy, bind port, peer audio port, sample-rate, buffer-size, bit-resolution, audio-backend, packet-header, transport, plugin, and payload-encoding settings. Public jacktrip executable preflight and Docker scripts remain reference/parity evidence tools rather than the primary runtime requirement."
    )
}

private func requireExternalConnectorNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, empty: ExternalConnectorValidationError.emptyField)
}

private func requireExternalConnectorNonEmptyList(_ values: [String], _ field: String) throws {
    try ValidationPrimitives.requireNonEmptyStrings(
        values,
        field: field,
        emptyField: ExternalConnectorValidationError.emptyField,
        emptyList: ExternalConnectorValidationError.emptyList
    )
}

private func requireExternalConnectorNonEmptyEvidenceClasses(
    _ values: [ExternalConnectorEvidenceClass],
    _ field: String
) throws {
    guard !values.isEmpty else {
        throw ExternalConnectorValidationError.emptyList(field)
    }
}
