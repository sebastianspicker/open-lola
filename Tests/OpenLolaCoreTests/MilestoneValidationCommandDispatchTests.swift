// Exercises fixture-backed validation and non-executing network dispatch through the CLI.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func milestoneValidationCommandAcceptsFixtureAndRejectsMissingInput() throws {
    let fixture = commandDispatchFixture(
        group: "LatencyBenchmarkReports",
        state: "valid",
        file: "latency-benchmark-partial.json"
    )

    let valid = try runCommandDispatchCLI([
        "validate-latency-benchmark-report", fixture.path
    ])
    let missing = try runCommandDispatchCLI([
        "validate-latency-benchmark-report",
        fixture.deletingLastPathComponent().appendingPathComponent("missing.json").path
    ])

    #expect(valid.exitCode == 0)
    #expect(valid.output.contains("latency benchmark report valid:"))
    #expect(valid.output.contains("VERDICT: PARTIAL"))
    #expect(missing.exitCode == 1)
    #expect(missing.output.contains("error:"))
}

@Test
func networkValidationCommandAcceptsFixtureAndRejectsIncompleteArguments() throws {
    let fixture = commandDispatchFixture(
        group: "EndpointLoopback",
        state: "valid",
        file: "endpoint-loopback-valid.json"
    )

    let valid = try runCommandDispatchCLI(["validate-loopback-report", fixture.path])
    let incomplete = try runCommandDispatchCLI([
        "direct-p2p-two-peer-local-run", "--plan", fixture.path
    ])

    #expect(valid.exitCode == 0)
    #expect(valid.output.contains("endpoint-loopback report valid:"))
    #expect(valid.output.contains("VERDICT: PASS"))
    #expect(incomplete.exitCode == 1)
    #expect(incomplete.output.contains("invalid argument: missing --output"))
}

@Test
func nonExecutingTwoPeerCommandWritesAndValidatesSupervisorReport() throws {
    let directory = try makeCommandDispatchDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let plan = try directPeerTwoPeerPlan(in: directory)
    let planURL = directory.appendingPathComponent("plan.json")
    let outputURL = directory.appendingPathComponent("nested/supervisor-report.json")
    try plan.prettyJSONData().write(to: planURL)

    let result = try runCommandDispatchCLI([
        "direct-p2p-two-peer-local-run",
        "--plan", planURL.path,
        "--output", outputURL.path,
        "--execute", "false"
    ])
    let report = try DirectPeerTwoPeerLocalRunReport.readValidated(fromPath: outputURL.path)

    #expect(result.exitCode == 0)
    #expect(result.output.contains("direct P2P two-peer supervisor report written:"))
    #expect(result.output.contains("executed: false"))
    #expect(result.output.contains("processes: 2"))
    #expect(report.executed == false)
    #expect(report.processResults.count == 2)
    #expect(report.processResults.allSatisfy { $0.exitCode == nil })
    #expect(report.executionMode == .local)
    #expect(report.aggregateExecuted == false)

    let validated = try runCommandDispatchCLI([
        "validate-direct-p2p-two-peer-local-run-report", outputURL.path
    ])
    #expect(validated.exitCode == 0)
    #expect(validated.output.contains("direct P2P two-peer local supervisor report valid:"))
}

@Test
func milestoneValidationRoutesRejectMissingFixtures() throws {
    let missingPath = commandDispatchRepositoryRoot
        .appendingPathComponent("Tests/OpenLolaCoreTests/Fixtures/missing-command-dispatch.json")

    for command in milestoneValidationCommands {
        let result = try runCommandDispatchCLI([command, missingPath.path])

        #expect(result.exitCode == 1, "\(command) should reject the missing report")
        #expect(result.output.contains("error:"), "\(command) should report a CLI error")
    }
}

