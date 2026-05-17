import Foundation

public enum RealtimeAudioPathClass: String, Codable, Sendable {
    case realtimePath
    case nearRealtimePath
    case reportOnly
    case syntheticOnly
}

public struct RealtimeAudioPathInventoryEntry: Codable, Equatable, Sendable {
    public let sourceFile: String
    public let pathClass: RealtimeAudioPathClass
    public let role: String
    public let relatedTestFiles: [String]
    public let relatedDocs: [String]
    public let fastestPassRelevant: Bool
    public let notes: String

    public init(
        sourceFile: String,
        pathClass: RealtimeAudioPathClass,
        role: String,
        relatedTestFiles: [String],
        relatedDocs: [String],
        fastestPassRelevant: Bool,
        notes: String
    ) {
        self.sourceFile = sourceFile
        self.pathClass = pathClass
        self.role = role
        self.relatedTestFiles = relatedTestFiles
        self.relatedDocs = relatedDocs
        self.fastestPassRelevant = fastestPassRelevant
        self.notes = notes
    }
}

public struct RealtimeAudioPathInventorySummary: Codable, Equatable, Sendable {
    public let entryCount: Int
    public let realtimePathCount: Int
    public let nearRealtimePathCount: Int
    public let reportOnlyCount: Int
    public let syntheticOnlyCount: Int
    public let fastestPassRelevantCount: Int
}

public struct RealtimeAudioPathInventoryReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: RealtimeAudioPathInventorySummary
    public let entries: [RealtimeAudioPathInventoryEntry]
    public let notes: String
}

public enum RealtimeAudioPathInventory {
    public static func report() -> RealtimeAudioPathInventoryReport {
        RealtimeAudioPathInventoryReport(
            id: "c06-realtime-audio-path-inventory",
            title: "C06 realtime audio buffering and latency path inventory",
            verdict: .partial,
            summary: summary(),
            entries: entries,
            notes: "Executable realtime-path crosswalk. It labels latency-sensitive ownership; it does not claim real RME/MADI hardware readiness."
        )
    }

    public static func summary() -> RealtimeAudioPathInventorySummary {
        RealtimeAudioPathInventorySummary(
            entryCount: entries.count,
            realtimePathCount: count(.realtimePath),
            nearRealtimePathCount: count(.nearRealtimePath),
            reportOnlyCount: count(.reportOnly),
            syntheticOnlyCount: count(.syntheticOnly),
            fastestPassRelevantCount: entries.filter(\.fastestPassRelevant).count
        )
    }

