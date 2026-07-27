// Collects measurement evidence evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
extension ReportSchemaInventory {
    static let entriesPart1: [ReportSchemaInventoryEntry] = [
        schema(.init(
            name: "ReferenceRigReport",
            family: "hardware baseline",
            evidenceClass: .externalWitnessed,
            sourceFile: "Sources/OpenLolaCore/Evidence/ReferenceRigReport.swift",
            validationFiles: ["Sources/OpenLolaCore/Evidence/ReferenceRigReportValidation.swift"],
            validatorCommands: ["validate-reference-rig-report"],
            fixtureGroup: "ReferenceRigReports",
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/ReferenceRigReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires two reference Macs, RME MADI path, direct wired profile, and DSCP classification."
        )),
        schema(.init(
            name: "EndpointLoopbackReport",
            family: "audio endpoint loopback",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Network/P2P/EndpointLoopbackReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-loopback-report"],
            fixtureGroup: "EndpointLoopback",
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/EndpointLoopbackReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires measured loopback metrics and stable accepted buffer rows."
        )),
        schema(.init(
            name: "RmeFastestAudioPathReport",
            family: "RME fastest audio path",
            evidenceClass: .externalWitnessed,
            sourceFile: "Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift",
            validationFiles: [],
            validatorCommands: ["validate-rme-fastest-audio-report"],
            fixtureGroup: "RmeFastestAudioPathReports",
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires visible RME device, driver evidence, and accepted loopback matrix."
        )),
        schema(.init(
            name: "AudioLoopbackRunReport",
            family: "audio loopback run",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift",
            validationFiles: [
                            "Sources/OpenLolaCore/Audio/Routing/AudioLoopbackHelpers.swift",
                            "Sources/OpenLolaCore/Audio/Routing/AudioRoutingValidators.swift"
            ],
            validatorCommands: ["validate-audio-loopback-run-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "Core Audio loopback run records selected devices, preflight, callback, handoff, and" +
                    " cleanup evidence. Single-run PASS is intentionally forbidden; measured closure requires" +
                    " aggregate acceptance with visible hardware evidence."
        )),
        schema(.init(
            name: "RealtimeAudioEngineReport",
            family: "realtime audio engine",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift",
            validationFiles: [],
            validatorCommands: ["validate-realtime-audio-engine-report"],
            fixtureGroup: "RealtimeAudioEngineReports",
            syntheticSmokeCommand: "realtime-audio-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS rejects synthetic runs, callback allocation, unbounded handoff, and buffered playout targets."
        )),
        schema(.init(
            name: "UdpPcmPacket",
            family: "UDP PCM packet contract",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift",
            validationFiles: [],
            validatorCommands: ["validate-udp-pcm-packet"],
            fixtureGroup: "UdpPcmPackets",
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes: "Packet validator proves binary contract shape, not runtime route readiness."
        )),
        schema(.init(
            name: "UdpPcmRouteReport",
            family: "UDP PCM route",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift",
            validationFiles: [],
            validatorCommands: ["validate-route-report"],
            fixtureGroup: "UdpPcmRoutes",
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires measured physical route evidence and bounded packet-age metrics."
        )),
        schema(.init(
            name: "MacToMacRouteCertificationReport",
            family: "Mac-to-Mac route certification",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Network/P2P/MacToMacRouteCertification.swift",
            validationFiles: [],
            validatorCommands: ["validate-route-certification-report"],
            fixtureGroup: "MacToMacRouteCertificationReports",
            syntheticSmokeCommand: "route-certification-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires direct-link route first and capture artifacts."
        )),
        schema(.init(
            name: "UdpPcmLoopbackReport",
            family: "UDP PCM loopback",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift",
            validationFiles: [],
            validatorCommands: ["validate-udp-pcm-loopback-report", "validate-udp-pcm-loopback-session"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "Session-pair validator compares two loopback reports for role, peer, port, packet-mode," +
                    " and duration consistency."
        )),
        schema(.init(
            name: "NetworkDiagnosticsReport",
            family: "network diagnostics",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift",
            validationFiles: [],
            validatorCommands: ["validate-network-diagnostics-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes: "Diagnostics are supporting evidence and cannot replace route certification."
        )),
        schema(.init(
            name: "NatFriendlyRouteReport",
            family: "NAT-friendly route",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift",
            validationFiles: [],
            validatorCommands: ["validate-nat-friendly-route-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "PASS requires direct traversal, raw P2P preference, passing loopback evidence, and a" +
                    " raw-route baseline; rendezvous-only and relay fallback remain compatibility-only."
        )),
        schema(.init(
            name: "MacToMacConnectionEstablishmentReport",
            family: "Mac-to-Mac connection establishment",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Network/P2P/MacToMacConnectionEstablishment.swift",
            validationFiles: [],
            validatorCommands: ["validate-mac-to-mac-connection-establishment-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/MacToMacConnectionEstablishmentTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Source-level setup contract for the IP/NAT-first default. PASS requires IP/NAT setup" +
                    " mode, passing diagnostics, passing NAT direct traversal evidence, direct UDP/IP" +
                    " selected route, no blockers, and no SSH or relay fallback."
        )),
        schema(.init(
            name: "DirectPeerSessionReport",
            family: "direct P2P session",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-direct-p2p-session-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "Direct peer session evidence covers socket-backed control agreement and media endpoint" +
                    " startup; PASS still requires direct-LAN evidence."
        )),
        schema(.init(
            name: "DirectPeerTwoPeerRunPlanReport",
            family: "direct P2P two-peer run plan",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift",
            validationFiles: [],
            validatorCommands: ["validate-direct-p2p-two-peer-plan-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Builds the responder/initiator command pair, explicit DirectPeerSessionReport" +
                    " references, and required evidence gates; PASS remains blocked until measured" +
                    " subordinate reports exist."
        )),
        schema(.init(
            name: "DirectPeerTwoPeerPrototypeReport",
            family: "direct P2P two-peer prototype",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerRunPlan.swift",
            validationFiles: [],
            validatorCommands: ["validate-direct-p2p-two-peer-report", "validate-direct-p2p-two-peer-prototype-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: [
                            "Tests/OpenLolaCoreTests/DirectPeerTwoPeerPrototypeReportTests.swift",
                            "Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"
            ],
            passRequiresMeasuredEvidence: true,
            notes:
                "Aggregates two validated DirectPeerSessionReport files and optional RX proof artifacts;" +
                    " PASS requires both subordinate reports and both RX proofs. The non-prototype validator" +
                    " is the canonical CLI surface; the prototype validator remains available for" +
                    " compatibility."
        )),
        schema(.init(
            name: "DirectPeerTwoPeerLocalRunReport",
            family: "direct P2P two-peer local supervisor",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-direct-p2p-two-peer-local-run-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/DirectPeerTwoPeerRunPlanTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Records dry-run or same-host supervisor launch state for the two planned peer commands;" +
                    " physical two-Mac PASS still requires measured subordinate reports."
        )),
        schema(.init(
            name: "DirectPeerMeshTopologyReport",
            family: "direct P2P mesh topology",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-direct-p2p-mesh-topology-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: "direct-p2p-mesh-topology-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Source-level topology smoke validates three-or-more-peer endpoint and directed route" +
                    " shape; PASS still requires physical multi-peer media evidence."
        ))
    ]
}
