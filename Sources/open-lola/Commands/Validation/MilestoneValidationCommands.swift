import Foundation
import OpenLolaCore

func handleMilestoneValidationCommand(_ arguments: [String]) throws -> Bool {
    switch arguments {
    case let args where args.count == 2 && args[0] == "validate-latency-benchmark-report":
        try validateReport(at: args[1], as: LatencyBenchmarkReport.self, label: "latency benchmark report")
    case let args where args.count == 2 && args[0] == "validate-rx-buffer-benchmark-report":
        try validateReport(
            at: args[1],
            as: RxBufferBenchmarkReport.self,
            label: "RX buffer benchmark report"
        )
    case let args where args.count == 2 && args[0] == "validate-latency-tuning-report":
        try validateReport(at: args[1], as: LatencyTuningReport.self, label: "latency tuning report")
    case let args where args.count == 2 && args[0] == "validate-drift-plc-report":
        try validateReport(at: args[1], as: DriftPlcReport.self, label: "drift-plc report")
    case let args where args.count == 2 && args[0] == "validate-drift-plc-certification-report":
        try validateReport(
            at: args[1],
            as: DriftPlcFixedTargetCertificationReport.self,
            label: "drift-plc fixed-target certification report"
        )
    case let args where args.count == 2 && args[0] == "validate-aoip-report":
        try validateReport(at: args[1], as: AoipEvaluationReport.self, label: "aoip evaluation report")
    case let args where args.count == 2 && args[0] == "validate-network-aoip-certification-report":
        try validateReport(
            at: args[1],
            as: NetworkAoipCertificationReport.self,
            label: "network AoIP certification report"
        )
    case let args where args.count == 2 && args[0] == "validate-video-capture-report":
        try validateReport(at: args[1], as: VideoCaptureReport.self, label: "video capture report")
    case let args where args.count == 2 && args[0] == "validate-video-capture-inventory":
        try validateReport(
            at: args[1],
            as: AVFoundationVideoDeviceInventoryReport.self,
            label: "video capture inventory"
        )
    case let args where args.count == 2 && args[0] == "validate-video-transport-report":
        try validateReport(at: args[1], as: VideoTransportReport.self, label: "video transport report")
    case let args where args.count == 2 && args[0] == "validate-integrated-av-report":
        try validateReport(at: args[1], as: IntegratedAvReport.self, label: "integrated A/V report")
    case let args where args.count == 2 && args[0] == "validate-integrated-profile-report":
        try validateReport(
            at: args[1],
            as: IntegratedProfileReport.self,
            label: "integrated profile report",
            extraLines: { ["aggregate-verdict: \($0.aggregateSubordinateVerdict.rawValue)"] }
        )
    case let args where args.count == 2 && args[0] == "validate-hardware-validation-report":
        try validateReport(at: args[1], as: HardwareValidationReport.self, label: "hardware validation report")
    case let args where args.count == 2 && args[0] == "validate-osc-cue-report":
        try validateReport(at: args[1], as: OscCueReport.self, label: "OSC cue report")
    case let args where args.count == 2 && args[0] == "validate-atem-control-report":
        try validateReport(at: args[1], as: AtemReadOnlyControlReport.self, label: "ATEM read-only control report")
    case let args where args.count == 2 && args[0] == "validate-lighting-gate-report":
        try validateReport(at: args[1], as: LightingFixtureGateReport.self, label: "lighting fixture gate report")
    case let args where args.count == 2 && args[0] == "validate-native-app-shell-report":
        try validateReport(at: args[1], as: NativeAppShellReport.self, label: "native app shell report")
    case let args where args.count == 2 && args[0] == "validate-native-app-shell-surface-probe-report":
        try validateReport(
            at: args[1],
            as: NativeAppShellSurfaceProbeReport.self,
            label: "native app shell surface probe report"
        )
    case let args where args.count == 2 && args[0] == "validate-recording-session-report":
        try validateReport(
            at: args[1],
            as: RecordingSessionArtifactReport.self,
            label: "recording session artifact report"
        )
    case let args where args.count == 2 && args[0] == "validate-packaging-field-report":
        try validateReport(at: args[1], as: PackagingFieldTestReport.self, label: "packaging field-test report")
    case let args where args.count == 2 && args[0] == "validate-field-runtime-proof":
        try validateReport(at: args[1], as: FieldReadyRuntimeProofReport.self, label: "field-ready runtime proof")
    case let args where args.count == 2 && args[0] == "validate-lola-parity-deferred-ledger":
        try validateReport(
            at: args[1],
            as: LoLaParityDeferredLedgerReport.self,
            label: "LoLa parity deferred ledger"
        )
    case let args where args.count == 2 && args[0] == "validate-faster-than-lola-closure":
        try validateReport(
            at: args[1],
            as: FasterThanLoLaClosureReport.self,
            label: "faster-than-LoLa closure report"
        )
    case let args where args.count == 2 && args[0] == "validate-external-connector-report":
        try validateReport(
            at: args[1],
            as: ExternalConnectorReport.self,
            label: "external connector report",
            extraLines: {
                [
                    "source-level-verdict: \($0.sourceLevelVerdict.rawValue)",
                    "real-world-verdict: \($0.realWorldVerdict.rawValue)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-external-connector-session-report":
        try validateReport(
            at: args[1],
            as: ExternalConnectorSessionReport.self,
            label: "external connector session report",
            extraLines: {
                [
                    "connector: \($0.connector.rawValue)",
                    "role: \($0.role.rawValue)",
                    "dry-run: \($0.dryRun)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-external-connector-connection-plan":
        try validateReport(
            at: args[1],
            as: ExternalConnectorConnectionPlanReport.self,
            label: "external connector connection plan",
            extraLines: {
                [
                    "connector: \($0.connector.rawValue)",
                    "endpoints: \($0.endpoints.count)",
                    "media: \($0.mediaMode.rawValue)",
                    "run-directory: \($0.runDirectory)",
                    "preflight-command: \($0.preflightCommand == nil ? "none" : "present")",
                    "shell-commands: \($0.endpoints.count)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-external-connector-nmp-plan":
        try validateReport(
            at: args[1],
            as: ExternalConnectorNmpPlanReport.self,
            label: "external connector NMP plan",
            extraLines: {
                [
                    "connectors: \($0.connectors.count)",
                    "plans: \($0.plans.count)",
                    "media: \($0.mediaMode.rawValue)",
                    "run-directory: \($0.runDirectory)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-external-connector-nmp-preflight":
        try validateReport(
            at: args[1],
            as: ExternalConnectorNmpPreflightReport.self,
            label: "external connector NMP preflight",
            extraLines: {
                [
                    "plan: \($0.planID)",
                    "results: \($0.results.count)",
                    "failing-results: \($0.results.filter { $0.report?.verdict == .fail }.count)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-external-connector-nmp-endpoint-run":
        try validateReport(
            at: args[1],
            as: ExternalConnectorNmpEndpointRunReport.self,
            label: "external connector NMP endpoint run",
            extraLines: {
                [
                    "plan: \($0.planID)",
                    "side: \($0.side.rawValue)",
                    "results: \($0.results.count)",
                    "failing-results: \($0.results.filter { $0.report.verdict == .fail }.count)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-external-connector-nmp-workflow":
        try validateReport(
            at: args[1],
            as: ExternalConnectorNmpWorkflowReport.self,
            label: "external connector NMP workflow",
            extraLines: {
                [
                    "plan: \($0.plan.id)",
                    "preflight-verdict: \($0.preflight.verdict.rawValue)",
                    "endpoint-verdict: \($0.endpointRun.verdict.rawValue)",
                    "side: \($0.side.rawValue)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-lola-capture-report":
        try validateReport(
            at: args[1],
            as: LoLaCompatibilityCaptureReport.self,
            label: "LoLa compatibility capture report",
            extraLines: {
                [
                    "input-format: \($0.inputFormat.rawValue)",
                    "packets: \($0.summary.packetCount)",
                    "media-envelope-packets: \($0.summary.lolaMediaEnvelopePacketCount)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-lola-packet-fixture-report":
        try validateReport(
            at: args[1],
            as: LoLaCompatibilityPacketFixtureReport.self,
            label: "LoLa packet fixture report",
            extraLines: {
                [
                    "frames: \($0.frames.count)",
                    "decoded-packets: \($0.decodedCapturePacketCount)",
                    "capture-bytes: \($0.captureByteCount)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-external-connector-executable-preflight-report":
        try validateReport(
            at: args[1],
            as: ExternalConnectorExecutablePreflightReport.self,
            label: "external connector executable preflight",
            extraLines: {
                [
                    "probes: \($0.probes.count)",
                    "failing-probes: \($0.probes.filter { $0.verdict == .fail }.count)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-lola-media-session-report":
        try validateReport(
            at: args[1],
            as: LoLaCompatibilityMediaSessionReport.self,
            label: "LoLa compatibility media session report",
            extraLines: {
                [
                    "role: \($0.role.rawValue)",
                    "frames: \($0.frames.count)",
                    "real-link-transmitted: \($0.realLinkTransmitted)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-goal-codewise-closure-report":
        try validateReport(
            at: args[1],
            as: GoalCodewiseClosureReport.self,
            label: "GOAL.md codewise closure report",
            extraLines: { ["real-world-verdict: \($0.realWorldVerdict.rawValue)"] }
        )
    case let args where args.count == 2 && args[0] == "validate-goal-runtime-evidence-template-report":
        try validateReport(
            at: args[1],
            as: GoalRuntimeEvidenceTemplateReport.self,
            label: "GOAL.md runtime evidence template",
            extraLines: { ["real-world-verdict: \($0.realWorldVerdict.rawValue)"] }
        )
    case let args where args.count == 2 && args[0] == "validate-goal-runtime-preflight-report":
        try validateReport(
            at: args[1],
            as: GoalRuntimePreflightReport.self,
            label: "GOAL.md runtime preflight report",
            extraLines: { ["real-world-verdict: \($0.realWorldVerdict.rawValue)"] }
        )
    case let args where args.count == 2 && args[0] == "validate-goal-completion-audit-report":
        try validateReport(
            at: args[1],
            as: GoalCompletionAuditReport.self,
            label: "GOAL.md completion audit report",
            extraLines: {
                [
                    "real-world-verdict: \($0.realWorldVerdict.rawValue)",
                    "blockers: \($0.blockers.count)",
                    "next-actions: \($0.nextActions.count)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-current-evidence-status-matrix-report":
        try validateReport(
            at: args[1],
            as: CurrentEvidenceStatusMatrixReport.self,
            label: "current evidence status matrix report",
            extraLines: {
                [
                    "source-matrix: \($0.sourceMatrixPath)",
                    "real-world-tasks: \($0.summary.realWorldTaskCount)",
                ]
            }
        )
    case let args where args.count == 2 && args[0] == "validate-release-hardening-report":
        try validateReport(at: args[1], as: ReleaseHardeningReport.self, label: "release hardening report")
    case let args where args.count == 2 && args[0] == "validate-open-source-release-readiness-report":
        try validateReport(
            at: args[1],
            as: OpenSourceReleaseReadinessReport.self,
            label: "open-source release readiness report"
        )
    default:
        return false
    }
    return true
}