@Test
func fixtureBackedMilestoneAndNetworkValidatorsAcceptReports() throws {
    for fixture in commandDispatchValidFixtures {
        let result = try runCommandDispatchCLI([
            fixture.command,
            commandDispatchFixture(
                group: fixture.group,
                state: "valid",
                file: fixture.file
            ).path
        ])

        #expect(result.exitCode == 0)
        #expect(result.output.contains("valid:"))
        #expect(result.output.contains("VERDICT:"))
    }
}

@Test
func fixtureBackedValidatorsRejectKnownInvalidReports() throws {
    for fixture in commandDispatchInvalidFixtures {
        let result = try runCommandDispatchCLI([
            fixture.command,
            commandDispatchFixture(
                group: fixture.group,
                state: "invalid",
                file: fixture.file
            ).path
        ])

        #expect(result.exitCode == 1)
        #expect(result.output.contains("error:"))
    }
}

@Test
func safeNetworkPacketAndHelpRoutesDispatchWithoutExternalProcesses() throws {
    let packet = commandDispatchFixture(
        group: "UdpPcmPackets",
        state: "valid",
        file: "valid-stereo-int16.hex"
    )
    let invalidPacket = commandDispatchFixture(
        group: "UdpPcmPackets",
        state: "invalid",
        file: "wrong-guard.hex"
    )

    let valid = try runCommandDispatchCLI(["validate-udp-pcm-packet", packet.path])
    let invalid = try runCommandDispatchCLI(["validate-udp-pcm-packet", invalidPacket.path])
    let routeHelp = try runCommandDispatchCLI(["udp-pcm-route-run", "--help"])
    let bundleHelp = try runCommandDispatchCLI([
        "verify-direct-p2p-session-evidence-bundle", "--help"
    ])

    #expect(valid.exitCode == 0)
    #expect(valid.output.contains("udp-pcm packet valid:"))
    #expect(invalid.exitCode == 1)
    #expect(invalid.output.contains("error:"))
    #expect(routeHelp.exitCode == 0)
    #expect(routeHelp.output.contains("Usage: open-lola udp-pcm-route-run"))
    #expect(bundleHelp.exitCode == 0)
    #expect(bundleHelp.output.contains("Usage: open-lola verify-direct-p2p-session-evidence-bundle"))
}

@Test
func twoPeerLocalRunRejectsUnsafeOrMalformedOptionsBeforeExecution() throws {
    let directory = try makeCommandDispatchDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let plan = try directPeerTwoPeerPlan(in: directory)
    let planURL = directory.appendingPathComponent("plan.json")
    try plan.prettyJSONData().write(to: planURL)
    let base = [
        "direct-p2p-two-peer-local-run",
        "--plan", planURL.path,
        "--output", directory.appendingPathComponent("report.json").path
    ]
    let cases: [([String], String)] = [
        (base + ["--execute", "later"], "invalid --execute"),
        (base + ["--execution-mode", "invalid"], "invalid --execution-mode"),
        (base + ["--readiness-delay-ms", "0"], "invalid --readiness-delay-ms"),
        (base + ["--execute", "true"], "missing --connection-preflight-report"),
        (base + ["--execution-mode", "ssh"], "ssh execution requires --ssh-fallback-explicit true")
    ]

    for (arguments, message) in cases {
        let result = try runCommandDispatchCLI(arguments)
        #expect(result.exitCode == 1)
        #expect(result.output.contains(message))
    }
}

@Test
func networkRunnerRoutesRejectMissingArgumentsBeforeAnyRuntimeWork() throws {
    let cases: [([String], String)] = [
        (["audio-loopback-run"], "--sample-rate"),
        (["udp-pcm-route-run"], "--role"),
        (["udp-pcm-loopback-run"], "--role"),
        (["network-diagnostics-run"], "--peer"),
        (["mac-to-mac-connection-preflight-run"], "--local-peer-id")
    ]

    for (arguments, requiredOption) in cases {
        let result = try runCommandDispatchCLI(arguments)

        #expect(result.exitCode == 1, "\(arguments[0]) should reject incomplete arguments")
        #expect(result.output.contains(requiredOption), "\(arguments[0]) should name its requirement")
    }
}

