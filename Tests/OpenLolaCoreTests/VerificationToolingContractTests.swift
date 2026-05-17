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
        "RUN_STEP:bash scripts/verify-docs.sh",
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
