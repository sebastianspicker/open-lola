import Foundation
import Testing


@Test
func releaseReadinessScriptDefinesLocalVerificationMatrix() throws {
    let matrix = try runShell(
        """
        source scripts/verify-release-readiness.sh
        run_step() { printf 'RUN_STEP:%s\\n' "$*"; }
        run_timed_step() {
          local timeout_seconds="$1"
          shift
          printf 'RUN_TIMED_STEP:%s:%s\\n' "$timeout_seconds" "$*"
        }
        manual_hardware_signing_gate() { printf 'MANUAL_GATE\\n'; }
        run_cli_probe() { printf 'CLI:%s:%s\\n' "$1" "$2"; }
        run_goal_report_probe() { printf 'GOAL:%s:%s\\n' "$1" "$4"; }
        run_open_source_release_readiness_probe() { printf 'OPEN_SOURCE_RELEASE_READINESS\\n'; }
        run_native_app_launch_probe() { printf 'NATIVE_APP_LAUNCH\\n'; }
        main
        """
    )

    #expect(matrix.status == 0)
    let requiredExternalGates = [
        "RUN_STEP:env PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh",
        "RUN_STEP:shellcheck -x scripts/build-local-ultragrid-docker.sh",
        "scripts/verify-release-readiness.sh scripts/lib/common.sh scripts/lib/parity.sh",
        "script/build_and_run.sh script/build_cli_app_bundle.sh",
        "linux_connector/env/probe_windows_lola.sh linux_connector/env/wsl_setup.sh",
        "ruff check linux_connector scripts/verify_docs scripts/lib/extract-preflight-executable.py",
        "python -m pytest -p no:cacheprovider linux_connector",
        "python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/extract-preflight-executable.py",
        "RUN_STEP:bash scripts/verify-release-hygiene.sh",
        "RUN_TIMED_STEP:600:swift build",
        "RUN_TIMED_STEP:1800:swift test --no-parallel",
        "MANUAL_GATE",
        "NATIVE_APP_LAUNCH",
        "OPEN_SOURCE_RELEASE_READINESS",
    ]
    for gate in requiredExternalGates {
        #expect(matrix.output.contains(gate))
    }

    for command in [
        "CLI:command-inventory:PARTIAL",
        "CLI:source-ownership-inventory:PARTIAL",
        "CLI:fixture-smoke-matrix:PARTIAL",
        "CLI:report-schema-inventory:PARTIAL",
        "CLI:realtime-audio-path-inventory:PARTIAL",
        "CLI:network-route-command-matrix:PARTIAL",
        "CLI:video-control-degrade-matrix:PARTIAL",
        "CLI:native-app-shell-surface-probe:PARTIAL",
        "GOAL:goal-codewise-closure:PASS",
        "GOAL:goal-runtime-evidence-template:PARTIAL",
        "GOAL:goal-runtime-preflight:PARTIAL",
        "GOAL:goal-completion-audit:PARTIAL",
    ] {
        #expect(matrix.output.contains(command))
    }

    #expect(matrix.output.contains("source-gate-verdict: pass"))
    #expect(matrix.output.contains("product-runtime-verdict: partial"))
    #expect(matrix.output.contains("VERDICT: PARTIAL"))
    #expect(!matrix.output.contains("VERDICT: PASS"))
}

@Test
func releaseReadinessScriptKeepsReleaseBoundaryExplicit() throws {
    let gate = try runShell(
        "source scripts/verify-release-readiness.sh; manual_hardware_signing_gate"
    )

    #expect(gate.status == 0)
    #expect(gate.output.contains("== manual release evidence gates =="))
    #expect(gate.output.contains("Developer ID, notarization, Gatekeeper, clean-Mac, hardware, benchmark"))
    for forbiddenPath in [".build/", "win-compiled/", "private/", "reverse-engineering/", "archive/"] {
        #expect(gate.output.contains(forbiddenPath))
    }
    #expect(!gate.output.contains("== bash scripts/verify-docs.sh =="))
}

