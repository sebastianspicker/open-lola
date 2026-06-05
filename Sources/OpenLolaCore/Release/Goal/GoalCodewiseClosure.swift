import Foundation

// Source-level GOAL.md closure ledger. This file defines an executable report
// schema for CLI validation; it does not replace measured runtime evidence.
public enum GoalCodewiseRequirementArea: String, Codable, Equatable, Sendable {
    case productGoal
    case priority
    case principle
    case compliance
    case architecture
    case definitionOfDone
    case artifact
    case validation
    case performance
    case decisionRule
}

public enum GoalCodewiseRequirementStatus: String, Codable, Equatable, Sendable {
    case codeImplemented
    case assumedPassedPendingMeasurement
}

public enum GoalCodewiseRequirementID: String, CaseIterable, Codable, Equatable, Sendable {
    case primaryProductGoal
    case priorityStableAudioLatency
    case priorityFullDuplexMultichannelAudio
    case priorityDirectP2PSession
    case priorityBlackmagicVideo
    case priorityMultipleVideoStreams
    case priorityLightingControl
    case priorityDocsBenchmarksRelease
    case principleAudioFirst
    case principleFastestProfileSimpleDirect
    case principleVideoNeverBlocksAudio
    case principleLightingNonBlocking
    case principleVisibleLatencyBudget
    case principleBenchmarkOrUnvalidated
    case principleSmallMilestones
    case complianceNoProprietaryCopy
    case complianceResearchToIndependentRequirement
    case compliancePublicAPIsStandardsOriginalTestsMeasurements
    case complianceSeparateReverseEngineering
    case compliancePublicDocsSanitized
    case complianceNoBypassExploit
    case architectureMacOSAppleSilicon
    case architectureProfessionalAudioRmeMadi
    case architectureProfessionalVideoBlackmagicAtem
    case architectureDirectP2PGoldStandard
    case architectureUDPFirstTransport
    case architectureSeparateControlMediaChannels
    case architectureExplicitNegotiationMetadata
    case architectureReceiverSideRoutingMixing
    case architectureRXBufferProfiles
    case architectureDirectLowLatencyMeasurable
    case dodMultichannelAudioBothDirections
    case dodReceiverRoutingMixing
    case dodDirectP2PSetup
    case dodAudioLatencyMeasured
    case dodJitterLossUnderrunMeasured
    case dodRXBuffersBenchmarked
    case dodBlackmagicVideoTXRX
    case dodMultiVideoSupportedOrStaged
    case dodAVTimingDocumented
    case dodPerformanceProfilesDocumented
    case dodTestsBenchmarksCriticalPaths
    case dodCleanRoomDefensible
    case dodPublicDocsSafe
    case artifactArchitectureDocs
    case artifactMilestoneDocs
    case artifactBenchmarkDocs
    case artifactResearchDocs
    case artifactReverseEngineeringDocs
    case artifactComplianceDocs
    case artifactTestingDocs
    case artifactDiagramDocs
    case validationEvidenceRationale
    case validationTestsBenchmarkMethod
    case validationLatencyImpact
    case validationFailureModes
    case validationMilestoneProgress
    case validationArchitectureDocs
    case performanceNoBlockingIOCallbacks
    case performanceNoHeapAllocationCallbacks
    case performanceNoLocksCallbacks
    case performanceNoLoggingCallbacks
    case performanceNoVideoUILightingOnAudioThreads
    case performanceNoHiddenBuffering
    case performanceNoUnnecessaryConversions
    case performanceNoAvoidableCopies
    case performanceBenchmarkSensitiveChanges
    case decisionRulePriorityOrder
}

public struct GoalCodewiseRequirement: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var area: GoalCodewiseRequirementArea
    public var status: GoalCodewiseRequirementStatus
    public var evidence: [String]
    public var assumption: String?
    public var notes: String

    public init(
        id: GoalCodewiseRequirementID,
        title: String,
        area: GoalCodewiseRequirementArea,
        status: GoalCodewiseRequirementStatus,
        evidence: [String],
        assumption: String? = nil,
        notes: String
    ) {
        self.id = id.rawValue
        self.title = title
        self.area = area
        self.status = status
        self.evidence = evidence
        self.assumption = assumption
        self.notes = notes
    }
}

