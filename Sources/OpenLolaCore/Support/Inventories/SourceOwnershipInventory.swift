import Foundation

public enum SourceOwnershipGroup: String, Codable, Sendable {
    case coreSupport
    case protocolSession
    case audioCoreAudio
    case audioMadiRme
    case audioRealtime
    case audioRouting
    case networkUdp
    case networkP2P
    case networkNat
    case networkDiagnosticsAoip
    case externalConnectors
    case timingLatencyBuffering
    case videoCaptureTransport
    case controlLightingAtemOsc
    case evidenceReportsValidation
    case benchmarksPerformance
    case releaseProofPackaging
    case platformAppShell
    case cliApplication
    case releaseReadinessInventories
    case thirdPartyVendoredCode
}

public enum SourceOwnershipRuntimeRole: String, Codable, Sendable {
    case sharedSupport
    case protocolContract
    case platformInventory
    case realtimeAudioPath
    case mediaRouting
    case networkTransport
    case routeProof
    case compatibilityPath
    case diagnosticGate
    case timingAndBuffering
    case videoPath
    case externalControlGate
    case evidenceContract
    case benchmarkContract
    case releaseGate
    case appShellBoundary
    case commandSurface
    case reviewInventory
    case thirdPartyVendorFence
}

public enum SourceOwnershipRisk: String, Codable, Sendable {
    case low
    case medium
    case high
}

public enum SourceOwnershipStatus: String, Codable, Sendable {
    case active
    case partiallyActive
    case deferred
    case needsHumanReview
}

public enum SourceOwnershipConfidence: String, Codable, Sendable {
    case confirmed
    case likely
    case inferred
    case unclear
}

public struct SourceOwnershipEntry: Codable, Equatable, Sendable {
    public let group: SourceOwnershipGroup
    public let purpose: String
    public let currentSourcePaths: [String]
    public let proposedSourcePath: String
    public let runtimeRole: SourceOwnershipRuntimeRole
    public let owner: String
    public let relatedTestFiles: [String]
    public let relatedFixturePaths: [String]
    public let relatedDocs: [String]
    public let refactorRisk: SourceOwnershipRisk
    public let firstMoveCandidate: Bool
    public let movedInC02: Bool
    public let status: SourceOwnershipStatus
    public let confidence: SourceOwnershipConfidence
    public let validationCommands: [String]
    public let improvementRecommendation: String
}

public struct SourceOwnershipInventorySummary: Codable, Equatable, Sendable {
    public let groupCount: Int
    public let lowRiskCount: Int
    public let mediumRiskCount: Int
    public let highRiskCount: Int
    public let firstMoveCandidateCount: Int
    public let movedInC02Count: Int
}

public struct SourceOwnershipInventoryReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: SourceOwnershipInventorySummary
    public let entries: [SourceOwnershipEntry]
    public let notes: String
}

public enum SourceOwnershipPathMatchKind: String, Codable, Equatable, Sendable {
    case exactPath
    case ownedDirectory
    case proposedRoot
}

public struct SourceOwnershipPathResolution: Codable, Equatable, Sendable {
    public let entry: SourceOwnershipEntry
    public let matchKind: SourceOwnershipPathMatchKind
    public let matchedPath: String
}

public struct SourceOwnershipCoverageReport: Codable, Equatable, Sendable {
    public let unmatched: [String]
    public let fallbackOnly: [String]
}

public enum SourceOwnershipInventory {
    public static func report() -> SourceOwnershipInventoryReport {
        SourceOwnershipInventoryReport(
            id: "c02-source-ownership-inventory",
            title: "C02 core source ownership split inventory",
            verdict: .partial,
            summary: summary(),
            entries: entries,
            notes: "Executable source/test/doc ownership crosswalk. C02 moves only the low-risk Core support batch; high-risk runtime groups remain explicitly deferred."
        )
    }

    public static func summary() -> SourceOwnershipInventorySummary {
        SourceOwnershipInventorySummary(
            groupCount: entries.count,
            lowRiskCount: count(.low),
            mediumRiskCount: count(.medium),
            highRiskCount: count(.high),
            firstMoveCandidateCount: entries.filter(\.firstMoveCandidate).count,
            movedInC02Count: entries.filter(\.movedInC02).count
        )
    }