@Test
func networkHelpAndUnknownRoutesStayInTheCommandDispatcher() throws {
    let cases: [([String], String)] = [
        (["udp-pcm-route-run", "-h"], "Usage: open-lola udp-pcm-route-run"),
        (["verify-direct-p2p-session-evidence-bundle", "-h"],
         "Usage: open-lola verify-direct-p2p-session-evidence-bundle"),
        (["not-a-network-command"], "Usage: open-lola")
    ]

    for (arguments, expectedOutput) in cases {
        let result = try runCommandDispatchCLI(arguments)

        #expect(result.output.contains(expectedOutput))
        #expect(result.exitCode == (arguments.count == 1 ? 1 : 0))
    }
}

@Test
func nonExecutingTwoPeerRouteSupportsLocalAndSSHReportModes() throws {
    let directory = try makeCommandDispatchDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let plan = try directPeerTwoPeerPlan(in: directory)
    let planURL = directory.appendingPathComponent("plan.json")
    try plan.prettyJSONData().write(to: planURL)
    let base = [
        "direct-p2p-two-peer-local-run",
        "--plan", planURL.path,
        "--execute", "false",
        "--readiness-delay-ms", "1"
    ]
    let cases: [([String], String, DirectPeerTwoPeerRunExecutionMode)] = [
        (
            base + [
                "--output", directory.appendingPathComponent("local-report.json").path,
                "--execution-mode", "local",
                "--executable", commandDispatchRepositoryRoot.appendingPathComponent(".build/debug/open-lola").path
            ],
            "local-report.json",
            .local
        ),
        (
            base + [
                "--output", directory.appendingPathComponent("ssh-report.json").path,
                "--execution-mode", "ssh",
                "--ssh-fallback-explicit", "true",
                "--ssh-fallback-reason", "non-executing coverage",
                "--mac-a-ssh", "localhost",
                "--mac-b-ssh", "localhost",
                "--mac-a-executable", "/usr/bin/false",
                "--mac-b-executable", "/usr/bin/false",
                "--mac-a-workdir", directory.path,
                "--mac-b-workdir", directory.path
            ],
            "ssh-report.json",
            .ssh
        )
    ]

    for (arguments, reportName, executionMode) in cases {
        let result = try runCommandDispatchCLI(arguments)
        let report = try DirectPeerTwoPeerLocalRunReport.readValidated(
            fromPath: directory.appendingPathComponent(reportName).path
        )

        #expect(result.exitCode == 0)
        #expect(result.output.contains("executed: false"))
        #expect(result.output.contains("executionMode: \(executionMode.rawValue)"))
        #expect(report.executed == false)
        #expect(report.executionMode == executionMode)
        #expect(report.processResults.allSatisfy { $0.exitCode == nil })
    }
}

@Test
func twoPeerSSHValidationNamesEachMissingSafetyFieldWithoutExecuting() throws {
    let directory = try makeCommandDispatchDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let plan = try directPeerTwoPeerPlan(in: directory)
    let planURL = directory.appendingPathComponent("plan.json")
    try plan.prettyJSONData().write(to: planURL)
    let base = [
        "direct-p2p-two-peer-local-run",
        "--plan", planURL.path,
        "--output", directory.appendingPathComponent("report.json").path,
        "--execute", "false",
        "--execution-mode", "ssh",
        "--ssh-fallback-explicit", "true"
    ]
    let cases: [([String], String)] = [
        (base, "ssh execution requires --ssh-fallback-reason"),
        (base + ["--ssh-fallback-reason", "coverage"], "ssh execution requires --mac-a-ssh"),
        (
            base + [
                "--ssh-fallback-reason", "coverage",
                "--mac-a-ssh", "localhost"
            ],
            "ssh execution requires --mac-b-ssh"
        )
    ]

    for (arguments, message) in cases {
        let result = try runCommandDispatchCLI(arguments)

        #expect(result.exitCode == 1)
        #expect(result.output.contains(message))
    }
}

