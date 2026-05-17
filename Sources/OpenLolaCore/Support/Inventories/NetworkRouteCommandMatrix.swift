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
        entry(
            "udp-pcm-send-once",
            .probe,
            "Sources/open-lola/main.swift",
            "two positional arguments: host and port",
            "UdpPcmPacket",
            .udpPcmPacketProbe,
            .packetContractOnly,
            false,
            "open-lola udp-pcm-send-once 127.0.0.1 5004",
            ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"],
            ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            "One-shot packet probe; useful for packet contract smoke, not route readiness."
        ),
        entry(
            "udp-pcm-receive-once",
            .probe,
            "Sources/open-lola/main.swift",
            "one positional argument: port",
            "UdpPcmPacket",
            .udpPcmPacketProbe,
            .packetContractOnly,
            false,
            "open-lola udp-pcm-receive-once 5004",
            ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"],
            ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            "One-shot receive probe; confirms decode path only."
        ),
        entry(
            "validate-udp-pcm-packet",
            .validator,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed-arity path argument",
            "UdpPcmPacket",
            .udpPcmPacketProbe,
            .packetContractOnly,
            false,
            "open-lola validate-udp-pcm-packet Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-int16.hex",
            ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"],
            ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            "Packet schema validation is a prerequisite but carries no route evidence."
        ),
        entry(
            "validate-route-report",
            .validator,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed-arity path argument",
            "UdpPcmRouteReport",
            .udpPcmRoute,
            .directFastestCandidate,
            true,
            "open-lola validate-route-report Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/valid/direct-link-pass.json",
            [
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift",
            ],
            ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"],
            "A passing physical direct-link route report can feed fastest-path evidence, but route certification still owns broader route ordering."
        ),
        entry(
            "validate-route-certification-report",
            .validator,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed-arity path argument",
            "MacToMacRouteCertificationReport",
            .udpPcmRoute,
            .directCertificationGate,
            true,
            "open-lola validate-route-certification-report Tests/OpenLolaCoreTests/Fixtures/MacToMacRouteCertificationReports/valid/g04-route-certification-partial.json",
            [
                "Sources/OpenLolaCore/Network/P2P/MacToMacRouteCertification.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift",
            ],
            ["Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift"],
            "Certification is the aggregate route gate and requires the direct-link candidate before switched or campus paths."
        ),
        entry(
            "udp-pcm-route-run",
            .run,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "UdpPcmRouteRunConfiguration.parse",
            "UdpPcmContinuousSenderSummary or UdpPcmRouteReport",
            .udpPcmRoute,
            .directFastestCandidate,
            true,
            "open-lola udp-pcm-route-run --role receiver --peer 10.10.20.10 --port 5004 --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 2 --output reports/route.json",
            [
                "Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift",
            ],
            ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"],
            "Receiver mode can emit measured route evidence; sender mode only emits a send summary."
        ),
        entry(
            "udp-pcm-localhost-smoke",
            .localhostSmoke,
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "fixed command",
            "UdpPcmPacket",
            .udpPcmPacketProbe,
            .packetContractOnly,
            false,
            "open-lola udp-pcm-localhost-smoke",
            ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"],
            ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            "Local packet smoke stays source-level and cannot close route readiness."
        ),
        entry(
            "udp-pcm-route-localhost-smoke",
            .localhostSmoke,
            "Sources/open-lola/Commands/MilestoneCommands.swift",
            "fixed command",
            "UdpPcmRouteReport",
            .udpPcmRoute,
            .directFastestCandidate,
            false,
            "open-lola udp-pcm-route-localhost-smoke",
            [
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteLocalhostSmoke.swift",
            ],
            ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"],
            "Localhost route smoke must remain PARTIAL and is explicitly excluded from fastest direct evidence."
        ),
        entry(
            "validate-udp-pcm-loopback-report",
            .validator,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed-arity path argument",
            "UdpPcmLoopbackReport",
            .udpPcmLoopback,
            .loopbackMeasurement,
            false,
            "open-lola validate-udp-pcm-loopback-report reports/loopback.json",
            ["Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift"],
            ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"],
            "Loopback timing supports route analysis but is not direct fastest-path proof by itself."
        ),
        entry(
            "validate-udp-pcm-loopback-session",
            .validator,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "two fixed path arguments",
            "UdpPcmLoopbackReport pair",
            .udpPcmLoopback,
            .loopbackMeasurement,
            false,
            "open-lola validate-udp-pcm-loopback-session reports/sender.json reports/looper.json",
            ["Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift"],
            ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"],
            "Session-pair validation proves reciprocal loopback agreement, not route superiority."
        ),
        entry(
            "udp-pcm-loopback-run",
            .run,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "UdpPcmLoopbackRunConfiguration.parse",
            "UdpPcmLoopbackReport",
            .udpPcmLoopback,
            .loopbackMeasurement,
            false,
            "open-lola udp-pcm-loopback-run --session-id s1 --role sender --bind-host 10.0.0.1 --peer 10.0.0.2 --port 5004 --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 2 --output reports/loopback.json",
            ["Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift"],
            ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"],
            "Measured UDP loopback is supporting route evidence and must be paired with route classification before promotion."
        ),
        entry(
            "udp-pcm-loopback-localhost-smoke",
            .localhostSmoke,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed command",
            "UdpPcmLoopbackReport",
            .udpPcmLoopback,
            .loopbackMeasurement,
            false,
            "open-lola udp-pcm-loopback-localhost-smoke",
            ["Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift"],
            ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"],
            "Localhost loopback smoke exercises timing code and remains PARTIAL evidence."
        ),
        entry(
            "validate-network-diagnostics-report",
            .validator,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed-arity path argument",
            "NetworkDiagnosticsReport",
            .networkDiagnostics,
            .diagnosticOnly,
            false,
            "open-lola validate-network-diagnostics-report reports/diagnostics.json",
            ["Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift"],
            ["Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift"],
            "Diagnostics explain reachability and traceroute behavior but cannot replace a route report."
        ),
        entry(
            "network-diagnostics-run",
            .run,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "NetworkDiagnosticsRunConfiguration.parse",
            "NetworkDiagnosticsReport",
            .networkDiagnostics,
            .diagnosticOnly,
            false,
            "open-lola network-diagnostics-run --peer 10.10.20.10 --ping-count 3 --max-hops 8 --output reports/diagnostics.json",
            ["Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift"],
            ["Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift"],
            "Runtime diagnostics are support artifacts for route triage only."
        ),
        entry(
            "validate-nat-friendly-route-report",
            .validator,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed-arity path argument",
            "NatFriendlyRouteReport",
            .natFriendlyRoute,
            .natCompatibilityOnly,
            false,
            "open-lola validate-nat-friendly-route-report reports/nat-friendly.json",
            [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift",
            ],
            ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            "NAT-friendly reports distinguish direct traversal from relay fallback and cannot be direct-fastest evidence."
        ),
        entry(
            "validate-mac-to-mac-connection-establishment-report",
            .validator,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed-arity path argument",
            "MacToMacConnectionEstablishmentReport",
            .macToMacConnectionEstablishment,
            .connectionPreflight,
            false,
            "open-lola validate-mac-to-mac-connection-establishment-report reports/mac-to-mac-preflight.json",
            ["Sources/OpenLolaCore/Network/P2P/MacToMacConnectionEstablishment.swift"],
            ["Tests/OpenLolaCoreTests/MacToMacConnectionEstablishmentTests.swift"],
            "Validates the IP/NAT-first setup report. It can permit a later direct UDP/IP media launch, but is not measured media evidence by itself."
        ),
        entry(
            "mac-to-mac-connection-preflight-run",
            .run,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "MacToMacConnectionEstablishmentRunConfiguration.parse",
            "MacToMacConnectionEstablishmentReport",
            .macToMacConnectionEstablishment,
            .connectionPreflight,
            false,
            "open-lola mac-to-mac-connection-preflight-run --local-peer-id mac-a --remote-peer-id mac-b --peer 203.0.113.7 --nat-route-report reports/nat.json --output reports/mac-to-mac-preflight.json",
            [
                "Sources/OpenLolaCore/Network/P2P/MacToMacConnectionEstablishment.swift",
                "Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
            ],
            ["Tests/OpenLolaCoreTests/MacToMacConnectionEstablishmentTests.swift"],
            "Default mac-to-mac setup preflight. It records reachability and NAT route blockers before direct media state may be trusted."
        ),
        entry(
            "nat-friendly-route-run",
            .run,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "NatFriendlyRouteRunConfiguration.parse",
            "NatFriendlyRouteReport",
            .natFriendlyRoute,
            .natCompatibilityOnly,
            false,
            "open-lola nat-friendly-route-run --role sender --bind-host 0.0.0.0 --peer-id sender-a --rendezvous-host 10.0.0.2 --rendezvous-port 7000 --session-id s1 --port 5004 --duration-seconds 2 --keepalive-interval-ms 250 --output reports/nat.json",
            [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift",
            ],
            ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            "The runner emits PARTIAL compatibility evidence and keeps raw direct P2P as the default fastest path."
        ),
        entry(
            "nat-friendly-localhost-smoke",
            .localhostSmoke,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed command",
            "NatFriendlyRouteReport",
            .natFriendlyRoute,
            .natCompatibilityOnly,
            false,
            "open-lola nat-friendly-localhost-smoke",
            [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift",
            ],
            ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            "Local NAT-friendly smoke proves localhost compatibility only."
        ),
        entry(
            "nat-rendezvous-run",
            .run,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "NatRendezvousRunConfiguration.parse",
            "NatRendezvousReport",
            .natRendezvous,
            .natCompatibilityOnly,
            false,
            "open-lola nat-rendezvous-run --bind-host 0.0.0.0 --port 7000 --session-id s1 --mode directTraversal --expected-peers 2 --timeout-seconds 30 --output reports/rendezvous.json",
            [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift",
            ],
            ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            "Rendezvous records peer discovery and external endpoint observation, not media route superiority."
        ),
        entry(
            "nat-rendezvous-localhost-smoke",
            .localhostSmoke,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed command",
            "NatRendezvousLocalhostSmokeResult",
            .natRendezvous,
            .natCompatibilityOnly,
            false,
            "open-lola nat-rendezvous-localhost-smoke",
            [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift",
            ],
            ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            "Local rendezvous smoke validates discovery and handoff on localhost only."
        ),
        entry(
            "nat-relay-run",
            .run,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "NatRelayRunConfiguration.parse",
            "NatRelayReport",
            .natRelay,
            .natCompatibilityOnly,
            false,
            "open-lola nat-relay-run --bind-host 0.0.0.0 --port 7001 --session-id s1 --expected-peers 2 --timeout-seconds 30 --output reports/relay.json",
            [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift",
            ],
            ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            "Relay reports are compatibility fallback evidence and must never be fastest-path proof."
        ),
        entry(
            "nat-relay-fallback-localhost-smoke",
            .localhostSmoke,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed command",
            "NatRelayFallbackLocalhostSmokeResult",
            .natRelay,
            .natCompatibilityOnly,
            false,
            "open-lola nat-relay-fallback-localhost-smoke",
            [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift",
            ],
            ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            "Relay fallback smoke intentionally proves failed direct traversal before relay use."
        ),
        entry(
            "nat-rendezvous-forwarder-run",
            .run,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "NatRendezvousForwarderLauncherConfiguration.parse",
            "NatRendezvousForwarderLauncherReport",
            .natForwarder,
            .natCompatibilityOnly,
            false,
            "open-lola nat-rendezvous-forwarder-run --bind-host 0.0.0.0 --rendezvous-port 7000 --forwarder-port 7001 --session-id s1 --expected-peers 2 --timeout-seconds 30 --output reports/forwarder.json",
            ["Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift"],
            ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            "Forwarder launch reports carry an explicit performance warning and compatibility-only boundary."
        ),
        entry(
            "nat-rendezvous-forwarder-localhost-smoke",
            .localhostSmoke,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed command",
            "NatRendezvousForwarderLauncherReport",
            .natForwarder,
            .natCompatibilityOnly,
            false,
            "open-lola nat-rendezvous-forwarder-localhost-smoke",
            [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift",
            ],
            ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            "Local forwarder smoke checks argument/service boundaries without performance claims."
        ),
        entry(
            "validate-direct-p2p-session-report",
            .validator,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed-arity path argument",
            "DirectPeerSessionReport",
            .directPeerSession,
            .directPeerSessionPartialOnly,
            false,
            "open-lola validate-direct-p2p-session-report reports/direct-p2p.json",
            ["Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift"],
            ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            "Direct peer session validation currently rejects PASS until manual direct-LAN evidence exists."
        ),
        entry(
            "validate-direct-p2p-mesh-topology-report",
            .validator,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed-arity path argument",
            "DirectPeerMeshTopologyReport",
            .directPeerSession,
            .directPeerSessionPartialOnly,
            false,
            "open-lola validate-direct-p2p-mesh-topology-report reports/direct-p2p-mesh.json",
            ["Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift"],
            ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            "Mesh topology validation proves multi-peer route shape only; it carries no physical media evidence."
        ),
        entry(
            "validate-direct-p2p-mesh-runtime-report",
            .validator,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed-arity path argument",
            "DirectPeerMeshRuntimeReport",
            .directPeerSession,
            .directPeerSessionPartialOnly,
            false,
            "open-lola validate-direct-p2p-mesh-runtime-report reports/direct-p2p-mesh-runtime.json",
            ["Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift"],
            ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            "Mesh runtime validation proves localhost all-pairs UDP PCM v2 delivery only; physical route evidence remains required."
        ),
        entry(
            "validate-direct-p2p-two-peer-plan-report",
            .validator,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "fixed-arity path argument",
            "DirectPeerTwoPeerRunPlanReport",
            .directPeerSession,
            .directPeerSessionPartialOnly,
            false,
            "open-lola validate-direct-p2p-two-peer-plan-report reports/direct-p2p-two-peer-plan.json",
            ["Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift"],
            ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"],
            "Plan validation proves the two expected endpoint commands and report references exist; it does not validate measured media delivery."
        ),
        entry(
            "direct-p2p-two-peer-plan-run",
            .run,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "DirectPeerTwoPeerRunPlanConfiguration.parse",
            "DirectPeerTwoPeerRunPlanReport",
            .directPeerSession,
            .directPeerSessionPartialOnly,
            false,
            "open-lola direct-p2p-two-peer-plan-run --output reports/direct-p2p-two-peer-plan.json --run-dir reports/m06 --mac-a-peer mac-a --mac-a-host 192.0.2.10 --mac-a-port-base 57000 --mac-a-input-uid rme-a --mac-a-output-uid rme-a --mac-a-video-device-id camera-a --mac-b-peer mac-b --mac-b-host 192.0.2.20 --mac-b-port-base 57010 --mac-b-input-uid rme-b --mac-b-output-uid rme-b --mac-b-video-device-id camera-b --duration-seconds 30",
            ["Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift"],
            ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"],
            "Builds the paired Mac command plan and subordinate DirectPeerSessionReport paths before a physical two-peer run."
        ),
        entry(
            "direct-p2p-mesh-topology-synthetic-smoke",
            .syntheticSmoke,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "--output path and optional peer count",
            "DirectPeerMeshTopologyReport",
            .directPeerSession,
            .directPeerSessionPartialOnly,
            false,
            "open-lola direct-p2p-mesh-topology-synthetic-smoke --output reports/direct-p2p-mesh.json",
            ["Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift"],
            ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            "Source-level three-or-more-peer topology smoke; runtime delivery evidence remains separate."
        ),
        entry(
            "direct-p2p-mesh-runtime-localhost-smoke",
            .localhostSmoke,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "--output path, optional peer count, and optional packet count",
            "DirectPeerMeshRuntimeReport",
            .directPeerSession,
            .directPeerSessionPartialOnly,
            false,
            "open-lola direct-p2p-mesh-runtime-localhost-smoke --output reports/direct-p2p-mesh-runtime.json",
            [
                "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift",
                "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift",
            ],
            ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            "Localhost mesh smoke routes UDP PCM v2 audio across every directed peer pair; it is not physical direct-LAN evidence."
        ),
        entry(
            "direct-p2p-session-run",
            .run,
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "--output path and optional packet count",
            "DirectPeerSessionReport",
            .directPeerSession,
            .directPeerSessionPartialOnly,
            false,
            "open-lola direct-p2p-session-run --output reports/direct-p2p.json",
            [
                "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift",
                "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift",
            ],
            ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            "Socket-backed direct-P2P run proves local control and media startup, not direct-LAN fastest evidence."
        ),
    ]

    private static func count(_ boundary: NetworkRouteEvidenceBoundary) -> Int {
        entries.filter { $0.evidenceBoundary == boundary }.count
    }
}

private func entry(
    _ command: String,
    _ kind: CLICommandKind,
    _ ownerSourceFile: String,
    _ parser: String,
    _ outputReport: String,
    _ routeMode: NetworkRouteMode,
    _ evidenceBoundary: NetworkRouteEvidenceBoundary,
    _ canContributeToFastestDirectEvidence: Bool,
    _ representativeCommand: String,
    _ relatedSourceFiles: [String],
    _ relatedTestFiles: [String],
    _ notes: String
) -> NetworkRouteCommandMatrixEntry {
    NetworkRouteCommandMatrixEntry(
        command: command,
        kind: kind,
        ownerSourceFile: ownerSourceFile,
        parser: parser,
        outputReport: outputReport,
        routeMode: routeMode,
        evidenceBoundary: evidenceBoundary,
        canContributeToFastestDirectEvidence: canContributeToFastestDirectEvidence,
        representativeCommand: representativeCommand,
        relatedSourceFiles: relatedSourceFiles,
        relatedTestFiles: relatedTestFiles,
        notes: notes
    )
}
