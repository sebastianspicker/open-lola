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
        self.assumptions = assumptions
        self.notes = notes
    }

    public func validate() throws {
        try requireExternalConnectorNonEmpty(id, "id")
        try requireExternalConnectorNonEmpty(title, "title")
        try requireExternalConnectorNonEmpty(capturedAt, "capturedAt")
        try requireExternalConnectorNonEmpty(notes, "notes")
        try requireExternalConnectorNonEmptyList(assumptions, "assumptions")
        try validateConnectors()

        if realWorldVerdict == .pass {
            throw ExternalConnectorValidationError.realWorldPassNotAllowed
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
            assumptions: [
                "LoLa connector uses local reverse-engineering evidence for control message names, visible fields, numeric SID formatting, recovered template terminators, default ports, status-check and direct quick-connect control entry paths, explicit tx-rx role parsing, recovered media body serialization, normal audio/video fragments, video prelude packets, source-level synthetic packet fixtures, passive capture media classification, post-control UDP socket media TX/RX with peer-source receive filtering, opt-in raw-link media TX/RX session wiring, and peer-specific tx-rx connection-plan endpoints; real Windows LoLa interoperability remains unclaimed.",
                "MVTP/UltraGrid connector launches the public uv command with explicit tx-rx mode, configurable capture/playback/display modules, default UDP video/audio ports, required remote peer host arguments for tx-rx endpoints, one full-duplex uv process for peer-known tx-rx sessions, concrete endpoint report paths derived from the plan output parent directory unless --run-dir is set, connector-scoped local executable identity preflight to catch non-UltraGrid uv PATH collisions and discover common UltraGrid aliases/install paths, and structured FAIL reports for early process exits.",
                "JackTrip connector launches the public jacktrip command for bidirectional audio, maps configured audio capture/playback names to JackTrip RtAudio input/output device options, adds a configurable UltraGrid video carrier for audio-video mode, requires a remote peer for that auxiliary video leg, exposes explicit tx-rx mode for peer-known auxiliary video, emits P2P server/client connection-plan commands with explicit bind and peer audio ports, exposes connector-scoped executable identity preflight for JackTrip plus auxiliary UltraGrid with discovered executable propagation into NMP endpoint commands, and reports early audio/video process exits as structured FAIL artifacts.",
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
        publicReference: "Public compatibility boundary: docs/reverse-engineering/README.md and docs/background/open-lola-compatibility-scope.md.",
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
        externalImplementationRequired: true,
        publicReference: "UltraGrid GitHub repository and wiki: https://github.com/CESNET/UltraGrid and https://github.com/CESNET/UltraGrid/wiki.",
        cleanRoomBoundary: "Uses public UltraGrid-style deployment assumptions only; no bundled UltraGrid code or private protocol logic.",
        requiredEvidenceForRealWorldPass: [
            "UltraGrid version and command transcript",
            "executable preflight PASS report for UltraGrid uv",
            "RTP/UDP route report",
            "audio-first degradation comparison",
            "video/audio sync report",
        ],
        notes: "MVTP/UltraGrid TX-RX is implemented as one uv launch plan with both transmit/capture and receive/display arguments. TX-RX plans require the remote peer host instead of silently self-peering, matching public UltraGrid sender/receiver examples. Generated bidirectional connection plans emit tx-rx endpoint commands for both peers. Connection plans emit a connector-scoped executable preflight command that probes local uv identity before endpoint attempts so Python uv is reported as a host-readiness failure without requiring unrelated JackTrip; preflight also tries common UltraGrid aliases and macOS install paths, and the NMP workflow propagates any discovered executable into endpoint commands. The session parser exposes UltraGrid audio capture, audio playback, video capture, video display, and full-duplex mode controls so real NMP endpoints can replace dry-run defaults."
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
        externalImplementationRequired: true,
        publicReference: "JackTrip GitHub repository and documentation: https://github.com/jacktrip/jacktrip and https://jacktrip.github.io/jacktrip/.",
        cleanRoomBoundary: "Uses public JackTrip-style audio mode, RtAudio system-backend mode, and channel assumptions. Audio-video mode keeps video on a separate public UltraGrid carrier instead of extending JackTrip's audio protocol.",
        requiredEvidenceForRealWorldPass: [
            "JackTrip version and launch transcript",
            "executable preflight PASS report for JackTrip and auxiliary UltraGrid uv",
            "auxiliary video carrier transcript when audio-video mode is used",
            "bidirectional audio route report",
            "channel-count and buffer report",
            "latency comparison against native direct-audio path",
        ],
        notes: "JackTrip TX-RX is implemented as a peer-known jacktrip RtAudio launch plan; configured audio capture/playback names are passed as RtAudio input/output device options. AV mode adds an auxiliary UltraGrid video launch plan with configurable capture/display modules and a required remote peer host for the video leg. Generated bidirectional connection plans emit one P2P server endpoint and one P2P client endpoint with explicit queue, redundancy, bind port, peer audio port, sample-rate, and buffer-size settings, and include a connector-scoped preflight for JackTrip plus auxiliary UltraGrid. The executable preflight reports missing jacktrip and non-UltraGrid uv before a real A/V endpoint run, tries common JackTrip/UltraGrid macOS install paths, and lets the NMP workflow propagate discovered audio and auxiliary-video executable paths into endpoint commands."
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
