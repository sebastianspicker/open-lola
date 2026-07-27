// Records ownership rows for timing, video, control, evidence, release, and app surfaces in the second inventory partition.
import Foundation

extension SourceOwnershipInventory {
    static let entriesPart2: [SourceOwnershipEntry] = [
        own(.init(
            group: .timingLatencyBuffering,
            purpose: "Clock, drift/PLC, latency profiles, RX buffering, and impairment simulation.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Timing/",
            "Sources/OpenLolaCore/Timing/MediaClock.swift", "Sources/OpenLolaCore/Timing/DriftPlcReport.swift",
            "Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift",
                "Sources/OpenLolaCore/Timing/LatencyProfileContracts.swift",

            "Sources/OpenLolaCore/Timing/RxBuffering.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Timing/", runtimeRole: .timingAndBuffering,
            owner: "Timing and buffering owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/MediaClockTests.swift", "Tests/OpenLolaCoreTests/DriftPlcReportTests.swift",
            "Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift",
                "Tests/OpenLolaCoreTests/RxBufferingTests.swift"
        ], relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/LatencyBenchmarkReports/valid/latency-benchmark-partial.json"],
            relatedDocs: ["docs/latency-budget.md", "docs/rx-buffering.md"], refactorRisk: .medium,
            moveState: .notSelected, status: .active, confidence: .confirmed, validationCommands: ["swift test --filter Latency"],
            improvementRecommendation: "Consider behavior-neutral file splits only when clock, drift, profile, or buffering edits require " +
                "them.")),