@Test
func pmrExternalProofBundleScriptRequiresLiveAndHardwareArtifacts() throws {
    let script = try readText("scripts/verify-pmr-external-proof-bundle.sh")

    let requiredReportValidations = [
        """
        validate_report "PMR-04" "pmr-04/realtime-audio-engine.json" "validate-realtime-audio-engine-report" "PASS"
        """,
        """
        validate_report "PMR-14" "pmr-14/rx-buffer-benchmark.json" "validate-rx-buffer-benchmark-report" "PASS"
        """,
        """
        validate_report "PMR-14" "pmr-14/drift-plc-certification.json" "validate-drift-plc-certification-report" "PASS"
        """,
        """
        validate_report "PMR-14" "pmr-14/direct-p2p-session.json" "validate-direct-p2p-session-report" "PASS"
        """,
        """
        validate_report "PMR-16" "pmr-16/madi-full-duplex.json" "validate-madi-full-duplex-report" "PASS"
        """,
        """
        validate_report "PMR-23" "pmr-23/recording-session.json" "validate-recording-session-report" "PASS"
        """,
    ]
    for validation in requiredReportValidations {
        #expect(script.contains(validation))
    }

    #expect(script.contains("validate_pmr04_runtime_contract"))
    #expect(script.contains("pmr-04/realtime-audio-engine.json runtime.callbackOwner must be audioDeviceIOProc"))
    #expect(script.contains("pmr-04/realtime-audio-engine.json runtime.handoff.shutdownCompleted must be true"))
    #expect(script.contains("require_file_contains \"$sanitizer_result\" \"ASAN: PASS\""))
    #expect(script.contains("require_file_contains \"$sanitizer_result\" \"TSAN: PASS\""))
    #expect(script.contains("verify-direct-p2p-session-evidence-bundle"))
    #expect(script.contains("expect_last_verdict \"pmr-14 direct P2P evidence bundle\" \"$output_file\" \"PASS\""))
    #expect(script.contains("validate_pmr14_runtime_contract"))
    #expect(script.contains("pmr-14/rx-buffer-benchmark.json evidenceKind must be physicalReferenceRig"))
    #expect(script.contains("pmr-14/rx-buffer-benchmark.json direct row fastestPassEligible must be true"))
    #expect(script.contains("pmr-14/drift-plc-certification.json lolaBaselineComparison.result must be openLolaFaster or openLolaEquivalent"))
    #expect(script.contains("pmr-14/direct-p2p-session.json measuredEvidence.packetCapture"))
    #expect(script.contains("pmr-14/direct-p2p-session.json avRuntime.runtimeMetrics.audioPayloadsSent"))
    #expect(script.contains("pmr-14/direct-p2p-session.json avRuntime.runtimeMetrics.audioPayloadsQueuedForPlayout"))
    #expect(script.contains("\"audioPlayoutUnderruns\","))

    let requiredPmr23Predicates = [
        "^role: tx-rx$",
        "^real-link-transmitted: true$",
        "^frames: [1-9][0-9]*$",
        "^state: completed$",
        "^can-start-ioproc: true$",
        "^blockers: 0$",
    ]
    for predicate in requiredPmr23Predicates {
        #expect(script.contains(predicate))
    }

    #expect(script.contains("require_file_contains \"$notes_path\" \"input UID:\""))
    #expect(script.contains("require_file_contains \"$notes_path\" \"output UID:\""))
    #expect(script.contains("require_file_contains \"$notes_path\" \"RME MADI\""))
    #expect(script.contains("require_file_contains \"$notes_path\" \"peer readiness: exchanged\""))
    #expect(script.contains("require_file_contains \"$notes_path\" \"teardown: completed\""))
    #expect(script.contains("require_file_contains \"$notes_path\" \"packet capture:\""))
    #expect(script.contains("pmr-16/hardware-notes.md input UID and output UID must be distinct"))
    #expect(script.contains("validate_pmr16_runtime_contract"))
    #expect(script.contains("\"completedReceiveBlocks\","))
    #expect(script.contains("\"renderedReceiveBlocks\","))
    #expect(script.contains("f\"pmr-16/madi-full-duplex.json metrics.{field}\""))
    #expect(script.contains("validate_pmr23_runtime_contract"))
    #expect(script.contains("pmr-23/lola-media-session.json peer must be a live non-loopback peer"))
    #expect(script.contains("pmr-23/audio-loopback-run.json callback.recordedIntervalSamples"))
    #expect(script.contains("pmr-23/audio-loopback-run.json handoff.shutdownCompleted"))
    #expect(script.contains("echo \"VERDICT: PASS\""))
}

