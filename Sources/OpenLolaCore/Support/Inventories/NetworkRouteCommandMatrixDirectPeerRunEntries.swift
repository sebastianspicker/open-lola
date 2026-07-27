// Collects source inventory evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

extension NetworkRouteCommandMatrix {
    static let directPeerRunEntries: [NetworkRouteCommandMatrixEntry] = [
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
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            notes: "Local forwarder smoke checks argument/service boundaries without " +
                "performance claims."
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
            notes: "Direct peer session validation currently rejects PASS until manual " +
                "direct-LAN evidence exists."
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
            representativeCommand: "open-lola verify-direct-p2p-session-evidence-bundle reports/direct-p2p.json " +
                ".",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift",
                "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionEvidenceBundleVerifier.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerSessionReportAVPassTests.swift"],
            notes: "PASS evidence promotion must prove declared Direct P2P artifacts " +
                "exist and match their SHA-256 hashes."
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
            representativeCommand: "open-lola validate-direct-p2p-mesh-topology-report " +
                "reports/direct-p2p-mesh.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            notes: "Mesh topology validation proves multi-peer route shape only; it " +
                "carries no physical media evidence."
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
            representativeCommand: "open-lola validate-direct-p2p-mesh-runtime-report " +
                "reports/direct-p2p-mesh-runtime.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            notes: "Mesh runtime validation proves localhost all-pairs UDP PCM v2 " +
                "delivery only; physical route evidence remains required."
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
            representativeCommand: "open-lola validate-direct-p2p-two-peer-plan-report " +
                "reports/direct-p2p-two-peer-plan.json",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"],
            notes: "Plan validation proves the two expected endpoint commands and report " +
                "references exist; it does not validate measured media delivery."
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
            representativeCommand: "open-lola direct-p2p-two-peer-plan-run --output " +
                "reports/direct-p2p-two-peer-plan.json --run-dir reports/m06 --mac-a-peer " +
                "mac-a --mac-a-host 192.0.2.10 --mac-a-port-base 57000 --mac-a-input-uid " +
                "rme-a --mac-a-output-uid rme-a --mac-a-video-device-id camera-a --mac-b-peer " +
                "mac-b --mac-b-host 192.0.2.20 --mac-b-port-base 57010 --mac-b-input-uid " +
                "rme-b --mac-b-output-uid rme-b --mac-b-video-device-id camera-b " +
                "--duration-seconds 30",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"],
            notes: "Builds the paired Mac command plan and subordinate " +
                "DirectPeerSessionReport paths before a physical two-peer run."
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
            representativeCommand: "open-lola direct-p2p-mesh-topology-synthetic-smoke --output " +
                "reports/direct-p2p-mesh.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            notes: "Source-level three-or-more-peer topology smoke; runtime delivery " +
                "evidence remains separate."
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
            representativeCommand: "open-lola direct-p2p-mesh-runtime-localhost-smoke --output " +
                "reports/direct-p2p-mesh-runtime.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift",
                "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            notes: "Localhost mesh smoke routes UDP PCM v2 audio across every directed " +
                "peer pair; it is not physical direct-LAN evidence."
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
                "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            notes: "Socket-backed direct-P2P run proves local control and media startup, " +
                "not direct-LAN fastest evidence."
        ))
    ]
}