    public static func entry(for group: SourceOwnershipGroup) -> SourceOwnershipEntry? {
        entries.first { $0.group == group }
    }

    public static func entry(forSourcePath path: String) -> SourceOwnershipEntry? {
        resolution(forSourcePath: path)?.entry
    }

    public static func resolution(forSourcePath path: String) -> SourceOwnershipPathResolution? {
        if let exact = entries.first(where: { $0.currentSourcePaths.contains(path) }) {
            return SourceOwnershipPathResolution(entry: exact, matchKind: .exactPath, matchedPath: path)
        }
        if let directory = entries.compactMap({ entry -> SourceOwnershipPathResolution? in
            guard let matchedPath = entry.currentSourcePaths.first(where: {
                $0.hasSuffix("/") && path.hasPrefix($0)
            }) else {
                return nil
            }
            return SourceOwnershipPathResolution(entry: entry, matchKind: .ownedDirectory, matchedPath: matchedPath)
        }).first {
            return directory
        }
        if let proposedRoot = entries.first(where: { path.hasPrefix($0.proposedSourcePath) }) {
            return SourceOwnershipPathResolution(
                entry: proposedRoot,
                matchKind: .proposedRoot,
                matchedPath: proposedRoot.proposedSourcePath
            )
        }
        return nil
    }

    public static func coverage(forSourcePaths paths: [String]) -> SourceOwnershipCoverageReport {
        var unmatched: [String] = []

        for path in paths.sorted() {
            guard resolution(forSourcePath: path) != nil else {
                unmatched.append(path)
                continue
            }
        }

        return SourceOwnershipCoverageReport(unmatched: unmatched, fallbackOnly: [])
    }

