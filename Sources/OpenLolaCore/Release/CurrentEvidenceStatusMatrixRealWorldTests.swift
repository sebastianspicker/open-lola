// Collects release-readiness evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

extension CurrentEvidenceStatusMatrixFixtures {
    static let realWorldTests = [
        task(CurrentRealWorldTaskDraft(
            id: .hardwareBaseline,
            title: "Hardware baseline",
            blocks: ["Q001"],
            requiredEvidence: [
                "Two Apple Silicon Macs",
                "RME MADI identity",
                "Blackmagic or ATEM identity",
                "wired route identity"
            ],
            acceptanceCondition: "Reference rig report validates physical devices and route evidence.",
            sourceCompletability: "Not source-completable; requires physical lab evidence."
        )),
        task(CurrentRealWorldTaskDraft(
            id: .coreAudioLoopback,
            title: "Core Audio loopback",
            blocks: ["Q002", "Q003"],
            requiredEvidence: ["RME input/output UID", "loopback latency report", "realtime callback proof"],
            acceptanceCondition: "Measured RME loopback passes fastest-profile constraints.",
            sourceCompletability: "Source supports the run; PASS requires visible hardware."
        )),
        task(CurrentRealWorldTaskDraft(
            id: .twoMacUdpP2P,
            title: "Two-Mac UDP/P2P",
            blocks: ["Q004"],
            requiredEvidence: ["two-peer run plan", "sender report", "receiver report", "packet loss and latency"],
            acceptanceCondition: "Direct two-Mac run validates media transport without localhost-only evidence.",
            sourceCompletability: "Source supports the run; PASS requires two hosts."
        )),
        task(CurrentRealWorldTaskDraft(
            id: .rxBufferProfiles,
            title: "RX buffer profiles",
            blocks: ["Q004", "Q012"],
            requiredEvidence: ["profile benchmark report", "route identity", "hidden playout growth check"],
            acceptanceCondition: "Profiles are measured on the same physical route and do not hide latency growth.",
            sourceCompletability: "Source supports benchmark generation; measured route is external."
        )),
        task(CurrentRealWorldTaskDraft(
            id: .plcAndDrift,
            title: "PLC and drift",
            blocks: ["Q002", "Q003", "Q004"],
            requiredEvidence: ["drift report", "fixed-target certification", "LoLa baseline comparison"],
            acceptanceCondition: "PLC/drift certification passes without target-depth growth or retransmission waits.",
            sourceCompletability: "Source supports validators; measured baseline is external."
        )),
        task(CurrentRealWorldTaskDraft(
            id: .networkTimingAndAoip,
            title: "Network timing and AoIP",
            blocks: ["Q005", "Q006", "Q012"],
            requiredEvidence: ["DSCP observation", "PTP/AoIP availability", "same-path comparison"],
            acceptanceCondition: "Network timing features are measured and only promoted "
                + "when superior on the same route.",
            sourceCompletability: "Source supports reports; route observations are external."
        )),
        task(CurrentRealWorldTaskDraft(
            id: .video,
            title: "Video",
            blocks: ["Q007"],
            requiredEvidence: ["real capture device", "video transport report", "AV sync", "audio-impact metrics"],
            acceptanceCondition: "Video path works while audio remains the protected critical path.",
            sourceCompletability: "Source supports AV reports; real device evidence is external."
        )),
        task(CurrentRealWorldTaskDraft(
            id: .lightingAndShowControl,
            title: "Lighting and show control",
            blocks: ["Q008", "Q009"],
            requiredEvidence: ["OSC peer", "ATEM status", "isolated lighting universe", "audio-impact metrics"],
            acceptanceCondition: "Show-control probes are safe, isolated, and do not degrade audio timing.",
            sourceCompletability: "Source supports reports; live device evidence is external."
        )),
        task(CurrentRealWorldTaskDraft(
            id: .windowsLoLaCompatibility,
            title: "Windows LoLa compatibility",
            blocks: ["WV01", "WV02", "WV03", "WV04", "WV05", "WV06", "WV07", "WV08", "WV09", "WV10"],
            requiredEvidence: ["Windows peer", "TX/RX capture", "control ACK", "media session evidence"],
            acceptanceCondition: "Windows LoLa peer validates recovered control/media compatibility.",
            sourceCompletability: "Source supports connector reports; Windows peer evidence is external."
        )),
        task(CurrentRealWorldTaskDraft(
            id: .releaseAndFieldPackage,
            title: "Release and field package",
            blocks: ["Q010"],
            requiredEvidence: ["signed app", "notarization", "Gatekeeper", "clean-Mac install", "field run"],
            acceptanceCondition: "Release hardening and field runtime proof pass with measured clean-Mac evidence.",
            sourceCompletability: "Not source-completable; requires signing and field execution."
        )),
        task(CurrentRealWorldTaskDraft(
            id: .natIspRoute,
            title: "NAT/ISP route",
            blocks: ["Q011", "Q012"],
            requiredEvidence: [
                "direct route attempt",
                "rendezvous/relay report",
                "fallback decision",
                "latency comparison"
            ],
            acceptanceCondition: "Direct-first route policy is measured across non-lab route conditions.",
            sourceCompletability: "Source supports NAT reports; ISP route behavior is external."
        ))
    ]

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
