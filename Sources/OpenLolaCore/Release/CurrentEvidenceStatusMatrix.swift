import Foundation

public enum CurrentEvidenceStatus: String, Codable, Hashable, Sendable {
    case done = "DONE"
    case sourceDone = "SOURCE-DONE"
    case partial = "PARTIAL"
    case blocked = "BLOCKED"
}

public enum CurrentEvidenceLaneID: String, CaseIterable, Codable, Hashable, Sendable {
    case measurementRig = "measurement-rig"
    case coreAudioRme = "core-audio-rme"
    case udpP2PTransport = "udp-p2p-transport"
    case rxBufferingLatencyProfiles = "rx-buffering-latency-profiles"
    case plcAndDrift = "plc-and-drift"
    case dscpPtpAoip = "dscp-ptp-aoip"
    case video = "video"
    case lightingShowControl = "lighting-show-control"
    case windowsLoLaCompatibility = "windows-lola-compatibility"
    case appRecordingOperatorSurface = "app-recording-operator-surface"
    case releaseFieldClosure = "release-field-closure"
}

public enum CurrentRealWorldTestID: String, CaseIterable, Codable, Hashable, Sendable {
    case hardwareBaseline = "RWT-001"
    case coreAudioLoopback = "RWT-002"
    case twoMacUdpP2P = "RWT-003"
    case rxBufferProfiles = "RWT-004"
    case plcAndDrift = "RWT-005"
    case networkTimingAndAoip = "RWT-006"
    case video = "RWT-007"
    case lightingAndShowControl = "RWT-008"
    case windowsLoLaCompatibility = "RWT-009"
    case releaseAndFieldPackage = "RWT-010"
    case natIspRoute = "RWT-011"
}

public struct CurrentEvidenceStatusMatrixSource: Codable, Equatable, Sendable {
    public let title: String
    public let path: String
    public let role: String
}

public struct CurrentEvidenceCrosswalkRow: Codable, Equatable, Sendable {
    public let lane: CurrentEvidenceLaneID
    public let status: CurrentEvidenceStatus
    public let finding: String
    public let doneNow: [String]
    public let missingBeforePass: [String]
    public let realWorldTaskIDs: [CurrentRealWorldTestID]
    public let sourceEvidence: [String]
}

public struct CurrentRealWorldTestTask: Codable, Equatable, Sendable {
    public let id: CurrentRealWorldTestID
    public let title: String
    public let blocks: [String]
    public let requiredEvidence: [String]
    public let acceptanceCondition: String
    public let sourceCompletability: String
}

public struct CurrentEvidenceStatusMatrixSummary: Codable, Equatable, Sendable {
    public let sourceCount: Int
    public let laneCount: Int
    public let realWorldTaskCount: Int
    public let sourceDoneLaneCount: Int
    public let partialLaneCount: Int
    public let blockedLaneCount: Int
    public let openRealWorldTaskCount: Int

    public init(
        sources: [CurrentEvidenceStatusMatrixSource],
        crosswalk: [CurrentEvidenceCrosswalkRow],
        realWorldTests: [CurrentRealWorldTestTask]
    ) {
        sourceCount = sources.count
        laneCount = crosswalk.count
        realWorldTaskCount = realWorldTests.count
        sourceDoneLaneCount = crosswalk.filter { $0.status == .sourceDone }.count
        partialLaneCount = crosswalk.filter { $0.status == .partial }.count
        blockedLaneCount = crosswalk.filter { $0.status == .blocked }.count
        openRealWorldTaskCount = realWorldTests.count
    }
}

public struct CurrentEvidenceStatusMatrixReport: ReportValidatingArtifact, Equatable, Sendable {
    public let id: String
    public let title: String
    public let capturedAt: String
    public let sourceMatrixPath: String
    public let verdict: MeasurementVerdict
    public let summary: CurrentEvidenceStatusMatrixSummary
    public let sources: [CurrentEvidenceStatusMatrixSource]
    public let crosswalk: [CurrentEvidenceCrosswalkRow]
    public let realWorldTests: [CurrentRealWorldTestTask]
    public let notes: String

