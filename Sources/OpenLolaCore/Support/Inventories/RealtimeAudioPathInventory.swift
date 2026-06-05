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
        realtimePath("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift", "bounded block rings, due-block playout, and fixed-target jitter buffering", ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift", "Tests/OpenLolaCoreTests/RxBufferingTests.swift"], ["docs/latency-first-architecture.md", "docs/rx-buffering.md"], "Must not allocate or grow hidden playout inside the callback-facing path."),
        realtimePath("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift", "preallocated payload capture ring and channel remap copy", ["Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift", "Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"], ["docs/multichannel-audio-routing.md", "docs/source-contracts.md"], "Callback capture must stay bounded and report invalid/remapped copies explicitly."),
        realtimePath("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift", "capture-to-UDP packetization and receive-to-playout handoff", ["Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift", "Tests/OpenLolaCoreTests/RxBufferingTests.swift"], ["docs/rx-buffering.md", "docs/multichannel-audio-routing.md", "docs/source-contracts.md"], "Runtime RX policy evidence must match configuration before fastest PASS is credible."),
        realtimePath("Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift", "MADI receive packet depacketization and same-deadline recovery", ["Tests/OpenLolaCoreTests/MadiReceiveTests.swift"], ["docs/madi-full-rx-tx.md", "docs/audio-rme-madi.md"], "Receive buffering changes affect the target professional audio path."),
        realtimePath("Sources/OpenLolaCore/Audio/MADI/MadiTransmit.swift", "MADI transmit packetization and channel ordering", ["Tests/OpenLolaCoreTests/MadiTransmitTests.swift"], ["docs/madi-full-rx-tx.md", "docs/multichannel-audio-routing.md"], "Transmit packet cadence must remain tied to the selected audio mode."),
        realtimePath("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexRuntime.swift", "full-duplex MADI runtime pairing and drift simulation", ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"], ["docs/madi-full-rx-tx.md"], "Full-duplex behavior is release-critical; socket runtime evidence still cannot replace physical RME evidence."),
        realtimePath("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift", "socket-backed UDP PCM v2 full-duplex run and receiver-mix surface", ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"], ["docs/madi-full-rx-tx.md"], "Network runtime runs must remain PARTIAL until paired with physical RME Core Audio evidence."),
        nearRealtimePath("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift", "engine configuration, runtime evidence, and handoff metrics", ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"], ["docs/latency-first-architecture.md"], "Report/config fields define the PASS contract around callback ownership and runtime handoff."),
        nearRealtimePath("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineHelpers.swift", "runtime helper construction and measured report assembly", ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"], ["docs/latency-first-architecture.md"], "Helpers must preserve the same RX policy accounting as the report validator."),
        nearRealtimePath("Sources/OpenLolaCore/Timing/RxBuffering.swift", "direct, small, adaptive, and stable/WAN RX policy contracts", ["Tests/OpenLolaCoreTests/RxBufferingTests.swift"], ["docs/rx-buffering.md", "docs/source-contracts.md"], "Every added receive target is visible as frames, packets, and microseconds."),
        nearRealtimePath("Sources/OpenLolaCore/Timing/MediaClock.swift", "host-time and frame-index timing conversion", ["Tests/OpenLolaCoreTests/MediaClockTests.swift"], ["docs/av-sync-and-timing.md"], "Clock changes can alter packet deadline and drift interpretation."),
        nearRealtimePath("Sources/OpenLolaCore/Audio/Routing/DirectAudioMediaRouter.swift", "audio-first media router policy", ["Tests/OpenLolaCoreTests/SessionProtocolTests.swift"], ["docs/latency-first-architecture.md"], "Default routing must reject video/control ownership of the audio-critical path."),
        nearRealtimePath("Sources/OpenLolaCore/Timing/LatencyProfileContracts.swift", "low-buffer profile selection and opt-in policy", ["Tests/OpenLolaCoreTests/LatencyProfileTests.swift"], ["docs/latency-profiles.md", "docs/source-contracts.md"], "8/16-frame profiles require explicit evidence gates and cannot become default silently."),
        nearRealtimePath("Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift", "source-level loopback run shape and selected mode evidence", ["Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift"], ["docs/audio-rme-madi.md"], "Loopback results feed RME fastest-path acceptance but are not callback code themselves."),
        nearRealtimePath("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexTypes.swift", "MADI full-duplex configuration and mode types", ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"], ["docs/madi-full-rx-tx.md"], "Type changes can alter accepted full-duplex runtime modes."),
        nearRealtimePath("Sources/OpenLolaCore/Audio/MADI/MadiReceiveTypes.swift", "MADI receive configuration and buffer types", ["Tests/OpenLolaCoreTests/MadiReceiveTests.swift"], ["docs/madi-full-rx-tx.md"], "Receive type changes can alter buffer cost and recovery behavior."),
        fastestReportOnly("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineReportValidation.swift", "strict validation for realtime engine reports", ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"], ["docs/latency-first-architecture.md"], "PASS validation must reject synthetic evidence, hidden buffering, and runtime/config RX mismatch."),
        fastestReportOnly("Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift", "latency benchmark report schema and PASS gates", ["Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift"], ["docs/benchmark-audio-latency.md"], "Benchmark PASS requires measured route and hardware evidence."),
        fastestReportOnly("Sources/OpenLolaCore/Timing/LatencyTuningReport.swift", "latency tuning report schema and selected-candidate gates", ["Tests/OpenLolaCoreTests/LatencyTuningReportTests.swift"], ["docs/latency-profiles.md"], "Tuning cannot promote unstable or non-fastest candidates as PASS."),
        fastestReportOnly("Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift", "RME fastest-path report and hardware evidence gate", ["Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift"], ["docs/rme-madi-routing.md", "docs/audio-rme-madi.md"], "Physical RME evidence remains required before real fastest-path PASS."),
        reportOnly("Sources/OpenLolaCore/Audio/MADI/MadiReceiveReport.swift", "MADI receive synthetic report schema", ["Tests/OpenLolaCoreTests/MadiReceiveTests.swift"], ["docs/madi-full-rx-tx.md"], "Synthetic receive validation documents source behavior only."),
        reportOnly("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift", "MADI full-duplex source/network report schema", ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"], ["docs/madi-full-rx-tx.md"], "Full-duplex and receiver-mix report evidence remains PARTIAL until measured hardware evidence exists."),
        syntheticOnly("Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineSyntheticSmoke.swift", "synthetic realtime engine report generator", ["Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift"], ["docs/latency-first-architecture.md"], "Synthetic smoke must stay PARTIAL and cannot close hardware readiness."),
        syntheticOnly("Sources/OpenLolaCore/Timing/RxImpairmentSimulator.swift", "deterministic packet impairment simulator", ["Tests/OpenLolaCoreTests/RxBufferingTests.swift"], ["docs/rx-buffering.md", "docs/source-contracts.md"], "Simulator is useful for stress coverage but is not a measured route."),
        syntheticOnly("Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkSyntheticSmoke.swift", "synthetic latency benchmark report generator", ["Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift"], ["docs/benchmark-audio-latency.md"], "Synthetic latency benchmark output remains PARTIAL."),
    ]

    private static func count(_ pathClass: RealtimeAudioPathClass) -> Int {
        entries.filter { $0.pathClass == pathClass }.count
    }
}

private struct RealtimeAudioPathInventoryEntryDraft {
    let sourceFile: String
    let pathClass: RealtimeAudioPathClass
    let role: String
    let tests: [String]
    let docs: [String]
    let fastestPassRelevant: Bool
    let notes: String
}

private func realtimePath(
    _ sourceFile: String,
    _ role: String,
    _ tests: [String],
    _ docs: [String],
    _ notes: String
) -> RealtimeAudioPathInventoryEntry {
    entry(RealtimeAudioPathInventoryEntryDraft(
        sourceFile: sourceFile,
        pathClass: .realtimePath,
        role: role,
        tests: tests,
        docs: docs,
        fastestPassRelevant: true,
        notes: notes
    ))
}

private func nearRealtimePath(
    _ sourceFile: String,
    _ role: String,
    _ tests: [String],
    _ docs: [String],
    _ notes: String
) -> RealtimeAudioPathInventoryEntry {
    entry(RealtimeAudioPathInventoryEntryDraft(
        sourceFile: sourceFile,
        pathClass: .nearRealtimePath,
        role: role,
        tests: tests,
        docs: docs,
        fastestPassRelevant: true,
        notes: notes
    ))
}

private func fastestReportOnly(
    _ sourceFile: String,
    _ role: String,
    _ tests: [String],
    _ docs: [String],
    _ notes: String
) -> RealtimeAudioPathInventoryEntry {
    entry(RealtimeAudioPathInventoryEntryDraft(
        sourceFile: sourceFile,
        pathClass: .reportOnly,
        role: role,
        tests: tests,
        docs: docs,
        fastestPassRelevant: true,
        notes: notes
    ))
}

private func reportOnly(
    _ sourceFile: String,
    _ role: String,
    _ tests: [String],
    _ docs: [String],
    _ notes: String
) -> RealtimeAudioPathInventoryEntry {
    entry(RealtimeAudioPathInventoryEntryDraft(
        sourceFile: sourceFile,
        pathClass: .reportOnly,
        role: role,
        tests: tests,
        docs: docs,
        fastestPassRelevant: false,
        notes: notes
    ))
}

private func syntheticOnly(
    _ sourceFile: String,
    _ role: String,
    _ tests: [String],
    _ docs: [String],
    _ notes: String
) -> RealtimeAudioPathInventoryEntry {
    entry(RealtimeAudioPathInventoryEntryDraft(
        sourceFile: sourceFile,
        pathClass: .syntheticOnly,
        role: role,
        tests: tests,
        docs: docs,
        fastestPassRelevant: false,
        notes: notes
    ))
}

private func entry(_ draft: RealtimeAudioPathInventoryEntryDraft) -> RealtimeAudioPathInventoryEntry {
    RealtimeAudioPathInventoryEntry(
        sourceFile: draft.sourceFile,
        pathClass: draft.pathClass,
        role: draft.role,
        relatedTestFiles: draft.tests,
        relatedDocs: draft.docs,
        fastestPassRelevant: draft.fastestPassRelevant,
        notes: draft.notes
    )
}
