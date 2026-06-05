import Foundation

public enum NetworkRouteMode: String, Codable, Sendable {
    case udpPcmPacketProbe
    case udpPcmRoute
    case udpPcmLoopback
    case networkDiagnostics
    case natFriendlyRoute
    case natRendezvous
    case natRelay
    case natForwarder
    case macToMacConnectionEstablishment
    case directPeerSession
}

public enum NetworkRouteEvidenceBoundary: String, Codable, Sendable {
    case packetContractOnly
    case directFastestCandidate
    case directCertificationGate
    case loopbackMeasurement
    case diagnosticOnly
    case natCompatibilityOnly
    case connectionPreflight
    case directPeerSessionPartialOnly
}

public struct NetworkRouteCommandMatrixEntry: Codable, Equatable, Sendable {
    public let command: String
    public let kind: CLICommandKind
    public let ownerSourceFile: String
    public let parser: String
    public let outputReport: String
    public let routeMode: NetworkRouteMode
    public let evidenceBoundary: NetworkRouteEvidenceBoundary
    public let canContributeToFastestDirectEvidence: Bool
    public let representativeCommand: String
    public let relatedSourceFiles: [String]
    public let relatedTestFiles: [String]
    public let notes: String

    public init(
        command: String,
        kind: CLICommandKind,
        ownerSourceFile: String,
        parser: String,
        outputReport: String,
        routeMode: NetworkRouteMode,
        evidenceBoundary: NetworkRouteEvidenceBoundary,
        canContributeToFastestDirectEvidence: Bool,
        representativeCommand: String,
        relatedSourceFiles: [String],
        relatedTestFiles: [String],
        notes: String
    ) {
        self.command = command
        self.kind = kind
        self.ownerSourceFile = ownerSourceFile
        self.parser = parser
        self.outputReport = outputReport
        self.routeMode = routeMode
        self.evidenceBoundary = evidenceBoundary
        self.canContributeToFastestDirectEvidence = canContributeToFastestDirectEvidence
        self.representativeCommand = representativeCommand
        self.relatedSourceFiles = relatedSourceFiles
        self.relatedTestFiles = relatedTestFiles
        self.notes = notes
    }
}

public struct NetworkRouteCommandMatrixSummary: Codable, Equatable, Sendable {
    public let entryCount: Int
    public let validatorCount: Int
    public let runCount: Int
    public let localhostSmokeCount: Int
    public let probeCount: Int
    public let fastestDirectEvidenceCount: Int
    public let natCompatibilityOnlyCount: Int
    public let diagnosticOnlyCount: Int
    public let loopbackMeasurementCount: Int
    public let packetContractOnlyCount: Int
}

public struct NetworkRouteCommandMatrixReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: NetworkRouteCommandMatrixSummary
    public let entries: [NetworkRouteCommandMatrixEntry]
    public let notes: String
}

public enum NetworkRouteCommandMatrix {
    public static func report() -> NetworkRouteCommandMatrixReport {
        NetworkRouteCommandMatrixReport(
            id: "c05-network-route-command-matrix",
            title: "C05 network transport route and argument matrix",
            verdict: .partial,
            summary: summary(),
            entries: entries,
            notes: "Executable route-command crosswalk. It separates direct fastest-path candidates from NAT, relay, diagnostics, loopback, and localhost-only evidence."
        )
    }

    public static func summary() -> NetworkRouteCommandMatrixSummary {
        NetworkRouteCommandMatrixSummary(
            entryCount: entries.count,
            validatorCount: entries.filter { $0.kind == .validator }.count,
            runCount: entries.filter { $0.kind == .run }.count,
            localhostSmokeCount: entries.filter { $0.kind == .localhostSmoke }.count,
            probeCount: entries.filter { $0.kind == .probe }.count,
            fastestDirectEvidenceCount: entries
                .filter(\.canContributeToFastestDirectEvidence)
                .count,
            natCompatibilityOnlyCount: count(.natCompatibilityOnly),
            diagnosticOnlyCount: count(.diagnosticOnly),
            loopbackMeasurementCount: count(.loopbackMeasurement),
            packetContractOnlyCount: count(.packetContractOnly)
        )
    }

