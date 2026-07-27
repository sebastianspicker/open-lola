// Collects measurement evidence evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
extension ReportSchemaInventory {
    static let entriesPart2: [ReportSchemaInventoryEntry] = [
        schema(.init(
            name: "DirectPeerMeshRuntimeReport",
            family: "direct P2P mesh runtime",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Network/P2P/DirectPeerMeshRuntimeReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-direct-p2p-mesh-runtime-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "Localhost runtime smoke routes UDP PCM v2 audio fragments across every directed" +
                    " three-or-more-peer route; PASS still requires physical multi-peer media evidence."
        )),
        schema(.init(
            name: "LatencyBenchmarkReport",
            family: "latency benchmark",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-latency-benchmark-report"],
            fixtureGroup: "LatencyBenchmarkReports",
            syntheticSmokeCommand: "latency-benchmark-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires measured critical-path evidence and one-way threshold compliance."
        )),
        schema(.init(
            name: "RxBufferBenchmarkReport",
            family: "RX buffer benchmark",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Timing/RxBufferBenchmarkReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-rx-buffer-benchmark-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/RxBufferingTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "Local runtime benchmark covers all RX profiles; PASS still requires same-route two-Mac" +
                    " physical benchmark evidence."
        )),
        schema(.init(
            name: "LatencyTuningReport",
            family: "latency tuning",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Timing/LatencyTuningReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-latency-tuning-report"],
            fixtureGroup: "LatencyTuningReports",
            syntheticSmokeCommand: "latency-tuning-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/LatencyTuningReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires baseline comparison and evidence for promoted latency changes."
        )),
        schema(.init(
            name: "DriftPlcReport",
            family: "drift and PLC",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Timing/DriftPlcReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-drift-plc-report"],
            fixtureGroup: "DriftPlcReports",
            syntheticSmokeCommand: "drift-plc-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/DriftPlcReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "PASS rejects callback correction, retransmission waits, hidden playout growth, and" +
                    " target-depth growth."
        )),
        schema(.init(
            name: "DriftPlcFixedTargetCertificationReport",
            family: "fixed-target drift PLC certification",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift",
            validationFiles: [],
            validatorCommands: ["validate-drift-plc-certification-report"],
            fixtureGroup: "DriftPlcFixedTargetCertificationReports",
            syntheticSmokeCommand: "drift-plc-certification-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/DriftPlcFixedTargetCertificationFixtures+TestSupport.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires accepted route, realtime engine, drift report, and LoLa baseline comparison."
        )),
        schema(.init(
            name: "AoipEvaluationReport",
            family: "AoIP evaluation",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Network/Diagnostics/AoipEvaluationReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-aoip-report"],
            fixtureGroup: "AoipEvaluationReports",
            syntheticSmokeCommand: "aoip-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "PASS requires measured superiority and same-path baseline; AoIP cannot replace direct-first defaults."
        )),
        schema(.init(
            name: "NetworkAoipCertificationReport",
            family: "network AoIP certification",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Network/Diagnostics/NetworkAoipCertification.swift",
            validationFiles: [],
            validatorCommands: ["validate-network-aoip-certification-report"],
            fixtureGroup: "NetworkAoipCertificationReports",
            syntheticSmokeCommand: "network-aoip-certification-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NetworkAoipCertificationFixtures+TestSupport.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires accepted route, drift certification, and AoIP reports."
        )),
        schema(.init(
            name: "VideoCaptureReport",
            family: "video capture",
            evidenceClass: .externalWitnessed,
            sourceFile: "Sources/OpenLolaCore/Video/VideoCaptureReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-video-capture-report"],
            fixtureGroup: "VideoCaptureReports",
            syntheticSmokeCommand: "video-capture-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires production capture evidence and audio impact metrics."
        )),
        schema(.init(
            name: "AVFoundationVideoDeviceInventoryReport",
            family: "video capture inventory",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift",
            validationFiles: [],
            validatorCommands: ["validate-video-capture-inventory"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes: "Inventory records device visibility and Blackmagic candidate detection; it is not a capture PASS."
        )),
        schema(.init(
            name: "VideoTransportReport",
            family: "video transport",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Video/VideoTransportReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-video-transport-report"],
            fixtureGroup: "VideoTransportReports",
            syntheticSmokeCommand: "video-transport-synthetic-smoke",
            relatedTestFiles: [
                            "Tests/OpenLolaCoreTests/VideoTransportReportTests.swift",
                            "Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift"
            ],
            passRequiresMeasuredEvidence: true,
            notes:
                "Socket-backed UDP raw-fragment reports exist, including staged multi-stream test-pattern" +
                    " probes; PASS still requires Blackmagic or ATEM source/output, raw route baseline, AV" +
                    " sync, and audio-protective degradation."
        )),
        schema(.init(
            name: "IntegratedAvReport",
            family: "integrated AV",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Integration/IntegratedAvReport.swift",
            validationFiles: ["Sources/OpenLolaCore/Integration/IntegratedAvReportValidation.swift"],
            validatorCommands: ["validate-integrated-av-report"],
            fixtureGroup: "IntegratedAvReports",
            syntheticSmokeCommand: "integrated-av-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "PASS rejects synthetic reports and requires audio-only baseline, P04 proof," +
                    " video/control evidence, and stable audio metrics."
        )),
        schema(.init(
            name: "IntegratedProfileReport",
            family: "integrated profile",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Integration/IntegratedProfileReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-integrated-profile-report"],
            fixtureGroup: "IntegratedProfileReports",
            syntheticSmokeCommand: "integrated-profile-synthetic-smoke",
            relatedTestFiles: [
                            "Tests/OpenLolaCoreTests/IntegratedProfileReportTests.swift",
                            "Tests/OpenLolaCoreTests/IntegratedProfileRunEvidenceTests.swift"
            ],
            passRequiresMeasuredEvidence: true,
            notes:
                "integrated-profile-run can aggregate measured runtime reports; PASS still requires" +
                    " physical subordinate evidence and full matrix benchmarks."
        )),
        schema(.init(
            name: "HardwareValidationReport",
            family: "hardware validation",
            evidenceClass: .externalWitnessed,
            sourceFile: "Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-hardware-validation-report"],
            fixtureGroup: "HardwareValidationReports",
            syntheticSmokeCommand: "hardware-validation-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/HardwareValidationReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "PASS requires RME MADI, Blackmagic/ATEM identity, fastest profile acceptance, and campus" +
                    " route evidence."
        )),
        schema(.init(
            name: "OscCueReport",
            family: "OSC cue control",
            evidenceClass: .externalWitnessed,
            sourceFile: "Sources/OpenLolaCore/Control/OscCueProbe.swift",
            validationFiles: [],
            validatorCommands: ["validate-osc-cue-report"],
            fixtureGroup: "OscCueReports",
            syntheticSmokeCommand: "osc-cue-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/OscCueReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires live/external peer evidence and no audio-latency impact."
        )),
        schema(.init(
            name: "AtemReadOnlyControlReport",
            family: "ATEM read-only control",
            evidenceClass: .externalWitnessed,
            sourceFile: "Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift",
            validationFiles: [],
            validatorCommands: ["validate-atem-control-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/IntegratedAvReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS must keep commands disarmed and evidence read-only control status."
        )),
        schema(.init(
            name: "LightingFixtureGateReport",
            family: "lighting fixture gate",
            evidenceClass: .externalWitnessed,
            sourceFile: "Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-lighting-gate-report"],
            fixtureGroup: "LightingFixtureGateReports",
            syntheticSmokeCommand: "lighting-gate-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires armed isolated universe, fixture owner match, and audio-safe policy."
        )),
        schema(.init(
            name: "NativeAppShellReport",
            family: "macOS app shell",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Platform/NativeAppShell.swift",
            validationFiles: [],
            validatorCommands: ["validate-native-app-shell-report"],
            fixtureGroup: "NativeAppShellReports",
            syntheticSmokeCommand: "native-app-shell-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/NativeAppShellTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes: "Source-level app shell report ensures UI does not own realtime paths."
        ))
    ]
}
