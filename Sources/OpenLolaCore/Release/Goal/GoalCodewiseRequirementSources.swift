// Shares the source groups referenced by both halves of the codewise goal table.

let goalCodewiseRequirementSourceGroups = (
    architecture: ["docs/latency-first-architecture.md", "Sources/OpenLolaCore"],
    audio: [
        "Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift",
        "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift"
    ],
    network: [
        "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift",
        "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift"
    ],
    video: [
        "Sources/OpenLolaCore/Video/VideoCaptureReport.swift",
        "Sources/OpenLolaCore/Video/VideoTransportReport.swift"
    ],
    docs: ["docs/README.md", "docs/current-state.md"],
    compliance: ["docs/release-boundary.md", "docs/release-manifest.md"],
    validation: ["Tests/OpenLolaCoreTests", "Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift"],
    performance: [
        "Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReport.swift",
        "docs/latency-budget.md"
    ]
)

func req(
    _ id: GoalCodewiseRequirementID,
    _ title: String,
    _ area: GoalCodewiseRequirementArea,
    _ evidence: [String],
    _ notes: String
) -> GoalCodewiseRequirement {
    GoalCodewiseRequirement(
        id: id,
        title: title,
        area: area,
        status: .codeImplemented,
        evidence: evidence,
        notes: notes
    )
}
