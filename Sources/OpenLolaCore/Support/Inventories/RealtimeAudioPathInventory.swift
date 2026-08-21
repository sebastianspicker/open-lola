// Classifies audio surfaces by callback, near-realtime, or non-realtime role so blocking and allocation risks remain auditable by path.
import Foundation
/// Defines the finite structured result values recorded by realtime-audio path inventory artifacts for deterministic validation and report interpretation.
public enum RealtimeAudioPathClass: String, Codable, Sendable {
    case realtimePath
    case nearRealtimePath
    case reportOnly
    case syntheticOnly
}
/// Captures inventory entry required to validate, interpret, and reproduce a realtime-audio path inventory result.
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
/// Captures summary statistics required to validate, interpret, and reproduce a realtime-audio path inventory result.
public struct RealtimeAudioPathInventorySummary: Codable, Equatable, Sendable {
    public let entryCount: Int
    public let realtimePathCount: Int
    public let nearRealtimePathCount: Int
    public let reportOnlyCount: Int
    public let syntheticOnlyCount: Int
    public let fastestPassRelevantCount: Int
}
/// Captures report contents required to validate, interpret, and reproduce a realtime-audio path inventory result.
public struct RealtimeAudioPathInventoryReport: PrettyJSONCodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let verdict: MeasurementVerdict
    public let summary: RealtimeAudioPathInventorySummary
    public let entries: [RealtimeAudioPathInventoryEntry]
    public let notes: String
}
/// Builds the realtime-audio path inventory from source-backed entries so ownership and operational boundaries remain reviewable.
public enum RealtimeAudioPathInventory {
    public static func report() -> RealtimeAudioPathInventoryReport {
        RealtimeAudioPathInventoryReport(
            id: "c06-realtime-audio-path-inventory",
            title: "C06 realtime audio buffering and latency path inventory",
            verdict: .partial,
            summary: summary(),
            entries: entries,
            notes: "Executable realtime-path crosswalk. It labels latency-sensitive ownership; it does "
                + "not claim real RME/MADI hardware readiness."
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
        realtimePath(
            "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift",
            "bounded block rings, due-block playout, and fixed-target jitter buffering",
            [],
            [
                "docs/latency-first-architecture.md",
                "docs/rx-buffering.md"
            ],
            "Must not allocate or grow hidden playout inside the callback-facing path."
        ),
        realtimePath(
            "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift",
            "preallocated payload capture ring and channel remap copy",
            [],
            [
                "docs/multichannel-audio-routing.md",
                "docs/source-contracts.md"
            ],
            "Callback capture must stay bounded and report invalid/remapped copies explicitly."
        ),
        realtimePath(
            "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift",
            "capture-to-UDP packetization and receive-to-playout handoff",
            [],
            [
                "docs/rx-buffering.md",
                "docs/multichannel-audio-routing.md",
                "docs/source-contracts.md"
            ],
            "Runtime RX policy evidence must match configuration before fastest PASS is credible."
        ),
        realtimePath(
            "Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift",
            "MADI receive packet depacketization and same-deadline recovery",
            [],
            [
                "docs/madi-full-rx-tx.md",
                "docs/audio-rme-madi.md"
            ],
            "Receive buffering changes affect the target professional audio path."
        ),
        realtimePath(
            "Sources/OpenLolaCore/Audio/MADI/MadiTransmit.swift",
            "MADI transmit packetization and channel ordering",
            [],
            [
                "docs/madi-full-rx-tx.md",
                "docs/multichannel-audio-routing.md"
            ],
            "Transmit packet cadence must remain tied to the selected audio mode."
        ),
        realtimePath(
            "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexRuntime.swift",
            "full-duplex MADI runtime pairing and drift simulation",
            [],
            ["docs/madi-full-rx-tx.md"],
            "Full-duplex behavior is release-critical; "
                + "socket runtime evidence still cannot replace physical RME evidence."
        ),
        realtimePath(
            "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift",
            "socket-backed UDP PCM v2 full-duplex run and receiver-mix surface",
            [],
            ["docs/madi-full-rx-tx.md"],
            "Network runtime runs must remain PARTIAL until paired with physical RME Core Audio evidence."
        ),
        nearRealtimePath(
            "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift",
            "engine configuration, runtime evidence, and handoff metrics",
            [],
            ["docs/latency-first-architecture.md"],
            "Report/config fields define the PASS contract around callback ownership and runtime handoff."
        ),
        nearRealtimePath(
            "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineHelpers.swift",
            "runtime helper construction and measured report assembly",
            [],
            ["docs/latency-first-architecture.md"],
            "Helpers must preserve the same RX policy accounting as the report validator."
        ),
        nearRealtimePath(
            "Sources/OpenLolaCore/Timing/RxBuffering.swift",
            "direct, small, adaptive, and stable/WAN RX policy contracts",
            [],
            [
                "docs/rx-buffering.md",
                "docs/source-contracts.md"
            ],
            "Every added receive target is visible as frames, packets, and microseconds."
        ),
        nearRealtimePath(
            "Sources/OpenLolaCore/Timing/MediaClock.swift",
            "host-time and frame-index timing conversion",
            [],
            ["docs/av-sync-and-timing.md"],
            "Clock changes can alter packet deadline and drift interpretation."
        ),
        nearRealtimePath(
            "Sources/OpenLolaCore/Audio/Routing/DirectAudioMediaRouter.swift",
            "audio-first media router policy",
            [],
            ["docs/latency-first-architecture.md"],
            "Default routing must reject video/control ownership of the audio-critical path."
        ),
        nearRealtimePath(
            "Sources/OpenLolaCore/Timing/LatencyProfileContracts.swift",
            "low-buffer profile selection and opt-in policy",
            [],
            [
                "docs/latency-profiles.md",
                "docs/source-contracts.md"
            ],
            "8/16-frame profiles require explicit evidence gates and cannot become default silently."
        ),
        nearRealtimePath(
            "Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift",
            "source-level loopback run shape and selected mode evidence",
            [],
            ["docs/audio-rme-madi.md"],
            "Loopback results feed RME fastest-path acceptance but are not callback code themselves."
        ),
        nearRealtimePath(
            "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexTypes.swift",
            "MADI full-duplex configuration and mode types",
            [],
            ["docs/madi-full-rx-tx.md"],
            "Type changes can alter accepted full-duplex runtime modes."
        ),
        nearRealtimePath(
            "Sources/OpenLolaCore/Audio/MADI/MadiReceiveTypes.swift",
            "MADI receive configuration and buffer types",
            [],
            ["docs/madi-full-rx-tx.md"],
            "Receive type changes can alter buffer cost and recovery behavior."
        ),
        fastestReportOnly(
            "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineReportValidation.swift",
            "strict validation for realtime engine reports",
            [],
            ["docs/latency-first-architecture.md"],
            "PASS validation must reject synthetic evidence, hidden buffering, and runtime/config RX mismatch."
        ),
        fastestReportOnly(
            "Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift",
            "latency benchmark report schema and PASS gates",
            [],
            ["docs/benchmark-audio-latency.md"],
            "Benchmark PASS requires measured route and hardware evidence."
        ),
        fastestReportOnly(
            "Sources/OpenLolaCore/Timing/LatencyTuningReport.swift",
            "latency tuning report schema and selected-candidate gates",
            [],
            ["docs/latency-profiles.md"],
            "Tuning cannot promote unstable or non-fastest candidates as PASS."
        ),
        fastestReportOnly(
            "Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift",
            "RME fastest-path report and hardware evidence gate",
            [],
            [
                "docs/rme-madi-routing.md",
                "docs/audio-rme-madi.md"
            ],
            "Physical RME evidence remains required before real fastest-path PASS."
        ),
        reportOnly(
            "Sources/OpenLolaCore/Audio/MADI/MadiReceiveReport.swift",
            "MADI receive synthetic report schema",
            [],
            ["docs/madi-full-rx-tx.md"],
            "Synthetic receive validation documents source behavior only."
        ),
        reportOnly(
            "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift",
            "MADI full-duplex source/network report schema",
            [],
            ["docs/madi-full-rx-tx.md"],
            "Full-duplex and receiver-mix report evidence remains PARTIAL until measured hardware evidence exists."
        ),
        syntheticOnly(
            "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngineSyntheticSmoke.swift",
            "synthetic realtime engine report generator",
            [],
            ["docs/latency-first-architecture.md"],
            "Synthetic smoke must stay PARTIAL and cannot close hardware readiness."
        ),
        syntheticOnly(
            "Sources/OpenLolaCore/Timing/RxImpairmentSimulator.swift",
            "deterministic packet impairment simulator",
            [],
            [
                "docs/rx-buffering.md",
                "docs/source-contracts.md"
            ],
            "Simulator is useful for stress coverage but is not a measured route."
        ),
        syntheticOnly(
            "Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkSyntheticSmoke.swift",
            "synthetic latency benchmark report generator",
            [],
            ["docs/benchmark-audio-latency.md"],
            "Synthetic latency benchmark output remains PARTIAL."
        )
    ]
    private static func count(_ pathClass: RealtimeAudioPathClass) -> Int {
        entries.filter { $0.pathClass == pathClass }.count
    }
}
private typealias RealtimeAudioPathInventoryEntryFactory = @Sendable (
    String,
    String,
    [String],
    [String],
    String
) -> RealtimeAudioPathInventoryEntry

private let realtimePath = makeRealtimeAudioPathInventoryEntryFactory(
    pathClass: .realtimePath,
    fastestPassRelevant: true
)
private let nearRealtimePath = makeRealtimeAudioPathInventoryEntryFactory(
    pathClass: .nearRealtimePath,
    fastestPassRelevant: true
)
private let fastestReportOnly = makeRealtimeAudioPathInventoryEntryFactory(
    pathClass: .reportOnly,
    fastestPassRelevant: true
)
private let reportOnly = makeRealtimeAudioPathInventoryEntryFactory(
    pathClass: .reportOnly,
    fastestPassRelevant: false
)
private let syntheticOnly = makeRealtimeAudioPathInventoryEntryFactory(
    pathClass: .syntheticOnly,
    fastestPassRelevant: false
)

private func makeRealtimeAudioPathInventoryEntryFactory(
    pathClass: RealtimeAudioPathClass,
    fastestPassRelevant: Bool
) -> RealtimeAudioPathInventoryEntryFactory {
    { sourceFile, role, tests, docs, notes in
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
}