    public static func current() -> CurrentEvidenceStatusMatrixReport {
        let sources = CurrentEvidenceStatusMatrixFixtures.sources
        let crosswalk = CurrentEvidenceStatusMatrixFixtures.crosswalk
        let realWorldTests = CurrentEvidenceStatusMatrixFixtures.realWorldTests
        return CurrentEvidenceStatusMatrixReport(
            id: "current-evidence-status-matrix-2026-05-11",
            title: "Current evidence status matrix",
            capturedAt: "2026-05-11T00:00:00Z",
            sourceMatrixPath: "archive/2026-05-11-research-archive/docs/research/RESEARCH_CURRENT_STATUS_MATRIX_2026.md",
            verdict: .partial,
            summary: CurrentEvidenceStatusMatrixSummary(
                sources: sources,
                crosswalk: crosswalk,
                realWorldTests: realWorldTests
            ),
            sources: sources,
            crosswalk: crosswalk,
            realWorldTests: realWorldTests,
            notes: "Source-level current-status matrix. PASS remains blocked until the real-world test tasks attach measured hardware, Windows-peer, signing, notarization, and field evidence."
        )
    }

    public func validate() throws {
        try CurrentEvidenceStatusMatrixValidator.validate(self)
    }
}

public enum CurrentEvidenceStatusMatrixValidationError: Error, Equatable {
    case emptyField(String)
    case emptyList(String)
    case malformedField(String)
    case duplicateLane(CurrentEvidenceLaneID)
    case missingLane(CurrentEvidenceLaneID)
    case duplicateRealWorldTask(CurrentRealWorldTestID)
    case missingRealWorldTask(CurrentRealWorldTestID)
    case unknownTaskReference(CurrentRealWorldTestID)
    case summaryMismatch
    case passForbidden
}

extension CurrentEvidenceStatusMatrixValidationError: ValidationEmptyFieldError, ValidationEmptyListError,
    ValidationMalformedFieldError {}

enum CurrentEvidenceStatusMatrixValidator: ReportPrimitiveValidating {
    typealias ValidationError = CurrentEvidenceStatusMatrixValidationError

    static func validate(_ report: CurrentEvidenceStatusMatrixReport) throws {
        try requireNonEmpty(report.id, "id")
        try requireNonEmpty(report.title, "title")
        try requireNonEmpty(report.capturedAt, "capturedAt")
        try requireISO8601Date(report.capturedAt, "capturedAt")
        try requireNonEmpty(report.sourceMatrixPath, "sourceMatrixPath")
        try requireNonEmpty(report.notes, "notes")
        try requireNonEmpty(report.sources, "sources")
        try requireNonEmpty(report.crosswalk, "crosswalk")
        try requireNonEmpty(report.realWorldTests, "realWorldTests")
        if report.verdict == .pass {
            throw CurrentEvidenceStatusMatrixValidationError.passForbidden
        }

        try validateSources(report.sources)
        try validateCrosswalk(report.crosswalk, tasks: report.realWorldTests.map(\.id))
        try validateRealWorldTests(report.realWorldTests)

        let expectedSummary = CurrentEvidenceStatusMatrixSummary(
            sources: report.sources,
            crosswalk: report.crosswalk,
            realWorldTests: report.realWorldTests
        )
        if report.summary != expectedSummary {
            throw CurrentEvidenceStatusMatrixValidationError.summaryMismatch
        }
    }

    private static func validateSources(_ sources: [CurrentEvidenceStatusMatrixSource]) throws {
        for source in sources {
            try requireNonEmpty(source.title, "sources.title")
            try requireNonEmpty(source.path, "sources.path")
            try requireNonEmpty(source.role, "sources.role")
        }
    }

    private static func validateCrosswalk(
        _ rows: [CurrentEvidenceCrosswalkRow],
        tasks: [CurrentRealWorldTestID]
    ) throws {
        let taskSet = Set(tasks)
        var seen = Set<CurrentEvidenceLaneID>()
        for row in rows {
            if !seen.insert(row.lane).inserted {
                throw CurrentEvidenceStatusMatrixValidationError.duplicateLane(row.lane)
            }
            try requireNonEmpty(row.finding, "crosswalk.finding")
            try requireNonEmptyStrings(row.doneNow, "crosswalk.doneNow")
            try requireNonEmptyStrings(row.missingBeforePass, "crosswalk.missingBeforePass")
            try requireNonEmpty(row.realWorldTaskIDs, "crosswalk.realWorldTaskIDs")
            try requireNonEmptyStrings(row.sourceEvidence, "crosswalk.sourceEvidence")
            for taskID in row.realWorldTaskIDs where !taskSet.contains(taskID) {
                throw CurrentEvidenceStatusMatrixValidationError.unknownTaskReference(taskID)
            }
        }
        for lane in CurrentEvidenceLaneID.allCases where !seen.contains(lane) {
            throw CurrentEvidenceStatusMatrixValidationError.missingLane(lane)
        }
    }