    public static let entries: [NetworkRouteCommandMatrixEntry] = [
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "udp-pcm-send-once",
            kind: .probe,
            ownerSourceFile: "Sources/open-lola/main.swift",
            parser: "two positional arguments: host and port",
            outputReport: "UdpPcmPacket",
            routeMode: .udpPcmPacketProbe,
            evidenceBoundary: .packetContractOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola udp-pcm-send-once 127.0.0.1 5004",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            notes: "One-shot packet probe; useful for packet contract smoke, not route readiness."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "udp-pcm-receive-once",
            kind: .probe,
            ownerSourceFile: "Sources/open-lola/main.swift",
            parser: "one positional argument: port",
            outputReport: "UdpPcmPacket",
            routeMode: .udpPcmPacketProbe,
            evidenceBoundary: .packetContractOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola udp-pcm-receive-once 5004",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            notes: "One-shot receive probe; confirms decode path only."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-udp-pcm-packet",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "UdpPcmPacket",
            routeMode: .udpPcmPacketProbe,
            evidenceBoundary: .packetContractOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola validate-udp-pcm-packet Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-int16.hex",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            notes: "Packet schema validation is a prerequisite but carries no route evidence."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-route-report",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "UdpPcmRouteReport",
            routeMode: .udpPcmRoute,
            evidenceBoundary: .directFastestCandidate,
            canContributeToFastestDirectEvidence: true,
            representativeCommand: "open-lola validate-route-report Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/valid/direct-link-pass.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"],
            notes: "A passing physical direct-link route report can feed fastest-path evidence, but route certification still owns broader route ordering."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-route-certification-report",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "MacToMacRouteCertificationReport",
            routeMode: .udpPcmRoute,
            evidenceBoundary: .directCertificationGate,
            canContributeToFastestDirectEvidence: true,
            representativeCommand: "open-lola validate-route-certification-report Tests/OpenLolaCoreTests/Fixtures/MacToMacRouteCertificationReports/valid/g04-route-certification-partial.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/MacToMacRouteCertification.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift"],
            notes: "Certification is the aggregate route gate and requires the direct-link candidate before switched or campus paths."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "udp-pcm-route-run",
            kind: .run,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "UdpPcmRouteRunConfiguration.parse",
            outputReport: "UdpPcmContinuousSenderSummary or UdpPcmRouteReport",
            routeMode: .udpPcmRoute,
            evidenceBoundary: .directFastestCandidate,
            canContributeToFastestDirectEvidence: true,
            representativeCommand: "open-lola udp-pcm-route-run --role receiver --peer 10.10.20.10 --port 5004 --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 2 --output reports/route.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"],
            notes: "Receiver mode can emit measured route evidence; sender mode only emits a send summary."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "udp-pcm-localhost-smoke",
            kind: .localhostSmoke,
            ownerSourceFile: "Sources/open-lola/Commands/MilestoneCommands.swift",
            parser: "fixed command",
            outputReport: "UdpPcmPacket",
            routeMode: .udpPcmPacketProbe,
            evidenceBoundary: .packetContractOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola udp-pcm-localhost-smoke",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            notes: "Local packet smoke stays source-level and cannot close route readiness."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "udp-pcm-route-localhost-smoke",
            kind: .localhostSmoke,
            ownerSourceFile: "Sources/open-lola/Commands/MilestoneCommands.swift",
            parser: "fixed command",
            outputReport: "UdpPcmRouteReport",
            routeMode: .udpPcmRoute,
            evidenceBoundary: .directFastestCandidate,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola udp-pcm-route-localhost-smoke",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteLocalhostSmoke.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"],
            notes: "Localhost route smoke must remain PARTIAL and is explicitly excluded from fastest direct evidence."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-udp-pcm-loopback-report",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "UdpPcmLoopbackReport",
            routeMode: .udpPcmLoopback,
            evidenceBoundary: .loopbackMeasurement,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola validate-udp-pcm-loopback-report reports/loopback.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"],
            notes: "Loopback timing supports route analysis but is not direct fastest-path proof by itself."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-udp-pcm-loopback-session",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "two fixed path arguments",
            outputReport: "UdpPcmLoopbackReport pair",
            routeMode: .udpPcmLoopback,
            evidenceBoundary: .loopbackMeasurement,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola validate-udp-pcm-loopback-session reports/sender.json reports/looper.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"],
            notes: "Session-pair validation proves reciprocal loopback agreement, not route superiority."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "udp-pcm-loopback-run",
            kind: .run,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "UdpPcmLoopbackRunConfiguration.parse",
            outputReport: "UdpPcmLoopbackReport",
            routeMode: .udpPcmLoopback,
            evidenceBoundary: .loopbackMeasurement,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola udp-pcm-loopback-run --session-id s1 --role sender --bind-host 10.0.0.1 --peer 10.0.0.2 --port 5004 --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 2 --output reports/loopback.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"],
            notes: "Measured UDP loopback is supporting route evidence and must be paired with route classification before promotion."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "udp-pcm-loopback-localhost-smoke",
            kind: .localhostSmoke,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed command",
            outputReport: "UdpPcmLoopbackReport",
            routeMode: .udpPcmLoopback,
            evidenceBoundary: .loopbackMeasurement,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola udp-pcm-loopback-localhost-smoke",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"],
            notes: "Localhost loopback smoke exercises timing code and remains PARTIAL evidence."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-network-diagnostics-report",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "NetworkDiagnosticsReport",
            routeMode: .networkDiagnostics,
            evidenceBoundary: .diagnosticOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola validate-network-diagnostics-report reports/diagnostics.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift"],
            notes: "Diagnostics explain reachability and traceroute behavior but cannot replace a route report."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "network-diagnostics-run",
            kind: .run,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "NetworkDiagnosticsRunConfiguration.parse",
            outputReport: "NetworkDiagnosticsReport",
            routeMode: .networkDiagnostics,
            evidenceBoundary: .diagnosticOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola network-diagnostics-run --peer 10.10.20.10 --ping-count 3 --max-hops 8 --output reports/diagnostics.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift"],
            notes: "Runtime diagnostics are support artifacts for route triage only."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-nat-friendly-route-report",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "NatFriendlyRouteReport",
            routeMode: .natFriendlyRoute,
            evidenceBoundary: .natCompatibilityOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola validate-nat-friendly-route-report reports/nat-friendly.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "NAT-friendly reports distinguish direct traversal from relay fallback and cannot be direct-fastest evidence."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-mac-to-mac-connection-establishment-report",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "MacToMacConnectionEstablishmentReport",
            routeMode: .macToMacConnectionEstablishment,
            evidenceBoundary: .connectionPreflight,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola validate-mac-to-mac-connection-establishment-report reports/mac-to-mac-preflight.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/P2P/MacToMacConnectionEstablishment.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/MacToMacConnectionEstablishmentTests.swift"],
            notes: "Validates the IP/NAT-first setup report. It can permit a later direct UDP/IP media launch, but is not measured media evidence by itself."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "mac-to-mac-connection-preflight-run",
            kind: .run,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "MacToMacConnectionEstablishmentRunConfiguration.parse",
            outputReport: "MacToMacConnectionEstablishmentReport",
            routeMode: .macToMacConnectionEstablishment,
            evidenceBoundary: .connectionPreflight,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola mac-to-mac-connection-preflight-run --local-peer-id mac-a --remote-peer-id mac-b --peer 203.0.113.7 --nat-route-report reports/nat.json --output reports/mac-to-mac-preflight.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/MacToMacConnectionEstablishment.swift",
                "Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/MacToMacConnectionEstablishmentTests.swift"],
            notes: "Default mac-to-mac setup preflight. It records reachability and NAT route blockers before direct media state may be trusted."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "nat-friendly-route-run",
            kind: .run,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "NatFriendlyRouteRunConfiguration.parse",
            outputReport: "NatFriendlyRouteReport",
            routeMode: .natFriendlyRoute,
            evidenceBoundary: .natCompatibilityOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola nat-friendly-route-run --role sender --bind-host 0.0.0.0 --peer-id sender-a --rendezvous-host 10.0.0.2 --rendezvous-port 7000 --session-id s1 --port 5004 --duration-seconds 2 --keepalive-interval-ms 250 --output reports/nat.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "The runner emits PARTIAL compatibility evidence and keeps raw direct P2P as the default fastest path."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "nat-friendly-localhost-smoke",
            kind: .localhostSmoke,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed command",
            outputReport: "NatFriendlyRouteReport",
            routeMode: .natFriendlyRoute,
            evidenceBoundary: .natCompatibilityOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola nat-friendly-localhost-smoke",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "Local NAT-friendly smoke proves localhost compatibility only."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "nat-rendezvous-run",
            kind: .run,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "NatRendezvousRunConfiguration.parse",
            outputReport: "NatRendezvousReport",
            routeMode: .natRendezvous,
            evidenceBoundary: .natCompatibilityOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola nat-rendezvous-run --bind-host 0.0.0.0 --port 7000 --session-id s1 --mode directTraversal --expected-peers 2 --timeout-seconds 30 --output reports/rendezvous.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "Rendezvous records peer discovery and external endpoint observation, not media route superiority."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "nat-rendezvous-localhost-smoke",
            kind: .localhostSmoke,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed command",
            outputReport: "NatRendezvousLocalhostSmokeResult",
            routeMode: .natRendezvous,
            evidenceBoundary: .natCompatibilityOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola nat-rendezvous-localhost-smoke",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "Local rendezvous smoke validates discovery and handoff on localhost only."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "nat-relay-run",
            kind: .run,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "NatRelayRunConfiguration.parse",
            outputReport: "NatRelayReport",
            routeMode: .natRelay,
            evidenceBoundary: .natCompatibilityOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola nat-relay-run --bind-host 0.0.0.0 --port 7001 --session-id s1 --expected-peers 2 --timeout-seconds 30 --output reports/relay.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "Relay reports are compatibility fallback evidence and must never be fastest-path proof."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "nat-relay-fallback-localhost-smoke",
            kind: .localhostSmoke,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed command",
            outputReport: "NatRelayFallbackLocalhostSmokeResult",
            routeMode: .natRelay,
            evidenceBoundary: .natCompatibilityOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola nat-relay-fallback-localhost-smoke",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "Relay fallback smoke intentionally proves failed direct traversal before relay use."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "nat-rendezvous-forwarder-run",
            kind: .run,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "NatRendezvousForwarderLauncherConfiguration.parse",
            outputReport: "NatRendezvousForwarderLauncherReport",
            routeMode: .natForwarder,
            evidenceBoundary: .natCompatibilityOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola nat-rendezvous-forwarder-run --bind-host 0.0.0.0 --rendezvous-port 7000 --forwarder-port 7001 --session-id s1 --expected-peers 2 --timeout-seconds 30 --output reports/forwarder.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "Forwarder launch reports carry an explicit performance warning and compatibility-only boundary."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "nat-rendezvous-forwarder-localhost-smoke",
            kind: .localhostSmoke,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed command",
            outputReport: "NatRendezvousForwarderLauncherReport",
            routeMode: .natForwarder,
            evidenceBoundary: .natCompatibilityOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola nat-rendezvous-forwarder-localhost-smoke",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "Local forwarder smoke checks argument/service boundaries without performance claims."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-direct-p2p-session-report",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "DirectPeerSessionReport",
            routeMode: .directPeerSession,
            evidenceBoundary: .directPeerSessionPartialOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola validate-direct-p2p-session-report reports/direct-p2p.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            notes: "Direct peer session validation currently rejects PASS until manual direct-LAN evidence exists."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "verify-direct-p2p-session-evidence-bundle",
            kind: .probe,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity report path and bundle root arguments",
            outputReport: "DirectPeerSessionEvidenceBundleVerification",
            routeMode: .directPeerSession,
            evidenceBoundary: .directPeerSessionPartialOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola verify-direct-p2p-session-evidence-bundle reports/direct-p2p.json .",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift",
                "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionEvidenceBundleVerifier.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerSessionReportAVPassTests.swift"],
            notes: "PASS evidence promotion must prove declared Direct P2P artifacts exist and match their SHA-256 hashes."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-direct-p2p-mesh-topology-report",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "DirectPeerMeshTopologyReport",
            routeMode: .directPeerSession,
            evidenceBoundary: .directPeerSessionPartialOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola validate-direct-p2p-mesh-topology-report reports/direct-p2p-mesh.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            notes: "Mesh topology validation proves multi-peer route shape only; it carries no physical media evidence."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-direct-p2p-mesh-runtime-report",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "DirectPeerMeshRuntimeReport",
            routeMode: .directPeerSession,
            evidenceBoundary: .directPeerSessionPartialOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola validate-direct-p2p-mesh-runtime-report reports/direct-p2p-mesh-runtime.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            notes: "Mesh runtime validation proves localhost all-pairs UDP PCM v2 delivery only; physical route evidence remains required."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-direct-p2p-two-peer-plan-report",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "DirectPeerTwoPeerRunPlanReport",
            routeMode: .directPeerSession,
            evidenceBoundary: .directPeerSessionPartialOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola validate-direct-p2p-two-peer-plan-report reports/direct-p2p-two-peer-plan.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"],
            notes: "Plan validation proves the two expected endpoint commands and report references exist; it does not validate measured media delivery."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "direct-p2p-two-peer-plan-run",
            kind: .run,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "DirectPeerTwoPeerRunPlanConfiguration.parse",
            outputReport: "DirectPeerTwoPeerRunPlanReport",
            routeMode: .directPeerSession,
            evidenceBoundary: .directPeerSessionPartialOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola direct-p2p-two-peer-plan-run --output reports/direct-p2p-two-peer-plan.json --run-dir reports/m06 --mac-a-peer mac-a --mac-a-host 192.0.2.10 --mac-a-port-base 57000 --mac-a-input-uid rme-a --mac-a-output-uid rme-a --mac-a-video-device-id camera-a --mac-b-peer mac-b --mac-b-host 192.0.2.20 --mac-b-port-base 57010 --mac-b-input-uid rme-b --mac-b-output-uid rme-b --mac-b-video-device-id camera-b --duration-seconds 30",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"],
            notes: "Builds the paired Mac command plan and subordinate DirectPeerSessionReport paths before a physical two-peer run."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "direct-p2p-mesh-topology-synthetic-smoke",
            kind: .syntheticSmoke,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "--output path and optional peer count",
            outputReport: "DirectPeerMeshTopologyReport",
            routeMode: .directPeerSession,
            evidenceBoundary: .directPeerSessionPartialOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola direct-p2p-mesh-topology-synthetic-smoke --output reports/direct-p2p-mesh.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            notes: "Source-level three-or-more-peer topology smoke; runtime delivery evidence remains separate."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "direct-p2p-mesh-runtime-localhost-smoke",
            kind: .localhostSmoke,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "--output path, optional peer count, and optional packet count",
            outputReport: "DirectPeerMeshRuntimeReport",
            routeMode: .directPeerSession,
            evidenceBoundary: .directPeerSessionPartialOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola direct-p2p-mesh-runtime-localhost-smoke --output reports/direct-p2p-mesh-runtime.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift",
                "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            notes: "Localhost mesh smoke routes UDP PCM v2 audio across every directed peer pair; it is not physical direct-LAN evidence."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "direct-p2p-session-run",
            kind: .run,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "--output path and optional packet count",
            outputReport: "DirectPeerSessionReport",
            routeMode: .directPeerSession,
            evidenceBoundary: .directPeerSessionPartialOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola direct-p2p-session-run --output reports/direct-p2p.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift",
                "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift",
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            notes: "Socket-backed direct-P2P run proves local control and media startup, not direct-LAN fastest evidence."
        )),
    ]

    private static func count(_ boundary: NetworkRouteEvidenceBoundary) -> Int {
        entries.filter { $0.evidenceBoundary == boundary }.count
    }
}

private struct NetworkRouteCommandMatrixEntryDraft {
    var command: String
    var kind: CLICommandKind
    var ownerSourceFile: String
    var parser: String
    var outputReport: String
    var routeMode: NetworkRouteMode
    var evidenceBoundary: NetworkRouteEvidenceBoundary
    var canContributeToFastestDirectEvidence: Bool
    var representativeCommand: String
    var relatedSourceFiles: [String]
    var relatedTestFiles: [String]
    var notes: String
}

private func entry(_ draft: NetworkRouteCommandMatrixEntryDraft) -> NetworkRouteCommandMatrixEntry {
    NetworkRouteCommandMatrixEntry(
        command: draft.command,
        kind: draft.kind,
        ownerSourceFile: draft.ownerSourceFile,
        parser: draft.parser,
        outputReport: draft.outputReport,
        routeMode: draft.routeMode,
        evidenceBoundary: draft.evidenceBoundary,
        canContributeToFastestDirectEvidence: draft.canContributeToFastestDirectEvidence,
        representativeCommand: draft.representativeCommand,
        relatedSourceFiles: draft.relatedSourceFiles,
        relatedTestFiles: draft.relatedTestFiles,
        notes: draft.notes
    )
}