public struct GoalCodewiseDocumentationArea: Codable, Equatable, Sendable {
    public var path: String
    public var purpose: String

    public init(path: String, purpose: String) {
        self.path = path
        self.purpose = purpose
    }

    public static let required: [GoalCodewiseDocumentationArea] = [
        .init(path: "docs/latency-first-architecture.md", purpose: "sanitized architecture and latency design"),
        .init(path: "docs/implementation-handoff.md", purpose: "implementation posture and active blockers"),
        .init(path: "docs/benchmark-methodology.md", purpose: "benchmark and measurement methodology"),
        .init(path: "docs/validation-methodology.md", purpose: "publication-safe validation and background synthesis"),
        .init(path: "docs/release-boundary.md", purpose: "clean-room, release, and notice gates"),
        .init(path: "docs/testing.md", purpose: "verification and surface-probe handoff"),
        .init(path: "docs/README.md", purpose: "flat public documentation map"),
    ]
}

public struct GoalCodewiseClosureSummary: Codable, Equatable, Sendable {
    public var requirementCount: Int
    public var codeImplementedCount: Int
    public var assumedPendingMeasurementCount: Int
    public var requiredDocumentationAreaCount: Int

    public init(requirements: [GoalCodewiseRequirement]) {
        requirementCount = requirements.count
        codeImplementedCount = requirements.filter { $0.status == .codeImplemented }.count
        assumedPendingMeasurementCount = requirements
            .filter { $0.status == .assumedPassedPendingMeasurement }
            .count
        requiredDocumentationAreaCount = GoalCodewiseDocumentationArea.required.count
    }
}

public enum GoalCodewiseClosureValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError {
    case emptyField(String)
    case emptyList(String)
    case duplicateRequirement(String)
    case missingRequiredRequirement(String)
    case missingRequiredDocumentationArea(String)
    case requirementWithoutEvidence(String)
    case assumedRequirementWithoutAssumption(String)
    case summaryMismatch
    case passWithAssumedRealWorldClosure
}