@Test
func pmrExternalProofBundleScriptRejectsWeakExternalArtifacts() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-pmr-proof-bundle-\(UUID().uuidString)")
    let bundle = temporaryRoot.appendingPathComponent("bundle")
    let fakeCLI = temporaryRoot.appendingPathComponent("open-lola")
    try FileManager.default.createDirectory(
        at: temporaryRoot,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }
    try createPmrProofBundleFixture(at: bundle)
    try writeFakePmrProofBundleCLI(to: fakeCLI)

    let passingBundle = try runShell(
        "OPEN_LOLA_CLI=\"$1\" bash scripts/verify-pmr-external-proof-bundle.sh \"$2\"",
        fakeCLI.path,
        bundle.path
    )
    #expect(passingBundle.status == 0)
    #expect(passingBundle.output.contains("PMR external proof bundle verified"))
    #expect(passingBundle.output.contains("VERDICT: PASS"))

    let weakLoLaBundle = try runShell(
        "OPEN_LOLA_CLI=\"$1\" OPEN_LOLA_FAKE_PMR_MODE=weak-lola bash scripts/verify-pmr-external-proof-bundle.sh \"$2\"",
        fakeCLI.path,
        bundle.path
    )
    #expect(weakLoLaBundle.status != 0)
    #expect(weakLoLaBundle.output.contains(
        "PMR-23 LoLa media session must match: ^real-link-transmitted: true$"
    ))
    #expect(!weakLoLaBundle.output.contains("PMR external proof bundle verified"))

    let weakCoreAudioBundle = try runShell(
        "OPEN_LOLA_CLI=\"$1\" OPEN_LOLA_FAKE_PMR_MODE=weak-coreaudio bash scripts/verify-pmr-external-proof-bundle.sh \"$2\"",
        fakeCLI.path,
        bundle.path
    )
    #expect(weakCoreAudioBundle.status != 0)
    #expect(weakCoreAudioBundle.output.contains(
        "PMR-23 audio loopback run must match: ^state: completed$"
    ))
    #expect(!weakCoreAudioBundle.output.contains("PMR external proof bundle verified"))

    let lolaReport = bundle.appendingPathComponent("pmr-23/lola-media-session.json")
    try weakPmr23LoLaMediaSessionJson.write(to: lolaReport, atomically: true, encoding: .utf8)
    let weakLoLaPeerBundle = try runShell(
        "OPEN_LOLA_CLI=\"$1\" bash scripts/verify-pmr-external-proof-bundle.sh \"$2\"",
        fakeCLI.path,
        bundle.path
    )
    #expect(weakLoLaPeerBundle.status != 0)
    #expect(weakLoLaPeerBundle.output.contains(
        "pmr-23/lola-media-session.json peer must be a live non-loopback peer"
    ))
    #expect(!weakLoLaPeerBundle.output.contains("PMR external proof bundle verified"))

    try validPmr23LoLaMediaSessionJson.write(to: lolaReport, atomically: true, encoding: .utf8)
    let audioLoopbackReport = bundle.appendingPathComponent("pmr-23/audio-loopback-run.json")
    try weakPmr23AudioLoopbackRunJson.write(to: audioLoopbackReport, atomically: true, encoding: .utf8)
    let weakCoreAudioRuntimeBundle = try runShell(
        "OPEN_LOLA_CLI=\"$1\" bash scripts/verify-pmr-external-proof-bundle.sh \"$2\"",
        fakeCLI.path,
        bundle.path
    )
    #expect(weakCoreAudioRuntimeBundle.status != 0)
    #expect(weakCoreAudioRuntimeBundle.output.contains(
        "pmr-23/audio-loopback-run.json callback.recordedIntervalSamples must be > 0"
    ))
    #expect(!weakCoreAudioRuntimeBundle.output.contains("PMR external proof bundle verified"))

    try validPmr23AudioLoopbackRunJson.write(to: audioLoopbackReport, atomically: true, encoding: .utf8)
    let hardwareNotes = bundle.appendingPathComponent("pmr-16/hardware-notes.md")
    try """
    input UID: shared-rme-madi-test-uid
    output UID: shared-rme-madi-test-uid
    RME MADI
    peer readiness: exchanged
    teardown: completed
    packet capture: private/captures/pmr-16-test.pcapng

    """.write(to: hardwareNotes, atomically: true, encoding: .utf8)
    let weakMadiBundle = try runShell(
        "OPEN_LOLA_CLI=\"$1\" bash scripts/verify-pmr-external-proof-bundle.sh \"$2\"",
        fakeCLI.path,
        bundle.path
    )
    #expect(weakMadiBundle.status != 0)
    #expect(weakMadiBundle.output.contains(
        "pmr-16/hardware-notes.md input UID and output UID must be distinct"
    ))
    #expect(!weakMadiBundle.output.contains("PMR external proof bundle verified"))

    try validPmr16HardwareNotes.write(to: hardwareNotes, atomically: true, encoding: .utf8)
    let madiReport = bundle.appendingPathComponent("pmr-16/madi-full-duplex.json")
    try weakPmr16MadiFullDuplexJson.write(to: madiReport, atomically: true, encoding: .utf8)
    let weakMadiTrafficBundle = try runShell(
        "OPEN_LOLA_CLI=\"$1\" bash scripts/verify-pmr-external-proof-bundle.sh \"$2\"",
        fakeCLI.path,
        bundle.path
    )
    #expect(weakMadiTrafficBundle.status != 0)
    #expect(weakMadiTrafficBundle.output.contains(
        "pmr-16/madi-full-duplex.json metrics.completedReceiveBlocks must be > 0"
    ))
    #expect(!weakMadiTrafficBundle.output.contains("PMR external proof bundle verified"))

    try validPmr16MadiFullDuplexJson.write(to: madiReport, atomically: true, encoding: .utf8)
    let directP2PReport = bundle.appendingPathComponent("pmr-14/direct-p2p-session.json")
    try weakPmr14DirectP2PSessionJson.write(to: directP2PReport, atomically: true, encoding: .utf8)
    let weakPmr14Bundle = try runShell(
        "OPEN_LOLA_CLI=\"$1\" bash scripts/verify-pmr-external-proof-bundle.sh \"$2\"",
        fakeCLI.path,
        bundle.path
    )
    #expect(weakPmr14Bundle.status != 0)
    #expect(weakPmr14Bundle.output.contains(
        "pmr-14/direct-p2p-session.json avRuntime.runtimeMetrics.audioPayloadsQueuedForPlayout must be > 0"
    ))
    #expect(!weakPmr14Bundle.output.contains("PMR external proof bundle verified"))

    try validPmr14DirectP2PSessionJson.write(to: directP2PReport, atomically: true, encoding: .utf8)
    let realtimeReport = bundle.appendingPathComponent("pmr-04/realtime-audio-engine.json")
    try weakPmr04RealtimeAudioEngineJson.write(to: realtimeReport, atomically: true, encoding: .utf8)
    let weakRealtimeBundle = try runShell(
        "OPEN_LOLA_CLI=\"$1\" bash scripts/verify-pmr-external-proof-bundle.sh \"$2\"",
        fakeCLI.path,
        bundle.path
    )
    #expect(weakRealtimeBundle.status != 0)
    #expect(weakRealtimeBundle.output.contains(
        "pmr-04/realtime-audio-engine.json runtime.callbackOwner must be audioDeviceIOProc"
    ))
    #expect(!weakRealtimeBundle.output.contains("PMR external proof bundle verified"))

    try validPmr04RealtimeAudioEngineJson.write(to: realtimeReport, atomically: true, encoding: .utf8)
    try "VERDICT: PASS\n".write(
        to: bundle.appendingPathComponent("pmr-04/sanitizer-result.txt"),
        atomically: true,
        encoding: .utf8
    )
    let weakSanitizerBundle = try runShell(
        "OPEN_LOLA_CLI=\"$1\" bash scripts/verify-pmr-external-proof-bundle.sh \"$2\"",
        fakeCLI.path,
        bundle.path
    )
    #expect(weakSanitizerBundle.status != 0)
    #expect(weakSanitizerBundle.output.contains(
        "must contain: ASAN: PASS"
    ))
    #expect(!weakSanitizerBundle.output.contains("PMR external proof bundle verified"))
}

