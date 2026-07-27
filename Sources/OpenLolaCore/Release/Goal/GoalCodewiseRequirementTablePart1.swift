// Holds the first half of source-backed goal requirements, keeping the large evidence catalog partitioned without hiding row-level gates.
import Foundation

let goalCodewiseRequirementTablePart1: [GoalCodewiseRequirement] = {
    let (
        architecture,
        audio,
        network,
        video,
        docs,
        compliance,
        validation,
        performance
    ) = goalCodewiseRequirementSourceGroups
    return [
        req(
            .primaryProductGoal,
            "Professional low-latency P2P AV system",
            .productGoal,
            architecture,
            "Represented by the source architecture, CLI inventories, and milestone validators."
        ),
        req(
            .priorityStableAudioLatency,
            "Lowest possible stable audio latency",
            .priority,
            audio + performance,
            "Audio-first profiles and callback guards are explicit."
        ),
        req(
            .priorityFullDuplexMultichannelAudio,
            "Full-duplex multichannel professional audio",
            .priority,
            audio,
            "MADI full-duplex and multichannel packet contracts exist."
        ),
        req(
            .priorityDirectP2PSession,
            "Robust direct P2P session setup",
            .priority,
            network,
            "Direct route, NAT-friendly, and session agreement surfaces exist."
        ),
        req(
            .priorityBlackmagicVideo,
            "Blackmagic / ATEM video workflows",
            .priority,
            video,
            "Video capture, transport, and ATEM read-only control gates exist."
        ),
        req(
            .priorityMultipleVideoStreams,
            "Multiple video perspectives or streams",
            .priority,
            [
                "Sources/OpenLolaCore/Video/MultiVideoStreams.swift",
                "Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift",
                "Sources/OpenLolaCore/Video/VideoStreamDescription.swift"
            ],
            "Multi-video stream contracts and staged capability limits exist."
        ),
        req(
            .priorityLightingControl,
            "Optional lighting/control integration",
            .priority,
            [
                "Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift",
                "Sources/OpenLolaCore/Control/OscCueProbe.swift"
            ],
            "OSC, sACN, and Art-Net gates are isolated from audio."
        ),
        req(
            .priorityDocsBenchmarksRelease,
            "Documentation, benchmarks, observability, release hardening",
            .priority,
            docs + ["Sources/OpenLolaCore/Release/ReleaseHardening.swift"],
            "Documentation, benchmark, and release ledgers exist."
        ),
        req(
            .principleAudioFirst,
            "Audio latency is highest priority",
            .principle,
            architecture,
            "Decision and architecture docs place audio first."
        ),
        req(
            .principleFastestProfileSimpleDirect,
            "Fastest profile remains simple and direct",
            .principle,
            ["Sources/OpenLolaCore/Timing/LatencyProfileContracts.swift", "docs/latency-profiles.md"],
            "Fastest profiles reject hidden buffering."
        ),
        req(
            .principleVideoNeverBlocksAudio,
            "Video never blocks audio-critical path",
            .principle,
            video + performance,
            "Video report gates track audio impact."
        ),
        req(
            .principleLightingNonBlocking,
            "Lighting/control is secondary and non-blocking",
            .principle,
            ["Sources/OpenLolaCore/Control/LightingFixtureGate.swift"],
            "Lighting gates require audio-safe policy."
        ),
        req(
            .principleVisibleLatencyBudget,
            "Every buffer, copy, conversion, and hop is visible",
            .principle,
            performance,
            "Latency budget and audit reports expose cost."
        ),
        req(
            .principleBenchmarkOrUnvalidated,
            "Major choices are benchmarked or marked unvalidated",
            .principle,
            ["Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift", "docs/benchmark-methodology.md"],
            "Benchmark reports keep partial verdicts visible."
        ),
        req(
            .principleSmallMilestones,
            "Small testable milestones",
            .principle,
            ["docs/current-state.md"],
            "The active public state records current status without a duplicate local-only handoff."
        ),
        req(
            .complianceNoProprietaryCopy,
            "No proprietary LoLa code or internals copied",
            .compliance,
            compliance,
            "Clean-room docs and public safety rules forbid copying."
        ),
        req(
            .complianceResearchToIndependentRequirement,
            "Research converts to independent requirements",
            .compliance,
            ["docs/validation-methodology.md", "docs/release-boundary.md"],
            "Research-to-requirements process is documented in the condensed active docs."
        ),
        req(
            .compliancePublicAPIsStandardsOriginalTestsMeasurements,
            "Use public APIs, standards, tests, and measurements",
            .compliance,
            compliance + validation,
            "Public APIs and original tests are the implementation basis."
        ),
        req(
            .complianceSeparateReverseEngineering,
            "Keep internal reverse-engineering separate",
            .compliance,
            ["docs/reverse-engineering-boundary.md"],
            "The public boundary defines the separation from local-only internal material."
        ),
        req(
            .compliancePublicDocsSanitized,
            "Public docs are sanitized",
            .compliance,
            ["scripts/verify_docs/main.py", "docs/README.md"],
            "Docs verifier checks release-surface safety."
        ),
        req(
            .complianceNoBypassExploit,
            "No bypass, patching, or exploit behavior",
            .compliance,
            compliance,
            "Compliance docs prohibit bypass behavior."
        ),
        req(
            .architectureMacOSAppleSilicon,
            "macOS-first Apple Silicon target",
            .architecture,
            ["Package.swift", "Sources/open-lola-app/OpenLolaApp.swift"],
            "SwiftPM and SwiftUI targets are Mac-native."
        ),
        req(
            .architectureProfessionalAudioRmeMadi,
            "Professional audio via RME MADI",
            .architecture,
            audio + ["docs/audio-rme-madi.md"],
            "RME/MADI source contracts exist."
        ),
        req(
            .architectureProfessionalVideoBlackmagicAtem,
            "Professional video via Blackmagic / ATEM",
            .architecture,
            video + ["docs/video-blackmagic-atem.md"],
            "Blackmagic/ATEM capture and control gates exist."
        ),
        req(
            .architectureDirectP2PGoldStandard,
            "Direct peer-to-peer media path",
            .architecture,
            network,
            "Raw direct route remains the gold-standard path."
        ),
        req(
            .architectureUDPFirstTransport,
            "UDP-first realtime media transport",
            .architecture,
            ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift", "docs/p2p-networking.md"],
            "UDP PCM contracts are primary."
        ),
        req(
            .architectureSeparateControlMediaChannels,
            "Separate control and media channels",
            .architecture,
            [
                "Sources/OpenLolaCore/Protocol/SessionControlMessage.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift"
            ],
            "Session control and media transport are separate."
        ),
        req(
            .architectureExplicitNegotiationMetadata,
            "Explicit IDs, timestamps, sequence, profiles, capabilities",
            .architecture,
            [
                "Sources/OpenLolaCore/Protocol/SessionProtocol.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift"
            ],
            "Negotiation and packet metadata are explicit."
        ),
        req(
            .architectureReceiverSideRoutingMixing,
            "Receiver-side routing and mixing",
            .architecture,
            ["Sources/OpenLolaCore/Audio/Routing/ReceiverMixSnapshot.swift", "docs/audio-routing.md"],
            "Receiver-local mix snapshots exist."
        ),
        req(
            .architectureRXBufferProfiles,
            "Optional RX buffer profiles",
            .architecture,
            ["Sources/OpenLolaCore/Timing/RxBuffering.swift", "docs/rx-buffering.md"],
            "RX policies are explicit and benchmarkable."
        ),
        req(
            .architectureDirectLowLatencyMeasurable,
            "Direct ultra-low-latency mode remains measurable",
            .architecture,
            ["Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift", "docs/latency-profiles.md"],
            "Latency-profile reports preserve direct-mode measurement."
        ),
        req(
            .dodMultichannelAudioBothDirections,
            "Multichannel audio TX/RX both directions",
            .definitionOfDone,
            audio,
            "Full-duplex source contracts and socket-backed runtime surfaces exist; two-machine RME " +
                "evidence remains a real-world gate."
        ),
        req(
            .dodReceiverRoutingMixing,
            "Receiver-side routing/mixing works",
            .definitionOfDone,
            [
                "Sources/OpenLolaCore/Audio/Routing/ReceiverMixSnapshot.swift",
                "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift",
                "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift"
            ],
            "Receiver mix is applied by MADI receive and recorded by socket-backed full-duplex runtime " +
                "evidence; physical RME receive proof remains a real-world gate."
        ),
        req(
            .dodDirectP2PSetup,
            "Direct P2P setup works",
            .definitionOfDone,
            [
                "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift",
                "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift"
            ],
            "Socket-backed local and manual-address control JSON plus UDP media run evidence exists; " +
                "physical direct-LAN packet capture remains a real-world gate."
        ),
        req(
            .dodAudioLatencyMeasured,
            "Audio latency is measured and documented",
            .definitionOfDone,
            ["Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift", "docs/benchmark-audio-latency.md"],
            "Benchmark schema and methodology exist; physical audio latency measurements remain a real-world gate."
        ),
        req(
            .dodJitterLossUnderrunMeasured,
            "Jitter, loss, underruns, overruns are measured",
            .definitionOfDone,
            [
                "Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift"
            ],
            "Metric and diagnostic surfaces exist; physical report evidence remains a real-world gate."
        ),
        req(
            .dodRXBuffersBenchmarked,
            "RX buffer modes are configurable and benchmarked",
            .definitionOfDone,
            [
                "Sources/OpenLolaCore/Timing/RxBufferBenchmarkReport.swift",
                "Sources/OpenLolaCore/Timing/RxBufferBenchmarkRunner.swift",
                "Sources/OpenLolaCore/Timing/RxBuffering.swift"
            ],
            "Local runtime benchmark covers Direct, Small, Adaptive, and Stable/WAN RX profiles; " +
                "same-route physical RME benchmarks remain a real-world gate."
        ),
        req(
            .dodBlackmagicVideoTXRX,
            "Blackmagic video TX/RX works",
            .definitionOfDone,
            video,
            "Capture and transport surfaces exist; production hardware evidence remains a real-world gate."
        ),
        req(
            .dodMultiVideoSupportedOrStaged,
            "Multiple video streams supported or staged",
            .definitionOfDone,
            [
                "Sources/OpenLolaCore/Video/MultiVideoStreams.swift",
                "Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift",
                "Sources/OpenLolaCore/Video/VideoTransportRunner.swift"
            ],
            "Multi-video capability is staged with explicit constraints and a bounded socket-backed runtime."
        ),
        req(
            .dodAVTimingDocumented,
            "AV timing behavior documented",
            .definitionOfDone,
            ["Sources/OpenLolaCore/Timing/MediaClock.swift", "docs/av-sync-and-timing.md"],
            "Audio-master timing policy is documented."
        ),
        req(
            .dodPerformanceProfilesDocumented,
            "Performance profiles documented",
            .definitionOfDone,
            ["docs/latency-profiles.md", "docs/benchmark-methodology.md"],
            "Profiles and benchmarking rules are documented."
        ),
        req(
            .dodTestsBenchmarksCriticalPaths,
            "Tests and benchmarks for critical paths",
            .definitionOfDone,
            validation + ["Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift"],
            "Critical source contracts are test-backed."
        ),
        req(
            .dodCleanRoomDefensible,
            "Implementation remains clean-room defensible",
            .definitionOfDone,
            compliance,
            "Compliance and public docs guards are explicit."
        ),
        req(
            .dodPublicDocsSafe,
            "Public docs explain without proprietary material",
            .definitionOfDone,
            ["docs/README.md", "scripts/verify_docs/constants.py"],
            "Public docs are sanitized and verified."
        )
    ]
}()