public struct GoalCodewiseClosureReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var goalDocument: String
    public var verdict: MeasurementVerdict
    public var realWorldVerdict: MeasurementVerdict
    public var summary: GoalCodewiseClosureSummary
    public var requirements: [GoalCodewiseRequirement]
    public var requiredDocumentationAreas: [GoalCodewiseDocumentationArea]
    public var assumptions: [String]
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        goalDocument: String,
        verdict: MeasurementVerdict,
        realWorldVerdict: MeasurementVerdict,
        requirements: [GoalCodewiseRequirement],
        requiredDocumentationAreas: [GoalCodewiseDocumentationArea],
        assumptions: [String],
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.goalDocument = goalDocument
        self.verdict = verdict
        self.realWorldVerdict = realWorldVerdict
        self.summary = GoalCodewiseClosureSummary(requirements: requirements)
        self.requirements = requirements
        self.requiredDocumentationAreas = requiredDocumentationAreas
        self.assumptions = assumptions
        self.notes = notes
    }

    public static func codewiseClosure() -> GoalCodewiseClosureReport {
        let requirements = goalCodewiseRequirements()
        return GoalCodewiseClosureReport(
            id: "goal-codewise-closure-2026-05-05",
            title: "GOAL.md codewise closure",
            capturedAt: "2026-05-05T00:00:00Z",
            goalDocument: "GOAL.md",
            verdict: .pass,
            realWorldVerdict: .partial,
            requirements: requirements,
            requiredDocumentationAreas: GoalCodewiseDocumentationArea.required,
            assumptions: [
                "Codewise closure means the required source, validation, CLI, and documentation surfaces exist.",
                "Physical two-Mac, RME MADI, Blackmagic/ATEM, lighting, signing, notarization, and clean-Mac evidence remains outside this source-level report.",
            ],
            notes: "All GOAL.md source, documentation, validation, and CLI surfaces are represented codewise; physical evidence remains explicit."
        )
    }

    public func validate() throws {
        try GoalCodewiseClosureValidator.requireNonEmpty(id, "id")
        try GoalCodewiseClosureValidator.requireNonEmpty(title, "title")
        try GoalCodewiseClosureValidator.requireNonEmpty(capturedAt, "capturedAt")
        try GoalCodewiseClosureValidator.requireNonEmpty(goalDocument, "goalDocument")
        try GoalCodewiseClosureValidator.requireNonEmpty(notes, "notes")
        try validateRequirements()
        try validateDocumentationAreas()
        try validateAssumptions()
        guard summary == GoalCodewiseClosureSummary(requirements: requirements) else {
            throw GoalCodewiseClosureValidationError.summaryMismatch
        }
        if verdict == .pass && realWorldVerdict != .partial {
            throw GoalCodewiseClosureValidationError.passWithAssumedRealWorldClosure
        }
    }

    private var hasAssumedMeasurements: Bool {
        requirements.contains { $0.status == .assumedPassedPendingMeasurement }
    }

    private func validateRequirements() throws {
        guard !requirements.isEmpty else {
            throw GoalCodewiseClosureValidationError.emptyList("requirements")
        }

        var seen = Set<String>()
        for requirement in requirements {
            try validateRequirement(requirement, seen: &seen)
        }

        try validateRequiredRequirementCoverage(seen)
    }

    private func validateRequirement(
        _ requirement: GoalCodewiseRequirement,
        seen: inout Set<String>
    ) throws {
        try GoalCodewiseClosureValidator.requireNonEmpty(requirement.id, "requirements.id")
        try GoalCodewiseClosureValidator.requireNonEmpty(requirement.title, "requirements.title")
        try GoalCodewiseClosureValidator.requireNonEmpty(requirement.notes, "requirements.notes")
        guard seen.insert(requirement.id).inserted else {
            throw GoalCodewiseClosureValidationError.duplicateRequirement(requirement.id)
        }
        try validateRequirementEvidence(requirement)
        try validateRequirementAssumption(requirement)
    }

    private func validateRequirementEvidence(_ requirement: GoalCodewiseRequirement) throws {
        guard !requirement.evidence.isEmpty else {
            throw GoalCodewiseClosureValidationError.requirementWithoutEvidence(requirement.id)
        }
        for evidence in requirement.evidence {
            try GoalCodewiseClosureValidator.requireNonEmpty(evidence, "requirements.evidence")
        }
    }

    private func validateRequirementAssumption(_ requirement: GoalCodewiseRequirement) throws {
        if requirement.status == .assumedPassedPendingMeasurement {
            guard let assumption = requirement.assumption, !assumption.isEmpty else {
                throw GoalCodewiseClosureValidationError.assumedRequirementWithoutAssumption(requirement.id)
            }
        }
    }

    private func validateRequiredRequirementCoverage(_ seen: Set<String>) throws {
        for id in GoalCodewiseRequirementID.allCases.map(\.rawValue) where !seen.contains(id) {
            throw GoalCodewiseClosureValidationError.missingRequiredRequirement(id)
        }
    }

    private func validateDocumentationAreas() throws {
        guard !requiredDocumentationAreas.isEmpty else {
            throw GoalCodewiseClosureValidationError.emptyList("requiredDocumentationAreas")
        }
        let paths = Set(requiredDocumentationAreas.map(\.path))
        for area in requiredDocumentationAreas {
            try GoalCodewiseClosureValidator.requireNonEmpty(area.path, "requiredDocumentationAreas.path")
            try GoalCodewiseClosureValidator.requireNonEmpty(area.purpose, "requiredDocumentationAreas.purpose")
        }
        for area in GoalCodewiseDocumentationArea.required where !paths.contains(area.path) {
            throw GoalCodewiseClosureValidationError.missingRequiredDocumentationArea(area.path)
        }
    }

    private func validateAssumptions() throws {
        if hasAssumedMeasurements {
            guard !assumptions.isEmpty else {
                throw GoalCodewiseClosureValidationError.emptyList("assumptions")
            }
        }
        for assumption in assumptions {
            try GoalCodewiseClosureValidator.requireNonEmpty(assumption, "assumptions")
        }
    }
}

