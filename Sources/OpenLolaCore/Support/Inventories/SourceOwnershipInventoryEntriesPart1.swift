// Lists ownership, tests, risks, and move constraints for core, audio, vendor, and network source groups in the first inventory partition.
import Foundation

extension SourceOwnershipInventory {
    static let entriesPart1: [SourceOwnershipEntry] = [
        own(.init(
            group: .coreSupport,
            purpose: "Shared capability, identity, debug, JSON, validation, and CLI facade support.",
            currentSourcePaths: [
            "Sources/OpenLolaContracts/",
            "Sources/OpenLolaCore/Core/CapabilitySummary.swift", "Sources/OpenLolaCore/Core/OpenLolaCLI.swift",
            "Sources/OpenLolaCore/Core/PeerIdentity.swift", "Sources/OpenLolaCore/Core/DebugTrace.swift",
            "Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift",
            "Sources/OpenLolaCore/Core/ValidationPrimitives.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Core/", runtimeRole: .sharedSupport,
            owner: "Core runtime maintainer", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/CapabilitySummaryTests.swift", "Tests/OpenLolaCoreTests/DebugTraceTests.swift",
            "Tests/OpenLolaCoreTests/SessionProtocolTests.swift"
        ], relatedFixturePaths: [], relatedDocs: ["docs/current-state.md", "docs/open-lola-protocol.md"],
            refactorRisk: .low, moveState: .completedC02, status: .active,
            confidence: .confirmed, validationCommands: ["swift test --filter SourceOwnershipInventoryTests", "swift build"],
            improvementRecommendation: "Keep Core limited to pure shared support; do not add hardware run logic here.")),
        own(.init(
            group: .protocolSession,
            purpose: "Versioned session negotiation, control messages, and capability contracts.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Protocol/SessionControlMessage.swift",
                "Sources/OpenLolaCore/Protocol/SessionProtocol.swift",

            "Sources/OpenLolaCore/Protocol/SessionCapabilityValidating.swift",
            "Sources/OpenLolaCore/Protocol/SessionNegotiation.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Protocol/", runtimeRole: .protocolContract,
            owner: "Protocol owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/SessionProtocolTests.swift",
                "Tests/OpenLolaCoreTests/SessionNegotiationTests.swift"
        ], relatedFixturePaths: [], relatedDocs: ["docs/open-lola-protocol.md", "docs/e2e-p2p-session.md"],
            refactorRisk: .medium, moveState: .notSelected, status: .active, confidence: .confirmed,
            validationCommands: ["swift test --filter SessionProtocolTests"],
            improvementRecommendation: "Keep packet/session command docs synchronized with this protocol folder.")),
        own(.init(
            group: .audioCoreAudio,
            purpose: "macOS Core Audio inventory and audio stream description models.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventory.swift",
                "Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift",

            "Sources/OpenLolaCore/Audio/CoreAudio/AudioStreamDescription.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Audio/CoreAudio/", runtimeRole: .platformInventory,
            owner: "macOS audio integration owner", relatedTestFiles: ["Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift"],
            relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/CoreAudioInventory/valid/core-audio-inventory-valid.json"],
            relatedDocs: ["docs/audio-routing.md", "docs/audio-rme-madi.md"], refactorRisk: .medium,
            moveState: .notSelected, status: .active, confidence: .confirmed, validationCommands: ["swift test --filter CoreAudioInventoryTests"],
            improvementRecommendation: "Keep CoreAudio fixture and inventory command references synchronized.")),
        own(.init(
            group: .audioMadiRme,
            purpose: "RME/MADI TX, RX, full-duplex runtime, matrix metadata, and mix contracts.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Audio/MADI/",
            "Sources/OpenLolaCore/Audio/MADI/MadiTransmit.swift", "Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift",
            "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexRuntime.swift",
                "Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift",

            "Sources/OpenLolaCore/Audio/MADI/RmeMatrixMetadata.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Audio/MADI/", runtimeRole: .realtimeAudioPath,
            owner: "MADI/RME owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/MadiTransmitTests.swift", "Tests/OpenLolaCoreTests/MadiReceiveTests.swift",
            "Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift",
                "Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift"
        ], relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/RmeFastestAudioPathReports/valid/rme-fastest-audio-partial.json"],
            relatedDocs: ["docs/madi-full-rx-tx.md", "docs/rme-madi-routing.md"], refactorRisk: .high,
            moveState: .notSelected, status: .active, confidence: .confirmed,
            validationCommands: ["swift test --filter Madi", "swift test --filter RmeFastestAudioPathTests"],
            improvementRecommendation: "Keep command smoke ownership and hardware boundary docs synchronized with the MADI folder.")),
        own(.init(
            group: .audioRealtime,
            purpose: "Realtime engine, buffers, packet handoff, payload capture, and callback evidence.",
            currentSourcePaths: [
            "Sources/COpenLolaAtomics/",
            "Sources/OpenLolaCore/Audio/Realtime/",
            "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift",
                "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift",

            "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift",
                "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Audio/Realtime/", runtimeRole: .realtimeAudioPath,
            owner: "Realtime audio owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift",
            "Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift",
            "Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift"
        ], relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/RealtimeAudioEngineReports/valid/realtime-audio-engine-partial.json"],
            relatedDocs: ["docs/latency-first-architecture.md", "docs/current-state.md"], refactorRisk: .high,
            moveState: .notSelected, status: .active, confidence: .confirmed, validationCommands: ["swift test --filter RealtimeAudio"],
            improvementRecommendation: "Keep latency benchmark and callback constraints visible when changing realtime code.")),
        own(.init(
            group: .audioRouting,
            purpose: "Direct media routing and audio routing assumption ledgers.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Audio/Routing/",
            "Sources/OpenLolaCore/Audio/Routing/DirectAudioMediaRouter.swift",
                "Sources/OpenLolaCore/Audio/Routing/AudioRoutingAssumptionLedger.swift",

            "Sources/OpenLolaCore/Audio/Routing/ReceiverMixSnapshot.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Audio/Routing/", runtimeRole: .mediaRouting,
            owner: "Audio routing owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift",
                "Tests/OpenLolaCoreTests/MultichannelTransportTests.swift"
        ], relatedFixturePaths: [], relatedDocs: ["docs/audio-routing.md", "docs/multichannel-audio-routing.md"],
            refactorRisk: .medium, moveState: .notSelected, status: .active, confidence: .likely,
            validationCommands: ["swift test --filter AudioLoopbackRunTests"],
            improvementRecommendation: "Keep receiver mix contracts under generic routing unless MADI-specific behavior is introduced.")),
        own(.init(
            group: .thirdPartyVendoredCode,
            purpose: "Vendored Opus and JPEG XS reference drops plus local bridge files.",
            currentSourcePaths: [
            "Sources/opus-1.5.2/",
            "Sources/xs_ref_sw_ed2/"
        ], proposedSourcePath: "Sources/ThirdParty/", runtimeRole: .thirdPartyVendorFence,
            owner: "Maintainer/legal review owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift",
            "Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift"
        ], relatedFixturePaths: [], relatedDocs: [
            "THIRD_PARTY_NOTICES.md",
            "docs/release-boundary.md",
            "docs/release-manifest.md"
        ], refactorRisk: .high, moveState: .notSelected, status: .needsHumanReview, confidence: .confirmed, validationCommands: [
            "swift test --filter ReleaseArtifactHygieneContractTests",
            "swift test --filter SourceOwnershipInventoryTests",
            "bash scripts/export-release-candidate.sh /tmp/open-lola-release-check"
        ],
            improvementRecommendation: "Do not treat upstream vendor internals as first-party refactor targets; keep local patches in the " +
                "documented bridge/manifest path and review license impact before release.")),

        own(.init(
            group: .networkUdp,
            purpose: "UDP PCM packets, socket operations, route runs, loopback, and multichannel transport.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Network/UDP/",
            "Sources/OpenLolaCore/Network/RTP/",
            "Sources/OpenLolaCore/Audio/Codecs/OpusCELTLowDelayCodec.swift",
            "Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift",

            "Sources/OpenLolaCore/Network/UDP/UdpPcmDataHelpers.swift",
            "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift",

            "Sources/OpenLolaCore/Network/UDP/MultichannelTransport.swift",
            "Sources/OpenLolaCore/Network/RTP/AES67ST2110L24Transport.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Network/UDP/", runtimeRole: .networkTransport,
            owner: "UDP transport owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift", "Tests/OpenLolaCoreTests/UdpPcmV2PacketTests.swift",
            "Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift",
                "Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift",

            "Tests/OpenLolaCoreTests/AES67ST2110L24TransportTests.swift"
        ], relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-int16.hex"],
            relatedDocs: ["docs/multichannel-transport.md", "docs/current-state.md"], refactorRisk: .high,
            moveState: .notSelected, status: .active, confidence: .confirmed, validationCommands: ["swift test --filter Udp"],
            improvementRecommendation: "Keep CLI commands and packet fixtures synchronized with UDP path changes.")),

        own(.init(
            group: .networkP2P,
            purpose: "Direct P2P session, localhost proof, route certification, and endpoint reports.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Network/P2P/",
            "Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift",
                "Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerRTPAudio.swift",

            "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift",
            "Sources/OpenLolaCore/Network/P2P/DirectP2PLocalhostSmoke.swift",
            "Sources/OpenLolaCore/Network/P2P/MacToMacRouteCertification.swift",
                "Sources/OpenLolaCore/Network/P2P/EndpointLoopbackReport.swift",

            "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift",
            "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Network/P2P/", runtimeRole: .routeProof,
            owner: "P2P route owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift",
                "Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift",

            "Tests/OpenLolaCoreTests/EndpointLoopbackReportTests.swift"
        ], relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/EndpointLoopback/valid/endpoint-loopback-valid.json"],
            relatedDocs: ["docs/e2e-p2p-session.md", "docs/p2p-networking.md"], refactorRisk: .high,
            moveState: .notSelected, status: .active, confidence: .confirmed, validationCommands: ["swift test --filter PeerSessionRunnerTests"],
            improvementRecommendation: "Keep route semantics traceable when changing P2P path or report ownership.")),
        own(.init(
            group: .networkNat,
            purpose: "NAT rendezvous, relay, fallback, and compatibility reports.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Network/NAT/",
            "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
                "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift",

            "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift",
                "Sources/OpenLolaCore/Network/NAT/NatRendezvousRelayRunners.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Network/NAT/", runtimeRole: .compatibilityPath,
            owner: "NAT compatibility owner", relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            relatedFixturePaths: [], relatedDocs: ["docs/p2p-networking.md", "docs/current-state.md"],
            refactorRisk: .high, moveState: .notSelected, status: .active, confidence: .confirmed,
            validationCommands: ["swift test --filter NatFriendlyRouteTests"],
            improvementRecommendation: "Keep separate from fastest-direct route evidence and move after C05 matrix stays green.")),
        own(.init(
            group: .networkDiagnosticsAoip,
            purpose: "Network diagnostics, AoIP evaluation, and AVB certification reports.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Network/Diagnostics/",
            "Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift",
                "Sources/OpenLolaCore/Network/Diagnostics/AoipEvaluationReport.swift",

            "Sources/OpenLolaCore/Network/Diagnostics/NetworkAoipCertification.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Network/Diagnostics/", runtimeRole: .diagnosticGate,
            owner: "Network diagnostics owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift",
                "Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift",

            "Tests/OpenLolaCoreTests/NetworkAoipCertificationTests.swift"
        ], relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/AoipEvaluationReports/valid/aoip-avb-partial.json"],
            relatedDocs: ["docs/p2p-networking.md", "docs/current-state.md"], refactorRisk: .medium,
            moveState: .notSelected, status: .active, confidence: .confirmed, validationCommands: ["swift test --filter NetworkDiagnosticsTests"],
            improvementRecommendation: "Keep diagnostics separate from route proof in docs and reports.")),
        own(.init(
            group: .externalConnectors,
            purpose: "Protocol-aware external connector descriptors and TX/RX launch sessions for LoLa, MVTP/UltraGrid, and " +
                "JackTrip.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Connectors/",
            "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorReport.swift",
            "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSession.swift",
            "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRunner.swift",
            "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorSessionRuntime.swift",
            "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorParsingDefaults.swift",
            "Sources/OpenLolaCore/Connectors/Core/ExternalConnectorExecutablePreflight.swift",
            "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorConnectionPlan.swift",
            "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPlan.swift",
            "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpPreflight.swift",
            "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpEndpointRun.swift",
            "Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpWorkflow.swift",
            "Sources/OpenLolaCore/Connectors/JackTrip/JackTripLaunchPlan.swift",
            "Sources/OpenLolaCore/Connectors/JackTrip/JackTripAuxiliaryVideoPlan.swift",
            "Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridLaunchPlan.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaConnectorLaunchPlan.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaConnectorRawLinkMediaEvidence.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaControlNetworkPreflight.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaTcpControlExchangeRuntime.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityControlMessage.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaModel.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityWireFrame.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaSession.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityRawLink.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReport.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityPacketFixture.swift",
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityControlSocket.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Connectors/", runtimeRole: .compatibilityPath,
            owner: "External connector owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/ExternalConnectorReportTests.swift",
            "Tests/OpenLolaCoreTests/ExternalConnectorSessionTests.swift",
            "Tests/OpenLolaCoreTests/ExternalConnectorAvMatrixTests.swift",
            "Tests/OpenLolaCoreTests/ExternalConnectorConnectionPlanTests.swift",
            "Tests/OpenLolaCoreTests/ExternalConnectorNmpPlanTests.swift",
            "Tests/OpenLolaCoreTests/ExternalConnectorNmpPreflightTests.swift",
            "Tests/OpenLolaCoreTests/ExternalConnectorNmpEndpointRunTests.swift",
            "Tests/OpenLolaCoreTests/ExternalConnectorNmpWorkflowTests.swift",
            "Tests/OpenLolaCoreTests/ExternalConnectorExecutablePreflightTests.swift",
            "Tests/OpenLolaCoreTests/ExternalConnectorLoLaMediaEvidenceTests.swift",
            "Tests/OpenLolaCoreTests/ExternalConnectorProcessGroupTests.swift",
            "Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift",
            "Tests/OpenLolaCoreTests/LoLaCompatibilityCaptureReportTests.swift",
            "Tests/OpenLolaCoreTests/LoLaCompatibilityPacketFixtureTests.swift",
            "Tests/OpenLolaCoreTests/LoLaCompatibilityControlSocketTests.swift"
        ], relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/ExternalConnectorReports/valid/external-connectors-source-pass.json"],
            relatedDocs: ["docs/current-state.md"], refactorRisk: .medium, moveState: .notSelected, status: .active,
            confidence: .confirmed,
            validationCommands: ["swift test --filter ExternalConnectorReportTests",
                "swift test --filter ExternalConnectorSessionTests",
                "swift test --filter ExternalConnectorAvMatrixTests",
                "swift test --filter ExternalConnectorConnectionPlanTests",
                "swift test --filter ExternalConnectorNmpPlanTests",
                "swift test --filter ExternalConnectorNmpPreflightTests",
                "swift test --filter ExternalConnectorNmpEndpointRunTests",
                "swift test --filter ExternalConnectorNmpWorkflowTests",
                "swift test --filter ExternalConnectorExecutablePreflightTests",
                "swift test --filter LoLaCompatibilityMediaSessionTests",
                "swift test --filter LoLaCompatibilityPacketFixtureTests"],

            improvementRecommendation: "Keep connector PASS blocked until measured external endpoint evidence exists."))
    ]
}