    private static func validateRealWorldTests(_ tasks: [CurrentRealWorldTestTask]) throws {
        var seen = Set<CurrentRealWorldTestID>()
        for task in tasks {
            if !seen.insert(task.id).inserted {
                throw CurrentEvidenceStatusMatrixValidationError.duplicateRealWorldTask(task.id)
            }
            try requireNonEmpty(task.title, "realWorldTests.title")
            try requireNonEmptyStrings(task.blocks, "realWorldTests.blocks")
            try requireNonEmptyStrings(task.requiredEvidence, "realWorldTests.requiredEvidence")
            try requireNonEmpty(task.acceptanceCondition, "realWorldTests.acceptanceCondition")
            try requireNonEmpty(task.sourceCompletability, "realWorldTests.sourceCompletability")
        }
        for taskID in CurrentRealWorldTestID.allCases where !seen.contains(taskID) {
            throw CurrentEvidenceStatusMatrixValidationError.missingRealWorldTask(taskID)
        }
    }
}

private enum CurrentEvidenceStatusMatrixFixtures {
    static let sources = [
        CurrentEvidenceStatusMatrixSource(
            title: "Current crosswalk matrix",
            path: "archive/2026-05-11-research-archive/docs/research/RESEARCH_CURRENT_STATUS_MATRIX_2026.md",
            role: "Primary current status and real-world test task matrix"
        ),
        CurrentEvidenceStatusMatrixSource(
            title: "Evidence matrix findings",
            path: "archive/2026-05-11-research-archive/docs/research/RESEARCH_EVIDENCE_MATRIX_2026.md",
            role: "Original finding IDs and evidence requirements"
        ),
        CurrentEvidenceStatusMatrixSource(
            title: "Open questions",
            path: "docs/open-questions.md",
            role: "Q001-Q012 closure state and external evidence gates"
        ),
        CurrentEvidenceStatusMatrixSource(
            title: "Windows LoLa validation checklist",
            path: "private/reverse-engineering/lola-2-windows/validation-checklist.md",
            role: "Private Windows-peer validation requirements"
        ),
        CurrentEvidenceStatusMatrixSource(
            title: "Mac port handoff",
            path: "docs/implementation-handoff.md",
            role: "Active implementation handoff and source-level completion status"
        ),
    ]