    public static let entries: [SourceOwnershipEntry] = [
        own(.coreSupport, "Shared capability, identity, debug, JSON, validation, and CLI facade support.", [
            "Sources/OpenLolaContracts/",
            "Sources/OpenLolaCore/Core/CapabilitySummary.swift", "Sources/OpenLolaCore/Core/OpenLolaCLI.swift",
            "Sources/OpenLolaCore/Core/PeerIdentity.swift", "Sources/OpenLolaCore/Core/DebugTrace.swift",
            "Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift",
            "Sources/OpenLolaCore/Core/ValidationPrimitives.swift",
        ], "Sources/OpenLolaCore/Core/", .sharedSupport, "Core runtime maintainer", [
            "Tests/OpenLolaCoreTests/CapabilitySummaryTests.swift", "Tests/OpenLolaCoreTests/DebugTraceTests.swift",
            "Tests/OpenLolaCoreTests/SessionProtocolTests.swift",
        ], [], ["docs/implementation-handoff.md", "docs/open-lola-protocol.md"], .low,
            firstMoveCandidate: true, movedInC02: true, .active, .confirmed,
            ["swift test --filter SourceOwnershipInventoryTests", "swift build"],
            "Keep Core limited to pure shared support; do not add hardware run logic here."),
        own(.protocolSession, "Versioned session negotiation, control messages, and capability contracts.", [
            "Sources/OpenLolaCore/Protocol/SessionControlMessage.swift", "Sources/OpenLolaCore/Protocol/SessionProtocol.swift",
            "Sources/OpenLolaCore/Protocol/SessionCapabilityValidating.swift",
            "Sources/OpenLolaCore/Protocol/SessionNegotiation.swift",
        ], "Sources/OpenLolaCore/Protocol/", .protocolContract, "Protocol owner", [
            "Tests/OpenLolaCoreTests/SessionProtocolTests.swift", "Tests/OpenLolaCoreTests/SessionNegotiationTests.swift",
        ], [], ["docs/open-lola-protocol.md", "docs/e2e-p2p-session.md"], .medium,
            .active, .confirmed, ["swift test --filter SessionProtocolTests"],
            "Keep packet/session command docs synchronized with this protocol folder."),
        own(.audioCoreAudio, "macOS Core Audio inventory and audio stream description models.", [
            "Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventory.swift", "Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift",
            "Sources/OpenLolaCore/Audio/CoreAudio/AudioStreamDescription.swift",
        ], "Sources/OpenLolaCore/Audio/CoreAudio/", .platformInventory, "macOS audio integration owner",
            ["Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift"],
            ["Tests/OpenLolaCoreTests/Fixtures/CoreAudioInventory/valid/core-audio-inventory-valid.json"],
            ["docs/audio-routing.md", "docs/audio-rme-madi.md"], .medium, .active,
            .confirmed, ["swift test --filter CoreAudioInventoryTests"],
            "Keep CoreAudio fixture and inventory command references synchronized."),
        own(.audioMadiRme, "RME/MADI TX, RX, full-duplex runtime, matrix metadata, and mix contracts.", [
            "Sources/OpenLolaCore/Audio/MADI/",
            "Sources/OpenLolaCore/Audio/MADI/MadiTransmit.swift", "Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift",
            "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexRuntime.swift", "Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift",
            "Sources/OpenLolaCore/Audio/MADI/RmeMatrixMetadata.swift",
        ], "Sources/OpenLolaCore/Audio/MADI/", .realtimeAudioPath, "MADI/RME owner", [
            "Tests/OpenLolaCoreTests/MadiTransmitTests.swift", "Tests/OpenLolaCoreTests/MadiReceiveTests.swift",
            "Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift", "Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift",
        ], ["Tests/OpenLolaCoreTests/Fixtures/RmeFastestAudioPathReports/valid/rme-fastest-audio-partial.json"],
            ["docs/madi-full-rx-tx.md", "docs/rme-madi-routing.md"], .high, .active,
            .confirmed, ["swift test --filter Madi", "swift test --filter RmeFastestAudioPathTests"],
            "Keep command smoke ownership and hardware boundary docs synchronized with the MADI folder."),
        own(.audioRealtime, "Realtime engine, buffers, packet handoff, payload capture, and callback evidence.", [
            "Sources/COpenLolaAtomics/",
            "Sources/OpenLolaCore/Audio/Realtime/",
            "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift", "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift",
            "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift", "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift",
        ], "Sources/OpenLolaCore/Audio/Realtime/", .realtimeAudioPath, "Realtime audio owner", [
            "Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift",
            "Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift",
            "Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift",
        ], ["Tests/OpenLolaCoreTests/Fixtures/RealtimeAudioEngineReports/valid/realtime-audio-engine-partial.json"],
            ["docs/latency-first-architecture.md", "docs/implementation-handoff.md"], .high,
            .active, .confirmed, ["swift test --filter RealtimeAudio"],
            "Keep latency benchmark and callback constraints visible when changing realtime code."),
        own(.audioRouting, "Direct media routing and audio routing assumption ledgers.", [
            "Sources/OpenLolaCore/Audio/Routing/",
            "Sources/OpenLolaCore/Audio/Routing/DirectAudioMediaRouter.swift", "Sources/OpenLolaCore/Audio/Routing/AudioRoutingAssumptionLedger.swift",
            "Sources/OpenLolaCore/Audio/Routing/ReceiverMixSnapshot.swift",
        ], "Sources/OpenLolaCore/Audio/Routing/", .mediaRouting, "Audio routing owner", [
            "Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift", "Tests/OpenLolaCoreTests/MultichannelTransportTests.swift",
        ], [], ["docs/audio-routing.md", "docs/multichannel-audio-routing.md"], .medium, .active,
            .likely, ["swift test --filter AudioLoopbackRunTests"],
            "Keep receiver mix contracts under generic routing unless MADI-specific behavior is introduced."),
        own(.thirdPartyVendoredCode, "Vendored Opus and JPEG XS reference drops plus local bridge files.", [
            "Sources/opus-1.5.2/",
            "Sources/xs_ref_sw_ed2/",
        ], "Sources/ThirdParty/", .thirdPartyVendorFence, "Maintainer/legal review owner", [
            "Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift",
            "Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift",
        ], [], [
            "THIRD_PARTY_NOTICES.md",
            "docs/release-boundary.md",
            "docs/release-manifest.md",
        ], .high, .needsHumanReview, .confirmed, [
            "swift test --filter ReleaseArtifactHygieneContractTests",
            "swift test --filter SourceOwnershipInventoryTests",
            "bash scripts/export-release-candidate.sh /tmp/open-lola-release-check",
        ],
            "Do not treat upstream vendor internals as first-party refactor targets; keep local patches in the documented bridge/manifest path and review license impact before release."),
        own(.networkUdp, "UDP PCM packets, socket operations, route runs, loopback, and multichannel transport.", [
            "Sources/OpenLolaCore/Network/UDP/",
            "Sources/OpenLolaCore/Network/RTP/",
            "Sources/OpenLolaCore/Audio/Codecs/OpusCELTLowDelayCodec.swift",
            "Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift", "Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift",
            "Sources/OpenLolaCore/Network/UDP/UdpPcmDataHelpers.swift",
            "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift", "Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift",
            "Sources/OpenLolaCore/Network/UDP/MultichannelTransport.swift",
            "Sources/OpenLolaCore/Network/RTP/AES67ST2110L24Transport.swift",
        ], "Sources/OpenLolaCore/Network/UDP/", .networkTransport, "UDP transport owner", [
            "Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift", "Tests/OpenLolaCoreTests/UdpPcmV2PacketTests.swift",
            "Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift", "Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift",
            "Tests/OpenLolaCoreTests/AES67ST2110L24TransportTests.swift",
        ], ["Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-int16.hex"],
            ["docs/multichannel-transport.md", "docs/implementation-handoff.md"], .high, .active,
            .confirmed, ["swift test --filter Udp"], "Keep CLI commands and packet fixtures synchronized with UDP path changes."),
        own(.networkP2P, "Direct P2P session, localhost proof, route certification, and endpoint reports.", [
            "Sources/OpenLolaCore/Network/P2P/",
            "Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift", "Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerRTPAudio.swift",
            "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVAudioLoops.swift",
            "Sources/OpenLolaCore/Network/P2P/DirectP2PLocalhostSmoke.swift",
            "Sources/OpenLolaCore/Network/P2P/MacToMacRouteCertification.swift", "Sources/OpenLolaCore/Network/P2P/EndpointLoopbackReport.swift",
            "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshTopologyReport.swift",
            "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift",
        ], "Sources/OpenLolaCore/Network/P2P/", .routeProof, "P2P route owner", [
            "Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift", "Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift",
            "Tests/OpenLolaCoreTests/EndpointLoopbackReportTests.swift",
        ], ["Tests/OpenLolaCoreTests/Fixtures/EndpointLoopback/valid/endpoint-loopback-valid.json"],
            ["docs/e2e-p2p-session.md", "docs/p2p-networking.md"], .high, .active,
            .confirmed, ["swift test --filter PeerSessionRunnerTests"],
            "Keep route semantics traceable when changing P2P path or report ownership."),
        own(.networkNat, "NAT rendezvous, relay, fallback, and compatibility reports.", [
            "Sources/OpenLolaCore/Network/NAT/",
            "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift", "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift",
            "Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift", "Sources/OpenLolaCore/Network/NAT/NatRendezvousRelayRunners.swift",
        ], "Sources/OpenLolaCore/Network/NAT/", .compatibilityPath, "NAT compatibility owner",
            ["Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift"], [],
            ["docs/p2p-networking.md", "docs/implementation-handoff.md"], .high, .active,
            .confirmed, ["swift test --filter NatFriendlyRouteTests"],
            "Keep separate from fastest-direct route evidence and move after C05 matrix stays green."),
        own(.networkDiagnosticsAoip, "Network diagnostics, AoIP evaluation, and AVB certification reports.", [
            "Sources/OpenLolaCore/Network/Diagnostics/",
            "Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift", "Sources/OpenLolaCore/Network/Diagnostics/AoipEvaluationReport.swift",
            "Sources/OpenLolaCore/Network/Diagnostics/NetworkAoipCertification.swift",
        ], "Sources/OpenLolaCore/Network/Diagnostics/", .diagnosticGate, "Network diagnostics owner", [
            "Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift", "Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift",
            "Tests/OpenLolaCoreTests/NetworkAoipCertificationTests.swift",
        ], ["Tests/OpenLolaCoreTests/Fixtures/AoipEvaluationReports/valid/aoip-avb-partial.json"],
            ["docs/p2p-networking.md", "docs/implementation-handoff.md"], .medium, .active,
            .confirmed, ["swift test --filter NetworkDiagnosticsTests"],
            "Keep diagnostics separate from route proof in docs and reports."),
        own(.externalConnectors, "Protocol-aware external connector descriptors and TX/RX launch sessions for LoLa, MVTP/UltraGrid, and JackTrip.", [
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
            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityControlSocket.swift",
        ], "Sources/OpenLolaCore/Connectors/", .compatibilityPath, "External connector owner", [
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
            "Tests/OpenLolaCoreTests/LoLaCompatibilityControlSocketTests.swift",
        ], ["Tests/OpenLolaCoreTests/Fixtures/ExternalConnectorReports/valid/external-connectors-source-pass.json"],
            ["docs/implementation-handoff.md", "docs/current-state.md"], .medium, .active,
            .confirmed, ["swift test --filter ExternalConnectorReportTests", "swift test --filter ExternalConnectorSessionTests", "swift test --filter ExternalConnectorAvMatrixTests", "swift test --filter ExternalConnectorConnectionPlanTests", "swift test --filter ExternalConnectorNmpPlanTests", "swift test --filter ExternalConnectorNmpPreflightTests", "swift test --filter ExternalConnectorNmpEndpointRunTests", "swift test --filter ExternalConnectorNmpWorkflowTests", "swift test --filter ExternalConnectorExecutablePreflightTests", "swift test --filter LoLaCompatibilityMediaSessionTests", "swift test --filter LoLaCompatibilityPacketFixtureTests"],
            "Keep connector PASS blocked until measured external endpoint evidence exists."),
        own(.timingLatencyBuffering, "Clock, drift/PLC, latency profiles, RX buffering, and impairment simulation.", [
            "Sources/OpenLolaCore/Timing/",
            "Sources/OpenLolaCore/Timing/MediaClock.swift", "Sources/OpenLolaCore/Timing/DriftPlcReport.swift",
            "Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift", "Sources/OpenLolaCore/Timing/LatencyProfileContracts.swift",
            "Sources/OpenLolaCore/Timing/RxBuffering.swift",
        ], "Sources/OpenLolaCore/Timing/", .timingAndBuffering, "Timing and buffering owner", [
            "Tests/OpenLolaCoreTests/MediaClockTests.swift", "Tests/OpenLolaCoreTests/DriftPlcReportTests.swift",
            "Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift", "Tests/OpenLolaCoreTests/RxBufferingTests.swift",
        ], ["Tests/OpenLolaCoreTests/Fixtures/LatencyBenchmarkReports/valid/latency-benchmark-partial.json"],
            ["docs/latency-budget.md", "docs/rx-buffering.md"], .medium, .active,
            .confirmed, ["swift test --filter Latency"], "Consider behavior-neutral file splits only when clock, drift, profile, or buffering edits require them."),
        own(.videoCaptureTransport, "Video capture, transport packetization, reassembly, renderer, and multistream contracts.", [
            "Sources/OpenLolaCore/Video/",
            "Sources/OpenLolaCore/Video/VideoCaptureReport.swift", "Sources/OpenLolaCore/Video/VideoTransportPacket.swift",
            "Sources/OpenLolaCore/Video/VideoTransportReport.swift", "Sources/OpenLolaCore/Video/VideoOutputRenderer.swift",
            "Sources/OpenLolaCore/Video/MultiVideoStreams.swift", "Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift",
        ], "Sources/OpenLolaCore/Video/", .videoPath, "Video transport owner", [
            "Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift", "Tests/OpenLolaCoreTests/VideoTransportReportTests.swift",
            "Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift", "Tests/OpenLolaCoreTests/MultiVideoTransportTests.swift",
        ], ["Tests/OpenLolaCoreTests/Fixtures/VideoTransportReports/valid/video-transport-partial.json"],
            ["docs/video-blackmagic-atem.md", "docs/implementation-handoff.md"], .high, .active,
            .confirmed, ["swift test --filter Video"], "Keep C07 matrix and video fixtures synchronized with video path changes."),
        own(.controlLightingAtemOsc, "OSC cue loop, ATEM read-only boundary, and lighting fixture gate contracts.", [
            "Sources/OpenLolaCore/Control/",
            "Sources/OpenLolaCore/Control/OscCueProbe.swift", "Sources/OpenLolaCore/Control/OscCueRunners.swift",
            "Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift", "Sources/OpenLolaCore/Control/LightingFixtureGate.swift",
            "Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift",
        ], "Sources/OpenLolaCore/Control/", .externalControlGate, "Control integration owner", [
            "Tests/OpenLolaCoreTests/OscCueReportTests.swift", "Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift",
        ], ["Tests/OpenLolaCoreTests/Fixtures/OscCueReports/valid/osc-cue-partial.json"],
            ["docs/lighting-control.md", "docs/implementation-handoff.md"], .high, .active,
            .confirmed, ["swift test --filter OscCueReportTests"],
            "Keep read-only/destructive-control safeguards visible before any control behavior change."),
        own(.evidenceReportsValidation, "Report schema inventory, validator surface, measured fixtures, reference rig, and hardware validation.", [
            "Sources/OpenLolaCore/Evidence/",
            "Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift",
            "Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift",
            "Sources/OpenLolaCore/Evidence/MeasurementReport.swift",
            "Sources/OpenLolaCore/Evidence/VerdictValidationPolicy.swift",
            "Sources/OpenLolaCore/Evidence/ReferenceRigReport.swift",
            "Sources/OpenLolaCore/Evidence/ReferenceRigHelpers.swift",
            "Sources/OpenLolaCore/Evidence/ReferenceRigReportValidation.swift",
            "Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift",
            "Sources/OpenLolaCore/Evidence/HardwareValidationRun.swift",
        ], "Sources/OpenLolaCore/Evidence/", .evidenceContract, "Evidence and validation owner", [
            "Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift", "Tests/OpenLolaCoreTests/MeasurementReportFixtureTests.swift",
            "Tests/OpenLolaCoreTests/ReferenceRigReportTests.swift", "Tests/OpenLolaCoreTests/HardwareValidationReportTests.swift",
            "Tests/OpenLolaCoreTests/VerdictValidationPolicyTests.swift",
        ], ["Tests/OpenLolaCoreTests/Fixtures/MeasurementReports/valid/network-valid.json"],
            ["docs/implementation-handoff.md", "docs/testing.md"], .medium, .active,
            .confirmed, ["swift test --filter ReportSchemaInventoryTests"],
            "Keep report schema inventory paths synchronized atomically."),
        own(.benchmarksPerformance, "Latency, performance, and end-to-end benchmark contracts and synthetic smokes.", [
            "Sources/OpenLolaCore/Benchmarks/",
            "Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReport.swift", "Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift",
            "Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift",
        ], "Sources/OpenLolaCore/Benchmarks/", .benchmarkContract, "Benchmark owner", [
            "Tests/OpenLolaCoreTests/PerformanceAuditTests.swift", "Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift",
            "Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift",
        ], ["Tests/OpenLolaCoreTests/Fixtures/LatencyBenchmarkReports/valid/latency-benchmark-partial.json"],
            ["docs/benchmark-methodology.md", "docs/latency-budget.md"], .medium, .active,
            .confirmed, ["swift test --filter PerformanceAuditTests"],
            "Keep benchmark reports separate from release proof policy files."),
        own(.releaseProofPackaging, "Recording, packaging field tests, field proof, release hardening, and parity closure.", [
            "Sources/OpenLolaCore/Integration/",
            "Sources/OpenLolaCore/Release/",
            "Sources/OpenLolaCore/Release/ReleaseHardening.swift", "Sources/OpenLolaCore/Release/PackagingFieldTest.swift",
            "Sources/OpenLolaCore/Release/FieldReadyRuntimeProof.swift", "Sources/OpenLolaCore/Release/RecordingSessionArtifacts.swift",
            "Sources/OpenLolaCore/Release/FasterThanLoLaClosure.swift",
            "Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift",
            "Sources/OpenLolaCore/Release/Goal/GoalCompletionAudit.swift",
        ], "Sources/OpenLolaCore/Release/", .releaseGate, "Release readiness owner", [
            "Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift", "Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift",
            "Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift", "Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift",
            "Tests/OpenLolaCoreTests/OpenSourceReleaseReadinessTests.swift",
            "Tests/OpenLolaCoreTests/GoalCompletionAuditTests.swift",
        ], ["Tests/OpenLolaCoreTests/Fixtures/ReleaseHardeningReports/valid/release-hardening-partial.json"],
            ["docs/implementation-handoff.md"], .high, .active, .confirmed,
            ["swift test --filter ReleaseHardeningTests"], "Keep release manifest, signing, and clean-Mac proof references aligned."),
        own(.platformAppShell, "Native macOS app-shell runtime boundary and launchability report.", [
            "Sources/open-lola-app/",
            "Sources/open-lola-app-main/",
            "Sources/OpenLolaCore/Platform/NativeAppShell.swift",
            "Sources/OpenLolaCore/Platform/",
            "Sources/OpenLolaCore/Platform/NativeAppShellMediaDevices.swift",
            "Sources/OpenLolaCore/Platform/NativeAppShellMediaInventory.swift",
            "Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerCommand.swift",
            "Sources/OpenLolaCore/Platform/NativeAppShellOperatorState.swift",
            "Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift",
        ], "Sources/OpenLolaCore/Platform/", .appShellBoundary, "macOS app-shell owner",
            ["Tests/OpenLolaCoreTests/NativeAppShellTests.swift"],
            ["Tests/OpenLolaCoreTests/Fixtures/NativeAppShellReports/valid/native-app-shell-partial.json"],
            ["docs/implementation-handoff.md"],
            .medium, .active, .likely, ["swift test --filter NativeAppShellTests"],
            "Keep app-shell runtime contracts separate from SwiftUI presentation code."),
        own(.cliApplication, "Executable command routing, argument parsing, command families, and user-facing CLI surface.", [
            "Sources/open-lola/",
            "Sources/open-lola/main.swift", "Sources/open-lola/Commands/MilestoneCommands.swift",
            "Sources/open-lola/Commands/CLICommandHelpers.swift",
            "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift",
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "Sources/open-lola/Commands/Audio/MadiReceiveCommands.swift",
            "Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift",
            "Sources/open-lola/Commands/Audio/LatencyProfileCommands.swift",
            "Sources/open-lola/Commands/Benchmarks/PerformanceCommands.swift",
            "Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift",
        ], "Sources/open-lola/Commands/", .commandSurface, "CLI owner", [
            "Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift", "Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift",
        ], [], ["docs/implementation-handoff.md", "docs/testing.md"], .medium,
            .active, .confirmed, ["swift test --filter CLICommandInventoryTests"],
            "Keep future command additions inside the domain-specific Commands folders."),
        own(.releaseReadinessInventories, "Executable inventories for commands, schemas, realtime paths, routes, AV/control, fixtures, and source ownership.", [
            "Sources/OpenLolaCore/Support/",
            "Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift",
            "Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrix.swift",
            "Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift",
            "Sources/OpenLolaCore/Support/Inventories/RealtimeAudioPathInventory.swift",
            "Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift",
            "Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift",
            "Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift",
        ], "Sources/OpenLolaCore/Support/Inventories/", .reviewInventory, "Release-readiness inventory owner", [
            "Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift", "Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift",
            "Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift",
            "Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift",
            "Tests/OpenLolaCoreTests/VideoControlDegradeMatrixTests.swift",
            "Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift",
        ], [], ["docs/implementation-handoff.md", "docs/testing.md"], .low, .active,
            .confirmed, ["swift test --filter SourceOwnershipInventoryTests"],
            "Keep inventory docs free of flat source assumptions."),
    ]

