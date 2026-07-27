// Collects source inventory evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

extension NetworkRouteCommandMatrix {
    static let natAndPreflightEntries: [NetworkRouteCommandMatrixEntry] = [
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
            notes: "Loopback timing supports route analysis but is not direct " +
                "fastest-path proof by itself."
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
            representativeCommand: "open-lola validate-udp-pcm-loopback-session reports/sender.json " +
                "reports/looper.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"],
            notes: "Session-pair validation proves reciprocal loopback agreement, not " +
                "route superiority."
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
            representativeCommand: "open-lola udp-pcm-loopback-run --session-id s1 --role sender --bind-host " +
                "10.0.0.1 --peer 10.0.0.2 --port 5004 --sample-rate 48000 --frames 32 " +
                "--channels 2 --duration-seconds 2 --output reports/loopback.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"],
            notes: "Measured UDP loopback is supporting route evidence and must be " +
                "paired with route classification before promotion."
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
            representativeCommand: "open-lola validate-network-diagnostics-report " +
                "reports/diagnostics.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift"],
            notes: "Diagnostics explain reachability and traceroute behavior but cannot " +
                "replace a route report."
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
            representativeCommand: "open-lola network-diagnostics-run --peer 10.10.20.10 --ping-count 3 " +
                "--max-hops 8 --output reports/diagnostics.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift"
            ],
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
            representativeCommand: "open-lola validate-nat-friendly-route-report " +
                "reports/nat-friendly.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "NAT-friendly reports distinguish direct traversal from relay " +
                "fallback and cannot be direct-fastest evidence."
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
            representativeCommand: "open-lola validate-mac-to-mac-connection-establishment-report " +
                "reports/mac-to-mac-preflight.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/MacToMacConnectionEstablishment.swift"
            ],
            relatedTestFiles: [
                "Tests/OpenLolaCoreTests/MacToMacConnectionEstablishmentTests.swift"
            ],
            notes: "Validates the IP/NAT-first setup report. It can permit a later " +
                "direct UDP/IP media launch, but is not measured media evidence by " +
                "itself."
        ))
    ]
}
