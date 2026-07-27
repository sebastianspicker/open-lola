// Verifies that release readiness script defines local verification matrix.
import Foundation
import Testing

@Test
func releaseReadinessScriptDefinesLocalVerificationMatrix() throws {
    let matrix = try runVerificationToolingShell(
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
        OPEN_LOLA_SKIP_INTERACTIVE_APP=0 main
        """
    )

    #expect(matrix.status == 0)
    expectReleaseReadinessExternalGates(in: matrix.output)
    expectReleaseReadinessProbeMatrix(in: matrix.output)
    #expect(matrix.output.contains("source-gate-verdict: pass"))
    #expect(matrix.output.contains("product-runtime-verdict: partial"))
    #expect(matrix.output.contains("VERDICT: PARTIAL"))
    #expect(!matrix.output.contains("VERDICT: PASS"))
}

@Test
func sourceDocumentationVerifierSelfTestPasses() throws {
    let result = try runVerificationToolingShell(
        "env PYTHONDONTWRITEBYTECODE=1 python3 scripts/verify_source_documentation.py --self-test"
    )

    #expect(result.status == 0)
    #expect(result.output.contains("source-documentation self-test passed"))
}

@Test
func releaseReadinessScriptKeepsReleaseBoundaryExplicit() throws {
    let gate = try runVerificationToolingShell(
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
func releaseReadinessScriptSkipsOnlyInteractiveAppEvidenceWhenExplicitlyRequested() throws {
    let gate = try runVerificationToolingShell(
        "source scripts/verify-release-readiness.sh; "
            + "OPEN_LOLA_SKIP_INTERACTIVE_APP=1 run_native_app_launch_gate"
    )

    #expect(gate.status == 0)
    #expect(gate.output.contains("native app launch probe -> SKIPPED (headless CI"))
    #expect(gate.output.contains("run locally for Launch Services and accessibility evidence"))
}

@Test
func pmrExternalProofBundleScriptRequiresLiveAndHardwareArtifacts() throws {
    let script = try verificationToolingReadText("scripts/verify-pmr-external-proof-bundle.sh")
    let scriptDocumentation = try verificationToolingReadText("scripts/README.md")
    let testingDocumentation = try verificationToolingReadText("docs/testing.md")

    expectPmrReportValidationCommands(in: script)
    expectPmr04AndPmr14RuntimeContracts(in: script)
    expectPmr16HardwareContracts(in: script)
    expectPmr23RuntimeContracts(in: script)
    let buildPathExport = "export OPEN_LOLA_SWIFT_BUILD_PATH=/private/tmp/open-lola-swiftpm-build"
    let buildCommand = """
        swift build --disable-sandbox --product open-lola --scratch-path "$OPEN_LOLA_SWIFT_BUILD_PATH"
        """
    for documentation in [scriptDocumentation, testingDocumentation] {
        #expect(documentation.contains(buildPathExport))
        #expect(documentation.contains(buildCommand))
    }
}

@Test
func pmrExternalProofBundleScriptRejectsWeakExternalArtifacts() throws {
    let fixture = try makeTemporaryPmrProofBundleFixture()
    defer {
        try? FileManager.default.removeItem(at: fixture.root)
    }

    let passingBundle = try runVerificationToolingShell(
        "OPEN_LOLA_CLI=\"$1\" bash scripts/verify-pmr-external-proof-bundle.sh \"$2\"",
        fixture.fakeCLI.path,
        fixture.bundle.path
    )
    #expect(passingBundle.status == 0)
    #expect(passingBundle.output.contains("PMR external proof bundle verified"))
    #expect(passingBundle.output.contains("VERDICT: PASS"))

    try expectWeakPmrMode(fixture, mode: "weak-lola", expected: "PMR-23 LoLa media session must match")
    try expectWeakPmrMode(fixture, mode: "weak-coreaudio", expected: "PMR-23 audio loopback run must match")
    try expectWeakPmrReportFixturesAreRejected(fixture)
}

@Test
func ciWorkflowRunsSameReleaseReadinessScriptWithoutPublishingArtifacts() throws {
    let workflow = try verificationToolingReadText(".github/workflows/release-readiness.yml")

    #expect(workflow.contains("bash scripts/verify-release-readiness.sh"))
    #expect(workflow.contains(
        "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2"
    ))
    #expect(workflow.contains("astral-sh/setup-uv@08807647e7069bb48b6ef5acd8ec9567f424441b"))
    #expect(workflow.contains("uv sync --locked --extra dev"))
    #expect(workflow.contains("uv run --locked --extra dev"))
    #expect(workflow.contains("runs-on: macos-26"))
    #expect(workflow.contains("DEVELOPER_DIR: /Applications/Xcode_26.6.app/Contents/Developer"))
    #expect(workflow.contains("[[ \"$(uv --version)\" == \"uv 0.10.7\"* ]]"))
    #expect(workflow.contains("python_path=\"$(uv python find 3.14.6)\""))
    #expect(workflow.contains("Apple Swift version 6.3.3"))
    #expect(workflow.contains("OPEN_LOLA_SWIFT_BUILD_PATH: ${{ runner.temp }}/open-lola-swiftpm-build"))
    #expect(workflow.contains("--scratch-path \"$OPEN_LOLA_SWIFT_BUILD_PATH\""))
    #expect(workflow.contains("python-version: \"3.14.6\""))
    #expect(workflow.contains("python-311:"))
    #expect(workflow.contains("python-version: \"3.11\""))
    #expect(workflow.contains("OPEN_LOLA_SKIP_INTERACTIVE_APP: \"1\""))
    #expect(workflow.contains("- \"v*-alpha.*\""))
    #expect(workflow.contains("contents: read"))
    #expect(!workflow.contains("OPEN_LOLA_PUBLIC_DOCS_ONLY"))
    #expect(!workflow.contains("radare2"))
    #expect(!workflow.contains("paths-ignore:"))
    #expect(!workflow.contains("upload-artifact"))
    #expect(!workflow.contains("upload-pages-artifact"))
    #expect(!workflow.contains("gh release"))
    #expect(!workflow.contains("action-gh-release"))
}

@Test
func jackTripDockerHelpersRejectMutablePrivilegedDefaults() throws {
    let scriptsReadme = try verificationToolingReadText("scripts/README.md")

    #expect(scriptsReadme.contains("OPEN_LOLA_JACKTRIP_DOCKER_IMAGE"))
    #expect(!scriptsReadme.contains("jacktrip/jacktrip:latest"))

    try expectJackTripDockerScriptsRejectUnsafeImages()
    try expectJackTripDockerClientUsesPinnedUnprivilegedContainer()
}

@Test
func wslLoLaNetworkHelperUsesStrictDryRunAndScopedFirewallControls() throws {
    let powerShell = try runVerificationToolingShell("command -v pwsh >/dev/null 2>&1")
    if powerShell.status != 0 {
        let script = try verificationToolingReadText("linux_connector/deployment/wsl/enable_wsl_lola_network.ps1")
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

    let dryRun = try runVerificationToolingShell(
        """
        pwsh -NoProfile -File linux_connector/deployment/wsl/enable_wsl_lola_network.ps1 \
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
