// Collects measurement evidence evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
extension ReportSchemaInventory {
    static let entriesPart4: [ReportSchemaInventoryEntry] = [
        schema(.init(
            name: "LoLaCompatibilityMediaSessionReport",
            family: "LoLa media source-level TX/RX",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaSession.swift",
            validationFiles: [
                            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift",
                            "Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityUdpMedia.swift"
            ],
            validatorCommands: ["validate-lola-media-session-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Source-level, post-control UDP socket, and opt-in raw-link LoLa media TX/RX generation" +
                    " and validation. It covers recovered Ethernet/IPv4/UDP framing, little-endian media" +
                    " bodies, audio normal fragments, video preludes, and video normal fragments while real" +
                    " Windows interoperability remains partial."
        )),
        schema(.init(
            name: "FasterThanLoLaClosureReport",
            family: "faster-than-LoLa closure",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Release/FasterThanLoLaClosure.swift",
            validationFiles: [],
            validatorCommands: ["validate-faster-than-lola-closure"],
            fixtureGroup: nil,
            syntheticSmokeCommand: "faster-than-lola-closure-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/FasterThanLoLaClosureTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes: "PASS requires measured LoLa baseline, latency win, no artifacts, and enough run duration."
        )),
        schema(.init(
            name: "GoalCodewiseClosureReport",
            family: "GOAL.md codewise closure",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Release/Goal/GoalCodewiseClosure.swift",
            validationFiles: [],
            validatorCommands: ["validate-goal-codewise-closure-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/GoalCodewiseClosureTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Codewise PASS ledger; real-world verdict remains PARTIAL because physical measurement," +
                    " hardware, signing, and clean-Mac evidence live in runtime gates."
        )),
        schema(.init(
            name: "GoalRuntimeEvidenceTemplateReport",
            family: "GOAL.md runtime evidence template",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Release/Goal/GoalRuntimeEvidenceTemplate.swift",
            validationFiles: [],
            validatorCommands: ["validate-goal-runtime-evidence-template-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Machine-readable runtime handoff; every deliverable remains PARTIAL until physical" +
                    " hardware, route, signing, and clean-Mac evidence is attached."
        )),
        schema(.init(
            name: "GoalRuntimePreflightReport",
            family: "GOAL.md runtime host preflight",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Release/Goal/GoalRuntimePreflight.swift",
            validationFiles: [],
            validatorCommands: ["validate-goal-runtime-preflight-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/GoalRuntimePreflightTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Executable current-host blocker report; it records visible audio/video/signing" +
                    " prerequisites but cannot replace physical two-Mac or clean-Mac evidence."
        )),
        schema(.init(
            name: "GoalCompletionAuditReport",
            family: "GOAL.md requirement-to-artifact completion audit",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Release/Goal/GoalCompletionAudit.swift",
            validationFiles: [],
            validatorCommands: ["validate-goal-completion-audit-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/GoalCompletionAuditTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Traceability audit maps every product goal, Apple Silicon path, professional AV" +
                    " deliverable, release blocker, and verification gate to source artifacts while keeping" +
                    " real-world evidence partial."
        )),
        schema(.init(
            name: "CurrentEvidenceStatusMatrixReport",
            family: "current evidence status matrix",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Release/CurrentEvidenceStatusMatrix.swift",
            validationFiles: [],
            validatorCommands: ["validate-current-evidence-status-matrix-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/CurrentEvidenceStatusMatrixTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Machine-readable crosswalk from research, evidence matrix, reverse-engineering findings," +
                    " and mac-port plan to current source status and RWT tasks; PASS remains blocked until" +
                    " real-world evidence is attached."
        )),
        schema(.init(
            name: "ReleaseHardeningReport",
            family: "release hardening",
            evidenceClass: .cleanMac,
            sourceFile: "Sources/OpenLolaCore/Release/ReleaseHardening.swift",
            validationFiles: [],
            validatorCommands: ["validate-release-hardening-report"],
            fixtureGroup: "ReleaseHardeningReports",
            syntheticSmokeCommand: "release-hardening-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "PASS requires measured reports, verification gates, public-doc audit, package PASS," +
                    " signing PASS, clean-Mac PASS, and no remaining partial gates."
        )),
        schema(.init(
            name: "OpenSourceReleaseReadinessReport",
            family: "open-source release readiness",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift",
            validationFiles: [],
            validatorCommands: ["validate-open-source-release-readiness-report"],
            fixtureGroup: "OpenSourceReleaseReadinessReports",
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/OpenSourceReleaseReadinessTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "PASS requires final source and documentation licenses, final notices, fixture" +
                    " provenance, allowlist release staging, reviewer signoff, and public approval."
        )),
        schema(.init(
            name: "MadiReceiveSyntheticReport",
            family: "MADI receive",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Audio/MADI/MadiReceiveReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-madi-rx-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: "madi-rx-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/MadiReceiveTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Synthetic receive report validates bounded buffers, overrun policy, and same-deadline" +
                    " recovery contracts."
        )),
        schema(.init(
            name: "MadiFullDuplexReport",
            family: "MADI full-duplex",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexReport.swift",
            validationFiles: [],
            validatorCommands: ["validate-madi-full-duplex-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: "madi-full-duplex-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "Report validates source-level and socket-backed full-duplex plus receiver-mix evidence;" +
                    " PASS still requires physical RME evidence."
        )),
        schema(.init(
            name: "PerformanceAuditReport",
            family: "performance audit",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReport.swift",
            validationFiles: ["Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReportValidation.swift"],
            validatorCommands: ["validate-performance-audit-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: "performance-audit-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/PerformanceAuditTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes:
                "PASS requires documented hot paths, worker boundaries, counter evidence, and acceleration decisions."
        )),
        schema(.init(
            name: "E2EBenchmarkReport",
            family: "E2E benchmark",
            evidenceClass: .measured,
            sourceFile: "Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift",
            validationFiles: ["Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReportValidation.swift"],
            validatorCommands: ["validate-e2e-benchmark-report"],
            fixtureGroup: nil,
            syntheticSmokeCommand: "e2e-benchmark-synthetic-smoke",
            relatedTestFiles: ["Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift"],
            passRequiresMeasuredEvidence: true,
            notes:
                "PASS requires measured run, physical two-peer evidence, required profile, and no" +
                    " video-induced audio timing regression."
        )),
        schema(.init(
            name: "CoreAudioInventoryReport",
            family: "CoreAudio inventory",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventory.swift",
            validationFiles: [],
            validatorCommands: [],
            fixtureGroup: "CoreAudioInventory",
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes: "Inventory report is source/platform discovery evidence, not runtime PASS."
        )),
        schema(.init(
            name: "MeasurementReport",
            family: "generic measurement fixture",
            evidenceClass: .sourceLevel,
            sourceFile: "Sources/OpenLolaCore/Evidence/MeasurementReport.swift",
            validationFiles: [],
            validatorCommands: [],
            fixtureGroup: "MeasurementReports",
            syntheticSmokeCommand: nil,
            relatedTestFiles: ["Tests/OpenLolaCoreTests/MeasurementReportFixtureTests.swift"],
            passRequiresMeasuredEvidence: false,
            notes: "Generic measurement fixtures preserve legacy/source contract shape for docs and validation tests."
        ))
    ]
}