private func goalCodewiseRequirements() -> [GoalCodewiseRequirement] {
    goalCodewiseRequirementTable
}

private let goalCodewiseRequirementTable: [GoalCodewiseRequirement] = {
    let architecture = ["docs/latency-first-architecture.md", "Sources/OpenLolaCore"]
    let audio = ["Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift", "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift"]
    let network = ["Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift", "Sources/OpenLolaCore/Network/NAT/NatFriendlyRoute.swift"]
    let video = ["Sources/OpenLolaCore/Video/VideoCaptureReport.swift", "Sources/OpenLolaCore/Video/VideoTransportReport.swift"]
    let docs = ["docs/README.md", "docs/current-state.md", "docs/implementation-handoff.md"]
    let compliance = ["docs/release-boundary.md", "docs/release-manifest.md"]
    let validation = ["Tests/OpenLolaCoreTests", "Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift"]
    let performance = ["Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReport.swift", "docs/latency-budget.md"]
    return [
        req(.primaryProductGoal, "Professional low-latency P2P AV system", .productGoal, architecture, "Represented by the source architecture, CLI inventories, and milestone validators."),
        req(.priorityStableAudioLatency, "Lowest possible stable audio latency", .priority, audio + performance, "Audio-first profiles and callback guards are explicit."),
        req(.priorityFullDuplexMultichannelAudio, "Full-duplex multichannel professional audio", .priority, audio, "MADI full-duplex and multichannel packet contracts exist."),
        req(.priorityDirectP2PSession, "Robust direct P2P session setup", .priority, network, "Direct route, NAT-friendly, and session agreement surfaces exist."),
        req(.priorityBlackmagicVideo, "Blackmagic / ATEM video workflows", .priority, video, "Video capture, transport, and ATEM read-only control gates exist."),
        req(.priorityMultipleVideoStreams, "Multiple video perspectives or streams", .priority, ["Sources/OpenLolaCore/Video/MultiVideoStreams.swift", "Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift", "Sources/OpenLolaCore/Video/VideoStreamDescription.swift"], "Multi-video stream contracts and staged capability limits exist."),
        req(.priorityLightingControl, "Optional lighting/control integration", .priority, ["Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift", "Sources/OpenLolaCore/Control/OscCueProbe.swift"], "OSC, sACN, and Art-Net gates are isolated from audio."),
        req(.priorityDocsBenchmarksRelease, "Documentation, benchmarks, observability, release hardening", .priority, docs + ["Sources/OpenLolaCore/Release/ReleaseHardening.swift"], "Documentation, benchmark, and release ledgers exist."),
        req(.principleAudioFirst, "Audio latency is highest priority", .principle, architecture, "Decision and architecture docs place audio first."),
        req(.principleFastestProfileSimpleDirect, "Fastest profile remains simple and direct", .principle, ["Sources/OpenLolaCore/Timing/LatencyProfileContracts.swift", "docs/latency-profiles.md"], "Fastest profiles reject hidden buffering."),
        req(.principleVideoNeverBlocksAudio, "Video never blocks audio-critical path", .principle, video + performance, "Video report gates track audio impact."),
        req(.principleLightingNonBlocking, "Lighting/control is secondary and non-blocking", .principle, ["Sources/OpenLolaCore/Control/LightingFixtureGate.swift"], "Lighting gates require audio-safe policy."),
        req(.principleVisibleLatencyBudget, "Every buffer, copy, conversion, and hop is visible", .principle, performance, "Latency budget and audit reports expose cost."),
        req(.principleBenchmarkOrUnvalidated, "Major choices are benchmarked or marked unvalidated", .principle, ["Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift", "docs/benchmark-methodology.md"], "Benchmark reports keep partial verdicts visible."),
        req(.principleSmallMilestones, "Small testable milestones", .principle, ["docs/implementation-handoff.md"], "The consolidated Mac-port handoff records current status without a duplicate companion fan-out."),
        req(.complianceNoProprietaryCopy, "No proprietary LoLa code or internals copied", .compliance, compliance, "Clean-room docs and public safety rules forbid copying."),
        req(.complianceResearchToIndependentRequirement, "Research converts to independent requirements", .compliance, ["docs/validation-methodology.md", "docs/release-boundary.md"], "Research-to-requirements process is documented in the condensed active docs."),
        req(.compliancePublicAPIsStandardsOriginalTestsMeasurements, "Use public APIs, standards, tests, and measurements", .compliance, compliance + validation, "Public APIs and original tests are the implementation basis."),
        req(.complianceSeparateReverseEngineering, "Keep internal reverse-engineering separate", .compliance, ["docs/reverse-engineering-boundary.md", "private/reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md"], "Public boundary and internal corpus are separated."),
        req(.compliancePublicDocsSanitized, "Public docs are sanitized", .compliance, ["scripts/verify_docs/main.py", "docs/README.md"], "Docs verifier checks release-surface safety."),
        req(.complianceNoBypassExploit, "No bypass, patching, or exploit behavior", .compliance, compliance, "Compliance docs prohibit bypass behavior."),
        req(.architectureMacOSAppleSilicon, "macOS-first Apple Silicon target", .architecture, ["Package.swift", "Sources/open-lola-app/OpenLolaApp.swift"], "SwiftPM and SwiftUI targets are Mac-native."),
        req(.architectureProfessionalAudioRmeMadi, "Professional audio via RME MADI", .architecture, audio + ["docs/audio-rme-madi.md"], "RME/MADI source contracts exist."),
        req(.architectureProfessionalVideoBlackmagicAtem, "Professional video via Blackmagic / ATEM", .architecture, video + ["docs/video-blackmagic-atem.md"], "Blackmagic/ATEM capture and control gates exist."),
        req(.architectureDirectP2PGoldStandard, "Direct peer-to-peer media path", .architecture, network, "Raw direct route remains the gold-standard path."),
        req(.architectureUDPFirstTransport, "UDP-first realtime media transport", .architecture, ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift", "docs/p2p-networking.md"], "UDP PCM contracts are primary."),
        req(.architectureSeparateControlMediaChannels, "Separate control and media channels", .architecture, ["Sources/OpenLolaCore/Protocol/SessionControlMessage.swift", "Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift"], "Session control and media transport are separate."),
        req(.architectureExplicitNegotiationMetadata, "Explicit IDs, timestamps, sequence, profiles, capabilities", .architecture, ["Sources/OpenLolaCore/Protocol/SessionProtocol.swift", "Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift"], "Negotiation and packet metadata are explicit."),
        req(.architectureReceiverSideRoutingMixing, "Receiver-side routing and mixing", .architecture, ["Sources/OpenLolaCore/Audio/Routing/ReceiverMixSnapshot.swift", "docs/audio-routing.md"], "Receiver-local mix snapshots exist."),
        req(.architectureRXBufferProfiles, "Optional RX buffer profiles", .architecture, ["Sources/OpenLolaCore/Timing/RxBuffering.swift", "docs/rx-buffering.md"], "RX policies are explicit and benchmarkable."),
        req(.architectureDirectLowLatencyMeasurable, "Direct ultra-low-latency mode remains measurable", .architecture, ["Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift", "docs/latency-profiles.md"], "Latency-profile reports preserve direct-mode measurement."),
        req(.dodMultichannelAudioBothDirections, "Multichannel audio TX/RX both directions", .definitionOfDone, audio, "Full-duplex source contracts and socket-backed runtime surfaces exist; two-machine RME evidence remains a real-world gate."),
        req(.dodReceiverRoutingMixing, "Receiver-side routing/mixing works", .definitionOfDone, ["Sources/OpenLolaCore/Audio/Routing/ReceiverMixSnapshot.swift", "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift", "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift"], "Receiver mix is applied by MADI receive and recorded by socket-backed full-duplex runtime evidence; physical RME receive proof remains a real-world gate."),
        req(.dodDirectP2PSetup, "Direct P2P setup works", .definitionOfDone, ["Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift", "Sources/OpenLolaCore/Network/P2P/DirectPeerSessionReport.swift", "Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift"], "Socket-backed local and manual-address control JSON plus UDP media run evidence exists; physical direct-LAN packet capture remains a real-world gate."),
        req(.dodAudioLatencyMeasured, "Audio latency is measured and documented", .definitionOfDone, ["Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift", "docs/benchmark-audio-latency.md"], "Benchmark schema and methodology exist; physical audio latency measurements remain a real-world gate."),
        req(.dodJitterLossUnderrunMeasured, "Jitter, loss, underruns, overruns are measured", .definitionOfDone, ["Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift", "Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackLatency.swift"], "Metric and diagnostic surfaces exist; physical report evidence remains a real-world gate."),
        req(.dodRXBuffersBenchmarked, "RX buffer modes are configurable and benchmarked", .definitionOfDone, ["Sources/OpenLolaCore/Timing/RxBufferBenchmarkReport.swift", "Sources/OpenLolaCore/Timing/RxBufferBenchmarkRunner.swift", "Sources/OpenLolaCore/Timing/RxBuffering.swift"], "Local runtime benchmark covers Direct, Small, Adaptive, and Stable/WAN RX profiles; same-route physical RME benchmarks remain a real-world gate."),
        req(.dodBlackmagicVideoTXRX, "Blackmagic video TX/RX works", .definitionOfDone, video, "Capture and transport surfaces exist; production hardware evidence remains a real-world gate."),
        req(.dodMultiVideoSupportedOrStaged, "Multiple video streams supported or staged", .definitionOfDone, ["Sources/OpenLolaCore/Video/MultiVideoStreams.swift", "Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift", "Sources/OpenLolaCore/Video/VideoTransportRunner.swift"], "Multi-video capability is staged with explicit constraints and a bounded socket-backed runtime."),
        req(.dodAVTimingDocumented, "AV timing behavior documented", .definitionOfDone, ["Sources/OpenLolaCore/Timing/MediaClock.swift", "docs/av-sync-and-timing.md"], "Audio-master timing policy is documented."),
        req(.dodPerformanceProfilesDocumented, "Performance profiles documented", .definitionOfDone, ["docs/latency-profiles.md", "docs/benchmark-methodology.md"], "Profiles and benchmarking rules are documented."),
        req(.dodTestsBenchmarksCriticalPaths, "Tests and benchmarks for critical paths", .definitionOfDone, validation + ["Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift"], "Critical source contracts are test-backed."),
        req(.dodCleanRoomDefensible, "Implementation remains clean-room defensible", .definitionOfDone, compliance, "Compliance and public docs guards are explicit."),
        req(.dodPublicDocsSafe, "Public docs explain without proprietary material", .definitionOfDone, ["docs/README.md", "scripts/verify_docs/constants.py"], "Public docs are sanitized and verified."),
        req(.artifactArchitectureDocs, "Architecture references current", .artifact, ["docs/latency-first-architecture.md", "docs/latency-budget.md", "docs/p2p-networking.md"], "Flat architecture references exist."),
        req(.artifactMilestoneDocs, "Implementation handoff current", .artifact, ["docs/implementation-handoff.md", "docs/current-state.md"], "Current state and handoff files exist."),
        req(.artifactBenchmarkDocs, "Benchmark references current", .artifact, ["docs/benchmark-methodology.md", "docs/benchmark-audio-latency.md", "docs/benchmark-e2e-av.md"], "Benchmark files exist in the flat docs surface."),
        req(.artifactResearchDocs, "Validation background current", .artifact, ["docs/validation-methodology.md", "docs/open-questions.md"], "Validation methodology and source-refresh questions exist."),
        req(.artifactReverseEngineeringDocs, "reverse-engineering boundary current", .artifact, ["docs/reverse-engineering-boundary.md"], "Public-safe boundary file exists."),
        req(.artifactComplianceDocs, "Release boundary current", .artifact, ["docs/release-boundary.md", "docs/release-manifest.md"], "Compliance and release files exist."),
        req(.artifactTestingDocs, "Testing reference current", .artifact, ["docs/testing.md"], "Testing file exists."),
        req(.artifactDiagramDocs, "Flat docs map current", .artifact, ["docs/README.md", "docs/latency-first-architecture.md"], "Former diagram router is archived; active map is flat."),
        req(.validationEvidenceRationale, "Evidence or design rationale", .validation, docs + validation, "Reports and docs carry evidence rationale."),
        req(.validationTestsBenchmarkMethod, "Tests or benchmark method", .validation, validation + ["docs/benchmark-methodology.md"], "Tests and benchmark docs exist."),
        req(.validationLatencyImpact, "Latency impact documented", .validation, ["docs/latency-budget.md", "Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReport.swift"], "Latency impact is represented in budget/audit surfaces."),
        req(.validationFailureModes, "Failure modes documented", .validation, ["docs/risk-register.md", "Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift"], "Risks and report validators capture failures."),
        req(.validationMilestoneProgress, "Milestone progress updated", .validation, ["docs/implementation-handoff.md"], "Canonical handoff records source and evidence gates."),
        req(.validationArchitectureDocs, "Architecture docs updated when relevant", .validation, ["docs/latency-first-architecture.md"], "Architecture reference is current."),
        req(.performanceNoBlockingIOCallbacks, "No blocking I/O in realtime audio callbacks", .performance, performance, "Performance audit guards callback behavior."),
        req(.performanceNoHeapAllocationCallbacks, "No heap allocation in callbacks", .performance, performance, "Realtime reports guard allocation policy."),
        req(.performanceNoLocksCallbacks, "No locks in callbacks unless proven safe", .performance, performance, "Realtime reports guard lock policy."),
        req(.performanceNoLoggingCallbacks, "No logging in callbacks except counters", .performance, performance, "Realtime reports guard logging policy."),
        req(.performanceNoVideoUILightingOnAudioThreads, "No video/UI/lighting work on audio threads", .performance, performance + video, "Ownership reports keep non-audio work off audio-critical paths."),
        req(.performanceNoHiddenBuffering, "No hidden buffering", .performance, ["Sources/OpenLolaCore/Timing/RxBuffering.swift", "Sources/OpenLolaCore/Timing/LatencyTuningReportValidation.swift"], "Buffer growth is explicit and validated."),
        req(.performanceNoUnnecessaryConversions, "No unnecessary format conversions", .performance, audio + performance, "Audio and profile reports expose conversion decisions."),
        req(.performanceNoAvoidableCopies, "No avoidable hot-path copies", .performance, performance, "Performance audit exposes copies and hot paths."),
        req(.performanceBenchmarkSensitiveChanges, "Benchmark before/after sensitive changes", .performance, ["Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift", "docs/benchmark-e2e-av.md"], "Benchmark contracts exist for sensitive changes."),
        req(.decisionRulePriorityOrder, "Conflict decisions follow GOAL.md priority order", .decisionRule, ["GOAL.md", "docs/latency-first-architecture.md"], "Clean-room correctness and audio latency stay ahead of convenience."),
    ]
}()

private func req(
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
