// Validates NetworkRouteCommandMatrixDirectPeerValidationEntries acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension NetworkRouteCommandMatrix {
    static let directPeerValidationEntries: [NetworkRouteCommandMatrixEntry] = [
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "mac-to-mac-connection-preflight-run",
            kind: .run,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "MacToMacConnectionEstablishmentRunConfiguration.parse",
            outputReport: "MacToMacConnectionEstablishmentReport",
            routeMode: .macToMacConnectionEstablishment,
            evidenceBoundary: .connectionPreflight,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola mac-to-mac-connection-preflight-run --local-peer-id mac-a " +
                "--remote-peer-id mac-b --peer 203.0.113.7 --nat-route-report " +
                "reports/nat.json --output reports/mac-to-mac-preflight.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/MacToMacConnectionEstablishment.swift",
                "Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift"
            ],
            relatedTestFiles: [
                "Tests/OpenLolaCoreTests/MacToMacConnectionEstablishmentTests.swift"
            ],
            notes: "Default mac-to-mac setup preflight. It records reachability and NAT " +
                "route blockers before direct media state may be trusted."
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
            representativeCommand: "open-lola nat-friendly-route-run --role sender --bind-host 0.0.0.0 --peer-id " +
                "sender-a --rendezvous-host 10.0.0.2 --rendezvous-port 7000 --session-id s1 " +
                "--port 5004 --duration-seconds 2 --keepalive-interval-ms 250 --output " +
                "reports/nat.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "The runner emits PARTIAL compatibility evidence and keeps raw direct " +
                "P2P as the default fastest path."
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
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift"
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
            representativeCommand: "open-lola nat-rendezvous-run --bind-host 0.0.0.0 --port 7000 --session-id s1 " +
                "--mode directTraversal --expected-peers 2 --timeout-seconds 30 --output " +
                "reports/rendezvous.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "Rendezvous records peer discovery and external endpoint observation, " +
                "not media route superiority."
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
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift"
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
            representativeCommand: "open-lola nat-relay-run --bind-host 0.0.0.0 --port 7001 --session-id s1 " +
                "--expected-peers 2 --timeout-seconds 30 --output reports/relay.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "Relay reports are compatibility fallback evidence and must never be " +
                "fastest-path proof."
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
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "Relay fallback smoke intentionally proves failed direct traversal " +
                "before relay use."
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
            representativeCommand: "open-lola nat-rendezvous-forwarder-run --bind-host 0.0.0.0 --rendezvous-port " +
                "7000 --forwarder-port 7001 --session-id s1 --expected-peers 2 " +
                "--timeout-seconds 30 --output reports/forwarder.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "Forwarder launch reports carry an explicit performance warning and " +
                "compatibility-only boundary."
        ))
    ]
}
