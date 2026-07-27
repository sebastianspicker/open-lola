// Collects release-readiness evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

enum CurrentEvidenceStatusMatrixFixtures {
    static let sources = [
        CurrentEvidenceStatusMatrixSource(
            title: "Current public state",
            path: "docs/current-state.md",
            role: "Primary current status and real-world test task matrix"
        ),
        CurrentEvidenceStatusMatrixSource(
            title: "Validation methodology",
            path: "docs/validation-methodology.md",
            role: "Public evidence requirements and validation rules"
        ),
        CurrentEvidenceStatusMatrixSource(
            title: "Open questions",
            path: "docs/open-questions.md",
            role: "Q001-Q012 closure state and external evidence gates"
        ),
        CurrentEvidenceStatusMatrixSource(
            title: "Windows LoLa compatibility scope",
            path: "docs/compatibility-scope.md",
            role: "Publication-safe Windows-peer scope and remaining validation gates"
        ),
        CurrentEvidenceStatusMatrixSource(
            title: "Testing and verification",
            path: "docs/testing.md",
            role: "Active source, runtime, and manual evidence gates"
        )
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
            done: [
                "Device inventory, RME path, realtime engine, MADI TX/RX, and full-duplex reports are source-covered."
            ],
            missing: ["Run physical Core Audio loopback on visible RME MADI hardware."],
            tasks: [.coreAudioLoopback],
            evidence: [
                "CoreAudioInventoryReport",
                "RmeFastestAudioPathReport",
                "RealtimeAudioEngineReport",
                "MadiFullDuplexReport"
            ]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .udpP2PTransport,
            status: .sourceDone,
            finding: "UDP PCM, direct P2P, and two-peer command/report surfaces exist.",
            done: ["Packet, route, loopback, NAT, direct peer, mesh, and two-peer plan reports are implemented."],
            missing: ["Run direct two-Mac route and packet-loss/latency evidence outside localhost."],
            tasks: [.twoMacUdpP2P, .natIspRoute],
            evidence: [
                "UdpPcmRouteReport",
                "MacToMacRouteCertificationReport",
                "DirectPeerTwoPeerPrototypeReport",
                "NatFriendlyRouteReport"
            ]
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
            done: [
                "Network diagnostics, route certification, AoIP evaluation, "
                    + "and network-AoIP certification reports exist."
            ],
            missing: [
                "Capture DSCP behavior, PTP availability, AoIP superiority or non-superiority, "
                    + "and route-specific timing."
            ],
            tasks: [.networkTimingAndAoip, .natIspRoute],
            evidence: ["NetworkDiagnosticsReport", "AoipEvaluationReport", "NetworkAoipCertificationReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .video,
            status: .partial,
            finding: "Video capture, transport, and integrated AV reports exist with audio-first degradation rules.",
            done: [
                "AVFoundation inventory, video capture, video transport, integrated AV, "
                    + "and integrated profile reports are implemented."
            ],
            missing: ["Run real Blackmagic or ATEM source/output, AV sync, and audio-impact measurements."],
            tasks: [.video],
            evidence: ["VideoCaptureReport", "VideoTransportReport", "IntegratedAvReport", "IntegratedProfileReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .lightingShowControl,
            status: .partial,
            finding: "OSC, ATEM read-only, and lighting fixture gate surfaces exist.",
            done: [
                "OSC cue, ATEM read-only, and lighting gate reports model armed/disarmed "
                    + "and audio-safe control behavior."
            ],
            missing: ["Probe real isolated show-control devices without unsafe fixture side effects."],
            tasks: [.lightingAndShowControl],
            evidence: ["OscCueReport", "AtemReadOnlyControlReport", "LightingFixtureGateReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .windowsLoLaCompatibility,
            status: .partial,
            finding: "LoLa connector and reverse-engineered packet surfaces are source-covered, "
                + "but Windows interop remains unproven.",
            done: [
                "External connector, LoLa capture, packet fixture, and media session reports model recovered "
                    + "control/media behavior."
            ],
            missing: ["Run Windows LoLa TX/RX peer validation and capture WV01-WV10 evidence."],
            tasks: [.windowsLoLaCompatibility],
            evidence: [
                "ExternalConnectorReport",
                "LoLaCompatibilityCaptureReport",
                "LoLaCompatibilityMediaSessionReport"
            ]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .appRecordingOperatorSurface,
            status: .partial,
            finding: "Native shell, operator surface, and recording artifact reports exist at source level.",
            done: ["Native app shell, surface probe, and recording session artifact contracts are implemented."],
            missing: [
                "Launch the app, record operator-surface proof, and prove side-lane recording "
                    + "without realtime interference."
            ],
            tasks: [.releaseAndFieldPackage],
            evidence: ["NativeAppShellReport", "NativeAppShellSurfaceProbeReport", "RecordingSessionArtifactReport"]
        )),
        row(CurrentEvidenceCrosswalkDraft(
            lane: .releaseFieldClosure,
            status: .blocked,
            finding: "Release remains blocked on clean-Mac, signing, notarization, fixture provenance, "
                + "and field evidence.",
            done: [
                "Packaging, field runtime proof, release hardening, open-source readiness, "
                    + "and goal completion audit reports exist."
            ],
            missing: [
                "Attach signed/notarized app evidence, Gatekeeper result, clean-Mac install, package hashes, "
                    + "and field run artifacts."
            ],
            tasks: [.releaseAndFieldPackage],
            evidence: [
                "PackagingFieldTestReport",
                "FieldReadyRuntimeProofReport",
                "ReleaseHardeningReport",
                "OpenSourceReleaseReadinessReport",
                "GoalCompletionAuditReport"
            ]
        ))
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

}