    static let crosswalk = [
        row(CurrentEvidenceCrosswalkDraft(
            lane: .measurementRig,
            status: .partial,
            finding: "Research asked for a physical reference rig and real two-Mac evidence.",
            done: ["Hardware validation and goal preflight reports model the required rig and blockers."],
            missing: ["Attach measured RME, Blackmagic or ATEM, wired route, and witness artifacts."],
            tasks: [.hardwareBaseline],
            evidence: ["HardwareValidationReport", "GoalRuntimePreflightReport", "ReferenceRigReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .coreAudioRme,
            status: .sourceDone,
            finding: "Core Audio and RME/MADI source paths exist, including fastest-profile contracts.",
            done: ["Device inventory, RME path, realtime engine, MADI TX/RX, and full-duplex reports are source-covered."],
            missing: ["Run physical Core Audio loopback on visible RME MADI hardware."],
            tasks: [.coreAudioLoopback],
            evidence: ["CoreAudioInventoryReport", "RmeFastestAudioPathReport", "RealtimeAudioEngineReport", "MadiFullDuplexReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .udpP2PTransport,
            status: .sourceDone,
            finding: "UDP PCM, direct P2P, and two-peer command/report surfaces exist.",
            done: ["Packet, route, loopback, NAT, direct peer, mesh, and two-peer plan reports are implemented."],
            missing: ["Run direct two-Mac route and packet-loss/latency evidence outside localhost."],
            tasks: [.twoMacUdpP2P, .natIspRoute],
            evidence: ["UdpPcmRouteReport", "MacToMacRouteCertificationReport", "DirectPeerTwoPeerPrototypeReport", "NatFriendlyRouteReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .rxBufferingLatencyProfiles,
            status: .sourceDone,
            finding: "RX buffering profiles and latency-profile runners are implemented.",
            done: ["direct, small, adaptive, and stableWan profiles are source-visible and benchmarkable."],
            missing: ["Measure same-route profile behavior on two Macs and reject hidden playout growth."],
            tasks: [.rxBufferProfiles],
            evidence: ["RxBufferBenchmarkReport", "LatencyTuningReport", "LatencyBenchmarkReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .plcAndDrift,
            status: .partial,
            finding: "PLC and drift contracts exist but need fixed-target physical certification.",
            done: ["Drift and PLC reports reject callback correction, retransmission waits, and target-depth growth."],
            missing: ["Record fixed-target drift/PLC certification against real route and LoLa baseline."],
            tasks: [.plcAndDrift],
            evidence: ["DriftPlcReport", "DriftPlcFixedTargetCertificationReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .dscpPtpAoip,
            status: .partial,
            finding: "DSCP and AoIP are represented as measured-report gates, not defaults.",
            done: ["Network diagnostics, route certification, AoIP evaluation, and network-AoIP certification reports exist."],
            missing: ["Capture DSCP behavior, PTP availability, AoIP superiority or non-superiority, and route-specific timing."],
            tasks: [.networkTimingAndAoip, .natIspRoute],
            evidence: ["NetworkDiagnosticsReport", "AoipEvaluationReport", "NetworkAoipCertificationReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .video,
            status: .partial,
            finding: "Video capture, transport, and integrated AV reports exist with audio-first degradation rules.",
            done: ["AVFoundation inventory, video capture, video transport, integrated AV, and integrated profile reports are implemented."],
            missing: ["Run real Blackmagic or ATEM source/output, AV sync, and audio-impact measurements."],
            tasks: [.video],
            evidence: ["VideoCaptureReport", "VideoTransportReport", "IntegratedAvReport", "IntegratedProfileReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .lightingShowControl,
            status: .partial,
            finding: "OSC, ATEM read-only, and lighting fixture gate surfaces exist.",
            done: ["OSC cue, ATEM read-only, and lighting gate reports model armed/disarmed and audio-safe control behavior."],
            missing: ["Probe real isolated show-control devices without unsafe fixture side effects."],
            tasks: [.lightingAndShowControl],
            evidence: ["OscCueReport", "AtemReadOnlyControlReport", "LightingFixtureGateReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .windowsLoLaCompatibility,
            status: .partial,
            finding: "LoLa connector and reverse-engineered packet surfaces are source-covered, but Windows interop remains unproven.",
            done: ["External connector, LoLa capture, packet fixture, and media session reports model recovered control/media behavior."],
            missing: ["Run Windows LoLa TX/RX peer validation and capture WV01-WV10 evidence."],
            tasks: [.windowsLoLaCompatibility],
            evidence: ["ExternalConnectorReport", "LoLaCompatibilityCaptureReport", "LoLaCompatibilityMediaSessionReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .appRecordingOperatorSurface,
            status: .partial,
            finding: "Native shell, operator surface, and recording artifact reports exist at source level.",
            done: ["Native app shell, surface probe, and recording session artifact contracts are implemented."],
            missing: ["Launch the app, record operator-surface proof, and prove side-lane recording without realtime interference."],
            tasks: [.releaseAndFieldPackage],
            evidence: ["NativeAppShellReport", "NativeAppShellSurfaceProbeReport", "RecordingSessionArtifactReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .releaseFieldClosure,
            status: .blocked,
            finding: "Release remains blocked on clean-Mac, signing, notarization, fixture provenance, and field evidence.",
            done: ["Packaging, field runtime proof, release hardening, open-source readiness, and goal completion audit reports exist."],
            missing: ["Attach signed/notarized app evidence, Gatekeeper result, clean-Mac install, package hashes, and field run artifacts."],
            tasks: [.releaseAndFieldPackage],
            evidence: ["PackagingFieldTestReport", "FieldReadyRuntimeProofReport", "ReleaseHardeningReport", "OpenSourceReleaseReadinessReport", "GoalCompletionAuditReport"]
        )),
    ]

    static let realWorldTests = [
        task(CurrentRealWorldTaskDraft(id: .hardwareBaseline, title: "Hardware baseline", blocks: ["Q001"], requiredEvidence: ["Two Apple Silicon Macs", "RME MADI identity", "Blackmagic or ATEM identity", "wired route identity"], acceptanceCondition: "Reference rig report validates physical devices and route evidence.", sourceCompletability: "Not source-completable; requires physical lab evidence.")),
        task(CurrentRealWorldTaskDraft(id: .coreAudioLoopback, title: "Core Audio loopback", blocks: ["Q002", "Q003"], requiredEvidence: ["RME input/output UID", "loopback latency report", "realtime callback proof"], acceptanceCondition: "Measured RME loopback passes fastest-profile constraints.", sourceCompletability: "Source supports the run; PASS requires visible hardware.")),
        task(CurrentRealWorldTaskDraft(id: .twoMacUdpP2P, title: "Two-Mac UDP/P2P", blocks: ["Q004"], requiredEvidence: ["two-peer run plan", "sender report", "receiver report", "packet loss and latency"], acceptanceCondition: "Direct two-Mac run validates media transport without localhost-only evidence.", sourceCompletability: "Source supports the run; PASS requires two hosts.")),
        task(CurrentRealWorldTaskDraft(id: .rxBufferProfiles, title: "RX buffer profiles", blocks: ["Q004", "Q012"], requiredEvidence: ["profile benchmark report", "route identity", "hidden playout growth check"], acceptanceCondition: "Profiles are measured on the same physical route and do not hide latency growth.", sourceCompletability: "Source supports benchmark generation; measured route is external.")),
        task(CurrentRealWorldTaskDraft(id: .plcAndDrift, title: "PLC and drift", blocks: ["Q002", "Q003", "Q004"], requiredEvidence: ["drift report", "fixed-target certification", "LoLa baseline comparison"], acceptanceCondition: "PLC/drift certification passes without target-depth growth or retransmission waits.", sourceCompletability: "Source supports validators; measured baseline is external.")),
        task(CurrentRealWorldTaskDraft(id: .networkTimingAndAoip, title: "Network timing and AoIP", blocks: ["Q005", "Q006", "Q012"], requiredEvidence: ["DSCP observation", "PTP/AoIP availability", "same-path comparison"], acceptanceCondition: "Network timing features are measured and only promoted when superior on the same route.", sourceCompletability: "Source supports reports; route observations are external.")),
        task(CurrentRealWorldTaskDraft(id: .video, title: "Video", blocks: ["Q007"], requiredEvidence: ["real capture device", "video transport report", "AV sync", "audio-impact metrics"], acceptanceCondition: "Video path works while audio remains the protected critical path.", sourceCompletability: "Source supports AV reports; real device evidence is external.")),
        task(CurrentRealWorldTaskDraft(id: .lightingAndShowControl, title: "Lighting and show control", blocks: ["Q008", "Q009"], requiredEvidence: ["OSC peer", "ATEM status", "isolated lighting universe", "audio-impact metrics"], acceptanceCondition: "Show-control probes are safe, isolated, and do not degrade audio timing.", sourceCompletability: "Source supports reports; live device evidence is external.")),
        task(CurrentRealWorldTaskDraft(id: .windowsLoLaCompatibility, title: "Windows LoLa compatibility", blocks: ["WV01", "WV02", "WV03", "WV04", "WV05", "WV06", "WV07", "WV08", "WV09", "WV10"], requiredEvidence: ["Windows peer", "TX/RX capture", "control ACK", "media session evidence"], acceptanceCondition: "Windows LoLa peer validates recovered control/media compatibility.", sourceCompletability: "Source supports connector reports; Windows peer evidence is external.")),
        task(CurrentRealWorldTaskDraft(id: .releaseAndFieldPackage, title: "Release and field package", blocks: ["Q010"], requiredEvidence: ["signed app", "notarization", "Gatekeeper", "clean-Mac install", "field run"], acceptanceCondition: "Release hardening and field runtime proof pass with measured clean-Mac evidence.", sourceCompletability: "Not source-completable; requires signing and field execution.")),
        task(CurrentRealWorldTaskDraft(id: .natIspRoute, title: "NAT/ISP route", blocks: ["Q011", "Q012"], requiredEvidence: ["direct route attempt", "rendezvous/relay report", "fallback decision", "latency comparison"], acceptanceCondition: "Direct-first route policy is measured across non-lab route conditions.", sourceCompletability: "Source supports NAT reports; ISP route behavior is external.")),
    ]

    private struct CurrentEvidenceCrosswalkDraft {
        var lane: CurrentEvidenceLaneID
        var status: CurrentEvidenceStatus
        var finding: String
        var done: [String]
        var missing: [String]
        var tasks: [CurrentRealWorldTestID]
        var evidence: [String]
    }

    private static func row(_ draft: CurrentEvidenceCrosswalkDraft) -> CurrentEvidenceCrosswalkRow {
        CurrentEvidenceCrosswalkRow(
            lane: draft.lane,
            status: draft.status,
            finding: draft.finding,
            doneNow: draft.done,
            missingBeforePass: draft.missing,
            realWorldTaskIDs: draft.tasks,
            sourceEvidence: draft.evidence
        )
    }

    private struct CurrentRealWorldTaskDraft {
        var id: CurrentRealWorldTestID
        var title: String
        var blocks: [String]
        var requiredEvidence: [String]
        var acceptanceCondition: String
        var sourceCompletability: String
    }

    private static func task(_ draft: CurrentRealWorldTaskDraft) -> CurrentRealWorldTestTask {
        CurrentRealWorldTestTask(
            id: draft.id,
            title: draft.title,
            blocks: draft.blocks,
            requiredEvidence: draft.requiredEvidence,
            acceptanceCondition: draft.acceptanceCondition,
            sourceCompletability: draft.sourceCompletability
        )
    }
}