@Test
func ciWorkflowRunsSameReleaseReadinessScriptWithoutPublishingArtifacts() throws {
    let workflow = try readText(".github/workflows/release-readiness.yml")

    #expect(workflow.contains("bash scripts/verify-release-readiness.sh"))
    #expect(workflow.contains("actions/checkout"))
    #expect(workflow.contains("actions/setup-python"))
    #expect(workflow.contains("tomllib.load"))
    #expect(workflow.contains("[\"project\"][\"optional-dependencies\"][\"dev\"]"))
    #expect(workflow.contains("contents: read"))
    #expect(!workflow.contains("upload-artifact"))
    #expect(!workflow.contains("upload-pages-artifact"))
    #expect(!workflow.contains("gh release"))
    #expect(!workflow.contains("action-gh-release"))
}

@Test
func jackTripDockerHelpersRejectMutablePrivilegedDefaults() throws {
    let scriptsReadme = try readText("scripts/README.md")

    #expect(scriptsReadme.contains("OPEN_LOLA_JACKTRIP_DOCKER_IMAGE"))
    #expect(!scriptsReadme.contains("jacktrip/jacktrip:latest"))

    for script in [
        "scripts/open-lola-jacktrip-docker-client.sh",
        "scripts/start-local-jacktrip-docker.sh",
        "scripts/compare-local-jacktrip-parity-docker.sh",
    ] {
        let missing = try runShell(
            "env -u OPEN_LOLA_JACKTRIP_DOCKER_IMAGE bash \"$1\" --version",
            script
        )
        #expect(missing.status == 64)
        #expect(missing.output.contains("OPEN_LOLA_JACKTRIP_DOCKER_IMAGE must be set"))
        #expect(missing.output.contains("Refusing the former unsafe default jacktrip/jacktrip:latest"))

        let latest = try runShell(
            "OPEN_LOLA_JACKTRIP_DOCKER_IMAGE=jacktrip/jacktrip:latest bash \"$1\" --version",
            script
        )
        #expect(latest.status == 64)
        #expect(latest.output.contains("must not use the mutable latest tag"))
    }

    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-jacktrip-docker-\(UUID().uuidString)")
    let fakeBin = temporaryRoot.appendingPathComponent("bin")
    let dockerLog = temporaryRoot.appendingPathComponent("docker-args.txt")
    try FileManager.default.createDirectory(at: fakeBin, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }
    let fakeDocker = fakeBin.appendingPathComponent("docker")
    try """
    #!/usr/bin/env bash
    printf '%s\\n' "$*" >> "$OPEN_LOLA_TEST_DOCKER_ARGS"
    exit 0
    """.write(to: fakeDocker, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: fakeDocker.path
    )

    let client = try runShell(
        "PATH=\"$1:$PATH\" OPEN_LOLA_TEST_DOCKER_ARGS=\"$2\" OPEN_LOLA_JACKTRIP_DOCKER_IMAGE=reviewed/jacktrip:1.0 bash scripts/open-lola-jacktrip-docker-client.sh -s -B 4464",
        fakeBin.path,
        dockerLog.path
    )
    #expect(client.status == 0)
    let dockerArgs = try String(contentsOf: dockerLog, encoding: .utf8)
    #expect(dockerArgs.contains("reviewed/jacktrip:1.0"))
    #expect(dockerArgs.contains("-p 4464:4464/tcp"))
    #expect(dockerArgs.contains("-p 4464:4464/udp"))
    #expect(!dockerArgs.contains("--privileged"))
    #expect(!dockerArgs.contains("jacktrip/jacktrip:latest"))
}