    private static func count(_ risk: SourceOwnershipRisk) -> Int {
        entries.filter { $0.refactorRisk == risk }.count
    }
}

private func own(
    _ group: SourceOwnershipGroup,
    _ purpose: String,
    _ currentSourcePaths: [String],
    _ proposedSourcePath: String,
    _ runtimeRole: SourceOwnershipRuntimeRole,
    _ owner: String,
    _ relatedTestFiles: [String],
    _ relatedFixturePaths: [String],
    _ relatedDocs: [String],
    _ refactorRisk: SourceOwnershipRisk,
    firstMoveCandidate: Bool = false,
    movedInC02: Bool = false,
    _ status: SourceOwnershipStatus,
    _ confidence: SourceOwnershipConfidence,
    _ validationCommands: [String],
    _ improvementRecommendation: String
) -> SourceOwnershipEntry {
    SourceOwnershipEntry(
        group: group,
        purpose: purpose,
        currentSourcePaths: currentSourcePaths,
        proposedSourcePath: proposedSourcePath,
        runtimeRole: runtimeRole,
        owner: owner,
        relatedTestFiles: relatedTestFiles,
        relatedFixturePaths: relatedFixturePaths,
        relatedDocs: relatedDocs,
        refactorRisk: refactorRisk,
        firstMoveCandidate: firstMoveCandidate,
        movedInC02: movedInC02,
        status: status,
        confidence: confidence,
        validationCommands: validationCommands,
        improvementRecommendation: improvementRecommendation
    )
}