        own(.init(
            group: .videoCaptureTransport,
            purpose: "Video capture, transport packetization, reassembly, renderer, and multistream contracts.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Video/",
            "Sources/OpenLolaCore/Video/VideoCaptureReport.swift",
                "Sources/OpenLolaCore/Video/VideoTransportPacket.swift",

            "Sources/OpenLolaCore/Video/VideoTransportReport.swift",
                "Sources/OpenLolaCore/Video/VideoOutputRenderer.swift",

            "Sources/OpenLolaCore/Video/MultiVideoStreams.swift",
                "Sources/OpenLolaCore/Video/VideoTransportMultiStreamRuntime.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Video/", runtimeRole: .videoPath,
            owner: "Video transport owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift",
                "Tests/OpenLolaCoreTests/VideoTransportReportTests.swift",

            "Tests/OpenLolaCoreTests/VideoTransportRunnerTests.swift",
                "Tests/OpenLolaCoreTests/MultiVideoTransportTests.swift"
        ], relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/VideoTransportReports/valid/video-transport-partial.json"],
            relatedDocs: ["docs/video-blackmagic-atem.md", "docs/current-state.md"], refactorRisk: .high,
            moveState: .notSelected, status: .active, confidence: .confirmed, validationCommands: ["swift test --filter Video"],
            improvementRecommendation: "Keep C07 matrix and video fixtures synchronized with video path changes.")),

        own(.init(
            group: .controlLightingAtemOsc,
            purpose: "OSC cue loop, ATEM read-only boundary, and lighting fixture gate contracts.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Control/",
            "Sources/OpenLolaCore/Control/OscCueProbe.swift", "Sources/OpenLolaCore/Control/OscCueRunners.swift",
            "Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift",
                "Sources/OpenLolaCore/Control/LightingFixtureGate.swift",

            "Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Control/", runtimeRole: .externalControlGate,
            owner: "Control integration owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/OscCueReportTests.swift", "Tests/OpenLolaCoreTests/LightingFixtureGateTests.swift"
        ], relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/OscCueReports/valid/osc-cue-partial.json"],
            relatedDocs: ["docs/lighting-control.md", "docs/current-state.md"], refactorRisk: .high,
            moveState: .notSelected, status: .active, confidence: .confirmed, validationCommands: ["swift test --filter OscCueReportTests"],
            improvementRecommendation: "Keep read-only/destructive-control safeguards visible before any control behavior change.")),
        own(.init(
            group: .evidenceReportsValidation,
            purpose: "Report schema inventory, validator surface, measured fixtures, reference rig, and hardware validation.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Evidence/",
            "Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift",
            "Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift",
            "Sources/OpenLolaCore/Evidence/MeasurementReport.swift",
            "Sources/OpenLolaCore/Evidence/VerdictValidationPolicy.swift",
            "Sources/OpenLolaCore/Evidence/ReferenceRigReport.swift",
            "Sources/OpenLolaCore/Evidence/ReferenceRigHelpers.swift",
            "Sources/OpenLolaCore/Evidence/ReferenceRigReportValidation.swift",
            "Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift",
            "Sources/OpenLolaCore/Evidence/HardwareValidationRun.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Evidence/", runtimeRole: .evidenceContract,
            owner: "Evidence and validation owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift",
                "Tests/OpenLolaCoreTests/MeasurementReportFixtureTests.swift",

            "Tests/OpenLolaCoreTests/ReferenceRigReportTests.swift",
                "Tests/OpenLolaCoreTests/HardwareValidationReportTests.swift",

            "Tests/OpenLolaCoreTests/VerdictValidationPolicyTests.swift"
        ], relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/MeasurementReports/valid/network-valid.json"],
            relatedDocs: ["docs/current-state.md", "docs/testing.md"], refactorRisk: .medium,
            moveState: .notSelected, status: .active, confidence: .confirmed, validationCommands: ["swift test --filter ReportSchemaInventoryTests"],
            improvementRecommendation: "Keep report schema inventory paths synchronized atomically.")),
        own(.init(
            group: .benchmarksPerformance,
            purpose: "Latency, performance, and end-to-end benchmark contracts and synthetic smokes.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Benchmarks/",
            "Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReport.swift",
                "Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift",

            "Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReport.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Benchmarks/", runtimeRole: .benchmarkContract,
            owner: "Benchmark owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/PerformanceAuditTests.swift",
                "Tests/OpenLolaCoreTests/LatencyBenchmarkReportTests.swift",

            "Tests/OpenLolaCoreTests/E2EBenchmarkReportTests.swift"
        ], relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/LatencyBenchmarkReports/valid/latency-benchmark-partial.json"],
            relatedDocs: ["docs/benchmark-methodology.md", "docs/latency-budget.md"], refactorRisk: .medium,
            moveState: .notSelected, status: .active, confidence: .confirmed, validationCommands: ["swift test --filter PerformanceAuditTests"],
            improvementRecommendation: "Keep benchmark reports separate from release proof policy files.")),
        own(.init(
            group: .releaseProofPackaging,
            purpose: "Recording, packaging field tests, field proof, release hardening, and parity closure.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Integration/",
            "Sources/OpenLolaCore/Release/",
            "Sources/OpenLolaCore/Release/ReleaseHardening.swift",
                "Sources/OpenLolaCore/Release/PackagingFieldTest.swift",

            "Sources/OpenLolaCore/Release/FieldReadyRuntimeProof.swift",
                "Sources/OpenLolaCore/Release/RecordingSessionArtifacts.swift",

            "Sources/OpenLolaCore/Release/FasterThanLoLaClosure.swift",
            "Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift",
            "Sources/OpenLolaCore/Release/Goal/GoalCompletionAudit.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Release/", runtimeRole: .releaseGate,
            owner: "Release readiness owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/ReleaseHardeningTests.swift",
                "Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift",

            "Tests/OpenLolaCoreTests/FieldReadyRuntimeProofTests.swift",
                "Tests/OpenLolaCoreTests/RecordingSessionArtifactTests.swift",

            "Tests/OpenLolaCoreTests/OpenSourceReleaseReadinessTests.swift",
            "Tests/OpenLolaCoreTests/GoalCompletionAuditTests.swift"
        ], relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/ReleaseHardeningReports/valid/release-hardening-partial.json"],
            relatedDocs: ["docs/current-state.md", "docs/release-boundary.md"], refactorRisk: .high,
            moveState: .notSelected, status: .active, confidence: .confirmed, validationCommands: ["swift test --filter ReleaseHardeningTests"],
            improvementRecommendation: "Keep release manifest, signing, and clean-Mac proof references aligned.")),

        own(.init(
            group: .platformAppShell,
            purpose: "Native macOS app-shell runtime boundary and launchability report.",
            currentSourcePaths: [
            "Sources/open-lola-app/",
            "Sources/open-lola-app-main/",
            "Sources/OpenLolaCore/Platform/NativeAppShell.swift",
            "Sources/OpenLolaCore/Platform/",
            "Sources/OpenLolaCore/Platform/NativeAppShellMediaDevices.swift",
            "Sources/OpenLolaCore/Platform/NativeAppShellMediaInventory.swift",
            "Sources/OpenLolaCore/Platform/NativeAppShellDirectPeerCommand.swift",
            "Sources/OpenLolaCore/Platform/NativeAppShellOperatorState.swift",
            "Sources/OpenLolaCore/Platform/NativeAppShellSurfaceContract.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Platform/", runtimeRole: .appShellBoundary,
            owner: "macOS app-shell owner", relatedTestFiles: ["Tests/OpenLolaCoreTests/NativeAppShellTests.swift"],
            relatedFixturePaths: ["Tests/OpenLolaCoreTests/Fixtures/NativeAppShellReports/valid/native-app-shell-partial.json"],
            relatedDocs: ["docs/current-state.md"], refactorRisk: .medium, moveState: .notSelected, status: .active,
            confidence: .likely, validationCommands: ["swift test --filter NativeAppShellTests"],
            improvementRecommendation: "Keep app-shell runtime contracts separate from SwiftUI presentation code.")),
        own(.init(
            group: .cliApplication,
            purpose: "Executable command routing, argument parsing, command families, and user-facing CLI surface.",
            currentSourcePaths: [
            "Sources/open-lola/",
            "Sources/open-lola/main.swift", "Sources/open-lola/Commands/MilestoneCommands.swift",
            "Sources/open-lola/Commands/CLICommandHelpers.swift",
            "Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift",
            "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            "Sources/open-lola/Commands/Audio/MadiReceiveCommands.swift",
            "Sources/open-lola/Commands/Audio/MadiFullDuplexCommands.swift",
            "Sources/open-lola/Commands/Audio/LatencyProfileCommands.swift",
            "Sources/open-lola/Commands/Benchmarks/PerformanceCommands.swift",
            "Sources/open-lola/Commands/Benchmarks/E2EBenchmarkCommands.swift"
        ], proposedSourcePath: "Sources/open-lola/Commands/", runtimeRole: .commandSurface,
            owner: "CLI owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift",
                "Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift"
        ], relatedFixturePaths: [], relatedDocs: ["docs/current-state.md", "docs/testing.md"],
            refactorRisk: .medium, moveState: .notSelected, status: .active, confidence: .confirmed,
            validationCommands: ["swift test --filter CLICommandInventoryTests"],
            improvementRecommendation: "Keep future command additions inside the domain-specific Commands folders.")),
        own(.init(
            group: .releaseReadinessInventories,
            purpose: "Executable inventories for commands, schemas, realtime paths, routes, AV/control, fixtures, and source " +
                "ownership.",
            currentSourcePaths: [
            "Sources/OpenLolaCore/Support/",
            "Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift",
            "Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrix.swift",
            "Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift",
            "Sources/OpenLolaCore/Support/Inventories/RealtimeAudioPathInventory.swift",
            "Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift",
            "Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift",
            "Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift"
        ], proposedSourcePath: "Sources/OpenLolaCore/Support/Inventories/", runtimeRole: .reviewInventory,
            owner: "Release-readiness inventory owner", relatedTestFiles: [
            "Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift",
                "Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift",

            "Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift",
            "Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift",
            "Tests/OpenLolaCoreTests/VideoControlDegradeMatrixTests.swift",
            "Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift"
        ], relatedFixturePaths: [], relatedDocs: ["docs/current-state.md", "docs/testing.md"],
            refactorRisk: .low, moveState: .notSelected, status: .active, confidence: .confirmed,
            validationCommands: ["swift test --filter SourceOwnershipInventoryTests"],
            improvementRecommendation: "Keep inventory docs free of flat source assumptions."))
    ]
}