@Test
func wslLoLaNetworkHelperUsesStrictDryRunAndScopedFirewallControls() throws {
    let powerShell = try runShell("command -v pwsh >/dev/null 2>&1")
    if powerShell.status != 0 {
        let script = try readText("linux_connector/env/enable_wsl_lola_network.ps1")
        #expect(script.contains("[CmdletBinding(SupportsShouldProcess = $true"))
        #expect(script.contains("$PSCmdlet.ShouldProcess"))
        #expect(script.contains("[switch]$SkipWslShutdown"))
        return
    }

    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("open-lola-wsl-helper-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: temporaryRoot,
        withIntermediateDirectories: true
    )
    defer {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    let config = temporaryRoot.appendingPathComponent("wslconfig")
    let originalConfig = """
    [wsl2]
    networkingMode=mirrored

    """
    try originalConfig.write(to: config, atomically: true, encoding: .utf8)

    let dryRun = try runShell(
        """
        pwsh -NoProfile -File linux_connector/env/enable_wsl_lola_network.ps1 \
          -ConfigPath "$1" \
          -UdpPorts 7000 \
          -RuleName "Open LoLa Test Rule" \
          -InterfaceAlias "vEthernet (WSL)" \
          -SkipWslShutdown \
          -WhatIf
        """,
        config.path
    )
    #expect(dryRun.status == 0)
    #expect(dryRun.output.contains("Merging WSL NAT networking config..."))
    #expect(dryRun.output.contains("What if: Performing the operation \"merge LoLa WSL NAT settings\""))
    #expect(dryRun.output.contains("Adding scoped Windows firewall rule for LoLa/WSL UDP..."))
    #expect(dryRun.output.contains("allow inbound UDP ports 7000 on vEthernet (WSL)"))
    #expect(dryRun.output.contains("Skipping WSL shutdown because -SkipWslShutdown was supplied."))
    #expect(dryRun.output.contains("Done. Restart WSL and rerun the probe."))
    #expect(try String(contentsOf: config, encoding: .utf8) == originalConfig)
}

private func writeUltraGridRuntimeLog(
    in directory: URL,
    name: String,
    displayFps: Double
) throws -> URL {
    let url = directory.appendingPathComponent(name)
    try """
    New incoming audio format detected: PCM 48000 Hz
    New incoming video format detected: RGB 640x360
    [Pbuf] [audio] 10/10 packets received (100.0%), 0 lost
    [Pbuf] [video] 10/10 packets received (100.0%), 0 lost
    Audio dec stats (cumulative): 480 played / 480 total audio frames
    Video dec stats (cumulative): 12 total / 12 disp / 0 drop / 0 corr / 0 miss
    [dummy] 10 frames in 1.0 seconds = \(displayFps) FPS

    """.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func createPmrProofBundleFixture(at bundle: URL) throws {
    let files = [
        "pmr-04/realtime-audio-engine.json": validPmr04RealtimeAudioEngineJson,
        "pmr-04/sanitizer-result.txt": """
        ASAN: PASS
        TSAN: PASS

        """,
        "pmr-14/rx-buffer-benchmark.json": validPmr14RxBufferBenchmarkJson,
        "pmr-14/drift-plc-certification.json": validPmr14DriftCertificationJson,
        "pmr-14/direct-p2p-session.json": validPmr14DirectP2PSessionJson,
        "pmr-16/madi-full-duplex.json": validPmr16MadiFullDuplexJson,
        "pmr-16/hardware-notes.md": validPmr16HardwareNotes,
        "pmr-23/lola-media-session.json": validPmr23LoLaMediaSessionJson,
        "pmr-23/audio-loopback-run.json": validPmr23AudioLoopbackRunJson,
        "pmr-23/recording-session.json": "{}\n",
    ]
    for (relativePath, contents) in files {
        let url = bundle.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
    try FileManager.default.createDirectory(
        at: bundle.appendingPathComponent("pmr-14/direct-p2p-evidence"),
        withIntermediateDirectories: true
    )
}

private let validPmr04RealtimeAudioEngineJson = """
{
  "runMode": "measured",
  "hardwarePath": "rmeMadi",
  "runArtifactPath": "private/reports/pmr-04-realtime-audio-engine.json",
  "runtime": {
    "callbackOwner": "audioDeviceIOProc",
    "udpSocketsPreparedBeforeStart": true,
    "reportWrittenAfterStop": true,
    "handoff": {
      "inputBlocks": 48,
      "outputBlocks": 48,
      "networkSendBlocks": 48,
      "networkReceiveBlocks": 48,
      "shutdownCompleted": true
    }
  }
}

"""

private let weakPmr04RealtimeAudioEngineJson = """
{
  "runMode": "measured",
  "hardwarePath": "rmeMadi",
  "runArtifactPath": "private/reports/pmr-04-realtime-audio-engine.json",
  "runtime": {
    "callbackOwner": "synthetic",
    "udpSocketsPreparedBeforeStart": true,
    "reportWrittenAfterStop": true,
    "handoff": {
      "inputBlocks": 48,
      "outputBlocks": 48,
      "networkSendBlocks": 48,
      "networkReceiveBlocks": 48,
      "shutdownCompleted": true
    }
  }
}

"""

private let validPmr14RxBufferBenchmarkJson = """
{
  "verdict": "pass",
  "evidenceKind": "physicalReferenceRig",
  "rows": [
    {
      "profile": "direct",
      "physicalEvidence": true,
      "fastestPassEligible": true
    }
  ]
}

"""

private let validPmr14DriftCertificationJson = """
{
  "verdict": "pass",
  "runMode": "measured",
  "runArtifactPath": "private/reports/pmr-14-drift-plc-run.json",
  "lolaBaselineComparison": {
    "availability": "measured",
    "measuredOnSameHardwareAndRoute": true,
    "result": "openLolaFaster"
  }
}

"""

private let validPmr14DirectP2PSessionJson = """
{
  "verdict": "pass",
  "measuredEvidence": {
    "kind": "physicalTwoPeerMacs",
    "packetCapturePath": "private/captures/pmr-14-direct-p2p.pcapng",
    "packetCapture": {
      "path": "private/captures/pmr-14-direct-p2p.pcapng",
      "captured": true
    },
    "dscp": {
      "artifact": {
        "path": "private/captures/pmr-14-dscp.json",
        "captured": true
      }
    },
    "clock": {
      "artifact": {
        "path": "private/captures/pmr-14-clock.log",
        "captured": true
      }
    }
  },
  "metrics": {
    "packetsSent": 48,
    "packetsReceived": 48,
    "packetsLost": 0,
    "audioPacketsRouted": 48,
    "recoveryEvents": 0,
    "audioPayloadsSentOnControlChannel": 0,
    "remotePacketsLost": 0,
    "remoteLatePackets": 0,
    "remoteUnderruns": 0,
    "remoteOverruns": 0
  },
  "avRuntime": {
    "runtimeMetrics": {
      "audioPayloadsSent": 48,
      "audioPayloadsQueuedForPlayout": 48,
      "audioPayloadsDroppedBeforeSend": 0,
      "audioPayloadsDroppedBeforePlayout": 0,
      "audioPayloadsDroppedByPlayoutQueue": 0,
      "audioPlayoutUnderruns": 0,
      "audioCallbackDeadlineMisses": 0,
      "audioCallbackOverruns": 0
    }
  }
}

"""

private let weakPmr14DirectP2PSessionJson = """
{
  "verdict": "pass",
  "measuredEvidence": {
    "kind": "physicalTwoPeerMacs",
    "packetCapturePath": "private/captures/pmr-14-direct-p2p.pcapng",
    "packetCapture": {
      "path": "private/captures/pmr-14-direct-p2p.pcapng",
      "captured": true
    },
    "dscp": {
      "artifact": {
        "path": "private/captures/pmr-14-dscp.json",
        "captured": true
      }
    },
    "clock": {
      "artifact": {
        "path": "private/captures/pmr-14-clock.log",
        "captured": true
      }
    }
  },
  "metrics": {
    "packetsSent": 48,
    "packetsReceived": 48,
    "packetsLost": 0,
    "audioPacketsRouted": 48,
    "recoveryEvents": 0,
    "audioPayloadsSentOnControlChannel": 0
  },
  "avRuntime": {
    "runtimeMetrics": {
      "audioPayloadsSent": 48,
      "audioPayloadsQueuedForPlayout": 0,
      "audioPayloadsDroppedBeforeSend": 0,
      "audioPayloadsDroppedBeforePlayout": 0,
      "audioPayloadsDroppedByPlayoutQueue": 0,
      "audioPlayoutUnderruns": 0,
      "audioCallbackDeadlineMisses": 0,
      "audioCallbackOverruns": 0
    }
  }
}

"""

private let validPmr16HardwareNotes = """
input UID: input-rme-madi-test-uid
output UID: output-rme-madi-test-uid
RME MADI
peer readiness: exchanged
teardown: completed
packet capture: private/captures/pmr-16-test.pcapng

"""

private let validPmr16MadiFullDuplexJson = """
{
  "runMode": "measuredPhysical",
  "verdict": "pass",
  "localPeerID": "mac-a",
  "remotePeerID": "mac-b",
  "localEndpoint": {
    "host": "192.0.2.10",
    "port": 49500
  },
  "remoteEndpoint": {
    "host": "192.0.2.11",
    "port": 49500
  },
  "metrics": {
    "transmittedBlocks": 48,
    "transmittedFragments": 96,
    "receivedFragments": 96,
    "completedReceiveBlocks": 48,
    "renderedReceiveBlocks": 48,
    "txSenderFrameEnd": 1536,
    "rxPlayoutFrameEnd": 1536
  }
}

"""

private let weakPmr16MadiFullDuplexJson = """
{
  "runMode": "measuredPhysical",
  "verdict": "pass",
  "localPeerID": "mac-a",
  "remotePeerID": "mac-b",
  "localEndpoint": {
    "host": "192.0.2.10",
    "port": 49500
  },
  "remoteEndpoint": {
    "host": "192.0.2.11",
    "port": 49500
  },
  "metrics": {
    "transmittedBlocks": 48,
    "transmittedFragments": 96,
    "receivedFragments": 96,
    "completedReceiveBlocks": 0,
    "renderedReceiveBlocks": 0,
    "txSenderFrameEnd": 1536,
    "rxPlayoutFrameEnd": 0
  }
}

"""

private let validPmr23LoLaMediaSessionJson = """
{
  "role": "tx-rx",
  "realLinkTransmitted": true,
  "runtimeError": null,
  "frames": [
    {
      "stream": "audio"
    }
  ],
  "audioFrameCount": 1,
  "totalWireBytes": 1200,
  "envelopeValidatedFrameCount": 1,
  "expectedDatagramCount": 1,
  "sentBytesTotal": 1200,
  "localHost": "192.0.2.10",
  "peer": "192.0.2.11"
}

"""

private let weakPmr23LoLaMediaSessionJson = """
{
  "role": "tx-rx",
  "realLinkTransmitted": true,
  "runtimeError": null,
  "frames": [
    {
      "stream": "audio"
    }
  ],
  "audioFrameCount": 1,
  "totalWireBytes": 1200,
  "envelopeValidatedFrameCount": 1,
  "expectedDatagramCount": 1,
  "sentBytesTotal": 1200,
  "localHost": "192.0.2.10",
  "peer": "127.0.0.1"
}

"""

private let validPmr23AudioLoopbackRunJson = """
{
  "runnerKind": "audioDeviceIOProc",
  "state": "completed",
  "configuration": {
    "inputUID": "rme-madi-uid",
    "outputUID": "rme-madi-uid",
    "sampleRateHertz": 48000,
    "framesPerBuffer": 32,
    "channelCount": 64,
    "durationSeconds": 1800
  },
  "preflight": {
    "inputDevice": {
      "uid": "rme-madi-uid"
    },
    "outputDevice": {
      "uid": "rme-madi-uid"
    },
    "rmeMadiVisible": true,
    "sampleRateSupported": true,
    "frameSizeInReportedRange": true,
    "canStartIOProc": true,
    "blockers": []
  },
  "callback": {
    "recordedIntervalSamples": 48
  },
  "handoff": {
    "inputBlocks": 48,
    "outputBlocks": 48,
    "networkSendBlocks": 48,
    "networkReceiveBlocks": 48,
    "shutdownCompleted": true
  },
  "cleanup": {
    "failures": []
  }
}

"""

private let weakPmr23AudioLoopbackRunJson = """
{
  "runnerKind": "audioDeviceIOProc",
  "state": "completed",
  "configuration": {
    "inputUID": "rme-madi-uid",
    "outputUID": "rme-madi-uid",
    "sampleRateHertz": 48000,
    "framesPerBuffer": 32,
    "channelCount": 64,
    "durationSeconds": 1800
  },
  "preflight": {
    "inputDevice": {
      "uid": "rme-madi-uid"
    },
    "outputDevice": {
      "uid": "rme-madi-uid"
    },
    "rmeMadiVisible": true,
    "sampleRateSupported": true,
    "frameSizeInReportedRange": true,
    "canStartIOProc": true,
    "blockers": []
  },
  "callback": {
    "recordedIntervalSamples": 0
  },
  "handoff": {
    "inputBlocks": 48,
    "outputBlocks": 48,
    "networkSendBlocks": 48,
    "networkReceiveBlocks": 48,
    "shutdownCompleted": true
  },
  "cleanup": {
    "failures": []
  }
}

"""

private func writeFakePmrProofBundleCLI(to url: URL) throws {
    try """
    #!/usr/bin/env bash
    set -euo pipefail

    command="${1:-}"
    mode="${OPEN_LOLA_FAKE_PMR_MODE:-pass}"

    case "$command" in
      validate-lola-media-session-report)
        echo "role: tx-rx"
        if [[ "$mode" == "weak-lola" ]]; then
          echo "real-link-transmitted: false"
          echo "frames: 0"
        else
          echo "real-link-transmitted: true"
          echo "frames: 480"
        fi
        echo "VERDICT: PARTIAL"
        ;;
      validate-audio-loopback-run-report)
        if [[ "$mode" == "weak-coreaudio" ]]; then
          echo "state: blockedPreflight"
          echo "can-start-ioproc: false"
          echo "blockers: 2"
        else
          echo "state: completed"
          echo "can-start-ioproc: true"
          echo "blockers: 0"
        fi
        echo "VERDICT: PARTIAL"
        ;;
      verify-direct-p2p-session-evidence-bundle)
        echo "bundle: verified"
        echo "VERDICT: PASS"
        ;;
      validate-*)
        echo "VERDICT: PASS"
        ;;
      *)
        echo "unexpected fake open-lola command: $command" >&2
        exit 64
        ;;
    esac

    """.write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o755],
        ofItemAtPath: url.path
    )
}

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func readText(_ relativePath: String) throws -> String {
    let url = repositoryRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private struct ShellResult {
    let status: Int32
    let output: String
}

private func runShell(_ command: String, _ arguments: String...) throws -> ShellResult {
    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.currentDirectoryURL = repositoryRoot
    process.arguments = ["-lc", command, "open-lola-test"] + arguments
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    var combinedOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
    combinedOutput.append(errorOutput)
    return ShellResult(
        status: process.terminationStatus,
        output: String(decoding: combinedOutput, as: UTF8.self)
    )
}