private struct CommandDispatchFixture {
    let command: String
    let group: String
    let file: String

    init(_ command: String, _ group: String, _ file: String) {
        self.command = command
        self.group = group
        self.file = file
    }
}

private let milestoneValidationCommands = [
    "validate-latency-benchmark-report",
    "validate-rx-buffer-benchmark-report",
    "validate-latency-tuning-report",
    "validate-drift-plc-report",
    "validate-drift-plc-certification-report",
    "validate-aoip-report",
    "validate-network-aoip-certification-report",
    "validate-video-capture-report",
    "validate-video-capture-inventory",
    "validate-video-transport-report",
    "validate-integrated-av-report",
    "validate-hardware-validation-report",
    "validate-osc-cue-report",
    "validate-atem-control-report",
    "validate-lighting-gate-report",
    "validate-native-app-shell-report",
    "validate-native-app-shell-surface-probe-report",
    "validate-recording-session-report",
    "validate-packaging-field-report",
    "validate-field-runtime-proof",
    "validate-lola-parity-deferred-ledger",
    "validate-faster-than-lola-closure",
    "validate-release-hardening-report",
    "validate-open-source-release-readiness-report",
    "validate-integrated-profile-report",
    "validate-external-connector-report",
    "validate-external-connector-session-report",
    "validate-external-connector-connection-plan",
    "validate-external-connector-nmp-plan",
    "validate-external-connector-nmp-preflight",
    "validate-external-connector-nmp-endpoint-run",
    "validate-external-connector-nmp-workflow",
    "validate-lola-capture-report",
    "validate-lola-packet-fixture-report",
    "validate-external-connector-executable-preflight-report",
    "validate-lola-media-session-report",
    "validate-goal-codewise-closure-report",
    "validate-goal-runtime-evidence-template-report",
    "validate-goal-runtime-preflight-report",
    "validate-goal-completion-audit-report",
    "validate-current-evidence-status-matrix-report"
]

