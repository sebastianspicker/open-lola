// Holds the second half of source-backed goal requirements, split so each row's evidence and verification command stays reviewable under file limits.
import Foundation

let goalCodewiseRequirementTablePart2: [GoalCodewiseRequirement] = {
    let (
        _,
        audio,
        _,
        video,
        docs,
        _,
        validation,
        performance
    ) = goalCodewiseRequirementSourceGroups
    return [
req(
            .artifactArchitectureDocs,
            "Architecture references current",
            .artifact,
            ["docs/latency-first-architecture.md", "docs/latency-budget.md", "docs/p2p-networking.md"],
            "Flat architecture references exist."
        ),
        req(
            .artifactMilestoneDocs,
            "Current public state current",
            .artifact,
            ["docs/current-state.md"],
            "The active public current-state file exists."
        ),
        req(
            .artifactBenchmarkDocs,
            "Benchmark references current",
            .artifact,
            ["docs/benchmark-methodology.md", "docs/benchmark-audio-latency.md", "docs/benchmark-e2e-av.md"],
            "Benchmark files exist in the flat docs surface."
        ),
        req(
            .artifactResearchDocs,
            "Validation background current",
            .artifact,
            ["docs/validation-methodology.md", "docs/open-questions.md"],
            "Validation methodology and source-refresh questions exist."
        ),
        req(
            .artifactReverseEngineeringDocs,
            "reverse-engineering boundary current",
            .artifact,
            ["docs/reverse-engineering-boundary.md"],
            "Public-safe boundary file exists."
        ),
        req(
            .artifactComplianceDocs,
            "Release boundary current",
            .artifact,
            ["docs/release-boundary.md", "docs/release-manifest.md"],
            "Compliance and release files exist."
        ),
        req(
            .artifactTestingDocs,
            "Testing reference current",
            .artifact,
            ["docs/testing.md"],
            "Testing file exists."
        ),
        req(
            .artifactDiagramDocs,
            "Flat docs map current",
            .artifact,
            ["docs/README.md", "docs/latency-first-architecture.md"],
            "Former diagram router is archived; active map is flat."
        ),
        req(
            .validationEvidenceRationale,
            "Evidence or design rationale",
            .validation,
            docs + validation,
            "Reports and docs carry evidence rationale."
        ),
        req(
            .validationTestsBenchmarkMethod,
            "Tests or benchmark method",
            .validation,
            validation + ["docs/benchmark-methodology.md"],
            "Tests and benchmark docs exist."
        ),
        req(
            .validationLatencyImpact,
            "Latency impact documented",
            .validation,
            ["docs/latency-budget.md", "Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReport.swift"],
            "Latency impact is represented in budget/audit surfaces."
        ),
        req(
            .validationFailureModes,
            "Failure modes documented",
            .validation,
            ["docs/risk-register.md", "Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift"],
            "Risks and report validators capture failures."
        ),
        req(
            .validationMilestoneProgress,
            "Milestone progress updated",
            .validation,
            ["docs/current-state.md"],
            "Current public state records source and evidence gates."
        ),
        req(
            .validationArchitectureDocs,
            "Architecture docs updated when relevant",
            .validation,
            ["docs/latency-first-architecture.md"],
            "Architecture reference is current."
        ),
        req(
            .performanceNoBlockingIOCallbacks,
            "No blocking I/O in realtime audio callbacks",
            .performance,
            performance,
            "Performance audit guards callback behavior."
        ),
        req(
            .performanceNoHeapAllocationCallbacks,
            "No heap allocation in callbacks",
            .performance,
            performance,
            "Realtime reports guard allocation policy."
        ),
        req(
            .performanceNoLocksCallbacks,
            "No locks in callbacks unless proven safe",
            .performance,
            performance,
            "Realtime reports guard lock policy."
        ),
        req(
            .performanceNoLoggingCallbacks,
            "No logging in callbacks except counters",
            .performance,
            performance,
            "Realtime reports guard logging policy."
        ),
        req(
            .performanceNoVideoUILightingOnAudioThreads,
            "No video/UI/lighting work on audio threads",
            .performance,
            performance + video,
            "Ownership reports keep non-audio work off audio-critical paths."
        ),
        req(
            .performanceNoHiddenBuffering,
            "No hidden buffering",
            .performance,
            [
                "Sources/OpenLolaCore/Timing/RxBuffering.swift",
                "Sources/OpenLolaCore/Timing/LatencyTuningReportValidation.swift"
            ],
            "Buffer growth is explicit and validated."
        ),
        req(
            .performanceNoUnnecessaryConversions,
            "No unnecessary format conversions",
            .performance,
            audio + performance,
            "Audio and profile reports expose conversion decisions."
        ),
        req(
            .performanceNoAvoidableCopies,
            "No avoidable hot-path copies",
            .performance,
            performance,
            "Performance audit exposes copies and hot paths."
        ),
        req(
            .performanceBenchmarkSensitiveChanges,
            "Benchmark before/after sensitive changes",
            .performance,
            ["Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift", "docs/benchmark-e2e-av.md"],
            "Benchmark contracts exist for sensitive changes."
        ),
        req(
            .decisionRulePriorityOrder,
            "Conflict decisions follow GOAL.md priority order",
            .decisionRule,
            [
                "GOAL.md",
                "docs/latency-first-architecture.md"
            ],
            "Clean-room correctness audio latency stay ahead convenience."
        )
    ]
}()