    public static let entries: [RealtimeAudioPathInventoryEntry] = [
        entry("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift", .realtimePath, "bounded block rings, due-block playout, and fixed-target jitter buffering", ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift", "Tests/OpenLolaCoreTests/RxBufferingTests.swift"], ["docs/latency-first-architecture.md", "docs/rx-buffering.md"], true, "Must not allocate or grow hidden playout inside the callback-facing path."),
        entry("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift", .realtimePath, "preallocated payload capture ring and channel remap copy", ["Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift", "Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"], ["docs/multichannel-audio-routing.md", "docs/source-contracts.md"], true, "Callback capture must stay bounded and report invalid/remapped copies explicitly."),
        entry("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift", .realtimePath, "capture-to-UDP packetization and receive-to-playout handoff", ["Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift", "Tests/OpenLolaCoreTests/RxBufferingTests.swift"], ["docs/rx-buffering.md", "docs/multichannel-audio-routing.md", "docs/source-contracts.md"], true, "Runtime RX policy evidence must match configuration before fastest PASS is credible."),
        entry("Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift", .realtimePath, "MADI receive packet depacketization and same-deadline recovery", ["Tests/OpenLolaCoreTests/MadiReceiveTests.swift"], ["docs/madi-full-rx-tx.md", "docs/audio-rme-madi.md"], true, "Receive buffering changes affect the target professional audio path."),
        entry("Sources/OpenLolaCore/Audio/MADI/MadiTransmit.swift", .realtimePath, "MADI transmit packetization and channel ordering", ["Tests/OpenLolaCoreTests/MadiTransmitTests.swift"], ["docs/madi-full-rx-tx.md", "docs/multichannel-audio-routing.md"], true, "Transmit packet cadence must remain tied to the selected audio mode."),
        entry("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexRuntime.swift", .realtimePath, "full-duplex MADI runtime pairing and drift simulation", ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"], ["docs/madi-full-rx-tx.md"], true, "Full-duplex behavior is release-critical; socket runtime evidence still cannot replace physical RME evidence."),
        entry("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift", .realtimePath, "socket-backed UDP PCM v2 full-duplex run and receiver-mix surface", ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"], ["docs/madi-full-rx-tx.md"], true, "Network runtime runs must remain PARTIAL until paired with physical RME Core Audio evidence."),
        entry("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift", .nearRealtimePath, "engine configuration, runtime evidence, and handoff metrics", ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"], ["docs/latency-first-architecture.md"], true, "Report/config fields define the PASS contract around callback ownership and runtime handoff."),
        entry("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineHelpers.swift", .nearRealtimePath, "runtime helper construction and measured report assembly", ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"], ["docs/latency-first-architecture.md"], true, "Helpers must preserve the same RX policy accounting as the report validator."),
        entry("Sources/OpenLolaCore/Timing/RxBuffering.swift", .nearRealtimePath, "direct, small, adaptive, and stable/WAN RX policy contracts", ["Tests/OpenLolaCoreTests/RxBufferingTests.swift"], ["docs/rx-buffering.md", "docs/source-contracts.md"], true, "Every added receive target is visible as frames, packets, and microseconds."),
        entry("Sources/OpenLolaCore/Timing/MediaClock.swift", .nearRealtimePath, "host-time and frame-index timing conversion", ["Tests/OpenLolaCoreTests/MediaClockTests.swift"], ["docs/av-sync-and-timing.md"], true, "Clock changes can alter packet deadline and drift interpretation."),
        entry("Sources/OpenLolaCore/Audio/Routing/DirectAudioMediaRouter.swift", .nearRealtimePath, "audio-first media router policy", ["Tests/OpenLolaCoreTests/SessionProtocolTests.swift"], ["docs/latency-first-architecture.md"], true, "Default routing must reject video/control ownership of the audio-critical path."),
        entry("Sources/OpenLolaCore/Timing/LatencyProfileContracts.swift", .nearRealtimePath, "low-buffer profile selection and opt-in policy", ["Tests/OpenLolaCoreTests/LatencyProfileTests.swift"], ["docs/latency-profiles.md", "docs/source-contracts.md"], true, "8/16-frame profiles require explicit evidence gates and cannot become default silently."),
        entry("Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift", .nearRealtimePath, "source-level loopback run shape and selected mode evidence", ["Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift"], ["docs/audio-rme-madi.md"], true, "Loopback results feed RME fastest-path acceptance but are not callback code themselves."),
        entry("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexTypes.swift", .nearRealtimePath, "MADI full-duplex configuration and mode types", ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"], ["docs/madi-full-rx-tx.md"], true, "Type changes can alter accepted full-duplex runtime modes."),
        entry("Sources/OpenLolaCore/Audio/MADI/MadiReceiveTypes.swift", .nearRealtimePath, "MADI receive configuration and buffer types", ["Tests/OpenLolaCoreTests/MadiReceiveTests.swift"], ["docs/madi-full-rx-tx.md"], true, "Receive type changes can alter buffer cost and recovery behavior."),
        entry("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineReportValidation.swift", .reportOnly, "strict validation for realtime engine reports", ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"], ["docs/latency-first-architecture.md"], true, "PASS validation must reject synthetic evidence, hidden buffering, and runtime/config RX mismatch."),
        entry("Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift", .reportOnly, "latency benchmark report schema and PASS gates", ["Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift"], ["docs/benchmark-audio-latency.md"], true, "Benchmark PASS requires measured route and hardware evidence."),
        entry("Sources/OpenLolaCore/Timing/LatencyTuningReport.swift", .reportOnly, "latency tuning report schema and selected-candidate gates", ["Tests/OpenLolaCoreTests/LatencyTuningReportTests.swift"], ["docs/latency-profiles.md"], true, "Tuning cannot promote unstable or non-fastest candidates as PASS."),
        entry("Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift", .reportOnly, "RME fastest-path report and hardware evidence gate", ["Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift"], ["docs/rme-madi-routing.md", "docs/audio-rme-madi.md"], true, "Physical RME evidence remains required before real fastest-path PASS."),
        entry("Sources/OpenLolaCore/Audio/MADI/MadiReceiveReport.swift", .reportOnly, "MADI receive synthetic report schema", ["Tests/OpenLolaCoreTests/MadiReceiveTests.swift"], ["docs/madi-full-rx-tx.md"], false, "Synthetic receive validation documents source behavior only."),
        entry("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift", .reportOnly, "MADI full-duplex source/network report schema", ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"], ["docs/madi-full-rx-tx.md"], false, "Full-duplex and receiver-mix report evidence remains PARTIAL until measured hardware evidence exists."),
        entry("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineSyntheticSmoke.swift", .syntheticOnly, "synthetic realtime engine report generator", ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"], ["docs/latency-first-architecture.md"], false, "Synthetic smoke must stay PARTIAL and cannot close hardware readiness."),
        entry("Sources/OpenLolaCore/Timing/RxImpairmentSimulator.swift", .syntheticOnly, "deterministic packet impairment simulator", ["Tests/OpenLolaCoreTests/RxBufferingTests.swift"], ["docs/rx-buffering.md", "docs/source-contracts.md"], false, "Simulator is useful for stress coverage but is not a measured route."),
        entry("Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkSyntheticSmoke.swift", .syntheticOnly, "synthetic latency benchmark report generator", ["Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift"], ["docs/benchmark-audio-latency.md"], false, "Synthetic latency benchmark output remains PARTIAL."),
    ]

    private static func count(_ pathClass: RealtimeAudioPathClass) -> Int {
        entries.filter { $0.pathClass == pathClass }.count
    }
}

private func entry(
    _ sourceFile: String,
    _ pathClass: RealtimeAudioPathClass,
    _ role: String,
    _ tests: [String],
    _ docs: [String],
    _ fastestPassRelevant: Bool,
    _ notes: String
) -> RealtimeAudioPathInventoryEntry {
    RealtimeAudioPathInventoryEntry(
        sourceFile: sourceFile,
        pathClass: pathClass,
        role: role,
        relatedTestFiles: tests,
        relatedDocs: docs,
        fastestPassRelevant: fastestPassRelevant,
        notes: notes
    )
}