private let commandDispatchValidFixtures = [
    CommandDispatchFixture("validate-latency-tuning-report", "LatencyTuningReports", "latency-tuning-partial.json"),
    CommandDispatchFixture("validate-drift-plc-report", "DriftPlcReports", "drift-plc-partial.json"),
    CommandDispatchFixture("validate-drift-plc-certification-report", "DriftPlcFixedTargetCertificationReports", "g05-drift-plc-certification-partial.json"),
    CommandDispatchFixture("validate-aoip-report", "AoipEvaluationReports", "aoip-avb-partial.json"),
    CommandDispatchFixture("validate-network-aoip-certification-report", "NetworkAoipCertificationReports", "g06-network-aoip-certification-partial.json"),
    CommandDispatchFixture("validate-video-capture-report", "VideoCaptureReports", "video-capture-partial.json"),
    CommandDispatchFixture("validate-video-transport-report", "VideoTransportReports", "video-transport-partial.json"),
    CommandDispatchFixture("validate-integrated-av-report", "IntegratedAvReports", "integrated-av-partial.json"),
    CommandDispatchFixture("validate-hardware-validation-report", "HardwareValidationReports", "hardware-validation-partial.json"),
    CommandDispatchFixture("validate-osc-cue-report", "OscCueReports", "osc-cue-partial.json"),
    CommandDispatchFixture("validate-lighting-gate-report", "LightingFixtureGateReports", "lighting-gate-partial.json"),
    CommandDispatchFixture("validate-native-app-shell-report", "NativeAppShellReports", "native-app-shell-partial.json"),
    CommandDispatchFixture("validate-recording-session-report", "RecordingSessionArtifacts", "recording-session-partial.json"),
    CommandDispatchFixture("validate-packaging-field-report", "PackagingFieldTests", "packaging-field-test-partial.json"),
    CommandDispatchFixture("validate-field-runtime-proof", "FieldReadyRuntimeProofs", "field-runtime-proof-partial.json"),
    CommandDispatchFixture("validate-lola-parity-deferred-ledger", "LoLaParityDeferredLedgers", "lola-parity-deferred-ledger-partial.json"),
    CommandDispatchFixture("validate-release-hardening-report", "ReleaseHardeningReports", "release-hardening-partial.json"),
    CommandDispatchFixture("validate-open-source-release-readiness-report", "OpenSourceReleaseReadinessReports", "open-source-release-readiness-pass.json"),
    CommandDispatchFixture("validate-integrated-profile-report", "IntegratedProfileReports", "integrated-profile-partial.json"),
    CommandDispatchFixture("validate-external-connector-report", "ExternalConnectorReports", "external-connectors-source-pass.json"),
    CommandDispatchFixture("validate-external-connector-session-report", "ExternalConnectorSessionReports", "external-connector-session-partial.json"),
    CommandDispatchFixture("validate-reference-rig-report", "ReferenceRigReports", "reference-rig-partial.json"),
    CommandDispatchFixture("validate-rme-fastest-audio-report", "RmeFastestAudioPathReports", "rme-fastest-audio-partial.json"),
    CommandDispatchFixture("validate-realtime-audio-engine-report", "RealtimeAudioEngineReports", "realtime-audio-engine-partial.json"),
    CommandDispatchFixture("validate-route-report", "UdpPcmRoutes", "direct-link-pass.json"),
    CommandDispatchFixture("validate-route-certification-report", "MacToMacRouteCertificationReports", "g04-route-certification-partial.json")
]

private let commandDispatchInvalidFixtures = [
    CommandDispatchFixture("validate-latency-benchmark-report", "LatencyBenchmarkReports", "latency-missing-verdict.json"),
    CommandDispatchFixture("validate-loopback-report", "EndpointLoopback", "missing-32-frame.json"),
    CommandDispatchFixture("validate-external-connector-session-report", "ExternalConnectorSessionReports", "external-connector-session-missing-media-pass.json"),
    CommandDispatchFixture("validate-integrated-av-report", "IntegratedAvReports", "integrated-av-synthetic-pass.json"),
    CommandDispatchFixture("validate-packaging-field-report", "PackagingFieldTests", "packaging-field-test-missing-signing.json"),
    CommandDispatchFixture("validate-field-runtime-proof", "FieldReadyRuntimeProofs", "field-runtime-proof-synthetic-pass.json"),
    CommandDispatchFixture("validate-realtime-audio-engine-report", "RealtimeAudioEngineReports", "realtime-audio-engine-synthetic-pass.json"),
    CommandDispatchFixture("validate-release-hardening-report", "ReleaseHardeningReports", "release-hardening-synthetic-pass.json"),
    CommandDispatchFixture("validate-open-source-release-readiness-report", "OpenSourceReleaseReadinessReports", "open-source-release-readiness-missing-requirement-pass.json")
]

private func runCommandDispatchCLI(_ arguments: [String]) throws -> (exitCode: Int32, output: String) {
    try runFreshOpenLolaCLI(
        arguments: arguments,
        context: "milestone validation command dispatch tests",
        logPrefix: "open-lola-command-dispatch"
    )
}

private func commandDispatchFixture(group: String, state: String, file: String) -> URL {
    commandDispatchRepositoryRoot
        .appendingPathComponent("Tests/OpenLolaCoreTests/Fixtures")
        .appendingPathComponent(group)
        .appendingPathComponent(state)
        .appendingPathComponent(file)
}

private func makeCommandDispatchDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-command-dispatch-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private var commandDispatchRepositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
